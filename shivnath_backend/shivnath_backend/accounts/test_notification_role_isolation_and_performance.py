import json
from decimal import Decimal
from django.contrib.auth.models import User
from django.test import TestCase
from rest_framework.test import APIClient
from rest_framework_simplejwt.tokens import RefreshToken

from accounts.models import (
    UserProfile,
    FranchiseProfile,
    AdminNotification,
    FranchiseNotification,
    CustomerNotification,
    DeviceToken,
    ServiceDistrict,
    ServiceZone,
)


class NotificationRoleIsolationAndPerformanceTests(TestCase):
    """
    Authoritative test suite verifying:
    1. Strict role-aware notification queryset isolation (Customer vs Franchise vs Admin).
    2. Customer cannot retrieve Admin or Franchise notifications via any endpoint.
    3. Franchise cannot retrieve Admin or other Franchise notifications.
    4. Lightweight unread count endpoint performance and accuracy.
    5. Token registration and unregistration isolation across accounts.
    """

    def setUp(self):
        # 1. Create District and Zone
        self.district = ServiceDistrict.objects.create(name='Raipur', state='Chhattisgarh')
        self.zone = ServiceZone.objects.create(district=self.district, name='Raipur Central', code='RP-CEN')

        # 2. Create Admin User
        self.admin_user = User.objects.create_user(
            username='admin@shivnath.com',
            email='admin@shivnath.com',
            password='Password123!',
            first_name='Admin',
            last_name='User',
            is_staff=True,
            is_superuser=True,
        )
        self.admin_profile, _ = UserProfile.objects.get_or_create(
            user=self.admin_user,
            defaults={'name': 'Admin User', 'phone': '9800000001', 'role': 'super_admin', 'status': 'active'}
        )
        self.admin_profile.role = 'super_admin'
        self.admin_profile.save()

        # 3. Create Franchise User A
        self.franchise_user_a = User.objects.create_user(
            username='franchise_a@shivnath.com',
            email='franchise_a@shivnath.com',
            password='Password123!',
            first_name='Franchise',
            last_name='Alpha',
        )
        self.franchise_profile_a, _ = UserProfile.objects.get_or_create(
            user=self.franchise_user_a,
            defaults={'name': 'Franchise Alpha', 'phone': '9800000002', 'role': 'franchise', 'status': 'active'}
        )
        self.franchise_profile_a.role = 'franchise'
        self.franchise_profile_a.save()
        self.fp_a = FranchiseProfile.objects.create(
            user=self.franchise_user_a,
            business_name='Alpha Water Services',
            city='Raipur',
            address='Station Road',
            status='approved',
        )

        # 4. Create Franchise User B
        self.franchise_user_b = User.objects.create_user(
            username='franchise_b@shivnath.com',
            email='franchise_b@shivnath.com',
            password='Password123!',
            first_name='Franchise',
            last_name='Beta',
        )
        self.franchise_profile_b, _ = UserProfile.objects.get_or_create(
            user=self.franchise_user_b,
            defaults={'name': 'Franchise Beta', 'phone': '9800000003', 'role': 'franchise', 'status': 'active'}
        )
        self.franchise_profile_b.role = 'franchise'
        self.franchise_profile_b.save()
        self.fp_b = FranchiseProfile.objects.create(
            user=self.franchise_user_b,
            business_name='Beta Water Services',
            city='Raipur',
            address='Ring Road',
            status='approved',
        )

        # 5. Create Customer User
        self.customer_user = User.objects.create_user(
            username='customer@shivnath.com',
            email='customer@shivnath.com',
            password='Password123!',
            first_name='Rahul',
            last_name='Sharma',
        )
        self.customer_profile, _ = UserProfile.objects.get_or_create(
            user=self.customer_user,
            defaults={'name': 'Rahul Sharma', 'phone': '9800000004', 'role': 'customer', 'status': 'active'}
        )
        self.customer_profile.role = 'customer'
        self.customer_profile.save()

        # Seed Notifications
        # Admin Notifications (Operational)
        self.admin_notif_1 = AdminNotification.objects.create(
            title='Franchise Stock Request #SR-101',
            message='Alpha Water Services requested 500 units of 20L Jar',
            notification_type='stock_alert',
            reference_id=101,
            is_read=False,
        )
        self.admin_notif_2 = AdminNotification.objects.create(
            title='New Lead Assigned: Priya Verma',
            message='Commercial bulk enquiry in Shankar Nagar',
            notification_type='general',
            reference_id=202,
            is_read=False,
        )

        # Franchise Notifications
        self.f_notif_a = FranchiseNotification.objects.create(
            franchise=self.fp_a,
            title='New Customer Assigned: Rahul Sharma',
            message='Rahul Sharma registered in your territory',
            notification_type='new_customer',
            reference_id=self.customer_user.id,
            is_read=False,
        )
        self.f_notif_b = FranchiseNotification.objects.create(
            franchise=self.fp_b,
            title='New Customer Assigned: Amit Patel',
            message='Amit Patel registered in your territory',
            notification_type='new_customer',
            reference_id=999,
            is_read=False,
        )

        # Customer Notifications
        self.c_notif_1 = CustomerNotification.objects.create(
            customer=self.customer_user,
            title='Order Confirmed! 🎉',
            message='Your water jar order #ORD-5001 is placed.',
            notification_type='order_update',
            reference_id=5001,
            is_read=False,
        )
        self.c_notif_2 = CustomerNotification.objects.create(
            customer=self.customer_user,
            title='Low Water Stock Reminder',
            message='7 days remaining in your active supply cycle.',
            notification_type='low_stock',
            reference_id=1,
            is_read=True,
        )

    def _client_for(self, user):
        client = APIClient()
        token = str(RefreshToken.for_user(user).access_token)
        client.credentials(HTTP_AUTHORIZATION=f'Bearer {token}')
        return client

    def test_customer_cannot_see_admin_or_franchise_notifications(self):
        """
        Customer calling /api/accounts/notifications/ or /api/accounts/customer/notifications/
        must ONLY receive CustomerNotification records belonging to them.
        """
        client = self._client_for(self.customer_user)

        # 1. Test unified notifications endpoint
        res = client.get('/api/accounts/notifications/')
        self.assertEqual(res.status_code, 200)
        data = res.json()
        self.assertTrue(data['success'])
        self.assertEqual(data['role'], 'customer')
        self.assertEqual(data['unread_count'], 1)  # 1 unread out of 2

        titles = [n['title'] for n in data['notifications']]
        self.assertIn('Order Confirmed! 🎉', titles)
        self.assertIn('Low Water Stock Reminder', titles)

        # MUST NEVER contain Admin or Franchise notifications
        self.assertNotIn('Franchise Stock Request #SR-101', titles)
        self.assertNotIn('New Lead Assigned: Priya Verma', titles)
        self.assertNotIn('New Customer Assigned: Rahul Sharma', titles)
        self.assertNotIn('New Customer Assigned: Amit Patel', titles)

        # 2. Test direct customer notifications endpoint
        res_cust = client.get('/api/accounts/customer/notifications/')
        self.assertEqual(res_cust.status_code, 200)
        data_cust = res_cust.json()
        self.assertTrue(data_cust['success'])
        self.assertEqual(len(data_cust['notifications']), 2)
        titles_cust = [n['title'] for n in data_cust['notifications']]
        self.assertNotIn('Franchise Stock Request #SR-101', titles_cust)

    def test_franchise_receives_only_their_own_notifications(self):
        """
        Franchise Alpha calling /api/accounts/notifications/ or /api/accounts/franchise-notifications/
        must ONLY see Franchise Alpha notifications, and NEVER Admin or Franchise Beta notifications.
        """
        client_a = self._client_for(self.franchise_user_a)

        res = client_a.get('/api/accounts/notifications/')
        self.assertEqual(res.status_code, 200)
        data = res.json()
        self.assertEqual(data['role'], 'franchise')
        self.assertEqual(data['count'], 1)
        self.assertEqual(data['notifications'][0]['title'], 'New Customer Assigned: Rahul Sharma')

        # Franchise Alpha cannot see Franchise Beta's customer
        titles = [n['title'] for n in data['notifications']]
        self.assertNotIn('New Customer Assigned: Amit Patel', titles)
        self.assertNotIn('Franchise Stock Request #SR-101', titles)

        # Franchise Beta check
        client_b = self._client_for(self.franchise_user_b)
        res_b = client_b.get('/api/accounts/notifications/')
        self.assertEqual(res_b.status_code, 200)
        data_b = res_b.json()
        self.assertEqual(data_b['count'], 1)
        self.assertEqual(data_b['notifications'][0]['title'], 'New Customer Assigned: Amit Patel')

    def test_admin_receives_operational_admin_notifications(self):
        """
        Admin receives operational admin notifications.
        """
        client_admin = self._client_for(self.admin_user)

        res = client_admin.get('/api/accounts/notifications/')
        self.assertEqual(res.status_code, 200)
        data = res.json()
        self.assertEqual(data['role'], 'super_admin')
        self.assertEqual(data['unread_count'], 2)

        titles = [n['title'] for n in data['notifications']]
        self.assertIn('Franchise Stock Request #SR-101', titles)
        self.assertIn('New Lead Assigned: Priya Verma', titles)

    def test_lightweight_unread_count_endpoint(self):
        """
        /api/accounts/notifications/unread-count/ returns accurate count scoped to user.
        """
        # Customer
        client_c = self._client_for(self.customer_user)
        res_c = client_c.get('/api/accounts/notifications/unread-count/')
        self.assertEqual(res_c.status_code, 200)
        self.assertEqual(res_c.json()['unread_count'], 1)

        # Franchise
        client_f = self._client_for(self.franchise_user_a)
        res_f = client_f.get('/api/accounts/notifications/unread-count/')
        self.assertEqual(res_f.status_code, 200)
        self.assertEqual(res_f.json()['unread_count'], 1)

        # Admin
        client_a = self._client_for(self.admin_user)
        res_a = client_a.get('/api/accounts/notifications/unread-count/')
        self.assertEqual(res_a.status_code, 200)
        self.assertEqual(res_a.json()['unread_count'], 2)

    def test_mark_as_read_isolation(self):
        """
        Marking notification read by Customer only affects that Customer's notification.
        """
        client_c = self._client_for(self.customer_user)
        res = client_c.post('/api/accounts/notifications/', {'id': self.c_notif_1.id})
        self.assertEqual(res.status_code, 200)

        self.c_notif_1.refresh_from_db()
        self.assertTrue(self.c_notif_1.is_read)

        # Admin notification remains unread
        self.admin_notif_1.refresh_from_db()
        self.assertFalse(self.admin_notif_1.is_read)

    def test_device_token_registration_and_account_switch_isolation(self):
        """
        When Admin registers token T on a phone, then logs out and Customer registers on the same phone:
        Token T must be re-associated with Customer, and Admin must NOT receive pushes sent to T.
        """
        client_admin = self._client_for(self.admin_user)
        shared_device_token = 'fcm_token_samsung_a14_unique_device_9999'

        # 1. Admin registers device token
        res_reg1 = client_admin.post('/api/accounts/register-device/', {
            'token': shared_device_token,
            'device_type': 'android'
        })
        self.assertEqual(res_reg1.status_code, 200)
        dt = DeviceToken.objects.get(token=shared_device_token)
        self.assertEqual(dt.user, self.admin_user)
        self.assertTrue(dt.is_active)

        # 2. Admin logs out -> unregisters device token
        res_unreg = client_admin.post('/api/accounts/unregister-device/', {
            'token': shared_device_token
        })
        self.assertEqual(res_unreg.status_code, 200)
        dt.refresh_from_db()
        self.assertFalse(dt.is_active)

        # 3. Customer logs in on the same phone -> registers device token
        client_cust = self._client_for(self.customer_user)
        res_reg2 = client_cust.post('/api/accounts/register-device/', {
            'token': shared_device_token,
            'device_type': 'android'
        })
        self.assertEqual(res_reg2.status_code, 200)
        dt.refresh_from_db()
        self.assertEqual(dt.user, self.customer_user)
        self.assertTrue(dt.is_active)

        # Verify active device tokens query for admin returns ZERO
        admin_tokens = list(DeviceToken.objects.filter(user=self.admin_user, is_active=True))
        self.assertEqual(len(admin_tokens), 0)

        # Verify active device tokens query for customer returns token
        cust_tokens = list(DeviceToken.objects.filter(user=self.customer_user, is_active=True))
        self.assertEqual(len(cust_tokens), 1)
        self.assertEqual(cust_tokens[0].token, shared_device_token)

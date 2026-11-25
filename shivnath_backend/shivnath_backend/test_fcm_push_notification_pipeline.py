import json
from decimal import Decimal
from datetime import date, timedelta
from unittest.mock import patch, MagicMock

from django.test import TestCase
from django.utils import timezone
from django.contrib.auth import get_user_model
from rest_framework.test import APIClient
from rest_framework import status

from accounts.models import (
    UserProfile,
    FranchiseProfile,
    DeviceToken,
    NotificationOutbox,
    AdminNotification,
    FranchiseNotification,
    CustomerNotification,
)
from accounts.fcm_services import (
    _init_firebase,
    _get_all_admins,
    _send_fcm_direct,
    enqueue_notification,
    dispatch_outbox_item,
    send_fcm_notification,
    notify_order_created,
    notify_order_status_update,
    notify_quotation_created,
    notify_quotation_status_update,
)
from chat.models import Quotation
from products.models import Product
from orders.models import Order, OrderItem
from billing.models import DeliveryOriginSetting, DeliveryDistanceBand

User = get_user_model()


class FCMPushNotificationPipelineTest(TestCase):
    def setUp(self):
        self.client = APIClient()

        # 1. Admin User
        self.admin = User.objects.create_superuser(
            username='admin_boss',
            email='admin@shivnath.com',
            password='AdminPassword@123'
        )
        UserProfile.objects.update_or_create(
            user=self.admin,
            defaults={'role': 'super_admin', 'phone': '9999900000', 'status': 'active'}
        )

        # 2. Franchise 1 User & Profile
        self.fran1_user = User.objects.create_user(
            username='krishna_water',
            email='krishna@gmail.com',
            password='Password@123'
        )
        UserProfile.objects.update_or_create(
            user=self.fran1_user,
            defaults={'role': 'franchise', 'phone': '9876543210', 'status': 'active'}
        )
        self.franchise1 = FranchiseProfile.objects.create(
            user=self.fran1_user,
            dealer_code='DLR-RAIPUR-01',
            business_name='Krishna Water Franchise',
            city='Raipur',
            address='Mowa Market, Raipur',
            status='approved'
        )

        # 3. Franchise 2 User & Profile (Unrelated for cross-tenant testing)
        self.fran2_user = User.objects.create_user(
            username='unrelated_fran',
            email='unrelated@gmail.com',
            password='Password@123'
        )
        UserProfile.objects.update_or_create(
            user=self.fran2_user,
            defaults={'role': 'franchise', 'phone': '9876543211', 'status': 'active'}
        )
        self.franchise2 = FranchiseProfile.objects.create(
            user=self.fran2_user,
            dealer_code='DLR-BHILAI-02',
            business_name='Bhilai Water Franchise',
            city='Bhilai',
            address='Sector 6, Bhilai',
            status='approved'
        )

        # 4. Customer User
        self.customer = User.objects.create_user(
            username='customer_ravi',
            email='ravi@gmail.com',
            password='Password@123'
        )
        UserProfile.objects.update_or_create(
            user=self.customer,
            defaults={'role': 'customer', 'phone': '9876543212', 'status': 'active'}
        )

        # Test Tokens
        self.admin_token = "fcm_token_admin_super_abc123"
        self.fran1_token = "fcm_token_fran1_krishna_def456"
        self.fran2_token = "fcm_token_fran2_unrelated_ghi789"
        self.cust_token = "fcm_token_cust_ravi_jkl012"

    def test_01_firebase_admin_initialization_with_credentials(self):
        """Firebase Admin SDK initializes successfully using service account credentials."""
        res = _init_firebase()
        self.assertTrue(res, "Firebase Admin SDK must initialize successfully.")

    def test_02_device_token_registration_and_multi_device(self):
        """Register device tokens via API, verify multi-device support and persistence."""
        self.client.force_authenticate(user=self.customer)

        # Device 1
        res1 = self.client.post('/api/notifications/register-device/', {
            'token': 'cust_device_1_token',
            'device_type': 'android',
            'device_name': 'Samsung Galaxy A14',
            'app_version': '1.0.0',
        }, format='json')
        self.assertEqual(res1.status_code, status.HTTP_200_OK)
        self.assertTrue(res1.data['success'])

        # Device 2
        res2 = self.client.post('/api/auth/register-device/', {
            'token': 'cust_device_2_token',
            'device_type': 'android',
            'device_name': 'Samsung Tablet',
            'app_version': '1.0.0',
        }, format='json')
        self.assertEqual(res2.status_code, status.HTTP_200_OK)

        active_tokens = DeviceToken.objects.filter(user=self.customer, is_active=True)
        self.assertEqual(active_tokens.count(), 2)

    def test_03_token_unregistration_and_account_takeover_protection(self):
        """Logout deactivates specific token; new user login reassigns and isolates token."""
        self.client.force_authenticate(user=self.customer)
        self.client.post('/api/notifications/register-device/', {
            'token': 'shared_phone_token',
            'device_type': 'android',
        }, format='json')

        dt = DeviceToken.objects.get(token='shared_phone_token')
        self.assertEqual(dt.user, self.customer)
        self.assertTrue(dt.is_active)

        # Unregister on logout
        res_unreg = self.client.post('/api/notifications/unregister-device/', {
            'token': 'shared_phone_token'
        }, format='json')
        self.assertEqual(res_unreg.status_code, status.HTTP_200_OK)

        dt.refresh_from_db()
        self.assertFalse(dt.is_active)

        # Franchise user logs into the same device
        self.client.force_authenticate(user=self.fran1_user)
        self.client.post('/api/notifications/register-device/', {
            'token': 'shared_phone_token',
            'device_type': 'android',
        }, format='json')

        dt.refresh_from_db()
        self.assertEqual(dt.user, self.fran1_user)
        self.assertTrue(dt.is_active)
        # Previous customer must NOT have this token active
        self.assertFalse(DeviceToken.objects.filter(user=self.customer, token='shared_phone_token', is_active=True).exists())

    @patch('accounts.fcm_services._trigger_async_dispatch')
    @patch('accounts.fcm_services._send_fcm_direct')
    def test_04_quotation_created_dispatches_fcm_to_franchise_with_tenant_isolation(self, mock_fcm, mock_async):
        """Admin publishing quotation triggers in-app notification & FCM to designated Franchise only."""
        mock_fcm.return_value = {'success': True, 'success_count': 1, 'failure_count': 0, 'message_id': 'fcm_q_001'}

        DeviceToken.objects.create(user=self.fran1_user, token=self.fran1_token, device_type='android', is_active=True)
        DeviceToken.objects.create(user=self.fran2_user, token=self.fran2_token, device_type='android', is_active=True)

        quotation = Quotation.objects.create(
            quotation_number='Q-TEST-001',
            title='Corporate 20L Dispenser Pack',
            franchise=self.franchise1,
            final_amount=Decimal('4500.00'),
            status='published',
            valid_until=date.today() + timedelta(days=15),
        )

        notify_quotation_created(quotation)

        # 1. In-app notification created for Franchise 1
        fn = FranchiseNotification.objects.filter(franchise=self.franchise1, reference_id=quotation.id)
        self.assertTrue(fn.exists())
        self.assertIn('Corporate 20L', fn.first().message)

        # 2. NO in-app notification for Franchise 2
        self.assertFalse(FranchiseNotification.objects.filter(franchise=self.franchise2, reference_id=quotation.id).exists())

        # 3. Synchronously dispatch outbox item to verify deterministic FCM payload
        item = NotificationOutbox.objects.filter(reference_id=quotation.id, notification_type='franchise_quotation').first()
        self.assertIsNotNone(item)
        res = dispatch_outbox_item(item.id)
        self.assertTrue(res.get('success'))

        mock_fcm.assert_called_once()
        called_tokens = mock_fcm.call_args[1]['tokens']
        self.assertIn(self.fran1_token, called_tokens)
        self.assertNotIn(self.fran2_token, called_tokens)
        self.assertIn('franchise_quotations', mock_fcm.call_args[1]['data']['screen'])

    @patch('accounts.fcm_services._trigger_async_dispatch')
    @patch('accounts.fcm_services._send_fcm_direct')
    def test_05_quotation_accepted_and_rejected_notify_admin_and_franchise(self, mock_fcm, mock_async):
        """Franchise accepting/rejecting quotation dispatches push to Admin and Franchise confirmation."""
        mock_fcm.return_value = {'success': True, 'success_count': 1, 'failure_count': 0, 'message_id': 'fcm_q_002'}

        DeviceToken.objects.create(user=self.admin, token=self.admin_token, device_type='android', is_active=True)
        DeviceToken.objects.create(user=self.fran1_user, token=self.fran1_token, device_type='android', is_active=True)

        quotation = Quotation.objects.create(
            quotation_number='Q-TEST-002',
            title='Event 1L Bottle Bulk',
            franchise=self.franchise1,
            final_amount=Decimal('8200.00'),
            status='accepted',
        )

        # Acceptance
        notify_quotation_status_update(quotation, action='accepted', actor_name='krishna_water')

        # Admin in-app notification created
        an = AdminNotification.objects.filter(reference_id=quotation.id, notification_type='quotation_accepted')
        self.assertTrue(an.exists())
        self.assertIn('Krishna Water Franchise accepted', an.first().message)

        # Rejection with mandatory reason
        mock_fcm.reset_mock()
        quotation.status = 'rejected'
        quotation.rejection_reason = 'Price rate per carton exceeds target regional ceiling.'
        quotation.save(update_fields=['status', 'rejection_reason'])

        notify_quotation_status_update(quotation, action='rejected', actor_name='krishna_water', reason=quotation.rejection_reason)

        an_rej = AdminNotification.objects.filter(reference_id=quotation.id, notification_type='quotation_rejected')
        self.assertTrue(an_rej.exists())
        self.assertIn('regional ceiling', an_rej.first().message)

    @patch('accounts.fcm_services._trigger_async_dispatch')
    @patch('accounts.fcm_services._send_fcm_direct')
    def test_06_order_hold_rejection_and_delay_fcm_triggers(self, mock_fcm, mock_async):
        """Order hold, delay, and rejection status transitions dispatch rich reason FCM notifications to Customer."""
        mock_fcm.return_value = {'success': True, 'success_count': 1, 'failure_count': 0, 'message_id': 'fcm_ord_001'}

        DeviceToken.objects.create(user=self.customer, token=self.cust_token, device_type='android', is_active=True)

        order = Order.objects.create(
            client_name='Ravi Kumar',
            created_by=self.customer,
            amount=Decimal('1200.00'),
            status='order_placement'
        )

        # 1. Hold transition
        order.status = 'on_hold'
        order.hold_reason = 'Water sample testing in progress for pure conductivity.'
        order.hold_reason_category = 'QUALITY_INSPECTION'
        order.save()

        notify_order_status_update(order, 'on_hold', actor_name='Admin')
        item_hold = NotificationOutbox.objects.filter(reference_id=order.id, recipient=self.customer, status='PENDING').first()
        self.assertIsNotNone(item_hold)
        dispatch_outbox_item(item_hold.id)

        mock_fcm.assert_called_once()
        self.assertIn(self.cust_token, mock_fcm.call_args[1]['tokens'])
        self.assertIn('conductivity', mock_fcm.call_args[1]['body'])
        self.assertEqual(mock_fcm.call_args[1]['data']['status'], 'on_hold')

        # 2. Delay transition
        mock_fcm.reset_mock()
        order.is_delayed = True
        order.delay_reason = 'Highway transport bottleneck near Durg junction.'
        order.save()

        notify_order_status_update(order, 'preparing', actor_name='Admin')
        item_delay = NotificationOutbox.objects.filter(reference_id=order.id, recipient=self.customer, status='PENDING').first()
        self.assertIsNotNone(item_delay)
        dispatch_outbox_item(item_delay.id)
        self.assertIn('Highway transport bottleneck', mock_fcm.call_args[1]['body'])

        # 3. Rejection transition
        mock_fcm.reset_mock()
        order.status = 'rejected'
        order.rejection_reason = 'Address inaccessible due to road widening work.'
        order.save()

        notify_order_status_update(order, 'rejected', actor_name='Admin')
        item_rej = NotificationOutbox.objects.filter(reference_id=order.id, recipient=self.customer, status='PENDING').first()
        self.assertIsNotNone(item_rej)
        dispatch_outbox_item(item_rej.id)
        self.assertIn('road widening work', mock_fcm.call_args[1]['body'])

    def test_07_distinction_between_in_app_and_push_notification(self):
        """System MUST distinguish in-app notification from push outcome: no token -> FAILED (not DELIVERED)."""
        # User has NO device token registered
        DeviceToken.objects.filter(user=self.customer).delete()

        items = enqueue_notification(
            users=[self.customer],
            title="Important Alert",
            body="No device token test",
            notification_type="order_status"
        )
        self.assertEqual(len(items), 1)
        item = items[0]

        res = dispatch_outbox_item(item.id)
        self.assertFalse(res.get('success'), "Must not report success when no device tokens exist.")

        item.refresh_from_db()
        self.assertEqual(item.status, 'FAILED', "Status must be FAILED, NOT DELIVERED, when recipient has no tokens.")
        self.assertEqual(item.fcm_response_code, 'NO_ACTIVE_TOKENS')

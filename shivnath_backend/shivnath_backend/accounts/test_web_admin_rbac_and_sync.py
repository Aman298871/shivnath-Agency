import json
from django.test import TestCase
from django.contrib.auth import get_user_model
from rest_framework.test import APIClient
from rest_framework import status
from accounts.models import UserProfile, AdminAuditLog, SystemEvent, publish_system_event
from accounts.permissions import HasGranularPermission

User = get_user_model()

class WebAdminRBACAndRealtimeSyncTestCase(TestCase):
    def setUp(self):
        self.client = APIClient()

        # 1. Super Admin
        self.super_admin = User.objects.create_superuser(
            username='superadmin_test',
            email='superadmin@test.com',
            password='Password@123'
        )
        self.super_admin_profile, _ = UserProfile.objects.get_or_create(
            user=self.super_admin,
            defaults={'role': 'super_admin', 'status': 'active', 'name': 'Super Admin'}
        )
        self.super_admin_profile.role = 'super_admin'
        self.super_admin_profile.status = 'active'
        self.super_admin_profile.admin_permissions = ['*']
        self.super_admin_profile.save()

        # 2. Staff Admin with restricted permissions (Orders only)
        self.orders_staff = User.objects.create_user(
            username='orders_staff',
            email='orders_staff@test.com',
            password='Password@123'
        )
        self.orders_profile, _ = UserProfile.objects.get_or_create(
            user=self.orders_staff,
            defaults={'role': 'admin', 'status': 'active', 'name': 'Orders Dispatcher'}
        )
        self.orders_profile.role = 'admin'
        self.orders_profile.status = 'active'
        self.orders_profile.admin_permissions = ['orders:view', 'orders:edit']
        self.orders_profile.save()
        self.orders_staff.refresh_from_db()

        # 3. Inactive Employee
        self.inactive_staff = User.objects.create_user(
            username='inactive_staff',
            email='inactive@test.com',
            password='Password@123',
            is_active=False
        )
        self.inactive_profile, _ = UserProfile.objects.get_or_create(
            user=self.inactive_staff,
            defaults={'role': 'admin', 'status': 'inactive', 'name': 'Deactivated Admin'}
        )
        self.inactive_profile.role = 'admin'
        self.inactive_profile.status = 'inactive'
        self.inactive_profile.save()
        self.inactive_staff.refresh_from_db()

    def test_has_granular_permission_logic(self):
        perm_orders_view = HasGranularPermission(module='orders', action='view')
        perm_billing_edit = HasGranularPermission(module='billing', action='edit')

        class MockView:
            pass

        class MockRequest:
            def __init__(self, user, method='GET'):
                self.user = user
                self.method = method

        req_super = MockRequest(self.super_admin)
        req_orders = MockRequest(self.orders_staff)
        req_inactive = MockRequest(self.inactive_staff)

        # Super admin has all permissions
        self.assertTrue(perm_orders_view.has_permission(req_super, MockView()))
        self.assertTrue(perm_billing_edit.has_permission(req_super, MockView()))

        # Orders staff has orders:view, but NOT billing:edit
        self.assertTrue(perm_orders_view.has_permission(req_orders, MockView()))
        self.assertFalse(perm_billing_edit.has_permission(req_orders, MockView()))

        # Inactive staff is denied everywhere
        self.assertFalse(perm_orders_view.has_permission(req_inactive, MockView()))
        self.assertFalse(perm_billing_edit.has_permission(req_inactive, MockView()))

    def test_publish_and_retrieve_system_events(self):
        # 1. Publish system event
        event = publish_system_event(
            event_type='order.created',
            payload={'order_id': 101, 'status': 'PENDING', 'total_amount': '500.00'},
            target_scope='all'
        )
        self.assertIsNotNone(event)
        self.assertEqual(event.event_type, 'order.created')
        self.assertEqual(event.payload['order_id'], 101)

        # 2. Retrieve latest events endpoint
        self.client.force_authenticate(user=self.super_admin)
        response = self.client.get('/api/events/latest/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        data = response.json()
        self.assertTrue(data['success'])
        self.assertGreaterEqual(len(data['events']), 1)
        self.assertEqual(data['events'][-1]['event_type'], 'order.created')

        # 3. Test after_id parameter
        last_id = data['latest_event_id']
        # Publish another event
        publish_system_event(
            event_type='order.updated',
            payload={'order_id': 101, 'status': 'DISPATCHED'},
            target_scope='all'
        )
        response_after = self.client.get(f'/api/events/latest/?after_id={last_id}')
        self.assertEqual(response_after.status_code, status.HTTP_200_OK)
        after_data = response_after.json()
        self.assertEqual(len(after_data['events']), 1)
        self.assertEqual(after_data['events'][0]['event_type'], 'order.updated')

    def test_admin_audit_logs_endpoint(self):
        # Create an audit log record
        AdminAuditLog.objects.create(
            actor=self.super_admin,
            action='UPDATE_ORDER_STATUS',
            resource_type='Order',
            resource_id='101',
            changes={'status': 'DELIVERED'}
        )

        self.client.force_authenticate(user=self.super_admin)
        response = self.client.get('/api/accounts/audit-logs/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        data = response.json()
        self.assertTrue(data['success'])
        self.assertGreaterEqual(data['total_count'], 1)
        self.assertEqual(data['logs'][0]['action'], 'UPDATE_ORDER_STATUS')

    def test_super_admin_employee_creation_and_event(self):
        self.client.force_authenticate(user=self.super_admin)
        payload = {
            'email': 'new_staff@test.com',
            'username': 'new_staff',
            'password': 'StaffPassword123!',
            'confirm_password': 'StaffPassword123!',
            'name': 'New Staff Member',
            'phone': '9876543210',
            'role': 'admin',
            'status': 'active',
            'admin_permissions': ['inventory:view', 'inventory:edit']
        }
        response = self.client.post('/api/accounts/super-admin/admins/', data=payload, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)

        new_user = User.objects.filter(email='new_staff@test.com').first()
        self.assertIsNotNone(new_user)
        self.assertTrue(new_user.is_active)
        self.assertEqual(new_user.profile.admin_permissions, ['inventory:view', 'inventory:edit'])

        # Check that employee.created event was published
        latest_event = SystemEvent.objects.order_by('-id').first()
        self.assertEqual(latest_event.event_type, 'employee.created')
        self.assertEqual(latest_event.payload['email'], 'new_staff@test.com')

    def test_sse_stream_security_and_authorization(self):
        # 1. Unauthenticated SSE connection attempt -> 401 Unauthorized
        res = self.client.get('/api/events/stream/')
        self.assertEqual(res.status_code, status.HTTP_401_UNAUTHORIZED)

        # 2. Inactive user token -> 401 Unauthorized
        from rest_framework_simplejwt.tokens import RefreshToken
        inactive_token = str(RefreshToken.for_user(self.inactive_staff).access_token)
        res = self.client.get(f'/api/events/stream/?token={inactive_token}')
        self.assertEqual(res.status_code, status.HTTP_401_UNAUTHORIZED)

        # 3. Customer user token -> 403 Forbidden (SSE restricted to operators)
        cust_user = User.objects.create_user(username='cust_sse', password='Password@123')
        prof, _ = UserProfile.objects.get_or_create(user=cust_user)
        prof.role = 'customer'
        prof.status = 'active'
        prof.save()
        cust_user.refresh_from_db()
        cust_token = str(RefreshToken.for_user(cust_user).access_token)
        res = self.client.get(f'/api/events/stream/?token={cust_token}')
        self.assertEqual(res.status_code, status.HTTP_403_FORBIDDEN)


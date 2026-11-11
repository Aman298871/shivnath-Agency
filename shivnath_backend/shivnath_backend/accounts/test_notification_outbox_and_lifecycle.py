import json
from datetime import timedelta
from unittest.mock import patch, MagicMock
from django.test import TestCase
from django.utils import timezone
from rest_framework.test import APIClient
from django.contrib.auth import get_user_model
from accounts.models import UserProfile, DeviceToken, NotificationOutbox
from accounts.fcm_services import (
    enqueue_notification,
    dispatch_outbox_item,
    process_notification_outbox,
    send_fcm_notification,
)

User = get_user_model()

class NotificationOutboxAndLifecycleTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.admin = User.objects.create_user(
            username='admin_notif_test',
            email='admin_notif@example.com',
            password='password123',
            is_staff=True,
            is_superuser=True
        )
        UserProfile.objects.update_or_create(
            user=self.admin,
            defaults={'role': 'admin', 'name': 'Admin User', 'phone': '9999900001'}
        )

        self.customer1 = User.objects.create_user(
            username='cust1_notif_test',
            email='cust1_notif@example.com',
            password='password123'
        )
        UserProfile.objects.update_or_create(
            user=self.customer1,
            defaults={'role': 'customer', 'name': 'Customer One', 'phone': '9999900002'}
        )

        self.customer2 = User.objects.create_user(
            username='cust2_notif_test',
            email='cust2_notif@example.com',
            password='password123'
        )
        UserProfile.objects.update_or_create(
            user=self.customer2,
            defaults={'role': 'customer', 'name': 'Customer Two', 'phone': '9999900003'}
        )
        self.token_str = "fcm_test_token_alpha_1234567890"

    def test_01_device_token_registration_with_metadata(self):
        """Verify device registration saves device metadata and timestamps."""
        self.client.force_authenticate(user=self.customer1)
        resp = self.client.post('/api/notifications/register-device/', {
            'token': self.token_str,
            'device_type': 'android',
            'device_name': 'Pixel 7 Android 14',
            'app_version': '1.0.0+6'
        }, format='json')
        self.assertEqual(resp.status_code, 200)

        dt = DeviceToken.objects.get(token=self.token_str)
        self.assertEqual(dt.user, self.customer1)
        self.assertEqual(dt.device_type, 'android')
        self.assertEqual(dt.device_name, 'Pixel 7 Android 14')
        self.assertEqual(dt.app_version, '1.0.0+6')
        self.assertTrue(dt.is_active)
        self.assertIsNotNone(dt.last_seen_at)

    def test_02_account_switching_reassigns_device_token(self):
        """When user B logs into the same physical device, token is reassigned to B."""
        DeviceToken.objects.create(
            user=self.customer1,
            token=self.token_str,
            device_type='android',
            is_active=True
        )

        self.client.force_authenticate(user=self.customer2)
        resp = self.client.post('/api/notifications/register-device/', {
            'token': self.token_str,
            'device_type': 'android',
        }, format='json')
        self.assertEqual(resp.status_code, 200)

        tokens = DeviceToken.objects.filter(token=self.token_str)
        self.assertEqual(tokens.count(), 1)
        self.assertEqual(tokens.first().user, self.customer2)
        self.assertTrue(tokens.first().is_active)

    def test_03_device_token_unregistration_deactivates_token(self):
        """Unregistering a token sets is_active=False."""
        dt = DeviceToken.objects.create(
            user=self.customer1,
            token=self.token_str,
            device_type='android',
            is_active=True
        )
        self.client.force_authenticate(user=self.customer1)
        resp = self.client.post('/api/notifications/unregister-device/', {
            'token': self.token_str
        }, format='json')
        self.assertEqual(resp.status_code, 200)

        dt.refresh_from_db()
        self.assertFalse(dt.is_active)

    def test_04_enqueue_notification_idempotent_deduplication(self):
        """Enqueueing identical idempotency key returns the existing item without duplicates."""
        key = "idemp_order_create_1001"
        items1 = enqueue_notification(
            users=self.customer1,
            title="Order Placed",
            body="Your water order is placed",
            notification_type="order_placed",
            reference_id=1001,
            idempotency_key=key
        )
        items2 = enqueue_notification(
            users=self.customer1,
            title="Order Placed Duplicate",
            body="Your water order is placed duplicate",
            notification_type="order_placed",
            reference_id=1001,
            idempotency_key=key
        )
        self.assertEqual(items1[0].id, items2[0].id)
        self.assertEqual(NotificationOutbox.objects.filter(idempotency_key=key).count(), 1)

    @patch('accounts.fcm_services._send_fcm_direct')
    def test_05_dispatch_outbox_item_success(self, mock_direct):
        """Successful FCM dispatch transitions outbox item to DELIVERED."""
        mock_direct.return_value = {
            'success': True,
            'success_count': 1,
            'failure_count': 0,
            'message_id': 'msg_firebase_001',
            'failed_tokens': []
        }
        DeviceToken.objects.create(
            user=self.customer1,
            token=self.token_str,
            device_type='android',
            is_active=True
        )

        items = enqueue_notification(
            users=self.customer1,
            title="Out for Delivery",
            body="Rider is on the way",
            notification_type="order_out_for_delivery",
            reference_id=1002
        )
        item = items[0]
        res = dispatch_outbox_item(item.id, worker_id="test_worker_1")
        self.assertTrue(res)

        item.refresh_from_db()
        self.assertEqual(item.status, 'DELIVERED')
        self.assertEqual(item.attempts, 1)
        self.assertEqual(item.fcm_message_id, 'msg_firebase_001')

    @patch('accounts.fcm_services._send_fcm_direct')
    def test_06_dispatch_outbox_item_transient_failure_retries(self, mock_direct):
        """Transient error (503 / timeout) schedules retry with backoff."""
        mock_direct.side_effect = Exception("FCM 503 Server Unavailable")

        DeviceToken.objects.create(
            user=self.customer1,
            token=self.token_str,
            device_type='android',
            is_active=True
        )
        items = enqueue_notification(
            users=self.customer1,
            title="Delivery Alert",
            body="Retry test",
            notification_type="test_retry",
            reference_id=1003
        )
        item = items[0]
        res = dispatch_outbox_item(item.id, worker_id="test_worker_2")
        self.assertFalse(res.get('success'))

        item.refresh_from_db()
        self.assertEqual(item.status, 'RETRY')
        self.assertEqual(item.attempts, 1)
        self.assertIsNotNone(item.next_retry_at)
        self.assertIn("503", item.error_message)

    @patch('accounts.fcm_services._send_fcm_direct')
    def test_07_dispatch_outbox_item_permanent_failure_deactivates_token(self, mock_direct):
        """Unregistered / invalid token deactivates token and marks item FAILED."""
        mock_direct.return_value = {
            'success': False,
            'success_count': 0,
            'failure_count': 1,
            'error': 'UNREGISTERED device token',
            'message_id': '',
            'failed_tokens': [(self.token_str, 'UNREGISTERED')]
        }
        dt = DeviceToken.objects.create(
            user=self.customer1,
            token=self.token_str,
            device_type='android',
            is_active=True
        )
        items = enqueue_notification(
            users=self.customer1,
            title="Final Notice",
            body="Permanent test",
            notification_type="test_fail",
            reference_id=1004
        )
        item = items[0]
        dispatch_outbox_item(item.id, worker_id="test_worker_3")

        item.refresh_from_db()
        self.assertEqual(item.status, 'FAILED')
        dt.refresh_from_db()
        self.assertFalse(dt.is_active)

    def test_08_sweeper_recovers_stale_processing_locks(self):
        """Items locked in PROCESSING for longer than stale_timeout are recovered and retried."""
        stale_time = timezone.now() - timedelta(minutes=15)
        item = NotificationOutbox.objects.create(
            recipient=self.customer1,
            title="Stale Item",
            body="Was abandoned by crashed worker",
            status='PROCESSING',
            locked_at=stale_time,
            locked_by="dead_worker_99"
        )

        with patch('accounts.fcm_services._send_fcm_direct') as mock_send:
            mock_send.return_value = {
                'success': True,
                'success_count': 0,
                'failure_count': 0,
                'message_id': '',
                'failed_tokens': []
            }
            stats = process_notification_outbox(batch_size=10, stale_timeout_minutes=5)

        self.assertGreaterEqual(stats['stale_recovered'], 1)

    def test_09_admin_outbox_monitoring_api(self):
        """Admin can view stats, list items, and retry failed outbox items."""
        failed_item = NotificationOutbox.objects.create(
            recipient=self.customer1,
            title="Failed Message",
            body="Failed payload",
            status='FAILED',
            attempts=5
        )

        self.client.force_authenticate(user=self.admin)

        # 1. Stats
        resp_stats = self.client.get('/api/accounts/notifications/outbox/stats/')
        self.assertEqual(resp_stats.status_code, 200)
        self.assertIn('summary', resp_stats.data)
        self.assertGreaterEqual(resp_stats.data['summary']['failed'], 1)

        # 2. List items
        resp_list = self.client.get('/api/accounts/notifications/outbox/items/?status=FAILED')
        self.assertEqual(resp_list.status_code, 200)
        self.assertGreaterEqual(len(resp_list.data['items']), 1)

        # 3. Retry failed items
        resp_retry = self.client.post('/api/accounts/notifications/outbox/retry/', {
            'outbox_ids': [failed_item.id]
        }, format='json')
        self.assertEqual(resp_retry.status_code, 200)
        self.assertEqual(resp_retry.data['reset_count'], 1)

        failed_item.refresh_from_db()
        self.assertEqual(failed_item.status, 'PENDING')
        self.assertEqual(failed_item.attempts, 0)

    @patch('accounts.fcm_services._send_fcm_direct')
    def test_10_multi_device_lifecycle_and_account_isolation(self, mock_direct):
        """
        Critical Phase 2 Test:
        - Customer A logs into Device 1 (token_1) and Device 2 (token_2).
        - Customer A logs out from Device 1 -> Device 2 remains active for Customer A.
        - Customer B logs into Device 1 (token_1).
        - Device 1 is now active for Customer B only.
        - Notifications to Customer A reach Device 2 only (never Device 1).
        - Notifications to Customer B reach Device 1 only (never Device 2).
        """
        token_1 = "fcm_token_device_one_11111"
        token_2 = "fcm_token_device_two_22222"

        # 1. Customer A logs into Device 1
        self.client.force_authenticate(user=self.customer1)
        res1 = self.client.post('/api/notifications/register-device/', {
            'token': token_1,
            'device_type': 'android',
            'device_name': 'CustomerA Phone 1'
        }, format='json')
        self.assertEqual(res1.status_code, 200)

        # 2. Customer A logs into Device 2
        res2 = self.client.post('/api/notifications/register-device/', {
            'token': token_2,
            'device_type': 'ios',
            'device_name': 'CustomerA Tablet'
        }, format='json')
        self.assertEqual(res2.status_code, 200)

        self.assertEqual(DeviceToken.objects.filter(user=self.customer1, is_active=True).count(), 2)

        # 3. Customer A logs out from Device 1
        res_logout = self.client.post('/api/notifications/unregister-device/', {
            'token': token_1
        }, format='json')
        self.assertEqual(res_logout.status_code, 200)

        # Device 2 MUST still be active for Customer A!
        self.assertTrue(DeviceToken.objects.filter(user=self.customer1, token=token_2, is_active=True).exists())
        self.assertFalse(DeviceToken.objects.filter(user=self.customer1, token=token_1, is_active=True).exists())

        # 4. Customer B logs into Device 1 (token_1)
        self.client.force_authenticate(user=self.customer2)
        res_cust2 = self.client.post('/api/notifications/register-device/', {
            'token': token_1,
            'device_type': 'android',
            'device_name': 'CustomerB Phone'
        }, format='json')
        self.assertEqual(res_cust2.status_code, 200)

        # Device 1 is now active for Customer B
        dt_b = DeviceToken.objects.get(token=token_1)
        self.assertEqual(dt_b.user, self.customer2)
        self.assertTrue(dt_b.is_active)

        # Device 2 is still active for Customer A
        dt_a = DeviceToken.objects.get(token=token_2)
        self.assertEqual(dt_a.user, self.customer1)
        self.assertTrue(dt_a.is_active)

        # 5. Dispatch notification to Customer A -> Must target token_2 only
        mock_direct.return_value = {'success': True, 'success_count': 1, 'failure_count': 0, 'message_id': 'm1'}
        items_a = enqueue_notification(
            users=self.customer1,
            title="Alert A",
            body="Hello Customer A",
            notification_type="order_update"
        )
        dispatch_outbox_item(items_a[0].id)
        mock_direct.assert_called_with(tokens=[token_2], title="Alert A", body="Hello Customer A", data=items_a[0].data)

        # 6. Dispatch notification to Customer B -> Must target token_1 only
        mock_direct.reset_mock()
        items_b = enqueue_notification(
            users=self.customer2,
            title="Alert B",
            body="Hello Customer B",
            notification_type="order_update"
        )
        dispatch_outbox_item(items_b[0].id)
        mock_direct.assert_called_with(tokens=[token_1], title="Alert B", body="Hello Customer B", data=items_b[0].data)

    def test_11_outbox_sweeper_webhook_endpoint(self):
        """Verify the secure maintenance sweeper webhook endpoint."""
        import hashlib
        from django.conf import settings
        valid_secret = getattr(settings, 'MAINTENANCE_CRON_SECRET', None) or hashlib.sha256((settings.SECRET_KEY + '_sweeper').encode('utf-8')).hexdigest()[:32]

        self.client.force_authenticate(user=None)

        # 1. Unauthenticated without secret returns 403 Forbidden
        res_unauth = self.client.post('/api/accounts/notifications/outbox/sweep/')
        self.assertEqual(res_unauth.status_code, 403)

        # 2. HTTP GET is rejected with 405 Method Not Allowed
        res_get = self.client.get('/api/accounts/notifications/outbox/sweep/')
        self.assertEqual(res_get.status_code, 405)

        # 3. Authenticated via secure header X-Sweeper-Secret returns 200 OK
        res_sweep_header = self.client.post(
            '/api/accounts/notifications/outbox/sweep/',
            HTTP_X_SWEEPER_SECRET=valid_secret
        )
        self.assertEqual(res_sweep_header.status_code, 200)
        self.assertTrue(res_sweep_header.data['success'])
        self.assertIn('stats', res_sweep_header.data)

        # 4. Authenticated via Authorization: Bearer <secret> returns 200 OK
        res_bearer = self.client.post(
            '/api/accounts/notifications/outbox/sweep/',
            HTTP_AUTHORIZATION=f'Bearer {valid_secret}'
        )
        self.assertEqual(res_bearer.status_code, 200)
        self.assertTrue(res_bearer.data['success'])

import os
import json
import hmac
import hashlib
from decimal import Decimal
from django.test import TestCase, override_settings
from django.contrib.auth.models import User
from django.core.files.uploadedfile import SimpleUploadedFile
from django.core.cache import cache
from rest_framework.test import APIClient
from rest_framework import status

from accounts.models import UserProfile, FranchiseProfile, SystemEvent
from orders.models import Order
from billing.models import Invoice
from orders.views import get_razorpay_credentials


class SecurityRemediationTestSuite(TestCase):
    def setUp(self):
        self.client = APIClient()
        cache.clear()

        # Helper to setup profile safely
        def setup_profile(user, role):
            profile = getattr(user, 'profile', None)
            if not profile:
                profile, _ = UserProfile.objects.get_or_create(user=user)
            profile.role = role
            profile.status = 'active'
            profile.save()
            return profile

        # 1. Super Admin
        self.super_admin_user = User.objects.create_superuser(
            username='test_superadmin@shivnath.com',
            email='test_superadmin@shivnath.com',
            password='TestSuperPassword123!'
        )
        setup_profile(self.super_admin_user, 'super_admin')

        # 2. Franchise User & Profile
        self.franchise_user = User.objects.create_user(
            username='test_franchise@shivnath.com',
            email='test_franchise@shivnath.com',
            password='TestFranchisePassword123!'
        )
        setup_profile(self.franchise_user, 'franchise')
        self.franchise_profile = FranchiseProfile.objects.create(
            user=self.franchise_user,
            business_name='Test Franchise Agency',
            city='Raipur',
            status='approved'
        )

        # 3. Customer A
        self.customer_a = User.objects.create_user(
            username='customer_a@example.com',
            email='customer_a@example.com',
            password='CustomerPasswordA123!'
        )
        setup_profile(self.customer_a, 'customer')

        # 4. Customer B
        self.customer_b = User.objects.create_user(
            username='customer_b@example.com',
            email='customer_b@example.com',
            password='CustomerPasswordB123!'
        )
        setup_profile(self.customer_b, 'customer')

        # 5. Orders for Customer A and B
        self.order_a = Order.objects.create(
            created_by=self.customer_a,
            franchise_name='Test Franchise Agency',
            city='Raipur',
            client_name='Customer A',
            delivery_address='Address A',
            amount=Decimal('1000.00'),
            grand_total=Decimal('1000.00'),
            status='order_placement',
            payment_status='pending'
        )
        self.order_b = Order.objects.create(
            created_by=self.customer_b,
            franchise_name='Test Franchise Agency',
            city='Raipur',
            client_name='Customer B',
            delivery_address='Address B',
            amount=Decimal('2000.00'),
            grand_total=Decimal('2000.00'),
            status='order_placement',
            payment_status='pending'
        )

        # 6. Invoices for Order A and Order B
        self.invoice_a = Invoice.objects.create(
            invoice_number='INV-TEST-0001',
            order=self.order_a,
            billed_to_name='Customer A',
            subtotal=Decimal('1000.00'),
            grand_total=Decimal('1000.00'),
            amount_paid=Decimal('0.00'),
            status='ISSUED'
        )
        self.invoice_b = Invoice.objects.create(
            invoice_number='INV-TEST-0002',
            order=self.order_b,
            billed_to_name='Customer B',
            subtotal=Decimal('2000.00'),
            grand_total=Decimal('2000.00'),
            amount_paid=Decimal('0.00'),
            status='ISSUED'
        )

    # -------------------------------------------------------------
    # P0.1 & P0.2: RAZORPAY CREDENTIALS & FAIL-CLOSED WEBHOOK
    # -------------------------------------------------------------
    def test_razorpay_credentials_no_hardcoded_fallback(self):
        with override_settings(RAZORPAY_KEY_ID='', RAZORPAY_KEY_SECRET=''):
            # When env vars are absent, get_razorpay_credentials must not return hardcoded test keys
            key_id, key_secret, _, _ = get_razorpay_credentials()
            self.assertNotEqual(key_id, 'rzp_live_Tnhqo3i0SyYYdf')
            self.assertNotEqual(key_secret, 'u6BrnyYxz3U9lqPNhSrWI7lB')

    def test_razorpay_webhook_fails_closed_when_secret_unset(self):
        with override_settings(RAZORPAY_WEBHOOK_SECRET=''):
            response = self.client.post(
                '/api/orders/razorpay/webhook/',
                data=json.dumps({'event': 'payment.captured'}),
                content_type='application/json'
            )
            self.assertEqual(response.status_code, status.HTTP_503_SERVICE_UNAVAILABLE)
            self.assertIn('RAZORPAY_WEBHOOK_SECRET is not configured', response.json().get('error', ''))

    def test_razorpay_webhook_rejects_missing_signature(self):
        with override_settings(RAZORPAY_WEBHOOK_SECRET='test_webhook_secret_key_123'):
            response = self.client.post(
                '/api/orders/razorpay/webhook/',
                data=json.dumps({'event': 'payment.captured'}),
                content_type='application/json'
            )
            self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
            self.assertIn('Missing X-Razorpay-Signature', response.json().get('error', ''))

    def test_razorpay_webhook_rejects_invalid_signature(self):
        with override_settings(RAZORPAY_WEBHOOK_SECRET='test_webhook_secret_key_123'):
            response = self.client.post(
                '/api/orders/razorpay/webhook/',
                data=json.dumps({'event': 'payment.captured'}),
                content_type='application/json',
                HTTP_X_RAZORPAY_SIGNATURE='tampered_signature_hex_value'
            )
            self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
            self.assertIn('Invalid webhook signature', response.json().get('error', ''))

    def test_razorpay_webhook_accepts_valid_signature(self):
        webhook_secret = 'test_webhook_secret_key_123'
        payload_bytes = json.dumps({'event': 'payment.captured', 'payload': {}}).encode('utf-8')
        valid_signature = hmac.new(webhook_secret.encode('utf-8'), payload_bytes, hashlib.sha256).hexdigest()

        with override_settings(RAZORPAY_WEBHOOK_SECRET=webhook_secret):
            response = self.client.post(
                '/api/orders/razorpay/webhook/',
                data=payload_bytes,
                content_type='application/json',
                HTTP_X_RAZORPAY_SIGNATURE=valid_signature
            )
            self.assertEqual(response.status_code, status.HTTP_200_OK)

    # -------------------------------------------------------------
    # P0.3: ORDER ACCESS CONTROL & ANTI-IDOR
    # -------------------------------------------------------------
    def test_anonymous_order_list_denied(self):
        response = self.client.get('/api/orders/')
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_anonymous_order_detail_denied(self):
        response = self.client.get(f'/api/orders/{self.order_a.id}/')
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_customer_order_list_isolation(self):
        self.client.force_authenticate(user=self.customer_a)
        response = self.client.get('/api/orders/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        order_ids = [o['id'] for o in response.json().get('orders', [])]
        self.assertIn(self.order_a.id, order_ids)
        self.assertNotIn(self.order_b.id, order_ids)

    def test_customer_order_detail_idor_blocked(self):
        self.client.force_authenticate(user=self.customer_a)
        # Attempt to access Customer B's order
        response = self.client.get(f'/api/orders/{self.order_b.id}/')
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_customer_cannot_update_another_customer_order(self):
        self.client.force_authenticate(user=self.customer_a)
        response = self.client.patch(
            f'/api/orders/{self.order_b.id}/',
            data={'status': 'cancelled'},
            format='json'
        )
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    # -------------------------------------------------------------
    # P0.4: INVOICE ACCESS CONTROL & ANTI-IDOR
    # -------------------------------------------------------------
    def test_anonymous_invoice_list_denied(self):
        response = self.client.get('/api/billing/invoices/')
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_customer_invoice_detail_idor_blocked(self):
        self.client.force_authenticate(user=self.customer_a)
        # Attempt to access Customer B's invoice
        response = self.client.get(f'/api/billing/invoices/{self.invoice_b.id}/')
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)

    def test_customer_can_access_own_invoice(self):
        self.client.force_authenticate(user=self.customer_a)
        response = self.client.get(f'/api/billing/invoices/{self.invoice_a.id}/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.json()['id'], self.invoice_a.id)

    # -------------------------------------------------------------
    # P0.5: DEMO SEED BACKDOOR REMOVAL
    # -------------------------------------------------------------
    def test_demo_seed_endpoint_denied_with_static_secret(self):
        # Unauthenticated request with previously hardcoded secret
        response = self.client.post(
            '/api/accounts/super-admin/seed-demo-data/',
            data={'secret': 'shivnath_demo_seed_secret_2026'},
            format='json'
        )
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_demo_seed_endpoint_denied_to_regular_customer(self):
        self.client.force_authenticate(user=self.customer_a)
        response = self.client.post(
            '/api/accounts/super-admin/seed-demo-data/',
            data={'secret': 'shivnath_demo_seed_secret_2026'},
            format='json'
        )
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_demo_seed_endpoint_strictly_disabled_in_production(self):
        self.client.force_authenticate(user=self.super_admin_user)
        with override_settings(DEBUG=False):
            response = self.client.post(
                '/api/accounts/super-admin/seed-demo-data/',
                format='json'
            )
            self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)
            self.assertIn('strictly disabled in production', response.json().get('error', ''))

    # -------------------------------------------------------------
    # P0.6: DATABASE BACKUP ENDPOINT AUTHORIZATION
    # -------------------------------------------------------------
    def test_backup_endpoint_denied_to_regular_customer(self):
        self.client.force_authenticate(user=self.customer_a)
        response = self.client.get('/api/accounts/backup/')
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_backup_endpoint_denied_to_franchise(self):
        self.client.force_authenticate(user=self.franchise_user)
        response = self.client.get('/api/accounts/backup/')
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_backup_endpoint_allowed_to_superadmin(self):
        self.client.force_authenticate(user=self.super_admin_user)
        response = self.client.get('/api/accounts/backup/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)

    # -------------------------------------------------------------
    # P0.7: SSE TICKET EXCHANGE & EVENT SCOPE FILTERING
    # -------------------------------------------------------------
    def test_sse_ticket_denied_to_regular_customer(self):
        self.client.force_authenticate(user=self.customer_a)
        response = self.client.post('/api/events/ticket/', format='json')
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_sse_ticket_granted_to_superadmin_and_single_use(self):
        self.client.force_authenticate(user=self.super_admin_user)
        response = self.client.post('/api/events/ticket/', format='json')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        ticket = response.json().get('ticket')
        self.assertTrue(bool(ticket))

        # Check ticket exists in cache
        cache_key = f"sse_ticket_{ticket}"
        self.assertIsNotNone(cache.get(cache_key))

        # Authenticate via ticket
        from accounts.realtime_views import _authenticate_sse_request
        from django.test import RequestFactory
        factory = RequestFactory()
        req = factory.get(f'/api/events/stream/?ticket={ticket}')
        user, profile = _authenticate_sse_request(req)
        self.assertEqual(user.id, self.super_admin_user.id)

        # Single-use: Calling again must fail as ticket has been consumed
        user2, profile2 = _authenticate_sse_request(req)
        self.assertIsNone(user2)

    def test_sse_polling_scope_isolation_prevents_admin_leakage(self):
        # Create an admin-only event and a franchise event
        SystemEvent.objects.create(
            event_type='admin.security_alert',
            payload={'alert': 'Internal sensitive audit log'},
            target_scope='admin'
        )
        SystemEvent.objects.create(
            event_type='order.created',
            payload={'order_id': 1},
            target_scope='franchise',
            franchise_id=self.franchise_profile.id
        )

        self.client.force_authenticate(user=self.franchise_user)
        response = self.client.get('/api/events/latest/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        events = response.json().get('events', [])

        event_types = [e['event_type'] for e in events]
        self.assertNotIn('admin.security_alert', event_types)
        self.assertIn('order.created', event_types)

    # -------------------------------------------------------------
    # P1: KYC DOCUMENT FILE VALIDATION
    # -------------------------------------------------------------
    def test_kyc_upload_rejects_executable_extension(self):
        self.client.force_authenticate(user=self.franchise_user)
        fake_exe = SimpleUploadedFile("malicious.exe", b"MZ_binary_content", content_type="application/octet-stream")
        response = self.client.post(
            f'/api/accounts/dealers/{self.franchise_profile.id}/documents/',
            data={
                'document_type': 'AADHAAR',
                'document_number': '123456789012',
                'document_file': fake_exe
            },
            format='multipart'
        )
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('Invalid file type', response.json().get('message', ''))

    def test_kyc_upload_rejects_oversized_file(self):
        self.client.force_authenticate(user=self.franchise_user)
        # Create actual payload > 10MB
        oversized_data = b"0" * (10 * 1024 * 1024 + 512)
        oversized_file = SimpleUploadedFile("large_scan.pdf", oversized_data, content_type="application/pdf")
        response = self.client.post(
            f'/api/accounts/dealers/{self.franchise_profile.id}/documents/',
            data={
                'document_type': 'AADHAAR',
                'document_number': '123456789012',
                'document_file': oversized_file
            },
            format='multipart'
        )
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('exceeds maximum allowed limit', response.json().get('message', ''))

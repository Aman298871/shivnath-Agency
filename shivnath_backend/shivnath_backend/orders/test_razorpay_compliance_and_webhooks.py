import hashlib
import hmac
import json
import os
import uuid
from decimal import Decimal
from django.contrib.auth import get_user_model
from django.test import TestCase
from rest_framework import status
from rest_framework.test import APIClient

from accounts.models import UserProfile
from billing.models import Invoice, PaymentTransaction
from orders.models import Order
from products.models import Product

User = get_user_model()


class RazorpayComplianceAndWebhookTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.user = User.objects.create_user(
            username='rzp_compliance_cust',
            password='TestPassword@123',
            email='rzp_cust@example.com'
        )
        self.profile = getattr(self.user, 'profile', None)
        if not self.profile:
            self.profile = UserProfile.objects.create(user=self.user, role='customer', phone='9876543210')
        else:
            self.profile.role = 'customer'
            self.profile.phone = '9876543210'
            self.profile.save()
        self.client.force_authenticate(user=self.user)

        self.product = Product.objects.create(
            name='WaterNow 20L Jar',
            sku='SHV-20L-TEST',
            price=Decimal('80.00'),
            size='20 Litre',
            volume_ml=20000,
            status='Active'
        )

        self.order = Order.objects.create(
            created_by=self.user,
            amount=Decimal('160.00'),
            grand_total=Decimal('160.00'),
            status='Order Placement',
            payment_status='pending',
            payment_mode='RAZORPAY',
        )

    def test_01_create_order_authoritative_amount_and_currency(self):
        """Authoritative server-side order creation strictly enforces INR and total amount."""
        res = self.client.post('/api/orders/razorpay/create-order/', {
            'order_id': self.order.id,
            'amount': 160.0,
            'currency': 'INR'
        })
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertTrue(res.data.get('success'))
        self.assertEqual(res.data.get('currency'), 'INR')
        self.assertEqual(res.data.get('amount_in_paise'), 16000)
        self.assertTrue(res.data.get('is_test_mode'))

    def test_02_amount_tampering_rejected(self):
        """If client attempts to pay ₹10 instead of ₹160, server rejects with HTTP 400."""
        res = self.client.post('/api/orders/razorpay/create-order/', {
            'order_id': self.order.id,
            'amount': 10.0,
            'currency': 'INR'
        })
        self.assertEqual(res.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertFalse(res.data.get('success'))
        self.assertIn('tampering', res.data.get('message', '').lower())

    def test_03_invalid_currency_rejected(self):
        """Currencies other than INR are rejected."""
        res = self.client.post('/api/orders/razorpay/create-order/', {
            'order_id': self.order.id,
            'amount': 160.0,
            'currency': 'USD'
        })
        self.assertEqual(res.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('INR currency is supported', res.data.get('message', ''))

    def test_04_configuration_safeguard_prevents_test_keys_in_live_env(self):
        """Configuration safeguard stops test key from accepting payments in LIVE mode."""
        old_env = os.environ.get('RAZORPAY_ENVIRONMENT')
        old_key = os.environ.get('RAZORPAY_KEY_ID')
        try:
            os.environ['RAZORPAY_ENVIRONMENT'] = 'LIVE'
            os.environ['RAZORPAY_KEY_ID'] = 'rzp_test_invalid_in_live'
            res = self.client.post('/api/orders/razorpay/create-order/', {
                'order_id': self.order.id,
                'amount': 160.0
            })
            self.assertEqual(res.status_code, status.HTTP_500_INTERNAL_SERVER_ERROR)
            self.assertIn('Test Key detected', res.data.get('message', ''))
        finally:
            if old_env:
                os.environ['RAZORPAY_ENVIRONMENT'] = old_env
            else:
                os.environ.pop('RAZORPAY_ENVIRONMENT', None)
            if old_key:
                os.environ['RAZORPAY_KEY_ID'] = old_key
            else:
                os.environ.pop('RAZORPAY_KEY_ID', None)

    def test_05_signature_verification_success_and_idempotency(self):
        """Verifies HMAC signature, updates invoice & order atomically, and handles retries idempotently."""
        secret = 'test_secret_123456789'
        old_secret = os.environ.get('RAZORPAY_KEY_SECRET')
        try:
            os.environ['RAZORPAY_KEY_SECRET'] = secret
            order_id_rzp = 'order_test_123'
            payment_id_rzp = 'pay_test_456'
            msg = f"{order_id_rzp}|{payment_id_rzp}".encode('utf-8')
            valid_sig = hmac.new(secret.encode('utf-8'), msg, hashlib.sha256).hexdigest()

            # First verify call -> SUCCESS
            res1 = self.client.post('/api/orders/razorpay/verify-payment/', {
                'order_id': self.order.id,
                'razorpay_order_id': order_id_rzp,
                'razorpay_payment_id': payment_id_rzp,
                'razorpay_signature': valid_sig,
            })
            self.assertEqual(res1.status_code, status.HTTP_200_OK)
            self.assertTrue(res1.data.get('success'))

            self.order.refresh_from_db()
            self.assertEqual(self.order.payment_status, 'paid')
            self.assertEqual(self.order.razorpay_payment_id, payment_id_rzp)

            txns = PaymentTransaction.objects.filter(reference_number=payment_id_rzp)
            self.assertEqual(txns.count(), 1)

            # Second verify call (retry/duplicate callback) -> IDEMPOTENT 200 without duplicate TXN
            res2 = self.client.post('/api/orders/razorpay/verify-payment/', {
                'order_id': self.order.id,
                'razorpay_order_id': order_id_rzp,
                'razorpay_payment_id': payment_id_rzp,
                'razorpay_signature': valid_sig,
            })
            self.assertEqual(res2.status_code, status.HTTP_200_OK)
            self.assertIn('already verified', res2.data.get('message', '').lower())
            self.assertEqual(PaymentTransaction.objects.filter(reference_number=payment_id_rzp).count(), 1)
        finally:
            if old_secret:
                os.environ['RAZORPAY_KEY_SECRET'] = old_secret
            else:
                os.environ.pop('RAZORPAY_KEY_SECRET', None)

    def test_06_signature_verification_failure_rejected(self):
        """Invalid cryptographic signature is rejected with HTTP 400."""
        secret = 'test_secret_123456789'
        old_secret = os.environ.get('RAZORPAY_KEY_SECRET')
        try:
            os.environ['RAZORPAY_KEY_SECRET'] = secret
            res = self.client.post('/api/orders/razorpay/verify-payment/', {
                'order_id': self.order.id,
                'razorpay_order_id': 'order_test_123',
                'razorpay_payment_id': 'pay_test_456',
                'razorpay_signature': 'tampered_invalid_signature',
            })
            self.assertEqual(res.status_code, status.HTTP_400_BAD_REQUEST)
            self.assertFalse(res.data.get('success'))
            self.assertEqual(res.data.get('error_code'), 'SIGNATURE_VERIFICATION_FAILED')
        finally:
            if old_secret:
                os.environ['RAZORPAY_KEY_SECRET'] = old_secret
            else:
                os.environ.pop('RAZORPAY_KEY_SECRET', None)

    def test_07_webhook_captured_event_handling(self):
        """Asynchronous Razorpay webhook marks order paid idempotently with signature verification."""
        wh_secret = 'wh_secret_test_abc'
        old_wh = os.environ.get('RAZORPAY_WEBHOOK_SECRET')
        try:
            os.environ['RAZORPAY_WEBHOOK_SECRET'] = wh_secret
            self.order.razorpay_order_id = 'order_wh_test_999'
            self.order.save(update_fields=['razorpay_order_id'])

            payload = {
                'event': 'payment.captured',
                'payload': {
                    'payment': {
                        'entity': {
                            'id': 'pay_wh_captured_111',
                            'order_id': 'order_wh_test_999',
                            'amount': 16000,
                            'status': 'captured',
                        }
                    }
                }
            }
            raw_body = json.dumps(payload).encode('utf-8')
            signature = hmac.new(wh_secret.encode('utf-8'), raw_body, hashlib.sha256).hexdigest()

            res = self.client.post(
                '/api/orders/razorpay/webhook/',
                data=raw_body,
                content_type='application/json',
                HTTP_X_RAZORPAY_SIGNATURE=signature
            )
            self.assertEqual(res.status_code, status.HTTP_200_OK)
            self.assertEqual(res.data.get('status'), 'ok')

            self.order.refresh_from_db()
            self.assertEqual(self.order.payment_status, 'paid')
            self.assertEqual(self.order.razorpay_payment_id, 'pay_wh_captured_111')
        finally:
            if old_wh:
                os.environ['RAZORPAY_WEBHOOK_SECRET'] = old_wh
            else:
                os.environ.pop('RAZORPAY_WEBHOOK_SECRET', None)

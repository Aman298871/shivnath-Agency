import os
from decimal import Decimal
from django.test import TestCase
from django.contrib.auth.models import User
from rest_framework.test import APIClient
from rest_framework import status

from datetime import timedelta
from django.utils import timezone
from products.models import Product
from inventory.models import ProductionBatch
from orders.models import Order, OrderItem
from billing.models import Invoice, PaymentTransaction


class CustomerOrderRazorpayFlowTest(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.user = User.objects.create_user(
            username='cust_9827011223',
            email='cust@example.com',
            password='Password@123',
            first_name='Aman',
            last_name='Kumar'
        )
        self.product, _ = Product.objects.get_or_create(
            sku='SHV-20L-TEST',
            defaults={
                'name': 'Shivnath 20L Purity Jar',
                'size': '20L',
                'package_type': 'JAR',
                'price': Decimal('10.00'),
                'stock': 100,
                'category': 'Water Jars',
            }
        )
        self.product.stock = 100
        self.product.package_type = 'JAR'
        self.product.save(update_fields=['stock', 'package_type'])

        self.batch = ProductionBatch.objects.create(
            batch_number='PB-TEST-RZP-001',
            product=self.product,
            manufacture_date=timezone.now().date(),
            expiry_date=timezone.now().date() + timedelta(days=90),
            quantity_produced_units=1000,
            quantity_remaining_company=1000,
            reserved_quantity=0,
            unit_production_cost=Decimal('5.00'),
            status='ACTIVE'
        )

    def test_customer_cod_order_is_strictly_rejected(self):
        self.client.force_authenticate(user=self.user)
        response = self.client.post('/api/orders/', {
            'customer_name': 'Aman Kumar',
            'phone': '9827011223',
            'delivery_address': 'Pandri, Raipur',
            'amount': 50.00,
            'items': 5,
            'payment_mode': 'COD',
            'order_items': [
                {'product_id': self.product.id, 'quantity': 5, 'price': 10.00}
            ]
        }, format='json')

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertFalse(response.data.get('success'))
        self.assertEqual(response.data.get('error_code'), 'COD_NOT_ALLOWED')

    def test_customer_razorpay_order_create_and_verify_pipeline(self):
        self.client.force_authenticate(user=self.user)
        
        # 1. Place order with RAZORPAY
        order_res = self.client.post('/api/orders/', {
            'customer_name': 'Aman Kumar',
            'phone': '9827011223',
            'delivery_address': 'Pandri, Raipur',
            'amount': 50.00,
            'items': 5,
            'payment_mode': 'RAZORPAY',
            'order_items': [
                {'product_id': self.product.id, 'quantity': 5, 'price': 10.00}
            ]
        }, format='json')

        self.assertEqual(order_res.status_code, status.HTTP_201_CREATED)
        order_id = order_res.data.get('id')
        self.assertTrue(order_id > 0)

        # 2. Initialize Razorpay Order
        created_order = Order.objects.get(id=order_id)
        authoritative_total = float(created_order.grand_total or created_order.amount)
        rzp_create_res = self.client.post('/api/orders/razorpay/create-order/', {
            'order_id': order_id,
            'amount': authoritative_total
        }, format='json')

        self.assertEqual(rzp_create_res.status_code, status.HTTP_200_OK)
        rzp_order_id = rzp_create_res.data.get('razorpay_order_id')
        self.assertTrue(rzp_order_id.startswith('order_'))

        # 3. Server-side payment verification
        import hmac
        import hashlib
        from orders.views import get_razorpay_credentials
        _, key_secret, _, _ = get_razorpay_credentials()
        secret = key_secret or 'test_secret_key'
        payment_id_rzp = 'pay_test_razorpay_12345'
        msg = f"{rzp_order_id}|{payment_id_rzp}".encode('utf-8')
        valid_sig = hmac.new(secret.encode('utf-8'), msg, hashlib.sha256).hexdigest()

        verify_res = self.client.post('/api/orders/razorpay/verify-payment/', {
            'order_id': order_id,
            'razorpay_order_id': rzp_order_id,
            'razorpay_payment_id': payment_id_rzp,
            'razorpay_signature': valid_sig,
        }, format='json')

        self.assertEqual(verify_res.status_code, status.HTTP_200_OK)
        self.assertTrue(verify_res.data.get('success'))
        
        # Verify authoritative DB state
        order = Order.objects.get(id=order_id)
        self.assertEqual(order.payment_status, 'paid')
        self.assertEqual(order.payment_mode, 'RAZORPAY')
        self.assertEqual(order.razorpay_payment_id, 'pay_test_razorpay_12345')

        # Verify Invoice & PaymentTransaction
        inv = order.invoice
        self.assertIsNotNone(inv)
        self.assertEqual(inv.status, 'PAID')
        self.assertTrue(inv.payments.filter(payment_method='RAZORPAY').exists())

        # 4. Verify historical order details remain visible even if product stock reaches 0
        self.product.stock = 0
        self.product.save()

        get_res = self.client.get(f'/api/orders/{order_id}/')
        self.assertEqual(get_res.status_code, status.HTTP_200_OK)
        self.assertEqual(get_res.data.get('order', {}).get('payment_display'), 'Paid')
        self.assertIn('Razorpay', get_res.data.get('order', {}).get('payment_mode'))

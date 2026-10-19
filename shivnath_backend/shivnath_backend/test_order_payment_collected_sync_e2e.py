import json
from decimal import Decimal
from django.test import TestCase
from django.contrib.auth.models import User
from rest_framework.test import APIClient
from rest_framework import status

from accounts.models import UserProfile, FranchiseProfile
from products.models import Product, ProductCategory
from orders.models import Order, OrderItem
from orders.serializers import OrderSerializer
from billing.models import Invoice, PaymentTransaction


class OrderPaymentCollectedSyncE2ETest(TestCase):
    """
    End-to-End integration test suite verifying synchronization of order payment status,
    linked GST invoice, audit payment transactions, and Franchise app payment_collected state.
    """

    def setUp(self):
        self.client = APIClient()

        # 1. Admin User
        self.admin_user = User.objects.create_user(
            username='admin_test',
            email='admin@test.com',
            password='pass',
            is_staff=True
        )
        admin_profile, _ = UserProfile.objects.get_or_create(user=self.admin_user)
        admin_profile.role = 'admin'
        admin_profile.save()
        self.admin_user.refresh_from_db()

        # 2. Franchise User & Profile
        self.franchise_user = User.objects.create_user(
            username='franchise_test',
            email='franchise@test.com',
            password='pass'
        )
        franchise_profile, _ = UserProfile.objects.get_or_create(user=self.franchise_user)
        franchise_profile.role = 'franchise'
        franchise_profile.save()
        self.franchise = FranchiseProfile.objects.create(
            user=self.franchise_user,
            business_name='Shivnath Test Agency',
            dealer_code='STA-101',
            status='approved',
            city='Raipur'
        )
        self.franchise_user.refresh_from_db()

        # 3. Customer User
        self.customer_user = User.objects.create_user(
            username='customer_test',
            email='customer@test.com',
            password='pass'
        )
        cust_profile, _ = UserProfile.objects.get_or_create(user=self.customer_user)
        cust_profile.role = 'customer'
        cust_profile.save()

        # 4. Product
        self.category = ProductCategory.objects.create(name='Mineral Water')
        self.product = Product.objects.create(
            category='Jar',
            category_ref=self.category,
            name='Shivnath 20L Jar',
            sku='SN-JAR-20L',
            size='20L',
            price=Decimal('100.00'),
            gst=18
        )

    def _create_delivered_order(self):
        """Helper to create a delivered order with 1 item (grand_total = 118.00)."""
        order = Order.objects.create(
            created_by=self.customer_user,
            city='Raipur',
            delivery_address='123 Test Street, Raipur',
            serving_franchise=self.franchise,
            registered_franchise=self.franchise,
            status='delivered',
            payment_status='pending',
            amount=Decimal('100.00'),
            grand_total=Decimal('118.00'),
            tax_amount=Decimal('18.00'),
            payment_mode='CASH'
        )
        OrderItem.objects.create(
            order=order,
            product=self.product,
            product_name=self.product.name,
            quantity=1,
            unit_price=Decimal('100.00'),
            total_price=Decimal('100.00')
        )
        return order

    def test_01_delivered_order_initially_shows_unpaid_in_serializer_and_billing(self):
        """A delivered order before payment collection must not be assumed paid."""
        order = self._create_delivered_order()

        # Test serializer output
        serializer_data = OrderSerializer(order).data
        self.assertEqual(serializer_data['payment_status'], 'pending')
        self.assertFalse(serializer_data['payment_collected'])
        self.assertFalse(serializer_data['is_pending_verification'])
        self.assertEqual(serializer_data['amount_paid'], 0.0)
        self.assertEqual(serializer_data['outstanding_balance'], 118.0)

        # Test Franchise GET /api/billing/orders/<order_id>/payments/
        self.client.force_authenticate(user=self.franchise_user)
        res = self.client.get(f'/api/billing/orders/{order.id}/payments/')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertFalse(res.data['payment_collected'])
        self.assertEqual(res.data['outstanding_balance'], 118.0)
        self.assertEqual(res.data['amount_paid'], 0.0)
        self.assertFalse(res.data['is_pending_verification'])

    def test_02_admin_marks_payment_collected_syncs_order_invoice_and_transactions(self):
        """
        When Admin updates order payment to 'paid' (or 'collected'):
        - Order payment_status becomes 'paid'.
        - Linked Invoice is generated/updated with status='PAID' and amount_paid=grand_total.
        - PaymentTransaction is recorded with SUCCESS.
        - Franchise API and OrderSerializer return payment_collected=True, outstanding_balance=0.0.
        """
        order = self._create_delivered_order()

        # Admin calls PATCH /api/orders/<id>/ with payment='paid'
        self.client.force_authenticate(user=self.admin_user)
        patch_res = self.client.patch(
            f'/api/orders/{order.id}/',
            data={'payment': 'paid'},
            format='json'
        )
        self.assertEqual(patch_res.status_code, status.HTTP_200_OK)

        order.refresh_from_db()
        self.assertEqual(order.payment_status, 'paid')

        # Check linked invoice synchronization
        self.assertTrue(hasattr(order, 'invoice'))
        invoice = order.invoice
        self.assertIsNotNone(invoice)
        self.assertEqual(invoice.status, 'PAID')
        self.assertEqual(invoice.amount_paid, invoice.grand_total)
        self.assertEqual(invoice.outstanding_balance, Decimal('0.00'))

        # Check audit transaction created
        txns = PaymentTransaction.objects.filter(invoice=invoice)
        self.assertTrue(txns.exists())
        self.assertTrue(txns.filter(payment_status='SUCCESS').exists())

        # Check OrderSerializer reflects payment_collected=True and outstanding_balance=0.0
        ser_data = OrderSerializer(order).data
        self.assertTrue(ser_data['payment_collected'])
        self.assertFalse(ser_data['is_pending_verification'])
        self.assertEqual(ser_data['payment_status'], 'paid')
        self.assertEqual(ser_data['outstanding_balance'], 0.0)
        self.assertEqual(ser_data['amount_paid'], 118.0)
        self.assertEqual(ser_data['invoice_status'], 'PAID')

        # Check Franchise GET /api/billing/orders/<order_id>/payments/ reflects verified payment
        self.client.force_authenticate(user=self.franchise_user)
        res = self.client.get(f'/api/billing/orders/{order.id}/payments/')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertTrue(res.data['payment_collected'])
        self.assertEqual(res.data['payment_status'], 'PAID')
        self.assertEqual(res.data['outstanding_balance'], 0.0)
        self.assertEqual(res.data['amount_paid'], 118.0)
        self.assertFalse(res.data['is_pending_verification'])

    def test_03_franchise_records_payment_then_admin_verifies(self):
        """
        When Franchise reports payment collection via /api/billing/orders/<order_id>/payments/:
        - Transaction recorded with PENDING_VERIFICATION.
        - OrderSerializer and API return is_pending_verification=True, payment_collected=False.
        When Admin verifies payment via /api/billing/payments/<txn_id>/verify/:
        - Transaction becomes SUCCESS.
        - Invoice & order become PAID.
        - OrderSerializer and API return payment_collected=True, is_pending_verification=False.
        """
        order = self._create_delivered_order()

        # 1. Franchise records cash payment
        self.client.force_authenticate(user=self.franchise_user)
        record_res = self.client.post(
            f'/api/billing/orders/{order.id}/payments/',
            data={
                'payment_type': 'FULL',
                'payment_method': 'CASH',
                'notes': 'Collected cash from customer upon delivery'
            },
            format='json'
        )
        self.assertEqual(record_res.status_code, status.HTTP_201_CREATED)
        txn_id = record_res.data['transaction']['id']

        order.refresh_from_db()
        self.assertEqual(order.payment_status, 'pending')

        # Check Franchise payments endpoint
        f_res = self.client.get(f'/api/billing/orders/{order.id}/payments/')
        self.assertEqual(f_res.status_code, status.HTTP_200_OK)
        self.assertTrue(f_res.data['is_pending_verification'])
        self.assertFalse(f_res.data['payment_collected'])

        # Check OrderSerializer
        order = Order.objects.get(id=order.id)
        ser_data = OrderSerializer(order).data
        self.assertTrue(ser_data['is_pending_verification'])
        self.assertFalse(ser_data['payment_collected'])

        # 2. Admin verifies transaction
        self.client.force_authenticate(user=self.admin_user)
        verify_res = self.client.post(f'/api/billing/payments/{txn_id}/verify/', format='json')
        self.assertEqual(verify_res.status_code, status.HTTP_200_OK)

        order.refresh_from_db()
        self.assertEqual(order.payment_status, 'paid')

        # Re-check Franchise payments endpoint
        self.client.force_authenticate(user=self.franchise_user)
        f_res_after = self.client.get(f'/api/billing/orders/{order.id}/payments/')
        self.assertEqual(f_res_after.status_code, status.HTTP_200_OK)
        self.assertTrue(f_res_after.data['payment_collected'])
        self.assertFalse(f_res_after.data['is_pending_verification'])
        self.assertEqual(f_res_after.data['payment_status'], 'PAID')
        self.assertEqual(f_res_after.data['outstanding_balance'], 0.0)

        # Re-check OrderSerializer
        ser_data_after = OrderSerializer(order).data
        self.assertTrue(ser_data_after['payment_collected'])
        self.assertFalse(ser_data_after['is_pending_verification'])
        self.assertEqual(ser_data_after['payment_status'], 'paid')
        self.assertEqual(ser_data_after['outstanding_balance'], 0.0)

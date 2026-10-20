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
    End-to-End integration test suite verifying the franchise payment collection workflow:
    - Franchise fulfills assigned order and collects cash/UPI directly from the customer.
    - Admin is NOT required to individually verify every order's customer payment.
    - Full payment immediately reflects PAYMENT COLLECTED.
    - Partial payment immediately reflects amount received and remaining payable balance.
    - Overpayment is validated and rejected.
    - Duplicate submission protection prevents concurrent double-charging.
    - Unauthorized access is blocked.
    - Admin dashboard summary aggregates franchise collections by date, mode, outstanding dues, and exceptions.
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

        # 3. Other Franchise User (for permission isolation tests)
        self.other_franchise_user = User.objects.create_user(
            username='other_franchise_test',
            email='other@test.com',
            password='pass'
        )
        other_profile, _ = UserProfile.objects.get_or_create(user=self.other_franchise_user)
        other_profile.role = 'franchise'
        other_profile.save()
        self.other_franchise = FranchiseProfile.objects.create(
            user=self.other_franchise_user,
            business_name='Other Agency',
            dealer_code='STA-102',
            status='approved',
            city='Bhilai'
        )

        # 4. Customer User
        self.customer_user = User.objects.create_user(
            username='customer_test',
            email='customer@test.com',
            password='pass'
        )
        cust_profile, _ = UserProfile.objects.get_or_create(user=self.customer_user)
        cust_profile.role = 'customer'
        cust_profile.save()

        # 5. Product
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

    def _create_delivered_order(self, base_amount=Decimal('100.00'), tax_amount=Decimal('18.00')):
        """Helper to create a delivered order with 1 item."""
        grand_total = base_amount + tax_amount
        order = Order.objects.create(
            created_by=self.customer_user,
            city='Raipur',
            delivery_address='123 Test Street, Raipur',
            serving_franchise=self.franchise,
            registered_franchise=self.franchise,
            status='delivered',
            payment_status='pending',
            amount=base_amount,
            grand_total=grand_total,
            tax_amount=tax_amount,
            payment_mode='CASH'
        )
        OrderItem.objects.create(
            order=order,
            product=self.product,
            product_name=self.product.name,
            quantity=1,
            unit_price=base_amount,
            total_price=base_amount
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

    def test_02_franchise_records_full_cash_collection_immediately_settles_without_admin_gate(self):
        """
        Franchise records full cash collection from customer:
        - Settles immediately with payment_status='paid' and payment_collected=True.
        - No Admin verification bottleneck required.
        - Linked Invoice becomes PAID and amount_paid=grand_total.
        - PaymentTransaction is recorded with SUCCESS and marked [FRANCHISE_COLLECTED].
        """
        order = self._create_delivered_order()

        self.client.force_authenticate(user=self.franchise_user)
        record_res = self.client.post(
            f'/api/billing/orders/{order.id}/payments/',
            data={
                'payment_type': 'FULL',
                'payment_method': 'CASH',
                'amount': 118.00,
                'notes': 'Collected full cash at customer doorstep'
            },
            format='json'
        )
        self.assertEqual(record_res.status_code, status.HTTP_201_CREATED)
        self.assertTrue(record_res.data['success'])
        self.assertTrue(record_res.data['data']['payment_collected'])
        self.assertFalse(record_res.data['data']['is_pending_verification'])
        self.assertEqual(record_res.data['data']['amount_paid'], 118.0)
        self.assertEqual(record_res.data['data']['outstanding_balance'], 0.0)

        order.refresh_from_db()
        self.assertEqual(order.payment_status, 'paid')

        # Check linked invoice synchronization
        invoice = order.invoice
        self.assertIsNotNone(invoice)
        self.assertEqual(invoice.status, 'PAID')
        self.assertEqual(invoice.amount_paid, Decimal('118.00'))
        self.assertEqual(invoice.outstanding_balance, Decimal('0.00'))

        # Check audit transaction created with SUCCESS and franchise note
        txns = PaymentTransaction.objects.filter(invoice=invoice)
        self.assertTrue(txns.filter(payment_status='SUCCESS').exists())
        last_txn = txns.last()
        self.assertIn('[FRANCHISE_COLLECTED]', last_txn.notes)
        self.assertIn('COLLECTED_BY:franchise_test', last_txn.notes)

        # Check OrderSerializer reflects payment_collected=True, outstanding_balance=0.0
        ser_data = OrderSerializer(order).data
        self.assertTrue(ser_data['payment_collected'])
        self.assertFalse(ser_data['is_pending_verification'])
        self.assertEqual(ser_data['payment_status'], 'paid')
        self.assertEqual(ser_data['outstanding_balance'], 0.0)
        self.assertEqual(ser_data['amount_paid'], 118.0)

    def test_03_franchise_records_partial_collection_and_balance_tracking(self):
        """
        Franchise records partial customer payment:
        - First collection: ₹50.00 of ₹118.00 -> remaining ₹68.00.
        - Order payment_status='partial', invoice status='PARTIALLY_PAID'.
        - Second collection: ₹68.00 -> fully clears balance.
        """
        order = self._create_delivered_order()

        self.client.force_authenticate(user=self.franchise_user)

        # 1. Partial payment: ₹50.00
        res1 = self.client.post(
            f'/api/billing/orders/{order.id}/payments/',
            data={
                'payment_type': 'PARTIAL',
                'payment_method': 'UPI',
                'amount': 50.00,
                'reference_number': 'UPI-REF-001',
                'notes': 'Partial payment via UPI'
            },
            format='json'
        )
        self.assertEqual(res1.status_code, status.HTTP_201_CREATED)
        self.assertFalse(res1.data['data']['payment_collected'])
        self.assertEqual(res1.data['data']['amount_paid'], 50.0)
        self.assertEqual(res1.data['data']['outstanding_balance'], 68.0)

        order.refresh_from_db()
        self.assertEqual(order.payment_status, 'partial')

        # Check GET /api/billing/orders/<id>/payments/ reflects partial state
        get_res1 = self.client.get(f'/api/billing/orders/{order.id}/payments/')
        self.assertEqual(get_res1.data['payment_status'], 'PARTIALLY_PAID')
        self.assertFalse(get_res1.data['payment_collected'])
        self.assertEqual(get_res1.data['amount_paid'], 50.0)
        self.assertEqual(get_res1.data['outstanding_balance'], 68.0)

        # 2. Complete remaining balance: ₹68.00
        res2 = self.client.post(
            f'/api/billing/orders/{order.id}/payments/',
            data={
                'payment_type': 'FULL',
                'payment_method': 'CASH',
                'amount': 68.00,
                'notes': 'Remaining balance cleared in cash'
            },
            format='json'
        )
        self.assertEqual(res2.status_code, status.HTTP_201_CREATED)
        self.assertTrue(res2.data['data']['payment_collected'])
        self.assertEqual(res2.data['data']['amount_paid'], 118.0)
        self.assertEqual(res2.data['data']['outstanding_balance'], 0.0)

        order.refresh_from_db()
        self.assertEqual(order.payment_status, 'paid')
        self.assertEqual(order.invoice.status, 'PAID')

    def test_04_overpayment_validation_rejected(self):
        """Payment amount exceeding remaining payable balance must be rejected with HTTP 400."""
        order = self._create_delivered_order()

        self.client.force_authenticate(user=self.franchise_user)
        res = self.client.post(
            f'/api/billing/orders/{order.id}/payments/',
            data={
                'payment_type': 'PARTIAL',
                'payment_method': 'CASH',
                'amount': 200.00,  # exceeds 118.00
            },
            format='json'
        )
        self.assertEqual(res.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('exceeds', res.data['message'].lower())

    def test_05_duplicate_submission_protection(self):
        """Concurrent or duplicate submit with identical amount and reference is rejected."""
        order = self._create_delivered_order()

        self.client.force_authenticate(user=self.franchise_user)
        payload = {
            'payment_type': 'PARTIAL',
            'payment_method': 'UPI',
            'amount': 40.00,
            'reference_number': 'UPI-DUP-1234',
            'notes': 'Doorstep UPI scan'
        }

        # First submission succeeds
        res1 = self.client.post(f'/api/billing/orders/{order.id}/payments/', data=payload, format='json')
        self.assertEqual(res1.status_code, status.HTTP_201_CREATED)

        # Immediate duplicate submission is rejected
        res2 = self.client.post(f'/api/billing/orders/{order.id}/payments/', data=payload, format='json')
        self.assertEqual(res2.status_code, status.HTTP_409_CONFLICT)
        self.assertIn('duplicate', res2.data['message'].lower())

    def test_06_unauthorized_franchise_cannot_record_collection(self):
        """Franchise B cannot record payment on an order assigned exclusively to Franchise A."""
        order = self._create_delivered_order()

        self.client.force_authenticate(user=self.other_franchise_user)
        res = self.client.post(
            f'/api/billing/orders/{order.id}/payments/',
            data={
                'payment_type': 'FULL',
                'payment_method': 'CASH',
                'amount': 118.00,
            },
            format='json'
        )
        self.assertEqual(res.status_code, status.HTTP_403_FORBIDDEN)

    def test_07_persisted_state_after_refresh_and_polling(self):
        """Franchise UI polling/refreshing must return authoritative backend state without reverting."""
        order = self._create_delivered_order()

        self.client.force_authenticate(user=self.franchise_user)
        # Record collection
        self.client.post(
            f'/api/billing/orders/{order.id}/payments/',
            data={'payment_type': 'FULL', 'payment_method': 'CASH', 'amount': 118.00},
            format='json'
        )

        # Multiple subsequent GET calls must remain consistently PAID
        for _ in range(3):
            res = self.client.get(f'/api/billing/orders/{order.id}/payments/')
            self.assertEqual(res.status_code, status.HTTP_200_OK)
            self.assertTrue(res.data['payment_collected'])
            self.assertEqual(res.data['payment_status'], 'PAID')
            self.assertEqual(res.data['outstanding_balance'], 0.0)
            self.assertFalse(res.data['is_pending_verification'])

    def test_08_franchise_collections_summary_for_admin_dashboard(self):
        """Admin collections summary endpoint aggregates collections by date, mode, outstanding, and exceptions."""
        order1 = self._create_delivered_order(base_amount=Decimal('100.00'), tax_amount=Decimal('18.00'))
        order2 = self._create_delivered_order(base_amount=Decimal('50.00'), tax_amount=Decimal('9.00'))

        # Franchise collects order1 full in Cash, order2 partial in UPI
        self.client.force_authenticate(user=self.franchise_user)
        self.client.post(
            f'/api/billing/orders/{order1.id}/payments/',
            data={'payment_type': 'FULL', 'payment_method': 'CASH', 'amount': 118.00},
            format='json'
        )
        self.client.post(
            f'/api/billing/orders/{order2.id}/payments/',
            data={'payment_type': 'PARTIAL', 'payment_method': 'UPI', 'amount': 30.00},
            format='json'
        )

        # Admin fetches collections summary
        self.client.force_authenticate(user=self.admin_user)
        summary_res = self.client.get('/api/billing/franchise-collections/summary/')
        self.assertEqual(summary_res.status_code, status.HTTP_200_OK)
        self.assertTrue(summary_res.data['success'])

        data = summary_res.data['data']
        self.assertEqual(data['summary']['total_transactions_in_period'], 2)
        self.assertEqual(data['summary']['total_collected_in_period'], 148.0)  # 118 + 30
        self.assertEqual(data['by_mode']['cash'], 118.0)
        self.assertEqual(data['by_mode']['upi'], 30.0)
        self.assertGreaterEqual(data['summary']['total_customer_outstanding'], 29.0)  # remaining on order2
        self.assertEqual(len(data['recent_collections']), 2)

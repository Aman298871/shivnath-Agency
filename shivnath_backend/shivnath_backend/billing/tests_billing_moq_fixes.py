import datetime
from decimal import Decimal
from django.test import TestCase
from django.contrib.auth.models import User
from django.urls import reverse
from rest_framework.test import APIClient
from rest_framework import status

from accounts.models import UserProfile, FranchiseProfile, ServiceZone, ServiceDistrict
from products.models import Product, ProductCategory, MinimumOrderPackagingRule
from orders.models import Order, OrderItem
from billing.models import Invoice, PaymentTransaction, CompanyBillingProfile
from billing.services import generate_invoice_for_order, record_payment_transaction
from products.packaging_services import validate_order_item_packaging, get_product_moq_info


class BillingAndMOQFixesTests(TestCase):
    def setUp(self):
        self.client = APIClient()

        # Company profile
        self.company_profile, _ = CompanyBillingProfile.objects.get_or_create(
            legal_name="Shivnath Agency",
            gstin="22AAAAA0000A1Z5",
            state_name="Chhattisgarh",
            state_code="22",
            cgst_rate=Decimal("9.00"),
            sgst_rate=Decimal("9.00"),
            is_configured=True,
        )

        # Users
        self.admin = User.objects.create_superuser('admin_user', 'admin@shivnath.com', 'pass123')
        self.customer1 = User.objects.create_user('cust1', 'cust1@example.com', 'pass123', first_name='Rohan', last_name='Patel')
        prof1, _ = UserProfile.objects.get_or_create(user=self.customer1)
        prof1.role = 'customer'
        prof1.phone = '9876543210'
        prof1.city = 'Raipur'
        prof1.save()

        self.customer2 = User.objects.create_user('cust2', 'cust2@example.com', 'pass123', first_name='Pooja', last_name='Sharma')
        prof2, _ = UserProfile.objects.get_or_create(user=self.customer2)
        prof2.role = 'customer'
        prof2.phone = '9876543211'
        prof2.city = 'Bhilai'
        prof2.save()

        self.franchise_user = User.objects.create_user('fran_user', 'fran@example.com', 'pass123')
        prof_f, _ = UserProfile.objects.get_or_create(user=self.franchise_user)
        prof_f.role = 'franchise'
        prof_f.phone = '9876543212'
        prof_f.save()
        self.district, _ = ServiceDistrict.objects.get_or_create(name='Raipur', state='Chhattisgarh')
        self.zone, _ = ServiceZone.objects.get_or_create(name='Raipur Central', district=self.district)

        self.franchise = FranchiseProfile.objects.create(
            user=self.franchise_user,
            business_name='Sangam Franchise Agency',
            dealer_code='DLR-SANGAM-001',
            city='Raipur',
            address='Station Road Raipur',
            status='approved',
        )

        from billing.models import DeliveryOriginSetting
        DeliveryOriginSetting.objects.get_or_create(
            is_active=True,
            defaults={
                'name': 'Shivnath Central Dispatch Hub',
                'address': 'Ekta Nagar, Pragati Nagar, LIC Colony, near Mowa Thana, Raipur, Chhattisgarh',
                'latitude': Decimal('21.267800'),
                'longitude': Decimal('81.671100'),
            }
        )

        # Products
        self.cat_water, _ = ProductCategory.objects.get_or_create(name='Water')
        self.jar_product = Product.objects.create(
            name='Shivnath 20L Water Jar',
            sku='SHV-20L-JAR',
            category='Water',
            category_ref=self.cat_water,
            package_type='JAR',
            size='20L',
            price=Decimal('70.00'),
            dealer_transfer_price=Decimal('50.00'),
            stock=500,
            units_per_case=1,
            status='Active',
        )

        self.bottle_product = Product.objects.create(
            name='Shivnath 500ml Bottled Water (Box of 24)',
            sku='SHV-500ML-BOT',
            category='Water',
            category_ref=self.cat_water,
            package_type='BOTTLE',
            size='500ml',
            price=Decimal('10.00'),
            dealer_transfer_price=Decimal('8.00'),
            stock=1000,
            units_per_case=24,
            status='Active',
        )

        from datetime import date, timedelta
        from inventory.models import ProductionBatch, DealerStockBatch
        ProductionBatch.objects.create(
            batch_number='BATCH-MOQ-FIXES-01',
            product=self.jar_product,
            manufacture_date=date.today(),
            expiry_date=date.today() + timedelta(days=180),
            quantity_produced_units=1000,
            quantity_remaining_company=1000,
            status='ACTIVE',
        )
        ProductionBatch.objects.create(
            batch_number='BATCH-MOQ-FIXES-02',
            product=self.bottle_product,
            manufacture_date=date.today(),
            expiry_date=date.today() + timedelta(days=180),
            quantity_produced_units=2000,
            quantity_remaining_company=2000,
            status='ACTIVE',
        )
        DealerStockBatch.objects.create(
            dealer=self.franchise,
            product=self.jar_product,
            batch_number='DLR-BATCH-01',
            manufacture_date=date.today(),
            expiry_date=date.today() + timedelta(days=180),
            received_quantity=500,
            remaining_quantity=500,
            is_active=True,
        )
        DealerStockBatch.objects.create(
            dealer=self.franchise,
            product=self.bottle_product,
            batch_number='DLR-BATCH-02',
            manufacture_date=date.today(),
            expiry_date=date.today() + timedelta(days=180),
            received_quantity=1000,
            remaining_quantity=1000,
            is_active=True,
        )

    # ---------------------------------------------------------
    # P0-4 / P0-5: MOQ Validation Tests
    # ---------------------------------------------------------
    def test_moq_jar_rejection_for_1_to_4(self):
        """1-4 eligible jars must be rejected across all ordering paths."""
        for qty in [1, 2, 3, 4]:
            with self.assertRaises(Exception):
                validate_order_item_packaging(self.jar_product, qty, channel='CUSTOMER')

    def test_moq_jar_acceptance_at_5(self):
        """5 jars must pass quantity validation."""
        result = validate_order_item_packaging(self.jar_product, 5, channel='CUSTOMER')
        self.assertTrue(result['is_valid'])
        self.assertEqual(result['quantity'], 5)

    def test_moq_bottle_boxes_rejection_for_under_5_boxes(self):
        """Fewer than 5 configured boxes must be rejected (e.g. 1-4 boxes = 24-96 bottles)."""
        upc = self.bottle_product.units_per_case # 24
        for boxes in [1, 2, 3, 4]:
            qty = boxes * upc
            with self.assertRaises(Exception):
                validate_order_item_packaging(self.bottle_product, qty, channel='CUSTOMER')

    def test_moq_bottle_boxes_rejection_for_loose_bottles(self):
        """Loose bottles (not a full carton multiple) must be rejected."""
        with self.assertRaises(Exception):
            validate_order_item_packaging(self.bottle_product, 25, channel='CUSTOMER')

    def test_moq_bottle_boxes_acceptance_at_5_boxes(self):
        """5 configured bottle boxes (120 bottles) must pass validation."""
        qty = 5 * self.bottle_product.units_per_case
        result = validate_order_item_packaging(self.bottle_product, qty, channel='CUSTOMER')
        self.assertTrue(result['is_valid'])
        self.assertEqual(result['carton_count'], 5.0)

    # ---------------------------------------------------------
    # P0-3: Direct vs Franchise Attribution Tests
    # ---------------------------------------------------------
    def test_direct_shivnath_order_has_no_false_franchise_attribution(self):
        """Direct Shivnath orders must not have a serving franchise or display customer as franchise."""
        self.client.force_authenticate(user=self.admin)
        res = self.client.post('/api/orders/', {
            'order_source': 'DIRECT_COMPANY',
            'product_id': self.jar_product.id,
            'items_count': 5,
            'client_name': 'Rohan Patel',
            'city': 'Raipur',
            'delivery_address': 'Central Plant Raipur',
            'payment_mode': 'ONLINE',
            'payment_status': 'paid',
        }, format='json')

        self.assertEqual(res.status_code, status.HTTP_201_CREATED, res.data)
        order_id = res.data['id']
        order = Order.objects.get(id=order_id)

        self.assertEqual(order.order_source, 'DIRECT_COMPANY')
        self.assertIsNone(order.serving_franchise)
        self.assertIn('Shivnath', order.franchise_name)

        # Check billing serializer
        inv = Invoice.objects.filter(order=order).first()
        self.assertIsNotNone(inv)
        from billing.serializers import InvoiceSerializer
        ser = InvoiceSerializer(inv).data
        self.assertIsNone(ser['franchise_name'])
        self.assertEqual(ser['order_source'], 'DIRECT_COMPANY')
        self.assertNotEqual(ser['franchise_name'], 'Rohan Patel')

    def test_franchise_assisted_order_records_correct_franchise(self):
        """Franchise assisted orders record the authoritative franchise."""
        self.client.force_authenticate(user=self.customer1)
        res = self.client.post('/api/orders/', {
            'order_source': 'FRANCHISE',
            'serving_franchise_id': self.franchise.id,
            'product_id': self.jar_product.id,
            'items_count': 5,
            'city': 'Raipur',
            'delivery_address': 'Sector 4 Raipur',
            'payment_mode': 'FRANCHISE_COLLECTION',
        }, format='json')

        self.assertEqual(res.status_code, status.HTTP_201_CREATED, res.data)
        order_id = res.data['id']
        order = Order.objects.get(id=order_id)

        self.assertEqual(order.order_source, 'FRANCHISE')
        self.assertEqual(order.serving_franchise_id, self.franchise.id)

        inv = Invoice.objects.filter(order=order).first()
        from billing.serializers import InvoiceSerializer
        ser = InvoiceSerializer(inv).data
        self.assertEqual(ser['franchise_name'], 'Sangam Franchise Agency')

    # ---------------------------------------------------------
    # P0-1 & P0-2: Invoice Generation & Payment Reconciliation
    # ---------------------------------------------------------
    def test_full_payment_yields_consistent_paid_status(self):
        """Full payment yields amount_paid == grand_total, outstanding == 0, and status == PAID (never Partial)."""
        order = Order.objects.create(
            created_by=self.customer1,
            franchise_name='Sangam Franchise Agency',
            serving_franchise=self.franchise,
            order_source='FRANCHISE',
            city='Raipur',
            amount=Decimal('460.00'),
            grand_total=Decimal('460.00'),
            items_count=5,
            payment_status='partial', # simulate older stale order status
        )
        inv = generate_invoice_for_order(order)
        gt = inv.grand_total

        # Record payment of full grand total
        record_payment_transaction(
            invoice_id=inv.id,
            amount_paid=gt,
            payment_method='CASH',
            actor=self.admin,
        )

        inv.refresh_from_db()
        order.refresh_from_db()

        self.assertEqual(inv.amount_paid, gt)
        self.assertEqual(inv.outstanding_balance, Decimal('0.00'))
        self.assertEqual(inv.status, 'PAID')
        self.assertEqual(order.payment_status, 'paid')

        # Re-run generate_invoice_for_order to test idempotency and status reconciliation
        inv2 = generate_invoice_for_order(order)
        self.assertEqual(inv2.status, 'PAID')
        self.assertEqual(inv2.amount_paid, gt)

        # Test serializer representation
        from billing.serializers import InvoiceSerializer
        ser = InvoiceSerializer(inv).data
        self.assertEqual(ser['status'], 'PAID')

    def test_partial_payment_leaves_correct_balance(self):
        """Partial payment updates amount_paid, leaves exact remaining balance, and status PARTIALLY_PAID."""
        order = Order.objects.create(
            created_by=self.customer1,
            order_source='DIRECT_COMPANY',
            city='Raipur',
            amount=Decimal('460.00'),
            grand_total=Decimal('460.00'),
            items_count=5,
            payment_status='pending',
        )
        inv = generate_invoice_for_order(order)
        gt = inv.grand_total

        # Pay 200 of grand total
        record_payment_transaction(
            invoice_id=inv.id,
            amount_paid=Decimal('200.00'),
            payment_method='UPI',
            actor=self.admin,
        )

        inv.refresh_from_db()
        self.assertEqual(inv.amount_paid, Decimal('200.00'))
        self.assertEqual(inv.outstanding_balance, gt - Decimal('200.00'))
        self.assertEqual(inv.status, 'PARTIALLY_PAID')

    def test_duplicate_payment_submission_rejected(self):
        """Submitting duplicate payment within rapid cutoff or duplicate ref is rejected."""
        order = Order.objects.create(
            created_by=self.customer1,
            city='Raipur',
            amount=Decimal('500.00'),
            grand_total=Decimal('500.00'),
            items_count=5,
        )
        inv = generate_invoice_for_order(order)

        # First payment succeeds
        record_payment_transaction(
            invoice_id=inv.id,
            amount_paid=Decimal('100.00'),
            payment_method='UPI',
            reference_number='UTR-DUPLICATE-CHECK-1',
            actor=self.admin,
        )

        # Immediate retry with same reference must be rejected
        with self.assertRaises(ValueError):
            record_payment_transaction(
                invoice_id=inv.id,
                amount_paid=Decimal('100.00'),
                payment_method='UPI',
                reference_number='UTR-DUPLICATE-CHECK-1',
                actor=self.admin,
            )

    # ---------------------------------------------------------
    # P0-1: Customer Invoice Download & Access Control
    # ---------------------------------------------------------
    def test_customer_invoice_download_access_control(self):
        """Customer can download their own invoice, but another customer receives 403."""
        order = Order.objects.create(
            created_by=self.customer1,
            city='Raipur',
            amount=Decimal('350.00'),
            grand_total=Decimal('350.00'),
            items_count=5,
        )
        generate_invoice_for_order(order)

        # Customer 1 (owner) downloads
        self.client.force_authenticate(user=self.customer1)
        res = self.client.get(f'/api/billing/orders/{order.id}/invoice/download/')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(res['Content-Type'], 'application/pdf')
        self.assertTrue(len(res.content) > 100)

        # Customer 2 attempts to download Customer 1's invoice
        self.client.force_authenticate(user=self.customer2)
        res2 = self.client.get(f'/api/billing/orders/{order.id}/invoice/download/')
        self.assertEqual(res2.status_code, status.HTTP_403_FORBIDDEN)

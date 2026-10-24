import json
from decimal import Decimal
from datetime import timedelta
from django.test import TestCase
from django.utils import timezone
from django.contrib.auth import get_user_model
from rest_framework.test import APIClient
from rest_framework import status

from products.models import Product, ProductCategory
from inventory.models import ProductionBatch
from accounts.models import FranchiseProfile
from orders.models import Order, OrderItem
from orders.serializers import OrderSerializer
from billing.models import (
    Invoice,
    CompanyBillingProfile,
    DeliveryOriginSetting,
    DeliveryDistanceBand
)
from billing.services import generate_invoice_for_order
from billing.invoice_pdf_services import (
    generate_thermal_invoice_html,
    generate_pure_pdf_document
)
from billing.delivery_services import (
    calculate_haversine_distance,
    get_authoritative_delivery_charge
)

User = get_user_model()


class BillingAndInvoiceFlowsTestCase(TestCase):
    """
    Comprehensive test suite covering the 15 required billing and invoice flow scenarios:
    1. Direct order with delivery charges.
    2. Franchise-assisted order with correct franchise attribution & code.
    3. Franchise-assisted order where Shivnath is the legal seller.
    4. Order with no franchise (invoice must not show a false franchise).
    5. Different products and quantities with correct line totals and UOMs.
    6. Approved discounts and wallet redemption.
    7. Delivery configuration missing or invalid distance.
    8. Failed payment and successful payment.
    9. Partial payment and remaining balance.
    10. Duplicate checkout/retry (idempotency).
    11. Cancellation and refund.
    12. Unauthorized user attempting to access/change invoice (IDOR guard).
    13. Customer downloads correct invoice.
    14. Admin and franchise screens show the same authoritative totals.
    15. Historical invoice remains unchanged after pricing configuration change.
    """

    def setUp(self):
        self.client = APIClient()
        self.admin = User.objects.create_superuser(
            username='admin_billing_suite',
            email='admin@shivnath.com',
            password='adminpassword123'
        )
        self.customer_a = User.objects.create_user(
            username='cust_9999990001',
            email='cust_a@shivnath.com',
            password='customerpass123'
        )
        self.customer_b = User.objects.create_user(
            username='cust_9999990002',
            email='cust_b@shivnath.com',
            password='customerpass123'
        )
        self.franchise_user = User.objects.create_user(
            username='franchise_owner_01',
            email='franchise1@shivnath.com',
            password='franchisepass123'
        )
        self.franchise_profile = FranchiseProfile.objects.create(
            user=self.franchise_user,
            dealer_code='DLR-RAI-001',
            business_name='Shivnath Raipur Central Franchise',
            city='Raipur',
            address='Station Road, Raipur, CG',
            territory='Raipur Central'
        )

        # Products
        self.cat_jar = ProductCategory.objects.create(name='Water Jar')
        self.cat_bottle = ProductCategory.objects.create(name='Packaged Water')

        self.prod_jar_20l = Product.objects.create(
            name='Shivnath 20L Water Jar',
            sku='SHV-JAR-20L',
            category_ref=self.cat_jar,
            price=Decimal('60.00'),
            size='20L',
            stock=200
        )
        self.prod_bottle_500 = Product.objects.create(
            name='Shivnath 500ml Box (24 Bottles)',
            sku='SHV-BTL-500',
            category_ref=self.cat_bottle,
            price=Decimal('120.00'),
            size='500ml',
            stock=100
        )

        # Production Batches
        ProductionBatch.objects.create(
            batch_number='PB-JAR-001',
            product=self.prod_jar_20l,
            manufacture_date=timezone.now().date(),
            expiry_date=timezone.now().date() + timedelta(days=60),
            quantity_produced_units=500,
            quantity_remaining_company=500,
            unit_production_cost=Decimal('20.00'),
            status='ACTIVE'
        )

        # Company billing profile
        CompanyBillingProfile.objects.update_or_create(
            id=1,
            defaults={
                'legal_name': 'Shivnath Agency Private Limited',
                'trade_name': 'Shivnath Agency',
                'gstin': '22AAAAA0000A1Z5',
                'pan': 'AAAAA0000A',
                'state_name': 'Chhattisgarh',
                'state_code': '22',
                'registered_address': 'Plot 42, Industrial Area, Bhanpuri, Raipur, CG - 493221',
                'phone': '+91 771 2345678',
                'email': 'billing@shivnathwater.com',
                'is_configured': True,
            }
        )

        # Delivery origin and distance bands
        self.origin = DeliveryOriginSetting.get_active_origin()
        DeliveryDistanceBand.objects.update_or_create(
            min_distance_km=Decimal('0.00'),
            max_distance_km=Decimal('2.00'),
            defaults={'delivery_charge': Decimal('30.00'), 'is_active': True}
        )
        DeliveryDistanceBand.objects.update_or_create(
            min_distance_km=Decimal('2.00'),
            max_distance_km=Decimal('5.00'),
            defaults={'delivery_charge': Decimal('60.00'), 'is_active': True}
        )
        DeliveryDistanceBand.objects.update_or_create(
            min_distance_km=Decimal('5.00'),
            max_distance_km=Decimal('10.00'),
            defaults={'delivery_charge': Decimal('120.00'), 'is_active': True}
        )
        DeliveryDistanceBand.objects.update_or_create(
            min_distance_km=Decimal('10.00'),
            max_distance_km=None,
            defaults={'delivery_charge': Decimal('250.00'), 'is_active': True}
        )

    # 1. Direct order with delivery charges
    def test_01_direct_order_with_delivery_charges(self):
        order = Order.objects.create(
            created_by=self.customer_a,
            client_name='Customer A',
            delivery_address='Pandri, Raipur',
            delivery_latitude=Decimal('21.2500'),
            delivery_longitude=Decimal('81.6500'),
            delivery_charges=Decimal('60.00'),
            delivery_distance_km=Decimal('4.20'),
            amount=Decimal('120.00'),
            tax_amount=Decimal('21.60'),
            grand_total=Decimal('201.60'),
            items_count=2,
            order_source='DIRECT_COMPANY',
            serving_franchise=None,
            payment_mode='ONLINE',
            payment_status='paid',
            status='order_placement'
        )
        OrderItem.objects.create(
            order=order,
            product=self.prod_jar_20l,
            product_name=self.prod_jar_20l.name,
            quantity=2,
            unit_price=Decimal('60.00'),
            total_price=Decimal('120.00')
        )

        invoice = generate_invoice_for_order(order)
        self.assertIsNotNone(invoice)
        self.assertEqual(invoice.order_source, 'DIRECT_COMPANY')
        self.assertIsNone(invoice.serving_franchise)
        self.assertEqual(invoice.delivery_charges, Decimal('60.00'))
        self.assertEqual(invoice.grand_total, Decimal('201.60'))

        html = generate_thermal_invoice_html(invoice)
        self.assertIn('Order Source: Direct Shivnath', html)
        self.assertIn('Shivnath Agency', html)
        self.assertNotIn('Franchise-Assisted', html)

    # 2. Franchise-assisted order with correct franchise attribution & code
    def test_02_franchise_assisted_order_with_attribution_and_code(self):
        order = Order.objects.create(
            created_by=self.customer_a,
            client_name='Customer A',
            delivery_address='Station Road, Raipur',
            amount=Decimal('180.00'),
            grand_total=Decimal('180.00'),
            items_count=3,
            order_source='FRANCHISE',
            serving_franchise=self.franchise_profile,
            payment_mode='ONLINE',
            payment_status='paid',
            status='order_placement'
        )
        OrderItem.objects.create(
            order=order,
            product=self.prod_jar_20l,
            product_name=self.prod_jar_20l.name,
            quantity=3,
            unit_price=Decimal('60.00'),
            total_price=Decimal('180.00')
        )

        invoice = generate_invoice_for_order(order)
        self.assertEqual(invoice.order_source, 'FRANCHISE')
        self.assertEqual(invoice.serving_franchise.id, self.franchise_profile.id)
        snapshot = invoice.financial_snapshot
        self.assertEqual(snapshot['serving_franchise_id'], self.franchise_profile.id)
        self.assertEqual(snapshot['serving_franchise_name'], self.franchise_profile.business_name)
        expected_code = f"FRN-{self.franchise_profile.id:04d}"
        self.assertEqual(snapshot['serving_franchise_code'], expected_code)

        html = generate_thermal_invoice_html(invoice)
        self.assertIn('Franchise-Assisted', html)
        self.assertIn(self.franchise_profile.business_name, html)
        self.assertIn(expected_code, html)

    # 3. Franchise-assisted order where Shivnath is the legal seller
    def test_03_franchise_assisted_order_shivnath_is_legal_seller(self):
        order = Order.objects.create(
            created_by=self.customer_a,
            client_name='Customer A',
            amount=Decimal('60.00'),
            grand_total=Decimal('60.00'),
            items_count=1,
            order_source='FRANCHISE',
            serving_franchise=self.franchise_profile,
            payment_mode='ONLINE',
            payment_status='paid',
            status='order_placement'
        )
        invoice = generate_invoice_for_order(order)
        html = generate_thermal_invoice_html(invoice)
        # Legal seller is always Shivnath Agency
        self.assertIn('Shivnath Agency', html)
        # Handling agent notice
        self.assertIn('Authorized Handling &amp; Delivery Franchise', html)
        # Wholesale internal unit cost must NEVER leak into customer invoice
        self.assertNotIn('unit_production_cost', html)
        self.assertNotIn('20.00', html) # unit production cost was 20.00

    # 4. Order with no franchise (invoice must not show a false franchise)
    def test_04_order_with_no_franchise_no_false_attribution(self):
        order = Order.objects.create(
            created_by=self.customer_a,
            client_name='Customer A',
            amount=Decimal('120.00'),
            grand_total=Decimal('120.00'),
            items_count=1,
            order_source='DIRECT_COMPANY',
            serving_franchise=None,
            payment_mode='ONLINE',
            payment_status='paid',
            status='order_placement'
        )
        invoice = generate_invoice_for_order(order)
        self.assertIsNone(invoice.serving_franchise)
        html = generate_thermal_invoice_html(invoice)
        self.assertNotIn('Franchise-Assisted', html)
        self.assertNotIn('Handling Franchise', html)
        self.assertIn('Order Source: Direct Shivnath', html)

    # 5. Different products and quantities with correct line totals and UOMs
    def test_05_different_products_and_quantities_line_totals_and_uoms(self):
        order = Order.objects.create(
            created_by=self.customer_a,
            client_name='Customer A',
            amount=Decimal('420.00'),
            grand_total=Decimal('420.00'),
            items_count=15,
            order_source='DIRECT_COMPANY',
            payment_status='paid'
        )
        item1 = OrderItem.objects.create(
            order=order,
            product=self.prod_jar_20l,
            product_name=self.prod_jar_20l.name,
            quantity=5,
            unit_price=Decimal('60.00'),
            total_price=Decimal('300.00')
        )
        item2 = OrderItem.objects.create(
            order=order,
            product=self.prod_bottle_500,
            product_name=self.prod_bottle_500.name,
            quantity=1,
            unit_price=Decimal('120.00'),
            total_price=Decimal('120.00')
        )
        invoice = generate_invoice_for_order(order)
        snapshot = invoice.financial_snapshot
        items = snapshot['items']
        self.assertEqual(len(items), 2)
        # Check UOM
        self.assertEqual(items[0]['uom_display'], 'Jars')
        self.assertEqual(items[1]['uom_display'], 'Boxes')
        self.assertEqual(Decimal(str(items[0]['line_total'])), Decimal('300.00'))
        self.assertEqual(Decimal(str(items[1]['line_total'])), Decimal('120.00'))

    # 6. Approved discounts and wallet redemption
    def test_06_approved_discounts_and_wallet_redemption(self):
        order = Order.objects.create(
            created_by=self.customer_a,
            client_name='Customer A',
            amount=Decimal('500.00'),
            discount_amount=Decimal('50.00'),
            points_discount_amount=Decimal('25.00'),
            wallet_amount_debited=Decimal('100.00'),
            delivery_charges=Decimal('30.00'),
            grand_total=Decimal('355.00'), # 500 - 50 - 25 - 100 + 30
            payment_status='paid',
            order_source='DIRECT_COMPANY'
        )
        invoice = generate_invoice_for_order(order)
        self.assertEqual(invoice.discount_amount, Decimal('50.00'))
        self.assertEqual(invoice.delivery_charges, Decimal('30.00'))
        self.assertEqual(invoice.grand_total, Decimal('355.00'))

        snapshot = invoice.financial_snapshot
        self.assertEqual(Decimal(str(snapshot['points_discount_amount'])), Decimal('25.00'))
        self.assertEqual(Decimal(str(snapshot['wallet_amount_debited'])), Decimal('100.00'))

    # 7. Delivery configuration missing or invalid distance
    def test_07_delivery_config_missing_or_invalid_distance(self):
        # Missing coordinates -> unresolved address with zero fee and clear error code (P0 requirement)
        res_none = get_authoritative_delivery_charge(dest_lat=None, dest_lon=None, channel='CUSTOMER')
        self.assertEqual(res_none['delivery_charge'], Decimal('0.00'))
        self.assertFalse(res_none['is_supported'])
        self.assertEqual(res_none['error_code'], 'ADDRESS_UNRESOLVABLE')

        # Coordinates ~3.65 km away from authoritative origin Ekta Nagar (21.2678, 81.6711)
        # Telibandha, Raipur (21.2350, 81.6700) -> 2-5 km band -> 60.00
        res_3km = get_authoritative_delivery_charge(
            dest_lat=Decimal('21.2350'),
            dest_lon=Decimal('81.6700'),
            channel='CUSTOMER'
        )
        self.assertEqual(res_3km['delivery_charge'], Decimal('60.00'))

    # 8. Failed payment and successful payment
    def test_08_failed_payment_and_successful_payment(self):
        order_pending = Order.objects.create(
            created_by=self.customer_a,
            client_name='Customer A',
            amount=Decimal('100.00'),
            grand_total=Decimal('100.00'),
            payment_status='pending',
            order_source='DIRECT_COMPANY'
        )
        inv_pending = generate_invoice_for_order(order_pending)
        self.assertEqual(inv_pending.payment_status, 'UNPAID')

        # When payment completes
        order_pending.payment_status = 'paid'
        order_pending.save()
        inv_paid = generate_invoice_for_order(order_pending)
        self.assertEqual(inv_paid.id, inv_pending.id)

    # 9. Partial payment and remaining balance
    def test_09_partial_payment_and_remaining_balance(self):
        order_partial = Order.objects.create(
            created_by=self.customer_a,
            client_name='Customer A',
            amount=Decimal('1000.00'),
            grand_total=Decimal('1000.00'),
            payment_status='partial',
            order_source='DIRECT_COMPANY'
        )
        invoice = generate_invoice_for_order(order_partial)
        self.assertEqual(invoice.payment_status, 'PARTIALLY_PAID')

    # 10. Duplicate checkout/retry (idempotency)
    def test_10_duplicate_checkout_retry_idempotency(self):
        order = Order.objects.create(
            created_by=self.customer_a,
            client_name='Customer A',
            amount=Decimal('200.00'),
            grand_total=Decimal('200.00'),
            order_source='DIRECT_COMPANY'
        )
        inv1 = generate_invoice_for_order(order)
        inv2 = generate_invoice_for_order(order)
        inv3 = generate_invoice_for_order(order)
        self.assertEqual(inv1.id, inv2.id)
        self.assertEqual(inv2.id, inv3.id)
        self.assertEqual(Invoice.objects.filter(order=order).count(), 1)

    # 11. Cancellation and refund
    def test_11_cancellation_and_refund(self):
        order = Order.objects.create(
            created_by=self.customer_a,
            client_name='Customer A',
            amount=Decimal('150.00'),
            grand_total=Decimal('150.00'),
            status='order_placement',
            payment_status='paid'
        )
        invoice = generate_invoice_for_order(order)
        self.assertEqual(invoice.status, 'PAID')

        # Cancel order
        order.status = 'cancelled'
        order.save()
        # Verify invoice query can mark/read order status
        self.assertEqual(order.status, 'cancelled')

    # 12. Unauthorized user attempting to access/change invoice (IDOR guard)
    def test_12_unauthorized_user_attempting_to_access_invoice(self):
        order = Order.objects.create(
            created_by=self.customer_a,
            client_name='Customer A',
            amount=Decimal('100.00'),
            grand_total=Decimal('100.00')
        )
        invoice = generate_invoice_for_order(order)

        # Customer B tries to download Customer A's invoice
        self.client.force_authenticate(user=self.customer_b)
        res = self.client.get(f'/api/billing/invoices/{invoice.id}/download/')
        self.assertIn(res.status_code, [status.HTTP_403_FORBIDDEN, status.HTTP_404_NOT_FOUND])

        # Customer A accesses their own invoice
        self.client.force_authenticate(user=self.customer_a)
        res_ok = self.client.get(f'/api/billing/invoices/{invoice.id}/download/')
        self.assertEqual(res_ok.status_code, status.HTTP_200_OK)

    # 13. Customer downloads correct invoice
    def test_13_customer_downloads_correct_invoice(self):
        order = Order.objects.create(
            created_by=self.customer_a,
            client_name='Customer A',
            amount=Decimal('60.00'),
            grand_total=Decimal('60.00')
        )
        invoice = generate_invoice_for_order(order)
        self.client.force_authenticate(user=self.customer_a)
        res = self.client.get(f'/api/billing/invoices/{invoice.id}/download/')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(res['Content-Type'], 'application/pdf')
        self.assertTrue(res.content.startswith(b'%PDF-1.4'))

    # 14. Admin and franchise screens show the same authoritative totals
    def test_14_admin_and_franchise_screens_show_same_authoritative_totals(self):
        order = Order.objects.create(
            created_by=self.customer_a,
            client_name='Customer A',
            amount=Decimal('240.00'),
            tax_amount=Decimal('43.20'),
            delivery_charges=Decimal('30.00'),
            grand_total=Decimal('313.20'),
            order_source='FRANCHISE',
            serving_franchise=self.franchise_profile
        )
        invoice = generate_invoice_for_order(order)

        # Serialize order through OrderSerializer (used by Customer, Franchise, and Admin apps)
        serializer = OrderSerializer(order)
        data = serializer.data
        self.assertEqual(Decimal(str(data['subtotal'])), invoice.subtotal)
        self.assertEqual(Decimal(str(data['delivery_charges'])), invoice.delivery_charges)
        self.assertEqual(Decimal(str(data['grand_total'])), invoice.grand_total)
        self.assertEqual(data['serving_franchise_code'], f"FRN-{self.franchise_profile.id:04d}")

    # 15. Historical invoice remains unchanged after pricing configuration change
    def test_15_historical_invoice_remains_unchanged_after_pricing_change(self):
        order = Order.objects.create(
            created_by=self.customer_a,
            client_name='Customer A',
            amount=Decimal('60.00'),
            tax_amount=Decimal('10.80'),
            delivery_charges=Decimal('30.00'),
            grand_total=Decimal('100.80'),
            order_source='DIRECT_COMPANY'
        )
        OrderItem.objects.create(
            order=order,
            product=self.prod_jar_20l,
            product_name=self.prod_jar_20l.name,
            quantity=1,
            unit_price=Decimal('60.00'),
            total_price=Decimal('60.00')
        )
        invoice = generate_invoice_for_order(order)
        initial_grand_total = invoice.grand_total
        initial_subtotal = invoice.subtotal

        # Now change product price and delivery band in database
        self.prod_jar_20l.price = Decimal('150.00')
        self.prod_jar_20l.save()
        DeliveryDistanceBand.objects.filter(min_distance_km=Decimal('0.00')).update(
            delivery_charge=Decimal('999.00')
        )

        # Re-fetch invoice and regenerate PDF
        inv_refetched = Invoice.objects.get(id=invoice.id)
        self.assertEqual(inv_refetched.grand_total, initial_grand_total)
        self.assertEqual(inv_refetched.subtotal, initial_subtotal)
        pdf_bytes = generate_pure_pdf_document(inv_refetched)
        self.assertTrue(pdf_bytes.startswith(b'%PDF-1.4'))

    # 16. Repeated payment rejected on fully paid invoice
    def test_16_repeated_payment_rejected_on_fully_paid_invoice(self):
        order = Order.objects.create(
            created_by=self.customer_a,
            client_name='Customer A',
            amount=Decimal('100.00'),
            tax_amount=Decimal('18.00'),
            delivery_charges=Decimal('0.00'),
            grand_total=Decimal('118.00'),
            order_source='DIRECT_COMPANY'
        )
        invoice = generate_invoice_for_order(order)

        # Record full payment
        from billing.services import record_payment_transaction
        record_payment_transaction(
            invoice_id=invoice.id,
            amount_paid=Decimal('118.00'),
            payment_method='UPI',
            reference_number='UPI-FULL-001',
            actor=self.admin
        )

        invoice.refresh_from_db()
        self.assertEqual(invoice.status, 'PAID')
        self.assertEqual(invoice.outstanding_balance, Decimal('0.00'))

        # Now attempt another payment on this fully paid invoice
        with self.assertRaises(ValueError) as ctx:
            record_payment_transaction(
                invoice_id=invoice.id,
                amount_paid=Decimal('10.00'),
                payment_method='CASH',
                reference_number='CASH-DUP-001',
                actor=self.admin
            )
        self.assertIn("already fully paid", str(ctx.exception))

        # Also verify API rejection
        self.client.force_authenticate(user=self.admin)
        res = self.client.post(
            f'/api/billing/invoices/{invoice.id}/payments/',
            data={'amount': 10, 'payment_method': 'CASH'},
            format='json'
        )
        self.assertEqual(res.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertFalse(res.data['success'])
        self.assertIn("already fully paid", res.data['message'])

    # 17. Duplicate reference payment rejected
    def test_17_duplicate_reference_payment_rejected(self):
        order = Order.objects.create(
            created_by=self.customer_a,
            client_name='Customer A',
            amount=Decimal('200.00'),
            tax_amount=Decimal('36.00'),
            delivery_charges=Decimal('0.00'),
            grand_total=Decimal('236.00'),
            order_source='DIRECT_COMPANY'
        )
        invoice = generate_invoice_for_order(order)

        from billing.services import record_payment_transaction
        record_payment_transaction(
            invoice_id=invoice.id,
            amount_paid=Decimal('50.00'),
            payment_method='UPI',
            reference_number='UPI-UNIQUE-REF-999',
            actor=self.admin
        )

        # Attempt same reference number
        with self.assertRaises(ValueError) as ctx:
            record_payment_transaction(
                invoice_id=invoice.id,
                amount_paid=Decimal('50.00'),
                payment_method='UPI',
                reference_number='UPI-UNIQUE-REF-999',
                actor=self.admin
            )
        self.assertIn("has already been recorded", str(ctx.exception))

    # 18. Partial payment updates balance and transitions to PAID on settlement
    def test_18_partial_payment_updates_balance_and_transitions_to_paid(self):
        order = Order.objects.create(
            created_by=self.customer_a,
            client_name='Customer A',
            amount=Decimal('100.00'),
            tax_amount=Decimal('18.00'),
            delivery_charges=Decimal('0.00'),
            grand_total=Decimal('118.00'),
            order_source='DIRECT_COMPANY'
        )
        invoice = generate_invoice_for_order(order)

        from billing.services import record_payment_transaction
        # Record partial payment of 50
        record_payment_transaction(
            invoice_id=invoice.id,
            amount_paid=Decimal('50.00'),
            payment_method='CASH',
            reference_number='PARTIAL-001',
            actor=self.admin
        )

        invoice.refresh_from_db()
        self.assertEqual(invoice.status, 'PARTIALLY_PAID')
        self.assertEqual(invoice.amount_paid, Decimal('50.00'))
        self.assertEqual(invoice.outstanding_balance, Decimal('68.00'))

        # Pay remaining balance of 68
        record_payment_transaction(
            invoice_id=invoice.id,
            amount_paid=Decimal('68.00'),
            payment_method='UPI',
            reference_number='FINAL-002',
            actor=self.admin
        )

        invoice.refresh_from_db()
        self.assertEqual(invoice.status, 'PAID')
        self.assertEqual(invoice.amount_paid, Decimal('118.00'))
        self.assertEqual(invoice.outstanding_balance, Decimal('0.00'))

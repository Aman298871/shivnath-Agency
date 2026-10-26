from decimal import Decimal
from django.test import TestCase
from django.contrib.auth.models import User
from rest_framework.test import APIClient

from products.models import Product, ProductCategory, MinimumOrderPackagingRule
from orders.models import Order, OrderItem
from billing.models import Invoice, CompanyBillingProfile
from billing.tax_calculator import calculate_order_tax_and_totals
from billing.services import generate_invoice_for_order
from billing.invoice_pdf_services import generate_pure_pdf_document, generate_thermal_invoice_html


class InvoicePricingAndGstReconciliationTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.admin = User.objects.create_superuser(
            username="admin_user",
            password="admin_password",
            email="admin@example.com",
        )
        self.customer = User.objects.create_user(
            username="kakinada_customer",
            first_name="Kakinada",
            last_name="Customer",
            email="kakinada@example.com",
        )

        self.profile = CompanyBillingProfile.objects.create(
            legal_name="Shivnath Agencies Central Plant",
            trade_name="Shivnath Agency",
            gstin="22AQNPK7620D1Z3",
            registered_address="Ekta Nagar, Raipur, Chhattisgarh",
            default_gst_rate=Decimal('18.00'),
            cgst_rate=Decimal('9.00'),
            sgst_rate=Decimal('9.00'),
            igst_rate=Decimal('18.00'),
            is_price_inclusive_gst=False,
            is_delivery_taxable=True,
            is_configured=True,
        )

        self.cat = ProductCategory.objects.create(name="Packaged Drinking Water", slug="packaged-drinking-water")

        self.bottle_200ml = Product.objects.create(
            name="Shivnath 200ml Event Bottle",
            sku="SHV-200ML-BOT",
            price=Decimal('5.00'),
            package_type="BOTTLE",
            size="200 ML",
            category_ref=self.cat,
        )

        # Packaging rule: 24 bottles per carton
        self.pack_rule = MinimumOrderPackagingRule.objects.create(
            product=self.bottle_200ml,
            applies_to="ALL",
            min_order_quantity=24,
            units_per_carton=24,
            is_active=True,
        )

    # -------------------------------------------------------------------------
    # TEST A: GST-Exclusive Calculations (18% and 5% with and without delivery tax)
    # -------------------------------------------------------------------------
    def test_a_gst_exclusive_calculations(self):
        """
        Verify GST-exclusive calculation:
        120 bottles @ ₹5.00 = ₹600.00. Delivery = ₹60.00.
        When delivery is taxable @ 18%:
          Taxable base: ₹660.00 -> GST: ₹118.80 (CGST: ₹59.40, SGST: ₹59.40) -> Total: ₹778.80.
        When delivery is NOT taxable @ 18%:
          Taxable base: ₹600.00 -> GST: ₹108.00 (CGST: ₹54.00, SGST: ₹54.00) -> Total: ₹768.00.
        When tax rate is 5% and delivery is taxable:
          Taxable base: ₹660.00 -> GST: ₹33.00 (CGST: ₹16.50, SGST: ₹16.50) -> Total: ₹693.00.
        """
        # Case 1: 18% Exclusive + Delivery Taxable
        self.profile.default_gst_rate = Decimal('18.00')
        self.profile.is_price_inclusive_gst = False
        self.profile.is_delivery_taxable = True
        self.profile.save()

        calc_1 = calculate_order_tax_and_totals(
            subtotal=Decimal('600.00'),
            delivery_fee=Decimal('60.00'),
            profile=self.profile,
        )
        self.assertEqual(calc_1['taxable_amount'], Decimal('660.00'))
        self.assertEqual(calc_1['tax_amount'], Decimal('118.80'))
        self.assertEqual(calc_1['cgst_amount'], Decimal('59.40'))
        self.assertEqual(calc_1['sgst_amount'], Decimal('59.40'))
        self.assertEqual(calc_1['grand_total'], Decimal('778.80'))

        # Case 2: 18% Exclusive + Delivery Non-Taxable (Reconciles Invoice 86 pre-GST vs post-GST)
        self.profile.is_delivery_taxable = False
        self.profile.save()

        calc_2 = calculate_order_tax_and_totals(
            subtotal=Decimal('600.00'),
            delivery_fee=Decimal('60.00'),
            profile=self.profile,
        )
        self.assertEqual(calc_2['taxable_amount'], Decimal('600.00'))
        self.assertEqual(calc_2['tax_amount'], Decimal('108.00'))
        self.assertEqual(calc_2['cgst_amount'], Decimal('54.00'))
        self.assertEqual(calc_2['sgst_amount'], Decimal('54.00'))
        self.assertEqual(calc_2['grand_total'], Decimal('768.00'))

        # Case 3: 5% Exclusive + Delivery Taxable
        self.profile.default_gst_rate = Decimal('5.00')
        self.profile.is_delivery_taxable = True
        self.profile.save()

        calc_3 = calculate_order_tax_and_totals(
            subtotal=Decimal('600.00'),
            delivery_fee=Decimal('60.00'),
            profile=self.profile,
        )
        self.assertEqual(calc_3['taxable_amount'], Decimal('660.00'))
        self.assertEqual(calc_3['tax_amount'], Decimal('33.00'))
        self.assertEqual(calc_3['cgst_amount'], Decimal('16.50'))
        self.assertEqual(calc_3['sgst_amount'], Decimal('16.50'))
        self.assertEqual(calc_3['grand_total'], Decimal('693.00'))

    # -------------------------------------------------------------------------
    # TEST B: GST-Inclusive Pricing (Tax extracted, NO double charging)
    # -------------------------------------------------------------------------
    def test_b_gst_inclusive_pricing_prevents_double_tax(self):
        """
        Verify GST-inclusive pricing:
        When price includes GST, customer expects ₹600 (products) + ₹60 (delivery) = ₹660.00 grand total.
        Taxes must be back-calculated and extracted, NEVER added on top.
        """
        self.profile.default_gst_rate = Decimal('18.00')
        self.profile.is_price_inclusive_gst = True
        self.profile.is_delivery_taxable = True
        self.profile.save()

        calc = calculate_order_tax_and_totals(
            subtotal=Decimal('600.00'),
            delivery_fee=Decimal('60.00'),
            profile=self.profile,
        )
        # 660 / 1.18 = 559.3220... -> Taxable: 559.32, Tax: 100.68, Grand Total: 660.00
        self.assertEqual(calc['grand_total'], Decimal('660.00'))
        self.assertEqual(calc['taxable_amount'], Decimal('559.32'))
        self.assertEqual(calc['tax_amount'], Decimal('100.68'))
        self.assertEqual(calc['cgst_amount'], Decimal('50.34'))
        self.assertEqual(calc['sgst_amount'], Decimal('50.34'))
        self.assertEqual(calc['taxable_amount'] + calc['tax_amount'], calc['grand_total'])

    # -------------------------------------------------------------------------
    # TEST C: Admin Rate Change (18% -> 5%) & Snapshot Immutability
    # -------------------------------------------------------------------------
    def test_c_admin_gst_rate_change_and_historical_snapshot(self):
        """
        Verify that changing GST rate in CompanyBillingProfile updates new invoices
        while previously generated invoices preserve their immutable historical snapshots.
        """
        # Order 1 placed at 18% GST (Exclusive)
        self.profile.default_gst_rate = Decimal('18.00')
        self.profile.is_price_inclusive_gst = False
        self.profile.is_delivery_taxable = False
        self.profile.save()

        order_1 = Order.objects.create(
            created_by=self.customer,
            amount=Decimal('600.00'),
            tax_amount=Decimal('108.00'),
            grand_total=Decimal('768.00'),
            delivery_charges=Decimal('60.00'),
            order_source='DIRECT_COMPANY',
            payment_mode='CASH',
            payment_status='pending',
        )
        OrderItem.objects.create(
            order=order_1,
            product=self.bottle_200ml,
            product_name="Shivnath 200ml Event Bottle",
            size="200 ML",
            quantity=120,
            unit_price=Decimal('5.00'),
            total_price=Decimal('600.00'),
        )
        inv_1 = generate_invoice_for_order(order_1)
        self.assertEqual(inv_1.tax_rate, Decimal('18.00'))
        self.assertEqual(inv_1.cgst_amount, Decimal('54.00'))
        self.assertEqual(inv_1.grand_total, Decimal('768.00'))

        # Admin changes rate to 5% via API or Profile
        self.client.force_authenticate(user=self.admin)
        res = self.client.put(
            '/api/billing/company-profile/',
            {
                'legal_name': self.profile.legal_name,
                'trade_name': self.profile.trade_name,
                'default_gst_rate': '5.00',
                'is_price_inclusive_gst': False,
                'is_delivery_taxable': False,
            },
            format='json',
        )
        self.assertEqual(res.status_code, 200)

        # Reload profile from DB
        self.profile.refresh_from_db()
        self.assertEqual(self.profile.default_gst_rate, Decimal('5.00'))
        self.assertEqual(self.profile.cgst_rate, Decimal('2.50'))
        self.assertEqual(self.profile.sgst_rate, Decimal('2.50'))

        # Order 2 placed under 5% GST
        order_2 = Order.objects.create(
            created_by=self.customer,
            amount=Decimal('600.00'),
            tax_amount=Decimal('30.00'),
            grand_total=Decimal('690.00'),
            delivery_charges=Decimal('60.00'),
            order_source='DIRECT_COMPANY',
            payment_mode='CASH',
            payment_status='pending',
        )
        OrderItem.objects.create(
            order=order_2,
            product=self.bottle_200ml,
            product_name="Shivnath 200ml Event Bottle",
            size="200 ML",
            quantity=120,
            unit_price=Decimal('5.00'),
            total_price=Decimal('600.00'),
        )
        inv_2 = generate_invoice_for_order(order_2)
        self.assertEqual(inv_2.tax_rate, Decimal('5.00'))
        self.assertEqual(inv_2.cgst_amount, Decimal('15.00'))
        self.assertEqual(inv_2.sgst_amount, Decimal('15.00'))
        self.assertEqual(inv_2.grand_total, Decimal('690.00'))

        # Check that Invoice 1 historical snapshot was NOT modified
        inv_1.refresh_from_db()
        self.assertEqual(inv_1.tax_rate, Decimal('18.00'))
        self.assertEqual(inv_1.cgst_amount, Decimal('54.00'))
        self.assertEqual(inv_1.grand_total, Decimal('768.00'))

    # -------------------------------------------------------------------------
    # TEST D: Zero Unexplained Discrepancy
    # -------------------------------------------------------------------------
    def test_d_zero_unexplained_discrepancy(self):
        """
        Verify that in all calculation branches, subtotal, taxes, delivery, and grand total
        satisfy exact mathematical balance with 0.00 unexplained difference.
        """
        scenarios = [
            (Decimal('600.00'), Decimal('60.00'), Decimal('18.00'), False, True),
            (Decimal('600.00'), Decimal('60.00'), Decimal('18.00'), False, False),
            (Decimal('600.00'), Decimal('60.00'), Decimal('5.00'), False, True),
            (Decimal('600.00'), Decimal('60.00'), Decimal('18.00'), True, True),
            (Decimal('600.00'), Decimal('60.00'), Decimal('5.00'), True, True),
            (Decimal('1250.75'), Decimal('45.50'), Decimal('18.00'), False, True),
            (Decimal('1250.75'), Decimal('45.50'), Decimal('18.00'), True, True),
        ]

        for subtotal, delivery, rate, inclusive, del_tax in scenarios:
            self.profile.default_gst_rate = rate
            self.profile.is_price_inclusive_gst = inclusive
            self.profile.is_delivery_taxable = del_tax
            self.profile.save()

            calc = calculate_order_tax_and_totals(subtotal, delivery, profile=self.profile)

            # Verification of tax sum
            self.assertEqual(calc['cgst_amount'] + calc['sgst_amount'], calc['tax_amount'])

            if inclusive:
                # In inclusive pricing, grand total must equal subtotal + delivery fee
                expected_total = subtotal + delivery
                self.assertEqual(calc['grand_total'], expected_total)
                self.assertEqual(calc['taxable_amount'] + calc['tax_amount'], calc['grand_total'])
            else:
                # In exclusive pricing, grand total must equal subtotal + delivery + tax_amount
                expected_total = subtotal + delivery + calc['tax_amount']
                self.assertEqual(calc['grand_total'], expected_total)

    # -------------------------------------------------------------------------
    # TEST E: Packaging Conversion (5 Cartons = 120 Bottles)
    # -------------------------------------------------------------------------
    def test_e_packaging_conversion_cartons_and_bottles(self):
        """
        Verify that 120 bottles with units_per_carton=24 are cleanly labeled as
        '5 Cartons (120 Bottles)' without mislabeling as Jars.
        """
        order = Order.objects.create(
            created_by=self.customer,
            amount=Decimal('600.00'),
            tax_amount=Decimal('108.00'),
            grand_total=Decimal('768.00'),
            delivery_charges=Decimal('60.00'),
            order_source='DIRECT_COMPANY',
            payment_mode='CASH',
            payment_status='pending',
        )
        OrderItem.objects.create(
            order=order,
            product=self.bottle_200ml,
            product_name="Shivnath 200ml Event Bottle",
            size="200 ML",
            quantity=120,
            unit_price=Decimal('5.00'),
            total_price=Decimal('600.00'),
        )

        inv = generate_invoice_for_order(order)
        item_snap = inv.financial_snapshot['items'][0]

        self.assertEqual(item_snap['packaging_display'], '5 Cartons (120 Bottles)')
        self.assertEqual(item_snap['unit_of_measure'], 'Bottles')
        self.assertNotEqual(item_snap['unit_of_measure'], 'Jars')

        # Check in HTML thermal generation
        thermal_html = generate_thermal_invoice_html(inv, paper_width_mm=80)
        self.assertIn('5 Cartons (120 Bottles)', thermal_html)
        self.assertNotIn('Jars', thermal_html)

        # Check in Pure PDF generation
        pdf_bytes = generate_pure_pdf_document(inv)
        pdf_text = pdf_bytes.decode('latin-1', 'replace')
        self.assertIn('5 Cartons \\(120 Bottles\\)', pdf_text)

    # -------------------------------------------------------------------------
    # TEST F: Customer Previous Balance Separation
    # -------------------------------------------------------------------------
    def test_f_customer_previous_balance_separation(self):
        """
        Verify that customer's previous outstanding debt from earlier orders
        is NEVER merged into the current invoice's subtotal or grand total.
        """
        # Create an earlier unpaid order of ₹500
        earlier_order = Order.objects.create(
            created_by=self.customer,
            amount=Decimal('500.00'),
            tax_amount=Decimal('0.00'),
            grand_total=Decimal('500.00'),
            delivery_charges=Decimal('0.00'),
            order_source='DIRECT_COMPANY',
            payment_mode='CASH',
            payment_status='pending',
        )

        # Current order of ₹600 + ₹60 delivery
        current_order = Order.objects.create(
            created_by=self.customer,
            amount=Decimal('600.00'),
            tax_amount=Decimal('118.80'),
            grand_total=Decimal('778.80'),
            delivery_charges=Decimal('60.00'),
            order_source='DIRECT_COMPANY',
            payment_mode='CASH',
            payment_status='pending',
        )
        OrderItem.objects.create(
            order=current_order,
            product=self.bottle_200ml,
            product_name="Shivnath 200ml Event Bottle",
            size="200 ML",
            quantity=120,
            unit_price=Decimal('5.00'),
            total_price=Decimal('600.00'),
        )

        inv = generate_invoice_for_order(current_order)

        # Current invoice must NOT contain the earlier ₹500 in its subtotal, grand total or outstanding balance
        self.assertEqual(inv.subtotal, Decimal('600.00'))
        self.assertEqual(inv.delivery_charges, Decimal('60.00'))
        self.assertEqual(inv.grand_total, Decimal('778.80'))
        self.assertEqual(inv.outstanding_balance, Decimal('778.80'))
        self.assertNotEqual(inv.grand_total, Decimal('1278.80'))

    # -------------------------------------------------------------------------
    # TEST G: Endpoint Calculation Harmony
    # -------------------------------------------------------------------------
    def test_g_calculation_harmony_between_api_order_and_invoice(self):
        """
        Verify that CalculateTaxAPIView, Order creation, and Invoice generation
        all produce identical figures without any mismatch.
        """
        self.profile.default_gst_rate = Decimal('18.00')
        self.profile.is_price_inclusive_gst = False
        self.profile.is_delivery_taxable = True
        self.profile.save()

        # 1. API Calculate Tax
        res = self.client.post(
            '/api/billing/calculate-tax/',
            {
                'subtotal': '600.00',
                'delivery_fee': '60.00',
                'discount': '0.00',
            },
            format='json',
        )
        self.assertEqual(res.status_code, 200)
        api_data = res.json()
        self.assertEqual(Decimal(str(api_data['tax_amount'])), Decimal('118.80'))
        self.assertEqual(Decimal(str(api_data['grand_total'])), Decimal('778.80'))

        # 2. Order Creation
        calc = calculate_order_tax_and_totals(
            subtotal=Decimal('600.00'),
            delivery_fee=Decimal('60.00'),
            profile=self.profile,
        )
        order = Order.objects.create(
            created_by=self.customer,
            amount=Decimal('600.00'),
            delivery_charges=Decimal('60.00'),
            tax_amount=calc['tax_amount'],
            grand_total=calc['grand_total'],
            order_source='DIRECT_COMPANY',
            payment_mode='CASH',
            payment_status='pending',
        )
        OrderItem.objects.create(
            order=order,
            product=self.bottle_200ml,
            product_name="Shivnath 200ml Event Bottle",
            size="200 ML",
            quantity=120,
            unit_price=Decimal('5.00'),
            total_price=Decimal('600.00'),
        )

        # 3. Invoice Generation
        inv = generate_invoice_for_order(order)

        self.assertEqual(inv.tax_amount, Decimal(str(api_data['tax_amount'])))
        self.assertEqual(inv.grand_total, Decimal(str(api_data['grand_total'])))
        self.assertEqual(order.grand_total, inv.grand_total)

    # -------------------------------------------------------------------------
    # TEST H: Payment Status Reconciliation
    # -------------------------------------------------------------------------
    def test_h_payment_status_and_reconciliation(self):
        """
        Verify unpaid, partial-payment, and fully-paid states.
        """
        order = Order.objects.create(
            created_by=self.customer,
            amount=Decimal('600.00'),
            delivery_charges=Decimal('60.00'),
            tax_amount=Decimal('118.80'),
            grand_total=Decimal('778.80'),
            order_source='DIRECT_COMPANY',
            payment_mode='CASH',
            payment_status='pending',
        )
        OrderItem.objects.create(
            order=order,
            product=self.bottle_200ml,
            product_name="Shivnath 200ml Event Bottle",
            size="200 ML",
            quantity=120,
            unit_price=Decimal('5.00'),
            total_price=Decimal('600.00'),
        )
        inv = generate_invoice_for_order(order)

        # State 1: Unpaid
        self.assertEqual(inv.payment_status, 'UNPAID')
        self.assertEqual(inv.amount_paid, Decimal('0.00'))
        self.assertEqual(inv.outstanding_balance, Decimal('778.80'))

        # State 2: Partial Payment
        inv.record_payment(Decimal('300.00'), payment_method='CASH', notes='Partial token cash')
        self.assertEqual(inv.payment_status, 'PARTIALLY_PAID')
        self.assertEqual(inv.amount_paid, Decimal('300.00'))
        self.assertEqual(inv.outstanding_balance, Decimal('478.80'))

        # State 3: Full Settlement
        inv.record_payment(Decimal('478.80'), payment_method='UPI', notes='Remaining online')
        self.assertEqual(inv.payment_status, 'PAID')
        self.assertEqual(inv.amount_paid, Decimal('778.80'))
        self.assertEqual(inv.outstanding_balance, Decimal('0.00'))

    # -------------------------------------------------------------------------
    # TEST I: Decimal Precision and Odd Divisions
    # -------------------------------------------------------------------------
    def test_i_decimal_precision_and_odd_tax_rates(self):
        """
        Verify that 5% GST and fractional prices do not cause 1-paisa drift.
        CGST and SGST must sum exactly to tax_amount.
        """
        self.profile.default_gst_rate = Decimal('5.00')
        self.profile.is_price_inclusive_gst = False
        self.profile.is_delivery_taxable = True
        self.profile.save()

        # Odd amount: subtotal = 333.33, delivery = 17.50 -> Base = 350.83
        calc = calculate_order_tax_and_totals(
            subtotal=Decimal('333.33'),
            delivery_fee=Decimal('17.50'),
            profile=self.profile,
        )
        # 350.83 * 0.05 = 17.5415 -> rounded: 17.54
        # CGST: 8.77, SGST: 8.77 -> sum = 17.54
        self.assertEqual(calc['tax_amount'], Decimal('17.54'))
        self.assertEqual(calc['cgst_amount'], Decimal('8.77'))
        self.assertEqual(calc['sgst_amount'], Decimal('8.77'))
        self.assertEqual(calc['cgst_amount'] + calc['sgst_amount'], calc['tax_amount'])
        self.assertEqual(calc['grand_total'], Decimal('368.37'))

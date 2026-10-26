from decimal import Decimal
from django.test import TestCase
from django.contrib.auth.models import User
from products.models import Product, ProductCategory
from orders.models import Order, OrderItem
from billing.models import Invoice, CompanyBillingProfile
from billing.services import generate_invoice_for_order
from billing.invoice_pdf_services import generate_pure_pdf_document, generate_thermal_invoice_html
from orders.serializers import OrderSerializer, OrderItemSerializer


class Invoice86RegressionTests(TestCase):
    def setUp(self):
        self.profile = CompanyBillingProfile.objects.create(
            legal_name="Shivnath Agencies Central Plant",
            trade_name="Shivnath Agency",
            gstin="22AQNPK7620D1Z3",
            registered_address="Ekta Nagar, Raipur, CG",
            default_gst_rate=Decimal('18.00'),
            cgst_rate=Decimal('9.00'),
            sgst_rate=Decimal('9.00'),
            igst_rate=Decimal('18.00'),
            is_delivery_taxable=False,
            is_configured=True,
        )

        self.user = User.objects.create_user(
            username="kakinada_test",
            first_name="Kakinada",
            last_name="Customer",
            email="kakinada@example.com",
        )

        self.cat = ProductCategory.objects.create(name="Packaged Drinking Water", slug="pdw")

        self.bottle_prod = Product.objects.create(
            name="Shivnath 200ml Event Bottle",
            sku="SHV-200ML",
            price=Decimal('5.00'),
            package_type="BOTTLE",
            size="200 ML",
            category_ref=self.cat,
        )

        self.jar_prod = Product.objects.create(
            name="Shivnath 20L Water Jar",
            sku="SHV-20L-JAR",
            price=Decimal('40.00'),
            package_type="JAR",
            size="20 L",
            category_ref=self.cat,
        )

    def test_invoice_86_arithmetic_and_tax_reconciliation(self):
        """
        Regression test for Invoice 86 issue:
        Subtotal 600 + Delivery 60 + GST 108 = 768.
        Confirms tax breakdown is preserved and never dropped for non-GST/retail bills.
        """
        order = Order.objects.create(
            created_by=self.user,
            amount=Decimal('600.00'),
            tax_amount=Decimal('108.00'),
            grand_total=Decimal('768.00'),
            delivery_charges=Decimal('60.00'),
            order_source='DIRECT_COMPANY',
            payment_mode='CASH',
            payment_status='pending',
        )

        item = OrderItem.objects.create(
            order=order,
            product=self.bottle_prod,
            product_name="Shivnath 200ml Event Bottle",
            size="200 ML",
            quantity=120,
            unit_price=Decimal('5.00'),
            total_price=Decimal('600.00'),
        )

        inv = generate_invoice_for_order(order)

        # 1. Authoritative financial balance
        self.assertEqual(inv.subtotal, Decimal('600.00'))
        self.assertEqual(inv.cgst_amount, Decimal('54.00'))
        self.assertEqual(inv.sgst_amount, Decimal('54.00'))
        self.assertEqual(inv.delivery_charges, Decimal('60.00'))
        self.assertEqual(inv.grand_total, Decimal('768.00'))
        self.assertEqual(inv.subtotal + inv.cgst_amount + inv.sgst_amount + inv.delivery_charges, inv.grand_total)
        self.assertEqual(inv.outstanding_balance, Decimal('768.00'))

        # 2. UOM must be Bottles, NEVER Jars
        item_snap = inv.financial_snapshot['items'][0]
        self.assertEqual(item_snap['uom'], 'Bottles')
        self.assertNotEqual(item_snap['uom'], 'Jars')

        # 3. Thermal HTML check
        thermal_html = generate_thermal_invoice_html(inv, paper_width_mm=80)
        self.assertIn('CGST (9%)', thermal_html)
        self.assertIn('SGST (9%)', thermal_html)
        self.assertIn('120 Bottles', thermal_html)
        self.assertNotIn('120 Jars', thermal_html)
        self.assertIn('This Invoice Balance Due', thermal_html)

        # 4. Pure PDF binary check
        pdf_bytes = generate_pure_pdf_document(inv)
        pdf_text = pdf_bytes.decode('latin-1', 'replace')
        self.assertIn('CGST \\(9%\\):', pdf_text)
        self.assertIn('SGST \\(9%\\):', pdf_text)
        self.assertIn('120 Bottles', pdf_text)
        self.assertNotIn('120 Jars', pdf_text)
        self.assertIn('This Invoice Balance Due:', pdf_text)

    def test_20l_jar_preserves_jar_uom(self):
        """
        Verify that genuine 20L water jars remain correctly classified as Jars.
        """
        order = Order.objects.create(
            created_by=self.user,
            amount=Decimal('200.00'),
            tax_amount=Decimal('36.00'),
            grand_total=Decimal('236.00'),
            delivery_charges=Decimal('0.00'),
            order_source='DIRECT_COMPANY',
            payment_mode='CASH',
            payment_status='pending',
        )

        item = OrderItem.objects.create(
            order=order,
            product=self.jar_prod,
            product_name="Shivnath 20L Water Jar",
            size="20 L",
            quantity=5,
            unit_price=Decimal('40.00'),
            total_price=Decimal('200.00'),
        )

        item_ser = OrderItemSerializer(item)
        self.assertEqual(item_ser.data['package_type'], 'JAR')
        self.assertEqual(item_ser.data['sales_unit_display'], 'Jars')

        inv = generate_invoice_for_order(order)
        self.assertEqual(inv.financial_snapshot['items'][0]['uom'], 'Jars')

    def test_customer_payment_synchronization(self):
        """
        Tests payment status serialization consistency between order and invoice.
        """
        order = Order.objects.create(
            created_by=self.user,
            amount=Decimal('100.00'),
            tax_amount=Decimal('18.00'),
            grand_total=Decimal('118.00'),
            delivery_charges=Decimal('0.00'),
            order_source='DIRECT_COMPANY',
            payment_mode='CASH',
            payment_status='pending',
        )

        ser_unpaid = OrderSerializer(order)
        self.assertEqual(ser_unpaid.data['payment_status'], 'pending')
        self.assertEqual(ser_unpaid.data['payment'], 'pending')

        # Full payment update
        order.payment_status = 'paid'
        order.save()

        ser_paid = OrderSerializer(order)
        self.assertEqual(ser_paid.data['payment_status'], 'paid')
        self.assertEqual(ser_paid.data['payment'], 'paid')
        self.assertEqual(ser_paid.data['outstanding_balance'], 0.0)

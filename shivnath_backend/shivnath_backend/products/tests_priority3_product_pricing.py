from django.test import TestCase
from django.contrib.auth import get_user_model
from decimal import Decimal
from rest_framework.test import APIClient

from products.models import Product
from orders.models import Order, OrderItem
from billing.models import Invoice
from accounts.models import UserProfile

User = get_user_model()


class Priority3ProductPricingTests(TestCase):
    def setUp(self):
        self.admin_user = User.objects.create_superuser(
            username='admin_pricing_tester',
            email='admin_pricing@waterwala.com',
            password='AdminPassword123!',
            first_name='Admin',
            last_name='PricingTester'
        )
        prof, _ = UserProfile.objects.get_or_create(user=self.admin_user)
        prof.role = 'admin'
        prof.save()

        self.client = APIClient()
        self.client.force_authenticate(user=self.admin_user)

        self.product = Product.objects.filter(sku='SHV-500ML-PRICING-TEST').first()
        if not self.product:
            self.product = Product.objects.create(
                name='Shivnath 500ml Bottled Water',
                sku='SHV-500ML-PRICING-TEST',
                category='water_bottles',
                size='500ml',
                price=Decimal('10.00'),
                dealer_transfer_price=Decimal('7.00'),
                mrp=Decimal('10.00'),
                gst=18,
                is_price_inclusive_gst=True,
                units_per_case=24,
                carton_price=Decimal('0.00'),
                discount_price=Decimal('0.00'),
                unit='Bottle',
                stock=500,
                status='Active'
            )

    def test_product_pricing_update_api(self):
        """Admin can update customer price, dealer wholesale rate, MRP, GST, pack size and carton price."""
        url = f"/api/products/{self.product.id}/pricing/"
        payload = {
            "price": 12.00,
            "dealer_transfer_price": 8.50,
            "mrp": 15.00,
            "gst": 18,
            "is_price_inclusive_gst": True,
            "units_per_case": 24,
            "carton_price": 280.00,
            "discount_price": 11.50,
            "unit": "Bottle",
            "size": "500ml",
        }

        response = self.client.patch(url, payload, format='json')
        self.assertEqual(response.status_code, 200)
        self.assertTrue(response.data["success"])

        # Reload from database
        self.product.refresh_from_db()
        self.assertEqual(self.product.price, Decimal('12.00'))
        self.assertEqual(self.product.dealer_transfer_price, Decimal('8.50'))
        self.assertEqual(self.product.mrp, Decimal('15.00'))
        self.assertEqual(self.product.gst, 18)
        self.assertTrue(self.product.is_price_inclusive_gst)
        self.assertEqual(self.product.units_per_case, 24)
        self.assertEqual(self.product.carton_price, Decimal('280.00'))
        self.assertEqual(self.product.discount_price, Decimal('11.50'))

        # Check calculated properties
        self.assertEqual(self.product.effective_price, Decimal('11.50'))
        self.assertEqual(self.product.calculated_carton_price, Decimal('280.00'))

    def test_validation_rejections(self):
        """API rejects negative prices, invalid GST rates, and invalid carton packaging units."""
        url = f"/api/products/{self.product.id}/pricing/"

        # Negative customer retail price
        res1 = self.client.patch(url, {"price": -5.00}, format='json')
        self.assertEqual(res1.status_code, 400)

        # Negative wholesale price
        res2 = self.client.patch(url, {"dealer_transfer_price": -2.00}, format='json')
        self.assertEqual(res2.status_code, 400)

        # Invalid GST percentage (> 100)
        res3 = self.client.patch(url, {"gst": 125}, format='json')
        self.assertEqual(res3.status_code, 400)

        # Invalid units per case (< 1)
        res4 = self.client.patch(url, {"units_per_case": 0}, format='json')
        self.assertEqual(res4.status_code, 400)

    def test_historical_order_and_invoice_snapshot_preservation(self):
        """
        Critical business requirement: Updating a product's price in the master catalog
        must NEVER alter historical order item snapshots or already-issued invoices.
        """
        # 1. Place an order when unit price is 10.00
        order = Order.objects.create(
            franchise_name='Raipur Central Depot',
            city='Raipur',
            items_count=1,
            amount=Decimal('240.00'),
            tax_amount=Decimal('43.20'),
            grand_total=Decimal('283.20'),
            status='delivered',
            payment_status='paid'
        )

        item = OrderItem.objects.create(
            order=order,
            product=self.product,
            product_name=self.product.name,
            size=self.product.size,
            quantity=24,
            unit_price=Decimal('10.00'),
            total_price=Decimal('240.00'),
        )

        # 2. Create invoice snapshot
        invoice = Invoice.objects.create(
            invoice_number='INV-TEST-PRICING-001',
            order=order,
            invoice_type='CUSTOMER_SALE_INVOICE',
            billed_to_name='Customer Alpha',
            subtotal=Decimal('240.00'),
            cgst_amount=Decimal('21.60'),
            sgst_amount=Decimal('21.60'),
            delivery_charges=Decimal('0.00'),
            grand_total=Decimal('283.20'),
            status='PAID'
        )

        # 3. Admin updates master product price to 25.00 (large increase)
        url = f"/api/products/{self.product.id}/pricing/"
        res = self.client.patch(url, {"price": 25.00, "mrp": 30.00}, format='json')
        self.assertEqual(res.status_code, 200)

        # 4. Verify historical order and invoice remain completely intact
        self.product.refresh_from_db()
        self.assertEqual(self.product.price, Decimal('25.00'))

        item.refresh_from_db()
        self.assertEqual(item.unit_price, Decimal('10.00'), "OrderItem unit_price must remain frozen at ₹10.00")
        self.assertEqual(item.total_price, Decimal('240.00'), "OrderItem total_price must remain frozen at ₹240.00")

        order.refresh_from_db()
        self.assertEqual(order.amount, Decimal('240.00'))
        self.assertEqual(order.grand_total, Decimal('283.20'))

        invoice.refresh_from_db()
        self.assertEqual(invoice.subtotal, Decimal('240.00'), "Invoice subtotal must remain frozen at ₹240.00")
        self.assertEqual(invoice.grand_total, Decimal('283.20'), "Invoice grand_total must remain frozen at ₹283.20")

    def test_carton_and_discount_price_properties(self):
        """Verify dynamic carton calculation and promotional discount price mechanics."""
        # Baseline: price = 10, units_per_case = 24, carton_price = 0 => auto-calculates 240
        self.product.carton_price = Decimal('0.00')
        self.product.discount_price = Decimal('0.00')
        self.product.price = Decimal('10.00')
        self.product.units_per_case = 24
        self.product.save()

        self.assertEqual(self.product.effective_price, Decimal('10.00'))
        self.assertEqual(self.product.calculated_carton_price, Decimal('240.00'))

        # Set discount price = 8.50 => effective_price is 8.50, auto carton price is 8.50 * 24 = 204.00
        self.product.discount_price = Decimal('8.50')
        self.product.save()
        self.assertEqual(self.product.effective_price, Decimal('8.50'))
        self.assertEqual(self.product.calculated_carton_price, Decimal('204.00'))

        # Set custom carton package price = 195.00 => calculated_carton_price returns custom 195.00
        self.product.carton_price = Decimal('195.00')
        self.product.save()
        self.assertEqual(self.product.calculated_carton_price, Decimal('195.00'))

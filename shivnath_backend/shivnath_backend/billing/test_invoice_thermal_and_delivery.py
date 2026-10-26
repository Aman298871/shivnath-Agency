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
from orders.models import Order, OrderItem
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


class InvoiceThermalAndDeliveryTestCase(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.admin = User.objects.create_superuser(
            username='admin_billing_test',
            email='admin@example.com',
            password='adminpassword123'
        )
        self.customer_a = User.objects.create_user(
            username='cust_8888888881',
            email='cust_a@example.com',
            password='customerpassword123'
        )
        self.customer_b = User.objects.create_user(
            username='cust_8888888882',
            email='cust_b@example.com',
            password='customerpassword123'
        )
        self.category = ProductCategory.objects.create(name='Mineral Water')
        self.product = Product.objects.create(
            name='Shivnath 500ml Bottled Water',
            sku='SHV-500-TEST',
            category_ref=self.category,
            price=Decimal('10.00'),
            size='500ml',
            stock=500
        )
        self.batch = ProductionBatch.objects.create(
            batch_number='PB-TEST-INV-001',
            product=self.product,
            manufacture_date=timezone.now().date(),
            expiry_date=timezone.now().date() + timedelta(days=90),
            quantity_produced_units=1000,
            quantity_remaining_company=1000,
            reserved_quantity=0,
            unit_production_cost=Decimal('5.00'),
            status='ACTIVE'
        )
        # Ensure company profile exists
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

        # Create active origin and bands
        self.origin = DeliveryOriginSetting.get_active_origin()
        # Origin is Bhanpuri, Raipur (21.3060, 81.6500)

        # Create order for Customer A
        self.order = Order.objects.create(
            created_by=self.customer_a,
            client_name='Customer A',
            delivery_address='Pandri, Raipur',
            delivery_latitude=Decimal('21.2500'),
            delivery_longitude=Decimal('81.6500'),
            delivery_charges=Decimal('30.00'),
            delivery_distance_km=Decimal('6.23'),
            amount=Decimal('100.00'),
            grand_total=Decimal('130.00'),
            items_count=10,
            payment_mode='ONLINE',
            payment_status='paid',
            status='order_placement'
        )
        OrderItem.objects.create(
            order=self.order,
            product=self.product,
            product_name=self.product.name,
            quantity=10,
            unit_price=Decimal('10.00'),
            total_price=Decimal('100.00')
        )

    def test_automatic_invoice_generation_idempotency(self):
        """Transitioning order to invoice_generated creates a unique invoice once without duplicates."""
        inv1 = generate_invoice_for_order(self.order)
        self.assertIsNotNone(inv1)
        self.assertIsNotNone(inv1.invoice_number)
        self.assertTrue(inv1.invoice_number.startswith('SHV'))
        self.assertEqual(inv1.order.id, self.order.id)
        self.assertEqual(inv1.grand_total, Decimal('130.00'))

        # Calling again must return the exact same invoice (idempotent)
        inv2 = generate_invoice_for_order(self.order)
        self.assertEqual(inv1.id, inv2.id)
        self.assertEqual(inv1.invoice_number, inv2.invoice_number)
        self.assertEqual(Invoice.objects.filter(order=self.order).count(), 1)

    def test_thermal_invoice_html_structure(self):
        """Thermal invoice HTML renders correctly with business details and line items."""
        invoice = generate_invoice_for_order(self.order)
        html_80 = generate_thermal_invoice_html(invoice, paper_width_mm=80)
        self.assertIn('Shivnath Agency', html_80)
        self.assertIn(invoice.invoice_number, html_80)
        self.assertIn('22AAAAA0000A1Z5', html_80)
        self.assertIn('Shivnath 500ml Bottled Water', html_80)
        self.assertIn('130.00', html_80)

        # 58mm compact layout
        html_58 = generate_thermal_invoice_html(invoice, paper_width_mm=58)
        self.assertIn('width: 58mm', html_58)

    def test_pure_pdf_generation(self):
        """Zero-dependency vector PDF generates a valid PDF 1.4 document."""
        invoice = generate_invoice_for_order(self.order)
        pdf_bytes = generate_pure_pdf_document(invoice)
        self.assertIsInstance(pdf_bytes, bytes)
        self.assertTrue(pdf_bytes.startswith(b'%PDF-1.4'))
        self.assertTrue(pdf_bytes.rstrip().endswith(b'%%EOF'))

    def test_delivery_distance_and_authoritative_charge(self):
        """Delivery charges are computed authoritatively on backend based on coordinates."""
        # Exact origin coordinates -> 0 km -> 0-2 km band
        res_origin = get_authoritative_delivery_charge(
            dest_lat=self.origin.latitude,
            dest_lon=self.origin.longitude,
            channel='CUSTOMER'
        )
        self.assertEqual(res_origin['distance_km'], 0.0)
        self.assertEqual(res_origin['delivery_charge'], Decimal('30.00'))

        # Distant coordinates (~15 km away) -> >10 km band
        res_distant = get_authoritative_delivery_charge(
            dest_lat=Decimal('21.1500'),
            dest_lon=Decimal('81.6500'),
            channel='CUSTOMER'
        )
        self.assertGreater(res_distant['distance_km'], 10.0)
        self.assertEqual(res_distant['delivery_charge'], Decimal('250.00'))

    def test_invoice_access_control_idor_prevention(self):
        """Customer B cannot view or download Customer A's invoice."""
        invoice = generate_invoice_for_order(self.order)

        # Customer A can access their own invoice
        self.client.force_authenticate(user=self.customer_a)
        res_a = self.client.get(f'/api/billing/invoices/{invoice.id}/download/')
        self.assertEqual(res_a.status_code, status.HTTP_200_OK)
        self.assertEqual(res_a['Content-Type'], 'application/pdf')

        # Customer B attempts to access Customer A's invoice -> 404/403 forbidden
        self.client.force_authenticate(user=self.customer_b)
        res_b = self.client.get(f'/api/billing/invoices/{invoice.id}/download/')
        self.assertIn(res_b.status_code, [status.HTTP_403_FORBIDDEN, status.HTTP_404_NOT_FOUND])

        # Admin can access any invoice
        self.client.force_authenticate(user=self.admin)
        res_admin = self.client.get(f'/api/billing/invoices/{invoice.id}/thermal/')
        self.assertEqual(res_admin.status_code, status.HTTP_200_OK)
        self.assertIn('text/html', res_admin['Content-Type'])

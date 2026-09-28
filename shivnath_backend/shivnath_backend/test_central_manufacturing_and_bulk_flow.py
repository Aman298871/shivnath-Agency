import os
import django
from datetime import timedelta
from decimal import Decimal

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from django.test import TestCase
from rest_framework.test import APIClient
from django.contrib.auth.models import User
from django.utils import timezone
from accounts.models import UserProfile
from products.models import Product, ProductCategory
from orders.models import Order, OrderItem
from inventory.models import ProductionBatch, InventoryTransactionLedger
from inventory.services import create_production_batch_atomic, record_batch_collection_atomic

class CentralManufacturingAndBulkFlowTestCase(TestCase):
    def setUp(self):
        self.client = APIClient()

        # Admin user
        self.admin = User.objects.create_user(
            username='central_plant_admin', email='plant@shivnath.com', password='password123', is_staff=True, is_superuser=True
        )
        profile, _ = UserProfile.objects.get_or_create(user=self.admin)
        profile.role = 'admin'
        profile.save()

        # Product Category
        self.category = ProductCategory.objects.create(
            name='Packaged Drinking Water Bottles',
            slug='bottles',
            order=1,
            is_active=True,
        )

        # 250 ML Bottle Product Master with configurable shelf-life
        self.product_250ml = Product.objects.create(
            name='Shivnath 250ml Mini Bottle',
            sku='SKU-BOT-250',
            category='Bottle',
            category_ref=self.category,
            size='250 ML',
            price=Decimal('6.00'),
            mrp=Decimal('10.00'),
            dealer_transfer_price=Decimal('4.50'),
            shelf_life_days=90,  # Configured shelf life for this client/variant
            unit='Bottle',
            stock=0,
            status='Active'
        )

    def test_complete_manufacturing_to_partial_collection_workflow(self):
        """
        Tests the authoritative Shivnath Agency workflow:
        1. Customer (Digital Marketing Wala) places bulk order for 5,000 units of 250 ML.
        2. Production requirement is reviewed, and plant manufactures batch BATCH-250-001 (5,000 units).
        3. Dynamic expiry date is verified from configured shelf life (Mfg + 90 days, NOT hardcoded 3 months).
        4. Customer collects 2,000 units; remaining 3,000 units STAY as company pending stock.
        5. Batch traceability verifies Produced: 5,000, Taken: 2,000, Pending: 3,000.
        6. Customer collects the remaining 3,000 units -> full stock cleared and order completed.
        """
        # Step 1: Customer (Digital Marketing Wala) places bulk requirement
        order = Order.objects.create(
            franchise_name='Digital Marketing Wala',
            client_name='Digital Marketing Wala',
            city='Raipur',
            delivery_address='VIP Road Commercial Complex, Raipur',
            order_source='DIRECT_COMPANY',
            label_requirement='Custom 250ml Holographic Waterproof Label',
            printing_requirement='Front Logo + Back Compliance & Batch Number',
            branding_requirement='Shrink wrap cartons of 24 bottles each',
            custom_shelf_life_days=90,
            amount=Decimal('30000.00'),
            grand_total=Decimal('35400.00'),
            status='order_placement',
            payment_status='partial',
            created_by=self.admin
        )
        order_item = OrderItem.objects.create(
            order=order,
            product=self.product_250ml,
            product_name=self.product_250ml.name,
            size='250 ML',
            quantity=5000,
            unit_price=Decimal('6.00'),
            total_price=Decimal('30000.00')
        )

        self.assertEqual(order.total_produced_units, 0)
        self.assertEqual(order.total_delivered_units, 0)
        self.assertEqual(order.total_pending_stock_units, 0)

        # Step 2 & 3: Factory manufactures Production Batch
        mfg_date = timezone.now().date()
        configured_shelf_life = 90
        expected_expiry_date = mfg_date + timedelta(days=configured_shelf_life)

        batch = create_production_batch_atomic(
            product_id=self.product_250ml.id,
            quantity_produced_units=5000,
            manufacture_date=mfg_date,
            batch_number='BATCH-250-001',
            shelf_life_days=configured_shelf_life,
            client_name='Digital Marketing Wala',
            linked_order=order,
            label_requirement='Custom 250ml Holographic Waterproof Label',
            printing_requirement='Front Logo + Back Compliance & Batch Number',
            branding_requirement='Shrink wrap cartons of 24 bottles each',
            actor=self.admin
        )

        # Validate Batch Creation & Expiry Calculation
        self.assertEqual(batch.batch_number, 'BATCH-250-001')
        self.assertEqual(batch.quantity_produced_units, 5000)
        self.assertEqual(batch.quantity_remaining_company, 5000)
        self.assertEqual(batch.quantity_dispatched, 0)
        self.assertEqual(batch.quantity_pending_collection, 5000)
        self.assertEqual(batch.dynamic_remaining_company, 5000)
        self.assertEqual(batch.expiry_date, expected_expiry_date)
        self.assertEqual(batch.client_name, 'Digital Marketing Wala')
        self.assertEqual(batch.linked_order_id, order.id)

        # Validate order synchronization
        order.refresh_from_db()
        self.assertEqual(order.total_produced_units, 5000)
        self.assertEqual(order.total_delivered_units, 0)
        self.assertEqual(order.total_pending_stock_units, 5000)
        self.assertEqual(order.status, 'preparing')

        # Step 4: Customer collects 2,000 bottles (Partial collection)
        res_collection_1 = record_batch_collection_atomic(
            batch_id=batch.id,
            quantity_collected=2000,
            client_name='Digital Marketing Wala Logistics',
            notes='Collected 2,000 units via Transport Vehicle DL-01-AB-1234',
            actor=self.admin
        )

        batch.refresh_from_db()
        order.refresh_from_db()

        # Step 5: Validate that remaining 3,000 bottles are STILL COMPANY PENDING STOCK
        self.assertEqual(batch.quantity_produced_units, 5000)
        self.assertEqual(batch.quantity_dispatched, 2000)
        self.assertEqual(batch.quantity_taken, 2000)
        self.assertEqual(batch.quantity_remaining_company, 3000)
        self.assertEqual(batch.quantity_pending_collection, 3000)
        self.assertEqual(batch.dynamic_remaining_company, 3000)
        self.assertEqual(batch.status, 'ACTIVE')

        self.assertEqual(order.total_produced_units, 5000)
        self.assertEqual(order.total_delivered_units, 2000)
        self.assertEqual(order.total_pending_stock_units, 3000)
        self.assertEqual(order.status, 'dispatch')  # Partially fulfilled / in transit

        # Validate authoritative transaction ledger entry for the collection
        ledger_entry = InventoryTransactionLedger.objects.filter(
            production_batch=batch,
            transaction_type='STOCK_TRANSFER_OUT',
            reference_type='CUSTOMER_COLLECTION'
        ).first()
        self.assertIsNotNone(ledger_entry)
        self.assertEqual(ledger_entry.quantity, Decimal('-2000'))
        self.assertEqual(ledger_entry.balance_after, Decimal('3000'))

        # Step 6: Customer collects the remaining 3,000 units
        res_collection_2 = record_batch_collection_atomic(
            batch_id=batch.id,
            quantity_collected=3000,
            client_name='Digital Marketing Wala Logistics',
            notes='Final collection of remaining 3,000 units',
            actor=self.admin
        )

        batch.refresh_from_db()
        order.refresh_from_db()

        # Step 7: Full Stock Cleared
        self.assertEqual(batch.quantity_produced_units, 5000)
        self.assertEqual(batch.quantity_dispatched, 5000)
        self.assertEqual(batch.quantity_remaining_company, 0)
        self.assertEqual(batch.quantity_pending_collection, 0)
        self.assertEqual(batch.dynamic_remaining_company, 0)
        self.assertEqual(batch.status, 'DEPLETED')

        self.assertEqual(order.total_produced_units, 5000)
        self.assertEqual(order.total_delivered_units, 5000)
        self.assertEqual(order.total_pending_stock_units, 0)
        self.assertEqual(order.status, 'delivered')

        print("\n========================================================")
        print("PASS: Central Manufacturing & Customer Bulk Order Traceability")
        print("Produced: 5,000 | Taken: 2,000 -> Remaining: 3,000 Pending Stock")
        print("Final Taken: 3,000 -> Remaining: 0 Stock Cleared")
        print("Configured Shelf Life (Mfg + 90 Days) = Expiry Date verified")
        print("========================================================\n")

    def test_create_production_batch_api_with_string_dates_and_expiry_serialization(self):
        """
        Verify that POST /api/inventory/production-batches/ succeeds when string dates
        (e.g. from Flutter: expiry_date="2027-03-27") are passed, and that is_expired
        serializes properly without throwing 'TypeError: >= not supported between instances of datetime.date and str'.
        """
        self.client.force_authenticate(user=self.admin)
        payload = {
            "product_id": str(self.product_250ml.id),
            "batch_number": "BATCH-666152",
            "quantity_produced_units": 5000,
            "shelf_life_days": 180,
            "expiry_date": "2027-03-27",
            "client_name": "",
            "linked_order": None,
            "label_requirement": "",
            "printing_requirement": "",
            "branding_requirement": ""
        }
        response = self.client.post(
            '/api/inventory/production-batches/',
            data=payload,
            content_type='application/json'
        )
        self.assertEqual(response.status_code, 201, response.data)
        self.assertEqual(response.data['batch_number'], 'BATCH-666152')
        self.assertEqual(response.data['quantity_produced_units'], 5000)
        self.assertEqual(response.data['expiry_date'], '2027-03-27')
        self.assertFalse(response.data['is_expired'])


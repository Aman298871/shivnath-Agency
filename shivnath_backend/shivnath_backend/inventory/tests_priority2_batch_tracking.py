from django.test import TestCase
from django.contrib.auth import get_user_model
from django.utils import timezone
from datetime import timedelta
from decimal import Decimal
from rest_framework.test import APIClient
from django.core.exceptions import ValidationError

from products.models import Product
from inventory.models import ProductionBatch, InventoryTransactionLedger
from inventory.services import (
    record_batch_collection_atomic,
    adjust_production_batch_atomic,
    receive_stock_request_atomic,
)

from accounts.models import UserProfile

User = get_user_model()


class Priority2BatchTrackingTests(TestCase):
    def setUp(self):
        self.admin_user = User.objects.create_superuser(
            username='admin_batch_tester',
            email='admin@waterwala.com',
            password='AdminPassword123!',
            first_name='Admin',
            last_name='Tester'
        )
        prof, _ = UserProfile.objects.get_or_create(user=self.admin_user)
        prof.role = 'admin'
        prof.save()

        self.client = APIClient()
        self.client.force_authenticate(user=self.admin_user)

        self.product = Product.objects.filter(sku='SHV-20L').first()
        if not self.product:
            self.product = Product.objects.create(
                name='Shivnath 20 Litre Dispenser Jar',
                sku='SHV-20L-TEST',
                category='water_jars',
                size='20 Litre Jar',
                price=Decimal('60.00'),
                unit='Jar',
                stock=100,
                shelf_life_days=45,
                status='Active'
            )

    def test_distinguishable_quantities_and_properties(self):
        """Verify all 8 distinguishable batch stock metrics and properties."""
        now = timezone.now().date()
        batch = ProductionBatch.objects.create(
            batch_number='PB-TEST-001',
            product=self.product,
            quantity_produced_units=100,
            quantity_remaining_company=100,
            quantity_dispatched=0,
            quantity_received=0,
            quantity_sold=0,
            quantity_damaged=0,
            quantity_returned=0,
            manufacture_date=now - timedelta(days=5),
            expiry_date=now + timedelta(days=40),
            status='ACTIVE'
        )

        self.assertEqual(batch.quantity_produced_units, 100)
        self.assertEqual(batch.available_quantity, 100)
        self.assertEqual(batch.remaining_usable_stock, 100)
        self.assertEqual(batch.quantity_expired, 0)
        self.assertEqual(batch.unit_of_measure, 'Jar')
        self.assertFalse(batch.is_expired)

    def test_expired_batch_returns_zero_available_stock_and_blocks_dispatch(self):
        """Verify expired batch zeroes available quantity and blocks dispatch."""
        now = timezone.now().date()
        expired_batch = ProductionBatch.objects.create(
            batch_number='PB-EXPIRED-001',
            product=self.product,
            quantity_produced_units=50,
            quantity_remaining_company=50,
            quantity_dispatched=0,
            manufacture_date=now - timedelta(days=60),
            expiry_date=now - timedelta(days=15),
            status='EXPIRED'
        )

        self.assertTrue(expired_batch.is_expired)
        self.assertEqual(expired_batch.available_quantity, 0)
        self.assertEqual(expired_batch.remaining_usable_stock, 0)
        self.assertEqual(expired_batch.dynamic_quantity_expired, 50)

        # Attempting dispatch from expired batch must raise ValidationError
        with self.assertRaises(ValidationError) as ctx:
            record_batch_collection_atomic(
                batch_id=expired_batch.id,
                quantity_collected=10,
                client_name='Driver Test',
                actor=self.admin_user
            )
        self.assertIn('Cannot dispatch or collect from batch', str(ctx.exception))

    def test_valid_batch_collection_updates_quantities_and_ledger(self):
        """Verify successful dispatch increments dispatched qty and decrements company remaining stock."""
        now = timezone.now().date()
        batch = ProductionBatch.objects.create(
            batch_number='PB-ACTIVE-002',
            product=self.product,
            quantity_produced_units=100,
            quantity_remaining_company=100,
            quantity_dispatched=0,
            manufacture_date=now,
            expiry_date=now + timedelta(days=45),
            status='ACTIVE'
        )

        res = record_batch_collection_atomic(
            batch_id=batch.id,
            quantity_collected=30,
            client_name='Franchise Dispatch Van',
            notes='Delivery to Franchise Hub Raipur',
            actor=self.admin_user
        )

        batch.refresh_from_db()
        self.assertEqual(batch.quantity_dispatched, 30)
        self.assertEqual(batch.quantity_remaining_company, 70)
        self.assertEqual(batch.available_quantity, 70)
        self.assertEqual(batch.remaining_usable_stock, 70)

        # Check ledger record
        ledger = InventoryTransactionLedger.objects.filter(production_batch=batch, transaction_type='STOCK_TRANSFER_OUT').first()
        self.assertIsNotNone(ledger)
        self.assertEqual(ledger.quantity, Decimal('-30'))
        self.assertEqual(ledger.balance_after, Decimal('70'))

    def test_stock_adjustment_damage_and_returns_with_mandatory_reasons(self):
        """Verify stock adjustments for damage, return, and expiry with mandatory audit reasons."""
        now = timezone.now().date()
        batch = ProductionBatch.objects.create(
            batch_number='PB-ADJUST-003',
            product=self.product,
            quantity_produced_units=100,
            quantity_remaining_company=100,
            manufacture_date=now,
            expiry_date=now + timedelta(days=45),
            status='ACTIVE'
        )

        # Reason is mandatory
        with self.assertRaises(ValidationError):
            adjust_production_batch_atomic(
                batch_id=batch.id,
                adjustment_type='DAMAGE',
                quantity=5,
                reason='',
                actor=self.admin_user
            )

        # Record 5 Damaged units
        adjust_production_batch_atomic(
            batch_id=batch.id,
            adjustment_type='DAMAGE',
            quantity=5,
            reason='Cap seal ruptured during plant handling',
            actor=self.admin_user
        )
        batch.refresh_from_db()
        self.assertEqual(batch.quantity_damaged, 5)
        self.assertEqual(batch.quantity_remaining_company, 95)

        # Record 2 Returned units
        adjust_production_batch_atomic(
            batch_id=batch.id,
            adjustment_type='RETURN',
            quantity=2,
            reason='Customer cancelled 2 jars upon arrival',
            actor=self.admin_user
        )
        batch.refresh_from_db()
        self.assertEqual(batch.quantity_returned, 2)
        self.assertEqual(batch.quantity_remaining_company, 97)

        # Verify adjustment API endpoint
        url = f'/api/inventory/production-batches/{batch.id}/adjustment/'
        response = self.client.post(url, {
            'adjustment_type': 'EXPIRY',
            'quantity': 3,
            'reason': 'Quality check expired 3 test jars'
        }, format='json')
        self.assertEqual(response.status_code, 200)

        batch.refresh_from_db()
        self.assertEqual(batch.quantity_expired, 3)

        # Verify history API endpoint returns complete chronological log
        history_url = f'/api/inventory/production-batches/{batch.id}/history/'
        hist_resp = self.client.get(history_url)
        self.assertEqual(hist_resp.status_code, 200)
        history_entries = hist_resp.data.get('history') or hist_resp.data.get('data', {}).get('history', [])
        self.assertGreaterEqual(len(history_entries), 3)

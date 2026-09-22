"""
Authoritative E2E Test Suite for Pending/Uncollected Stock Approaching Expiry Alert
and Pre-Dispatch vs Post-Delivery Order Cancellation Safety.
"""
import os
import sys
import django
from decimal import Decimal
from datetime import date, timedelta

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from django.contrib.auth.models import User
from django.utils import timezone
from django.test import TestCase

from accounts.models import UserProfile, FranchiseProfile, AdminNotification
from accounts.services import apply_data_scope
from products.models import Product
from inventory.models import (
    ProductionBatch,
    DealerStockRequest,
    DealerStockRequestAllocation,
    InventoryTransactionLedger,
    ExpiryAlertLog,
)
from orders.models import Order, OrderItem, OrderItemBatchReservation
from inventory.services import (
    get_pending_stock_expiry_alerts,
    dispatch_order_atomic,
    deliver_order_atomic,
    cancel_order_atomic,
)


class PendingStockExpiryAndCancellationTestCase(TestCase):
    def setUp(self):
        self.today = timezone.now().date()
        self.created_objects = []

        # Cleanup existing test records if any
        DealerStockRequestAllocation.objects.filter(stock_request__request_number__in=['ORD-1025', 'ORD-MULTI-BATCH']).delete()
        DealerStockRequest.objects.filter(request_number__in=['ORD-1025', 'ORD-MULTI-BATCH']).delete()
        OrderItemBatchReservation.objects.filter(order_item__order_id=1025).delete()
        OrderItemBatchReservation.objects.filter(order_item__order__created_by__username='test_super_owner').delete()
        OrderItem.objects.filter(order__created_by__username='test_super_owner').delete()
        Order.objects.filter(id=1025).delete()
        Order.objects.filter(created_by__username='test_super_owner').delete()
        ProductionBatch.objects.filter(batch_number__in=['SHV-500-2026-00125', 'BATCH-A-EARLY', 'BATCH-B-LATER', 'BATCH-CANCEL-TEST']).delete()

        # Super Admin
        self.super_admin_user, _ = User.objects.get_or_create(
            username='test_super_owner',
            defaults={'email': 'owner@shivnath.com', 'is_superuser': True}
        )
        self.super_admin_prof, _ = UserProfile.objects.get_or_create(
            user=self.super_admin_user,
            defaults={'role': 'super_admin', 'data_scope_type': 'all_data'}
        )

        # Scoped Admin (Territory scoped: 'RAIPUR')
        self.scoped_admin_user, _ = User.objects.get_or_create(
            username='test_raipur_admin',
            defaults={'email': 'raipur_admin@shivnath.com', 'is_superuser': False}
        )
        self.scoped_admin_user.is_superuser = False
        self.scoped_admin_user.save()
        self.scoped_admin_prof, _ = UserProfile.objects.get_or_create(
            user=self.scoped_admin_user,
            defaults={
                'role': 'admin',
                'data_scope_type': 'territory_scoped',
                'assigned_scope_ids': ['RAIPUR']
            }
        )
        self.scoped_admin_prof.role = 'admin'
        self.scoped_admin_prof.data_scope_type = 'territory_scoped'
        self.scoped_admin_prof.assigned_scope_ids = ['RAIPUR']
        self.scoped_admin_prof.save()

        # Other Admin (Territory scoped: 'BILASPUR')
        self.other_admin_user, _ = User.objects.get_or_create(
            username='test_bilaspur_admin',
            defaults={'email': 'bilaspur_admin@shivnath.com', 'is_superuser': False}
        )
        self.other_admin_user.is_superuser = False
        self.other_admin_user.save()
        self.other_admin_prof, _ = UserProfile.objects.get_or_create(
            user=self.other_admin_user,
            defaults={
                'role': 'admin',
                'data_scope_type': 'territory_scoped',
                'assigned_scope_ids': ['BILASPUR']
            }
        )
        self.other_admin_prof.role = 'admin'
        self.other_admin_prof.data_scope_type = 'territory_scoped'
        self.other_admin_prof.assigned_scope_ids = ['BILASPUR']
        self.other_admin_prof.save()

        # Dealer in Raipur
        self.dealer_user, _ = User.objects.get_or_create(
            username='dealer_xyz',
            defaults={'email': 'dealer_xyz@shivnath.com'}
        )
        self.dealer_prof, _ = FranchiseProfile.objects.get_or_create(
            user=self.dealer_user,
            defaults={
                'business_name': 'XYZ Wholesale Dealer',
                'city': 'RAIPUR',
                'territory': 'RAIPUR',
                'status': 'approved'
            }
        )
        self.dealer_prof.city = 'RAIPUR'
        self.dealer_prof.territory = 'RAIPUR'
        self.dealer_prof.save()

        # Official 500 ML Product
        self.product, _ = Product.objects.get_or_create(
            sku='SKU-BOT-500',
            defaults={
                'name': '500 ML Bottle',
                'volume_ml': 500,
                'package_type': 'BOTTLE',
                'status': 'Active',
                'shelf_life_days': 180,
                'price': Decimal('100.00'),
                'dealer_transfer_price': Decimal('80.00'),
                'mrp': Decimal('120.00'),
            }
        )

    def test_01_pending_stock_expiry_scenario_exact(self):
        """
        Scenario from user prompt:
        Allocated = 5,000
        Collected = 2,000
        Pending = 3,000
        Expiry is approaching (e.g. 15 days).
        - ADMIN receives alert with pending = 3,000.
        - SUPER_ADMIN receives alert with pending = 3,000.
        - Other territory admin does NOT receive alert (scoped).
        """
        # Batch expiring in 15 days
        exp_date = self.today + timedelta(days=15)
        batch = ProductionBatch.objects.create(
            product=self.product,
            batch_number='SHV-500-2026-00125',
            manufacture_date=self.today - timedelta(days=30),
            expiry_date=exp_date,
            quantity_produced_units=10000,
            quantity_remaining_company=10000,
            unit_production_cost=Decimal('50.00'),
            status='ACTIVE'
        )

        # Stock request of 5000 units
        stock_req = DealerStockRequest.objects.create(
            request_number='ORD-1025',
            dealer=self.dealer_prof,
            product=self.product,
            requested_quantity=5000,
            approved_quantity=5000,
            status='DISPATCHED'
        )

        # Allocation: 5,000 allocated, 2,000 collected/received
        alloc = DealerStockRequestAllocation.objects.create(
            stock_request=stock_req,
            production_batch=batch,
            allocated_quantity=5000,
            dispatched_quantity=5000,
            received_quantity=2000,
            damaged_quantity=0
        )

        # 1. Super Admin Query
        super_alerts = [a for a in get_pending_stock_expiry_alerts(user=self.super_admin_user, target_date=self.today) if a['order_number'] == 'ORD-1025']
        self.assertEqual(len(super_alerts), 1)
        alert = super_alerts[0]
        self.assertEqual(alert['pending_quantity'], 3000)
        self.assertEqual(alert['allocated_quantity'], 5000)
        self.assertEqual(alert['collected_quantity'], 2000)
        self.assertEqual(alert['dealer_or_customer'], 'XYZ Wholesale Dealer')
        self.assertEqual(alert['order_number'], 'ORD-1025')
        self.assertEqual(alert['product_name'], self.product.name)
        self.assertEqual(alert['batch_number'], 'SHV-500-2026-00125')
        self.assertEqual(alert['remaining_days'], 15)
        self.assertEqual(alert['alert_level'], '15_DAYS')

        # 2. Scoped Raipur Admin Query (should see it)
        raipur_alerts = [a for a in get_pending_stock_expiry_alerts(user=self.scoped_admin_user, target_date=self.today) if a['order_number'] == 'ORD-1025']
        self.assertEqual(len(raipur_alerts), 1)
        self.assertEqual(raipur_alerts[0]['pending_quantity'], 3000)

        # 3. Scoped Bilaspur Admin Query (should NOT see it - data scoped)
        bilaspur_alerts = [a for a in get_pending_stock_expiry_alerts(user=self.other_admin_user, target_date=self.today) if a['order_number'] == 'ORD-1025']
        self.assertEqual(len(bilaspur_alerts), 0)

        # 4. Partial Collection Update (1,000 more collected -> pending becomes 2,000)
        alloc.received_quantity = 3000
        alloc.save(update_fields=['received_quantity'])

        updated_alerts = [a for a in get_pending_stock_expiry_alerts(user=self.super_admin_user, target_date=self.today) if a['order_number'] == 'ORD-1025']
        self.assertEqual(len(updated_alerts), 1)
        self.assertEqual(updated_alerts[0]['pending_quantity'], 2000)
        self.assertEqual(updated_alerts[0]['collected_quantity'], 3000)

        # 5. Full Collection (Remaining 2,000 collected -> pending = 0)
        alloc.received_quantity = 5000
        alloc.save(update_fields=['received_quantity'])

        cleared_alerts = [a for a in get_pending_stock_expiry_alerts(user=self.super_admin_user, target_date=self.today) if a['order_number'] == 'ORD-1025']
        self.assertEqual(len(cleared_alerts), 0, "Alert must automatically stop when pending stock reaches zero!")

    def test_02_multi_batch_pending_expiry(self):
        """
        Multi-batch scenario:
        Batch A: 1,000 units expiring in 10 days
        Batch B: 2,000 units expiring in 25 days
        Must show separate batch warnings, earliest expiring first.
        """
        batch_a = ProductionBatch.objects.create(
            product=self.product,
            batch_number='BATCH-A-EARLY',
            manufacture_date=self.today - timedelta(days=20),
            expiry_date=self.today + timedelta(days=10),
            quantity_produced_units=5000,
            quantity_remaining_company=5000,
            unit_production_cost=Decimal('50.00'),
            status='ACTIVE'
        )
        batch_b = ProductionBatch.objects.create(
            product=self.product,
            batch_number='BATCH-B-LATER',
            manufacture_date=self.today - timedelta(days=10),
            expiry_date=self.today + timedelta(days=25),
            quantity_produced_units=5000,
            quantity_remaining_company=5000,
            unit_production_cost=Decimal('50.00'),
            status='ACTIVE'
        )

        stock_req = DealerStockRequest.objects.create(
            request_number='ORD-MULTI-BATCH',
            dealer=self.dealer_prof,
            product=self.product,
            requested_quantity=3000,
            approved_quantity=3000,
            status='APPROVED'
        )

        DealerStockRequestAllocation.objects.create(
            stock_request=stock_req,
            production_batch=batch_b,
            allocated_quantity=2000,
            received_quantity=0
        )
        DealerStockRequestAllocation.objects.create(
            stock_request=stock_req,
            production_batch=batch_a,
            allocated_quantity=1000,
            received_quantity=0
        )

        alerts = [a for a in get_pending_stock_expiry_alerts(user=self.super_admin_user, target_date=self.today) if a['order_number'] == 'ORD-MULTI-BATCH']
        self.assertEqual(len(alerts), 2)
        # Verify earliest batch (10 days) is first
        self.assertEqual(alerts[0]['batch_number'], 'BATCH-A-EARLY')
        self.assertEqual(alerts[0]['remaining_days'], 10)
        self.assertEqual(alerts[0]['pending_quantity'], 1000)

        self.assertEqual(alerts[1]['batch_number'], 'BATCH-B-LATER')
        self.assertEqual(alerts[1]['remaining_days'], 25)
        self.assertEqual(alerts[1]['pending_quantity'], 2000)

    def test_03_order_cancellation_pre_dispatch_vs_post_delivery(self):
        """
        Verify cancellation rules:
        - Pre-dispatch: soft reservation is released; NO sale/return ledger.
        - Post-delivery: inventory is returned; RETURN ledger entry is created.
        """
        batch = ProductionBatch.objects.create(
            product=self.product,
            batch_number='BATCH-CANCEL-TEST',
            manufacture_date=self.today - timedelta(days=10),
            expiry_date=self.today + timedelta(days=90),
            quantity_produced_units=1000,
            quantity_remaining_company=1000,
            reserved_quantity=100,
            unit_production_cost=Decimal('50.00'),
            status='ACTIVE'
        )

        # Case A: Pre-dispatch order
        order_pre = Order.objects.create(
            created_by=self.super_admin_user,
            order_source='DIRECT_COMPANY',
            city='RAIPUR',
            status='plant_approval'
        )
        item_pre = OrderItem.objects.create(
            order=order_pre,
            product=self.product,
            product_name=self.product.name,
            quantity=100,
            unit_price=Decimal('120.00'),
            total_price=Decimal('12000.00')
        )
        res_pre = OrderItemBatchReservation.objects.create(
            order_item=item_pre,
            production_batch=batch,
            reserved_quantity=100,
            consumed_quantity=0,
            released_quantity=0
        )

        cancel_order_atomic(order_pre, actor=self.super_admin_user)

        res_pre.refresh_from_db()
        batch.refresh_from_db()
        self.assertEqual(res_pre.released_quantity, 100)
        self.assertEqual(batch.reserved_quantity, 0, "Soft reservation must be released on pre-dispatch cancellation")
        self.assertFalse(
            InventoryTransactionLedger.objects.filter(reference_id=str(order_pre.id)).exists(),
            "Pre-dispatch cancellation must not create ledger transaction"
        )

        # Case B: Post-delivery order
        batch.quantity_remaining_company = 500
        batch.reserved_quantity = 50
        batch.save()

        order_post = Order.objects.create(
            created_by=self.super_admin_user,
            order_source='DIRECT_COMPANY',
            city='RAIPUR',
            status='preparing'
        )
        item_post = OrderItem.objects.create(
            order=order_post,
            product=self.product,
            product_name=self.product.name,
            quantity=50,
            unit_price=Decimal('120.00'),
            total_price=Decimal('6000.00')
        )
        res_post = OrderItemBatchReservation.objects.create(
            order_item=item_post,
            production_batch=batch,
            reserved_quantity=50,
            consumed_quantity=0,
            released_quantity=0
        )

        # Dispatch and deliver
        dispatch_order_atomic(order_post, actor=self.super_admin_user)
        deliver_order_atomic(order_post, actor=self.super_admin_user)

        batch.refresh_from_db()
        self.assertEqual(batch.quantity_remaining_company, 450)

        # Now cancel delivered order -> must produce RETURN ledger
        cancel_order_atomic(order_post, actor=self.super_admin_user)

        batch.refresh_from_db()
        self.assertEqual(batch.quantity_remaining_company, 500, "Inventory must be restocked on post-delivery cancellation")
        return_ledger = InventoryTransactionLedger.objects.filter(
            transaction_type='RETURN',
            reference_id=str(order_post.id)
        ).first()
        self.assertIsNotNone(return_ledger, "RETURN transaction must be written to ledger for cancelled delivered order")
        self.assertEqual(return_ledger.quantity, Decimal('50.00'))


if __name__ == '__main__':
    import unittest
    suite = unittest.TestLoader().loadTestsFromTestCase(PendingStockExpiryAndCancellationTestCase)
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    sys.exit(0 if result.wasSuccessful() else 1)

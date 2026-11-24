import json
from decimal import Decimal
from datetime import date, timedelta
from django.test import TestCase
from django.contrib.auth import get_user_model
from django.utils import timezone
from rest_framework.test import APIClient
from rest_framework import status

from accounts.models import FranchiseProfile, ServiceZone, UserProfile
from products.models import Product
from orders.models import Order, OrderItem, OrderStatusHistory, OrderItemBatchReservation
from inventory.models import ProductionBatch
from inventory.services import reserve_order_stock_fefo_atomic
from orders.wallet_services import get_or_create_wallet, redeem_points_for_order
from billing.models import DeliveryOriginSetting, DeliveryDistanceBand

User = get_user_model()


class OrderManufacturingAndCheckoutSuite(TestCase):
    def setUp(self):
        self.client = APIClient()

        # Admin user
        self.admin_user = User.objects.create_superuser(
            username='admin_test',
            password='Password@123',
            email='admin@shivnath.com'
        )
        UserProfile.objects.update_or_create(
            user=self.admin_user,
            defaults={'role': 'super_admin', 'phone': '9999999990', 'status': 'active'}
        )

        # Customer user
        self.customer = User.objects.create_user(
            username='cust_sangam',
            password='Password@123',
            email='sangam@test.com'
        )
        UserProfile.objects.update_or_create(
            user=self.customer,
            defaults={'role': 'customer', 'phone': '8982922423', 'status': 'active'}
        )

        # Product
        self.product = Product.objects.create(
            name='Shivnath 20 Litre Dispenser Jar',
            sku='JAR-20L-TEST-01',
            size='20L',
            category='Jar',
            package_type='JAR',
            volume_ml=20000,
            units_per_case=1,
            price=Decimal('80.00'),
            dealer_transfer_price=Decimal('45.00'),
            stock=0,
            status='Active',
            shelf_life_days=180
        )

        # Delivery Origin & Distance band for testing
        DeliveryOriginSetting.objects.all().delete()
        DeliveryDistanceBand.objects.all().delete()
        self.origin = DeliveryOriginSetting.objects.create(
            name='Central Dispatch',
            address='Mowa, Raipur',
            latitude=Decimal('21.267800'),
            longitude=Decimal('81.671100'),
            is_active=True
        )
        self.band = DeliveryDistanceBand.objects.create(
            name='Raipur Local (0-15km)',
            min_distance_km=Decimal('0.00'),
            max_distance_km=Decimal('15.00'),
            delivery_charge=Decimal('0.00'),
            is_supported=True,
            is_active=True,
            order=1
        )

    def test_01_customer_order_succeeds_when_inventory_is_zero(self):
        """
        Verify fix for Video Issue 1:
        Customer placing order with 0 non-expired batch stock must NOT be rejected.
        Order must be created with needs_manufacturing=True and total_pending_stock_units=5.
        """
        self.client.force_authenticate(user=self.customer)

        payload = {
            'franchise': 'Shivnath Agency (Direct)',
            'city': 'Raipur',
            'customer_name': 'Sangam',
            'phone': '8982922423',
            'delivery_address': 'c00192, kota, kota, Raipur, 492010, Chhattisgarh',
            'items': 5,
            'amount': 400.0,
            'grand_total': 400.0,
            'status': 'order_placement',
            'payment': 'pending',
            'payment_mode': 'RAZORPAY',
            'order_source': 'DIRECT_COMPANY',
            'order_items': [
                {'product_id': self.product.id, 'quantity': 5, 'price': 80.0}
            ]
        }

        response = self.client.post('/api/orders/', data=payload, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED, response.data)
        self.assertTrue(response.data['success'])

        order_id = response.data.get('id') or response.data['order']['id']
        order = Order.objects.get(id=order_id)

        self.assertTrue(order.needs_manufacturing, "Order should be flagged as needs_manufacturing=True")
        self.assertEqual(order.total_pending_stock_units, 5, "All 5 units should be queued as pending stock")

        # Stock should not become negative
        self.product.refresh_from_db()
        self.assertGreaterEqual(self.product.stock, 0, "Product stock must never become negative")

        # Check OrderStatusHistory contains MANUFACTURING_REQUIRED
        hist = OrderStatusHistory.objects.filter(order=order, reason_category='MANUFACTURING_REQUIRED').first()
        self.assertIsNotNone(hist, "OrderStatusHistory should record reason_category='MANUFACTURING_REQUIRED'")
        self.assertIn("queued for manufacturing fulfillment", hist.notes)

    def test_02_partial_inventory_allocation(self):
        """
        Verify that available batch stock is reserved, and only the remaining shortfall
        is flagged as pending manufacturing.
        """
        # Create a batch with 2 units available
        today = timezone.now().date()
        batch = ProductionBatch.objects.create(
            batch_number='PB-PARTIAL-001',
            product=self.product,
            manufacture_date=today - timedelta(days=2),
            expiry_date=today + timedelta(days=60),
            quantity_produced_units=2,
            quantity_remaining_company=2,
            reserved_quantity=0,
            status='ACTIVE'
        )

        order = Order.objects.create(
            created_by=self.customer,
            client_name='Sangam',
            franchise_name='Shivnath Agency (Direct)',
            order_source='DIRECT_COMPANY',
            amount=Decimal('400.00'),
            grand_total=Decimal('400.00'),
            delivery_address='c00192, kota, Raipur',
            status='order_placement'
        )
        OrderItem.objects.create(
            order=order,
            product=self.product,
            product_name=self.product.name,
            size=self.product.size,
            quantity=5,
            unit_price=Decimal('80.00'),
            total_price=Decimal('400.00')
        )

        # Run atomic FEFO reservation with allow_partial=True
        reserve_order_stock_fefo_atomic(order, allow_partial=True)
        order.refresh_from_db()

        self.assertTrue(order.needs_manufacturing)
        self.assertEqual(order.total_pending_stock_units, 3, "Shortfall of 3 units should be pending")

        # Check reservation
        batch.refresh_from_db()
        self.assertEqual(batch.reserved_quantity, 2, "2 available units must be reserved")
        res = OrderItemBatchReservation.objects.filter(production_batch=batch).first()
        self.assertIsNotNone(res)
        self.assertEqual(res.reserved_quantity, 2)

    def test_03_admin_allocates_completed_batch(self):
        """
        Verify that Admin can allocate a completed manufacturing batch to fulfill
        an order awaiting manufacturing, clearing needs_manufacturing flag.
        """
        self.client.force_authenticate(user=self.admin_user)

        # Create order needing manufacturing
        order = Order.objects.create(
            created_by=self.customer,
            client_name='Sangam',
            franchise_name='Shivnath Agency (Direct)',
            order_source='DIRECT_COMPANY',
            amount=Decimal('400.00'),
            grand_total=Decimal('400.00'),
            delivery_address='Kota, Raipur',
            status='order_placement',
            needs_manufacturing=True,
            total_pending_stock_units=5
        )
        OrderItem.objects.create(
            order=order,
            product=self.product,
            product_name=self.product.name,
            size=self.product.size,
            quantity=5,
            unit_price=Decimal('80.00'),
            total_price=Decimal('400.00')
        )

        # Now manufacturing completes a batch of 10 units
        today = timezone.now().date()
        batch = ProductionBatch.objects.create(
            batch_number='PB-FRESH-001',
            product=self.product,
            manufacture_date=today,
            expiry_date=today + timedelta(days=90),
            quantity_produced_units=10,
            quantity_remaining_company=10,
            reserved_quantity=0,
            status='ACTIVE'
        )

        # Call allocate-batch endpoint
        resp = self.client.post(
            f'/api/orders/{order.id}/allocate-batch/',
            data={'batch_id': batch.id},
            format='json'
        )
        self.assertEqual(resp.status_code, status.HTTP_200_OK, resp.data)
        self.assertTrue(resp.data['success'])
        self.assertEqual(resp.data['allocated_units'], 5)
        self.assertEqual(resp.data['pending_units'], 0)
        self.assertFalse(resp.data['needs_manufacturing'])

        order.refresh_from_db()
        self.assertFalse(order.needs_manufacturing)
        self.assertEqual(order.total_pending_stock_units, 0)
        self.assertEqual(order.status, 'preparing')

    def test_04_admin_hold_reject_mandatory_reason_enforcement(self):
        """
        Verify that Admin Hold and Reject endpoints enforce mandatory reason categories
        and notes, preventing empty or arbitrary state manipulation.
        """
        self.client.force_authenticate(user=self.admin_user)

        order = Order.objects.create(
            created_by=self.customer,
            client_name='Sangam',
            franchise_name='Shivnath Agency (Direct)',
            amount=Decimal('100.00'),
            grand_total=Decimal('100.00'),
            status='order_placement'
        )

        # Hold without category should fail
        resp_hold_fail = self.client.post(f'/api/orders/{order.id}/hold/', data={}, format='json')
        self.assertEqual(resp_hold_fail.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertFalse(resp_hold_fail.data['success'])

        # Hold with valid category & notes should succeed
        resp_hold_ok = self.client.post(
            f'/api/orders/{order.id}/hold/',
            data={'reason_category': 'MANUFACTURING_DELAY', 'notes': 'Raw material jars awaiting delivery'},
            format='json'
        )
        self.assertEqual(resp_hold_ok.status_code, status.HTTP_200_OK)
        order.refresh_from_db()
        self.assertEqual(order.status, 'on_hold')
        self.assertEqual(order.hold_reason_category, 'MANUFACTURING_DELAY')

        # Resume order
        resp_resume = self.client.post(f'/api/orders/{order.id}/resume/', data={}, format='json')
        self.assertEqual(resp_resume.status_code, status.HTTP_200_OK)
        order.refresh_from_db()
        self.assertNotEqual(order.status, 'on_hold')

    def test_05_wallet_order_with_insufficient_stock_succeeds(self):
        """
        Verify that Water Wallet redemption does not raise ValidationError when
        central inventory is insufficient, but queues order for manufacturing.
        """
        wallet = get_or_create_wallet(self.customer)
        wallet.reward_points = 500
        wallet.balance = Decimal('1000.00')
        wallet.save()

        # Product stock is 0 and no batches exist
        result = redeem_points_for_order(
            user=self.customer,
            product_id=self.product.id,
            quantity=5,
            points_to_redeem=100,
            delivery_address='Kota, Raipur'
        )

        self.assertIn('order_id', result)
        order = Order.objects.get(id=result['order_id'])
        self.assertTrue(order.needs_manufacturing, "Wallet order should be flagged for manufacturing")
        self.assertEqual(order.payment_status, 'paid')
        self.assertEqual(order.order_source, 'WATER_WALLET_REDEMPTION')

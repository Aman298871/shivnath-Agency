import json
from decimal import Decimal
from datetime import date, timedelta
from django.test import TestCase
from django.contrib.auth import get_user_model
from django.utils import timezone
from rest_framework.test import APIClient
from rest_framework import status

from accounts.models import FranchiseProfile, ServiceZone, UserProfile
from products.models import Product, MinimumOrderPackagingRule
from orders.models import Order, OrderItem, OrderStatusHistory, OrderItemBatchReservation
from inventory.models import ProductionBatch
from inventory.services import reserve_order_stock_fefo_atomic
from billing.models import DeliveryOriginSetting, DeliveryDistanceBand

User = get_user_model()


class CustomerStockVisibilityAndFulfillmentTest(TestCase):
    def setUp(self):
        self.client = APIClient()

        # Super Admin
        self.admin = User.objects.create_superuser(
            username='admin_boss',
            password='Password@123',
            email='admin_boss@shivnath.com'
        )
        UserProfile.objects.update_or_create(
            user=self.admin,
            defaults={'role': 'super_admin', 'phone': '9999999990', 'status': 'active'}
        )

        # Customer A
        self.customer_a = User.objects.create_user(
            username='customer_a',
            password='Password@123',
            email='customer_a@test.com'
        )
        UserProfile.objects.update_or_create(
            user=self.customer_a,
            defaults={'role': 'customer', 'phone': '9876543210', 'status': 'active', 'city': 'Raipur', 'locality': 'Mowa'}
        )

        # Customer B
        self.customer_b = User.objects.create_user(
            username='customer_b',
            password='Password@123',
            email='customer_b@test.com'
        )
        UserProfile.objects.update_or_create(
            user=self.customer_b,
            defaults={'role': 'customer', 'phone': '9876543211', 'status': 'active', 'city': 'Bhilai', 'locality': 'Sector 6'}
        )

        # Active Product with 0 physical stock
        self.zero_stock_product = Product.objects.create(
            name='Shivnath 20 Litre Dispenser Jar',
            sku='SHV-20L-TEST',
            size='20L',
            category='Jar',
            package_type='JAR',
            volume_ml=20000,
            units_per_case=1,
            price=Decimal('80.00'),
            dealer_transfer_price=Decimal('45.00'),
            stock=0,  # Zero stock
            status='Active',
            shelf_life_days=180
        )

        # Baseline Packaging Rule (MOQ 5)
        MinimumOrderPackagingRule.objects.create(
            product=self.zero_stock_product,
            franchise=None,
            min_order_quantity=5,
            sales_unit='JAR',
            allow_franchise_override=True,
            is_active=True
        )

        # Inactive / Discontinued Product
        self.inactive_product = Product.objects.create(
            name='Discontinued Bottle 500ml',
            sku='SHV-500-DISC',
            size='500ml',
            category='Bottle',
            price=Decimal('20.00'),
            stock=100,
            status='Inactive',
        )

        # Delivery Origin Setting and Distance Band
        DeliveryOriginSetting.objects.all().delete()
        DeliveryDistanceBand.objects.all().delete()
        self.origin = DeliveryOriginSetting.objects.create(
            name='Shivnath Agency Central Dispatch',
            address='Ekta Nagar, Pragati Nagar, LIC Colony, near Mowa Thana, Raipur, Chhattisgarh',
            latitude=Decimal('21.267800'),
            longitude=Decimal('81.671100'),
            is_active=True
        )
        self.band = DeliveryDistanceBand.objects.create(
            name='Local Raipur (0-50 km)',
            min_distance_km=Decimal('0.00'),
            max_distance_km=Decimal('50.00'),
            delivery_charge=Decimal('0.00'),
            is_supported=True,
            is_active=True,
            order=1
        )

    def _make_payload(self, product_id, qty, cust_name='Customer A', phone='9876543210'):
        return {
            'franchise': 'Shivnath Agency (Direct)',
            'city': 'Raipur',
            'customer_name': cust_name,
            'phone': phone,
            'delivery_address': 'Flat 101, Mowa, Raipur, 492010, Chhattisgarh',
            'payment': 'pending',
            'payment_mode': 'RAZORPAY',
            'order_source': 'DIRECT_COMPANY',
            'items': [
                {'product_id': product_id, 'quantity': qty, 'price': 80.0}
            ],
        }

    def test_01_customer_places_order_when_stock_is_zero(self):
        """Customer places an order when product stock is 0 - must SUCCEED."""
        self.client.force_authenticate(user=self.customer_a)
        payload = self._make_payload(self.zero_stock_product.id, 5)
        res = self.client.post('/api/orders/', data=payload, format='json')
        self.assertEqual(res.status_code, status.HTTP_201_CREATED, res.data)
        self.assertTrue(res.data['success'])
        order_id = res.data.get('id') or res.data['order']['id']

        # Verify order exists and is flagged for manufacturing/replenishment
        order = Order.objects.get(id=order_id)
        self.assertEqual(order.status, 'order_placement')
        self.assertTrue(order.needs_manufacturing)

        # CRITICAL: Product stock must NOT be decremented below 0
        self.zero_stock_product.refresh_from_db()
        self.assertEqual(self.zero_stock_product.stock, 0)

        # No premature batch reservations created
        self.assertEqual(order.items.first().batch_reservations.count(), 0)

    def test_02_customer_places_order_when_stock_is_less_than_requested(self):
        """Customer orders 10 units when only 3 units of stock exist - must SUCCEED without stock decrement."""
        self.zero_stock_product.stock = 3
        self.zero_stock_product.save(update_fields=['stock'])

        self.client.force_authenticate(user=self.customer_a)
        payload = self._make_payload(self.zero_stock_product.id, 10)
        res = self.client.post('/api/orders/', data=payload, format='json')
        self.assertEqual(res.status_code, status.HTTP_201_CREATED, res.data)
        self.assertTrue(res.data['success'])

        # Stock must remain unchanged at 3 because physical allocation hasn't happened
        self.zero_stock_product.refresh_from_db()
        self.assertEqual(self.zero_stock_product.stock, 3)

    def test_03_customer_cannot_order_inactive_discontinued_product(self):
        """Legitimate business restriction: Inactive/discontinued products must be blocked."""
        self.client.force_authenticate(user=self.customer_a)
        payload = self._make_payload(self.inactive_product.id, 5)
        res = self.client.post('/api/orders/', data=payload, format='json')
        self.assertEqual(res.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertFalse(res.data['success'])
        self.assertEqual(res.data.get('error_code'), 'PRODUCT_DISCONTINUED')

    def test_04_customer_moq_restriction_enforced_independent_of_stock(self):
        """MOQ restriction (< 5 jars) is enforced even though stock availability is hidden."""
        self.client.force_authenticate(user=self.customer_a)
        payload = self._make_payload(self.zero_stock_product.id, 2)  # MOQ is 5
        res = self.client.post('/api/orders/', data=payload, format='json')
        self.assertEqual(res.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertFalse(res.data['success'])
        self.assertEqual(res.data.get('error_code'), 'PACKAGING_RULE_VIOLATION')

    def test_05_hold_requires_reason_and_persists_for_customer(self):
        """Admin placing order on hold requires category and notes, and customer sees them."""
        # Create order
        self.client.force_authenticate(user=self.customer_a)
        payload = self._make_payload(self.zero_stock_product.id, 5)
        res = self.client.post('/api/orders/', data=payload, format='json')
        order_id = res.data.get('id') or res.data['order']['id']

        # Admin tries to hold without reason - must fail
        self.client.force_authenticate(user=self.admin)
        res_fail = self.client.patch(f'/api/orders/{order_id}/status/', data={
            'status': 'on_hold',
        }, format='json')
        self.assertEqual(res_fail.status_code, status.HTTP_400_BAD_REQUEST)

        # Admin holds with reason category and details
        dispatch_target = (date.today() + timedelta(days=2)).isoformat()
        res_hold = self.client.patch(f'/api/orders/{order_id}/status/', data={
            'status': 'on_hold',
            'reason_category': 'MANUFACTURING_REQUIRED',
            'notes': 'Fresh RO bottling run in progress for high-grade purity batch.',
            'expected_dispatch_date': dispatch_target,
        }, format='json')
        self.assertEqual(res_hold.status_code, status.HTTP_200_OK)
        self.assertTrue(res_hold.data['success'])

        # Customer A retrieves order details - must see status, reason and expected date
        self.client.force_authenticate(user=self.customer_a)
        res_cust = self.client.get(f'/api/orders/{order_id}/')
        self.assertEqual(res_cust.status_code, status.HTTP_200_OK)
        data = res_cust.data.get('order') or res_cust.data
        self.assertEqual(data['status'], 'on_hold')
        self.assertEqual(data['hold_reason'], 'Fresh RO bottling run in progress for high-grade purity batch.')
        self.assertEqual(data['hold_reason_category'], 'MANUFACTURING_REQUIRED')
        self.assertEqual(data['expected_dispatch_date'], dispatch_target)
        self.assertIn('Fresh RO bottling run', data['customer_status_message'])

    def test_06_rejection_requires_reason_and_persists_for_customer(self):
        """Admin rejecting order requires category and explanation, customer sees explanation."""
        # Create order
        self.client.force_authenticate(user=self.customer_a)
        payload = self._make_payload(self.zero_stock_product.id, 5)
        res = self.client.post('/api/orders/', data=payload, format='json')
        order_id = res.data.get('id') or res.data['order']['id']

        # Admin rejects with explanation
        self.client.force_authenticate(user=self.admin)
        res_rej = self.client.patch(f'/api/orders/{order_id}/status/', data={
            'status': 'rejected',
            'reason_category': 'OUT_OF_SERVICE_AREA',
            'notes': 'Delivery pin code is inaccessible due to bridge maintenance.',
        }, format='json')
        self.assertEqual(res_rej.status_code, status.HTTP_200_OK)

        # Customer A views order - must remain visible in history with reason
        self.client.force_authenticate(user=self.customer_a)
        res_cust = self.client.get(f'/api/orders/{order_id}/')
        self.assertEqual(res_cust.status_code, status.HTTP_200_OK)
        data = res_cust.data.get('order') or res_cust.data
        self.assertEqual(data['status'], 'rejected')
        self.assertEqual(data['rejection_reason'], 'Delivery pin code is inaccessible due to bridge maintenance.')
        self.assertIn('bridge maintenance', data['customer_status_message'])

    def test_07_delay_reason_and_timeline_persist_for_customer(self):
        """Delay reason and revised delivery date persist and are returned in customer serializer."""
        # Create order
        self.client.force_authenticate(user=self.customer_a)
        payload = self._make_payload(self.zero_stock_product.id, 5)
        res = self.client.post('/api/orders/', data=payload, format='json')
        order_id = res.data.get('id') or res.data['order']['id']

        # Admin updates order with delay
        revised = (date.today() + timedelta(days=3)).isoformat()
        self.client.force_authenticate(user=self.admin)
        res_delay = self.client.patch(f'/api/orders/{order_id}/status/', data={
            'status': 'preparing',
            'is_delayed': True,
            'delay_reason': 'Monsoon traffic delay along Ring Road bypass.',
            'revised_delivery_date': revised,
        }, format='json')
        self.assertEqual(res_delay.status_code, status.HTTP_200_OK)

        # Customer views delay info
        self.client.force_authenticate(user=self.customer_a)
        res_cust = self.client.get(f'/api/orders/{order_id}/')
        self.assertEqual(res_cust.status_code, status.HTTP_200_OK)
        data = res_cust.data.get('order') or res_cust.data
        self.assertTrue(data['is_delayed'])
        self.assertEqual(data['delay_reason'], 'Monsoon traffic delay along Ring Road bypass.')
        self.assertEqual(data['revised_delivery_date'], revised)

    def test_08_customer_a_cannot_view_customer_b_order(self):
        """Cross-tenant security: Customer A cannot view Customer B's order or reasons."""
        # Customer B places order
        self.client.force_authenticate(user=self.customer_b)
        payload = self._make_payload(self.zero_stock_product.id, 5, cust_name='Customer B', phone='9876543211')
        res_b = self.client.post('/api/orders/', data=payload, format='json')
        order_b_id = res_b.data.get('id') or res_b.data['order']['id']

        # Customer A attempts to access Customer B's order
        self.client.force_authenticate(user=self.customer_a)
        res_hack = self.client.get(f'/api/orders/{order_b_id}/')
        self.assertIn(res_hack.status_code, [status.HTTP_403_FORBIDDEN, status.HTTP_404_NOT_FOUND])

    def test_09_unauthorized_user_cannot_update_order_status(self):
        """Non-admin customer cannot hold or update order status."""
        self.client.force_authenticate(user=self.customer_a)
        payload = self._make_payload(self.zero_stock_product.id, 5)
        res = self.client.post('/api/orders/', data=payload, format='json')
        order_id = res.data.get('id') or res.data['order']['id']

        # Normal customer tries to transition status
        res_unauth = self.client.patch(f'/api/orders/{order_id}/status/', data={'status': 'on_hold'}, format='json')
        self.assertEqual(res_unauth.status_code, status.HTTP_403_FORBIDDEN)

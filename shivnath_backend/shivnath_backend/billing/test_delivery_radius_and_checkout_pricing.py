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
from accounts.models import FranchiseProfile
from billing.models import (
    DeliveryOriginSetting,
    DeliveryDistanceBand,
)
from billing.delivery_services import (
    calculate_haversine_distance,
    get_authoritative_delivery_charge,
    resolve_address_coordinates,
)

User = get_user_model()


class DeliveryRadiusAndCheckoutPricingTestCase(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.admin = User.objects.create_superuser(
            username='admin_delivery_test',
            email='admin_deliv@example.com',
            password='adminpassword123'
        )
        self.customer = User.objects.create_user(
            username='cust_9999999991',
            email='cust_deliv@example.com',
            password='customerpassword123'
        )
        self.franchise_user = User.objects.create_user(
            username='fran_user_1',
            email='fran_user@example.com',
            password='franchisepassword123'
        )
        self.franchise = FranchiseProfile.objects.create(
            user=self.franchise_user,
            dealer_code='DLR-MOWA-001',
            business_name='Mowa Authorized Franchise',
            city='Raipur',
            address='Mowa Market, Raipur',
            status='approved'
        )

        self.category = ProductCategory.objects.create(name='Packaged Drinking Water')
        self.product = Product.objects.create(
            name='Shivnath 20L Water Can',
            sku='SHV-20L-TEST',
            category_ref=self.category,
            price=Decimal('80.00'),
            size='20L',
            stock=100
        )
        self.batch = ProductionBatch.objects.create(
            batch_number='PB-DELIV-TEST-001',
            product=self.product,
            manufacture_date=timezone.now().date(),
            expiry_date=timezone.now().date() + timedelta(days=90),
            quantity_produced_units=500,
            quantity_remaining_company=500,
            reserved_quantity=0,
            unit_production_cost=Decimal('30.00'),
            status='ACTIVE'
        )

        # Clear existing origin and distance bands to start from known state
        DeliveryOriginSetting.objects.all().delete()
        DeliveryDistanceBand.objects.all().delete()

        # Create Shivnath Agencies origin: Ekta Nagar, Pragati Nagar, LIC Colony, near Mowa Thana, Raipur
        self.origin = DeliveryOriginSetting.objects.create(
            name='Shivnath Agency Central Dispatch',
            address='Ekta Nagar, Pragati Nagar, LIC Colony, near Mowa Thana, Raipur, Chhattisgarh',
            latitude=Decimal('21.267800'),
            longitude=Decimal('81.671100'),
            is_active=True
        )

        # Create standard distance slabs
        # 0 to 5 km: ₹20.00
        self.band_0_5 = DeliveryDistanceBand.objects.create(
            name='Local Raipur (0-5 km)',
            min_distance_km=Decimal('0.00'),
            max_distance_km=Decimal('5.00'),
            delivery_charge=Decimal('20.00'),
            is_supported=True,
            is_active=True,
            order=1
        )
        # 5 to 10 km: ₹40.00
        self.band_5_10 = DeliveryDistanceBand.objects.create(
            name='Extended Raipur (5-10 km)',
            min_distance_km=Decimal('5.00'),
            max_distance_km=Decimal('10.00'),
            delivery_charge=Decimal('40.00'),
            is_supported=True,
            is_active=True,
            order=2
        )
        # 10 to 15 km: ₹70.00
        self.band_10_15 = DeliveryDistanceBand.objects.create(
            name='Outer Raipur (10-15 km)',
            min_distance_km=Decimal('10.00'),
            max_distance_km=Decimal('15.00'),
            delivery_charge=Decimal('70.00'),
            is_supported=True,
            is_active=True,
            order=3
        )

    def test_01_configured_origin_and_coordinates(self):
        """Verify delivery origin address and coordinates match Shivnath Agencies central dispatch."""
        active_origin = DeliveryOriginSetting.get_active_origin()
        self.assertIsNotNone(active_origin)
        self.assertIn('Ekta Nagar', active_origin.address)
        self.assertIn('Mowa Thana', active_origin.address)
        self.assertEqual(float(active_origin.latitude), 21.2678)
        self.assertEqual(float(active_origin.longitude), 81.6711)

    def test_02_distance_calculation_within_slabs(self):
        """Test delivery charge calculation for destinations in each configured distance slab."""
        # Destination 1: Mowa Thana (~0.2 km -> 0-5 km slab -> ₹20)
        calc_mowa = get_authoritative_delivery_charge(
            dest_latitude=21.2680,
            dest_longitude=81.6715
        )
        self.assertTrue(calc_mowa['is_supported'])
        self.assertFalse(calc_mowa.get('is_blocked', False))
        self.assertEqual(calc_mowa['delivery_charge'], Decimal('20.00'))
        self.assertLess(float(calc_mowa['distance_km']), 1.0)
        self.assertEqual(calc_mowa['band_name'], 'Local Raipur (0-5 km)')

        # Destination 2: Pandri Raipur (~2.6 km -> 0-5 km slab -> ₹20)
        calc_pandri = get_authoritative_delivery_charge(
            dest_latitude=21.2530,
            dest_longitude=81.6560
        )
        self.assertTrue(calc_pandri['is_supported'])
        self.assertEqual(calc_pandri['delivery_charge'], Decimal('20.00'))
        self.assertGreater(float(calc_pandri['distance_km']), 1.0)
        self.assertLess(float(calc_pandri['distance_km']), 5.0)

        # Destination 3: Mana VIP Road Raipur (~6.7 km -> 5-10 km slab -> ₹40)
        calc_mana = get_authoritative_delivery_charge(
            dest_latitude=21.2100,
            dest_longitude=81.6900
        )
        self.assertTrue(calc_mana['is_supported'])
        self.assertEqual(calc_mana['delivery_charge'], Decimal('40.00'))
        self.assertGreater(float(calc_mana['distance_km']), 5.0)
        self.assertLess(float(calc_mana['distance_km']), 10.0)
        self.assertEqual(calc_mana['band_name'], 'Extended Raipur (5-10 km)')

        # Destination 4: Tatibandh Raipur (~11.8 km -> 10-15 km slab -> ₹70)
        calc_tati = get_authoritative_delivery_charge(
            dest_latitude=21.2630,
            dest_longitude=81.5570
        )
        self.assertTrue(calc_tati['is_supported'])
        self.assertEqual(calc_tati['delivery_charge'], Decimal('70.00'))
        self.assertGreater(float(calc_tati['distance_km']), 10.0)
        self.assertLessEqual(float(calc_tati['distance_km']), 15.0)
        self.assertEqual(calc_tati['band_name'], 'Outer Raipur (10-15 km)')

    def test_03_address_beyond_serviceable_radius(self):
        """Addresses beyond 15 km or max radius must be rejected as unsupported, not silently charged zero."""
        # Durg / Bhilai (~35 km)
        calc_durg = get_authoritative_delivery_charge(
            dest_latitude=21.1900,
            dest_longitude=81.2800
        )
        self.assertFalse(calc_durg['is_supported'])
        self.assertEqual(calc_durg['error_code'], 'DELIVERY_UNSUPPORTED')
        self.assertGreater(float(calc_durg['distance_km']), 15.0)
        self.assertIn('outside our maximum serviceable delivery radius', calc_durg['message'])

    def test_04_origin_blocked_when_unconfigured_or_inactive(self):
        """When origin is inactive, configuration is flagged as BLOCKED without fabricating a fee."""
        self.origin.is_active = False
        self.origin.save()

        calc = get_authoritative_delivery_charge(dest_latitude=21.2680, dest_longitude=81.6715)
        self.assertFalse(calc['is_supported'])
        self.assertTrue(calc['is_blocked'])
        self.assertEqual(calc['error_code'], 'ORIGIN_CONFIGURATION_BLOCKED')
        self.assertIn('not configured or inactive', calc['message'])

    def test_05_pricing_bands_blocked_when_missing(self):
        """When no active pricing bands exist, configuration is flagged as BLOCKED."""
        DeliveryDistanceBand.objects.all().update(is_active=False)

        calc = get_authoritative_delivery_charge(dest_latitude=21.2680, dest_longitude=81.6715)
        self.assertFalse(calc['is_supported'])
        self.assertTrue(calc['is_blocked'])
        self.assertEqual(calc['error_code'], 'PRICING_BANDS_BLOCKED')
        self.assertIn('No active delivery distance pricing bands', calc['message'])

    def test_06_address_geocoding_resolution(self):
        """Curated Raipur areas resolve to exact coordinates without external API dependency."""
        coords_mowa = resolve_address_coordinates("Mowa, Raipur, CG")
        self.assertIsNotNone(coords_mowa)
        self.assertAlmostEqual(coords_mowa[0], 21.2678, places=3)
        self.assertAlmostEqual(coords_mowa[1], 81.6711, places=3)

        coords_pandri = resolve_address_coordinates("Cloth Market, Pandri, Raipur")
        self.assertIsNotNone(coords_pandri)
        self.assertAlmostEqual(coords_pandri[0], 21.2612, places=3)

        # Coordinate string parsing
        coords_raw = resolve_address_coordinates("Near Bus Stand 21.2400, 81.6300 Raipur")
        self.assertIsNotNone(coords_raw)
        self.assertAlmostEqual(coords_raw[0], 21.2400, places=4)
        self.assertAlmostEqual(coords_raw[1], 81.6300, places=4)

    def test_07_delivery_calculate_api_view(self):
        """Test /api/billing/delivery/calculate/ endpoint with address and coordinates."""
        self.client.force_authenticate(user=self.customer)

        # With address string
        res = self.client.post('/api/billing/delivery/calculate/', {
            'address': 'Pandri, Raipur',
            'channel': 'CUSTOMER'
        }, format='json')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertTrue(res.data['success'])
        data = res.data['data']
        self.assertEqual(float(data['delivery_charge']), 20.0)
        self.assertEqual(data['band_name'], 'Local Raipur (0-5 km)')
        self.assertTrue(data['is_supported'])
        self.assertFalse(data['is_blocked'])

        # Beyond radius address
        res_far = self.client.post('/api/billing/delivery/calculate/', {
            'latitude': 21.1900,
            'longitude': 81.2800,
            'channel': 'CUSTOMER'
        }, format='json')
        self.assertEqual(res_far.status_code, status.HTTP_200_OK)
        self.assertFalse(res_far.data['success'])
        self.assertFalse(res_far.data['data']['is_supported'])
        self.assertEqual(res_far.data['data']['error_code'], 'DELIVERY_UNSUPPORTED')

    def test_08_order_creation_server_authoritative_delivery_charges(self):
        """Server-side order creation must enforce authoritative delivery charge and calculate grand_total."""
        self.client.force_authenticate(user=self.customer)

        # Customer buys 5 cans (5 * 80 = 400, satisfies 20L MOQ) at Pandri Raipur (delivery charge = 20)
        # Client tries to maliciously pass delivery_charges = 0.0 or grand_total = 400
        order_payload = {
            'customer_name': 'Test Customer',
            'phone': '9999999991',
            'delivery_address': 'Pandri, Raipur',
            'order_items': [
                {'product_id': self.product.id, 'quantity': 5, 'price': 80.0}
            ],
            'amount': 400.0,
            'delivery_charges': 0.0,  # Tampered client fee
            'grand_total': 400.0,     # Tampered client total
            'order_source': 'DIRECT_COMPANY',
            'payment': 'pending',
            'payment_mode': 'RAZORPAY',
        }

        res = self.client.post('/api/orders/', order_payload, format='json')
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        self.assertTrue(res.data['success'])

        order_id = res.data.get('order_id') or res.data['id']
        order = Order.objects.get(id=order_id)

        # Server MUST have overridden delivery_charges to 20.00 and grand_total to 420.00
        self.assertEqual(order.delivery_charges, Decimal('20.00'))
        self.assertEqual(order.amount, Decimal('400.00'))
        self.assertEqual(order.grand_total, Decimal('420.00'))
        self.assertIsNotNone(order.delivery_distance_km)

    def test_09_order_creation_rejected_outside_service_radius(self):
        """Order placement must be blocked when destination is outside delivery radius."""
        self.client.force_authenticate(user=self.customer)

        order_payload = {
            'customer_name': 'Far Customer',
            'phone': '9999999991',
            'delivery_address': 'Durg Railway Station, Chhattisgarh',
            'delivery_latitude': 21.1900,
            'delivery_longitude': 81.2800,
            'order_items': [
                {'product_id': self.product.id, 'quantity': 5, 'price': 80.0}
            ],
            'amount': 400.0,
            'order_source': 'DIRECT_COMPANY',
        }

        res = self.client.post('/api/orders/', order_payload, format='json')
        self.assertEqual(res.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertFalse(res.data['success'])
        self.assertEqual(res.data['error_code'], 'DELIVERY_UNSUPPORTED')

    def test_10_razorpay_order_amount_must_match_authoritative_grand_total(self):
        """Razorpay payment order must strictly match order.grand_total (including delivery fee)."""
        self.client.force_authenticate(user=self.customer)

        # Create valid order with grand_total = 420.00 (400 subtotal + 20 delivery)
        order = Order.objects.create(
            created_by=self.customer,
            client_name='Test Customer',
            delivery_address='Pandri, Raipur',
            franchise_name='Direct Company',
            city='Raipur',
            amount=Decimal('400.00'),
            delivery_charges=Decimal('20.00'),
            grand_total=Decimal('420.00'),
            order_source='DIRECT_COMPANY',
            payment_status='pending',
            payment_mode='RAZORPAY',
        )

        # Client requests Razorpay order with client_amount = 400.0 (tampered / subtotal only)
        # Server must reject with AMOUNT_MISMATCH
        res_mismatch = self.client.post('/api/orders/razorpay/create-order/', {
            'order_id': order.id,
            'amount': 400.0
        }, format='json')
        self.assertEqual(res_mismatch.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertEqual(res_mismatch.data['code'], 'AMOUNT_MISMATCH')

        # Client requests with authoritative grand total (420.00)
        # Server must accept and create order for 42000 paise
        res_correct = self.client.post('/api/orders/razorpay/create-order/', {
            'order_id': order.id,
            'amount': 420.0
        }, format='json')
        self.assertEqual(res_correct.status_code, status.HTTP_200_OK)
        amount_paise = (res_correct.data.get('data') or res_correct.data)['amount_in_paise']
        self.assertEqual(amount_paise, 42000)

    def test_11_admin_distance_slab_validation(self):
        """Admin panel distance band API rejects overlapping slabs and negative delivery charges."""
        self.client.force_authenticate(user=self.admin)

        # Negative delivery charge
        res_neg = self.client.post('/api/billing/delivery/bands/', {
            'label': 'Invalid Negative Slab',
            'min_distance_km': 15.0,
            'max_distance_km': 20.0,
            'delivery_charge': -10.0,
        }, format='json')
        self.assertEqual(res_neg.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('cannot be negative', res_neg.data['message'])

        # Overlapping slab (e.g. 3.0 to 7.0 overlaps with 0-5 and 5-10)
        res_overlap = self.client.post('/api/billing/delivery/bands/', {
            'name': 'Overlapping Slab',
            'min_distance_km': 3.0,
            'max_distance_km': 7.0,
            'delivery_charge': 35.0,
        }, format='json')
        self.assertEqual(res_overlap.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('Overlapping distance band detected', res_overlap.data['message'])

    def test_12_admin_origin_update_and_immediate_application(self):
        """Admin updates origin settings and the subsequent delivery calculation immediately reflects changes."""
        self.client.force_authenticate(user=self.admin)

        # Update origin depot
        res_update = self.client.post('/api/billing/delivery/origin/', {
            'depot_name': 'Shivnath Agencies Updated Hub',
            'address': 'Ekta Nagar, Near Mowa Thana, Raipur',
            'latitude': 21.2678,
            'longitude': 81.6711,
            'is_active': True
        }, format='json')
        self.assertEqual(res_update.status_code, status.HTTP_200_OK)
        self.assertTrue(res_update.data['success'])

        # Verify DB updated
        origin = DeliveryOriginSetting.get_active_origin()
        self.assertEqual(origin.name, 'Shivnath Agencies Updated Hub')
        self.assertEqual(origin.address, 'Ekta Nagar, Near Mowa Thana, Raipur')

    def test_13_gps_denied_manual_address_entry(self):
        """When GPS is denied or coordinates unavailable, manual address resolves and prices correctly."""
        self.client.force_authenticate(user=self.customer)

        res = self.client.post('/api/billing/delivery/calculate/', {
            'address': 'Pandri, Raipur, CG',
            'latitude': None,
            'longitude': None,
            'channel': 'CUSTOMER'
        }, format='json')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertTrue(res.data['success'])
        self.assertEqual(float(res.data['data']['delivery_charge']), 20.0)
        self.assertEqual(res.data['data']['distance_method'], 'HAVERSINE_STRAIGHT_LINE')
        self.assertEqual(res.data['data']['distance_metric'], 'HAVERSINE_GREAT_CIRCLE_KM')

    def test_14_invalid_unresolved_address_fails_gracefully(self):
        """Unresolvable manual address returns ADDRESS_UNRESOLVABLE and blocks order creation without fabricating fee."""
        self.client.force_authenticate(user=self.customer)

        # 1. Calculation endpoint
        res = self.client.post('/api/billing/delivery/calculate/', {
            'address': 'Unmapped Remote Desert Outpost 999999',
            'channel': 'CUSTOMER'
        }, format='json')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertFalse(res.data['success'])
        self.assertEqual(res.data['data']['error_code'], 'ADDRESS_UNRESOLVABLE')
        self.assertFalse(res.data['data']['is_supported'])

        # 2. Order creation attempt with unresolvable address
        order_payload = {
            'customer_name': 'Lost Customer',
            'phone': '9999999991',
            'delivery_address': 'Unmapped Remote Desert Outpost 999999',
            'order_items': [
                {'product_id': self.product.id, 'quantity': 5, 'price': 80.0}
            ],
            'amount': 400.0,
            'order_source': 'DIRECT_COMPANY',
        }
        res_order = self.client.post('/api/orders/', order_payload, format='json')
        self.assertEqual(res_order.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertFalse(res_order.data['success'])
        self.assertEqual(res_order.data['error_code'], 'ADDRESS_UNRESOLVABLE')

    def test_15_address_changed_after_initial_calculation(self):
        """When customer changes address from Mowa (0-5 km) to Bhatagaon (5-10 km), fee is recalculated to higher slab."""
        self.client.force_authenticate(user=self.customer)

        # Step 1: Initial address in Mowa (~0.2 km -> ₹20)
        res1 = self.client.post('/api/billing/delivery/calculate/', {
            'address': 'Mowa, Raipur',
            'channel': 'CUSTOMER'
        }, format='json')
        self.assertEqual(float(res1.data['data']['delivery_charge']), 20.0)

        # Step 2: Customer changes address to Bhatagaon (~7.2 km -> ₹40)
        res2 = self.client.post('/api/billing/delivery/calculate/', {
            'address': 'Bhatagaon, Raipur',
            'channel': 'CUSTOMER'
        }, format='json')
        self.assertEqual(float(res2.data['data']['delivery_charge']), 40.0)
        self.assertEqual(res2.data['data']['band_name'], 'Extended Raipur (5-10 km)')

        # Step 3: Order placed with Bhatagaon address produces grand_total = 400 + 40 = 440
        order_payload = {
            'customer_name': 'Moving Customer',
            'phone': '9999999991',
            'delivery_address': 'Bhatagaon, Raipur',
            'order_items': [
                {'product_id': self.product.id, 'quantity': 5, 'price': 80.0}
            ],
            'amount': 400.0,
            'order_source': 'DIRECT_COMPANY',
        }
        res_order = self.client.post('/api/orders/', order_payload, format='json')
        self.assertEqual(res_order.status_code, status.HTTP_201_CREATED)
        order_id = res_order.data.get('order_id') or res_order.data['id']
        order = Order.objects.get(id=order_id)
        self.assertEqual(order.delivery_charges, Decimal('40.00'))
        self.assertEqual(order.grand_total, Decimal('440.00'))

    def test_16_cart_change_recalculates_final_payable_amount(self):
        """When cart items or quantities change, final payable amount reflects updated subtotal + delivery fee."""
        self.client.force_authenticate(user=self.customer)

        # 10 cans = ₹800 subtotal + ₹20 delivery fee = ₹820 grand total
        order_payload = {
            'customer_name': 'Cart Update Customer',
            'phone': '9999999991',
            'delivery_address': 'Pandri, Raipur',
            'order_items': [
                {'product_id': self.product.id, 'quantity': 10, 'price': 80.0}
            ],
            'amount': 800.0,
            'order_source': 'DIRECT_COMPANY',
            'payment': 'pending',
            'payment_mode': 'RAZORPAY',
        }
        res_order = self.client.post('/api/orders/', order_payload, format='json')
        self.assertEqual(res_order.status_code, status.HTTP_201_CREATED)
        order_id = res_order.data.get('order_id') or res_order.data['id']
        order = Order.objects.get(id=order_id)

        self.assertEqual(order.amount, Decimal('800.00'))
        self.assertEqual(order.delivery_charges, Decimal('20.00'))
        self.assertEqual(order.grand_total, Decimal('820.00'))

        # Razorpay initiation for old total (₹420) must be rejected
        res_old = self.client.post('/api/orders/razorpay/create-order/', {
            'order_id': order.id,
            'amount': 420.0
        }, format='json')
        self.assertEqual(res_old.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertEqual(res_old.data['code'], 'AMOUNT_MISMATCH')

        # Razorpay initiation for updated total (₹820) succeeds
        res_new = self.client.post('/api/orders/razorpay/create-order/', {
            'order_id': order.id,
            'amount': 820.0
        }, format='json')
        self.assertEqual(res_new.status_code, status.HTTP_200_OK)
        amount_paise = (res_new.data.get('data') or res_new.data)['amount_in_paise']
        self.assertEqual(amount_paise, 82000)

    def test_17_direct_and_franchise_payment_flows_remain_separated(self):
        """Franchise orders use FRANCHISE_COLLECTION and cannot be routed through central Razorpay."""
        from inventory.models import DealerStockBatch
        DealerStockBatch.objects.create(
            dealer=self.franchise,
            product=self.product,
            batch_number='DSB-TEST-001',
            manufacture_date=timezone.now().date(),
            expiry_date=timezone.now().date() + timedelta(days=60),
            received_quantity=100,
            remaining_quantity=100,
            unit_transfer_price=Decimal('50.00'),
            is_active=True
        )

        self.client.force_authenticate(user=self.customer)

        # 1. Place franchise-fulfilled order
        franchise_order_payload = {
            'customer_name': 'Franchise Customer',
            'phone': '9999999991',
            'delivery_address': 'Pandri, Raipur',
            'order_items': [
                {'product_id': self.product.id, 'quantity': 5, 'price': 80.0}
            ],
            'amount': 400.0,
            'order_source': 'FRANCHISE',
            'serving_franchise_id': self.franchise.id,
            'payment': 'pending',
            'payment_mode': 'FRANCHISE_COLLECTION',
        }
        res = self.client.post('/api/orders/', franchise_order_payload, format='json')
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        order_id = res.data.get('order_id') or res.data['id']
        fran_order = Order.objects.get(id=order_id)
        self.assertEqual(fran_order.order_source, 'FRANCHISE')
        self.assertEqual(fran_order.payment_mode, 'FRANCHISE_COLLECTION')

        # 2. Attempting to create central company Razorpay order for franchise order MUST be blocked
        rzp_res = self.client.post('/api/orders/razorpay/create-order/', {
            'order_id': fran_order.id,
            'amount': float(fran_order.grand_total)
        }, format='json')
        self.assertEqual(rzp_res.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertEqual(rzp_res.data['error_code'], 'FRANCHISE_ORDER_ONLINE_PAYMENT_NOT_SUPPORTED')

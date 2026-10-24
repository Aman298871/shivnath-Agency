import json
from decimal import Decimal
from django.test import TestCase
from django.contrib.auth import get_user_model
from rest_framework.test import APIClient
from rest_framework import status
from rest_framework.exceptions import ValidationError as DRFValidationError
from django.core.exceptions import ValidationError as DjangoValidationError

from products.models import Product, ProductCategory, MinimumOrderPackagingRule
from products.packaging_services import validate_order_item_packaging, get_product_moq_info
from orders.models import Wallet, WalletTransaction, WalletRedemptionRule, Order, OrderItem
from orders.wallet_services import (
    get_or_create_wallet,
    get_redemption_eligible_products,
    redeem_points_for_order,
)
from billing.models import DeliveryDistanceBand, DeliveryOriginSetting

User = get_user_model()


class WaterWalletRedemptionMOQTestCase(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.customer = User.objects.create_user(
            username='moq_test_cust',
            email='moq_cust@test.com',
            password='Password123!',
            first_name='Rahul',
            last_name='Sharma'
        )
        self.client.force_authenticate(user=self.customer)

        # Create wallet with generous points and balance
        self.wallet = get_or_create_wallet(self.customer)
        self.wallet.reward_points = 5000  # 5,000 points
        self.wallet.balance = Decimal('1000.00')  # Rs 1,000 cash balance
        self.wallet.save()

        from billing.models import DeliveryOriginSetting
        DeliveryOriginSetting.objects.get_or_create(
            is_active=True,
            defaults={
                'name': 'Shivnath Central Dispatch Hub',
                'address': 'Ekta Nagar, Pragati Nagar, LIC Colony, near Mowa Thana, Raipur, Chhattisgarh',
                'latitude': Decimal('21.267800'),
                'longitude': Decimal('81.671100'),
            }
        )

        # Set redemption rule: 2 points = Rs 1.00 discount (min 100 points)
        self.rule = WalletRedemptionRule.get_active_rule()
        self.rule.points_per_rupee_discount = Decimal('2.00')
        self.rule.rupees_spent_per_point = Decimal('10.00')
        self.rule.min_points_to_redeem = 100
        self.rule.save()

        # Categories
        self.cat_jar = ProductCategory.objects.create(name='Water Jars')
        self.cat_bottle = ProductCategory.objects.create(name='Mineral Bottles')

        # Products
        # 1. 20L Water Jar (JAR, 1 unit/case, Rs 60/jar)
        self.jar_product = Product.objects.create(
            name='Shivnath 20 Litre Dispenser Jar',
            sku='SHV-JAR-20L',
            category_ref=self.cat_jar,
            package_type='JAR',
            units_per_case=1,
            price=Decimal('60.00'),
            stock=500,
            status='Active'
        )

        # 2. 500ml Water Bottle (BOTTLE, 24 units/case, Rs 10/bottle)
        self.bottle_500ml = Product.objects.create(
            name='Shivnath 500ml Travel Bottle',
            sku='SHV-BOT-500ML',
            category_ref=self.cat_bottle,
            package_type='BOTTLE',
            units_per_case=24,
            price=Decimal('10.00'),
            stock=1000,
            status='Active'
        )

        # 3. 1L Water Bottle (BOTTLE, 12 units/case, Rs 20/bottle)
        self.bottle_1l = Product.objects.create(
            name='Shivnath 1 Litre Premium Mineral Bottle',
            sku='SHV-BOT-1L',
            category_ref=self.cat_bottle,
            package_type='BOTTLE',
            units_per_case=12,
            price=Decimal('20.00'),
            stock=600,
            status='Active'
        )

        from inventory.models import ProductionBatch
        from datetime import date, timedelta
        today = date.today()
        exp = today + timedelta(days=90)
        ProductionBatch.objects.create(
            batch_number='BATCH-JAR-01',
            product=self.jar_product,
            status='ACTIVE',
            manufacture_date=today,
            expiry_date=exp,
            quantity_produced_units=500,
            quantity_remaining_company=500,
            unit_production_cost=Decimal('20.00'),
        )
        ProductionBatch.objects.create(
            batch_number='BATCH-BOT-500',
            product=self.bottle_500ml,
            status='ACTIVE',
            manufacture_date=today,
            expiry_date=exp,
            quantity_produced_units=1000,
            quantity_remaining_company=1000,
            unit_production_cost=Decimal('5.00'),
        )
        ProductionBatch.objects.create(
            batch_number='BATCH-BOT-1L',
            product=self.bottle_1l,
            status='ACTIVE',
            manufacture_date=today,
            expiry_date=exp,
            quantity_produced_units=600,
            quantity_remaining_company=600,
            unit_production_cost=Decimal('10.00'),
        )

    # -------------------------------------------------------------
    # POSITIVE TEST CASES
    # -------------------------------------------------------------

    def test_positive_5_jars_redemption(self):
        """5 jars through Water Wallet / points redemption succeeds and deducts correct points."""
        initial_points = self.wallet.reward_points
        initial_stock = self.jar_product.stock

        # 5 jars * Rs 60 = Rs 300 = 600 points needed (at 2 pts / Rs)
        res = redeem_points_for_order(
            user=self.customer,
            product_id=self.jar_product.id,
            quantity=5,
            delivery_address='Shankar Nagar, Raipur'
        )

        self.assertTrue(res['success'])
        self.assertEqual(res['quantity'], 5)
        self.assertEqual(res['points_redeemed'], 600)
        self.assertEqual(res['points_discount_amount'], 300.0)

        # Verify wallet state
        self.wallet.refresh_from_db()
        self.assertEqual(self.wallet.reward_points, initial_points - 600)

        # Verify stock decrement
        self.jar_product.refresh_from_db()
        self.assertEqual(self.jar_product.stock, initial_stock - 5)

        # Verify Order attributes
        order = Order.objects.get(id=res['order_id'])
        self.assertEqual(order.order_source, 'WATER_WALLET_REDEMPTION')
        self.assertEqual(order.items_count, 5)
        self.assertEqual(order.payment_status, 'paid')

    def test_positive_5_bottle_boxes_redemption(self):
        """5 bottle boxes (5 * 24 = 120 bottles) through points redemption succeeds."""
        initial_points = self.wallet.reward_points
        initial_stock = self.bottle_500ml.stock

        # 120 bottles * Rs 10 = Rs 1,200 = 2,400 points needed
        res = redeem_points_for_order(
            user=self.customer,
            product_id=self.bottle_500ml.id,
            quantity=120,
            delivery_address='Shankar Nagar, Raipur'
        )

        self.assertTrue(res['success'])
        self.assertEqual(res['quantity'], 120)
        self.assertEqual(res['points_redeemed'], 2400)
        self.assertEqual(res['points_discount_amount'], 1200.0)

        # Verify wallet and stock
        self.wallet.refresh_from_db()
        self.assertEqual(self.wallet.reward_points, initial_points - 2400)
        self.bottle_500ml.refresh_from_db()
        self.assertEqual(self.bottle_500ml.stock, initial_stock - 120)

    def test_positive_5_boxes_different_case_size(self):
        """5 boxes of 1L bottles (5 * 12 = 60 bottles) succeeds."""
        # 60 bottles * Rs 20 = Rs 1,200 = 2,400 points
        res = redeem_points_for_order(
            user=self.customer,
            product_id=self.bottle_1l.id,
            quantity=60,
            delivery_address='Pandri, Raipur'
        )
        self.assertTrue(res['success'])
        self.assertEqual(res['quantity'], 60)

    def test_positive_regular_checkout_5_jars_and_boxes(self):
        """Regular checkout endpoint permits 5 jars and 5 boxes."""
        res_jar = self.client.post('/api/orders/', {
            'order_items': [{'product_id': self.jar_product.id, 'quantity': 5, 'price': 60.0}],
            'amount': 300.0,
            'items_count': 5,
            'payment_mode': 'WALLET',
            'delivery_address': 'Civil Lines, Raipur',
            'customer_name': 'Rahul Sharma',
            'phone': '9876543210',
        }, format='json')
        self.assertEqual(res_jar.status_code, status.HTTP_201_CREATED)

        # Top up wallet for the second order (120 bottles = Rs 1,200)
        self.wallet.refresh_from_db()
        self.wallet.balance += Decimal('2000.00')
        self.wallet.save()

        res_box = self.client.post('/api/orders/', {
            'order_items': [{'product_id': self.bottle_500ml.id, 'quantity': 120, 'price': 10.0}],
            'amount': 1200.0,
            'items_count': 120,
            'payment_mode': 'WALLET',
            'delivery_address': 'Mowa, Raipur',
            'customer_name': 'Rahul Sharma',
            'phone': '9876543210',
        }, format='json')
        self.assertEqual(res_box.status_code, status.HTTP_201_CREATED)

    # -------------------------------------------------------------
    # NEGATIVE TEST CASES & ATOMIC ROLLBACK
    # -------------------------------------------------------------

    def test_negative_1_to_4_jars_rejected(self):
        """Ordering 1 to 4 jars is strictly rejected; points and balances remain unchanged."""
        for q in [1, 2, 3, 4]:
            pts_before = self.wallet.reward_points
            bal_before = self.wallet.balance
            stock_before = self.jar_product.stock
            order_count_before = Order.objects.count()

            with self.assertRaises((DjangoValidationError, DRFValidationError)) as ctx:
                redeem_points_for_order(
                    user=self.customer,
                    product_id=self.jar_product.id,
                    quantity=q
                )
            self.assertIn("Minimum order requirement not met", str(ctx.exception))

            # Verify complete atomic rollback
            self.wallet.refresh_from_db()
            self.assertEqual(self.wallet.reward_points, pts_before)
            self.assertEqual(self.wallet.balance, bal_before)
            self.jar_product.refresh_from_db()
            self.assertEqual(self.jar_product.stock, stock_before)
            self.assertEqual(Order.objects.count(), order_count_before)

    def test_negative_5_individual_bottles_rejected_as_below_moq(self):
        """Ordering 5 individual bottles (instead of 5 boxes) is rejected!"""
        pts_before = self.wallet.reward_points

        with self.assertRaises((DjangoValidationError, DRFValidationError)) as ctx:
            redeem_points_for_order(
                user=self.customer,
                product_id=self.bottle_500ml.id,
                quantity=5  # 5 loose bottles, NOT 5 boxes
            )
        self.assertIn("Minimum permitted order is 5 bottle boxes (120 bottles)", str(ctx.exception))

        self.wallet.refresh_from_db()
        self.assertEqual(self.wallet.reward_points, pts_before)

    def test_negative_1_to_4_bottle_boxes_rejected(self):
        """Ordering 1 to 4 full boxes (24, 48, 72, 96 bottles) is rejected because MOQ is 5 boxes."""
        for boxes in [1, 2, 3, 4]:
            bottles = boxes * 24
            pts_before = self.wallet.reward_points

            with self.assertRaises((DjangoValidationError, DRFValidationError)) as ctx:
                redeem_points_for_order(
                    user=self.customer,
                    product_id=self.bottle_500ml.id,
                    quantity=bottles
                )
            self.assertIn("Minimum permitted order is 5 bottle boxes", str(ctx.exception))

            self.wallet.refresh_from_db()
            self.assertEqual(self.wallet.reward_points, pts_before)

    def test_negative_partial_cartons_rejected(self):
        """Ordering non-multiples of box packaging (e.g. 125 bottles instead of 120 or 144) is rejected."""
        pts_before = self.wallet.reward_points

        with self.assertRaises((DjangoValidationError, DRFValidationError)) as ctx:
            redeem_points_for_order(
                user=self.customer,
                product_id=self.bottle_500ml.id,
                quantity=125  # 125 > 120, but not a multiple of 24
            )
        self.assertIn("must be ordered in full carton / box packaging", str(ctx.exception))

        self.wallet.refresh_from_db()
        self.assertEqual(self.wallet.reward_points, pts_before)

    def test_negative_api_endpoint_rejects_below_moq(self):
        """Direct POST to /api/orders/wallet/redeem/ with below-MOQ quantity returns HTTP 400."""
        res = self.client.post('/api/orders/wallet/redeem/', {
            'product_id': self.jar_product.id,
            'quantity': 1,
            'delivery_address': 'Pandri, Raipur'
        }, format='json')

        self.assertEqual(res.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertFalse(res.data['success'])
        self.assertEqual(res.data.get('error_code'), 'PACKAGING_RULE_VIOLATION')
        self.assertIn("Minimum order requirement not met", res.data['message'])

    def test_negative_regular_checkout_rejects_below_moq(self):
        """Direct POST to /api/orders/ with below-MOQ quantity returns HTTP 400."""
        res = self.client.post('/api/orders/', {
            'order_items': [{'product_id': self.jar_product.id, 'quantity': 2}],
            'payment_mode': 'WALLET',
            'delivery_address': 'Pandri, Raipur'
        }, format='json')

        self.assertEqual(res.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertFalse(res.data['success'])
        self.assertEqual(res.data.get('error_code'), 'PACKAGING_RULE_VIOLATION')

    # -------------------------------------------------------------
    # DELIVERY CHARGES & ECONOMICS
    # -------------------------------------------------------------

    def test_delivery_charges_preserved_in_redemption(self):
        """Authoritative delivery charges are applied and debited from wallet cash without being wiped by points."""
        # Configure delivery band: 0 to 10 km = Rs 50
        DeliveryDistanceBand.objects.all().delete()
        DeliveryDistanceBand.objects.create(
            name='Local 0-10km',
            min_distance_km=Decimal('0.00'),
            max_distance_km=Decimal('10.00'),
            delivery_charge=Decimal('50.00'),
            order=1,
            is_active=True
        )

        origin = DeliveryOriginSetting.get_active_origin()
        # Origin is Raipur (21.2514, 81.6296); destination 5km away
        dest_lat = float(origin.latitude) + 0.03
        dest_lon = float(origin.longitude) + 0.03

        initial_bal = self.wallet.balance

        # 5 jars = Rs 300 subtotal (covered by 600 points). Delivery fee = Rs 50 (debited from wallet cash)
        res = redeem_points_for_order(
            user=self.customer,
            product_id=self.jar_product.id,
            quantity=5,
            delivery_latitude=dest_lat,
            delivery_longitude=dest_lon,
            delivery_address='VIP Road, Raipur'
        )

        self.assertTrue(res['success'])
        self.assertEqual(res['points_discount_amount'], 300.0)
        self.assertEqual(res['wallet_amount_debited'], 50.0)
        self.assertEqual(res['total_amount'], 350.0)

        # Verify wallet cash debited Rs 50
        self.wallet.refresh_from_db()
        self.assertEqual(self.wallet.balance, initial_bal - Decimal('50.00'))

    # -------------------------------------------------------------
    # CATALOGUE API METADATA
    # -------------------------------------------------------------

    def test_catalogue_api_provides_moq_metadata(self):
        """Catalog endpoint exposes moq, moq_units, and points required for MOQ."""
        data = get_redemption_eligible_products(self.customer)
        self.assertTrue(data['success'])

        jar_entry = next((p for p in data['products'] if p['id'] == self.jar_product.id), None)
        self.assertIsNotNone(jar_entry)
        self.assertEqual(jar_entry['min_order_quantity'], 5)
        self.assertEqual(jar_entry['moq_units'], 5)
        self.assertEqual(jar_entry['sales_unit'], 'JAR')
        self.assertEqual(jar_entry['points_required'], 600)  # 5 * Rs 60 * 2 pts/Rs
        self.assertEqual(jar_entry['moq_display_text'], "Minimum order: 5 water jars")

        bottle_entry = next((p for p in data['products'] if p['id'] == self.bottle_500ml.id), None)
        self.assertIsNotNone(bottle_entry)
        self.assertEqual(bottle_entry['min_order_quantity'], 5)
        self.assertEqual(bottle_entry['moq_units'], 120)  # 5 * 24
        self.assertEqual(bottle_entry['sales_unit'], 'CARTON')
        self.assertEqual(bottle_entry['points_required'], 2400)  # 120 * Rs 10 * 2 pts/Rs
        self.assertIn("5 bottle boxes (120 bottles)", bottle_entry['moq_display_text'])

import json
from decimal import Decimal
from django.test import TestCase, Client
from django.contrib.auth.models import User
from rest_framework import status

from products.models import Product, ProductCategory
from orders.models import Wallet, WalletTransaction, WalletRedemptionRule, Order
from orders.wallet_services import get_redemption_eligible_products, redeem_points_for_order


class CategoryFilterAndRedemptionBugTests(TestCase):
    def setUp(self):
        self.client = Client()

        # Customer user
        self.customer = User.objects.create_user(
            username='bug_test_cust',
            email='bug_cust@shivnath.com',
            password='testpassword123'
        )
        self.customer.profile.role = 'customer'
        self.customer.profile.save()

        # Categories: simulating duplicate/split categories seen in production
        # 1) "Packaged Water Bottles" (slug: "water-bottles", ID parent: None)
        self.cat_packaged_bottles = ProductCategory.objects.create(
            name='Packaged Water Bottles',
            slug='water-bottles',
            order=1,
            is_active=True
        )
        # 2) "Water Bottles" (slug: "water-bottles")
        self.cat_water_bottles = ProductCategory.objects.create(
            name='Water Bottles',
            slug='water-bottles',
            order=1,
            is_active=True
        )
        # 3) "20L Water Jars" (slug: "water-jars")
        self.cat_20l_jars = ProductCategory.objects.create(
            name='20L Water Jars',
            slug='water-jars',
            order=2,
            is_active=True
        )
        # 4) "Water Jars" (slug: "water-jars")
        self.cat_water_jars = ProductCategory.objects.create(
            name='Water Jars',
            slug='water-jars',
            order=2,
            is_active=True
        )

        # Products assigned to cat_water_bottles (ID 2), but user might filter by cat_packaged_bottles (ID 1)
        self.bottle_500 = Product.objects.create(
            name='Shivnath 500ml Travel Bottle',
            sku='TEST-SHV-500',
            size='500 ML',
            volume_ml=500,
            package_type='BOTTLE',
            units_per_case=24,
            price=Decimal('10.00'),
            mrp=Decimal('10.00'),
            stock=500,
            unit='Bottle',
            category='Water Bottles',
            category_ref=self.cat_water_bottles,
            status='Active'
        )

        self.jar_20 = Product.objects.create(
            name='Shivnath 20 Litre Dispenser Jar',
            sku='TEST-SHV-20L',
            size='20 L',
            volume_ml=20000,
            package_type='JAR',
            units_per_case=1,
            price=Decimal('80.00'),
            mrp=Decimal('80.00'),
            stock=100,
            unit='Jar',
            category='Water Jars',
            category_ref=self.cat_water_jars,
            status='Active'
        )

        # Inactive product
        self.inactive_prod = Product.objects.create(
            name='Shivnath Archived Bottle',
            sku='TEST-INACTIVE',
            size='1 L',
            volume_ml=1000,
            package_type='BOTTLE',
            units_per_case=12,
            price=Decimal('20.00'),
            stock=0,
            unit='Bottle',
            category='Water Bottles',
            category_ref=self.cat_water_bottles,
            status='Inactive'
        )

        # Wallet setup for customer
        self.wallet = Wallet.objects.create(
            user=self.customer,
            balance=Decimal('0.00'),
            reward_points=250
        )

        # Redemption Rule: 2 Pts per Rupee discount, min 50 Pts
        self.rule = WalletRedemptionRule.objects.create(
            rupees_spent_per_point=Decimal('10.00'),
            points_per_rupee_discount=Decimal('2.00'),
            min_points_to_redeem=50,
            is_active=True
        )

    def test_category_filter_by_packaged_water_bottles_id(self):
        """
        Selecting category_id of 'Packaged Water Bottles' MUST return active bottle products
        even though products are linked to 'Water Bottles' category_ref with identical slug.
        """
        res = self.client.get(f'/api/products/?category_id={self.cat_packaged_bottles.id}&active_only=true')
        self.assertEqual(res.status_code, 200)
        data = res.json()
        self.assertTrue(data['success'])
        skus = [p['sku'] for p in data['products']]
        self.assertIn('TEST-SHV-500', skus)
        self.assertNotIn('TEST-SHV-20L', skus)
        self.assertNotIn('TEST-INACTIVE', skus)

    def test_category_filter_by_20l_water_jars_id(self):
        """
        Selecting category_id of '20L Water Jars' MUST return active jar products
        even though products are linked to 'Water Jars' category_ref.
        """
        res = self.client.get(f'/api/products/?category_id={self.cat_20l_jars.id}&active_only=true')
        self.assertEqual(res.status_code, 200)
        data = res.json()
        self.assertTrue(data['success'])
        skus = [p['sku'] for p in data['products']]
        self.assertIn('TEST-SHV-20L', skus)
        self.assertNotIn('TEST-SHV-500', skus)

    def test_category_filter_by_category_name_string(self):
        """
        Filtering by category='Packaged Water Bottles' or category='Water Jars' works seamlessly.
        """
        res1 = self.client.get('/api/products/?category=Packaged+Water+Bottles&active_only=true')
        self.assertEqual(res1.status_code, 200)
        skus1 = [p['sku'] for p in res1.json()['products']]
        self.assertIn('TEST-SHV-500', skus1)
        self.assertNotIn('TEST-SHV-20L', skus1)

        res2 = self.client.get('/api/products/?category=Water+Jars&active_only=true')
        self.assertEqual(res2.status_code, 200)
        skus2 = [p['sku'] for p in res2.json()['products']]
        self.assertIn('TEST-SHV-20L', skus2)
        self.assertNotIn('TEST-SHV-500', skus2)

    def test_category_filter_all_returns_all_active(self):
        """
        'All' returns all active products and excludes inactive ones.
        """
        res = self.client.get('/api/products/?active_only=true')
        self.assertEqual(res.status_code, 200)
        skus = [p['sku'] for p in res.json()['products']]
        self.assertIn('TEST-SHV-500', skus)
        self.assertIn('TEST-SHV-20L', skus)
        self.assertNotIn('TEST-INACTIVE', skus)

    def test_redemption_products_endpoint_returns_data_list(self):
        """
        BUG 2 VERIFICATION: /api/orders/wallet/redemption-products/ must return 'data' as a List
        containing eligible products with correct point calculations.
        """
        from rest_framework_simplejwt.tokens import RefreshToken
        token = str(RefreshToken.for_user(self.customer).access_token)
        res = self.client.get(
            '/api/orders/wallet/redemption-products/',
            HTTP_AUTHORIZATION=f'Bearer {token}'
        )
        self.assertEqual(res.status_code, 200)
        body = res.json()
        self.assertTrue(body['success'])
        self.assertIn('data', body)
        self.assertIsInstance(body['data'], list)
        self.assertIn('products', body)
        self.assertIsInstance(body['products'], list)

        # 500ml bottle price is 10.00 -> 10 * 2 pts/rupee = 20 points
        bottle_item = next(p for p in body['data'] if p['id'] == self.bottle_500.id)
        self.assertEqual(bottle_item['points_required'], 20)
        self.assertTrue(bottle_item['can_redeem_full'])

    def test_redemption_order_direct_to_admin(self):
        """
        Executing point redemption creates an order routed to Central Admin and debits points once.
        """
        from rest_framework_simplejwt.tokens import RefreshToken
        token = str(RefreshToken.for_user(self.customer).access_token)
        initial_points = self.wallet.reward_points
        payload = {
            'product_id': self.bottle_500.id,
            'quantity': 1,
            'notes': 'Test redemption flow'
        }
        res = self.client.post(
            '/api/orders/wallet/redeem/',
            data=json.dumps(payload),
            content_type='application/json',
            HTTP_AUTHORIZATION=f'Bearer {token}'
        )
        self.assertEqual(res.status_code, 201)
        body = res.json()
        self.assertTrue(body['success'])
        self.assertIn('order', body)
        self.assertIn('data', body)
        self.assertEqual(body['points_redeemed'], 20)

        # Refresh wallet and verify single deduction
        self.wallet.refresh_from_db()
        self.assertEqual(self.wallet.reward_points, initial_points - 20)

        # Verify Order properties: Central Admin fulfillment, WATER_WALLET_REDEMPTION
        order = Order.objects.get(id=body['order_id'])
        self.assertEqual(order.order_source, 'WATER_WALLET_REDEMPTION')
        self.assertIsNone(order.serving_franchise)
        self.assertEqual(order.payment_status.lower(), 'paid')
        self.assertEqual(order.payment_mode, 'WALLET_REDEMPTION')

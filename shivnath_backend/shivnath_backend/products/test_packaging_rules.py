import json
from decimal import Decimal
from django.test import TestCase
from django.contrib.auth import get_user_model
from rest_framework.test import APIClient
from rest_framework import status
from products.models import Product, ProductCategory, MinimumOrderPackagingRule
from products.packaging_services import (
    get_applicable_packaging_rule,
    validate_order_item_packaging,
    get_product_moq_info
)
from django.core.exceptions import ValidationError as DjangoValidationError
from rest_framework.exceptions import ValidationError as DRFValidationError
from accounts.models import FranchiseProfile, UserProfile
from inventory.models import ProductionBatch, DealerStockBatch
from billing.models import DeliveryDistanceBand, DeliveryOriginSetting
from datetime import date, timedelta

User = get_user_model()


class MinimumOrderPackagingRuleTestCase(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.admin = User.objects.create_superuser(
            username='admin_test_user',
            email='admin@example.com',
            password='adminpassword123'
        )
        self.customer = User.objects.create_user(
            username='cust_8888888888',
            email='cust@example.com',
            password='customerpassword123'
        )
        self.category = ProductCategory.objects.create(name='Water Bottles')
        self.product = Product.objects.create(
            name='Mineral Water 500ml',
            sku='SHV-TEST-PKG-01',
            category_ref=self.category,
            price=Decimal('10.00'),
            size='500ml'
        )

    def test_moq_enforcement(self):
        """Test that ordering below minimum order quantity raises ValidationError."""
        rule = MinimumOrderPackagingRule.objects.create(
            product=self.product,
            sales_unit='BOTTLE',
            min_order_quantity=10,
            units_per_carton=24,
            allow_partial_carton=True,
            applies_to='ALL',
            is_active=True
        )

        # Ordering 5 items (below min 10)
        from rest_framework.exceptions import ValidationError as DRFValidationError
        with self.assertRaises((DjangoValidationError, DRFValidationError)) as ctx:
            validate_order_item_packaging(self.product, 5, channel='CUSTOMER')
        self.assertIn("Minimum order requirement not met", str(ctx.exception))

        # Ordering 10 items (meets min)
        result = validate_order_item_packaging(self.product, 10, channel='CUSTOMER')
        self.assertEqual(result['quantity'], 10)

    def test_partial_carton_rejection(self):
        """Test that partial cartons are rejected when allow_partial_cartons=False."""
        MinimumOrderPackagingRule.objects.create(
            product=self.product,
            sales_unit='BOTTLE',
            min_order_quantity=24,
            units_per_carton=24,
            allow_partial_carton=False,
            applies_to='ALL',
            is_active=True
        )

        # 30 is not a multiple of 24
        from rest_framework.exceptions import ValidationError as DRFValidationError
        with self.assertRaises((DjangoValidationError, DRFValidationError)) as ctx:
            validate_order_item_packaging(self.product, 30, channel='CUSTOMER')
        self.assertIn("must be ordered in full carton", str(ctx.exception))

        # 48 is exactly 2 cartons of 24
        result = validate_order_item_packaging(self.product, 48, channel='CUSTOMER')
        self.assertEqual(result['carton_count'], Decimal('2.0'))
        self.assertEqual(result['units_per_carton'], 24)

    def test_product_rule_takes_precedence_over_category_rule(self):
        """Test specificity: product-specific rule overrides category-wide rule."""
        cat_rule = MinimumOrderPackagingRule.objects.create(
            category=self.category,
            sales_unit='BOTTLE',
            min_order_quantity=5,
            units_per_carton=10,
            allow_partial_carton=True,
            priority=1,
            is_active=True
        )
        prod_rule = MinimumOrderPackagingRule.objects.create(
            product=self.product,
            sales_unit='BOTTLE',
            min_order_quantity=20,
            units_per_carton=24,
            allow_partial_carton=True,
            priority=10,
            is_active=True
        )

        matched = get_applicable_packaging_rule(self.product, channel='CUSTOMER')
        self.assertEqual(matched.id, prod_rule.id)

    def test_packaging_rule_api_endpoints(self):
        """Admin can list and create rules; customers cannot create rules."""
        self.client.force_authenticate(user=self.admin)
        res = self.client.post('/api/products/packaging-rules/', {
            'product': self.product.id,
            'sales_unit': 'BOTTLE',
            'min_order_quantity': 12,
            'units_per_carton': 12,
            'allow_partial_carton': False,
            'applies_to': 'ALL',
            'is_active': True
        })
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)

        # Check packaging-rules/check/ endpoint
        self.client.force_authenticate(user=self.customer)
        check_res = self.client.get(f'/api/products/packaging-rules/check/?product_id={self.product.id}&quantity=10')
        self.assertEqual(check_res.status_code, status.HTTP_200_OK)
        self.assertFalse(check_res.data['is_valid'])
        self.assertIn('error', check_res.data)

        # Check with valid quantity
        check_valid = self.client.get(f'/api/products/packaging-rules/check/?product_id={self.product.id}&quantity=24')
        self.assertEqual(check_valid.status_code, status.HTTP_200_OK)
        self.assertTrue(check_valid.data['is_valid'])
        self.assertEqual(check_valid.data['carton_count'], 2.0)


class PolicyAPackagingRuleRegressionTestCase(TestCase):
    """
    Automated regression test suite for Policy A (Admin Mandatory MOQ + Franchise Additional MOQ):
    Effective MOQ = max(Admin Baseline MOQ, Serving Franchise MOQ)
    Admin baseline is mandatory. Franchise can increase minimum quantity but can never reduce it.
    """

    def setUp(self):
        self.client = APIClient()

        # 1. Admin User
        self.admin = User.objects.create_superuser(
            username='admin_policy_a',
            email='admin_pa@example.com',
            password='AdminPassword123!'
        )

        # 2. Customer User & Profile
        self.customer = User.objects.create_user(
            username='cust_policy_a',
            email='cust_pa@example.com',
            password='CustomerPassword123!'
        )
        self.customer_profile, _ = UserProfile.objects.get_or_create(
            user=self.customer,
            defaults={
                'name': 'Ramesh Patel',
                'phone': '9876543210',
                'city': 'Raipur',
                'role': 'customer'
            }
        )
        self.customer_profile.name = 'Ramesh Patel'
        self.customer_profile.phone = '9876543210'
        self.customer_profile.city = 'Raipur'
        self.customer_profile.role = 'customer'
        self.customer_profile.save()

        # 3. Serving Franchise Alpha (Raipur)
        self.f1_user = User.objects.create_user(
            username='f1_policy_a',
            email='f1_pa@example.com',
            password='FranchisePassword123!'
        )
        f1_prof, _ = UserProfile.objects.get_or_create(user=self.f1_user)
        f1_prof.role = 'franchise'
        f1_prof.save()

        self.franchise_1, _ = FranchiseProfile.objects.get_or_create(
            user=self.f1_user,
            defaults={
                'business_name': 'Franchise Alpha Raipur',
                'dealer_code': 'DLR-PA-001',
                'city': 'Raipur',
                'address': 'Telibandha, Raipur',
                'status': 'approved'
            }
        )

        # 4. Serving Franchise Beta (Durg)
        self.f2_user = User.objects.create_user(
            username='f2_policy_a',
            email='f2_pa@example.com',
            password='FranchisePassword123!'
        )
        f2_prof, _ = UserProfile.objects.get_or_create(user=self.f2_user)
        f2_prof.role = 'franchise'
        f2_prof.save()

        self.franchise_2, _ = FranchiseProfile.objects.get_or_create(
            user=self.f2_user,
            defaults={
                'business_name': 'Franchise Beta Durg',
                'dealer_code': 'DLR-PA-002',
                'city': 'Durg',
                'address': 'Station Road, Durg',
                'status': 'approved'
            }
        )

        # 5. Categories & Products
        self.cat_water = ProductCategory.objects.create(name='Drinking Water')

        # Product A: 20L Water Jar (JAR, 1 unit/case)
        self.product_jar = Product.objects.create(
            name='Shivnath 20L Water Jar',
            sku='SHV-PA-JAR-20L',
            category_ref=self.cat_water,
            package_type='JAR',
            units_per_case=1,
            price=Decimal('60.00'),
            dealer_transfer_price=Decimal('45.00'),
            stock=500,
            status='Active'
        )

        # Product B: 500ml Bottle (BOTTLE, 24 units/case)
        self.product_bottle = Product.objects.create(
            name='Shivnath 500ml Bottle Case',
            sku='SHV-PA-BOT-500ML',
            category_ref=self.cat_water,
            package_type='BOTTLE',
            units_per_case=24,
            price=Decimal('10.00'),
            dealer_transfer_price=Decimal('7.50'),
            stock=1000,
            status='Active'
        )

        # Product C: Accessory (PIECE, 1 unit/case)
        self.product_pump = Product.objects.create(
            name='Manual Dispenser Pump',
            sku='SHV-PA-PUMP-01',
            category_ref=self.cat_water,
            package_type='PIECE',
            units_per_case=1,
            price=Decimal('150.00'),
            dealer_transfer_price=Decimal('110.00'),
            stock=100,
            status='Active'
        )

        # 6. Delivery Settings for Order Creation API
        DeliveryOriginSetting.objects.get_or_create(
            is_active=True,
            defaults={
                'name': 'Shivnath Central Hub',
                'address': 'Telibandha, Raipur',
                'latitude': Decimal('21.250000'),
                'longitude': Decimal('81.630000'),
            }
        )
        DeliveryDistanceBand.objects.get_or_create(
            name='Local Delivery (0-50km)',
            min_distance_km=Decimal('0.00'),
            max_distance_km=Decimal('50.00'),
            defaults={
                'delivery_charge': Decimal('30.00'),
                'is_active': True,
                'is_supported': True,
            }
        )

        # 7. Stock Batches
        today = date.today()
        exp = today + timedelta(days=90)
        ProductionBatch.objects.create(
            batch_number='PB-PA-JAR-01',
            product=self.product_jar,
            status='ACTIVE',
            manufacture_date=today,
            expiry_date=exp,
            quantity_produced_units=500,
            quantity_remaining_company=500,
            unit_production_cost=Decimal('20.00')
        )
        DealerStockBatch.objects.create(
            batch_number='DSB-PA-JAR-01',
            dealer=self.franchise_1,
            product=self.product_jar,
            manufacture_date=today,
            expiry_date=exp,
            received_quantity=200,
            remaining_quantity=200,
            unit_transfer_price=Decimal('45.00'),
            is_active=True
        )

    # ------------------------------------------------------------------
    # POLICY A - SCENARIOS 1 to 6
    # ------------------------------------------------------------------

    def test_scenario_1_admin_5_franchise_4_customer_qty_4_rejected(self):
        """
        Scenario 1:
        Admin Baseline MOQ = 5
        Serving Franchise MOQ = 4
        Effective MOQ = max(5, 4) = 5 (Franchise cannot lower company baseline)
        Customer attempts ordering 4 -> REJECTED
        """
        MinimumOrderPackagingRule.objects.create(
            name='Admin Jar Baseline',
            product=self.product_jar,
            sales_unit='JAR',
            min_order_quantity=5,
            units_per_carton=1,
            allow_partial_carton=True,
            allow_franchise_override=True,
            applies_to='ALL',
            priority=10,
            is_active=True
        )
        MinimumOrderPackagingRule.objects.create(
            name='Franchise Alpha Lower Jar Rule',
            product=self.product_jar,
            franchise=self.franchise_1,
            sales_unit='JAR',
            min_order_quantity=4,
            units_per_carton=1,
            allow_partial_carton=True,
            applies_to='ALL',
            priority=20,
            is_active=True
        )

        # Baseline rule must be returned because franchise rule (4) < baseline (5)
        applicable_rule = get_applicable_packaging_rule(
            self.product_jar,
            channel='CUSTOMER',
            franchise=self.franchise_1
        )
        self.assertIsNone(applicable_rule.franchise)
        self.assertEqual(applicable_rule.min_order_quantity, 5)

        # Ordering 4 must fail validation
        with self.assertRaises((DjangoValidationError, DRFValidationError)) as ctx:
            validate_order_item_packaging(
                self.product_jar,
                4,
                channel='CUSTOMER',
                franchise=self.franchise_1
            )
        self.assertIn("Minimum order requirement not met", str(ctx.exception))

    def test_scenario_2_admin_5_franchise_4_customer_qty_5_accepted(self):
        """
        Scenario 2:
        Admin Baseline MOQ = 5
        Serving Franchise MOQ = 4
        Effective MOQ = max(5, 4) = 5
        Customer orders 5 -> ACCEPTED
        """
        MinimumOrderPackagingRule.objects.create(
            name='Admin Jar Baseline',
            product=self.product_jar,
            sales_unit='JAR',
            min_order_quantity=5,
            units_per_carton=1,
            allow_partial_carton=True,
            allow_franchise_override=True,
            applies_to='ALL',
            priority=10,
            is_active=True
        )
        MinimumOrderPackagingRule.objects.create(
            name='Franchise Alpha Lower Jar Rule',
            product=self.product_jar,
            franchise=self.franchise_1,
            sales_unit='JAR',
            min_order_quantity=4,
            units_per_carton=1,
            allow_partial_carton=True,
            applies_to='ALL',
            priority=20,
            is_active=True
        )

        result = validate_order_item_packaging(
            self.product_jar,
            5,
            channel='CUSTOMER',
            franchise=self.franchise_1
        )
        self.assertTrue(result['is_valid'])
        self.assertEqual(result['quantity'], 5)
        self.assertEqual(result['min_order_quantity'], 5)

    def test_scenario_3_admin_4_franchise_5_customer_qty_4_rejected(self):
        """
        Scenario 3:
        Admin Baseline MOQ = 4
        Serving Franchise MOQ = 5
        Effective MOQ = max(4, 5) = 5 (Franchise increased MOQ)
        Customer attempts ordering 4 -> REJECTED
        """
        MinimumOrderPackagingRule.objects.create(
            name='Admin Jar Baseline',
            product=self.product_jar,
            sales_unit='JAR',
            min_order_quantity=4,
            units_per_carton=1,
            allow_partial_carton=True,
            allow_franchise_override=True,
            applies_to='ALL',
            priority=10,
            is_active=True
        )
        MinimumOrderPackagingRule.objects.create(
            name='Franchise Alpha Higher Jar Rule',
            product=self.product_jar,
            franchise=self.franchise_1,
            sales_unit='JAR',
            min_order_quantity=5,
            units_per_carton=1,
            allow_partial_carton=True,
            applies_to='ALL',
            priority=20,
            is_active=True
        )

        # Franchise override is active because 5 >= 4
        applicable_rule = get_applicable_packaging_rule(
            self.product_jar,
            channel='CUSTOMER',
            franchise=self.franchise_1
        )
        self.assertEqual(applicable_rule.franchise_id, self.franchise_1.id)
        self.assertEqual(applicable_rule.min_order_quantity, 5)

        # Ordering 4 must fail validation
        with self.assertRaises((DjangoValidationError, DRFValidationError)) as ctx:
            validate_order_item_packaging(
                self.product_jar,
                4,
                channel='CUSTOMER',
                franchise=self.franchise_1
            )
        self.assertIn("Minimum order requirement not met", str(ctx.exception))

    def test_scenario_4_admin_4_franchise_5_customer_qty_5_accepted(self):
        """
        Scenario 4:
        Admin Baseline MOQ = 4
        Serving Franchise MOQ = 5
        Effective MOQ = max(4, 5) = 5
        Customer orders 5 -> ACCEPTED
        """
        MinimumOrderPackagingRule.objects.create(
            name='Admin Jar Baseline',
            product=self.product_jar,
            sales_unit='JAR',
            min_order_quantity=4,
            units_per_carton=1,
            allow_partial_carton=True,
            allow_franchise_override=True,
            applies_to='ALL',
            priority=10,
            is_active=True
        )
        MinimumOrderPackagingRule.objects.create(
            name='Franchise Alpha Higher Jar Rule',
            product=self.product_jar,
            franchise=self.franchise_1,
            sales_unit='JAR',
            min_order_quantity=5,
            units_per_carton=1,
            allow_partial_carton=True,
            applies_to='ALL',
            priority=20,
            is_active=True
        )

        result = validate_order_item_packaging(
            self.product_jar,
            5,
            channel='CUSTOMER',
            franchise=self.franchise_1
        )
        self.assertTrue(result['is_valid'])
        self.assertEqual(result['quantity'], 5)
        self.assertEqual(result['min_order_quantity'], 5)

    def test_scenario_5_admin_5_no_franchise_rule_customer_qty_4_rejected(self):
        """
        Scenario 5:
        Admin Baseline MOQ = 5
        No Franchise Rule exists
        Effective MOQ = 5
        Customer attempts ordering 4 -> REJECTED
        Customer orders 5 -> ACCEPTED
        """
        MinimumOrderPackagingRule.objects.create(
            name='Admin Jar Baseline',
            product=self.product_jar,
            sales_unit='JAR',
            min_order_quantity=5,
            units_per_carton=1,
            allow_partial_carton=True,
            allow_franchise_override=True,
            applies_to='ALL',
            priority=10,
            is_active=True
        )

        # Ordering 4 fails
        with self.assertRaises((DjangoValidationError, DRFValidationError)) as ctx:
            validate_order_item_packaging(
                self.product_jar,
                4,
                channel='CUSTOMER',
                franchise=self.franchise_1
            )
        self.assertIn("Minimum order requirement not met", str(ctx.exception))

        # Ordering 5 succeeds
        result = validate_order_item_packaging(
            self.product_jar,
            5,
            channel='CUSTOMER',
            franchise=self.franchise_1
        )
        self.assertTrue(result['is_valid'])
        self.assertEqual(result['quantity'], 5)

    def test_scenario_6_no_admin_rule_franchise_4_customer_qty_3_rejected_qty_5_accepted(self):
        """
        Scenario 6:
        No Admin rule in DB
        Franchise MOQ = 4
        Without Admin baseline allow_franchise_override, Franchise rule cannot take effect.
        Approved default policy (5 jars) applies.
        Customer ordering 3 -> REJECTED
        Customer ordering 4 -> REJECTED
        Customer ordering 5 -> ACCEPTED
        """
        # Franchise attempts to create a rule without an Admin baseline
        MinimumOrderPackagingRule.objects.create(
            name='Franchise Standalone Rule',
            product=self.product_jar,
            franchise=self.franchise_1,
            sales_unit='JAR',
            min_order_quantity=4,
            units_per_carton=1,
            allow_partial_carton=True,
            applies_to='ALL',
            priority=10,
            is_active=True
        )

        # Ordering 3 fails
        with self.assertRaises((DjangoValidationError, DRFValidationError)) as ctx:
            validate_order_item_packaging(
                self.product_jar,
                3,
                channel='CUSTOMER',
                franchise=self.franchise_1
            )
        self.assertIn("Minimum order requirement not met", str(ctx.exception))

        # Ordering 4 fails (below default policy of 5)
        with self.assertRaises((DjangoValidationError, DRFValidationError)) as ctx:
            validate_order_item_packaging(
                self.product_jar,
                4,
                channel='CUSTOMER',
                franchise=self.franchise_1
            )
        self.assertIn("Minimum order requirement not met", str(ctx.exception))

        # Ordering 5 succeeds
        result = validate_order_item_packaging(
            self.product_jar,
            5,
            channel='CUSTOMER',
            franchise=self.franchise_1
        )
        self.assertTrue(result['is_valid'])
        self.assertEqual(result['quantity'], 5)
        self.assertEqual(result['min_order_quantity'], 5)

    # ------------------------------------------------------------------
    # EDGE CASES & BOUNDARY TESTS
    # ------------------------------------------------------------------

    def test_franchise_override_disabled_on_admin_baseline(self):
        """
        When Admin sets allow_franchise_override=False, any Franchise rule is strictly ignored.
        Admin Baseline MOQ = 4 (override=False)
        Franchise MOQ = 8
        Effective MOQ = 4
        """
        MinimumOrderPackagingRule.objects.create(
            name='Admin Jar Baseline Locked',
            product=self.product_jar,
            sales_unit='JAR',
            min_order_quantity=4,
            units_per_carton=1,
            allow_partial_carton=True,
            allow_franchise_override=False,  # OVERRIDE DISABLED
            applies_to='ALL',
            priority=10,
            is_active=True
        )
        MinimumOrderPackagingRule.objects.create(
            name='Franchise Alpha Higher Rule',
            product=self.product_jar,
            franchise=self.franchise_1,
            sales_unit='JAR',
            min_order_quantity=8,
            units_per_carton=1,
            allow_partial_carton=True,
            applies_to='ALL',
            priority=20,
            is_active=True
        )

        applicable_rule = get_applicable_packaging_rule(
            self.product_jar,
            channel='CUSTOMER',
            franchise=self.franchise_1
        )
        self.assertIsNone(applicable_rule.franchise)
        self.assertEqual(applicable_rule.min_order_quantity, 4)

        # Ordering 4 succeeds because baseline is 4 and override was ignored
        res = validate_order_item_packaging(
            self.product_jar,
            4,
            channel='CUSTOMER',
            franchise=self.franchise_1
        )
        self.assertTrue(res['is_valid'])
        self.assertEqual(res['min_order_quantity'], 4)

    def test_franchise_override_with_max_franchise_moq_cap(self):
        """
        When Admin sets max_franchise_moq=8, Franchise cannot set MOQ above 8.
        If Franchise rule > 8 exists in DB, it is discarded and baseline applies.
        """
        MinimumOrderPackagingRule.objects.create(
            name='Admin Jar Baseline Capped',
            product=self.product_jar,
            sales_unit='JAR',
            min_order_quantity=4,
            max_franchise_moq=8,
            units_per_carton=1,
            allow_partial_carton=True,
            allow_franchise_override=True,
            applies_to='ALL',
            priority=10,
            is_active=True
        )
        # Exceeds cap of 8
        MinimumOrderPackagingRule.objects.create(
            name='Franchise Alpha Over-the-Cap Rule',
            product=self.product_jar,
            franchise=self.franchise_1,
            sales_unit='JAR',
            min_order_quantity=10,
            units_per_carton=1,
            allow_partial_carton=True,
            applies_to='ALL',
            priority=20,
            is_active=True
        )

        applicable_rule = get_applicable_packaging_rule(
            self.product_jar,
            channel='CUSTOMER',
            franchise=self.franchise_1
        )
        # Over-the-cap rule is discarded; baseline is used
        self.assertIsNone(applicable_rule.franchise)
        self.assertEqual(applicable_rule.min_order_quantity, 4)

    def test_franchise_rule_isolation_across_different_franchises(self):
        """
        Franchise Alpha sets MOQ=8. Franchise Beta has no rule.
        Order served by Franchise Alpha requires 8.
        Order served by Franchise Beta requires baseline 4.
        """
        MinimumOrderPackagingRule.objects.create(
            name='Admin Jar Baseline',
            product=self.product_jar,
            sales_unit='JAR',
            min_order_quantity=4,
            units_per_carton=1,
            allow_partial_carton=True,
            allow_franchise_override=True,
            applies_to='ALL',
            priority=10,
            is_active=True
        )
        MinimumOrderPackagingRule.objects.create(
            name='Franchise Alpha MOQ 8',
            product=self.product_jar,
            franchise=self.franchise_1,
            sales_unit='JAR',
            min_order_quantity=8,
            units_per_carton=1,
            allow_partial_carton=True,
            applies_to='ALL',
            priority=20,
            is_active=True
        )

        # Alpha: 4 rejected, 8 accepted
        with self.assertRaises((DjangoValidationError, DRFValidationError)):
            validate_order_item_packaging(
                self.product_jar,
                4,
                channel='CUSTOMER',
                franchise=self.franchise_1
            )
        res_alpha = validate_order_item_packaging(
            self.product_jar,
            8,
            channel='CUSTOMER',
            franchise=self.franchise_1
        )
        self.assertTrue(res_alpha['is_valid'])

        # Beta: 4 accepted (baseline 4 applies)
        res_beta = validate_order_item_packaging(
            self.product_jar,
            4,
            channel='CUSTOMER',
            franchise=self.franchise_2
        )
        self.assertTrue(res_beta['is_valid'])
        self.assertEqual(res_beta['min_order_quantity'], 4)

    def test_multiple_products_order_validation(self):
        """
        Order contains multiple products with different MOQ rules:
        - Product Jar: Baseline MOQ = 5
        - Product Bottle: Baseline MOQ = 2 boxes (48 bottles, full peti enforced)
        Validating a mixed cart where one item fails rejects that item.
        """
        MinimumOrderPackagingRule.objects.create(
            name='Admin Jar Baseline',
            product=self.product_jar,
            sales_unit='JAR',
            min_order_quantity=5,
            units_per_carton=1,
            allow_partial_carton=True,
            is_active=True
        )
        MinimumOrderPackagingRule.objects.create(
            name='Admin Bottle 2 Boxes Baseline',
            product=self.product_bottle,
            sales_unit='CARTON',
            min_order_quantity=2,
            units_per_carton=24,
            allow_partial_carton=False,
            is_active=True
        )

        # Jar passes with 5
        res_jar = validate_order_item_packaging(self.product_jar, 5, channel='CUSTOMER')
        self.assertTrue(res_jar['is_valid'])

        # Bottle fails with 24 (1 box < 2 boxes min)
        with self.assertRaises((DjangoValidationError, DRFValidationError)) as ctx:
            validate_order_item_packaging(self.product_bottle, 24, channel='CUSTOMER')
        self.assertIn("Minimum order requirement not met", str(ctx.exception))

        # Bottle passes with 48 (2 full boxes)
        res_bot = validate_order_item_packaging(self.product_bottle, 48, channel='CUSTOMER')
        self.assertTrue(res_bot['is_valid'])
        self.assertEqual(res_bot['carton_count'], 2.0)

    def test_franchise_cannot_create_rule_below_admin_baseline_via_api(self):
        """
        API security check:
        Franchise user attempts to POST /api/products/packaging-rules/ with MOQ < baseline.
        Backend rejects with HTTP 400 Bad Request.
        """
        MinimumOrderPackagingRule.objects.create(
            name='Admin Jar Baseline',
            product=self.product_jar,
            sales_unit='JAR',
            min_order_quantity=6,
            units_per_carton=1,
            allow_partial_carton=True,
            allow_franchise_override=True,
            is_active=True
        )

        # Authenticate as Franchise 1
        self.client.force_authenticate(user=self.f1_user)
        res = self.client.post('/api/products/packaging-rules/', {
            'product': self.product_jar.id,
            'sales_unit': 'JAR',
            'min_order_quantity': 4,  # Attempting lower than baseline 6
            'units_per_carton': 1,
            'allow_partial_carton': True,
            'applies_to': 'ALL',
            'is_active': True
        })
        self.assertEqual(res.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("cannot be lower than company minimum baseline", str(res.data.get('message', '')))

    def test_customer_order_creation_enforces_serving_franchise_moq(self):
        """
        End-to-end Order Creation API (/api/orders/):
        Admin Baseline MOQ = 4 jars (allow_franchise_override=True)
        Franchise Alpha MOQ = 6 jars
        Customer places order via /api/orders/ specifying serving_franchise_id:
        - Quantity 4 -> HTTP 400 (PACKAGING_RULE_VIOLATION)
        - Quantity 6 -> HTTP 201 (CREATED)
        - Tampered/non-existent serving_franchise_id -> HTTP 400
        """
        MinimumOrderPackagingRule.objects.create(
            name='Admin Jar Baseline',
            product=self.product_jar,
            sales_unit='JAR',
            min_order_quantity=4,
            units_per_carton=1,
            allow_partial_carton=True,
            allow_franchise_override=True,
            is_active=True
        )
        MinimumOrderPackagingRule.objects.create(
            name='Franchise Alpha MOQ 6',
            product=self.product_jar,
            franchise=self.franchise_1,
            sales_unit='JAR',
            min_order_quantity=6,
            units_per_carton=1,
            allow_partial_carton=True,
            is_active=True
        )

        self.client.force_authenticate(user=self.customer)

        # 1. Quantity 4 violates Franchise Alpha MOQ (6)
        res_fail = self.client.post('/api/orders/', {
            'order_items': [{'product_id': self.product_jar.id, 'quantity': 4, 'price': 60.0}],
            'amount': 240.0,
            'items_count': 4,
            'payment_mode': 'PAY_ON_DELIVERY',
            'delivery_address': 'Telibandha, Raipur',
            'customer_name': 'Ramesh Patel',
            'phone': '9876543210',
            'serving_franchise_id': self.franchise_1.id,
        }, format='json')
        self.assertEqual(res_fail.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertEqual(res_fail.data.get('error_code'), 'PACKAGING_RULE_VIOLATION')
        self.assertEqual(res_fail.data.get('product_id'), self.product_jar.id)

        # 2. Quantity 6 satisfies Franchise Alpha MOQ (6)
        res_ok = self.client.post('/api/orders/', {
            'order_items': [{'product_id': self.product_jar.id, 'quantity': 6, 'price': 60.0}],
            'amount': 360.0,
            'items_count': 6,
            'payment_mode': 'PAY_ON_DELIVERY',
            'delivery_address': 'Telibandha, Raipur',
            'customer_name': 'Ramesh Patel',
            'phone': '9876543210',
            'serving_franchise_id': self.franchise_1.id,
        }, format='json')
        self.assertEqual(res_ok.status_code, status.HTTP_201_CREATED)

        # 3. Tampered non-existent serving franchise ID
        res_tampered = self.client.post('/api/orders/', {
            'order_items': [{'product_id': self.product_jar.id, 'quantity': 6, 'price': 60.0}],
            'amount': 360.0,
            'items_count': 6,
            'payment_mode': 'PAY_ON_DELIVERY',
            'delivery_address': 'Telibandha, Raipur',
            'customer_name': 'Ramesh Patel',
            'phone': '9876543210',
            'serving_franchise_id': 999999,
        }, format='json')
        self.assertEqual(res_tampered.status_code, status.HTTP_400_BAD_REQUEST)

    def test_packaging_rule_priority_determinism(self):
        """
        Verify deterministic priority ordering:
        Multiple baseline rules exist with different priorities.
        The rule with the highest priority must ALWAYS be chosen deterministically.
        """
        # Baseline Rule A (lower priority)
        MinimumOrderPackagingRule.objects.create(
            name='Lower Priority Baseline',
            product=self.product_jar,
            sales_unit='JAR',
            min_order_quantity=4,
            units_per_carton=1,
            allow_partial_carton=True,
            allow_franchise_override=True,
            priority=5,
            is_active=True
        )
        # Baseline Rule B (higher priority)
        rule_high = MinimumOrderPackagingRule.objects.create(
            name='Higher Priority Baseline',
            product=self.product_jar,
            sales_unit='JAR',
            min_order_quantity=8,
            units_per_carton=1,
            allow_partial_carton=True,
            allow_franchise_override=True,
            priority=15,
            is_active=True
        )

        resolved_rule = get_applicable_packaging_rule(self.product_jar, channel='CUSTOMER')
        self.assertEqual(resolved_rule.id, rule_high.id)
        self.assertEqual(resolved_rule.min_order_quantity, 8)

        # Ordering 4 fails (below higher priority baseline of 8)
        with self.assertRaises((DjangoValidationError, DRFValidationError)):
            validate_order_item_packaging(self.product_jar, 4, channel='CUSTOMER')

        # Ordering 8 succeeds
        res_ok = validate_order_item_packaging(self.product_jar, 8, channel='CUSTOMER')
        self.assertTrue(res_ok['is_valid'])
        self.assertEqual(res_ok['quantity'], 8)



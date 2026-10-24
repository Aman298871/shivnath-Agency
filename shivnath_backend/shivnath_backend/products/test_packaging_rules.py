import json
from decimal import Decimal
from django.test import TestCase
from django.contrib.auth import get_user_model
from rest_framework.test import APIClient
from rest_framework import status
from products.models import Product, ProductCategory, MinimumOrderPackagingRule
from products.packaging_services import (
    get_applicable_packaging_rule,
    validate_order_item_packaging
)
from django.core.exceptions import ValidationError as DjangoValidationError

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

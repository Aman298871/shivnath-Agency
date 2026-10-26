import json
from decimal import Decimal
from django.test import TestCase
from django.contrib.auth import get_user_model
from rest_framework.test import APIClient
from rest_framework import status

from accounts.models import (
    CityDistrict, ServiceZone, ServiceArea, FranchiseProfile, UserProfile
)
from billing.models import DeliveryOriginSetting
from products.models import Product, ProductCategory, MinimumOrderPackagingRule
from products.packaging_services import (
    get_applicable_packaging_rule,
    get_product_moq_info,
    validate_order_item_packaging
)
from billing.delivery_services import get_address_suggestions

User = get_user_model()


class ZoneDiscoveryAndMoqOverridesTestCase(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.admin = User.objects.create_superuser(
            username='admin_zone_user',
            email='admin_zone@example.com',
            password='adminpassword123'
        )
        self.franchise_user = User.objects.create_user(
            username='franchise_user_1',
            email='franchise1@example.com',
            password='franchisepassword123'
        )
        prof1, _ = UserProfile.objects.get_or_create(user=self.franchise_user)
        prof1.role = 'franchise'
        prof1.save()

        self.franchise_profile = FranchiseProfile.objects.create(
            user=self.franchise_user,
            business_name="Test North Franchise",
            dealer_code="FR-NORTH-01",
            city="Raipur",
            address="Tatibandh, Raipur",
            status="approved"
        )
        
        self.other_franchise_user = User.objects.create_user(
            username='franchise_user_2',
            email='franchise2@example.com',
            password='franchisepassword123'
        )
        prof2, _ = UserProfile.objects.get_or_create(user=self.other_franchise_user)
        prof2.role = 'franchise'
        prof2.save()

        self.other_franchise_profile = FranchiseProfile.objects.create(
            user=self.other_franchise_user,
            business_name="Test South Franchise",
            dealer_code="FR-SOUTH-02",
            city="Raipur",
            address="Amanaka, Raipur",
            status="approved"
        )

        self.district, _ = CityDistrict.objects.get_or_create(
            name="Raipur",
            defaults={"state": "Chhattisgarh", "is_active": True}
        )
        self.hub, _ = DeliveryOriginSetting.objects.get_or_create(
            name="Test Central Hub",
            defaults={
                "city": "Raipur",
                "address": "Tatibandh, Raipur",
                "latitude": Decimal("21.2500"),
                "longitude": Decimal("81.6300")
            }
        )
        self.zone, _ = ServiceZone.objects.get_or_create(
            district=self.district,
            name="Test North Zone",
            defaults={
                "code": "TEST-NR-01",
                "is_active": True,
                "fulfilment_hub": self.hub
            }
        )
        self.area1, _ = ServiceArea.objects.get_or_create(
            zone=self.zone,
            locality_name="Tatibandh",
            defaults={
                "district": self.district,
                "pincode": "492099",
                "latitude": Decimal("21.2580"),
                "longitude": Decimal("81.5600"),
                "is_active": True
            }
        )
        self.area2, _ = ServiceArea.objects.get_or_create(
            zone=self.zone,
            locality_name="Amanaka",
            defaults={
                "district": self.district,
                "pincode": "492010",
                "latitude": Decimal("21.2460"),
                "longitude": Decimal("81.5900"),
                "is_active": True
            }
        )

        self.category, _ = ProductCategory.objects.get_or_create(name='Drinking Water')
        self.product_jar, _ = Product.objects.get_or_create(
            sku='SHV-JAR-20L',
            defaults={
                'name': '20L Mineral Water Jar',
                'category_ref': self.category,
                'price': Decimal('80.00'),
                'size': '20L'
            }
        )
        self.product_box, _ = Product.objects.get_or_create(
            sku='SHV-BOX-500ML',
            defaults={
                'name': '500ml Bottled Water Box (24 Bottles)',
                'category_ref': self.category,
                'price': Decimal('240.00'),
                'size': '500ml'
            }
        )

    def test_get_address_suggestions_from_database(self):
        """ServiceArea records from DB are returned with zone and covered localities."""
        suggestions = get_address_suggestions("Tatibandh")
        self.assertTrue(len(suggestions) > 0)
        
        match = next((s for s in suggestions if s['locality'] == "Tatibandh"), None)
        self.assertIsNotNone(match)
        self.assertEqual(match['zone_name'], "Test North Zone")
        self.assertEqual(match['district'], "Raipur")
        self.assertEqual(match['state'], "Chhattisgarh")
        self.assertTrue(match['is_configured_zone'])
        self.assertIn("Amanaka", match.get('covered_localities', []))

    def test_admin_zone_management_api(self):
        """Admin can list and create zones."""
        self.client.force_authenticate(user=self.admin)
        res = self.client.get('/api/accounts/zones/')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        data = res.json()
        self.assertTrue(len(data.get('results', [])) >= 1)

        # Create new zone
        payload = {
            "name": "Test East Zone",
            "code": "TEST-ER-02",
            "district_id": self.district.id,
            "fulfilment_hub_id": self.hub.id,
            "is_active": True
        }
        res_post = self.client.post('/api/accounts/zones/', payload, format='json')
        self.assertEqual(res_post.status_code, status.HTTP_201_CREATED)
        self.assertEqual(res_post.json()['name'], "Test East Zone")

    def test_admin_zone_area_management_api(self):
        """Admin can list and add localities/areas to a zone."""
        self.client.force_authenticate(user=self.admin)
        res = self.client.get(f'/api/accounts/zones/{self.zone.id}/areas/')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        areas = res.json().get('areas', [])
        self.assertEqual(len(areas), 2)
        names = [a['name'] for a in areas]
        self.assertIn("Tatibandh", names)
        self.assertIn("Amanaka", names)

        # Add new area
        area_payload = {
            "name": "Geeta Nagar",
            "pincode": "492001",
            "latitude": "21.2380",
            "longitude": "81.6050",
            "is_active": True
        }
        res_post = self.client.post(f'/api/accounts/zones/{self.zone.id}/areas/', area_payload, format='json')
        self.assertEqual(res_post.status_code, status.HTTP_201_CREATED)
        self.assertEqual(res_post.json()['name'], "Geeta Nagar")
        self.assertEqual(res_post.json()['zone_name'], "Test North Zone")

    def test_admin_moq_baseline_preserves_defaults(self):
        """Admin baseline sets 5 jars and 5 boxes with franchise override rules."""
        # Baseline 20L Jar rule: 5 jars
        jar_rule = MinimumOrderPackagingRule.objects.create(
            product=self.product_jar,
            sales_unit='JAR',
            min_order_quantity=5,
            units_per_carton=1,
            allow_partial_carton=True,
            allow_franchise_override=True,
            max_franchise_moq=25,
            is_active=True
        )
        
        info = get_product_moq_info(self.product_jar)
        self.assertEqual(info['min_order_quantity'], 5)
        self.assertEqual(info['sales_unit'], 'JAR')
        self.assertTrue(info['allow_franchise_override'])
        self.assertEqual(info['max_franchise_moq'], 25)

        # Packaging validation passes on 5 jars, fails on 4
        from rest_framework.exceptions import ValidationError as DRFValidationError
        from django.core.exceptions import ValidationError as DjangoValidationError
        with self.assertRaises((DjangoValidationError, DRFValidationError)):
            validate_order_item_packaging(self.product_jar, 4)
        
        res = validate_order_item_packaging(self.product_jar, 5)
        self.assertEqual(res['quantity'], 5)

    def test_franchise_override_disabled_rejection(self):
        """If Admin sets allow_franchise_override=False, franchise cannot create override."""
        # Admin creates strict baseline rule (no overrides allowed)
        MinimumOrderPackagingRule.objects.create(
            product=self.product_box,
            sales_unit='BOX',
            min_order_quantity=5,
            units_per_carton=24,
            allow_partial_carton=False,
            allow_franchise_override=False,
            is_active=True
        )

        self.client.force_authenticate(user=self.franchise_user)
        payload = {
            "product": self.product_box.id,
            "sales_unit": "BOX",
            "min_order_quantity": 6,
            "units_per_carton": 24,
            "allow_partial_carton": False,
            "is_active": True
        }
        res = self.client.post('/api/products/packaging-rules/', payload, format='json')
        self.assertEqual(res.status_code, status.HTTP_403_FORBIDDEN)
        self.assertIn("does not permit franchise-level overrides", res.json().get('error', ''))

    def test_franchise_cannot_lower_moq_below_company_baseline(self):
        """Franchise cannot set MOQ lower than company baseline."""
        MinimumOrderPackagingRule.objects.create(
            product=self.product_jar,
            sales_unit='JAR',
            min_order_quantity=5,
            units_per_carton=1,
            allow_partial_carton=True,
            allow_franchise_override=True,
            max_franchise_moq=20,
            is_active=True
        )

        self.client.force_authenticate(user=self.franchise_user)
        payload = {
            "product": self.product_jar.id,
            "sales_unit": "JAR",
            "min_order_quantity": 3,  # Invalid: less than company minimum of 5
            "units_per_carton": 1,
            "allow_partial_carton": True,
            "is_active": True
        }
        res = self.client.post('/api/products/packaging-rules/', payload, format='json')
        self.assertEqual(res.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("cannot be lower than company minimum", res.json().get('error', ''))

    def test_franchise_valid_override_takes_precedence_only_for_that_franchise(self):
        """A valid franchise override applies only to orders served by that franchise."""
        MinimumOrderPackagingRule.objects.create(
            product=self.product_jar,
            sales_unit='JAR',
            min_order_quantity=5,
            units_per_carton=1,
            allow_partial_carton=True,
            allow_franchise_override=True,
            max_franchise_moq=20,
            is_active=True
        )

        # Franchise 1 creates valid override: MOQ = 8
        self.client.force_authenticate(user=self.franchise_user)
        payload = {
            "product": self.product_jar.id,
            "sales_unit": "JAR",
            "min_order_quantity": 8,
            "units_per_carton": 1,
            "allow_partial_carton": True,
            "is_active": True
        }
        res = self.client.post('/api/products/packaging-rules/', payload, format='json')
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)

        # For franchise 1: MOQ is 8
        f1_info = get_product_moq_info(self.product_jar, franchise=self.franchise_profile)
        self.assertEqual(f1_info['min_order_quantity'], 8)
        self.assertTrue(f1_info['is_franchise_override'])

        # For franchise 2 (or global): MOQ is still company baseline 5
        f2_info = get_product_moq_info(self.product_jar, franchise=self.other_franchise_profile)
        self.assertEqual(f2_info['min_order_quantity'], 5)
        self.assertFalse(f2_info.get('is_franchise_override', False))

        global_info = get_product_moq_info(self.product_jar)
        self.assertEqual(global_info['min_order_quantity'], 5)

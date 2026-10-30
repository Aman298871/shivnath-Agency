import json
from decimal import Decimal
from django.test import TestCase
from django.contrib.auth import get_user_model
from rest_framework.test import APIClient
from rest_framework import status
from billing.models import DeliveryOriginSetting, DeliveryDistanceBand
from products.models import Product, ProductCategory, MinimumOrderPackagingRule

User = get_user_model()


class AdminBackendPersistenceIntegrationTestCase(TestCase):
    """
    Isolated integration tests verifying that admin configuration save requests
    reach the backend, return successful responses, update the actual database,
    and can be retrieved independently of client-side cache.
    """

    def setUp(self):
        self.client = APIClient()
        self.admin = User.objects.create_superuser(
            username='admin_persistence_tester',
            email='admin_persistence@example.com',
            password='adminpassword123'
        )
        self.client.force_authenticate(user=self.admin)

        # Clear existing origin and bands in isolated test DB
        DeliveryOriginSetting.objects.all().delete()
        DeliveryDistanceBand.objects.all().delete()

        # Seed initial origin
        self.origin = DeliveryOriginSetting.objects.create(
            name='Initial Central Depot',
            address='Initial Depot Address, Raipur',
            latitude=Decimal('21.267800'),
            longitude=Decimal('81.671100'),
            free_delivery_radius_km=Decimal('2.00'),
            max_serviceable_radius_km=Decimal('100.00'),
            default_delivery_charge=Decimal('45.00'),
            is_active=True
        )

        # Create category and products for packaging rules
        self.category = ProductCategory.objects.create(name='Water Containers')
        self.jar_product = Product.objects.create(
            name='Shivnath 20L Dispenser Jar',
            sku='SHV-JAR-20L-TEST',
            category_ref=self.category,
            price=Decimal('80.00'),
            size='20L'
        )
        self.bottle_product = Product.objects.create(
            name='Shivnath 500ml Travel Bottle',
            sku='SHV-BOT-500ML-TEST',
            category_ref=self.category,
            price=Decimal('10.00'),
            size='500ml'
        )

    def test_01_delivery_origin_backend_save_and_reopen_retrieval(self):
        """
        1. Save request reaches backend.
        2. Backend returns success.
        3. DB contains updated values.
        4. Reopening (GET) retrieves server values.
        """
        update_payload = {
            'depot_name': 'Shivnath Agency Raipur HQ Updated',
            'address': 'Ekta Nagar, Near Mowa Thana, Raipur, CG',
            'latitude': 21.268500,
            'longitude': 81.672000,
            'free_delivery_radius_km': 4.5,
            'max_serviceable_radius_km': 150.0,
            'default_delivery_charge': 55.0,
            'is_active': True
        }

        # Step 1 & 2: POST update
        res = self.client.post('/api/billing/delivery/origin/', update_payload, format='json')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertTrue(res.data.get('success'))

        # Step 3: Verify DB contains updated values
        persisted = DeliveryOriginSetting.get_active_origin()
        self.assertEqual(persisted.name, 'Shivnath Agency Raipur HQ Updated')
        self.assertEqual(persisted.free_delivery_radius_km, Decimal('4.50'))
        self.assertEqual(persisted.max_serviceable_radius_km, Decimal('150.00'))
        self.assertEqual(persisted.default_delivery_charge, Decimal('55.00'))

        # Step 4: GET (Reopen retrieval) returns server values
        get_res = self.client.get('/api/billing/delivery/origin/')
        self.assertEqual(get_res.status_code, status.HTTP_200_OK)
        origin_data = get_res.data.get('origin', {})
        self.assertEqual(origin_data['name'], 'Shivnath Agency Raipur HQ Updated')
        self.assertEqual(float(origin_data['free_delivery_radius_km']), 4.5)
        self.assertEqual(float(origin_data['max_serviceable_radius_km']), 150.0)
        self.assertEqual(float(origin_data['default_delivery_charge']), 55.0)

    def test_02_distance_band_backend_save_and_reopen_retrieval(self):
        """
        1. Create band reaches backend.
        2. Backend returns success (201).
        3. DB contains updated band.
        4. Reopening (GET) retrieves persisted bands.
        """
        band_payload = {
            'name': 'Regional Outer Band (15-35 km)',
            'label': 'Regional Outer Band (15-35 km)',
            'min_distance_km': 15.0,
            'max_distance_km': 35.0,
            'delivery_charge': 85.0,
            'is_supported': True,
            'is_active': True,
            'order': 3
        }

        # Step 1 & 2: POST band
        res = self.client.post('/api/billing/delivery/bands/', band_payload, format='json')
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)

        # Step 3: Verify DB contains updated band
        band = DeliveryDistanceBand.objects.filter(min_distance_km=Decimal('15.00')).first()
        self.assertIsNotNone(band)
        self.assertEqual(band.max_distance_km, Decimal('35.00'))
        self.assertEqual(band.delivery_charge, Decimal('85.00'))
        self.assertTrue(band.is_supported)

        # Step 4: GET (Reopen retrieval) returns persisted bands
        get_res = self.client.get('/api/billing/delivery/bands/')
        self.assertEqual(get_res.status_code, status.HTTP_200_OK)
        bands_list = get_res.data if isinstance(get_res.data, list) else get_res.data.get('bands', [])
        found = any(b['name'] == 'Regional Outer Band (15-35 km)' and float(b['delivery_charge']) == 85.0 for b in bands_list)
        self.assertTrue(found)

    def test_03_packaging_rule_20l_jar_moq_and_bottle_carton_backend_save(self):
        """
        1. Save 20L jar rule and 500ml bottle carton rule.
        2. Backend returns success.
        3. DB contains updated rules.
        4. Reopening (GET) retrieves both rules.
        """
        # Jar Rule
        jar_payload = {
            'product': self.jar_product.id,
            'sales_unit': 'JAR',
            'min_order_quantity': 8,
            'units_per_carton': 1,
            'allow_partial_carton': True,
            'applies_to': 'ALL',
            'is_active': True
        }
        res_jar = self.client.post('/api/products/packaging-rules/', jar_payload, format='json')
        self.assertEqual(res_jar.status_code, status.HTTP_201_CREATED)

        # Bottle Carton Rule
        bottle_payload = {
            'product': self.bottle_product.id,
            'sales_unit': 'CARTON',
            'min_order_quantity': 10,
            'units_per_carton': 24,
            'allow_partial_carton': False,
            'applies_to': 'ALL',
            'is_active': True
        }
        res_bottle = self.client.post('/api/products/packaging-rules/', bottle_payload, format='json')
        self.assertEqual(res_bottle.status_code, status.HTTP_201_CREATED)

        # Step 3: Verify DB contains both rules
        db_jar_rule = MinimumOrderPackagingRule.objects.filter(product=self.jar_product).first()
        self.assertIsNotNone(db_jar_rule)
        self.assertEqual(db_jar_rule.min_order_quantity, 8)
        self.assertEqual(db_jar_rule.sales_unit, 'JAR')
        self.assertTrue(db_jar_rule.allow_partial_carton)

        db_bottle_rule = MinimumOrderPackagingRule.objects.filter(product=self.bottle_product).first()
        self.assertIsNotNone(db_bottle_rule)
        self.assertEqual(db_bottle_rule.min_order_quantity, 10)
        self.assertEqual(db_bottle_rule.units_per_carton, 24)
        self.assertFalse(db_bottle_rule.allow_partial_carton)

        # Step 4: GET (Reopen retrieval) returns both rules
        get_res = self.client.get('/api/products/packaging-rules/')
        self.assertEqual(get_res.status_code, status.HTTP_200_OK)
        rules = get_res.data if isinstance(get_res.data, list) else get_res.data.get('rules', [])
        jar_found = any(r.get('product') == self.jar_product.id and r.get('min_order_quantity') == 8 for r in rules)
        bottle_found = any(r.get('product') == self.bottle_product.id and r.get('units_per_carton') == 24 for r in rules)
        self.assertTrue(jar_found)
        self.assertTrue(bottle_found)

    def test_04_failed_or_invalid_backend_save_rejections(self):
        """
        Verify that invalid or corrupt save requests fail at the backend,
        return HTTP 400, and do NOT persist invalid data into the DB.
        """
        # Negative delivery charge
        bad_band = self.client.post('/api/billing/delivery/bands/', {
            'name': 'Negative Band',
            'min_distance_km': 5.0,
            'max_distance_km': 10.0,
            'delivery_charge': -25.0,
        }, format='json')
        self.assertEqual(bad_band.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertFalse(DeliveryDistanceBand.objects.filter(delivery_charge__lt=0).exists())

        # Inverted distance range (min > max)
        inverted_band = self.client.post('/api/billing/delivery/bands/', {
            'name': 'Inverted Band',
            'min_distance_km': 30.0,
            'max_distance_km': 10.0,
            'delivery_charge': 40.0,
        }, format='json')
        self.assertEqual(inverted_band.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertFalse(DeliveryDistanceBand.objects.filter(name='Inverted Band').exists())

        # Free radius greater than maximum serviceable radius
        bad_origin = self.client.post('/api/billing/delivery/origin/', {
            'free_delivery_radius_km': 200.0,
            'max_serviceable_radius_km': 50.0,
        }, format='json')
        self.assertEqual(bad_origin.status_code, status.HTTP_400_BAD_REQUEST)
        persisted = DeliveryOriginSetting.get_active_origin()
        self.assertNotEqual(persisted.free_delivery_radius_km, Decimal('200.00'))

import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from rest_framework.test import APITestCase, APIClient
from django.contrib.auth.models import User
from accounts.models import UserProfile, FranchiseProfile
from products.models import Product, ProductCategory
from inventory.models import RawMaterial

class DealerRoleSecurityTestCase(APITestCase):
    def setUp(self):
        self.client = APIClient()

        # Super Admin User
        self.superadmin = User.objects.create_user(
            username='admin_boss', email='admin@shivnath.com', password='password123', is_superuser=True
        )
        UserProfile.objects.filter(user=self.superadmin).update(role='super_admin')

        # Authorized Admin User
        self.admin = User.objects.create_user(
            username='plant_admin', email='plant@shivnath.com', password='password123'
        )
        admin_profile = self.admin.profile
        admin_profile.role = 'admin'
        admin_profile.save()

        # Wholesale Dealer (Franchise) User
        self.dealer_user = User.objects.create_user(
            username='dealer_raipur', email='dealer@shivnath.com', password='password123'
        )
        dealer_profile_role = self.dealer_user.profile
        dealer_profile_role.role = 'franchise'
        dealer_profile_role.save()
        self.dealer_profile = FranchiseProfile.objects.create(
            user=self.dealer_user,
            business_name='Raipur Water Hub',
            city='Raipur',
            address='Station Road, Raipur',
            status='approved',
        )

        # Existing Product Category
        self.category = ProductCategory.objects.create(
            name='Packaged Drinking Water',
            slug='packaged-drinking-water',
            order=1,
            is_active=True,
        )

        # Existing Product Master
        self.product = Product.objects.create(
            name='Shivnath 20L Water Jar',
            sku='SHIV-JAR-20L',
            category='Water Jar',
            category_ref=self.category,
            size='20 Litre',
            price=35.0,
            mrp=40.0,
            dealer_transfer_price=28.0,
            unit='Jar',
            stock=500,
            status='Active',
        )

    def test_dealer_cannot_create_product(self):
        """Wholesale Dealer / Franchise MUST receive HTTP 403 Forbidden when trying to create product."""
        self.client.force_authenticate(user=self.dealer_user)
        res = self.client.post(
            '/api/products/',
            data={
                'name': 'Illegal Dealer Product',
                'sku': 'ILLEGAL-01',
                'size': '500 ml',
                'price': 15.0,
                'status': 'Active',
            },
            format='json',
        )
        self.assertEqual(res.status_code, 403, f"Expected 403 Forbidden, got {res.status_code}: {res.content}")

    def test_dealer_cannot_update_product(self):
        """Wholesale Dealer / Franchise MUST receive HTTP 403 Forbidden when trying to update product master."""
        self.client.force_authenticate(user=self.dealer_user)
        res = self.client.patch(
            f'/api/products/{self.product.id}/',
            data={'price': 50.0},
            format='json',
        )
        self.assertEqual(res.status_code, 403, f"Expected 403 Forbidden, got {res.status_code}: {res.content}")

    def test_dealer_cannot_delete_product(self):
        """Wholesale Dealer / Franchise MUST receive HTTP 403 Forbidden when trying to delete product master."""
        self.client.force_authenticate(user=self.dealer_user)
        res = self.client.delete(f'/api/products/{self.product.id}/')
        self.assertEqual(res.status_code, 403, f"Expected 403 Forbidden, got {res.status_code}: {res.content}")

    def test_dealer_cannot_create_category(self):
        """Wholesale Dealer / Franchise MUST receive HTTP 403 Forbidden when trying to create product category."""
        self.client.force_authenticate(user=self.dealer_user)
        res = self.client.post(
            '/api/products/categories/',
            data={'name': 'Dealer Custom Category'},
            format='json',
        )
        self.assertEqual(res.status_code, 403, f"Expected 403 Forbidden, got {res.status_code}: {res.content}")

    def test_dealer_cannot_create_raw_materials(self):
        """Wholesale Dealer MUST receive HTTP 403 Forbidden when trying to create raw materials."""
        self.client.force_authenticate(user=self.dealer_user)
        res = self.client.post(
            '/api/inventory/raw-materials/',
            data={'name': 'Preform 20L', 'sku': 'RAW-PRE-20', 'category': 'Preforms', 'unit_of_measure': 'pcs'},
            format='json',
        )
        self.assertEqual(res.status_code, 403, f"Expected 403 Forbidden, got {res.status_code}: {res.content}")

    def test_dealer_cannot_create_production_batches(self):
        """Wholesale Dealer MUST receive HTTP 403 Forbidden when trying to trigger production batches."""
        self.client.force_authenticate(user=self.dealer_user)
        res = self.client.post(
            '/api/inventory/production-batches/',
            data={'product': self.product.id, 'quantity_produced_units': 100},
            format='json',
        )
        self.assertEqual(res.status_code, 403, f"Expected 403 Forbidden, got {res.status_code}: {res.content}")

    def test_dealer_can_view_official_catalog(self):
        """Wholesale Dealer CAN read and search the company product catalog."""
        self.client.force_authenticate(user=self.dealer_user)
        res = self.client.get('/api/products/')
        self.assertEqual(res.status_code, 200)
        data = res.json()
        self.assertTrue(data.get('success'))
        self.assertGreaterEqual(data.get('count'), 1)

    def test_dealer_can_view_categories(self):
        """Wholesale Dealer CAN read categories to browse catalog."""
        self.client.force_authenticate(user=self.dealer_user)
        res = self.client.get('/api/products/categories/')
        self.assertEqual(res.status_code, 200)
        data = res.json()
        self.assertTrue(data.get('success'))

    def test_admin_can_create_product(self):
        """Authorized Admin CAN create products."""
        self.client.force_authenticate(user=self.admin)
        res = self.client.post(
            '/api/products/',
            data={
                'name': 'Shivnath 500ml Bottle Box',
                'sku': 'SHIV-500ML-BOX',
                'category': 'Packaged Water',
                'size': '500 ml',
                'price': 240.0,
                'unit': 'Box',
                'stock': 200,
                'status': 'Active',
            },
            format='json',
        )
        self.assertEqual(res.status_code, 201, f"Expected 201 Created, got {res.status_code}: {res.content}")

    def test_admin_can_create_category(self):
        """Authorized Admin CAN create category."""
        self.client.force_authenticate(user=self.admin)
        res = self.client.post(
            '/api/products/categories/',
            data={'name': 'Soda & Flavored Waters', 'order': 2},
            format='json',
        )
        self.assertEqual(res.status_code, 201, f"Expected 201 Created, got {res.status_code}: {res.content}")

if __name__ == '__main__':
    from django.core.management import call_command
    call_command('test', 'test_dealer_role_permission_correction')

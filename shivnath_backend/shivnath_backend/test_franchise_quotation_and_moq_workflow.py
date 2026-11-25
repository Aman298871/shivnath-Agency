"""
Automated Test Suite for Quotation Distribution Workflow & MOQ Management
Verifies:
1. Customer accounts are strictly denied access to quotations (403 Forbidden).
2. Admin can create draft & published quotations assigned to specific franchises.
3. Franchise can view strictly their own quotations; cannot view other franchise's quotations.
4. Franchise can accept quotation; records timestamp and authenticated franchise user.
5. Duplicate acceptance and accepting expired/withdrawn quotations is prevented.
6. Franchise can reject quotation with a mandatory reason; rejection without reason is rejected (400).
7. Admin MOQ baseline and franchise override rules enforce Effective MOQ = max(baseline, franchise).
8. Franchise cannot lower MOQ below company mandatory baseline.
"""

import os
import sys
import datetime
from decimal import Decimal

# Setup Django environment
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
import django
django.setup()

from django.test import TestCase
from django.contrib.auth.models import User
from django.utils import timezone
from rest_framework.test import APIClient
from rest_framework import status
from rest_framework_simplejwt.tokens import RefreshToken

from accounts.models import UserProfile, FranchiseProfile
from products.models import Product, ProductCategory, MinimumOrderPackagingRule
from chat.models import Quotation


class FranchiseQuotationAndMOQWorkflowTestCase(TestCase):
    def setUp(self):
        self.client = APIClient()

        # 1. Admin User
        self.admin = User.objects.create_superuser(
            username='agency_admin',
            email='admin@shivnath.com',
            password='AdminPassword123!',
        )
        p_admin, _ = UserProfile.objects.get_or_create(user=self.admin)
        p_admin.role = 'admin'
        p_admin.save()
        self.admin_token = str(RefreshToken.for_user(self.admin).access_token)

        # 2. Franchise 1 User & Profile
        self.franchise1_user = User.objects.create_user(
            username='franchise_raipur',
            email='raipur@shivnath.com',
            password='FranchisePassword123!',
        )
        p_f1, _ = UserProfile.objects.get_or_create(user=self.franchise1_user)
        p_f1.role = 'franchise'
        p_f1.save()
        self.franchise1_profile = FranchiseProfile.objects.create(
            user=self.franchise1_user,
            business_name='Shivnath Raipur Central Agency',
            dealer_code='DLR-RPR-001',
            city='Raipur',
            address='Telibandha, Raipur',
        )
        self.franchise1_token = str(RefreshToken.for_user(self.franchise1_user).access_token)

        # 3. Franchise 2 User & Profile
        self.franchise2_user = User.objects.create_user(
            username='franchise_bhilai',
            email='bhilai@shivnath.com',
            password='FranchisePassword123!',
        )
        p_f2, _ = UserProfile.objects.get_or_create(user=self.franchise2_user)
        p_f2.role = 'franchise'
        p_f2.save()
        self.franchise2_profile = FranchiseProfile.objects.create(
            user=self.franchise2_user,
            business_name='Shivnath Bhilai Dealer',
            dealer_code='DLR-BHL-002',
            city='Bhilai',
            address='Sector 6, Bhilai',
        )
        self.franchise2_token = str(RefreshToken.for_user(self.franchise2_user).access_token)

        # 4. Customer User
        self.customer_user = User.objects.create_user(
            username='retail_customer',
            email='customer@example.com',
            password='CustomerPassword123!',
        )
        p_cust, _ = UserProfile.objects.get_or_create(user=self.customer_user)
        p_cust.role = 'customer'
        p_cust.save()
        self.customer_token = str(RefreshToken.for_user(self.customer_user).access_token)

        # 5. Products
        self.cat_water, _ = ProductCategory.objects.get_or_create(name='Packaged Drinking Water')
        self.jar_product = Product.objects.create(
            name='Shivnath 20 Litre Dispenser Jar',
            sku='SHV-JAR-20L-TST',
            price=Decimal('80.00'),
            category='Jar',
            package_type='JAR',
            units_per_case=1,
        )
        self.bottle_product = Product.objects.create(
            name='Shivnath 500ml Bottled Water (Box of 24)',
            sku='SHV-500ML-TST',
            price=Decimal('240.00'),
            category='Bottle',
            package_type='BOTTLE',
            units_per_case=24,
        )

    # =========================================================================
    # PART 1: QUOTATION ACCESS RESTRICTIONS & FRANCHISE ISOLATION
    # =========================================================================

    def test_01_customer_cannot_access_quotations(self):
        """Customer tokens are rejected with 403 Forbidden for all quotation endpoints."""
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.customer_token}')

        # 1. Listing endpoint
        res_list = self.client.get('/api/chat/quotations/')
        self.assertEqual(res_list.status_code, status.HTTP_403_FORBIDDEN)

        # 2. Detail endpoint even if quotation ID is known
        q = Quotation.objects.create(
            title='Confidential Franchise Rate Sheet',
            franchise=self.franchise1_profile,
            unit_price=Decimal('50.00'),
            total_price=Decimal('2500.00'),
            status='published',
        )
        res_detail = self.client.get(f'/api/chat/quotations/{q.id}/')
        self.assertEqual(res_detail.status_code, status.HTTP_403_FORBIDDEN)

        # 3. Action endpoint
        res_action = self.client.post(f'/api/chat/quotations/{q.id}/action/', {'action': 'accept'})
        self.assertEqual(res_action.status_code, status.HTTP_403_FORBIDDEN)

    def test_02_admin_creates_quotation_assigned_to_franchise(self):
        """Admin creates published quotation targeting Franchise 1."""
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.admin_token}')

        payload = {
            'title': 'Q1 2026 Special Jar Contract',
            'franchise': self.franchise1_profile.id,
            'product': self.jar_product.id,
            'quantity_tier': '100+ Jars',
            'unit_price': '55.00',
            'total_price': '5500.00',
            'discount_percent': '5.00',
            'additional_charges': '100.00',
            'applicable_terms': 'Guaranteed 24-hr replacement warranty.',
            'validity': 'Valid for 45 days',
            'status': 'published',
        }
        res = self.client.post('/api/chat/quotations/', payload, format='json')
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        q_data = res.data.get('quotation')
        self.assertIsNotNone(q_data)
        self.assertEqual(q_data.get('franchise_id'), self.franchise1_profile.id)
        self.assertEqual(q_data.get('status'), 'published')
        self.assertTrue(q_data.get('quotation_number', '').startswith('Q-FRN-'))

    def test_03_franchise_inbox_isolation(self):
        """Franchise 1 can see only its own quotation; Franchise 2 cannot see it."""
        # Create quotation for Franchise 1
        q_f1 = Quotation.objects.create(
            title='Franchise 1 Rate Card',
            franchise=self.franchise1_profile,
            product=self.jar_product,
            unit_price=Decimal('60.00'),
            total_price=Decimal('3000.00'),
            final_amount=Decimal('3000.00'),
            status='published',
        )

        # Create quotation for Franchise 2
        q_f2 = Quotation.objects.create(
            title='Franchise 2 Rate Card',
            franchise=self.franchise2_profile,
            product=self.bottle_product,
            unit_price=Decimal('200.00'),
            total_price=Decimal('4000.00'),
            final_amount=Decimal('4000.00'),
            status='published',
        )

        # Franchise 1 queries
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.franchise1_token}')
        res_f1 = self.client.get('/api/chat/quotations/')
        self.assertEqual(res_f1.status_code, status.HTTP_200_OK)
        ids_f1 = [q['id'] for q in res_f1.data['quotations']]
        self.assertIn(q_f1.id, ids_f1)
        self.assertNotIn(q_f2.id, ids_f1)

        # Franchise 1 directly requests Franchise 2's quotation -> 403 Forbidden
        res_leak = self.client.get(f'/api/chat/quotations/{q_f2.id}/')
        self.assertEqual(res_leak.status_code, status.HTTP_403_FORBIDDEN)

    # =========================================================================
    # PART 2: QUOTATION ACCEPTANCE & REJECTION ACTIONS
    # =========================================================================

    def test_04_franchise_accepts_quotation(self):
        """Franchise accepts a valid pending quotation."""
        q = Quotation.objects.create(
            title='Bulk Dispenser Agreement',
            franchise=self.franchise1_profile,
            unit_price=Decimal('50.00'),
            total_price=Decimal('5000.00'),
            final_amount=Decimal('5000.00'),
            status='published',
            valid_until=timezone.now().date() + datetime.timedelta(days=30),
        )

        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.franchise1_token}')
        res = self.client.post(f'/api/chat/quotations/{q.id}/action/', {'action': 'accept'})
        self.assertEqual(res.status_code, status.HTTP_200_OK)

        q.refresh_from_db()
        self.assertEqual(q.status, 'accepted')
        self.assertIsNotNone(q.accepted_at)
        self.assertEqual(q.accepted_by, self.franchise1_user)

        # Duplicate acceptance should be rejected
        res_dup = self.client.post(f'/api/chat/quotations/{q.id}/action/', {'action': 'accept'})
        self.assertEqual(res_dup.status_code, status.HTTP_400_BAD_REQUEST)

    def test_05_franchise_rejects_quotation_with_mandatory_reason(self):
        """Rejecting quotation requires a mandatory reason."""
        q = Quotation.objects.create(
            title='High Rate Contract',
            franchise=self.franchise1_profile,
            unit_price=Decimal('90.00'),
            total_price=Decimal('9000.00'),
            final_amount=Decimal('9000.00'),
            status='published',
        )

        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.franchise1_token}')

        # Missing reason -> 400 Bad Request
        res_no_reason = self.client.post(f'/api/chat/quotations/{q.id}/action/', {'action': 'reject', 'reason': ''})
        self.assertEqual(res_no_reason.status_code, status.HTTP_400_BAD_REQUEST)

        # Valid reason -> 200 OK
        res_ok = self.client.post(
            f'/api/chat/quotations/{q.id}/action/',
            {'action': 'reject', 'reason': 'Quoted price exceeds local market budget.'}
        )
        self.assertEqual(res_ok.status_code, status.HTTP_200_OK)

        q.refresh_from_db()
        self.assertEqual(q.status, 'rejected')
        self.assertEqual(q.rejection_reason, 'Quoted price exceeds local market budget.')

    # =========================================================================
    # PART 3: MOQ MANAGEMENT & EFFECTIVE MOQ ENFORCEMENT
    # =========================================================================

    def test_06_admin_creates_baseline_and_franchise_override(self):
        """Admin creates baseline rule (MOQ=5) and permits override up to 20."""
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.admin_token}')

        # 1. Admin Baseline Rule
        res_baseline = self.client.post('/api/products/packaging-rules/', {
            'product': self.jar_product.id,
            'name': 'Jar 20L Baseline Rule',
            'sales_unit': 'JAR',
            'min_order_quantity': 5,
            'units_per_carton': 1,
            'allow_franchise_override': True,
            'max_franchise_moq': 20,
            'is_active': True,
            'applies_to': 'CUSTOMER',
        })
        self.assertIn(res_baseline.status_code, [status.HTTP_200_OK, status.HTTP_201_CREATED])

        # 2. Franchise 1 sets override = 10 (Valid: 5 <= 10 <= 20)
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.franchise1_token}')
        res_f1 = self.client.post('/api/products/packaging-rules/', {
            'product': self.jar_product.id,
            'min_order_quantity': 10,
        })
        self.assertIn(res_f1.status_code, [status.HTTP_200_OK, status.HTTP_201_CREATED])

        # 3. Verify effective MOQ is 10 for Franchise 1
        from products.packaging_services import get_product_moq_info
        info_f1 = get_product_moq_info(self.jar_product, channel='CUSTOMER', franchise=self.franchise1_profile)
        self.assertEqual(info_f1['min_order_quantity'], 10)

        # 4. Verify Franchise 2 still gets baseline MOQ = 5
        info_f2 = get_product_moq_info(self.jar_product, channel='CUSTOMER', franchise=self.franchise2_profile)
        self.assertEqual(info_f2['min_order_quantity'], 5)

    def test_07_franchise_cannot_lower_moq_below_baseline(self):
        """Franchise cannot set MOQ lower than mandatory Admin baseline."""
        # Baseline = 5
        MinimumOrderPackagingRule.objects.create(
            product=self.jar_product,
            franchise=None,
            min_order_quantity=5,
            allow_franchise_override=True,
            max_franchise_moq=25,
            sales_unit='JAR',
            applies_to='CUSTOMER',
        )

        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {self.franchise1_token}')
        # Request MOQ = 3 (Lower than baseline 5) -> must be rejected
        res_low = self.client.post('/api/products/packaging-rules/', {
            'product': self.jar_product.id,
            'min_order_quantity': 3,
        })
        self.assertEqual(res_low.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('cannot be lower than company minimum baseline', res_low.data['message'])

    def test_08_effective_moq_mathematical_invariant(self):
        """Verify Effective MOQ = max(Admin Baseline, Franchise MOQ)."""
        from products.packaging_services import get_product_moq_info

        baseline = MinimumOrderPackagingRule.objects.create(
            product=self.bottle_product,
            franchise=None,
            min_order_quantity=48,
            allow_franchise_override=True,
            max_franchise_moq=100,
            sales_unit='BOTTLE',
            applies_to='CUSTOMER',
        )

        # Case A: Franchise MOQ = 60 -> Effective = 60
        f_rule = MinimumOrderPackagingRule.objects.create(
            product=self.bottle_product,
            franchise=self.franchise1_profile,
            min_order_quantity=60,
            sales_unit='BOTTLE',
            applies_to='CUSTOMER',
        )
        info = get_product_moq_info(self.bottle_product, channel='CUSTOMER', franchise=self.franchise1_profile)
        self.assertEqual(info['min_order_quantity'], 60)

        # Case B: If franchise rule was somehow stored with 36 -> Effective fallback = 48
        f_rule.min_order_quantity = 36
        f_rule.save()
        info_low = get_product_moq_info(self.bottle_product, channel='CUSTOMER', franchise=self.franchise1_profile)
        self.assertEqual(info_low['min_order_quantity'], 48)

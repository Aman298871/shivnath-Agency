from decimal import Decimal
from django.contrib.auth.models import User
from django.test import TestCase
from django.utils import timezone
from rest_framework import status
from rest_framework.test import APIClient

from accounts.models import (
    UserProfile,
    FranchiseProfile,
    CustomerFranchiseRelationship,
    ServiceZone,
    ServiceDistrict,
)
from orders.models import Order, OrderItem, Wallet
from leads.models import Lead
from followups.models import FollowUp
from inventory.models import DealerStockRequest
from products.models import Product


class AdminCustomerCRMAndDashboardTests(TestCase):
    """
    Comprehensive tests for:
    - Admin Customer CRM Directory (pagination, search, filters, aggregations)
    - Admin Customer Detail (profile, attribution, statistics, paginated orders)
    - Admin Authoritative Dashboard Stats (untruncated global DB counts)
    - Permission isolation (Admin vs Franchise vs Customer)
    """

    def setUp(self):
        self.client = APIClient()

        # 1. Admin User
        self.admin_user = User.objects.create_user(
            username='admin_crm_tester',
            email='admin@shivnathwater.com',
            password='TestPassword123!',
            is_staff=True,
            is_superuser=True
        )
        self.admin_profile, _ = UserProfile.objects.get_or_create(user=self.admin_user)
        self.admin_profile.name = 'Master Admin'
        self.admin_profile.role = 'super_admin'
        self.admin_profile.phone = '9893000001'
        self.admin_profile.status = 'active'
        self.admin_profile.save()

        # 2. Franchise User & Profile
        self.franchise_user = User.objects.create_user(
            username='raipur_franchise_user',
            email='raipur@shivnathwater.com',
            password='TestPassword123!'
        )
        self.franchise_profile, _ = FranchiseProfile.objects.get_or_create(
            user=self.franchise_user,
            defaults={
                'business_name': 'Raipur Central Franchise',
                'city': 'Raipur',
                'address': 'Main Road, Raipur',
                'status': 'approved',
                'security_deposit': 50000
            }
        )
        fran_prof, _ = UserProfile.objects.get_or_create(user=self.franchise_user)
        fran_prof.name = 'Raipur Franchise Manager'
        fran_prof.role = 'franchise'
        fran_prof.phone = '9893000002'
        fran_prof.status = 'active'
        fran_prof.save()

        # Second Franchise
        self.bilaspur_user = User.objects.create_user(
            username='bilaspur_franchise_user',
            email='bilaspur@shivnathwater.com',
            password='TestPassword123!'
        )
        self.bilaspur_profile, _ = FranchiseProfile.objects.get_or_create(
            user=self.bilaspur_user,
            defaults={
                'business_name': 'Bilaspur Water Hub',
                'city': 'Bilaspur',
                'address': 'Vyapar Vihar, Bilaspur',
                'status': 'approved',
                'security_deposit': 50000
            }
        )
        bil_prof, _ = UserProfile.objects.get_or_create(user=self.bilaspur_user)
        bil_prof.name = 'Bilaspur Partner'
        bil_prof.role = 'franchise'
        bil_prof.phone = '9893000003'
        bil_prof.status = 'active'
        bil_prof.save()

        # 3. Service District & Zones
        self.district = ServiceDistrict.objects.create(
            name='Raipur District',
            state='Chhattisgarh',
            is_active=True
        )
        self.zone_north = ServiceZone.objects.create(
            district=self.district,
            name='North Raipur Zone',
            code='Z-NR-01',
            is_active=True
        )
        self.zone_south = ServiceZone.objects.create(
            district=self.district,
            name='South Raipur Zone',
            code='Z-SR-02',
            is_active=True
        )

        # 4. Products for Order Items
        self.product_20l = Product.objects.create(
            name='20L Purified Water Jar',
            sku='JAR-20L',
            size='20L',
            price=Decimal('70.00'),
            category='Jar',
            status='Active'
        )
        self.product_carton = Product.objects.create(
            name='500ml Bottled Water Carton (24 Pack)',
            sku='BOT-500ML-24',
            size='500ml',
            price=Decimal('240.00'),
            category='Bottle',
            status='Active'
        )

        # 5. Customer 1 (Active, Zone North, Registered with Raipur Franchise)
        self.customer1 = User.objects.create_user(
            username='cust_aarav',
            email='aarav.sharma@example.com',
            password='TestPassword123!'
        )
        self.cust1_profile, _ = UserProfile.objects.get_or_create(user=self.customer1)
        self.cust1_profile.name = 'Aarav Sharma'
        self.cust1_profile.phone = '9123456780'
        self.cust1_profile.city = 'Raipur'
        self.cust1_profile.district = 'Raipur District'
        self.cust1_profile.address = 'Flat 402, Shanti Heights, Shankar Nagar'
        self.cust1_profile.zone = self.zone_north
        self.cust1_profile.role = 'customer'
        self.cust1_profile.status = 'active'
        self.cust1_profile.gstin = '22AAAAA0000A1Z5'
        self.cust1_profile.gst_legal_name = 'Aarav Enterprises'
        self.cust1_profile.save()

        self.cust1_rel = CustomerFranchiseRelationship.objects.create(
            customer=self.customer1,
            registered_franchise=self.franchise_profile,
            current_serving_franchise=self.franchise_profile,
            zone=self.zone_north,
            district=self.district,
            service_status='active'
        )
        Wallet.objects.create(user=self.customer1, balance=Decimal('350.00'), reward_points=120)

        # 6. Customer 2 (Active, Zone South, Registered with Bilaspur, Served by Raipur)
        self.customer2 = User.objects.create_user(
            username='cust_priya',
            email='priya.verma@example.com',
            password='TestPassword123!'
        )
        self.cust2_profile, _ = UserProfile.objects.get_or_create(user=self.customer2)
        self.cust2_profile.name = 'Priya Verma'
        self.cust2_profile.phone = '9123456781'
        self.cust2_profile.city = 'Raipur'
        self.cust2_profile.district = 'Raipur District'
        self.cust2_profile.address = 'House 12, Civil Lines'
        self.cust2_profile.zone = self.zone_south
        self.cust2_profile.role = 'customer'
        self.cust2_profile.status = 'active'
        self.cust2_profile.save()

        self.cust2_rel = CustomerFranchiseRelationship.objects.create(
            customer=self.customer2,
            registered_franchise=self.bilaspur_profile,
            current_serving_franchise=self.franchise_profile,
            zone=self.zone_south,
            district=self.district,
            service_status='active'
        )

        # 7. Customer 3 (Inactive / Missing Zone / Direct Company)
        self.customer3 = User.objects.create_user(
            username='cust_rohan',
            email='rohan.patel@example.com',
            password='TestPassword123!'
        )
        self.cust3_profile, _ = UserProfile.objects.get_or_create(user=self.customer3)
        self.cust3_profile.name = 'Rohan Patel'
        self.cust3_profile.phone = '9123456782'
        self.cust3_profile.city = 'Durg'
        self.cust3_profile.role = 'customer'
        self.cust3_profile.status = 'inactive'
        self.cust3_profile.save()
        # No CustomerFranchiseRelationship created to test unassigned / honest representation

        # 8. Create Orders for Customer 1 (3 Orders: 1 Delivered, 1 In-Progress, 1 Cancelled)
        # Order 1: Delivered
        self.order1 = Order.objects.create(
            created_by=self.customer1,
            serving_franchise=self.franchise_profile,
            registered_franchise=self.franchise_profile,
            zone=self.zone_north,
            amount=Decimal('350.00'),
            tax_amount=Decimal('42.00'),
            grand_total=Decimal('392.00'),
            status='delivered',
            payment_status='paid',
            order_source='FRANCHISE',
            items_count=5
        )
        OrderItem.objects.create(
            order=self.order1,
            product=self.product_20l,
            product_name=self.product_20l.name,
            quantity=5,
            unit_price=Decimal('70.00'),
            total_price=Decimal('350.00')
        )

        # Order 2: Preparing / In-Progress
        self.order2 = Order.objects.create(
            created_by=self.customer1,
            serving_franchise=self.franchise_profile,
            registered_franchise=self.franchise_profile,
            zone=self.zone_north,
            amount=Decimal('480.00'),
            tax_amount=Decimal('57.60'),
            grand_total=Decimal('537.60'),
            status='preparing',
            payment_status='pending',
            order_source='FRANCHISE',
            items_count=2
        )
        OrderItem.objects.create(
            order=self.order2,
            product=self.product_carton,
            product_name=self.product_carton.name,
            quantity=2,
            unit_price=Decimal('240.00'),
            total_price=Decimal('480.00')
        )

        # Order 3: Cancelled
        self.order3 = Order.objects.create(
            created_by=self.customer1,
            serving_franchise=self.franchise_profile,
            registered_franchise=self.franchise_profile,
            zone=self.zone_north,
            amount=Decimal('140.00'),
            tax_amount=Decimal('16.80'),
            grand_total=Decimal('156.80'),
            status='cancelled',
            payment_status='pending',
            order_source='FRANCHISE',
            items_count=2
        )
        OrderItem.objects.create(
            order=self.order3,
            product=self.product_20l,
            product_name=self.product_20l.name,
            quantity=2,
            unit_price=Decimal('70.00'),
            total_price=Decimal('140.00')
        )

        # 9. Create Orders for Customer 2 (1 Direct Company Order)
        self.order4 = Order.objects.create(
            created_by=self.customer2,
            serving_franchise=None,
            registered_franchise=self.bilaspur_profile,
            zone=self.zone_south,
            amount=Decimal('720.00'),
            tax_amount=Decimal('86.40'),
            grand_total=Decimal('806.40'),
            status='delivered',
            payment_status='paid',
            order_source='DIRECT_COMPANY',
            items_count=3
        )
        OrderItem.objects.create(
            order=self.order4,
            product=self.product_carton,
            product_name=self.product_carton.name,
            quantity=3,
            unit_price=Decimal('240.00'),
            total_price=Decimal('720.00')
        )

        # 10. Dashboard Lead & Followup Fixtures
        Lead.objects.create(
            name='Prospective Franchise A',
            phone='9893111111',
            city='Bhilai',
            score_category='HOT',
            status='interested'
        )
        Lead.objects.create(
            name='Prospective Franchise B',
            phone='9893222222',
            city='Durg',
            score_category='WARM',
            status='franchise_confirmed'
        )
        FollowUp.objects.create(
            lead=Lead.objects.first(),
            followup_datetime=timezone.now(),
            status='Pending',
            note='Initial inquiry follow-up'
        )
        DealerStockRequest.objects.create(
            request_number='SR-TEST-001',
            dealer=self.franchise_profile,
            product=self.product_carton,
            requested_quantity=50,
            status='REQUESTED'
        )

    # -------------------------------------------------------------------------
    # TEST: Customer List CRM
    # -------------------------------------------------------------------------

    def test_admin_customer_list_success(self):
        self.client.force_authenticate(user=self.admin_user)
        res = self.client.get('/api/auth/admin/customers/')

        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertTrue(res.data['success'])
        self.assertEqual(res.data['count'], 3)
        self.assertEqual(res.data['summary']['total_customers'], 3)
        self.assertEqual(res.data['summary']['active_customers'], 2)

        results = res.data['results']
        self.assertEqual(len(results), 3)

        # Verify Customer 1 Aggregations
        c1 = next(c for c in results if c['id'] == self.customer1.id)
        self.assertEqual(c1['name'], 'Aarav Sharma')
        self.assertEqual(c1['phone'], '9123456780')
        self.assertEqual(c1['customer_code'], f'CUST-{1000 + self.customer1.id}')
        self.assertEqual(c1['status'], 'Active')
        self.assertEqual(c1['zone']['name'], 'North Raipur Zone')
        self.assertEqual(c1['registered_franchise']['name'], 'Raipur Central Franchise')
        self.assertEqual(c1['current_serving_franchise']['name'], 'Raipur Central Franchise')
        self.assertEqual(c1['wallet_balance'], 350.0)

        # Check Order Metrics: Total: 3, Delivered: 1, Pending: 1, Cancelled: 1
        m1 = c1['metrics']
        self.assertEqual(m1['total_orders'], 3)
        self.assertEqual(m1['delivered_orders'], 1)
        self.assertEqual(m1['pending_orders'], 1)
        self.assertEqual(m1['cancelled_orders'], 1)
        # Lifetime spend excludes cancelled: 392.00 + 537.60 = 929.60
        self.assertAlmostEqual(m1['total_spent'], 929.60, places=2)
        self.assertIsNotNone(m1['last_order_date'])

    def test_admin_customer_list_search(self):
        self.client.force_authenticate(user=self.admin_user)

        # Search by phone
        res_phone = self.client.get('/api/auth/admin/customers/?search=9123456780')
        self.assertEqual(res_phone.status_code, status.HTTP_200_OK)
        self.assertEqual(res_phone.data['count'], 1)
        self.assertEqual(res_phone.data['results'][0]['name'], 'Aarav Sharma')

        # Search by customer code
        c_code = f'CUST-{1000 + self.customer2.id}'
        res_code = self.client.get(f'/api/auth/admin/customers/?search={c_code}')
        self.assertEqual(res_code.status_code, status.HTTP_200_OK)
        self.assertEqual(res_code.data['count'], 1)
        self.assertEqual(res_code.data['results'][0]['name'], 'Priya Verma')

    def test_admin_customer_list_filters(self):
        self.client.force_authenticate(user=self.admin_user)

        # Filter by status: inactive
        res_inact = self.client.get('/api/auth/admin/customers/?status=inactive')
        self.assertEqual(res_inact.status_code, status.HTTP_200_OK)
        self.assertEqual(res_inact.data['count'], 1)
        self.assertEqual(res_inact.data['results'][0]['name'], 'Rohan Patel')

        # Filter by zone: South Raipur Zone
        res_zone = self.client.get(f'/api/auth/admin/customers/?zone={self.zone_south.id}')
        self.assertEqual(res_zone.status_code, status.HTTP_200_OK)
        self.assertEqual(res_zone.data['count'], 1)
        self.assertEqual(res_zone.data['results'][0]['name'], 'Priya Verma')

    def test_admin_customer_list_unassigned_handling(self):
        self.client.force_authenticate(user=self.admin_user)
        res = self.client.get('/api/auth/admin/customers/?search=Rohan')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        c3 = res.data['results'][0]
        # Missing zone must be truthfully "Not assigned", never fabricated
        self.assertEqual(c3['zone']['name'], 'Not assigned')
        self.assertIsNone(c3['registered_franchise'])
        self.assertIsNone(c3['current_serving_franchise'])

    # -------------------------------------------------------------------------
    # TEST: Customer Detail CRM
    # -------------------------------------------------------------------------

    def test_admin_customer_detail_profile_and_stats(self):
        self.client.force_authenticate(user=self.admin_user)
        res = self.client.get(f'/api/auth/admin/customers/{self.customer1.id}/')

        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertTrue(res.data['success'])

        data = res.data
        cust = data['customer']
        self.assertEqual(cust['name'], 'Aarav Sharma')
        self.assertEqual(cust['gst_profile']['gstin'], '22AAAAA0000A1Z5')
        self.assertEqual(cust['zone']['name'], 'North Raipur Zone')
        self.assertEqual(cust['wallet']['balance'], 350.0)

        # Statistics
        stats = data['statistics']
        self.assertEqual(stats['total_orders'], 3)
        self.assertEqual(stats['delivered_orders'], 1)
        self.assertEqual(stats['pending_orders'], 1)
        self.assertEqual(stats['cancelled_orders'], 1)
        self.assertAlmostEqual(stats['total_order_value'], 929.60, places=2)

        # Paginated Order History
        orders_hist = data['order_history']
        self.assertEqual(orders_hist['count'], 3)
        self.assertEqual(len(orders_hist['orders']), 3)

        # Check Order details inside history
        ord_delivered = next(o for o in orders_hist['orders'] if o['id'] == self.order1.id)
        self.assertEqual(ord_delivered['status'], 'delivered')
        self.assertEqual(ord_delivered['serving_franchise']['name'], 'Raipur Central Franchise')
        self.assertEqual(ord_delivered['registered_franchise']['name'], 'Raipur Central Franchise')
        self.assertEqual(len(ord_delivered['items']), 1)
        self.assertEqual(ord_delivered['items'][0]['product_name'], '20L Purified Water Jar')

    def test_admin_customer_detail_direct_company_attribution(self):
        self.client.force_authenticate(user=self.admin_user)
        res = self.client.get(f'/api/auth/admin/customers/{self.customer2.id}/')
        self.assertEqual(res.status_code, status.HTTP_200_OK)

        orders = res.data['order_history']['orders']
        self.assertEqual(len(orders), 1)
        direct_ord = orders[0]
        self.assertEqual(direct_ord['order_source'], 'DIRECT_COMPANY')
        # Serving franchise must be None for direct company, registered must remain Bilaspur
        self.assertIsNone(direct_ord['serving_franchise'])
        self.assertEqual(direct_ord['registered_franchise']['name'], 'Bilaspur Water Hub')

    # -------------------------------------------------------------------------
    # TEST: Authoritative Admin Dashboard Stats
    # -------------------------------------------------------------------------

    def test_admin_dashboard_stats_authoritative_aggregates(self):
        self.client.force_authenticate(user=self.admin_user)
        res = self.client.get('/api/auth/admin/dashboard-stats/')

        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertTrue(res.data['success'])

        stats = res.data['stats']

        # Leads
        self.assertEqual(stats['total_leads'], 2)
        self.assertEqual(stats['hot_leads'], 1)
        self.assertEqual(stats['confirmed_dealers'], 1)
        self.assertEqual(stats['followups_today'], 1)

        # Orders (4 total in DB: order1, order2, order3, order4)
        self.assertEqual(stats['total_orders'], 4)
        self.assertEqual(stats['delivered_orders'], 2) # order1, order4
        self.assertEqual(stats['pending_orders'], 1)   # order2
        self.assertEqual(stats['cancelled_orders'], 1) # order3
        # Total order value (excluding cancelled: 392.00 + 537.60 + 806.40 = 1736.00)
        self.assertAlmostEqual(stats['total_order_value'], 1736.00, places=2)

        # Customers (3 legitimate customers, staff/franchises excluded)
        self.assertEqual(stats['total_customers'], 3)
        self.assertEqual(stats['active_customers'], 2)

        # Franchises (2 approved)
        self.assertEqual(stats['total_franchises'], 2)
        self.assertEqual(stats['pending_franchises'], 0)

        # Stock Requests
        self.assertEqual(stats['franchise_stock_requests'], 1)
        self.assertEqual(stats['pending_stock_requests'], 1)

    # -------------------------------------------------------------------------
    # TEST: Permission Isolation
    # -------------------------------------------------------------------------

    def test_unauthorized_access_prevented(self):
        # 1. Anonymous user -> 401
        res_anon = self.client.get('/api/auth/admin/customers/')
        self.assertIn(res_anon.status_code, [status.HTTP_401_UNAUTHORIZED, status.HTTP_403_FORBIDDEN])

        # 2. Franchise user -> 403 Forbidden
        self.client.force_authenticate(user=self.franchise_user)
        res_fran = self.client.get('/api/auth/admin/customers/')
        self.assertEqual(res_fran.status_code, status.HTTP_403_FORBIDDEN)

        res_fran_stats = self.client.get('/api/auth/admin/dashboard-stats/')
        self.assertEqual(res_fran_stats.status_code, status.HTTP_403_FORBIDDEN)

        # 3. Customer user -> 403 Forbidden
        self.client.force_authenticate(user=self.customer1)
        res_cust = self.client.get('/api/auth/admin/customers/')
        self.assertEqual(res_cust.status_code, status.HTTP_403_FORBIDDEN)

import json
from decimal import Decimal
from django.test import TestCase
from django.contrib.auth import get_user_model
from rest_framework.test import APIClient

from accounts.models import FranchiseProfile, ServiceZone, ServiceDistrict, SupportContact, UserProfile
from products.models import Product, ProductCategory
from orders.models import Order, OrderItem
from billing.models import Invoice, PaymentTransaction

User = get_user_model()


class CustomerOutstandingReconciliationTests(TestCase):
    def setUp(self):
        self.client = APIClient()

        # Admin User
        self.admin_user, _ = User.objects.get_or_create(
            username='admin_audit',
            defaults={
                'email': 'admin@shivnath.com',
                'is_staff': True,
                'is_superuser': True,
            }
        )
        self.admin_user.set_password('Password@123')
        self.admin_user.save()
        UserProfile.objects.update_or_create(
            user=self.admin_user,
            defaults={'role': 'admin', 'phone': '9806247194'},
        )

        # Support Contact
        self.support_contact, _ = SupportContact.objects.get_or_create(
            role='customer',
            defaults={
                'name': 'Shivnath Support Desk',
                'phone': '+91 98062 47194',
                'is_active': True,
            }
        )

        # Customer User
        self.customer, _ = User.objects.get_or_create(
            username='cust_audit_77',
            defaults={
                'email': 'cust77@shivnath.com',
            }
        )
        self.customer.set_password('Password@123')
        self.customer.save()
        UserProfile.objects.update_or_create(
            user=self.customer,
            defaults={'role': 'customer', 'phone': '9893000077'},
        )

        # District and Zone
        self.district, _ = ServiceDistrict.objects.get_or_create(
            name='Raipur Audit Test',
            defaults={'is_active': True}
        )
        self.zone, _ = ServiceZone.objects.get_or_create(
            name='Devendra Nagar Audit',
            district=self.district,
            defaults={'is_active': True}
        )

        # Franchise User and Profile
        self.franchise_user, _ = User.objects.get_or_create(
            username='franchise_dn_audit',
            defaults={
                'email': 'dn_water@shivnath.com',
            }
        )
        self.franchise_user.set_password('Password@123')
        self.franchise_user.save()
        UserProfile.objects.update_or_create(
            user=self.franchise_user,
            defaults={'role': 'franchise', 'phone': '+91 98264 21818'},
        )
        self.franchise_profile, _ = FranchiseProfile.objects.get_or_create(
            user=self.franchise_user,
            defaults={
                'business_name': 'Devendra Nagar Water Supply',
                'city': 'Raipur',
                'address': 'Sector 2, Devendra Nagar',
                'status': 'approved',
            }
        )

        # Product
        self.category, _ = ProductCategory.objects.get_or_create(
            name='Packaged Water Audit',
            defaults={'slug': 'pdw_audit'}
        )
        self.product_jar, _ = Product.objects.get_or_create(
            sku='SHV-JAR-20L-AUDIT',
            defaults={
                'name': 'Shivnath 20L Jar',
                'category_ref': self.category,
                'price': Decimal('70.00'),
                'package_type': 'JAR',
                'status': 'Active',
            }
        )
        self.product_bottle, _ = Product.objects.get_or_create(
            sku='SHV-500ML-BOX-AUDIT',
            defaults={
                'name': 'Shivnath 500ml Box',
                'category_ref': self.category,
                'price': Decimal('120.00'),
                'package_type': 'BOTTLE',
                'status': 'Active',
            }
        )

    def test_01_genuine_unpaid_invoice_with_itemization_and_franchise_collector(self):
        """Genuine unpaid order fulfilled by franchise must attribute correctly to Franchise."""
        self.client.force_authenticate(user=self.customer)

        order = Order.objects.create(
            created_by=self.customer,
            serving_franchise=self.franchise_profile,
            status='delivered',
            payment_status='pending',
            amount=Decimal('140.00'),
            tax_amount=Decimal('25.20'),
            grand_total=Decimal('165.20'),
            remaining_payable_amount=Decimal('165.20'),
        )
        OrderItem.objects.create(
            order=order,
            product=self.product_jar,
            quantity=2,
            unit_price=Decimal('70.00'),
            total_price=Decimal('140.00'),
        )
        inv = Invoice.objects.create(
            order=order,
            invoice_number='SHV/2026/RET-9001',
            invoice_type='CUSTOMER_SALE_INVOICE',
            status='UNPAID',
            subtotal=Decimal('140.00'),
            cgst_amount=Decimal('12.60'),
            sgst_amount=Decimal('12.60'),
            grand_total=Decimal('165.20'),
            amount_paid=Decimal('0.00'),
        )

        res = self.client.get('/api/billing/customer-outstanding/')
        self.assertEqual(res.status_code, 200)
        data = res.data
        self.assertTrue(data['success'])
        self.assertEqual(data['summary']['total_outstanding'], 165.2)
        self.assertEqual(data['summary']['franchise_outstanding'], 165.2)
        self.assertEqual(data['summary']['admin_outstanding'], 0.0)

        # Contacts verification
        self.assertEqual(data['contacts']['franchise']['name'], 'Devendra Nagar Water Supply')
        self.assertEqual(data['contacts']['franchise']['phone'], '+91 98264 21818')
        self.assertTrue(data['contacts']['franchise']['is_configured'])

        # Items breakdown
        self.assertEqual(len(data['items']), 1)
        item = data['items'][0]
        self.assertEqual(item['order_id'], order.id)
        self.assertEqual(item['invoice_number'], 'SHV/2026/RET-9001')
        self.assertEqual(item['collector_type'], 'FRANCHISE')
        self.assertEqual(item['collector_name'], 'Devendra Nagar Water Supply')
        self.assertEqual(item['remaining_due'], 165.2)
        self.assertEqual(len(item['products']), 1)
        self.assertEqual(item['products'][0]['product_name'], 'Shivnath 20L Jar')
        self.assertEqual(item['products'][0]['quantity'], 2)

    def test_02_partially_paid_invoice(self):
        """Partially paid invoice must reflect exact remaining due, not original total."""
        self.client.force_authenticate(user=self.customer)

        order = Order.objects.create(
            created_by=self.customer,
            serving_franchise=self.franchise_profile,
            status='delivered',
            payment_status='partial',
            amount=Decimal('140.00'),
            grand_total=Decimal('165.20'),
            remaining_payable_amount=Decimal('65.20'),
        )
        inv = Invoice.objects.create(
            order=order,
            invoice_number='SHV/2026/RET-9002',
            invoice_type='CUSTOMER_SALE_INVOICE',
            status='PARTIAL',
            subtotal=Decimal('140.00'),
            grand_total=Decimal('165.20'),
            amount_paid=Decimal('100.00'),
        )

        res = self.client.get('/api/billing/customer-outstanding/')
        self.assertEqual(res.status_code, 200)
        self.assertEqual(res.data['summary']['total_outstanding'], 65.2)
        self.assertEqual(res.data['items'][0]['amount_paid'], 100.0)
        self.assertEqual(res.data['items'][0]['remaining_due'], 65.2)

    def test_03_fully_paid_invoice_must_not_remain_outstanding(self):
        """Fully paid orders and invoices must never be returned in outstanding."""
        self.client.force_authenticate(user=self.customer)

        order = Order.objects.create(
            created_by=self.customer,
            status='delivered',
            payment_status='paid',
            grand_total=Decimal('500.00'),
        )
        Invoice.objects.create(
            order=order,
            invoice_number='SHV/2026/RET-PAID',
            status='PAID',
            grand_total=Decimal('500.00'),
            amount_paid=Decimal('500.00'),
        )

        res = self.client.get('/api/billing/customer-outstanding/')
        self.assertEqual(res.status_code, 200)
        self.assertEqual(res.data['summary']['total_outstanding'], 0.0)
        self.assertEqual(len(res.data['items']), 0)

    def test_04_cancelled_orders_excluded_even_if_invoice_unpaid(self):
        """Cancelled orders must never create phantom dues (e.g. root cause of ₹47)."""
        self.client.force_authenticate(user=self.customer)

        order = Order.objects.create(
            created_by=self.customer,
            status='cancelled',
            payment_status='pending',
            amount=Decimal('40.00'),
            grand_total=Decimal('47.20'),
        )
        # Stale invoice sitting as unpaid
        Invoice.objects.create(
            order=order,
            invoice_number='SHV/2026/RET-STALE-47',
            status='UNPAID',
            grand_total=Decimal('47.20'),
            amount_paid=Decimal('0.00'),
        )

        res = self.client.get('/api/billing/customer-outstanding/')
        self.assertEqual(res.status_code, 200)
        self.assertEqual(res.data['summary']['total_outstanding'], 0.0)
        self.assertEqual(len(res.data['items']), 0)

    def test_05_separate_admin_and_franchise_balances(self):
        """Separate Franchise and Admin balances must be computed independently without double counting."""
        self.client.force_authenticate(user=self.customer)

        # Franchise order: ₹100
        o_franchise = Order.objects.create(
            created_by=self.customer,
            serving_franchise=self.franchise_profile,
            status='delivered',
            payment_status='pending',
            grand_total=Decimal('100.00'),
        )
        Invoice.objects.create(
            order=o_franchise,
            invoice_number='SHV/2026/RET-F100',
            status='UNPAID',
            grand_total=Decimal('100.00'),
            amount_paid=Decimal('0.00'),
        )

        # Admin Direct order: ₹200
        o_admin = Order.objects.create(
            created_by=self.customer,
            serving_franchise=None,
            order_source='DIRECT_COMPANY',
            status='delivered',
            payment_status='pending',
            grand_total=Decimal('200.00'),
        )
        Invoice.objects.create(
            order=o_admin,
            invoice_number='SHV/2026/INV-A200',
            invoice_type='DIRECT_COMPANY_SALE_INVOICE',
            status='UNPAID',
            grand_total=Decimal('200.00'),
            amount_paid=Decimal('0.00'),
        )

        res = self.client.get('/api/billing/customer-outstanding/')
        self.assertEqual(res.status_code, 200)
        data = res.data
        self.assertEqual(data['summary']['total_outstanding'], 300.0)
        self.assertEqual(data['summary']['franchise_outstanding'], 100.0)
        self.assertEqual(data['summary']['admin_outstanding'], 200.0)

        # Item collector types
        types = {item['order_id']: item['collector_type'] for item in data['items']}
        self.assertEqual(types[o_franchise.id], 'FRANCHISE')
        self.assertEqual(types[o_admin.id], 'ADMIN')

    def test_06_admin_can_inspect_any_customer_outstanding(self):
        """Staff/Admin can pass ?user_id=X to audit customer ledger."""
        self.client.force_authenticate(user=self.admin_user)

        o = Order.objects.create(
            created_by=self.customer,
            status='delivered',
            payment_status='pending',
            grand_total=Decimal('50.00'),
        )

        res = self.client.get(f'/api/billing/customer-outstanding/?user_id={self.customer.id}')
        self.assertEqual(res.status_code, 200)
        self.assertEqual(res.data['customer']['id'], self.customer.id)
        self.assertEqual(res.data['summary']['total_outstanding'], 50.0)

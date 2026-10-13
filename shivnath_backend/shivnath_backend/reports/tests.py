import csv
from datetime import date, timedelta
from decimal import Decimal
from django.contrib.auth.models import User
from django.utils import timezone
from rest_framework.test import APITestCase

from accounts.models import UserProfile, FranchiseProfile, CustomerStockCycle
from reports.csv_export_views import sanitize_csv_cell


class CSVFormulaInjectionAndBOMTestCase(APITestCase):
    """
    Verifies CSV security (CWE-1236 mitigation) and Excel UTF-8 BOM encoding.
    """

    def setUp(self):
        self.admin = User.objects.create_user(
            username='admin_report_test',
            email='admin_report@shivnath.com',
            password='password123',
            is_staff=True,
            is_superuser=True
        )
        self.admin_profile = UserProfile.objects.filter(user=self.admin).first()
        if not self.admin_profile:
            self.admin_profile = UserProfile.objects.create(user=self.admin, role='admin')
        else:
            self.admin_profile.role = 'admin'
            self.admin_profile.save()

    def test_sanitize_csv_cell_dangerous_formulas(self):
        dangerous_inputs = [
            '=cmd|\' /C calc\'!A0',
            '+1234567890',
            '-1+1',
            '@SUM(A1:A10)',
            '\tDDE("cmd";"calc";"")',
            '\rFormulaInjection',
        ]
        for payload in dangerous_inputs:
            sanitized = sanitize_csv_cell(payload)
            self.assertTrue(
                sanitized.startswith("'"),
                f"Payload {payload} was not sanitized with leading single-quote! Got: {sanitized}"
            )

        # Safe values must NOT be modified
        self.assertEqual(sanitize_csv_cell(100), 100)
        self.assertEqual(sanitize_csv_cell(45.50), 45.50)
        self.assertEqual(sanitize_csv_cell(Decimal('120.00')), Decimal('120.00'))
        self.assertEqual(sanitize_csv_cell('Shivnath Water'), 'Shivnath Water')
        self.assertEqual(sanitize_csv_cell(None), '')

    def test_csv_export_response_headers_and_utf8_bom(self):
        self.client.force_authenticate(user=self.admin)
        response = self.client.get('/api/reports/export/')
        self.assertEqual(response.status_code, 200)

        # Content-Type check
        content_type = response.headers.get('Content-Type', '')
        self.assertIn('text/csv', content_type)
        self.assertIn('charset=utf-8', content_type)

        # Content-Disposition check
        disp = response.headers.get('Content-Disposition', '')
        self.assertIn('attachment;', disp)
        self.assertIn('.csv', disp)

        # Excel UTF-8 BOM check (\ufeff in utf-8 is b'\xef\xbb\xbf')
        self.assertTrue(
            response.content.startswith('\ufeff'.encode('utf-8')),
            "Exported CSV does not start with standard UTF-8 BOM (\\ufeff)!"
        )


class CSVReportAccessControlTestCase(APITestCase):
    """
    Verifies server-side role and authorization boundaries for report exports.
    """

    def setUp(self):
        # 1. Admin
        self.admin = User.objects.create_user(
            username='admin_access_test',
            email='admin_acc@shivnath.com',
            password='password123',
            is_staff=True,
            is_superuser=True
        )
        UserProfile.objects.filter(user=self.admin).update(role='admin')

        # 2. Franchise
        self.franchise_user = User.objects.create_user(
            username='dealer_access_test',
            email='dealer_acc@shivnath.com',
            password='password123'
        )
        UserProfile.objects.filter(user=self.franchise_user).update(role='franchise')
        self.franchise_profile = FranchiseProfile.objects.create(
            user=self.franchise_user,
            business_name='Bilaspur Pure Water Agency',
            city='Bilaspur',
            status='approved'
        )

        # 3. Customer
        self.customer = User.objects.create_user(
            username='customer_access_test',
            email='cust_acc@shivnath.com',
            password='password123'
        )
        UserProfile.objects.filter(user=self.customer).update(role='customer')

    def test_unauthenticated_user_denied(self):
        response = self.client.get('/api/reports/export/')
        self.assertEqual(response.status_code, 401)

    def test_customer_user_forbidden(self):
        self.client.force_authenticate(user=self.customer)
        response = self.client.get('/api/reports/export/')
        self.assertEqual(response.status_code, 403)

    def test_franchise_user_allowed_for_franchise_reports(self):
        self.client.force_authenticate(user=self.franchise_user)
        # Orders report
        response = self.client.get('/api/reports/export/orders/')
        self.assertEqual(response.status_code, 200)

        # Stock requests report
        response = self.client.get('/api/reports/export/stock_requests/')
        self.assertEqual(response.status_code, 200)

    def test_franchise_user_forbidden_for_admin_only_reports(self):
        self.client.force_authenticate(user=self.franchise_user)
        # Production / BOM is restricted to plant admin
        response = self.client.get('/api/reports/export/production/')
        self.assertEqual(response.status_code, 403)

        # Directory / All Users is restricted to admin
        response = self.client.get('/api/reports/export/directory/')
        self.assertEqual(response.status_code, 403)

    def test_admin_user_can_export_all_report_types(self):
        self.client.force_authenticate(user=self.admin)
        report_types = [
            'comprehensive',
            'orders',
            'sales_revenue',
            'inventory',
            'stock_requests',
            'directory',
            'payments',
            'production',
        ]
        for rt in report_types:
            with self.subTest(report_type=rt):
                response = self.client.get(f'/api/reports/export/{rt}/')
                self.assertEqual(response.status_code, 200)


class CustomerDirectoryNullSafetyTestCase(APITestCase):
    """
    Verifies that the customer directory does not crash (500) when a customer's
    cycle has serving_franchise=None (direct company orders).
    """

    def setUp(self):
        self.admin = User.objects.create_user(
            username='admin_dir_test',
            email='admin_dir@shivnath.com',
            password='password123',
            is_staff=True,
            is_superuser=True
        )
        UserProfile.objects.filter(user=self.admin).update(role='admin')

        self.customer = User.objects.create_user(
            username='cust_direct_test',
            email='cust_direct@shivnath.com',
            password='password123'
        )
        self.customer_profile = UserProfile.objects.filter(user=self.customer).first()
        if not self.customer_profile:
            self.customer_profile = UserProfile.objects.create(
                user=self.customer,
                role='customer',
                name='Direct Company Customer'
            )
        else:
            self.customer_profile.role = 'customer'
            self.customer_profile.name = 'Direct Company Customer'
            self.customer_profile.save()

    def test_customer_directory_with_null_serving_franchise(self):
        today = timezone.now().date()
        # Create an active cycle with NO serving franchise (serving_franchise=None)
        CustomerStockCycle.objects.create(
            customer=self.customer,
            duration_choice='30_days',
            duration_days=30,
            start_date=today,
            expected_end_date=today + timedelta(days=30),
            service_status='active',
            serving_franchise=None,
        )

        self.client.force_authenticate(user=self.admin)
        response = self.client.get('/api/accounts/users/?role=customer')
        self.assertEqual(response.status_code, 200)

        data = response.json()
        self.assertTrue(data.get('success', False))
        users = data.get('users', [])
        found_cust = next((u for u in users if u['id'] == self.customer.id), None)
        self.assertIsNotNone(found_cust)
        stock_info = found_cust.get('active_stock_cycle')
        self.assertIsNotNone(stock_info)
        self.assertIsNone(stock_info.get('serving_franchise_id'))
        self.assertEqual(stock_info.get('serving_franchise_name'), 'Shivnath Agency (Direct)')

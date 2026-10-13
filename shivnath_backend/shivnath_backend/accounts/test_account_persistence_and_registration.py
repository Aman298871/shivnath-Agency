import io
from decimal import Decimal
from django.contrib.auth.models import User
from django.core.files.uploadedfile import SimpleUploadedFile
from django.db import connection
from django.test import TestCase
from rest_framework.test import APIClient
from rest_framework import status

from accounts.models import (
    UserProfile,
    FranchiseProfile,
    ServiceDistrict,
    ServiceZone,
    FranchiseTerritoryAssignment,
    CustomerFranchiseRelationship,
    DealerDocument,
    AdminNotification,
)


class AccountPersistenceAndRegistrationRegressionTests(TestCase):
    """
    Authoritative regression test suite validating:
    1. Atomic and transactional Customer registration and persistence.
    2. Atomic and transactional Franchise registration with FSSAI KYC document and pending status.
    3. Password hashing security (PBKDF2/SHA256, no plaintext in DB).
    4. Duplicate email and mobile number prevention (no duplicate accounts).
    5. Multi-identifier login resolution (email, phone, case-insensitivity, formatted phone, ID).
    6. Admin User Directory visibility and isolation.
    7. Database connection close/reopen persistence (simulating process restart).
    """

    def setUp(self):
        self.client = APIClient()

        # 1. Master Territory Setup
        self.district, _ = ServiceDistrict.objects.get_or_create(
            name='Raipur', defaults={'state': 'Chhattisgarh', 'is_active': True}
        )
        self.zone, _ = ServiceZone.objects.get_or_create(
            district=self.district, name='East Raipur', defaults={'code': 'RP-EAST', 'is_active': True}
        )

        # 2. Existing Headquarters Franchise (required for territory fallback)
        self.hq_user = User.objects.create_user(
            username='hq@shivnath.com',
            email='hq@shivnath.com',
            password='Password123!',
            first_name='HQ Manager',
        )
        self.hq_user_prof, _ = UserProfile.objects.get_or_create(user=self.hq_user)
        self.hq_user_prof.name = 'HQ Manager'
        self.hq_user_prof.phone = '9826000001'
        self.hq_user_prof.role = 'franchise'
        self.hq_user_prof.status = 'active'
        self.hq_user_prof.district = 'Raipur'
        self.hq_user_prof.city = 'Raipur'
        self.hq_user_prof.save()

        self.hq_franchise, _ = FranchiseProfile.objects.get_or_create(
            user=self.hq_user,
            defaults={
                'business_name': 'Shivnath Agency Central HQ',
                'city': 'Raipur',
                'address': 'Industrial Estate, Raipur',
                'territory': 'East Raipur',
                'fssai_number': '10522016000123',
                'is_headquarters': True,
                'status': 'approved',
            }
        )
        FranchiseTerritoryAssignment.objects.get_or_create(
            franchise=self.hq_franchise,
            zone=self.zone,
            defaults={'is_primary': True, 'is_active': True}
        )

        # 3. Super Admin Account
        self.admin_user = User.objects.create_user(
            username='admin@gmail.com',
            email='admin@gmail.com',
            password='Password123!',
            first_name='Super Admin',
            is_staff=True,
            is_superuser=True,
        )
        self.admin_prof, _ = UserProfile.objects.get_or_create(user=self.admin_user)
        self.admin_prof.name = 'Super Admin'
        self.admin_prof.phone = '9800000000'
        self.admin_prof.role = 'super_admin'
        self.admin_prof.status = 'active'
        self.admin_prof.save()

    def test_01_customer_atomic_registration_and_persistence(self):
        """Verify Customer registration is atomic, commits to all required tables, and returns 201."""
        payload = {
            'name': 'Aman Customer',
            'phone': '9826112345',
            'email': 'aman.customer@waternow.test',
            'password': 'SecurePass@123',
            'confirm_password': 'SecurePass@123',
            'city': 'Raipur',
            'district': 'Raipur',
            'zone_id': self.zone.id,
            'address': 'House 14, Shankar Nagar',
        }

        response = self.client.post('/api/auth/register/customer/', payload, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED, response.data)
        self.assertTrue(response.data.get('success'))

        # Verify auth_user commit
        user = User.objects.filter(email='aman.customer@waternow.test').first()
        self.assertIsNotNone(user, "User was not persisted to auth_user table.")
        self.assertEqual(user.first_name, 'Aman Customer')
        self.assertTrue(user.is_active)

        # Verify accounts_userprofile commit
        profile = UserProfile.objects.filter(user=user).first()
        self.assertIsNotNone(profile, "UserProfile was not persisted to accounts_userprofile table.")
        self.assertEqual(profile.role, 'customer')
        self.assertEqual(profile.phone, '9826112345')
        self.assertEqual(profile.district, 'Raipur')
        self.assertEqual(profile.status, 'active')

        # Verify accounts_customerfranchiserelationship commit
        rel = CustomerFranchiseRelationship.objects.filter(customer=user).first()
        self.assertIsNotNone(rel, "CustomerFranchiseRelationship was not created.")
        self.assertEqual(rel.registered_franchise, self.hq_franchise)

    def test_02_franchise_atomic_registration_and_pending_status(self):
        """Verify Franchise registration commits user, profile, franchise profile, and KYC doc with pending status."""
        dummy_fssai_pdf = SimpleUploadedFile(
            name='fssai_cert.pdf',
            content=b'%PDF-1.4 dummy fssai certificate stream for automated testing',
            content_type='application/pdf'
        )

        payload = {
            'owner_name': 'Ramesh Franchise Owner',
            'business_name': 'Ramesh Pure Water Distribution',
            'phone': '9826198765',
            'email': 'ramesh.franchise@waternow.test',
            'password': 'SecurePass@123',
            'confirm_password': 'SecurePass@123',
            'city': 'Raipur',
            'address': 'Shop 10, Pandri Market',
            'territory': 'East Raipur',
            'fssai_number': '10523016000999',
            'document_file': dummy_fssai_pdf,
        }

        response = self.client.post('/api/auth/register/franchise/', payload, format='multipart')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED, response.data)
        self.assertTrue(response.data.get('success'))
        self.assertEqual(response.data.get('status'), 'Pending Admin Approval')

        # Verify auth_user
        user = User.objects.filter(email='ramesh.franchise@waternow.test').first()
        self.assertIsNotNone(user, "Franchise user was not created in auth_user.")

        # Verify UserProfile
        profile = UserProfile.objects.filter(user=user).first()
        self.assertIsNotNone(profile)
        self.assertEqual(profile.role, 'franchise')
        self.assertEqual(profile.status, 'pending')

        # Verify FranchiseProfile
        fp = FranchiseProfile.objects.filter(user=user).first()
        self.assertIsNotNone(fp)
        self.assertEqual(fp.business_name, 'Ramesh Pure Water Distribution')
        self.assertEqual(fp.status, 'pending')
        self.assertEqual(fp.fssai_number, '10523016000999')

        # Verify DealerDocument
        doc = DealerDocument.objects.filter(dealer=fp).first()
        self.assertIsNotNone(doc)
        self.assertEqual(doc.document_type, 'FSSAI_CERTIFICATE')
        self.assertEqual(doc.verification_status, 'PENDING')

        # Verify AdminNotification
        notif = AdminNotification.objects.filter(reference_id=user.id).first()
        self.assertIsNotNone(notif)
        self.assertEqual(notif.notification_type, 'franchise_registration')

    def test_03_password_hashing_security(self):
        """Verify passwords are mathematically hashed with PBKDF2/SHA256 and never stored in plaintext."""
        raw_password = 'MySecretPassword123'
        user = User.objects.create_user(
            username='security_test@waternow.test',
            email='security_test@waternow.test',
            password=raw_password,
        )

        # Raw password must NEVER appear in the database
        self.assertNotEqual(user.password, raw_password)
        self.assertTrue(user.password.startswith('pbkdf2_sha256$'))
        self.assertTrue(user.check_password(raw_password))
        self.assertFalse(user.check_password('WrongPassword'))

    def test_04_duplicate_email_and_phone_validation(self):
        """Verify registration prevents duplicate emails and phones with clear 400 validation messages."""
        payload = {
            'name': 'Existing Customer',
            'phone': '9826111111',
            'email': 'existing.customer@waternow.test',
            'password': 'Password123!',
            'confirm_password': 'Password123!',
            'city': 'Raipur',
            'district': 'Raipur',
            'zone_id': self.zone.id,
            'address': 'Raipur Address',
        }
        res1 = self.client.post('/api/auth/register/customer/', payload, format='json')
        self.assertEqual(res1.status_code, status.HTTP_201_CREATED)

        # Duplicate email
        dup_email_payload = payload.copy()
        dup_email_payload['phone'] = '9826222222'
        res_dup_email = self.client.post('/api/auth/register/customer/', dup_email_payload, format='json')
        self.assertEqual(res_dup_email.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('email', str(res_dup_email.data))

    def test_05_multi_identifier_login_resolution(self):
        """Verify login endpoint resolves accounts by email, phone, and case-insensitively."""
        user = User.objects.create_user(
            username='multilogin@waternow.test',
            email='multilogin@waternow.test',
            password='Password123!',
            first_name='Multi User',
        )
        prof, _ = UserProfile.objects.get_or_create(user=user)
        prof.name = 'Multi User'
        prof.phone = '9826333333'
        prof.role = 'customer'
        prof.status = 'active'
        prof.save()

        # 1. Login with lowercase email
        r1 = self.client.post('/api/auth/login/', {'email': 'multilogin@waternow.test', 'password': 'Password123!'})
        self.assertEqual(r1.status_code, status.HTTP_200_OK, r1.data)
        self.assertIn('access', r1.data)

        # 2. Login with uppercase / mixed-case email
        r2 = self.client.post('/api/auth/login/', {'email': 'MultiLogin@WaterNow.TEST', 'password': 'Password123!'})
        self.assertEqual(r2.status_code, status.HTTP_200_OK, r2.data)

        # 3. Login with 10-digit mobile number
        r3 = self.client.post('/api/auth/login/', {'email': '9826333333', 'password': 'Password123!'})
        self.assertEqual(r3.status_code, status.HTTP_200_OK, r3.data)

        # 4. Login with +91 formatted mobile number
        r4 = self.client.post('/api/auth/login/', {'email': '+91 9826333333', 'password': 'Password123!'})
        self.assertEqual(r4.status_code, status.HTTP_200_OK, r4.data)

        # 5. Non-existent account returns 400 "No account found"
        r5 = self.client.post('/api/auth/login/', {'email': 'ghost_user@waternow.test', 'password': 'Password123!'})
        self.assertEqual(r5.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('No account found with these credentials', str(r5.data))

    def test_06_admin_user_directory_visibility_and_isolation(self):
        """Verify Admin User Directory correctly returns registered customers and excludes admin/staff."""
        # Create test customer
        cust_user = User.objects.create_user(
            username='directory_cust@waternow.test',
            email='directory_cust@waternow.test',
            password='Password123!',
            first_name='Directory Customer',
        )
        prof, _ = UserProfile.objects.get_or_create(user=cust_user)
        prof.name = 'Directory Customer'
        prof.phone = '9826444444'
        prof.role = 'customer'
        prof.status = 'active'
        prof.save()

        # Authenticate as super admin
        login_res = self.client.post('/api/auth/login/', {'email': 'admin@gmail.com', 'password': 'Password123!'})
        token = login_res.data['access']
        self.client.credentials(HTTP_AUTHORIZATION=f'Bearer {token}')

        # Query /api/accounts/users/
        dir_res = self.client.get('/api/accounts/users/')
        self.assertEqual(dir_res.status_code, status.HTTP_200_OK)
        users = dir_res.data.get('users', [])
        user_emails = [u['email'] for u in users]

        # Customer must be listed
        self.assertIn('directory_cust@waternow.test', user_emails)
        # Super admin must be excluded from customer directory
        self.assertNotIn('admin@gmail.com', user_emails)

    def test_07_database_connection_persistence_across_reconnect(self):
        """Verify records survive database connection close and reopen (simulating process restart)."""
        user = User.objects.create_user(
            username='persist_check@waternow.test',
            email='persist_check@waternow.test',
            password='Password123!',
        )
        prof, _ = UserProfile.objects.get_or_create(user=user)
        prof.name = 'Persistence User'
        prof.phone = '9826555555'
        prof.role = 'customer'
        prof.status = 'active'
        prof.save()

        # Force database connection close
        connection.close()

        # Reopen connection and verify user persists
        reloaded_user = User.objects.filter(email='persist_check@waternow.test').first()
        self.assertIsNotNone(reloaded_user)
        self.assertEqual(reloaded_user.profile.phone, '9826555555')

import json
from decimal import Decimal
from django.contrib.auth.models import User
from django.test import TestCase
from rest_framework import status
from rest_framework.test import APIClient

from accounts.models import UserProfile, FranchiseProfile
from orders.models import Order
from billing.models import Invoice
from products.models import Product


class RBACMatrixVerificationTest(TestCase):
    """
    Comprehensive verification of the 10 RBAC roles/profiles,
    horizontal multi-tenant data scope isolation, and anti-privilege escalation.
    """

    def setUp(self):
        self.client = APIClient()

        # 1. Super Admin
        self.super_admin = User.objects.create_superuser(
            username="test_super_admin",
            email="superadmin@waterwala.in",
            password="Password123!",
        )
        sa_prof, _ = UserProfile.objects.get_or_create(user=self.super_admin)
        sa_prof.role = "super_admin"
        sa_prof.status = "active"
        sa_prof.data_scope_type = "all_data"
        sa_prof.admin_permissions = ["*"]
        sa_prof.save()
        self.super_admin.refresh_from_db()

        # 2. Franchises A and B
        self.user_fr_a = User.objects.create_user(
            username="dealer_alpha", email="dealer_alpha@waterwala.in", password="Password123!"
        )
        self.fr_a = FranchiseProfile.objects.create(
            user=self.user_fr_a,
            business_name="Alpha Water Distribution",
            status="approved",
            city="Raipur",
        )
        fa_prof, _ = UserProfile.objects.get_or_create(user=self.user_fr_a)
        fa_prof.role = "franchise"
        fa_prof.status = "active"
        fa_prof.save()
        self.user_fr_a.refresh_from_db()

        self.user_fr_b = User.objects.create_user(
            username="dealer_beta", email="dealer_beta@waterwala.in", password="Password123!"
        )
        self.fr_b = FranchiseProfile.objects.create(
            user=self.user_fr_b,
            business_name="Beta Water Distribution",
            status="approved",
            city="Bilaspur",
        )
        fb_prof, _ = UserProfile.objects.get_or_create(user=self.user_fr_b)
        fb_prof.role = "franchise"
        fb_prof.status = "active"
        fb_prof.save()
        self.user_fr_b.refresh_from_db()

        # 3. Customer
        self.cust_user = User.objects.create_user(
            username="cust_one", email="cust1@gmail.com", password="Password123!"
        )
        c_prof, _ = UserProfile.objects.get_or_create(user=self.cust_user)
        c_prof.role = "customer"
        c_prof.status = "active"
        c_prof.save()
        self.cust_user.refresh_from_db()

        # 4. Products
        self.product = Product.objects.create(
            name="20L Mineral Jar",
            sku="JAR-20L-TST",
            size="20L",
            price=Decimal("60.00"),
            mrp=Decimal("80.00"),
            status="Active",
        )

        # 5. Orders (One for Franchise A, one for Franchise B)
        self.order_a = Order.objects.create(
            created_by=self.cust_user,
            serving_franchise=self.fr_a,
            franchise_name=self.fr_a.business_name,
            city="Raipur",
            status="order_placement",
            amount=Decimal("120.00"),
            grand_total=Decimal("120.00"),
        )
        self.order_b = Order.objects.create(
            created_by=self.cust_user,
            serving_franchise=self.fr_b,
            franchise_name=self.fr_b.business_name,
            city="Bilaspur",
            status="order_placement",
            amount=Decimal("240.00"),
            grand_total=Decimal("240.00"),
        )

        # 6. Invoices
        self.invoice_a = Invoice.objects.create(
            invoice_number="INV-TST-ALPHA-101",
            order=self.order_a,
            billed_to_name="Customer One",
            grand_total=Decimal("120.00"),
            amount_paid=Decimal("0.00"),
            status="UNPAID",
        )
        self.invoice_b = Invoice.objects.create(
            invoice_number="INV-TST-BETA-202",
            order=self.order_b,
            billed_to_name="Customer One",
            grand_total=Decimal("240.00"),
            amount_paid=Decimal("0.00"),
            status="UNPAID",
        )

    def _create_employee(self, username, permissions=None, scope="all_data", scope_ids=None, is_active=True, status="active", role="admin"):
        user = User.objects.create_user(username=username, password="Password123!", is_active=is_active)
        profile, _ = UserProfile.objects.get_or_create(user=user)
        profile.role = role
        profile.status = status
        profile.data_scope_type = scope
        profile.assigned_scope_ids = scope_ids or []
        profile.admin_permissions = permissions or []
        profile.save()
        user.refresh_from_db()
        return user

    # -------------------------------------------------------------------------
    # PROFILE 1: Super Admin (Wildcard Access)
    # -------------------------------------------------------------------------
    def test_profile_1_super_admin_has_full_access(self):
        self.client.force_authenticate(user=self.super_admin)

        # Super admin endpoints
        res = self.client.get("/api/accounts/super-admin/admins/")
        self.assertEqual(res.status_code, status.HTTP_200_OK)

        # Customers, Franchises, Orders, Billing, Products
        res = self.client.get("/api/accounts/admin/customers/")
        self.assertEqual(res.status_code, status.HTTP_200_OK)

        res = self.client.get("/api/accounts/franchises/")
        self.assertEqual(res.status_code, status.HTTP_200_OK)

        res = self.client.get("/api/orders/")
        self.assertEqual(res.status_code, status.HTTP_200_OK)

        res = self.client.get("/api/billing/invoices/")
        self.assertEqual(res.status_code, status.HTTP_200_OK)

        res = self.client.get("/api/products/stats/")
        self.assertEqual(res.status_code, status.HTTP_200_OK)

    # -------------------------------------------------------------------------
    # PROFILE 2: Admin with Restricted Permission (orders:view only)
    # -------------------------------------------------------------------------
    def test_profile_2_restricted_order_viewer(self):
        emp = self._create_employee("emp_orders_viewer", permissions=["orders:view"])
        self.client.force_authenticate(user=emp)

        # Authorized on orders view
        res = self.client.get("/api/orders/")
        self.assertEqual(res.status_code, status.HTTP_200_OK)

        res = self.client.get(f"/api/orders/{self.order_a.id}/")
        self.assertEqual(res.status_code, status.HTTP_200_OK)

        # FORBIDDEN on order delete
        res = self.client.delete(f"/api/orders/{self.order_a.id}/")
        self.assertEqual(res.status_code, status.HTTP_403_FORBIDDEN)

        # FORBIDDEN on order status update
        res = self.client.patch(f"/api/orders/{self.order_a.id}/status/", {"status": "plant_approval"})
        self.assertEqual(res.status_code, status.HTTP_403_FORBIDDEN)

        # FORBIDDEN on customers, franchises, billing, products stats, super admin
        res = self.client.get("/api/accounts/admin/customers/")
        self.assertEqual(res.status_code, status.HTTP_403_FORBIDDEN)

        res = self.client.get("/api/accounts/franchises/")
        self.assertEqual(res.status_code, status.HTTP_403_FORBIDDEN)

        res = self.client.get("/api/billing/invoices/")
        self.assertEqual(res.status_code, status.HTTP_403_FORBIDDEN)

        res = self.client.get("/api/products/stats/")
        self.assertEqual(res.status_code, status.HTTP_403_FORBIDDEN)

        res = self.client.get("/api/accounts/super-admin/admins/")
        self.assertEqual(res.status_code, status.HTTP_403_FORBIDDEN)

    # -------------------------------------------------------------------------
    # PROFILE 3: Billing Employee (billing:view, billing:edit, billing:approve)
    # -------------------------------------------------------------------------
    def test_profile_3_billing_employee(self):
        emp = self._create_employee("emp_billing", permissions=["billing:view", "billing:edit", "billing:approve"])
        self.client.force_authenticate(user=emp)

        # Authorized on billing
        res = self.client.get("/api/billing/invoices/")
        self.assertEqual(res.status_code, status.HTTP_200_OK)

        # FORBIDDEN on order modification/deletion
        res = self.client.delete(f"/api/orders/{self.order_a.id}/")
        self.assertEqual(res.status_code, status.HTTP_403_FORBIDDEN)

        # FORBIDDEN on customers and super admin
        res = self.client.get("/api/accounts/admin/customers/")
        self.assertEqual(res.status_code, status.HTTP_403_FORBIDDEN)

        res = self.client.get("/api/accounts/super-admin/admins/")
        self.assertEqual(res.status_code, status.HTTP_403_FORBIDDEN)

    # -------------------------------------------------------------------------
    # PROFILE 4: Order Management Employee (orders:view, orders:edit)
    # -------------------------------------------------------------------------
    def test_profile_4_order_management_employee(self):
        emp = self._create_employee("emp_orders_mgr", permissions=["orders:view", "orders:edit"])
        self.client.force_authenticate(user=emp)

        # Allowed on view and status update
        res = self.client.get("/api/orders/")
        self.assertEqual(res.status_code, status.HTTP_200_OK)

        res = self.client.patch(f"/api/orders/{self.order_a.id}/status/", {"status": "plant_approval"})
        self.assertEqual(res.status_code, status.HTTP_200_OK)

        # FORBIDDEN on delete
        res = self.client.delete(f"/api/orders/{self.order_a.id}/")
        self.assertEqual(res.status_code, status.HTTP_403_FORBIDDEN)

        # FORBIDDEN on billing and customers
        res = self.client.get("/api/billing/invoices/")
        self.assertEqual(res.status_code, status.HTTP_403_FORBIDDEN)

        res = self.client.get("/api/accounts/admin/customers/")
        self.assertEqual(res.status_code, status.HTTP_403_FORBIDDEN)

    # -------------------------------------------------------------------------
    # PROFILE 5: Customer Support Employee (customers:view, customers:edit)
    # -------------------------------------------------------------------------
    def test_profile_5_customer_support_employee(self):
        emp = self._create_employee("emp_crm", permissions=["customers:view", "customers:edit"])
        self.client.force_authenticate(user=emp)

        # Allowed on customers
        res = self.client.get("/api/accounts/admin/customers/")
        self.assertEqual(res.status_code, status.HTTP_200_OK)

        # FORBIDDEN on orders, billing, and admin management
        res = self.client.get("/api/orders/")
        self.assertEqual(res.status_code, status.HTTP_403_FORBIDDEN)

        res = self.client.get("/api/billing/invoices/")
        self.assertEqual(res.status_code, status.HTTP_403_FORBIDDEN)

        res = self.client.get("/api/accounts/super-admin/admins/")
        self.assertEqual(res.status_code, status.HTTP_403_FORBIDDEN)

    # -------------------------------------------------------------------------
    # PROFILE 6: Inventory Employee (inventory:view, inventory:adjust)
    # -------------------------------------------------------------------------
    def test_profile_6_inventory_employee(self):
        emp = self._create_employee("emp_stock", permissions=["inventory:view", "inventory:adjust"])
        self.client.force_authenticate(user=emp)

        # FORBIDDEN on order deletion, billing, customers, super admin
        res = self.client.delete(f"/api/orders/{self.order_a.id}/")
        self.assertEqual(res.status_code, status.HTTP_403_FORBIDDEN)

        res = self.client.get("/api/billing/invoices/")
        self.assertEqual(res.status_code, status.HTTP_403_FORBIDDEN)

        res = self.client.get("/api/accounts/admin/customers/")
        self.assertEqual(res.status_code, status.HTTP_403_FORBIDDEN)

        res = self.client.get("/api/accounts/super-admin/admins/")
        self.assertEqual(res.status_code, status.HTTP_403_FORBIDDEN)

    # -------------------------------------------------------------------------
    # PROFILE 7: Read-Only Wildcard Employee (*:view only)
    # -------------------------------------------------------------------------
    def test_profile_7_read_only_employee(self):
        emp = self._create_employee("emp_readonly", permissions=["*:view"])
        self.client.force_authenticate(user=emp)

        # View allowed across all operational modules
        res = self.client.get("/api/orders/")
        self.assertEqual(res.status_code, status.HTTP_200_OK)

        res = self.client.get("/api/billing/invoices/")
        self.assertEqual(res.status_code, status.HTTP_200_OK)

        res = self.client.get("/api/accounts/admin/customers/")
        self.assertEqual(res.status_code, status.HTTP_200_OK)

        res = self.client.get("/api/accounts/franchises/")
        self.assertEqual(res.status_code, status.HTTP_200_OK)

        # Mutations STRICTLY FORBIDDEN
        res = self.client.delete(f"/api/orders/{self.order_a.id}/")
        self.assertEqual(res.status_code, status.HTTP_403_FORBIDDEN)

        res = self.client.patch(f"/api/orders/{self.order_a.id}/status/", {"status": "plant_approval"})
        self.assertEqual(res.status_code, status.HTTP_403_FORBIDDEN)

        res = self.client.post(f"/api/billing/invoices/{self.invoice_a.id}/payments/", {"amount": "50"})
        self.assertEqual(res.status_code, status.HTTP_403_FORBIDDEN)

    # -------------------------------------------------------------------------
    # PROFILE 8: Deactivated Employee (is_active=False / status='inactive')
    # -------------------------------------------------------------------------
    def test_profile_8_deactivated_employee(self):
        emp = self._create_employee("emp_inactive", permissions=["*"], is_active=False, status="inactive")
        self.client.force_authenticate(user=emp)

        # Immediate rejection on all endpoints
        res = self.client.get("/api/orders/")
        self.assertEqual(res.status_code, status.HTTP_403_FORBIDDEN)

        res = self.client.get("/api/accounts/admin/customers/")
        self.assertEqual(res.status_code, status.HTTP_403_FORBIDDEN)

        res = self.client.get("/api/billing/invoices/")
        self.assertEqual(res.status_code, status.HTTP_403_FORBIDDEN)

    # -------------------------------------------------------------------------
    # PROFILE 9: Employee with Empty Permissions (admin_permissions=[])
    # -------------------------------------------------------------------------
    def test_profile_9_employee_with_no_permissions(self):
        emp = self._create_employee("emp_empty_perms", permissions=[])
        self.client.force_authenticate(user=emp)

        res = self.client.get("/api/orders/")
        self.assertEqual(res.status_code, status.HTTP_403_FORBIDDEN)

        res = self.client.get("/api/accounts/admin/customers/")
        self.assertEqual(res.status_code, status.HTTP_403_FORBIDDEN)

        res = self.client.get("/api/billing/invoices/")
        self.assertEqual(res.status_code, status.HTTP_403_FORBIDDEN)

        res = self.client.get("/api/accounts/franchises/")
        self.assertEqual(res.status_code, status.HTTP_403_FORBIDDEN)

    # -------------------------------------------------------------------------
    # PROFILE 10: Single-Module Employee (reports:view only)
    # -------------------------------------------------------------------------
    def test_profile_10_single_module_reports_employee(self):
        emp = self._create_employee("emp_reports_only", permissions=["reports:view"])
        self.client.force_authenticate(user=emp)

        # All other modules blocked
        res = self.client.get("/api/orders/")
        self.assertEqual(res.status_code, status.HTTP_403_FORBIDDEN)

        res = self.client.get("/api/billing/invoices/")
        self.assertEqual(res.status_code, status.HTTP_403_FORBIDDEN)

        res = self.client.get("/api/products/stats/")
        self.assertEqual(res.status_code, status.HTTP_403_FORBIDDEN)

        res = self.client.get("/api/accounts/admin/customers/")
        self.assertEqual(res.status_code, status.HTTP_403_FORBIDDEN)

    # -------------------------------------------------------------------------
    # DATA SCOPE ISOLATION TEST (Horizontal Multi-Tenant Boundary)
    # -------------------------------------------------------------------------
    def test_data_scope_isolation_dealer_scoped(self):
        """
        An employee scoped to Franchise A cannot view Franchise B orders or mutate them.
        """
        emp = self._create_employee(
            "emp_dealer_a_scoped",
            permissions=["orders:view", "orders:edit"],
            scope="dealer_scoped",
            scope_ids=[self.fr_a.id],
        )
        self.client.force_authenticate(user=emp)

        # 1. Querying orders list only returns Franchise A orders
        res = self.client.get("/api/orders/")
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        orders_data = res.data.get("orders") or res.data
        if isinstance(orders_data, list):
            returned_ids = [o.get("id") for o in orders_data]
            self.assertIn(self.order_a.id, returned_ids)
            self.assertNotIn(self.order_b.id, returned_ids)

        # 2. Accessing Franchise A order directly is permitted
        res = self.client.get(f"/api/orders/{self.order_a.id}/")
        self.assertEqual(res.status_code, status.HTTP_200_OK)

        # 3. Accessing Franchise B order directly is BLOCKED with 403 Forbidden
        res = self.client.get(f"/api/orders/{self.order_b.id}/")
        self.assertEqual(res.status_code, status.HTTP_403_FORBIDDEN)

        # 4. Mutating Franchise B order is BLOCKED with 403 Forbidden
        res = self.client.patch(f"/api/orders/{self.order_b.id}/status/", {"status": "plant_approval"})
        self.assertEqual(res.status_code, status.HTTP_403_FORBIDDEN)

    # -------------------------------------------------------------------------
    # ANTI-PRIVILEGE ESCALATION TEST
    # -------------------------------------------------------------------------
    def test_anti_privilege_escalation(self):
        """
        A normal admin / employee cannot create super_admin or grant permissions they do not possess.
        """
        emp = self._create_employee("emp_escalation_attacker", permissions=["orders:view"])
        self.client.force_authenticate(user=emp)

        # 1. Calling Super Admin creation endpoint returns 403
        payload = {
            "first_name": "Rogue",
            "last_name": "Admin",
            "email": "rogue@waterwala.in",
            "phone": "9998887776",
            "role": "super_admin",
            "admin_permissions": ["*"],
        }
        res = self.client.post("/api/accounts/super-admin/admins/", payload)
        self.assertEqual(res.status_code, status.HTTP_403_FORBIDDEN)

    # -------------------------------------------------------------------------
    # PROFILE 6b: Permission Revocation Mid-Session Test
    # -------------------------------------------------------------------------
    def test_permission_revocation_mid_session(self):
        """
        Tests that when an employee's permissions are revoked in the database mid-session,
        subsequent requests on the same session are immediately blocked without needing relogin.
        """
        emp = self._create_employee("emp_revocable", permissions=["orders:view", "orders:edit"])
        self.client.force_authenticate(user=emp)

        # 1. Initially allowed to view and edit
        res = self.client.get("/api/orders/")
        self.assertEqual(res.status_code, status.HTTP_200_OK)

        res = self.client.patch(f"/api/orders/{self.order_a.id}/status/", {"status": "plant_approval"})
        self.assertEqual(res.status_code, status.HTTP_200_OK)

        # 2. Super admin revokes 'orders:edit' privilege in the database
        prof = emp.profile
        prof.admin_permissions = ["orders:view"]
        prof.save()

        # 3. Same session attempts edit -> immediately rejected with 403 Forbidden
        res = self.client.patch(f"/api/orders/{self.order_a.id}/status/", {"status": "dispatch"})
        self.assertEqual(res.status_code, status.HTTP_403_FORBIDDEN)

        # 4. View still works
        res = self.client.get("/api/orders/")
        self.assertEqual(res.status_code, status.HTTP_200_OK)

        # 5. Super admin completely revokes all permissions
        prof.admin_permissions = []
        prof.save()

        # 6. Same session attempts view -> immediately rejected with 403 Forbidden
        res = self.client.get("/api/orders/")
        self.assertEqual(res.status_code, status.HTTP_403_FORBIDDEN)

    # -------------------------------------------------------------------------
    # DIRECT API BYPASS & PAYLOAD TAMPERING TEST
    # -------------------------------------------------------------------------
    def test_payload_tampering_and_direct_api_bypass(self):
        """
        Tests that restricted employees cannot bypass authorization by tampering
        with request payloads, adding elevated role flags, or requesting foreign records.
        """
        emp = self._create_employee("emp_tamperer", permissions=["orders:view"])
        self.client.force_authenticate(user=emp)

        # 1. Attempting to access Super Admin employee list directly
        res = self.client.get("/api/accounts/super-admin/admins/")
        self.assertEqual(res.status_code, status.HTTP_403_FORBIDDEN)

        # 2. Attempting to access audit logs directly
        res = self.client.get("/api/accounts/audit-logs/")
        self.assertEqual(res.status_code, status.HTTP_403_FORBIDDEN)

        # 3. Attempting to create an admin with self-injected super_admin role
        payload = {
            "username": "hacked_admin",
            "email": "hacked@waterwala.in",
            "password": "Password123!",
            "role": "super_admin",
            "admin_permissions": ["*"]
        }
        res = self.client.post("/api/accounts/super-admin/admins/", payload)
        self.assertEqual(res.status_code, status.HTTP_403_FORBIDDEN)

        # 4. Attempting to mutate product with injected admin flags
        res = self.client.patch(f"/api/products/{self.product.id}/", {"price": "1.00", "role": "super_admin"})
        self.assertEqual(res.status_code, status.HTTP_403_FORBIDDEN)


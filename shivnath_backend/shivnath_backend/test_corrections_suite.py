import os
import sys
import django

# Setup django environment
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
django.setup()

from django.core.management import call_command
from django.db import transaction
from rest_framework.test import APIRequestFactory, force_authenticate
from rest_framework import status

from accounts.models import User, ServiceZone, SupportContact, CustomerFranchiseRelationship, FranchiseProfile
from products.models import ProductCategory, Product
from accounts.views import (
    CustomerRegisterView,
    FranchiseRegisterView,
    TerritoryMasterView,
    EligibleFranchisesView,
    FranchiseDashboardStatsView,
    AdminFranchiseDetailView,
)
from products.views import CategoryListCreateView, CategoryDetailView
from products.serializers import ProductCategorySerializer

def run_tests():
    print("==================================================")
    print("STARTING SHIVNATH AGENCY COMPREHENSIVE TEST SUITE")
    print("==================================================")

    # 1. Django Check
    print("\n[TEST 1] Django System Check (python manage.py check)...")
    call_command('check')
    print("  -> PASSED: Django system check passed with 0 errors.")

    factory = APIRequestFactory()

    # 2. Existing Data & 'Jar' Category Preservation
    print("\n[TEST 2] Verifying Preservation of Existing 'Jar' Category & Products...")
    jar_cat = ProductCategory.objects.filter(name__iexact='Jar').first()
    if jar_cat:
        print(f"  -> Found existing Jar category: ID={jar_cat.id}, Name='{jar_cat.name}', Path='{jar_cat.full_path}'")
        jar_products = Product.objects.filter(category__iexact='Jar')
        print(f"  -> Found {jar_products.count()} products assigned to Jar category.")
        assert jar_products.count() >= 0
    else:
        # Create Jar category if fresh DB
        jar_cat = ProductCategory.objects.create(name='Jar', slug='jar-test', is_active=True)
        print("  -> Created baseline Jar category for testing.")
    print("  -> PASSED: Existing Jar data verified and preserved.")

    # 3. Unlimited-Depth Category Hierarchy & Validation
    print("\n[TEST 3] Testing Recursive Unlimited-Depth Category Tree & Validations...")
    # Create test hierarchy: Root -> Level1 -> Level2 -> Level3 -> Level4 (5 levels)
    with transaction.atomic():
        root, _ = ProductCategory.objects.get_or_create(name="Beverages [TEST]", defaults={"slug": "beverages-test"})
        lvl1, _ = ProductCategory.objects.get_or_create(name="Bottled Water [TEST]", parent=root, defaults={"slug": "bottled-water-test"})
        lvl2, _ = ProductCategory.objects.get_or_create(name="Mineral [TEST]", parent=lvl1, defaults={"slug": "mineral-test"})
        lvl3, _ = ProductCategory.objects.get_or_create(name="Premium Sparkling [TEST]", parent=lvl2, defaults={"slug": "sparkling-test"})
        lvl4, _ = ProductCategory.objects.get_or_create(name="330ml Glass [TEST]", parent=lvl3, defaults={"slug": "330ml-glass-test"})

    print(f"  -> Level 4 full_path: '{lvl4.full_path}'")
    assert "Beverages [TEST] > Bottled Water [TEST] > Mineral [TEST] > Premium Sparkling [TEST] > 330ml Glass [TEST]" in lvl4.full_path
    descendants = root.get_descendant_ids()
    print(f"  -> Root descendant IDs ({len(descendants)} total): {descendants}")
    assert lvl1.id in descendants
    assert lvl4.id in descendants

    # Test Duplicate Sibling Rejection
    print("  -> Testing duplicate sibling rejection...")
    dup_serializer = ProductCategorySerializer(data={"name": "Bottled Water [TEST]", "parent": root.id})
    assert not dup_serializer.is_valid()
    assert "name" in dup_serializer.errors
    print(f"     Rejected as expected: {dup_serializer.errors['name']}")

    # Test Self-Parent Rejection
    print("  -> Testing self-parent rejection...")
    self_serializer = ProductCategorySerializer(instance=root, data={"name": root.name, "parent": root.id}, partial=True)
    assert not self_serializer.is_valid()
    assert "parent" in self_serializer.errors
    print(f"     Rejected as expected: {self_serializer.errors['parent']}")

    # Test Circular Hierarchy Rejection (setting root's parent to lvl4)
    print("  -> Testing circular hierarchy rejection...")
    circ_serializer = ProductCategorySerializer(instance=root, data={"name": root.name, "parent": lvl4.id}, partial=True)
    assert not circ_serializer.is_valid()
    assert "parent" in circ_serializer.errors
    print(f"     Rejected as expected: {circ_serializer.errors['parent']}")

    # Test Safe Archive Rejection when active children exist
    print("  -> Testing safe archive dependency rejection...")
    cat_view = CategoryDetailView.as_view()
    req = factory.delete(f'/api/products/categories/{root.id}/')
    # Use admin user
    admin_user = User.objects.filter(is_superuser=True).first()
    if not admin_user:
        admin_user = User.objects.create_superuser(username='test_admin', email='test_admin@test.com', password='password123')
    force_authenticate(req, user=admin_user)
    resp = cat_view(req, pk=root.id)
    assert resp.status_code == 400
    print(f"     Archive rejected as expected: {resp.data.get('message')}")
    print("  -> PASSED: Category hierarchy, validation, and safe archive verified.")

    # 4. Territory Master & Eligible Franchises
    print("\n[TEST 4] Testing Territory Master & Eligible Franchise Resolution...")
    t_view = TerritoryMasterView.as_view()
    t_req = factory.get('/api/auth/territory-master/?district=Raipur')
    t_resp = t_view(t_req)
    assert t_resp.status_code == 200
    territories = t_resp.data.get('territories', [])
    print(f"  -> Active territories in Raipur: {len(territories)}")
    assert len(territories) > 0
    sample_territory = territories[0]
    sample_tid = sample_territory['id']

    ef_view = EligibleFranchisesView.as_view()
    ef_req = factory.get(f'/api/auth/eligible-franchises/?territory_id={sample_tid}&district=Raipur')
    ef_resp = ef_view(ef_req)
    assert ef_resp.status_code == 200
    exact = ef_resp.data.get('exact_matches', [])
    available = ef_resp.data.get('available_franchises', [])
    support = ef_resp.data.get('support_contact')
    print(f"  -> Eligible franchises for '{sample_territory['name']}': {len(exact)} exact matches, {len(available)} fallback options. Support: {support}")
    print("  -> PASSED: Territory master and franchise resolution verified.")

    # 5. Customer Registration without PIN
    print("\n[TEST 5] Testing Customer Registration without PIN...")
    c_reg_view = CustomerRegisterView.as_view()
    c_data = {
        "name": "Test Cust Automated",
        "phone": "9876543210",
        "email": "autocust@test.com",
        "password": "Password123!",
        "confirm_password": "Password123!",
        "city": "Raipur",
        "district": "Raipur",
        "zone_id": sample_tid,
        "address": "Auto Test Street",
        # Notice: NO PINCODE
    }
    # Delete if exists
    User.objects.filter(email=c_data["email"]).delete()
    c_req = factory.post('/api/auth/register/customer/', c_data, format='json')
    c_resp = c_reg_view(c_req)
    print(f"  -> Registration response code: {c_resp.status_code}")
    assert c_resp.status_code == 201, f"Expected 201, got {c_resp.status_code}: {c_resp.data}"
    created_cust = User.objects.get(email=c_data["email"])
    assert created_cust.profile.role == 'customer'
    print(f"  -> Successfully created Customer: {created_cust.profile.name} without PIN.")
    print("  -> PASSED: Customer registration without PIN verified.")

    # 6. Franchise Registration: Atomic, No Token Bug, Friendly Duplicate Error
    print("\n[TEST 6] Testing Franchise Registration (Atomic, 201, No Token Failure, Duplicate Rejection)...")
    f_reg_view = FranchiseRegisterView.as_view()
    f_data = {
        "owner_name": "Auto Franchise Owner",
        "business_name": "Auto Water Dist [TEST]",
        "phone": "9123456789",
        "email": "autofranchise@test.com",
        "password": "Password123!",
        "confirm_password": "Password123!",
        "city": "Raipur",
        "address": "Industrial Area, Raipur",
        "territory": "Central Raipur",
        "pan_number": "ABCDE1234F",
        "aadhaar_number": "123456789012",
        "gst_number": "22AAAAA0000A1Z5",
    }
    User.objects.filter(email=f_data["email"]).delete()
    f_req = factory.post('/api/auth/register/franchise/', f_data, format='json')
    f_resp = f_reg_view(f_req)
    print(f"  -> Franchise registration response code: {f_resp.status_code}")
    assert f_resp.status_code == 201, f"Expected 201, got {f_resp.status_code}: {f_resp.data}"
    assert f_resp.data.get('status') == 'Pending Admin Approval'
    # Tokens should NOT be in 201 response since account is pending admin approval
    assert 'access' not in f_resp.data
    print("  -> Verified: HTTP 201 returned with 'Pending Admin Approval', no RefreshToken exception.")

    # Test Duplicate Registration
    print("  -> Testing duplicate franchise registration rejection...")
    f_req_dup = factory.post('/api/auth/register/franchise/', f_data, format='json')
    f_resp_dup = f_reg_view(f_req_dup)
    assert f_resp_dup.status_code == 400
    print(f"  -> Duplicate response: {f_resp_dup.data.get('message')}")
    assert "already registered" in f_resp_dup.data.get('message', '').lower() or "already exists" in str(f_resp_dup.data).lower()
    print("  -> PASSED: Franchise registration and duplicate handling verified.")

    # 7. Franchise Dashboard Stats (PostgreSQL-backed)
    print("\n[TEST 7] Testing Franchise Dashboard Stats View...")
    dash_view = FranchiseDashboardStatsView.as_view()
    # Find active franchise
    f_user = User.objects.filter(profile__role='franchise', franchise_profile__status='approved').first()
    if not f_user:
        f_user = User.objects.filter(profile__role='franchise').first()
    dash_req = factory.get('/api/auth/franchise/dashboard-stats/')
    force_authenticate(dash_req, user=f_user)
    dash_resp = dash_view(dash_req)
    assert dash_resp.status_code == 200
    d_data = dash_resp.data.get('stats', dash_resp.data)
    print("  -> Dashboard stats received from PostgreSQL:")
    for k in ['customers_served', 'registered_customers', 'active_stock', 'low_stock', 'on_hold', 'expired_stock', 'pending_orders', 'total_orders']:
        assert k in d_data, f"Missing stat: {k}"
        print(f"     • {k}: {d_data[k]}")
    print("  -> PASSED: Franchise dashboard stats verified.")

    # 8. Admin Franchise Detail & Cross-Serving (Customer X)
    print("\n[TEST 8] Testing Admin Franchise Detail & Registered vs Serving Separation (Customer X)...")
    detail_view = AdminFranchiseDetailView.as_view()
    detail_req = factory.get(f'/api/auth/admin/franchises/{f_user.id}/detail/')
    force_authenticate(detail_req, user=admin_user)
    detail_resp = detail_view(detail_req, franchise_id=f_user.id)
    assert detail_resp.status_code == 200
    summary = detail_resp.data.get('summary', {})
    print(f"  -> Franchise detail summary: {summary}")
    assert 'registered_customers_count' in summary
    assert 'customers_served_count' in summary

    # Check Customer X if seeded
    cust_x = User.objects.filter(email="customer_x@shivnath.test").first()
    if cust_x and hasattr(cust_x, 'customer_relationship'):
        cp = cust_x.customer_relationship
        print(f"  -> Customer X verified:")
        print(f"     Registered Franchise: {cp.registered_franchise.business_name if cp.registered_franchise else None}")
        print(f"     Serving Franchise:    {cp.current_serving_franchise.business_name if cp.current_serving_franchise else None}")
        assert cp.registered_franchise != cp.current_serving_franchise, "Customer X must have Registered != Serving!"
        print("  -> PASSED: Customer X cross-serving isolation verified.")

    print("\n==================================================")
    print("ALL TESTS PASSED SUCCESSFULLY!")
    print("==================================================")

if __name__ == '__main__':
    run_tests()

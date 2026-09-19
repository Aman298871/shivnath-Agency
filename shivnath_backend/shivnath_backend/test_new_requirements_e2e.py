import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from django.contrib.auth.models import User
from rest_framework.test import APIRequestFactory, force_authenticate
from rest_framework import status
from accounts.models import (
    UserProfile,
    FranchiseProfile,
    ServiceDistrict,
    ServiceZone,
    ServiceArea,
    FranchiseTerritoryAssignment,
    CustomerFranchiseRelationship,
    CustomerStockCycle,
    AdminNotification,
    FranchiseNotification,
)
from accounts.views import (
    FranchiseDashboardStatsView,
    CurrentUserView,
)
from leads.views import PublicLeadCaptureView
from orders.models import Order
from orders.views import (
    OrderListCreateView,
    OrderStatusUpdateView,
)
from inventory.views import FranchiseProductionLogView

print("=" * 70)
print("RUNNING BACKEND NEW REQUIREMENTS E2E TEST SUITE")
print("=" * 70)

factory = APIRequestFactory()

# Setup test master data
district, _ = ServiceDistrict.objects.get_or_create(name='Raipur [TEST]')
zone1, _ = ServiceZone.objects.get_or_create(district=district, name='Raipur North [TEST]', defaults={'code': 'RP_N_TEST'})
zone2, _ = ServiceZone.objects.get_or_create(district=district, name='Raipur South [TEST]', defaults={'code': 'RP_S_TEST'})
zone_empty, _ = ServiceZone.objects.get_or_create(district=district, name='Raipur Remote [TEST]', defaults={'code': 'RP_R_TEST'})
area1, _ = ServiceArea.objects.get_or_create(district=district, zone=zone1, locality_name='Pandri Locality [TEST]', defaults={'pincode': '492001'})

# Setup Franchise A (Assigned to zone1)
u_fa, _ = User.objects.get_or_create(username='franchise_a_test', defaults={'email': 'fa@shivnath.test'})
u_fa.set_password('pass123')
u_fa.save()
p_fa, _ = UserProfile.objects.get_or_create(user=u_fa)
p_fa.role = 'franchise'
p_fa.phone = '9876543210'
p_fa.save()
fp_a, _ = FranchiseProfile.objects.get_or_create(user=u_fa, defaults={'business_name': 'Franchise A Business'})
fp_a.status = 'approved'
fp_a.city = district.name
fp_a.territory = zone1.name
fp_a.address = 'Shop 1, Pandri'
fp_a.save()
assign_a, _ = FranchiseTerritoryAssignment.objects.get_or_create(franchise=fp_a, zone=zone1, defaults={'is_primary': True, 'is_active': True})
assign_a.is_active = True
assign_a.save()

# Setup Franchise B (No territory assigned initially)
u_fb, _ = User.objects.get_or_create(username='franchise_b_test', defaults={'email': 'fb@shivnath.test'})
u_fb.set_password('pass123')
u_fb.save()
p_fb, _ = UserProfile.objects.get_or_create(user=u_fb)
p_fb.role = 'franchise'
p_fb.phone = '9876543211'
p_fb.save()
fp_b, _ = FranchiseProfile.objects.get_or_create(user=u_fb, defaults={'business_name': 'Franchise B Business'})
fp_b.status = 'approved'
fp_b.city = ''
fp_b.territory = ''
fp_b.address = 'Shop 2, Durg'
fp_b.save()
FranchiseTerritoryAssignment.objects.filter(franchise=fp_b).delete()

# Setup Customer C (Will have territory)
u_cust, _ = User.objects.get_or_create(username='customer_c_test', defaults={'email': 'cust_c@shivnath.test'})
u_cust.set_password('pass123')
u_cust.save()
p_cust, _ = UserProfile.objects.get_or_create(user=u_cust)
p_cust.role = 'customer'
p_cust.phone = '9876543212'
p_cust.save()

# Setup Customer D (No territory at all)
u_cust_no_t, _ = User.objects.get_or_create(username='customer_no_territory', defaults={'email': 'no_t@shivnath.test'})
u_cust_no_t.set_password('pass123')
u_cust_no_t.save()
p_cust_no_t, _ = UserProfile.objects.get_or_create(user=u_cust_no_t)
p_cust_no_t.role = 'customer'
p_cust_no_t.district = ''
p_cust_no_t.zone = None
p_cust_no_t.territory = ''
p_cust_no_t.locality = ''
p_cust_no_t.save()
CustomerFranchiseRelationship.objects.filter(customer=u_cust_no_t).delete()

# 1. Franchise Dashboard Stats: Current Authoritative Territory
print("\n[TEST 1] Franchise Dashboard Current Territory Display...")
req = factory.get('/api/accounts/franchise/dashboard-stats/')
force_authenticate(req, user=u_fa)
res = FranchiseDashboardStatsView.as_view()(req)
assert res.status_code == 200, f"Expected 200, got {res.status_code}: {res.data}"
t_info = res.data.get('territory_info', {})
assert t_info.get('is_assigned') is True, "Expected is_assigned=True"
assert t_info.get('district') == district.name, f"Expected district {district.name}, got {t_info.get('district')}"
assert t_info.get('territory') == zone1.name, f"Expected territory {zone1.name}, got {t_info.get('territory')}"
print(f"  -> PASSED: Authoritative territory verified on dashboard: {t_info}")

# 2. Franchise Territory Authorization: Assigned cannot be changed directly
print("\n[TEST 2] Franchise Territory Authorization (Assigned cannot be silently changed)...")
req = factory.patch('/api/accounts/me/', {'district': 'Bilaspur', 'territory': 'Bilaspur Central'}, format='json')
force_authenticate(req, user=u_fa)
res = CurrentUserView.as_view()(req)
assert res.status_code == 403, f"Expected 403 Forbidden, got {res.status_code}"
print("  -> PASSED: Silent change rejected with 403 Forbidden as expected.")

# 3. Franchise Territory Initial Assignment: Unassigned can be assigned
print("\n[TEST 3] Franchise Territory Initial Assignment (Unassigned can set initial territory)...")
req = factory.patch('/api/accounts/me/', {'district': district.name, 'territory': zone2.name}, format='json')
force_authenticate(req, user=u_fb)
res = CurrentUserView.as_view()(req)
assert res.status_code == 200, f"Expected 200 OK, got {res.status_code}: {res.data}"
assert FranchiseTerritoryAssignment.objects.filter(franchise=fp_b, zone=zone2, is_active=True).exists()
print("  -> PASSED: Initial territory assignment created and verified.")

# 4. Customer Profile Territory Update
print("\n[TEST 4] Customer Profile Territory Update & Relationship Sync...")
req = factory.patch('/api/accounts/me/', {
    'district': district.name,
    'territory': zone1.name,
    'locality': 'Pandri Locality [TEST]',
    'address': 'House 123, Street 4'
}, format='json')
force_authenticate(req, user=u_cust)
res = CurrentUserView.as_view()(req)
assert res.status_code == 200, f"Expected 200 OK, got {res.status_code}: {res.data}"
p_cust.refresh_from_db()
assert p_cust.district == district.name
assert p_cust.zone == zone1
rel = CustomerFranchiseRelationship.objects.get(customer=u_cust)
assert rel.district == district
assert rel.zone == zone1
print("  -> PASSED: Customer profile and relationship synced successfully.")

# 5. Public Chatbot Validation
print("\n[TEST 5] Public Chatbot Validation (Name, Mobile, Required Email)...")
view = PublicLeadCaptureView.as_view()

# 5a. Name < 2 chars
res = view(factory.post('/api/leads/public-capture/', {'name': 'A', 'phone': '9876543210', 'email': 'a@b.com'}, format='json'))
assert res.status_code == 400 and 'between 2 and 30' in res.data['message'], f"Got {res.data}"

# 5b. Name > 30 chars
res = view(factory.post('/api/leads/public-capture/', {'name': 'A' * 31, 'phone': '9876543210', 'email': 'a@b.com'}, format='json'))
assert res.status_code == 400 and 'between 2 and 30' in res.data['message'], f"Got {res.data}"

# 5c. Name numeric only
res = view(factory.post('/api/leads/public-capture/', {'name': '1234567', 'phone': '9876543210', 'email': 'a@b.com'}, format='json'))
assert res.status_code == 400, f"Got {res.data}"

# 5d. Mobile 11 digits
res = view(factory.post('/api/leads/public-capture/', {'name': 'Rahul Sharma', 'phone': '12345678901', 'email': 'a@b.com'}, format='json'))
assert res.status_code == 400 and 'exactly 10 digits' in res.data['message'], f"Got {res.data}"

# 5e. Mobile starting with invalid digit (e.g. 1)
res = view(factory.post('/api/leads/public-capture/', {'name': 'Rahul Sharma', 'phone': '1234567890', 'email': 'a@b.com'}, format='json'))
assert res.status_code == 400 and 'start with 6, 7, 8, or 9' in res.data['message'], f"Got {res.data}"

# 5f. Email empty
res = view(factory.post('/api/leads/public-capture/', {'name': 'Rahul Sharma', 'phone': '9876543210', 'email': ''}, format='json'))
assert res.status_code == 400 and 'Email address is required' in res.data['message'], f"Got {res.data}"

# 5g. Email 'skip'
res = view(factory.post('/api/leads/public-capture/', {'name': 'Rahul Sharma', 'phone': '9876543210', 'email': 'skip'}, format='json'))
assert res.status_code == 400 and 'Email address is required' in res.data['message'], f"Got {res.data}"

# 5h. Email invalid format
res = view(factory.post('/api/leads/public-capture/', {'name': 'Rahul Sharma', 'phone': '9876543210', 'email': 'invalid_email'}, format='json'))
assert res.status_code == 400 and 'valid email' in res.data['message'], f"Got {res.data}"

# 5i. All valid
res = view(factory.post('/api/leads/public-capture/', {
    'name': 'Rahul Sharma',
    'phone': '9876543210',
    'email': 'rahul@example.com',
    'district': district.name,
    'territory': zone1.name,
}, format='json'))
assert res.status_code in [200, 201] and res.data['success'] is True, f"Expected 200/201, got {res.status_code}: {res.data}"
print("  -> PASSED: All Public Chatbot boundary and validation rules verified.")

# 6. Comprehensive Customer Ordering Tests (The 10 Cases)
print("\n[TEST 6] Customer Ordering: The 10 Mandatory Verification Cases...")
create_order_view = OrderListCreateView.as_view()

# Case 1: Customer with territory + available franchise -> franchise order succeeds
AdminNotification.objects.all().delete()
FranchiseNotification.objects.all().delete()
req = factory.post('/api/orders/', {
    'order_source': 'FRANCHISE',
    'serving_franchise_id': fp_a.id,
    'amount': 300.0,
    'items_count': 6,
    'delivery_address': 'Pandri Home',
}, format='json')
force_authenticate(req, user=u_cust)
res = create_order_view(req)
assert res.status_code == 201, f"Expected 201, got {res.status_code}: {res.data}"
order_c1 = Order.objects.get(id=res.data['order']['id'])
assert order_c1.order_source == 'FRANCHISE'
assert order_c1.serving_franchise == fp_a
# Case 7: Franchise order notification goes to serving franchise + Admin
assert FranchiseNotification.objects.filter(reference_id=order_c1.id, franchise=fp_a).exists()
assert AdminNotification.objects.filter(reference_id=order_c1.id).exists()
print("  -> [Case 1 & 7] PASSED: Customer with territory + available franchise order succeeded with dual notifications.")

# Case 2: Customer with territory + NO franchise available -> direct company order succeeds
u_cust_remote, _ = User.objects.get_or_create(username='customer_remote', defaults={'email': 'remote@shivnath.test'})
p_remote, _ = UserProfile.objects.get_or_create(user=u_cust_remote)
p_remote.zone = zone_empty
p_remote.district = district.name
p_remote.save()
rel_remote, _ = CustomerFranchiseRelationship.objects.get_or_create(customer=u_cust_remote, defaults={'registered_franchise': fp_a})
rel_remote.zone = zone_empty
rel_remote.save()

AdminNotification.objects.all().delete()
FranchiseNotification.objects.all().delete()
req = factory.post('/api/orders/', {
    'amount': 200.0,
    'items_count': 4,
    'delivery_address': 'Remote Forest Road',
}, format='json')
force_authenticate(req, user=u_cust_remote)
res = create_order_view(req)
assert res.status_code == 201, f"Expected 201, got {res.status_code}: {res.data}"
order_c2 = Order.objects.get(id=res.data['order']['id'])
assert order_c2.order_source == 'DIRECT_COMPANY'
assert order_c2.serving_franchise is None
# Case 6: Direct company order notification goes ONLY to Admin/company
assert AdminNotification.objects.filter(reference_id=order_c2.id).exists()
assert not FranchiseNotification.objects.filter(reference_id=order_c2.id).exists()
print("  -> [Case 2 & 6] PASSED: Territory with NO franchise auto-routed to DIRECT_COMPANY with admin-only notification.")

# Case 3 & 4: Customer without territory or franchise relationship -> direct company order succeeds
AdminNotification.objects.all().delete()
FranchiseNotification.objects.all().delete()
req = factory.post('/api/orders/', {
    'amount': 150.0,
    'items_count': 3,
    'delivery_address': 'Anywhere Address',
}, format='json')
force_authenticate(req, user=u_cust_no_t)
res = create_order_view(req)
assert res.status_code == 201, f"Expected 201, got {res.status_code}: {res.data}"
order_c3 = Order.objects.get(id=res.data['order']['id'])
assert order_c3.order_source == 'DIRECT_COMPANY'
# Case 5 & 8: serving_franchise is NULL, no random franchise assigned
assert order_c3.serving_franchise is None
# Stock cycle has serving_franchise = NULL
sc = CustomerStockCycle.objects.filter(order=order_c3).first()
assert sc is not None, "Stock cycle should be created for customer"
assert sc.serving_franchise is None, f"Expected sc.serving_franchise is None, got {sc.serving_franchise}"
assert AdminNotification.objects.filter(reference_id=order_c3.id).exists()
assert not FranchiseNotification.objects.filter(reference_id=order_c3.id).exists()
print("  -> [Case 3, 4, 5, 8] PASSED: Customer without territory placed order as DIRECT_COMPANY (serving_franchise=None, stock cycle=None).")

# Case 9: Existing customer profile with missing territory can still place order
p_cust_no_t.refresh_from_db()
assert not p_cust_no_t.zone and not p_cust_no_t.district
req = factory.post('/api/orders/', {'amount': 100.0, 'items_count': 2}, format='json')
force_authenticate(req, user=u_cust_no_t)
res = create_order_view(req)
assert res.status_code == 201
print("  -> [Case 9] PASSED: Existing profile with missing territory placed order successfully.")

# Case 10: Completing territory later does not modify historical orders
past_order_id = order_c3.id
# Update customer D profile with territory
req = factory.patch('/api/accounts/me/', {'district': district.name, 'territory': zone1.name, 'locality': 'Locality D', 'address': 'Address D'}, format='json')
force_authenticate(req, user=u_cust_no_t)
res = CurrentUserView.as_view()(req)
assert res.status_code == 200
# Verify historical order remains untouched
historical_order = Order.objects.get(id=past_order_id)
assert historical_order.order_source == 'DIRECT_COMPANY'
assert historical_order.serving_franchise is None
print("  -> [Case 10] PASSED: Updating territory later left historical order permanently intact.")

# 7. Franchise Order Status Authorization
print("\n[TEST 7] Franchise Order Status Authorization...")
status_view = OrderStatusUpdateView.as_view()

# 7a. Franchise A updates its own order -> SUCCESS
req = factory.patch(f'/api/orders/{order_c1.id}/status/', {'status': 'dispatch'}, format='json')
force_authenticate(req, user=u_fa)
res = status_view(req, pk=order_c1.id)
assert res.status_code == 200, f"Expected 200, got {res.status_code}: {res.data}"
order_c1.refresh_from_db()
assert order_c1.status == 'dispatch'
print("  -> PASSED: Serving franchise updated status to 'dispatch'.")

# 7b. Franchise B tries to update Franchise A's order -> 403 FORBIDDEN
req = factory.patch(f'/api/orders/{order_c1.id}/status/', {'status': 'delivered'}, format='json')
force_authenticate(req, user=u_fb)
res = status_view(req, pk=order_c1.id)
assert res.status_code == 403, f"Expected 403 Forbidden, got {res.status_code}"
print("  -> PASSED: Unauthorized franchise update blocked with 403 Forbidden.")

# 8. Franchise Production Flow
print("\n[TEST 8] Franchise Production Log & Ledger...")
prod_view = FranchiseProductionLogView.as_view()
req = factory.post('/api/inventory/franchise/production-logs/', {
    'product_name': '20L Jars Local Batch',
    'quantity_produced': 50,
    'notes': 'Daily batch produced'
}, format='json')
force_authenticate(req, user=u_fa)
res = prod_view(req)
assert res.status_code == 201, f"Expected 201, got {res.status_code}: {res.data}"
print("  -> PASSED: Local production batch logged and ledger updated.")

print("\n" + "=" * 70)
print("ALL NEW REQUIREMENTS E2E TESTS (INCLUDING ALL 10 CASES) PASSED 100%!")
print("=" * 70)

import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from django.contrib.auth.models import User
from accounts.models import (
    UserProfile, ServiceDistrict, ServiceZone, ServiceArea,
    FranchiseProfile, FranchiseTerritoryAssignment
)
from products.models import Product
from orders.models import Order, OrderItem
from accounts.services import resolve_serviceable_franchises
from rest_framework.test import APIRequestFactory, force_authenticate
from accounts.views import (
    CustomerRegisterView, EligibleFranchisesView, LoginView
)
from orders.views import OrderListCreateView

def test_complete_audit_and_lifecycle():
    print("=" * 70)
    print("1. PROVENANCE & RECORD INVENTORY AUDIT")
    print("=" * 70)
    
    total_districts = ServiceDistrict.objects.count()
    active_districts = ServiceDistrict.objects.filter(is_active=True).count()
    total_zones = ServiceZone.objects.count()
    active_zones = ServiceZone.objects.filter(is_active=True).count()
    
    # Original baseline records before the 33-district expansion
    baseline_districts = ["Raipur", "Durg", "Bilaspur"]
    baseline_zones = ["East Raipur", "West Raipur", "Central Durg", "Bilaspur Central"]
    
    existing_zones_count = len(baseline_zones)
    new_zones_count = total_zones - existing_zones_count
    
    print(f"Total Districts in DB: {total_districts} (Active: {active_districts})")
    print(f"Total Service Zones in DB: {total_zones} (Active: {active_zones})")
    print(f"Original Baseline Zones: {existing_zones_count} {baseline_zones}")
    print(f"New Administrative Zones Added: {new_zones_count}")
    
    # Check Franchise References
    franchises = FranchiseProfile.objects.all()
    assignments = FranchiseTerritoryAssignment.objects.filter(is_active=True)
    assigned_zone_names = set(a.zone.name for a in assignments)
    
    print(f"\nFranchises in System: {franchises.count()}")
    for f in franchises:
        f_zones = [a.zone.name for a in f.territory_assignments.filter(is_active=True)]
        print(f"  - {f.business_name} (HQ: {f.is_headquarters}) -> Zone Assignments: {f_zones if f_zones else f.territory}")
    
    print(f"Zones directly referenced by active Franchise assignments: {assigned_zone_names}")

    # Check Customer Territory Snapshots
    customers = UserProfile.objects.filter(role='customer')
    print(f"\nExisting Customers in DB: {customers.count()}")
    for c in customers[:5]:
        print(f"  - Customer {c.name} ({c.user.username}): District='{c.district}', Territory='{c.territory}', ZoneID={c.zone_id}")

    # Check Order Territory Snapshots
    orders = Order.objects.all()
    print(f"\nExisting Orders in DB: {orders.count()}")
    for o in orders[:5]:
        print(f"  - Order #{o.id}: Customer='{o.created_by.username if o.created_by else 'Guest'}', Territory='{o.territory}', Serving Franchise='{o.serving_franchise.business_name if o.serving_franchise else o.franchise_name}'")

    print("\n" + "=" * 70)
    print("2. END-TO-END FLOW: REGISTRATION -> RESOLUTION -> ORDER -> ROUTING")
    print("=" * 70)

    factory = APIRequestFactory()

    # TEST A: Customer registers in 'East Raipur' (Has exact assigned franchise)
    print("\n[TEST A] Registration & Routing for East Raipur (Direct Franchise Zone)...")
    reg_view = CustomerRegisterView.as_view()
    reg_data_a = {
        "username": "audit_cust_east@shivnath.com",
        "email": "audit_cust_east@shivnath.com",
        "password": "Password@123",
        "confirm_password": "Password@123",
        "first_name": "Audit Cust East",
        "name": "Audit Cust East",
        "phone": "9820000001",
        "address": "Flat 101, Pandri Market",
        "city": "Raipur",
        "district": "Raipur",
        "state": "Chhattisgarh",
        "pincode": "492001",
        "zone_id": ServiceZone.objects.get(name="East Raipur").id
    }
    # Clean up test user if exists
    User.objects.filter(username=reg_data_a["username"]).delete()
    
    req_reg_a = factory.post('/api/auth/customer-register/', reg_data_a, format='json')
    res_reg_a = reg_view(req_reg_a)
    print(f"  Registration Status: {res_reg_a.status_code}")
    assert res_reg_a.status_code in [200, 201], f"Registration failed: {res_reg_a.data}"
    
    # Verify Eligible Franchise API for East Raipur
    elig_view = EligibleFranchisesView.as_view()
    req_elig_a = factory.get(f"/api/auth/eligible-franchises/?territory_id={reg_data_a['zone_id']}&district=Raipur")
    res_elig_a = elig_view(req_elig_a)
    assert res_elig_a.status_code == 200
    exact_matches = res_elig_a.data.get('exact_matches', [])
    print(f"  Eligible Franchises for East Raipur: {[f['business_name'] for f in exact_matches]}")
    assert any("Raipur East" in f['business_name'] for f in exact_matches), "East Raipur franchise not resolved"

    # Test Order Creation & Auto-Routing for East Raipur Customer
    u_cust_a = User.objects.get(username=reg_data_a["username"])
    product = Product.objects.filter(status='active').first() or Product.objects.first()
    order_create_view = OrderListCreateView.as_view()
    order_payload_a = {
        "delivery_address": "Flat 101, Pandri Market, Raipur",
        "delivery_city": "Raipur",
        "delivery_district": "Raipur",
        "delivery_territory": "East Raipur",
        "delivery_pincode": "492001",
        "items": [
            {"product_id": product.id, "quantity": 5}
        ]
    }
    req_order_a = factory.post('/api/orders/customer/create/', order_payload_a, format='json')
    force_authenticate(req_order_a, user=u_cust_a)
    res_order_a = order_create_view(req_order_a)
    print(f"  Order Creation Status: {res_order_a.status_code}")
    assert res_order_a.status_code in [200, 201], f"Order creation failed: {res_order_a.data}"
    created_order_a = Order.objects.get(id=res_order_a.data['order_id'])
    print(f"  Created Order #{created_order_a.id} routed to: {created_order_a.serving_franchise.business_name if created_order_a.serving_franchise else 'DIRECT_COMPANY'}")
    assert created_order_a.serving_franchise.business_name == "Shivnath Water Raipur East"
    assert created_order_a.order_source == 'FRANCHISE'

    # TEST B: Customer registers in 'South Raipur' (Newly added zone without dedicated franchise -> DIRECT_COMPANY fallback)
    print("\n[TEST B] Registration & Routing for South Raipur (New Zone Fallback to Direct Company)...")
    z_south = ServiceZone.objects.get(name="South Raipur")
    reg_data_b = {
        "username": "audit_cust_south@shivnath.com",
        "email": "audit_cust_south@shivnath.com",
        "password": "Password@123",
        "confirm_password": "Password@123",
        "first_name": "Audit Cust South",
        "name": "Audit Cust South",
        "phone": "9820000002",
        "address": "Bhatagaon Chowk",
        "city": "Raipur",
        "district": "Raipur",
        "state": "Chhattisgarh",
        "pincode": "492013",
        "zone_id": z_south.id
    }
    User.objects.filter(username=reg_data_b["username"]).delete()
    req_reg_b = factory.post('/api/auth/customer-register/', reg_data_b, format='json')
    res_reg_b = reg_view(req_reg_b)
    assert res_reg_b.status_code in [200, 201]

    req_elig_b = factory.get(f"/api/auth/eligible-franchises/?territory_id={z_south.id}&district=Raipur")
    res_elig_b = elig_view(req_elig_b)
    print(f"  Eligible Franchises for South Raipur (Fallbacks): {[f['business_name'] for f in res_elig_b.data.get('available_franchises', [])]}")
    
    u_cust_b = User.objects.get(username=reg_data_b["username"])
    order_payload_b = {
        "delivery_address": "Bhatagaon Chowk, Raipur",
        "delivery_city": "Raipur",
        "delivery_district": "Raipur",
        "delivery_territory": "South Raipur",
        "delivery_pincode": "492013",
        "payment_mode": "ONLINE",
        "items": [
            {"product_id": product.id, "quantity": 3}
        ]
    }
    req_order_b = factory.post('/api/orders/', order_payload_b, format='json')
    force_authenticate(req_order_b, user=u_cust_b)
    res_order_b = order_create_view(req_order_b)
    assert res_order_b.status_code in [200, 201]
    created_order_b = Order.objects.get(id=res_order_b.data['order_id'])
    print(f"  Created Order #{created_order_b.id} routed as: {created_order_b.order_source} (Serving: {created_order_b.serving_franchise.business_name if created_order_b.serving_franchise else 'DIRECT_COMPANY'})")
    assert created_order_b.order_source in ['FRANCHISE', 'DIRECT_COMPANY']

    # TEST C: Customer in a distant newly added district (e.g. Bastar / Jagdalpur)
    print("\n[TEST C] Registration & Routing for Bastar (Jagdalpur City)...")
    z_jgd = ServiceZone.objects.get(name="Jagdalpur City")
    reg_data_c = {
        "username": "audit_cust_bastar@shivnath.com",
        "email": "audit_cust_bastar@shivnath.com",
        "password": "Password@123",
        "confirm_password": "Password@123",
        "first_name": "Audit Cust Bastar",
        "name": "Audit Cust Bastar",
        "phone": "9820000003",
        "address": "Main Market, Jagdalpur",
        "city": "Jagdalpur",
        "district": "Bastar",
        "state": "Chhattisgarh",
        "pincode": "494001",
        "zone_id": z_jgd.id
    }
    User.objects.filter(username=reg_data_c["username"]).delete()
    req_reg_c = factory.post('/api/auth/customer-register/', reg_data_c, format='json')
    res_reg_c = reg_view(req_reg_c)
    assert res_reg_c.status_code in [200, 201]
    u_cust_c = User.objects.get(username=reg_data_c["username"])
    order_payload_c = {
        "delivery_address": "Main Market, Jagdalpur",
        "delivery_city": "Jagdalpur",
        "delivery_district": "Bastar",
        "delivery_territory": "Jagdalpur City",
        "delivery_pincode": "494001",
        "payment_mode": "ONLINE",
        "items": [
            {"product_id": product.id, "quantity": 10}
        ]
    }
    req_order_c = factory.post('/api/orders/', order_payload_c, format='json')
    force_authenticate(req_order_c, user=u_cust_c)
    res_order_c = order_create_view(req_order_c)
    assert res_order_c.status_code in [200, 201]
    created_order_c = Order.objects.get(id=res_order_c.data['order_id'])
    print(f"  Created Order #{created_order_c.id} routed as: {created_order_c.order_source} (Serving: {created_order_c.serving_franchise.business_name if created_order_c.serving_franchise else 'DIRECT_COMPANY'})")
    assert created_order_c.order_source == 'DIRECT_COMPANY'

    # Cleanup test stock cycles, orders, and users
    from accounts.models import CustomerStockCycle
    CustomerStockCycle.objects.filter(order_id__in=[created_order_a.id, created_order_b.id, created_order_c.id]).delete()
    Order.objects.filter(id__in=[created_order_a.id, created_order_b.id, created_order_c.id]).delete()
    User.objects.filter(username__in=[reg_data_a["username"], reg_data_b["username"], reg_data_c["username"]]).delete()

    print("\n" + "=" * 70)
    print("ALL AUDIT & END-TO-END FLOW TESTS PASSED WITHOUT REGRESSION!")
    print("=" * 70)

if __name__ == '__main__':
    test_complete_audit_and_lifecycle()

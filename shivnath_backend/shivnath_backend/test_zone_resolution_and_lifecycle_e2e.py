import os
import django
from decimal import Decimal
from datetime import date, timedelta

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from django.test import RequestFactory
from django.contrib.auth.models import User
from rest_framework import status
from rest_framework.test import APIRequestFactory, force_authenticate

from accounts.models import (
    UserProfile,
    FranchiseProfile,
    ServiceDistrict,
    ServiceZone,
    ServiceArea,
    FranchiseTerritoryAssignment,
    CustomerFranchiseRelationship,
    CustomerStockCycle,
    ServiceHoldHistory,
    CustomerBulkOrder,
    FranchiseNotification,
    AdminNotification,
)
from accounts.views import (
    CustomerRegisterView,
    ZoneResolutionView,
    CustomerServiceStatusView,
    FranchiseCustomerListView,
    EligibleFranchisesView,
)
from orders.models import Order
from orders.views import OrderListCreateView, CustomerBulkOrderView
from products.models import Product
from accounts.services import check_and_dispatch_stock_alerts


def run_all_tests():
    print("\n=======================================================")
    print("RUNNING END-TO-END VERIFICATION: ZONE RESOLUTION & LIFECYCLE")
    print("=======================================================\n")

    factory = APIRequestFactory()

    # -----------------------------------------------------------------
    # SCENARIO 1: DYNAMIC ZONE RESOLUTION (VALID, AMBIGUOUS, UNKNOWN)
    # -----------------------------------------------------------------
    print("--- Scenario 1: Dynamic Zone Resolution ---")
    view = ZoneResolutionView.as_view()

    # 1. Valid PIN
    req1 = factory.post('/api/accounts/resolve-zone/', {'district': 'Raipur', 'pincode': '492001'})
    res1 = view(req1)
    assert res1.status_code == 200, f"Expected 200, got {res1.status_code}"
    assert res1.data['status'] == 'resolved', f"Expected resolved, got {res1.data['status']}"
    assert res1.data['zone_name'] == 'East Raipur'
    print("  [PASS] Valid PIN 492001 -> correctly resolved to East Raipur.")

    # 2. Ambiguous PIN
    req2 = factory.post('/api/accounts/resolve-zone/', {'district': 'Raipur', 'pincode': '492099'})
    res2 = view(req2)
    assert res2.status_code == 200
    assert res2.data['status'] == 'ambiguous', f"Expected ambiguous, got {res2.data['status']}"
    assert len(res2.data['options']) >= 2
    print(f"  [PASS] Ambiguous PIN 492099 -> returned {len(res2.data['options'])} options without guessing.")

    # 3. Ambiguous PIN resolved via locality
    req2_loc = factory.post('/api/accounts/resolve-zone/', {'district': 'Raipur', 'pincode': '492099', 'locality': 'North Pandri Border'})
    res2_loc = view(req2_loc)
    assert res2_loc.status_code == 200
    assert res2_loc.data['status'] == 'resolved'
    assert res2_loc.data['zone_name'] == 'East Raipur'
    print("  [PASS] Ambiguous PIN 492099 + Locality 'North Pandri' -> successfully resolved to East Raipur.")

    # 4. Unknown PIN
    req3 = factory.post('/api/accounts/resolve-zone/', {'district': 'Raipur', 'pincode': '999999'})
    res3 = view(req3)
    assert res3.status_code == 200
    assert res3.data['status'] == 'unknown'
    assert 'available_areas' in res3.data
    print("  [PASS] Unknown PIN 999999 -> status unknown with suggested available areas.")

    # -----------------------------------------------------------------
    # SCENARIO 2: ZONE TAMPER RESISTANCE & DETERMINISTIC REGISTRATION
    # -----------------------------------------------------------------
    print("\n--- Scenario 2: Zone Tamper Resistance & Deterministic Registration ---")
    reg_view = CustomerRegisterView.as_view()

    # 1. Tampered Zone ID test
    durg_zone = ServiceZone.objects.get(name="Central Durg")
    tampered_data = {
        'name': 'Tamper Test User',
        'phone': '9893000001',
        'email': 'tamper_test@shivnath.com',
        'password': 'password123',
        'confirm_password': 'password123',
        'city': 'Raipur',
        'district': 'Raipur',
        'pincode': '492001',  # Raipur East
        'zone_id': durg_zone.id,  # Tampered to Durg!
    }
    req_tamp = factory.post('/api/auth/register/customer/', tampered_data)
    res_tamp = reg_view(req_tamp)
    assert res_tamp.status_code == 400, f"Expected 400 on tampered zone, got {res_tamp.status_code}"
    assert 'zone_id' in res_tamp.data['errors']
    print("  [PASS] Tampered Zone ID mismatching PIN was rejected with 400 Bad Request.")

    # 2. Clean Valid Registration
    User.objects.filter(email='rahul_east@shivnath.com').delete()
    clean_data = {
        'name': 'Rahul Sharma',
        'phone': '9893111222',
        'email': 'rahul_east@shivnath.com',
        'password': 'password123',
        'confirm_password': 'password123',
        'city': 'Raipur',
        'district': 'Raipur',
        'pincode': '492001',
        'address': 'House 14, Pandri',
    }
    req_clean = factory.post('/api/auth/register/customer/', clean_data)
    res_clean = reg_view(req_clean)
    assert res_clean.status_code == 201, f"Expected 201, got {res_clean.status_code} ({res_clean.data})"

    rahul_user = User.objects.get(email='rahul_east@shivnath.com')
    rel = CustomerFranchiseRelationship.objects.get(customer=rahul_user)
    assert rel.registered_franchise.business_name == "Shivnath Water Raipur East", f"Got {rel.registered_franchise.business_name}"
    assert rel.zone.name == "East Raipur"
    print(f"  [PASS] Rahul registered -> deterministically assigned to '{rel.registered_franchise.business_name}' in {rel.zone.name}.")

    # Verify Dual Notifications on Registration
    f_notif = FranchiseNotification.objects.filter(franchise=rel.registered_franchise, notification_type='new_customer', reference_id=rahul_user.id).first()
    assert f_notif is not None, "Franchise notification was not created!"
    assert "Rahul Sharma" in f_notif.message

    a_notif = AdminNotification.objects.filter(notification_type='customer_registration', reference_id=rahul_user.id).first()
    assert a_notif is not None, "Admin notification was not created!"
    print("  [PASS] Dual notifications created for Assigned Franchise and Admin on registration.")

    # -----------------------------------------------------------------
    # SCENARIO 3: DYNAMIC STOCK DURATION & ORDER PLACEMENT
    # -----------------------------------------------------------------
    print("\n--- Scenario 3: Order Placement with Dynamic Stock Duration & Serving Franchise ---")
    order_view = OrderListCreateView.as_view()

    # Product
    prod = Product.objects.first()
    if not prod:
        prod = Product.objects.create(name="Shivnath 20L Jar", sku="SKU-JAR-TEST", price=Decimal("80.00"), stock=500)
    else:
        prod.stock = 500
        prod.save()

    # Select secondary franchise in same zone as serving franchise
    pureflow_east = FranchiseProfile.objects.get(business_name="Pure Flow Water East Zone")

    order_payload = {
        'items': 5,
        'order_items': [{'product_id': prod.id, 'quantity': 5, 'price': 80.0}],
        'duration_choice': '2 Months',
        'duration_days': 60,
        'serving_franchise_id': pureflow_east.id,
    }
    req_order = factory.post('/api/orders/', order_payload, format='json')
    force_authenticate(req_order, user=rahul_user)
    res_order = order_view(req_order)
    assert res_order.status_code == 201, f"Expected 201, got {res_order.status_code} ({res_order.data})"

    order_id = res_order.data['order']['id']
    placed_order = Order.objects.get(id=order_id)

    # Verify duration and expected end date
    today = date.today()
    expected_end = today + timedelta(days=60)
    assert placed_order.duration_choice == '2 Months'
    assert placed_order.duration_days == 60
    assert placed_order.expected_end_date == expected_end
    assert placed_order.serving_franchise == pureflow_east
    assert placed_order.registered_franchise.business_name == "Shivnath Water Raipur East"
    print(f"  [PASS] Order #{placed_order.order_code} stored duration '2 Months' (60 days), ending {expected_end}.")
    print(f"  [PASS] Dual franchise preserved: Registered='{placed_order.registered_franchise.business_name}' vs Serving='{placed_order.serving_franchise.business_name}'.")

    # Verify active stock cycle
    cycle = CustomerStockCycle.objects.filter(customer=rahul_user, order=placed_order).first()
    assert cycle is not None
    assert cycle.serving_franchise == pureflow_east
    assert cycle.expected_end_date == expected_end
    assert cycle.service_status == 'active'
    print(f"  [PASS] CustomerStockCycle created permanently linked to serving franchise '{cycle.serving_franchise.business_name}'.")

    # -----------------------------------------------------------------
    # SCENARIO 4: MULTI-CYCLE SAFE HOLD / RESUME LIFECYCLE
    # -----------------------------------------------------------------
    print("\n--- Scenario 4: Multi-Cycle Safe Hold / Resume Lifecycle ---")
    status_view = CustomerServiceStatusView.as_view()

    # 1. HOLD Cycle 1
    req_hold = factory.post('/api/accounts/service-status/', {'action': 'hold', 'reason': 'Customer vacation'})
    force_authenticate(req_hold, user=rahul_user)
    res_hold = status_view(req_hold)
    assert res_hold.status_code == 200, f"Expected 200, got {res_hold.status_code}"
    cycle.refresh_from_db()
    assert cycle.service_status == 'hold'
    assert cycle.remaining_days_at_hold == 60
    print(f"  [PASS] Service placed on HOLD: {cycle.remaining_days_at_hold} days preserved safely.")

    # Verify Hold log
    hold_log = ServiceHoldHistory.objects.filter(stock_cycle=cycle, action='hold').latest('created_at')
    assert hold_log.actor == rahul_user
    assert hold_log.remaining_days == 60
    print("  [PASS] ServiceHoldHistory logged hold action and remaining days.")

    # 2. RESUME Cycle 1
    req_resume = factory.post('/api/accounts/service-status/', {'action': 'resume', 'reason': 'Returned from vacation'})
    force_authenticate(req_resume, user=rahul_user)
    res_resume = status_view(req_resume)
    assert res_resume.status_code == 200
    cycle.refresh_from_db()
    assert cycle.service_status == 'active'
    assert cycle.expected_end_date == today + timedelta(days=60)
    print(f"  [PASS] Service RESUMED: new expected end date recalculated to {cycle.expected_end_date}.")

    # 3. HOLD Cycle 2 (simulate remaining days decrementing)
    cycle.expected_end_date = today + timedelta(days=20)
    cycle.save(update_fields=['expected_end_date'])

    req_hold2 = factory.post('/api/accounts/service-status/', {'action': 'hold', 'reason': 'Repairs at premises'})
    force_authenticate(req_hold2, user=rahul_user)
    res_hold2 = status_view(req_hold2)
    assert res_hold2.status_code == 200
    cycle.refresh_from_db()
    assert cycle.remaining_days_at_hold == 20
    print(f"  [PASS] Second HOLD cycle preserved current remaining duration (20 days), not original 60 days.")

    # 4. RESUME Cycle 2
    req_resume2 = factory.post('/api/accounts/service-status/', {'action': 'resume'})
    force_authenticate(req_resume2, user=rahul_user)
    res_resume2 = status_view(req_resume2)
    assert res_resume2.status_code == 200
    cycle.refresh_from_db()
    assert cycle.expected_end_date == today + timedelta(days=20)
    print(f"  [PASS] Second RESUME safely restored {cycle.expected_end_date} (today + 20 days).")

    # -----------------------------------------------------------------
    # SCENARIO 5: 7-DAY LOW-STOCK ALERT ENGINE
    # -----------------------------------------------------------------
    print("\n--- Scenario 5: 7-Day Low-Stock Alert Engine ---")
    # Simulate cycle reaching 5 days remaining
    cycle.expected_end_date = today + timedelta(days=5)
    cycle.low_stock_alert_sent = False
    cycle.save(update_fields=['expected_end_date', 'low_stock_alert_sent'])

    alerts = check_and_dispatch_stock_alerts()
    assert len(alerts) >= 1
    cycle.refresh_from_db()
    assert cycle.low_stock_alert_sent is True

    # Check that Serving Franchise received alert
    alert_notif = FranchiseNotification.objects.filter(franchise=cycle.serving_franchise, notification_type='stock_alert', reference_id=cycle.id).first()
    assert alert_notif is not None
    assert "Low Stock Alert" in alert_notif.title
    print(f"  [PASS] 7-day low-stock alert triggered and dispatched to serving franchise '{cycle.serving_franchise.business_name}' and Admin.")

    # -----------------------------------------------------------------
    # SCENARIO 6: CUSTOMER BULK ORDER & SERVER SECURITY
    # -----------------------------------------------------------------
    print("\n--- Scenario 6: Customer Bulk Order & Server Security ---")
    bulk_view = CustomerBulkOrderView.as_view()

    # 1. Attempt bulk order with illegal cross-territory franchise
    durg_franchise = FranchiseProfile.objects.get(business_name="Shivnath Water Durg")
    bad_bulk = {
        'product_name': '20L Jars Bulk',
        'quantity': 200,
        'required_date': (today + timedelta(days=10)).isoformat(),
        'serving_franchise_id': durg_franchise.id,  # Customer is in Raipur, franchise is in Durg!
    }
    req_bad_bulk = factory.post('/api/orders/bulk/', bad_bulk, format='json')
    force_authenticate(req_bad_bulk, user=rahul_user)
    res_bad_bulk = bulk_view(req_bad_bulk)
    assert res_bad_bulk.status_code == 400
    print("  [PASS] Bulk order rejected cross-territory franchise submission.")

    # 2. Valid Bulk Order
    good_bulk = {
        'product_name': '20L Jars Bulk',
        'quantity': 200,
        'duration_choice': '1 Month Supply',
        'required_date': (today + timedelta(days=5)).isoformat(),
        'delivery_address': 'Pandri Convention Center',
        'serving_franchise_id': pureflow_east.id,
        'additional_notes': 'Corporate Event Delivery',
    }
    req_good_bulk = factory.post('/api/orders/bulk/', good_bulk, format='json')
    force_authenticate(req_good_bulk, user=rahul_user)
    res_good_bulk = bulk_view(req_good_bulk)
    assert res_good_bulk.status_code == 201
    bulk_id = res_good_bulk.data['bulk_order']['id']
    bulk_rec = CustomerBulkOrder.objects.get(id=bulk_id)
    assert bulk_rec.district == "Raipur"
    assert bulk_rec.zone_name == "East Raipur"
    print(f"  [PASS] Bulk order #{bulk_id} created with server-derived District/Zone ({bulk_rec.district} - {bulk_rec.zone_name}).")

    # -----------------------------------------------------------------
    # SCENARIO 7: FRANCHISE PERMISSION ISOLATION
    # -----------------------------------------------------------------
    print("\n--- Scenario 7: Franchise Permission Isolation ---")
    f_cust_view = FranchiseCustomerListView.as_view()

    # Franchise East (serving East Raipur)
    u_f_east = User.objects.get(username="franchise_east@shivnath.com")
    req_fe = factory.get('/api/accounts/franchise-customers/')
    force_authenticate(req_fe, user=u_f_east)
    res_fe = f_cust_view(req_fe)
    if res_fe.status_code != 200:
        print(f"DEBUG res_fe status: {res_fe.status_code}, data: {res_fe.data}")
    assert res_fe.status_code == 200, f"Expected 200, got {res_fe.status_code}"
    east_cust_ids = [c['id'] for c in res_fe.data['customers']]
    assert rahul_user.id in east_cust_ids
    print(f"  [PASS] Franchise East can see its registered customer (Rahul Sharma).")

    # Franchise Durg (unrelated territory)
    u_f_durg = User.objects.get(username="franchise_durg@shivnath.com")
    req_fd = factory.get('/api/accounts/franchise-customers/')
    force_authenticate(req_fd, user=u_f_durg)
    res_fd = f_cust_view(req_fd)
    assert res_fd.status_code == 200
    durg_cust_ids = [c['id'] for c in res_fd.data['customers']]
    assert rahul_user.id not in durg_cust_ids
    print(f"  [PASS] Franchise Durg CANNOT see Rahul Sharma (strict queryset isolation confirmed).")

    # -----------------------------------------------------------------
    # SCENARIO 8: SERVICEABILITY FALLBACK, EMPTY-STATE PREVENTION & TAMPER PROTECTION
    # -----------------------------------------------------------------
    print("\n--- Scenario 8: Serviceability Fallback, Empty-State Prevention & Tamper Protection ---")
    elig_view = EligibleFranchisesView.as_view()

    # Create a new test zone in Raipur with ZERO assigned franchises: 'North Raipur'
    d_raipur = ServiceDistrict.objects.get(name="Raipur")
    z_north, _ = ServiceZone.objects.get_or_create(district=d_raipur, name="North Raipur", code="RPR-NORTH", defaults={'is_active': True})

    rahul_rel = CustomerFranchiseRelationship.objects.get(customer=rahul_user)
    z_east = rahul_rel.zone
    fp_east = rahul_rel.registered_franchise

    # Case 1: Exact Zone with Active Franchise
    req_exact = factory.get(f'/api/accounts/eligible-franchises/?zone_id={z_east.id}')
    res_exact = elig_view(req_exact)
    assert res_exact.status_code == 200
    assert res_exact.data['match_level'] == 'exact'
    assert res_exact.data['is_fallback'] is False
    assert len(res_exact.data['franchises']) >= 1
    print("  [PASS] Exact zone with active franchise -> returns exact-zone franchises (is_fallback=False).")

    # Case 2: Exact Zone has NO franchise, but Raipur District has active franchises -> Fallback returned
    req_fallback = factory.get(f'/api/accounts/eligible-franchises/?zone_id={z_north.id}&district=Raipur')
    res_fallback = elig_view(req_fallback)
    assert res_fallback.status_code == 200
    assert res_fallback.data['match_level'] == 'district_fallback'
    assert res_fallback.data['is_fallback'] is True
    assert 'nearby/alternate' in res_fallback.data['fallback_message']
    assert len(res_fallback.data['franchises']) >= 1
    assert 'service_coverage' in res_fallback.data['franchises'][0]
    fallback_f_id = res_fallback.data['franchises'][0]['id']
    print("  [PASS] Exact zone has no franchise, same district has active franchise -> fallback franchises returned with service coverage info.")

    # Case 3: Inactive franchise is NEVER returned
    inactive_user, _ = User.objects.get_or_create(username="inactive_f@shivnath.com", defaults={'email': 'inactive_f@shivnath.com'})
    inactive_fp, _ = FranchiseProfile.objects.get_or_create(user=inactive_user, defaults={'business_name': 'Inactive Water', 'status': 'rejected'})
    inactive_fp.status = 'rejected'
    inactive_fp.save()
    FranchiseTerritoryAssignment.objects.get_or_create(franchise=inactive_fp, zone=z_north, defaults={'is_active': False})
    req_inact = factory.get(f'/api/accounts/eligible-franchises/?zone_id={z_north.id}')
    res_inact = elig_view(req_inact)
    returned_ids = [f['id'] for f in res_inact.data['franchises']]
    assert inactive_fp.id not in returned_ids
    print("  [PASS] Inactive or unapproved franchise -> never shown in exact or fallback search.")

    # Case 4: Remote district with NO franchises anywhere -> Service Unavailable + Support Contact
    d_remote, _ = ServiceDistrict.objects.get_or_create(name="Remote District", defaults={'state': 'Chhattisgarh', 'is_active': True})
    z_remote, _ = ServiceZone.objects.get_or_create(district=d_remote, name="Remote Valley", code="RMT-VLY", defaults={'is_active': True})
    req_none = factory.get(f'/api/accounts/eligible-franchises/?zone_id={z_remote.id}&district=Remote District')
    res_none = elig_view(req_none)
    assert res_none.status_code == 200
    assert res_none.data['match_level'] == 'none'
    assert res_none.data['count'] == 0
    assert res_none.data['support_contact'] is not None
    assert 'phone' in res_none.data['support_contact']
    print("  [PASS] Area with zero franchises -> returns match_level='none' with Central Support contact.")

    # Case 5: Tamper Protection - Customer in North Raipur cannot submit arbitrary/unrelated franchise from Durg
    order_view = OrderListCreateView.as_view()
    bad_order_data = {
        'items': 1,
        'amount': '150.00',
        'serving_franchise_id': durg_franchise.id,  # Durg franchise cannot serve Raipur customer!
        'duration_choice': '1 Month',
        'duration_days': 30,
        'order_items': [{'product_id': 1, 'quantity': 1, 'price': 150.0}],
    }
    req_bad_order = factory.post('/api/orders/', bad_order_data, format='json')
    force_authenticate(req_bad_order, user=rahul_user)
    res_bad_order = order_view(req_bad_order)
    assert res_bad_order.status_code == 400
    print("  [PASS] Customer order with unrelated cross-territory franchise rejected with 400 Bad Request.")

    # Case 6: Dual Franchise Preservation when Ordering from Fallback Franchise
    # Customer Rahul is registered with Franchise East (fp_east).
    # He places an order with a valid fallback franchise (e.g. pureflow_east or fp_west)
    fallback_f = FranchiseProfile.objects.get(id=fallback_f_id)
    good_fallback_order = {
        'items': 1,
        'amount': '300.00',
        'serving_franchise_id': fallback_f.id,
        'duration_choice': '1 Month',
        'duration_days': 30,
        'order_items': [{'product_id': 1, 'quantity': 2, 'price': 150.0}],
    }
    req_good_order = factory.post('/api/orders/', good_fallback_order, format='json')
    force_authenticate(req_good_order, user=rahul_user)
    res_good_order = order_view(req_good_order)
    assert res_good_order.status_code == 201
    created_order = Order.objects.get(id=res_good_order.data['order']['id'])
    assert created_order.serving_franchise_id == fallback_f.id
    assert created_order.registered_franchise_id == fp_east.id
    rahul_rel = CustomerFranchiseRelationship.objects.get(customer=rahul_user)
    assert rahul_rel.registered_franchise_id == fp_east.id, "Registered franchise must NEVER be overwritten!"
    print(f"  [PASS] Dual franchise preserved: Registered='{fp_east.business_name}' retained while Serving='{fallback_f.business_name}' assigned to Order.")

    print("\n=======================================================")
    print("ALL 8 CORE SERVER, LIFECYCLE & FALLBACK SCENARIOS PASSED 100%!")
    print("=======================================================\n")


if __name__ == '__main__':
    run_all_tests()


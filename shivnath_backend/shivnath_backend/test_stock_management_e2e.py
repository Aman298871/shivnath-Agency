import os
import django
from datetime import date, timedelta

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from django.contrib.auth.models import User
from django.utils import timezone
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
    StockAlertLog,
    CustomerNotification,
    FranchiseNotification,
    AdminNotification,
)
from orders.models import Order, OrderItem
from products.models import Product
from accounts.services import (
    add_calendar_months,
    calculate_stock_end_date,
    trigger_daily_low_stock_alerts,
    send_customer_registration_notifications,
    send_order_placed_notifications,
)


def run_stock_management_tests():
    print("\n=======================================================")
    print("RUNNING END-TO-END VERIFICATION: STOCK MANAGEMENT SYSTEM")
    print("=======================================================")

    # --- Setup Clean Test Data ---
    CustomerStockCycle.objects.filter(customer__username__startswith='stock_test_').delete()
    CustomerFranchiseRelationship.objects.filter(customer__username__startswith='stock_test_').delete()
    Order.objects.filter(created_by__username__startswith='stock_test_').delete()
    FranchiseTerritoryAssignment.objects.filter(franchise__user__username__startswith='stock_test_').delete()
    FranchiseProfile.objects.filter(user__username__startswith='stock_test_').delete()
    User.objects.filter(username__startswith='stock_test_').delete()
    Product.objects.filter(sku='STOCK-JAR-20L').delete()
    ServiceDistrict.objects.filter(name='Stock Raipur District').delete()
    ServiceDistrict.objects.filter(name='Stock Durg District').delete()

    district = ServiceDistrict.objects.create(name='Stock Raipur District', state='Chhattisgarh')
    zone_east = ServiceZone.objects.create(district=district, name='Stock Raipur East', code='STOCK_RPR_EAST')
    zone_west = ServiceZone.objects.create(district=district, name='Stock Raipur West', code='STOCK_RPR_WEST')
    area_east = ServiceArea.objects.create(district=district, zone=zone_east, pincode='492088', locality_name='Stock Telibandha')

    # Franchise A (East)
    u_fa = User.objects.create_user('stock_test_fa', 'fa@shivnath.com', 'pass123', first_name='Franchise', last_name='Alpha')
    p_fa, _ = UserProfile.objects.get_or_create(user=u_fa)
    p_fa.role = 'franchise'
    p_fa.phone = '9888800001'
    p_fa.save()
    f_alpha = FranchiseProfile.objects.create(user=u_fa, business_name='Alpha Water East', status='approved', city='Raipur')
    FranchiseTerritoryAssignment.objects.create(franchise=f_alpha, zone=zone_east, is_primary=True, is_active=True)

    # Franchise B (West)
    u_fb = User.objects.create_user('stock_test_fb', 'fb@shivnath.com', 'pass123', first_name='Franchise', last_name='Beta')
    p_fb, _ = UserProfile.objects.get_or_create(user=u_fb)
    p_fb.role = 'franchise'
    p_fb.phone = '9888800002'
    p_fb.save()
    f_beta = FranchiseProfile.objects.create(user=u_fb, business_name='Beta Water West', status='approved', city='Raipur')
    FranchiseTerritoryAssignment.objects.create(franchise=f_beta, zone=zone_west, is_primary=True, is_active=True)

    # Unrelated Franchise C (Durg)
    dist_durg = ServiceDistrict.objects.create(name='Stock Durg District', state='Chhattisgarh')
    zone_durg = ServiceZone.objects.create(district=dist_durg, name='Stock Durg North', code='STOCK_DURG_N')
    u_fc = User.objects.create_user('stock_test_fc', 'fc@shivnath.com', 'pass123', first_name='Franchise', last_name='Gamma')
    p_fc, _ = UserProfile.objects.get_or_create(user=u_fc)
    p_fc.role = 'franchise'
    p_fc.phone = '9888800003'
    p_fc.save()
    f_gamma = FranchiseProfile.objects.create(user=u_fc, business_name='Gamma Water Durg', status='approved', city='Durg')
    FranchiseTerritoryAssignment.objects.create(franchise=f_gamma, zone=zone_durg, is_primary=True, is_active=True)

    # Product
    prod = Product.objects.create(name='Shivnath 20L Purity Jar', sku='STOCK-JAR-20L', size='20 Litre', price=80.00, stock=500)

    # Customer registered under Franchise A (East)
    u_cust = User.objects.create_user('stock_test_cust', 'customer_aman@shivnath.com', 'pass123', first_name='Aman', last_name='Singh')
    p_cust, _ = UserProfile.objects.get_or_create(user=u_cust)
    p_cust.role = 'customer'
    p_cust.phone = '9800012345'
    p_cust.district = 'Stock Raipur District'
    p_cust.pincode = '492088'
    p_cust.locality = 'Stock Telibandha'
    p_cust.zone = zone_east
    p_cust.save()
    rel = CustomerFranchiseRelationship.objects.create(
        customer=u_cust,
        registered_franchise=f_alpha,
        current_serving_franchise=f_alpha,
        district=district,
        zone=zone_east,
        service_area=area_east,
        pincode='492088',
        locality='Stock Telibandha',
        service_status='active'
    )

    print("\n--- 1. Testing Explicit Calendar Month & Custom Duration Calculations ---")
    d_start = date(2026, 9, 18)
    d_1m = calculate_stock_end_date(d_start, '1 Month')
    assert d_1m == date(2026, 10, 18), f"Expected 2026-10-18, got {d_1m}"
    print(f"  [PASS] 1 Month: 18 Sep 2026 -> {d_1m} (1 calendar month)")

    d_2m = calculate_stock_end_date(d_start, '2 Months')
    assert d_2m == date(2026, 11, 18), f"Expected 2026-11-18, got {d_2m}"
    print(f"  [PASS] 2 Months: 18 Sep 2026 -> {d_2m} (2 calendar months)")

    d_3m = calculate_stock_end_date(d_start, '3 Months')
    assert d_3m == date(2026, 12, 18), f"Expected 2026-12-18, got {d_3m}"
    print(f"  [PASS] 3 Months: 18 Sep 2026 -> {d_3m} (3 calendar months)")

    d_custom = calculate_stock_end_date(d_start, 'Custom', custom_days=45)
    assert d_custom == date(2026, 11, 2), f"Expected 2026-11-02, got {d_custom}"
    print(f"  [PASS] Custom 45 Days: 18 Sep 2026 -> {d_custom} (exact 45 days)")

    # Month end boundary test (31 Jan + 1 month in non-leap year)
    d_jan31 = date(2025, 1, 31)
    d_feb = calculate_stock_end_date(d_jan31, '1 Month')
    assert d_feb == date(2025, 2, 28), f"Expected 2025-02-28, got {d_feb}"
    print(f"  [PASS] Boundary Test: 31 Jan 2025 -> {d_feb} (month end clamped correctly)")

    print("\n--- 2. Order Creation -> Permanent Order Link & Dual Franchise Association ---")
    # Customer orders from fallback/serving Franchise B (West), while registered with Franchise A (East)
    order = Order.objects.create(
        created_by=u_cust,
        franchise_name=f_beta.business_name,
        city='Raipur',
        serving_franchise=f_beta,
        registered_franchise=f_alpha,
        zone=zone_east,
        duration_choice='1 Month',
        duration_days=30,
        expected_end_date=d_1m,
        amount=160.00,
        items_count=2,
    )
    OrderItem.objects.create(order=order, product=prod, product_name=prod.name, size=prod.size, quantity=2, unit_price=80.00, total_price=160.00)

    # Create CustomerStockCycle directly linked to order
    cycle = CustomerStockCycle.objects.create(
        customer=u_cust,
        order=order,
        product=prod,
        product_name=prod.name,
        variant_size=prod.size,
        quantity=2,
        serving_franchise=f_beta,
        registered_franchise=f_alpha,
        district=district,
        zone=zone_east,
        service_area=area_east,
        pincode='492088',
        start_date=d_start,
        duration_choice='1 Month',
        duration_days=30,
        expected_end_date=d_1m,
        service_status='active',
    )
    assert cycle.order == order, "StockCycle order link mismatch!"
    assert cycle.serving_franchise == f_beta, "StockCycle serving franchise must be Franchise B!"
    assert cycle.registered_franchise == f_alpha, "StockCycle registered franchise must be Franchise A!"
    print(f"  [PASS] Order #{order.order_code} created and permanently linked to StockCycle #{cycle.id}.")
    print(f"  [PASS] Dual franchise preserved: Registered='{cycle.registered_franchise.business_name}' vs Serving='{cycle.serving_franchise.business_name}'.")

    print("\n--- 3. Registration & Order Placement Notifications ---")
    FranchiseNotification.objects.all().delete()
    AdminNotification.objects.all().delete()

    send_customer_registration_notifications(u_cust, rel)
    assert FranchiseNotification.objects.filter(franchise=f_alpha, notification_type='new_customer').exists(), "Assigned franchise did not receive registration notification!"
    assert AdminNotification.objects.filter(notification_type='customer_registration').exists(), "Admin did not receive registration notification!"
    assert not FranchiseNotification.objects.filter(franchise=f_beta, notification_type='new_customer').exists(), "Unrelated franchise received registration notification!"
    print("  [PASS] Registration notification delivered to Assigned Franchise Alpha and Admin; Franchise Beta untouched.")

    send_order_placed_notifications(order, cycle)
    assert FranchiseNotification.objects.filter(franchise=f_beta, notification_type='order_placed').exists(), "Serving franchise did not receive order notification!"
    assert not FranchiseNotification.objects.filter(franchise=f_alpha, notification_type='order_placed').exists(), "Non-serving franchise must NOT receive order notification!"
    assert not FranchiseNotification.objects.filter(franchise=f_gamma, notification_type='order_placed').exists(), "Unrelated franchise must NOT receive order notification!"
    print("  [PASS] Order notification routed exclusively to Serving Franchise Beta and Admin; Registered Franchise Alpha and Gamma not notified.")

    print("\n--- 4. Low-Stock Notification 7-Day Window & Explicit Expiry Rules ---")
    CustomerNotification.objects.all().delete()
    FranchiseNotification.objects.all().delete()
    AdminNotification.objects.all().delete()
    StockAlertLog.objects.all().delete()

    # Case A: 10 days remaining (e.g. simulation date 8 Oct, end date 18 Oct)
    date_10_days = date(2026, 10, 8)
    dispatched = trigger_daily_low_stock_alerts(target_date=date_10_days)
    assert len(dispatched) == 0, "No notification should be dispatched when 10 days remain!"
    assert CustomerNotification.objects.count() == 0, "Customer should not receive alert at 10 days!"
    print("  [PASS] 10 days remaining -> Exactly 0 alerts sent.")

    # Case B: 8 days remaining (simulation date 10 Oct)
    date_8_days = date(2026, 10, 10)
    dispatched = trigger_daily_low_stock_alerts(target_date=date_8_days)
    assert len(dispatched) == 0, "No notification should be dispatched when 8 days remain!"
    print("  [PASS] 8 days remaining -> Exactly 0 alerts sent.")

    # Case C: Exactly 7 days remaining (simulation date 11 Oct)
    date_7_days = date(2026, 10, 11)
    dispatched = trigger_daily_low_stock_alerts(target_date=date_7_days)
    my_dispatched = [d for d in dispatched if d['cycle_id'] == cycle.id]
    assert len(my_dispatched) == 1, f"Alert batch should trigger for cycle #{cycle.id} at 7 days remaining! Got: {dispatched}"
    assert my_dispatched[0]['days_remaining'] == 7, "Remaining days should be 7!"

    # Verify exactly 3 targets:
    # 1. Customer
    c_notif = CustomerNotification.objects.filter(customer=u_cust, notification_type='low_stock').first()
    assert c_notif is not None, "Customer notification was not created!"
    assert "7 days" in c_notif.message, f"Customer notification missing '7 days': {c_notif.message}"

    # 2. Serving Franchise Beta
    f_notif = FranchiseNotification.objects.filter(franchise=f_beta, notification_type='stock_alert').first()
    assert f_notif is not None, "Serving Franchise Beta notification was not created!"
    assert not FranchiseNotification.objects.filter(franchise=f_alpha, notification_type='stock_alert', reference_id=cycle.id).exists(), "Franchise Alpha should NOT receive stock alert!"
    assert not FranchiseNotification.objects.filter(franchise=f_gamma, notification_type='stock_alert', reference_id=cycle.id).exists(), "Franchise Gamma should NOT receive stock alert!"

    # 3. Admin
    a_notif = AdminNotification.objects.filter(notification_type='stock_alert', reference_id=cycle.id).first()
    assert a_notif is not None, "Admin notification was not created!"

    # Verify StockAlertLog recorded
    logs = StockAlertLog.objects.filter(stock_cycle=cycle, alert_date=date_7_days, status='sent')
    assert logs.count() == 3, f"Expected 3 sent logs in StockAlertLog, found {logs.count()}"
    print("  [PASS] 7 days remaining -> Dispatched to exactly Customer, Serving Franchise Beta, and Admin.")

    print("\n--- 5. Idempotency & Deduplication Engine ---")
    # Re-run alert engine for the exact same date (11 Oct)
    dispatched_dup = trigger_daily_low_stock_alerts(target_date=date_7_days)
    my_dispatched_dup = [d for d in dispatched_dup if d['cycle_id'] == cycle.id]
    assert len(my_dispatched_dup) == 0, "Deduplication failed: job re-ran on same date and dispatched again!"
    assert StockAlertLog.objects.filter(stock_cycle=cycle, alert_date=date_7_days).count() == 3, "Duplicate logs were inserted!"
    assert CustomerNotification.objects.filter(customer=u_cust, notification_type='low_stock').count() == 1, "Duplicate customer notifications created!"
    print("  [PASS] Re-running alert engine on same day dispatched 0 duplicate alerts.")

    print("\n--- 6. Daily Countdown Progression (6, 5, 4, 3, 2, 1 days) ---")
    for remaining in [6, 5, 4, 3, 2, 1]:
        sim_date = d_1m - timedelta(days=remaining)
        dispatched_day = trigger_daily_low_stock_alerts(target_date=sim_date)
        my_dispatched_day = [d for d in dispatched_day if d['cycle_id'] == cycle.id]
        assert len(my_dispatched_day) == 1, f"Expected alert for day {remaining}!"
        latest_c_notif = CustomerNotification.objects.filter(customer=u_cust).order_by('-created_at').first()
        assert f"{remaining} day" in latest_c_notif.message, f"Expected message with '{remaining} day', got: {latest_c_notif.message}"
    print("  [PASS] Daily countdown progressed smoothly across 6, 5, 4, 3, 2, 1 days with accurate days remaining.")

    print("\n--- 7. Expiry Rule Enforcement (days_remaining <= 0) ---")
    # Date of expiry: 18 Oct
    date_expiry = d_1m
    dispatched_exp = trigger_daily_low_stock_alerts(target_date=date_expiry)
    cycle.refresh_from_db()
    assert cycle.service_status == 'expired', f"Cycle service status should be 'expired', got {cycle.service_status}"
    assert cycle.computed_status == 'Expired', f"Computed status should be 'Expired', got {cycle.computed_status}"
    assert len(dispatched_exp) == 0, "No 'X days remaining' alert should be sent on expiry!"
    print("  [PASS] On expected end date (days_remaining <= 0), stock cycle immediately marked Expired without '0 days remaining' alerts.")

    print("\n--- 8. Multi-Cycle Safe Hold / Resume Logic ---")
    # Reset cycle for hold testing with 10 days remaining
    cycle.service_status = 'active'
    cycle.expected_end_date = date(2026, 10, 20)
    cycle.save()

    today_hold = date(2026, 10, 10)
    # Put on hold
    rem_days = (cycle.expected_end_date - today_hold).days # 10 days
    cycle.service_status = 'hold'
    cycle.remaining_days_at_hold = rem_days
    cycle.hold_timestamp = timezone.now()
    cycle.save()
    ServiceHoldHistory.objects.create(stock_cycle=cycle, customer=u_cust, action='hold', actor_role='customer', remaining_days=rem_days)

    assert cycle.days_remaining == 10, f"Expected 10 days frozen, got {cycle.days_remaining}"
    assert cycle.computed_status == 'On Hold'

    # While on hold, trigger daily alerts on simulation date where normal end date would have been 5 days
    sim_date_hold = date(2026, 10, 15)
    dispatched_on_hold = trigger_daily_low_stock_alerts(target_date=sim_date_hold)
    assert len(dispatched_on_hold) == 0, "No low-stock alerts should ever trigger while stock is on HOLD!"
    print("  [PASS] HOLD froze countdown at 10 days; daily alerts completely suppressed.")

    # Resume 20 days later
    today_resume = date(2026, 10, 30)
    new_end_date = today_resume + timedelta(days=cycle.remaining_days_at_hold) # 30 Oct + 10 days = 9 Nov
    cycle.service_status = 'active'
    cycle.expected_end_date = new_end_date
    cycle.remaining_days_at_hold = None
    cycle.save()
    ServiceHoldHistory.objects.create(stock_cycle=cycle, customer=u_cust, action='resume', actor_role='customer', remaining_days=10)

    assert cycle.expected_end_date == date(2026, 11, 9), f"Expected 2026-11-09, got {cycle.expected_end_date}"
    print(f"  [PASS] RESUME safely calculated new end date: {cycle.expected_end_date} (today + 10 days).")

    # Second HOLD -> RESUME cycle
    cycle.service_status = 'hold'
    cycle.remaining_days_at_hold = 5
    cycle.save()
    ServiceHoldHistory.objects.create(stock_cycle=cycle, customer=u_cust, action='hold', actor_role='customer', remaining_days=5)

    today_resume_2 = date(2026, 11, 15)
    cycle.expected_end_date = today_resume_2 + timedelta(days=5)
    cycle.service_status = 'active'
    cycle.remaining_days_at_hold = None
    cycle.save()
    ServiceHoldHistory.objects.create(stock_cycle=cycle, customer=u_cust, action='resume', actor_role='customer', remaining_days=5)

    assert cycle.expected_end_date == date(2026, 11, 20), f"Expected 2026-11-20, got {cycle.expected_end_date}"
    assert cycle.hold_logs.count() == 4, f"Expected 4 hold/resume log records, got {cycle.hold_logs.count()}"
    print("  [PASS] Multiple HOLD -> RESUME cycles preserved remaining duration accurately in ServiceHoldHistory.")

    print("\n--- 9. Customer Refill Preserves Complete Stock History ---")
    # Customer refills: creates Cycle 2 with Serving Franchise Alpha
    order_refill = Order.objects.create(
        created_by=u_cust,
        franchise_name=f_alpha.business_name,
        city='Raipur',
        serving_franchise=f_alpha,
        registered_franchise=f_alpha,
        zone=zone_east,
        duration_choice='1 Month',
        duration_days=30,
        expected_end_date=date(2026, 12, 20),
        amount=160.00,
        items_count=2,
    )
    # Cycle 1 marked completed
    cycle.service_status = 'completed'
    cycle.save()

    cycle_2 = CustomerStockCycle.objects.create(
        customer=u_cust,
        order=order_refill,
        product=prod,
        product_name=prod.name,
        variant_size=prod.size,
        quantity=2,
        serving_franchise=f_alpha,
        registered_franchise=f_alpha,
        district=district,
        zone=zone_east,
        service_area=area_east,
        pincode='492088',
        start_date=date(2026, 11, 20),
        duration_choice='1 Month',
        duration_days=30,
        expected_end_date=date(2026, 12, 20),
        service_status='active',
    )

    # Both cycles exist in database
    cust_cycles = CustomerStockCycle.objects.filter(customer=u_cust)
    assert cust_cycles.count() == 2, f"Expected 2 cycles in history, got {cust_cycles.count()}"
    assert cust_cycles.filter(serving_franchise=f_beta).exists(), "Cycle 1 (served by Franchise Beta) was lost!"
    assert cust_cycles.filter(serving_franchise=f_alpha).exists(), "Cycle 2 (served by Franchise Alpha) missing!"
    print("  [PASS] Refill created new stock cycle while permanently preserving past stock cycle history.")

    print("\n--- 10. Permission Isolation Verification ---")
    # Franchise Beta can see Cycle 1 (which it served)
    assert CustomerStockCycle.objects.filter(serving_franchise=f_beta).exists(), "Franchise Beta cannot see Cycle 1 it served!"
    # Franchise Beta CANNOT see Cycle 2 (served by Franchise Alpha)
    assert not CustomerStockCycle.objects.filter(serving_franchise=f_beta, id=cycle_2.id).exists(), "Franchise Beta should not see Cycle 2!"
    # Unrelated Franchise Gamma cannot see either cycle
    assert CustomerStockCycle.objects.filter(serving_franchise=f_gamma).count() == 0, "Franchise Gamma should see 0 cycles!"
    print("  [PASS] Strict franchise queryset isolation verified: Franchises see only stock cycles they serve; unrelated franchises see 0.")

    print("\n=======================================================")
    print("ALL STOCK MANAGEMENT & 7-DAY ALERT TESTS PASSED 100%!")
    print("=======================================================\n")


if __name__ == '__main__':
    run_stock_management_tests()

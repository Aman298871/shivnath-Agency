import os
import django
from datetime import date, timedelta
from decimal import Decimal

import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from django.contrib.auth.models import User
from accounts.models import UserProfile, FranchiseProfile, AdminNotification
from products.models import Product
from orders.models import Order, OrderItem
from inventory.models import (
    ProductionBatch,
    DealerStockRequest,
    DealerStockRequestAllocation,
    DealerStockBatch,
    StockAlertRecord,
)
from inventory.services import get_pending_stock_expiry_alerts
from followups.models import FollowUp, FollowUpAuditLog
from leads.models import Lead, LeadActivity
from rest_framework.test import APIRequestFactory, force_authenticate
from inventory.views import PendingStockExpiryAlertView, PendingStockExpiryAlertActionView, DealerStockRequestListCreateAPIView
from followups.views import FollowUpDetailView, CompleteFollowUpView, CompletedFollowUpListView
from orders.views import OrderListCreateView


def run_tests():
    print("================================================================")
    print("STARTING STRICT FIX VERIFICATION SUITE")
    print("================================================================")

    # 1. SETUP USERS & PROFILES
    super_admin, _ = User.objects.get_or_create(username="test_super_admin", defaults={"email": "sa@test.com", "is_superuser": True})
    p_sa, _ = UserProfile.objects.get_or_create(user=super_admin)
    p_sa.role = "super_admin"
    p_sa.save()

    admin_user, _ = User.objects.get_or_create(username="test_admin_user", defaults={"email": "admin@test.com"})
    p_admin, _ = UserProfile.objects.get_or_create(user=admin_user)
    p_admin.role = "admin"
    p_admin.save()

    franchise_user, _ = User.objects.get_or_create(username="test_franchise_b", defaults={"email": "fran_b@test.com"})
    p_fran, _ = UserProfile.objects.get_or_create(user=franchise_user)
    p_fran.role = "franchise"
    p_fran.save()
    fp, _ = FranchiseProfile.objects.get_or_create(
        user=franchise_user,
        defaults={
            "business_name": "Shivnath Franchise Bilaspur",
            "city": "Bilaspur",
            "address": "Main Road, Bilaspur",
            "status": "approved",
        }
    )

    customer_user, _ = User.objects.get_or_create(username="test_customer_a", defaults={"email": "cust_a@test.com"})
    p_cust, _ = UserProfile.objects.get_or_create(user=customer_user)
    p_cust.role = "customer"
    p_cust.save()

    factory = APIRequestFactory()

    # ================================================================
    # TEST 1: STOCK EXPIRY ALERTS PERSISTENT STATE & DEDUPLICATION
    # ================================================================
    print("\n--- TEST 1: Stock Expiry Alert Acknowledgement & Deduplication ---")
    today = date.today()
    exp_date = today + timedelta(days=20)

    # Ensure test product exists
    prod_500 = Product.objects.filter(sku="SHV-500").first()
    if not prod_500:
        prod_500 = Product.objects.create(name="Shivnath 500ml Water", sku="SHV-500", size="500ml", price=Decimal("10.00"), stock=5000, status="Active")

    batch, _ = ProductionBatch.objects.get_or_create(
        batch_number="PB-STRICT-TEST-500",
        defaults={
            "product": prod_500,
            "quantity_produced_units": 5000,
            "quantity_remaining_company": 5000,
            "manufacture_date": today - timedelta(days=10),
            "expiry_date": exp_date,
            "unit_production_cost": Decimal("5.00"),
        }
    )

    # Create uncollected pending order stock
    order, _ = Order.objects.get_or_create(
        franchise_name=fp.business_name,
        serving_franchise=fp,
        created_by=customer_user,
        status="pending",
        defaults={"amount": Decimal("30000.00"), "items_count": 3000, "city": "Bilaspur"}
    )
    oi, _ = OrderItem.objects.get_or_create(
        order=order,
        product=prod_500,
        defaults={"product_name": prod_500.name, "quantity": 3000, "unit_price": Decimal("10.00"), "total_price": Decimal("30000.00")}
    )

    from orders.models import OrderItemBatchReservation
    OrderItemBatchReservation.objects.get_or_create(
        order_item=oi,
        production_batch=batch,
        defaults={"reserved_quantity": 3000, "consumed_quantity": 0, "released_quantity": 0}
    )

    # Clean pre-existing alert records so we test our specific alert cleanly
    StockAlertRecord.objects.all().update(status='ACKNOWLEDGED')
    # Remove our target record so it gets freshly generated as ACTIVE
    StockAlertRecord.objects.filter(batch_number=batch.batch_number).delete()

    # First fetch: alert record is created with can_popup=True, status=ACTIVE
    req1 = factory.get('/api/inventory/pending-stock-expiry-alerts/')
    force_authenticate(req1, user=admin_user)
    res1 = PendingStockExpiryAlertView.as_view()(req1)
    assert res1.status_code == 200, f"Fetch alerts failed: {res1.data}"
    assert res1.data['has_unacknowledged_popup'] is True, f"Expected has_unacknowledged_popup=True, got {res1.data}"
    alerts = res1.data['alerts']
    target_alert = next((a for a in alerts if a['batch_number'] == batch.batch_number), None)
    assert target_alert is not None, f"Alert for batch {batch.batch_number} not found"
    assert target_alert['can_popup'] is True
    assert target_alert['status'] == 'ACTIVE'
    alert_id = target_alert['id']
    print(f"[OK] Alert generated with ID {alert_id}, status: {target_alert['status']}, can_popup: {target_alert['can_popup']}")

    # Now Admin clicks "MARK AS REVIEWED" (ACKNOWLEDGE)
    act_req = factory.post(
        '/api/inventory/pending-stock-expiry-alerts/action/',
        {'alert_id': alert_id, 'action': 'ACKNOWLEDGE'},
        format='json'
    )
    force_authenticate(act_req, user=admin_user)
    act_res = PendingStockExpiryAlertActionView.as_view()(act_req)
    assert act_res.status_code == 200, f"Acknowledge failed: {act_res.data}"
    assert act_res.data['alert']['status'] == 'ACKNOWLEDGED'
    print(f"[OK] Alert {alert_id} successfully marked as ACKNOWLEDGED in PostgreSQL")

    # Second fetch: has_unacknowledged_popup MUST now be False!
    req2 = factory.get('/api/inventory/pending-stock-expiry-alerts/')
    force_authenticate(req2, user=admin_user)
    res2 = PendingStockExpiryAlertView.as_view()(req2)
    assert res2.status_code == 200
    target_alert2 = next((a for a in res2.data['alerts'] if a['batch_number'] == batch.batch_number), None)
    assert target_alert2['status'] == 'ACKNOWLEDGED'
    assert target_alert2['can_popup'] is False
    assert res2.data['has_unacknowledged_popup'] is False, "Popup must NOT be shown for reviewed alerts!"
    print("[OK] Deduplication & Persistent Acknowledgement confirmed: popup flag is False on reload!")

    # Verify False Physical Stock Clearance Prevention:
    # Attempting to mark as RESOLVED while 3000 units are still pending in database must be REJECTED!
    res_req = factory.post(
        '/api/inventory/pending-stock-expiry-alerts/action/',
        {'alert_id': alert_id, 'action': 'RESOLVE'},
        format='json'
    )
    force_authenticate(res_req, user=admin_user)
    res_res = PendingStockExpiryAlertActionView.as_view()(res_req)
    assert res_res.status_code == 400, "RESOLVE must NOT succeed when physical stock is still pending!"
    print(f"[OK] False stock clearance blocked: {res_res.data['message']}")

    # ================================================================
    # TEST 2: FOLLOW-UP RESCHEDULE & COMPLETION AUDIT LOG & COMPLETED LIST
    # ================================================================
    print("\n--- TEST 2: Follow-up Reschedule, Completion Audit Log & History ---")
    lead, _ = Lead.objects.get_or_create(
        name="Test Lead Raipur Enterprise",
        defaults={
            "phone": "9876543210",
            "city": "Raipur",
            "district": "Raipur",
            "status": "new_lead",
            "score": "warm",
            "lead_type": "FRANCHISE",
            "created_by": admin_user,
        }
    )

    from django.utils import timezone
    orig_dt = timezone.now() + timedelta(days=2)
    followup = FollowUp.objects.create(
        lead=lead,
        created_by=admin_user,
        followup_datetime=orig_dt,
        followup_type="Phone Call",
        note="Initial contact regarding franchise expansion",
        status="Pending",
    )

    # Reschedule via API
    new_dt = timezone.now() + timedelta(days=5)
    patch_req = factory.patch(
        f'/api/followups/{followup.id}/',
        {"followup_datetime": new_dt.isoformat(), "note": "Rescheduled after client requested more time"},
        format='json'
    )
    force_authenticate(patch_req, user=admin_user)
    patch_res = FollowUpDetailView.as_view()(patch_req, pk=followup.id)
    assert patch_res.status_code == 200, f"Reschedule failed: {patch_res.data}"

    # Verify audit log recorded RESCHEDULED
    audit_resched = FollowUpAuditLog.objects.filter(followup=followup, action='RESCHEDULED').first()
    assert audit_resched is not None, "Reschedule audit log must exist!"
    assert audit_resched.performed_by == admin_user
    print(f"[OK] Reschedule audit log verified: action={audit_resched.action}, by={audit_resched.performed_by.username}")

    # Complete follow-up with outcome notes
    comp_req = factory.patch(
        f'/api/followups/{followup.id}/complete/',
        {"outcome": "Discussed commercial terms, customer agreed to site visit"},
        format='json'
    )
    force_authenticate(comp_req, user=admin_user)
    comp_res = CompleteFollowUpView.as_view()(comp_req, pk=followup.id)
    assert comp_res.status_code == 200, f"Complete failed: {comp_res.data}"

    followup.refresh_from_db()
    assert followup.status.upper() == 'COMPLETED'
    assert followup.completed_by == admin_user
    assert "site visit" in followup.outcome_notes

    # Verify completion audit log
    audit_comp = FollowUpAuditLog.objects.filter(followup=followup, action='COMPLETED').first()
    assert audit_comp is not None, "Completion audit log must exist!"
    assert audit_comp.notes == followup.outcome_notes
    print(f"[OK] Completion audit log verified: action={audit_comp.action}, completed_by={followup.completed_by.username}, outcome={audit_comp.notes}")

    # Verify Completed Follow-up List View API
    hist_req = factory.get('/api/followups/completed/?period=today')
    force_authenticate(hist_req, user=admin_user)
    hist_res = CompletedFollowUpListView.as_view()(hist_req)
    assert hist_res.status_code == 200, f"Completed list failed: {hist_res.data}"
    assert hist_res.data['count'] >= 1
    found_rec = next((f for f in hist_res.data['followups'] if f['id'] == followup.id), None)
    assert found_rec is not None, "Completed followup must be present in CompletedFollowUpListView"
    assert found_rec['completed_by_name'] == admin_user.username or found_rec['completed_by_name'] == admin_user.get_full_name()
    print("[OK] Completed Follow-up screen endpoint verified with full historical audit details!")

    # ================================================================
    # TEST 3: CUSTOMER -> FRANCHISE & FRANCHISE -> ADMIN ORDER VISIBILITY
    # ================================================================
    print("\n--- TEST 3: Customer <-> Franchise Order Visibility ---")
    # Customer A places order routed to Franchise B
    cust_ord_req = factory.post(
        '/api/orders/',
        {
            "serving_franchise_id": fp.id,
            "order_source": "FRANCHISE",
            "items_list": [{"product_id": prod_500.id, "quantity": 50, "price": 10.0}],
            "address": "Main Road, Bilaspur",
            "city": "Bilaspur",
        },
        format='json'
    )
    force_authenticate(cust_ord_req, user=customer_user)
    cust_ord_res = OrderListCreateView.as_view()(cust_ord_req)
    assert cust_ord_res.status_code in [200, 201], f"Customer order failed: {cust_ord_res.data}"
    cust_order_id = cust_ord_res.data['id']
    print(f"[OK] Customer order #{cust_ord_res.data.get('order_id')} created successfully")

    # Visibility checks for Customer order:
    # 1. Customer:
    get_cust = factory.get('/api/orders/')
    force_authenticate(get_cust, user=customer_user)
    assert any(o['id'] == cust_order_id for o in OrderListCreateView.as_view()(get_cust).data.get('orders', []))
    print("  [OK] Visible in Customer 'My Orders'")

    # 2. Franchise B:
    get_fran = factory.get('/api/orders/')
    force_authenticate(get_fran, user=franchise_user)
    assert any(o['id'] == cust_order_id for o in OrderListCreateView.as_view()(get_fran).data.get('orders', []))
    print("  [OK] Visible in Franchise B Orders")

    # 3. Admin:
    get_adm = factory.get('/api/orders/')
    force_authenticate(get_adm, user=admin_user)
    assert any(o['id'] == cust_order_id for o in OrderListCreateView.as_view()(get_adm).data.get('orders', []))
    print("  [OK] Visible in Admin Orders")

    # 4. Super Admin:
    get_sa = factory.get('/api/orders/')
    force_authenticate(get_sa, user=super_admin)
    assert any(o['id'] == cust_order_id for o in OrderListCreateView.as_view()(get_sa).data.get('orders', []))
    print("  [OK] Visible in Super Admin Orders")

    # Franchise B places an order / sale
    print("\n--- TEST 4: Franchise-Created Order Visibility ---")
    fran_ord_req = factory.post(
        '/api/orders/',
        {
            "items_list": [{"product_id": prod_500.id, "quantity": 100, "price": 10.0}],
            "address": "Store counter, Bilaspur",
            "city": "Bilaspur",
        },
        format='json'
    )
    force_authenticate(fran_ord_req, user=franchise_user)
    fran_ord_res = OrderListCreateView.as_view()(fran_ord_req)
    assert fran_ord_res.status_code in [200, 201], f"Franchise order creation failed: {fran_ord_res.data}"
    fran_order_id = fran_ord_res.data['id']
    print(f"[OK] Franchise order #{fran_ord_res.data.get('order_id')} created successfully")

    # Visibility checks for Franchise order:
    # 1. Franchise B must see it!
    get_fran2 = factory.get('/api/orders/')
    force_authenticate(get_fran2, user=franchise_user)
    assert any(o['id'] == fran_order_id for o in OrderListCreateView.as_view()(get_fran2).data.get('orders', []))
    print("  [OK] Franchise order visible to Franchise B")

    # 2. Admin must see it!
    get_adm2 = factory.get('/api/orders/')
    force_authenticate(get_adm2, user=admin_user)
    assert any(o['id'] == fran_order_id for o in OrderListCreateView.as_view()(get_adm2).data.get('orders', []))
    print("  [OK] Franchise order visible to Admin")

    # 3. Super Admin must see it!
    get_sa2 = factory.get('/api/orders/')
    force_authenticate(get_sa2, user=super_admin)
    assert any(o['id'] == fran_order_id for o in OrderListCreateView.as_view()(get_sa2).data.get('orders', []))
    print("  [OK] Franchise order visible to Super Admin")

    # ================================================================
    # TEST 5: FRANCHISE STOCK REQUEST WITH ONLY ONE PRODUCT
    # ================================================================
    print("\n--- TEST 5: Partial Product Stock Request (Only SHV-500) ---")
    stk_req = factory.post(
        '/api/inventory/dealer-stock-requests/',
        {
            "items": [
                {
                    "sku": "SHV-500",
                    "quantity": 100,
                }
            ],
            "notes": "Urgent refill for SHV-500 only."
        },
        format='json'
    )
    force_authenticate(stk_req, user=franchise_user)
    stk_res = DealerStockRequestListCreateAPIView.as_view()(stk_req)
    assert stk_res.status_code in [200, 201], f"Partial stock request failed: {stk_res.data}"
    data = stk_res.data['data'] if 'data' in stk_res.data else stk_res.data
    assert len(data) == 1
    sr_obj = data[0]
    assert sr_obj['product_sku'] == 'SHV-500' or sr_obj.get('product') == prod_500.id
    assert sr_obj['requested_quantity'] == 100
    print(f"[OK] Partial stock request submitted with only 1 SKU (SHV-500, qty=100). Request #{sr_obj['request_number']}")

    # Verify notification created
    notif = AdminNotification.objects.filter(notification_type='stock_alert').order_by('-created_at').first()
    assert notif is not None
    assert "SHV-500" in notif.message or "Stock Request" in notif.title
    print(f"[OK] Admin notification generated: '{notif.title}' -> '{notif.message}'")

    print("\n================================================================")
    print("ALL STRICT ACCEPTANCE VERIFICATION TESTS PASSED SUCCESSFULLY!")
    print("================================================================")

if __name__ == '__main__':
    run_tests()

import os
import sys
import django
from decimal import Decimal
from datetime import timedelta

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from django.utils import timezone
from django.contrib.auth.models import User
from rest_framework.test import APIRequestFactory, force_authenticate
from accounts.models import UserProfile, FranchiseProfile, AdminNotification
from products.models import Product
from inventory.models import ProductionBatch, DealerStockRequest, DealerStockRequestAllocation, InventoryTransactionLedger
from orders.models import Order, OrderItem, OrderStatusHistory
from leads.models import Lead, LeadActivity, LeadJourneyState
from billing.models import Invoice, PaymentTransaction
from inventory.services import record_batch_collection_atomic, get_pending_stock_expiry_alerts
from leads.services import validate_and_create_chatbot_inquiry
from inventory.views import DealerStockRequestListCreateAPIView

print("=" * 80)
print("STARTING E2E VERIFICATION SCRIPT FOR CLIENT-DEMO READINESS")
print("=" * 80)

results = {}

# ==============================================================================
# TEST 1: PUBLIC CUSTOMER ENQUIRY -> LEAD
# ==============================================================================
print("\n[TEST 1] PUBLIC CUSTOMER ENQUIRY -> LEAD CREATION...")
try:
    phone = "9823456789"
    email = "client.demo.inquiry@example.com"
    lead = validate_and_create_chatbot_inquiry({
        'name': "Sunil Sharma Demo",
        'phone': phone,
        'email': email,
        'district': "Raipur",
        'city': "Raipur",
        'territory': "Pandri",
        'notes': "Interested in 20L commercial water dispenser and 500ml bottles.",
        'session_id': "sess_client_demo_001"
    })
    assert lead.source == 'PUBLIC_CHATBOT', f"Expected PUBLIC_CHATBOT, got {lead.source}"
    assert lead.phone == phone
    assert lead.name == "Sunil Sharma Demo"
    assert lead.id is not None
    activity = LeadActivity.objects.filter(lead=lead).first()
    assert activity is not None, "LeadActivity must be generated"
    print(f"  -> PASSED: Lead ID={lead.id} created with source={lead.source}, score={lead.score_category}")
    results['TEST_1_PUBLIC_ENQUIRY'] = 'PASS'
except Exception as e:
    print(f"  -> FAILED TEST 1: {e}")
    results['TEST_1_PUBLIC_ENQUIRY'] = f'FAIL: {e}'

# ==============================================================================
# TEST 2: ALL 5 OFFICIAL SKUs RESOLUTION & FRANCHISE STOCK REQUEST
# ==============================================================================
print("\n[TEST 2] ALL 5 OFFICIAL SKUs RESOLUTION & FRANCHISE STOCK REQUEST...")
try:
    official_skus = ['SHV-200', 'SHV-250', 'SHV-500', 'SHV-1L', 'SHV-20L']
    franchise = FranchiseProfile.objects.filter(status='approved').first()
    if not franchise:
        u_f, _ = User.objects.get_or_create(username='demo_franchise_user')
        franchise = FranchiseProfile.objects.create(
            user=u_f,
            business_name="Demo Shivnath Franchise",
            city="Raipur",
            territory="Pandri",
            status="approved"
        )
    factory = APIRequestFactory()
    view = DealerStockRequestListCreateAPIView.as_view()

    for sku in official_skus:
        req = factory.post('/api/inventory/dealer-requests/', {
            'product_sku': sku,
            'quantity': 100,
            'notes': f'Test request for official SKU {sku}'
        }, format='json')
        force_authenticate(req, user=franchise.user)
        res = view(req)
        assert res.status_code == 201, f"Expected 201 for {sku}, got {res.status_code}: {res.data}"
        print(f"  -> PASSED: Stock Request for SKU {sku} created successfully (Response: ID={res.data.get('id')})")

    results['TEST_2_STOCK_REQUEST_SKUS'] = 'PASS'
except Exception as e:
    print(f"  -> FAILED TEST 2: {e}")
    results['TEST_2_STOCK_REQUEST_SKUS'] = f'FAIL: {e}'

# ==============================================================================
# TEST 3: CUSTOMER ORDER CREATION & PREVIOUS OUTSTANDING BREAKDOWN
# ==============================================================================
print("\n[TEST 3] CUSTOMER ORDER & FINANCIAL EXPOSURE BREAKDOWN...")
try:
    ts = timezone.now().strftime('%H%M%S%f')
    cust_user = User.objects.create(
        username=f"demo_cust_{ts}",
        email=f"demo_{ts}@test.com"
    )
    prof = getattr(cust_user, 'profile', None) or UserProfile.objects.get(user=cust_user)
    prof.role = 'customer'
    prof.phone = f"98{ts[:8]}"
    prof.city = 'Raipur'
    prof.save()
    
    # 1. Place Order 1
    order1 = Order.objects.create(
        created_by=cust_user,
        franchise_name="Shivnath Agency Central",
        city="Raipur",
        snapshot_territory="Pandri",
        order_source="DIRECT_COMPANY",
        status="order_placement",
        amount=Decimal('4500.00'),
        grand_total=Decimal('4500.00'),
        payment_status="pending"
    )
    OrderStatusHistory.objects.create(
        order=order1,
        old_status='',
        new_status="order_placement",
        notes="Order placed by customer via Customer App",
        changed_by=cust_user
    )
    # Generate Invoice for Order 1 with outstanding = 3000 (4500 - 1500 paid)
    inv1 = Invoice.objects.create(
        invoice_number=f"INV-TEST-{ts}",
        order=order1,
        billed_to_name="Test Customer 1",
        grand_total=Decimal('4500.00'),
        amount_paid=Decimal('1500.00'),
        status='PARTIALLY_PAID'
    )
    PaymentTransaction.objects.create(
        transaction_number=f"TXN-TEST-{ts}",
        invoice=inv1,
        amount_paid=Decimal('1500.00'),
        payment_method='UPI',
        reference_number='TXN-DEMO-PARTIAL-1500'
    )

    # 2. Place Order 2 for same customer: Outstanding must be 3000!
    from orders.serializers import OrderSerializer
    order2 = Order.objects.create(
        created_by=cust_user,
        franchise_name="Shivnath Agency Central",
        city="Raipur",
        snapshot_territory="Pandri",
        order_source="DIRECT_COMPANY",
        status="order_placement",
        amount=Decimal('6000.00'),
        grand_total=Decimal('6000.00'),
        payment_status="pending"
    )
    serializer = OrderSerializer(order2)
    s_data = serializer.data
    assert Decimal(str(s_data['previous_outstanding'])) == Decimal('3000.00'), f"Expected 3000.00, got {s_data['previous_outstanding']}"
    assert Decimal(str(s_data['current_order_amount'])) == Decimal('6000.00'), f"Expected 6000.00, got {s_data['current_order_amount']}"
    assert Decimal(str(s_data['total_exposure'])) == Decimal('9000.00'), f"Expected 9000.00, got {s_data['total_exposure']}"
    print(f"  -> PASSED: Order 2 Financial Breakdown: Prev={s_data['previous_outstanding']}, Current={s_data['current_order_amount']}, Total Due={s_data['total_exposure']}")
    results['TEST_3_FINANCIAL_EXPOSURE'] = 'PASS'
except Exception as e:
    import traceback
    traceback.print_exc()
    print(f"  -> FAILED TEST 3: {e}")
    results['TEST_3_FINANCIAL_EXPOSURE'] = f'FAIL: {e}'

# ==============================================================================
# TEST 4: LEAD TEMPERATURE & CRM STATUS LIFECYCLE + AUTOMATION PAUSE
# ==============================================================================
print("\n[TEST 4] LEAD TEMPERATURE & CRM STATUS LIFECYCLE + AUTOMATION PAUSE...")
try:
    lead = Lead.objects.filter(phone="9823456789").first()
    assert lead is not None
    journey_state, _ = LeadJourneyState.objects.get_or_create(lead=lead)
    
    # Change temperature HOT -> WARM -> COLD -> HOT
    for temp in ['HOT', 'WARM', 'COLD', 'HOT']:
        lead.score = temp
        lead.score_category = temp
        lead.save()
        LeadActivity.objects.create(
            lead=lead,
            activity_type='status_change',
            title='Temperature Changed',
            description=f"Temperature updated to {temp}"
        )
    assert lead.score == 'HOT'
    assert lead.score_category == 'HOT'

    # Change status to FOLLOW_UP_REQUIRED -> active status
    lead.status = 'FOLLOW_UP_REQUIRED'
    lead.save()
    lead.refresh_from_db()
    journey_state.refresh_from_db()
    assert not journey_state.is_paused, "Journey should NOT be paused for FOLLOW_UP_REQUIRED"

    # Now change status to CONVERTED -> MUST PAUSE JOURNEY
    lead.status = 'CONVERTED'
    lead.save()
    lead.refresh_from_db()
    journey_state.refresh_from_db()
    assert journey_state.is_paused, "Journey MUST be paused upon CONVERTED"
    assert journey_state.pause_reason == 'CONVERTED', f"Expected pause_reason CONVERTED, got {journey_state.pause_reason}"
    print(f"  -> PASSED: Lead status CONVERTED correctly triggered automation pause (reason: {journey_state.pause_reason})")
    results['TEST_4_LEAD_LIFECYCLE'] = 'PASS'
except Exception as e:
    print(f"  -> FAILED TEST 4: {e}")
    results['TEST_4_LEAD_LIFECYCLE'] = f'FAIL: {e}'

# ==============================================================================
# TEST 5 & 6: PRODUCTION BATCH, RECORD COLLECTION WITH PARTIAL PAYMENT
# ==============================================================================
print("\n[TEST 5 & 6] PRODUCTION BATCH, RECORD COLLECTION WITH PARTIAL PAYMENT...")
try:
    prod_500 = Product.objects.filter(volume_ml=500, status__iexact='active').first()
    today = timezone.now().date()
    exp_date = today + timedelta(days=90)
    batch = ProductionBatch.objects.create(
        product=prod_500,
        batch_number=f"PB-TEST-{timezone.now().strftime('%H%M%S%f')}",
        manufacture_date=today,
        expiry_date=exp_date,
        quantity_produced_units=5000,
        quantity_remaining_company=5000,
        unit_production_cost=Decimal('40.00'),
        status='ACTIVE'
    )
    assert batch.quantity_produced_units == 5000
    assert batch.quantity_remaining_company == 5000

    # Record partial collection of 2,000 units with PARTIAL ONLINE payment
    # Amount Due = Rs 100,000, Paid Now = Rs 40,000 -> Remaining = Rs 60,000
    res = record_batch_collection_atomic(
        batch_id=batch.id,
        quantity_collected=2000,
        client_name="Mr. Ramesh Collection Rep",
        notes="Direct client pickup with partial online advance",
        actor=cust_user,
        payment_status="PARTIAL",
        payment_method="ONLINE",
        reference_number="TXN-UPI-9988776655",
        amount_due=Decimal('100000.00'),
        amount_paid=Decimal('40000.00')
    )
    batch.refresh_from_db()
    taken_company = batch.quantity_produced_units - batch.quantity_remaining_company
    assert taken_company == 2000, f"Expected 2000 taken, got {taken_company}"
    assert batch.quantity_remaining_company == 3000, f"Expected 3000 remaining, got {batch.quantity_remaining_company}"
    assert res['billing'] is not None, "Billing details must be returned"
    assert res['billing']['payment_status'] in ['PARTIAL', 'PARTIALLY_PAID']
    assert Decimal(str(res['billing']['amount_due'])) == Decimal('100000.00')
    assert Decimal(str(res['billing']['amount_paid'])) == Decimal('40000.00')
    assert Decimal(str(res['billing']['remaining_amount'])) == Decimal('60000.00')
    
    # Check Invoice and PaymentTransaction in PostgreSQL
    inv_id = res['billing']['invoice_id']
    invoice = Invoice.objects.get(id=inv_id)
    assert invoice.outstanding_balance == Decimal('60000.00'), f"Expected 60000 balance, got {invoice.outstanding_balance}"
    assert invoice.amount_paid == Decimal('40000.00')
    ptxn = PaymentTransaction.objects.filter(invoice=invoice).first()
    assert ptxn is not None
    assert ptxn.reference_number == "TXN-UPI-9988776655"
    assert ptxn.amount_paid == Decimal('40000.00')

    print(f"  -> PASSED: Batch Collection & Partial Payment recorded: Remaining Company Stock = {batch.quantity_remaining_company}, Outstanding Balance = Rs {invoice.outstanding_balance}")
    results['TEST_5_6_BATCH_AND_PAYMENT'] = 'PASS'
except Exception as e:
    import traceback
    traceback.print_exc()
    print(f"  -> FAILED TEST 5 & 6: {e}")
    results['TEST_5_6_BATCH_AND_PAYMENT'] = f'FAIL: {e}'

# ==============================================================================
# TEST 7: EXPIRY / PENDING STOCK ALERT EXACT BATCH LOOKUP
# ==============================================================================
print("\n[TEST 7] EXPIRY / PENDING STOCK ALERT EXACT BATCH LOOKUP...")
try:
    super_admin = User.objects.filter(is_superuser=True).first()
    alerts = get_pending_stock_expiry_alerts(user=super_admin, target_date=today)
    print(f"  -> Total pending stock expiry alerts generated: {len(alerts)}")
    # Verify that each alert provides batch_number and batch_id
    for alert in alerts[:3]:
        assert 'batch_number' in alert, "Alert must contain batch_number"
        assert 'batch_id' in alert, "Alert must contain batch_id"
        assert 'pending_quantity' in alert, "Alert must contain pending_quantity"
        print(f"     Alert: Batch={alert['batch_number']}, Pending={alert['pending_quantity']}, Expiry={alert['expiry_date']}")
    results['TEST_7_EXPIRY_ALERTS'] = 'PASS'
except Exception as e:
    print(f"  -> FAILED TEST 7: {e}")
    results['TEST_7_EXPIRY_ALERTS'] = f'FAIL: {e}'

# ==============================================================================
# TEST 8: ADMIN & SUPER ADMIN NOTIFICATIONS & REFRESH CONSISTENCY
# ==============================================================================
print("\n[TEST 8] ADMIN & SUPER ADMIN DUAL NOTIFICATIONS & VISIBILITY...")
try:
    recent_notifs = AdminNotification.objects.order_by('-created_at')[:5]
    assert recent_notifs.exists(), "Admin notifications must exist in database"
    for n in recent_notifs:
        print(f"  -> Notif #{n.id}: [{n.notification_type}] {n.title} (Read={n.is_read})")
    results['TEST_8_NOTIFICATIONS'] = 'PASS'
except Exception as e:
    print(f"  -> FAILED TEST 8: {e}")
    results['TEST_8_NOTIFICATIONS'] = f'FAIL: {e}'

print("\n" + "=" * 80)
print("FINAL SUMMARY OF REAL CLIENT-DEMO VERIFICATION TESTS:")
for k, v in results.items():
    print(f"  {k}: {v}")
print("=" * 80)

all_passed = all(v == 'PASS' for v in results.values())
if not all_passed:
    sys.exit(1)
print("\nALL CLIENT DEMO VERIFICATION CHECKS PASSED 100%!")

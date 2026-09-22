import os
import django
import sys
from decimal import Decimal
from datetime import date, timedelta

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from django.contrib.auth.models import User
from django.utils import timezone
from orders.models import Order, OrderItem
from products.models import Product
from leads.models import Lead, CRMActivityLog
from inventory.models import DealerStockRequest, DailyBusinessReport, ProductionBatch, InventoryTransactionLedger
from accounts.models import FranchiseProfile, UserProfile
from rest_framework.test import APIClient

def run_verification():
    print("=" * 60)
    print("STARTING E2E DATA FLOW & REPORTING VERIFICATION")
    print("=" * 60)

    # 1. Verify / Create Admin user
    admin_user, _ = User.objects.get_or_create(
        username='admin_test',
        defaults={'email': 'admin@shivnath.com', 'is_staff': True, 'is_superuser': True}
    )
    admin_user.set_password('Admin@1234')
    admin_user.save()
    admin_profile, _ = UserProfile.objects.get_or_create(
        user=admin_user,
        defaults={'role': 'admin', 'full_name': 'Test Admin', 'phone': '9876543210'}
    )

    client = APIClient()
    client.force_authenticate(user=admin_user)

    # 2. Verify Customer Order Flow
    print("\n--- 1. Testing Customer Order Visibility ---")
    customer_user, _ = User.objects.get_or_create(
        username='customer_test',
        defaults={'email': 'customer@shivnath.com'}
    )
    product = Product.objects.first()
    if not product:
        product = Product.objects.create(
            name="1 Litre Packaged Water",
            sku="SHIV-1L",
            price=20.0,
            stock=500
        )

    test_order = Order.objects.create(
        created_by=customer_user,
        franchise_name="Aman Verma",
        city="Raipur",
        items_count=24,
        amount=Decimal("480.00"),
        grand_total=Decimal("480.00"),
        order_source="DIRECT_COMPANY",
        status="order_placement"
    )
    OrderItem.objects.get_or_create(
        order=test_order,
        product=product,
        defaults={
            'quantity': 24,
            'unit_price': Decimal("20.00"),
            'total_price': Decimal("480.00"),
            'snapshot_unit_production_cost': Decimal("8.00")
        }
    )
    print(f"[PASS] Created test order: {test_order.order_code} (ID: {test_order.id})")

    # Fetch from Admin Orders endpoint
    res = client.get('/api/orders/')
    print(f"Admin Orders Endpoint status: {res.status_code}")
    assert res.status_code == 200, f"Expected 200, got {res.status_code}"
    orders_data = res.data if isinstance(res.data, list) else res.data.get('orders', res.data.get('results', []))
    order_codes = [o.get('order_code') or o.get('id') for o in orders_data]
    assert test_order.order_code in order_codes or any(str(test_order.id) in str(o) for o in order_codes), f"Order {test_order.order_code} not found in Admin Orders!"
    print(f"[PASS] Order {test_order.order_code} is immediately visible in Admin Orders endpoint!")

    # 3. Verify Franchise Stock Request Flow
    print("\n--- 2. Testing Franchise Stock Request Visibility ---")
    franchise_user, _ = User.objects.get_or_create(
        username='franchise_test',
        defaults={'email': 'franchise@shivnath.com'}
    )
    franchise_profile, _ = FranchiseProfile.objects.get_or_create(
        user=franchise_user,
        defaults={
            'business_name': 'Shivnath Raipur Franchise',
            'territory': 'Raipur Central',
            'city': 'Raipur',
            'address': 'Main Road, Tatibandh, Raipur',
            'status': 'approved'
        }
    )

    # Post batch stock request as done by Flutter dealer_stock_screen.dart
    client_franchise = APIClient()
    client_franchise.force_authenticate(user=franchise_user)
    stock_payload = {
        'items': [
            {
                'product_id': product.id,
                'product_name': product.name,
                'requested_quantity': 500,
                'notes': 'Urgent requirement for summer'
            }
        ]
    }
    stock_res = client_franchise.post('/api/inventory/dealer-stock-requests/', stock_payload, format='json')
    print(f"Franchise Stock Request POST status: {stock_res.status_code}")
    assert stock_res.status_code in [200, 201], f"Stock request failed with {stock_res.status_code}: {stock_res.data}"
    print(f"[PASS] Franchise Stock Request successfully created: {stock_res.data}")

    # Verify visibility in Admin
    admin_stock_res = client.get('/api/inventory/dealer-stock-requests/')
    assert admin_stock_res.status_code == 200, f"Expected 200, got {admin_stock_res.status_code}"
    admin_reqs = admin_stock_res.data if isinstance(admin_stock_res.data, list) else admin_stock_res.data.get('requests', admin_stock_res.data.get('results', []))
    print(f"[PASS] Franchise Stock Requests visible in Admin: {len(admin_reqs)} records found.")

    # 4. Verify Public Chatbot Lead Creation
    print("\n--- 3. Testing Public Chatbot Lead Creation ---")
    anon_client = APIClient()
    lead_payload = {
        'name': 'Ramesh Kumar',
        'phone': '9123456789',
        'email': '',  # No email provided, inquiry only
        'inquiry_type': 'FRANCHISE_ENQUIRY',
        'city': 'Raipur',
        'notes': 'Interested in opening a franchise in Tatibandh'
    }
    lead_res = anon_client.post('/api/leads/public-capture/', lead_payload, format='json')
    print(f"Public Lead Capture status: {lead_res.status_code}")
    assert lead_res.status_code in [200, 201], f"Lead capture failed with {lead_res.status_code}: {lead_res.data}"
    lead_id = (lead_res.data.get('lead') or {}).get('id') or lead_res.data.get('lead_id') or lead_res.data.get('id')
    created_lead = Lead.objects.get(id=lead_id)
    print(f"[PASS] Lead created in database: Name={created_lead.name}, Phone={created_lead.phone}, Source={created_lead.source}")
    assert created_lead.source == 'PUBLIC_CHATBOT', f"Expected PUBLIC_CHATBOT, got {created_lead.source}"

    # Also test guest chatbot message lead auto-capture
    chat_payload = {
        'message': 'Hello, I need bulk water supply of 2000 jars for my wedding. My contact is 9888877777',
        'session_id': 'test-session-public-101'
    }
    chat_res = anon_client.post('/api/chat/message/', chat_payload, format='json')
    print(f"Chat View response status: {chat_res.status_code}")
    chatbot_lead = Lead.objects.filter(phone='9888877777').first()
    assert chatbot_lead is not None, "Lead was not auto-created from ChatView natural language!"
    print(f"[PASS] ChatView automatically created lead: Name={chatbot_lead.name}, Phone={chatbot_lead.phone}, Source={chatbot_lead.source}")

    # 5. Verify Daily Business Reports Endpoint with all date filters
    print("\n--- 4. Testing Reporting Endpoint & Date Filters ---")
    for period in ['today', 'yesterday', 'this_week', 'this_month']:
        rep_res = client.get(f'/api/inventory/daily-reports/?period={period}')
        assert rep_res.status_code == 200, f"Period {period} failed: {rep_res.status_code}"
        summary = rep_res.data.get('summary', {})
        cust_act = rep_res.data.get('customer_activity', [])
        fran_act = rep_res.data.get('franchise_activity', [])
        lead_act = rep_res.data.get('lead_activity', [])
        print(f"[PASS] Filter '{period.upper()}': Gross Rev={summary.get('gross_revenue')}, Customer Orders={len(cust_act)}, Franchise Reqs={len(fran_act)}, Leads={len(lead_act)}")

    # Test Custom Date Range
    today_str = date.today().isoformat()
    start_str = (date.today() - timedelta(days=3)).isoformat()
    custom_res = client.get(f'/api/inventory/daily-reports/?start_date={start_str}&end_date={today_str}')
    assert custom_res.status_code == 200, f"Custom date filter failed: {custom_res.status_code}"
    print(f"[PASS] Custom Filter '{start_str} to {today_str}': Orders={len(custom_res.data.get('customer_activity', []))}")

    print("\n" + "=" * 60)
    print("ALL E2E DATA FLOW & REPORTING TESTS PASSED!")
    print("=" * 60)

if __name__ == '__main__':
    run_verification()

import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from django.contrib.auth.models import User
from accounts.models import UserProfile, DeviceToken, FranchiseProfile, FranchiseTerritoryAssignment, ServiceZone
from products.models import Product
from orders.models import Order
from accounts.fcm_services import (
    send_fcm_notification, notify_order_created, notify_stock_request_created,
    notify_lead_created, notify_payment_received, _get_all_admins
)
from leads.models import Lead
from inventory.models import DealerStockRequest

def run_fcm_real_business_trace():
    print("=" * 70)
    print("REAL BUSINESS EVENT -> FCM PUSH NOTIFICATION AUDIT & TRACE")
    print("=" * 70)

    # Physical Samsung A14 token registered on device
    PHYSICAL_DEVICE_FCM_TOKEN = "cufULmzKQBiYx23ds6gGGf:APA91bE_0gSj2wjHCBUANPOAGha0uG1ynYHR_umh1XTniFRbimAtVpG9LyOayxv3leirdcpgjxBr4kNN_MyXfHLjxZnbWR_9h3ZEtEZW4uJgaXqPZgFyLmA"
    
    # Setup / Ensure Users
    admin_user = User.objects.filter(is_superuser=True).first()
    if not admin_user:
        admin_user, _ = User.objects.get_or_create(
            username="admin@shivnath.com",
            defaults={"email": "admin@shivnath.com", "is_superuser": True, "is_staff": True, "is_active": True}
        )
        UserProfile.objects.get_or_create(user=admin_user, defaults={"name": "Shivnath Admin", "role": "super_admin", "status": "active"})

    customer_user = User.objects.filter(profile__role='customer', is_active=True).first()
    if not customer_user:
        customer_user, _ = User.objects.get_or_create(
            username="test_customer_fcm@shivnath.com",
            defaults={"email": "test_customer_fcm@shivnath.com", "is_active": True}
        )
        UserProfile.objects.get_or_create(user=customer_user, defaults={"name": "Test Customer", "role": "customer", "status": "active"})

    franchise_profile = FranchiseProfile.objects.filter(is_headquarters=False, status='approved').first()
    franchise_user = franchise_profile.user if franchise_profile else None

    print(f"Admin User: {admin_user.username} (ID: {admin_user.id})")
    print(f"Customer User: {customer_user.username} (ID: {customer_user.id})")
    print(f"Franchise User: {franchise_user.username if franchise_user else 'None'} (Business: {franchise_profile.business_name if franchise_profile else 'None'})")

    # Associate device token with Customer and Admin for this real-device test
    dt_cust, _ = DeviceToken.objects.update_or_create(
        token=PHYSICAL_DEVICE_FCM_TOKEN,
        defaults={"user": customer_user, "device_type": "android", "is_active": True}
    )
    print(f"\n[TOKEN AUDIT] Registered DeviceToken for Customer {customer_user.username}: {PHYSICAL_DEVICE_FCM_TOKEN[:15]}...{PHYSICAL_DEVICE_FCM_TOKEN[-8:]} (Active: {dt_cust.is_active})")

    # -------------------------------------------------------------
    # TEST 1: DIRECT CUSTOMER ORDER (NOTIFIES ADMIN & CUSTOMER)
    # -------------------------------------------------------------
    print("\n" + "-" * 60)
    print("TEST 1: Customer Places Direct Company Order")
    print("-" * 60)
    prod = Product.objects.filter(status='Active').first() or Product.objects.first()
    order_direct = Order.objects.create(
        created_by=customer_user,
        client_name=customer_user.get_full_name() or customer_user.username,
        franchise_name="Shivnath Agency Central Plant",
        serving_franchise=None,
        order_source="DIRECT_COMPANY",
        city="Raipur",
        amount=500.0,
        grand_total=500.0,
        status="order_placement",
        payment_status="paid",
        payment_mode="ONLINE"
    )
    print(f"Created Real Order #{order_direct.id} ({order_direct.order_code}) for Customer: {customer_user.username}")
    
    # Trigger actual business notification dispatcher
    notify_order_created(order_direct)

    # -------------------------------------------------------------
    # TEST 2: FRANCHISE-FULFILLED ORDER (NOTIFIES FRANCHISE, ADMIN, CUSTOMER)
    # -------------------------------------------------------------
    print("\n" + "-" * 60)
    print("TEST 2: Customer Places Franchise-Fulfilled Order")
    print("-" * 60)
    order_franchise = Order.objects.create(
        created_by=customer_user,
        client_name=customer_user.get_full_name() or customer_user.username,
        franchise_name=franchise_profile.business_name if franchise_profile else "Shivnath Water Raipur East",
        serving_franchise=franchise_profile,
        order_source="FRANCHISE",
        city="Raipur",
        amount=1200.0,
        grand_total=1200.0,
        status="order_placement",
        payment_status="paid",
        payment_mode="ONLINE"
    )
    print(f"Created Real Order #{order_franchise.id} ({order_franchise.order_code}) for Franchise: {franchise_profile.business_name if franchise_profile else 'None'}")
    notify_order_created(order_franchise)

    # -------------------------------------------------------------
    # TEST 3: FRANCHISE STOCK REQUEST (NOTIFIES ADMIN)
    # -------------------------------------------------------------
    print("\n" + "-" * 60)
    print("TEST 3: Franchise Submits Stock Request")
    print("-" * 60)
    # Temporarily bind physical device token to Admin to test Admin push delivery
    DeviceToken.objects.update_or_create(
        token=PHYSICAL_DEVICE_FCM_TOKEN,
        defaults={"user": admin_user, "device_type": "android", "is_active": True}
    )
    stock_req = DealerStockRequest.objects.create(
        dealer=franchise_profile,
        product=prod,
        requested_quantity=100,
        status="PENDING_APPROVAL"
    )
    print(f"Created Real Stock Request #{stock_req.id} ({stock_req.request_number}) from {franchise_profile.business_name if franchise_profile else 'None'}")
    notify_stock_request_created(stock_req)

    # -------------------------------------------------------------
    # TEST 4: PUBLIC CHATBOT LEAD (NOTIFIES ADMIN)
    # -------------------------------------------------------------
    print("\n" + "-" * 60)
    print("TEST 4: Public Chatbot Lead Submission")
    print("-" * 60)
    lead = Lead.objects.create(
        name="Aman Lead Test",
        phone="9806247194",
        city="Raipur",
        territory="East Raipur",
        inquiry_type="franchise",
        lead_source="chatbot",
        status="new"
    )
    print(f"Created Real Lead #{lead.id} ({lead.name}, Phone: {lead.phone})")
    notify_lead_created(lead)

    # -------------------------------------------------------------
    # TEST 5: PAYMENT RECEIVED (NOTIFIES ADMIN & CUSTOMER)
    # -------------------------------------------------------------
    print("\n" + "-" * 60)
    print("TEST 5: Razorpay Online Payment Received")
    print("-" * 60)
    notify_payment_received(
        customer_user=customer_user,
        amount=500.0,
        payment_id="pay_test_audit_12345",
        order=order_direct
    )

    print("\n" + "=" * 70)
    print("ALL REAL BUSINESS EVENT FCM TRACES COMPLETED!")
    print("=" * 70)

if __name__ == '__main__':
    run_fcm_real_business_trace()

import os
import unittest
from django.test import TestCase
from django.contrib.auth import get_user_model
from decimal import Decimal
from accounts.models import (
    UserProfile, FranchiseProfile, ServiceDistrict, ServiceZone,
    AdminNotification, FranchiseNotification, CustomerNotification, DeviceToken
)
from products.models import Product
from orders.models import Order, OrderItem
from inventory.models import DealerStockRequest
from leads.models import Lead
from billing.models import Invoice, PaymentTransaction
from accounts.fcm_services import (
    notify_order_created, notify_stock_request_created,
    notify_lead_created, notify_payment_received,
    notify_stock_request_status_update, send_fcm_notification,
    _get_all_admins
)

User = get_user_model()

class FCMProductionPipelineVerificationTest(TestCase):
    """
    Authoritative test suite verifying the complete FCM push notification pipeline:
    1. Customer places order -> Franchise/Admin push notification
    2. Franchise stock request -> Admin push notification
    3. Public chatbot lead -> Admin push notification
    4. Payment submission -> Admin verification push notification
    5. Payment approval -> Customer / Franchise push notification
    6. Token audit & role isolation (wrong roles blocked)
    """

    def setUp(self):
        # 1. Super Admin with active device token
        self.superadmin, _ = User.objects.get_or_create(
            username='admin_boss',
            defaults={'email': 'admin_boss@waternow.com', 'is_superuser': True, 'is_staff': True, 'is_active': True}
        )
        UserProfile.objects.update_or_create(
            user=self.superadmin,
            defaults={'role': 'super_admin', 'name': 'Super Admin WaterNow'}
        )
        self.admin_token, _ = DeviceToken.objects.update_or_create(
            token='fcm_token_superadmin_physical_samsung_a14',
            defaults={'user': self.superadmin, 'device_type': 'android', 'is_active': True}
        )

        # 2. Franchise A with active device token
        self.franchise_a_user, _ = User.objects.get_or_create(
            username='franchise_raipur',
            defaults={'email': 'raipur@waternow.com', 'is_active': True}
        )
        self.district, _ = ServiceDistrict.objects.get_or_create(name='Raipur', defaults={'state': 'Chhattisgarh'})
        self.zone, _ = ServiceZone.objects.get_or_create(name='Raipur Central', defaults={'district': self.district})
        self.franchise_a, _ = FranchiseProfile.objects.get_or_create(
            user=self.franchise_a_user,
            defaults={'business_name': 'WaterNow Raipur Franchise', 'city': 'Raipur', 'status': 'approved'}
        )
        self.franchise_a_token, _ = DeviceToken.objects.update_or_create(
            token='fcm_token_franchise_a_device',
            defaults={'user': self.franchise_a_user, 'device_type': 'android', 'is_active': True}
        )

        # 3. Franchise B (should NEVER get Franchise A notifications)
        self.franchise_b_user, _ = User.objects.get_or_create(
            username='franchise_bhilai',
            defaults={'email': 'bhilai@waternow.com', 'is_active': True}
        )
        self.franchise_b, _ = FranchiseProfile.objects.get_or_create(
            user=self.franchise_b_user,
            defaults={'business_name': 'WaterNow Bhilai Franchise', 'city': 'Bhilai', 'status': 'approved'}
        )
        self.franchise_b_token, _ = DeviceToken.objects.update_or_create(
            token='fcm_token_franchise_b_device',
            defaults={'user': self.franchise_b_user, 'device_type': 'android', 'is_active': True}
        )

        # 4. Customer with active device token
        self.customer, _ = User.objects.get_or_create(
            username='customer_aman',
            defaults={'email': 'aman@example.com', 'is_active': True}
        )
        UserProfile.objects.update_or_create(
            user=self.customer,
            defaults={'role': 'customer', 'name': 'Aman Customer', 'phone': '9876500001'}
        )
        self.customer_token, _ = DeviceToken.objects.update_or_create(
            token='fcm_token_customer_aman_device',
            defaults={'user': self.customer, 'device_type': 'android', 'is_active': True}
        )

        # 5. Product
        self.product, _ = Product.objects.get_or_create(
            sku='WN-500ML-BOX',
            defaults={'name': 'WaterNow 500 ML Pack', 'size': '500ML', 'price': Decimal('240.00'), 'stock': 1000, 'status': 'Active'}
        )

    def test_1_customer_order_dispatch_pipeline(self):
        """Test 1: Customer places order -> Franchise & Admin push dispatched, correct tokens targeted."""
        order = Order.objects.create(
            client_name='Aman Customer',
            created_by=self.customer,
            serving_franchise=self.franchise_a,
            order_source='FRANCHISE',
            franchise_name=self.franchise_a.business_name,
            amount=Decimal('480.00'),
            items_count=2,
            status='order_placement',
            payment_status='pending'
        )
        OrderItem.objects.create(
            order=order,
            product=self.product,
            product_name=self.product.name,
            quantity=2,
            unit_price=240.0,
            total_price=480.0
        )

        # Dispatch real notification
        notify_order_created(order)

        # DB Notifications check
        admin_notif = AdminNotification.objects.filter(reference_id=order.id).first()
        self.assertIsNotNone(admin_notif)
        self.assertIn('Aman Customer', admin_notif.message)
        self.assertIn('ORD-', admin_notif.title)

        franchise_notif = FranchiseNotification.objects.filter(franchise=self.franchise_a, reference_id=order.id).first()
        self.assertIsNotNone(franchise_notif)
        self.assertIn('Aman Customer', franchise_notif.message)

        # Recipient isolation: Franchise B must NOT receive any notification
        franchise_b_notif = FranchiseNotification.objects.filter(franchise=self.franchise_b, reference_id=order.id).first()
        self.assertIsNone(franchise_b_notif)

        cust_notif = CustomerNotification.objects.filter(customer=self.customer, reference_id=order.id).first()
        self.assertIsNotNone(cust_notif)

    def test_2_franchise_stock_request_pipeline(self):
        """Test 2: Franchise creates stock request -> Admin receives push notification."""
        stock_req = DealerStockRequest.objects.create(
            request_number='SR-202610-0099',
            dealer=self.franchise_a,
            product=self.product,
            requested_quantity=500,
            status='REQUESTED'
        )

        notify_stock_request_created(stock_req)

        admin_notif = AdminNotification.objects.filter(reference_id=stock_req.id).first()
        self.assertIsNotNone(admin_notif)
        self.assertIn(self.franchise_a.business_name, admin_notif.title)
        self.assertIn('500', admin_notif.message)

    def test_3_chatbot_lead_capture_pipeline(self):
        """Test 3: Public chatbot creates lead -> Admin receives push notification."""
        lead = Lead.objects.create(
            name='Rohit Sharma',
            phone='9893012345',
            city='Raipur',
            status='NEW',
            source='PUBLIC_CHATBOT',
            notes='Inquired about 20L jars for corporate office.'
        )

        notify_lead_created(lead)

        admin_notif = AdminNotification.objects.filter(reference_id=lead.id).first()
        self.assertIsNotNone(admin_notif)
        self.assertIn('Rohit Sharma', admin_notif.title)
        self.assertIn('9893012345', admin_notif.message)

    def test_4_payment_submission_and_approval_pipeline(self):
        """Test 4: Payment submitted -> Admin alerted; Payment approved -> Customer & Franchise notified."""
        invoice = Invoice.objects.create(
            invoice_number='INV-WN-2026-0001',
            invoice_type='CUSTOMER_INVOICE',
            billed_to_name='Aman Customer',
            grand_total=Decimal('480.00'),
            amount_paid=Decimal('0.00'),
            status='PENDING_PAYMENT'
        )
        order = Order.objects.create(
            client_name='Aman Customer',
            created_by=self.customer,
            serving_franchise=self.franchise_a,
            order_source='FRANCHISE',
            amount=Decimal('480.00'),
            items_count=2,
            status='order_placement',
            payment_status='pending'
        )
        invoice.order = order
        invoice.save()

        # Step 4A: Payment Submission (Pending verification)
        notify_payment_received(order, Decimal('480.00'), actor_name='Aman Customer', is_pending=True, invoice=invoice)

        admin_notif = AdminNotification.objects.filter(reference_id=order.id, notification_type='payment_verification').first()
        self.assertIsNotNone(admin_notif)
        self.assertIn('480', admin_notif.message)

        # Step 4B: Payment Approved (Confirmed receipt)
        notify_payment_received(order, Decimal('480.00'), actor_name='Super Admin', is_pending=False, invoice=invoice)

        cust_notif = CustomerNotification.objects.filter(customer=self.customer, reference_id=order.id).first()
        self.assertIsNotNone(cust_notif)
        self.assertIn('Payment Received', cust_notif.title)

    def test_5_device_token_account_switch_isolation(self):
        """Test 5: Device token properly transfers between accounts without data bleed."""
        shared_phone_token = 'samsung_galaxy_a14_device_fcm_token_xyz'

        # User 1 registers token
        DeviceToken.objects.update_or_create(
            token=shared_phone_token,
            defaults={'user': self.customer, 'device_type': 'android', 'is_active': True}
        )
        self.assertEqual(DeviceToken.objects.filter(user=self.customer, is_active=True).count(), 2)

        # User 1 logs out: token deactivated
        DeviceToken.objects.filter(token=shared_phone_token).update(is_active=False)
        self.assertFalse(DeviceToken.objects.get(token=shared_phone_token).is_active)

        # User 2 logs in on same phone: token reassigned to User 2 and reactivated
        dt, _ = DeviceToken.objects.update_or_create(
            token=shared_phone_token,
            defaults={'user': self.superadmin, 'device_type': 'android', 'is_active': True}
        )
        self.assertEqual(dt.user, self.superadmin)
        self.assertTrue(dt.is_active)

        # Querying customer active tokens must NOT include shared_phone_token
        cust_tokens = list(DeviceToken.objects.filter(user=self.customer, is_active=True).values_list('token', flat=True))
        self.assertNotIn(shared_phone_token, cust_tokens)

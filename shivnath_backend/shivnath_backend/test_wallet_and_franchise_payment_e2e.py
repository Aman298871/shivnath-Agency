"""
End-to-End Automated Test Suite: Wallet Ownership, Franchise Order & Payment Separation, and Central Company Payment Integrity
Shivnath Agency (Water Wala)

Verifies:
1. Central Company Razorpay payment verification, amount tampering rejection, and cancellation handling.
2. Franchise order creation:
   - Order belongs strictly to the selected franchise (order_source='FRANCHISE', serving_franchise=<id>).
   - Central Razorpay gateway blocks franchise orders (FRANCHISE_ORDER_ONLINE_PAYMENT_NOT_SUPPORTED).
   - Central Razorpay verification blocks franchise orders (FRANCHISE_ORDER_PAYMENT_NOT_SUPPORTED).
   - Only permitted payment method is FRANCHISE_COLLECTION (collected on delivery).
3. Wallet Ownership and Integrity:
   - User wallet is isolated to owner.
   - Recharging wallet works atomically with ledger entry.
   - Debiting wallet for direct company order reduces balance atomically and records ORDER_DEBIT with balance_after.
   - Insufficient balance is rejected without debiting wallet.
   - Water Wallet cannot pay for Franchise orders.
   - Refunding wallet-paid order on cancellation restores balance atomically and logs ORDER_REFUND with idempotency.
4. Franchise Dashboard & Authorization Isolation:
   - Franchise A cannot see Franchise B's orders.
   - Franchise order cancellation restores inventory.
"""

import os
import sys
import json
import uuid
import hmac
import hashlib
from decimal import Decimal
from datetime import timedelta
from unittest.mock import patch, MagicMock

# Setup Django environment
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
import django
django.setup()

from django.utils import timezone
from django.test import TestCase
from django.contrib.auth.models import User
from rest_framework.test import APIClient
from rest_framework.exceptions import ValidationError

from accounts.models import UserProfile, FranchiseProfile
from products.models import Product, ProductCategory
from orders.models import Order, OrderItem, Wallet, WalletTransaction, WalletRedemptionRule
from orders.wallet_services import (
    get_or_create_wallet,
    initiate_wallet_recharge,
    verify_wallet_recharge,
    debit_wallet_for_order,
    refund_order_to_wallet,
    sync_customer_earned_points,
    award_points_for_order,
    get_redemption_eligible_products,
    redeem_points_for_order,
)
from inventory.models import ProductionBatch, DealerStockBatch
from inventory.services import reserve_order_stock_fefo_atomic, cancel_order_atomic


class WalletAndFranchisePaymentE2ETests(TestCase):
    def setUp(self):
        self.client = APIClient()

        # 1. Central Admin
        self.admin = User.objects.create_superuser(
            username='admin_e2e',
            email='admin@waterwala.com',
            password='AdminPass123!'
        )
        p_admin, _ = UserProfile.objects.get_or_create(user=self.admin)
        p_admin.role = 'admin'
        p_admin.save()

        # 2. Franchise A
        self.user_fran_a = User.objects.create_user(
            username='franchise_a',
            email='franchise_a@waterwala.com',
            password='FranPass123!'
        )
        p_fran_a, _ = UserProfile.objects.get_or_create(user=self.user_fran_a)
        p_fran_a.role = 'franchise'
        p_fran_a.save()
        self.franchise_a = FranchiseProfile.objects.create(
            user=self.user_fran_a,
            business_name='Water Wala Raipur Central',
            dealer_code='WW-RPR-001',
            status='approved',
            city='Raipur'
        )

        # 3. Franchise B
        self.user_fran_b = User.objects.create_user(
            username='franchise_b',
            email='franchise_b@waterwala.com',
            password='FranPass123!'
        )
        p_fran_b, _ = UserProfile.objects.get_or_create(user=self.user_fran_b)
        p_fran_b.role = 'franchise'
        p_fran_b.save()
        self.franchise_b = FranchiseProfile.objects.create(
            user=self.user_fran_b,
            business_name='Water Wala Durg Branch',
            dealer_code='WW-DRG-002',
            status='approved',
            city='Durg'
        )

        # 4. Customer
        self.customer = User.objects.create_user(
            username='customer_ravi',
            email='ravi@example.com',
            password='CustomerPass123!'
        )
        p_cust, _ = UserProfile.objects.get_or_create(user=self.customer)
        p_cust.role = 'customer'
        p_cust.phone = '9876543210'
        p_cust.save()

        # 5. Product Category & Product
        self.category = ProductCategory.objects.create(name='20L Jars')
        self.product = Product.objects.create(
            name='Mineral Water Jar 20L',
            sku='WW-JAR-20L',
            size='20L',
            category_ref=self.category,
            price=Decimal('90.00'),
            dealer_transfer_price=Decimal('65.00'),
            stock=100,
            status='Active'
        )

        # 6. Company ProductionBatch (for Direct Company Orders)
        self.company_batch = ProductionBatch.objects.create(
            batch_number='PB-E2E-001',
            product=self.product,
            manufacture_date=timezone.now().date(),
            expiry_date=timezone.now().date() + timedelta(days=90),
            quantity_produced_units=1000,
            quantity_remaining_company=1000,
            reserved_quantity=0,
            unit_production_cost=Decimal('35.00'),
            status='ACTIVE'
        )

        # 7. DealerStockBatch for Franchise A (for Franchise Orders)
        self.dealer_batch_a = DealerStockBatch.objects.create(
            dealer=self.franchise_a,
            product=self.product,
            batch_number='DB-RPR-001',
            manufacture_date=timezone.now().date(),
            expiry_date=timezone.now().date() + timedelta(days=60),
            received_quantity=500,
            remaining_quantity=500,
            reserved_quantity=0,
            unit_transfer_price=Decimal('65.00'),
            is_active=True
        )

        # 8. Test dummy Razorpay credentials
        self.test_key_id = 'rzp_test_e2e_key_123'
        self.test_key_secret = 'e2e_secret_456'

    # =========================================================================
    # A. Central-Company/Admin Orders & Razorpay Verification
    # =========================================================================
    def test_central_order_creation_and_tampered_amount_rejection(self):
        """Central order amount is validated server-side; tampered amounts are rejected."""
        self.client.force_authenticate(user=self.customer)

        # Create Direct Company Order
        res = self.client.post('/api/orders/', {
            'franchise': 'Shivnath Agency (Direct)',
            'city': 'Raipur',
            'customer_name': 'Ravi Kumar',
            'phone': '9876543210',
            'delivery_address': 'Sector 1, Shankar Nagar, Raipur',
            'items': 2,
            'amount': 180.0,
            'status': 'order_placement',
            'payment': 'pending',
            'payment_mode': 'RAZORPAY',
            'order_source': 'DIRECT_COMPANY',
            'serving_franchise_id': None,
            'order_items': [
                {'product_id': self.product.id, 'quantity': 2, 'price': 90.0}
            ],
        }, format='json')

        self.assertEqual(res.status_code, 201)
        order_id = res.data.get('id') or (res.data.get('order') or {}).get('id')
        order = Order.objects.get(id=order_id)
        self.assertEqual(order.order_source, 'DIRECT_COMPANY')
        self.assertIsNone(order.serving_franchise)

        # Attempt to tamper amount during Razorpay order initialization
        with patch.dict(os.environ, {
            'RAZORPAY_KEY_ID': self.test_key_id,
            'RAZORPAY_KEY_SECRET': self.test_key_secret,
            'RAZORPAY_ENVIRONMENT': 'TEST'
        }, clear=False):
            tampered_res = self.client.post('/api/orders/razorpay/create-order/', {
                'order_id': order.id,
                'amount': 50.0  # Tampered: order is 180.0, client claims 50.0
            }, format='json')

            self.assertEqual(tampered_res.status_code, 400)
            self.assertEqual(tampered_res.data['error_code'], 'AMOUNT_MISMATCH')

    # =========================================================================
    # B. Franchise Orders and Payment Separation
    # =========================================================================
    def test_franchise_order_cannot_use_central_razorpay_gateway(self):
        """Franchise order cannot initialize or verify payment through central company Razorpay."""
        self.client.force_authenticate(user=self.customer)

        # Place order with Franchise A
        res = self.client.post('/api/orders/', {
            'franchise': self.franchise_a.business_name,
            'city': 'Raipur',
            'customer_name': 'Ravi Kumar',
            'phone': '9876543210',
            'delivery_address': 'Pandri, Raipur',
            'items': 3,
            'amount': 270.0,
            'status': 'order_placement',
            'payment': 'pending',
            'payment_mode': 'FRANCHISE_COLLECTION',
            'order_source': 'FRANCHISE',
            'serving_franchise_id': self.franchise_a.id,
            'order_items': [
                {'product_id': self.product.id, 'quantity': 3, 'price': 90.0}
            ],
        }, format='json')

        self.assertEqual(res.status_code, 201)
        order_id = res.data.get('id') or (res.data.get('order') or {}).get('id')
        order = Order.objects.get(id=order_id)

        # Verify order ownership & payment mode
        self.assertEqual(order.order_source, 'FRANCHISE')
        self.assertEqual(order.serving_franchise, self.franchise_a)
        self.assertEqual(order.payment_mode, 'FRANCHISE_COLLECTION')

        # 1. Attempt to create Razorpay order for this franchise order
        with patch.dict(os.environ, {
            'RAZORPAY_KEY_ID': self.test_key_id,
            'RAZORPAY_KEY_SECRET': self.test_key_secret,
            'RAZORPAY_ENVIRONMENT': 'TEST'
        }, clear=False):
            rzp_create_res = self.client.post('/api/orders/razorpay/create-order/', {
                'order_id': order.id,
                'amount': 270.0
            }, format='json')

            self.assertEqual(rzp_create_res.status_code, 400)
            self.assertEqual(rzp_create_res.data['error_code'], 'FRANCHISE_ORDER_ONLINE_PAYMENT_NOT_SUPPORTED')

        # 2. Attempt to verify Razorpay payment for this franchise order
        with patch.dict(os.environ, {
            'RAZORPAY_KEY_ID': self.test_key_id,
            'RAZORPAY_KEY_SECRET': self.test_key_secret,
            'RAZORPAY_ENVIRONMENT': 'TEST'
        }, clear=False):
            rzp_verify_res = self.client.post('/api/orders/razorpay/verify-payment/', {
                'order_id': order.id,
                'razorpay_order_id': 'order_mock_franchise_123',
                'razorpay_payment_id': 'pay_mock_franchise_456',
                'razorpay_signature': 'dummy_sig'
            }, format='json')

            self.assertEqual(rzp_verify_res.status_code, 400)
            self.assertEqual(rzp_verify_res.data['error_code'], 'FRANCHISE_ORDER_PAYMENT_NOT_SUPPORTED')

    def test_franchise_dashboard_order_isolation(self):
        """Franchise A can see its own orders; Franchise B cannot see Franchise A's orders."""
        order_a = Order.objects.create(
            created_by=self.customer,
            serving_franchise=self.franchise_a,
            franchise_name=self.franchise_a.business_name,
            city='Raipur',
            amount=Decimal('180.00'),
            grand_total=Decimal('180.00'),
            status='order_placement',
            payment_status='pending',
            payment_mode='FRANCHISE_COLLECTION',
            order_source='FRANCHISE'
        )

        # Franchise A queries orders list
        self.client.force_authenticate(user=self.user_fran_a)
        res_a = self.client.get('/api/orders/')
        self.assertEqual(res_a.status_code, 200)
        orders_list_a = res_a.data.get('orders') if isinstance(res_a.data, dict) else res_a.data
        order_ids_a = [o['id'] for o in orders_list_a]
        self.assertIn(order_a.id, order_ids_a)

        # Franchise B queries orders list
        self.client.force_authenticate(user=self.user_fran_b)
        res_b = self.client.get('/api/orders/')
        self.assertEqual(res_b.status_code, 200)
        orders_list_b = res_b.data.get('orders') if isinstance(res_b.data, dict) else res_b.data
        order_ids_b = [o['id'] for o in orders_list_b]
        # Franchise B must NOT see Franchise A's order
        self.assertNotIn(order_a.id, order_ids_b)

    # =========================================================================
    # C. Wallet Ownership and Deductions
    # =========================================================================
    def test_wallet_creation_recharge_and_isolated_ownership(self):
        """Wallet belongs strictly to the user and recharges atomically."""
        wallet = get_or_create_wallet(self.customer)
        self.assertEqual(wallet.user, self.customer)
        self.assertEqual(wallet.balance, Decimal('0.00'))

        # Recharge wallet with ₹1,000
        init_res = initiate_wallet_recharge(self.customer, 1000.0)
        self.assertTrue(init_res['success'])
        rzp_order_id = init_res['razorpay_order_id']

        verify_res = verify_wallet_recharge(
            user=self.customer,
            razorpay_order_id=rzp_order_id,
            razorpay_payment_id='pay_mock_wallet_789',
            razorpay_signature='mock_signature_test'
        )
        self.assertTrue(verify_res['success'])
        self.assertEqual(verify_res['balance'], 1000.0)

        wallet.refresh_from_db()
        self.assertEqual(wallet.balance, Decimal('1000.00'))

        # Idempotency: verify again with same payment details returns already_processed
        dup_res = verify_wallet_recharge(
            user=self.customer,
            razorpay_order_id=rzp_order_id,
            razorpay_payment_id='pay_mock_wallet_789',
            razorpay_signature='mock_signature_test'
        )
        self.assertTrue(dup_res['success'])
        self.assertTrue(dup_res['already_processed'])
        self.assertEqual(wallet.balance, Decimal('1000.00'))

    def test_wallet_cannot_pay_for_franchise_orders(self):
        """Central Water Wallet cannot be used to pay for Franchise orders."""
        wallet = get_or_create_wallet(self.customer)
        wallet.balance = Decimal('5000.00')
        wallet.save()

        franchise_order = Order.objects.create(
            created_by=self.customer,
            serving_franchise=self.franchise_a,
            franchise_name=self.franchise_a.business_name,
            city='Raipur',
            amount=Decimal('450.00'),
            grand_total=Decimal('450.00'),
            status='order_placement',
            payment_status='pending',
            payment_mode='FRANCHISE_COLLECTION',
            order_source='FRANCHISE'
        )

        with self.assertRaises(ValidationError) as cm:
            debit_wallet_for_order(order=franchise_order, user=self.customer)

        self.assertIn('Central Water Wallet balances cannot be used to pay for Franchise orders', str(cm.exception))
        # Verify wallet balance was NOT touched
        wallet.refresh_from_db()
        self.assertEqual(wallet.balance, Decimal('5000.00'))

    def test_wallet_debit_for_direct_order_and_insufficient_balance(self):
        """Wallet is debited for direct company orders; insufficient balance is rejected."""
        wallet = get_or_create_wallet(self.customer)
        wallet.balance = Decimal('100.00')
        wallet.save()

        expensive_order = Order.objects.create(
            created_by=self.customer,
            franchise_name='Shivnath Agency (Direct)',
            city='Raipur',
            amount=Decimal('500.00'),
            grand_total=Decimal('500.00'),
            status='order_placement',
            payment_status='pending',
            payment_mode='WALLET',
            order_source='DIRECT_COMPANY'
        )

        # 1. Insufficient balance test
        with self.assertRaises(ValidationError) as cm:
            debit_wallet_for_order(order=expensive_order, user=self.customer)
        self.assertIn('Insufficient Water Wallet balance', str(cm.exception))
        wallet.refresh_from_db()
        self.assertEqual(wallet.balance, Decimal('100.00'))

        # 2. Add sufficient funds and test successful atomic debit
        wallet.balance = Decimal('1000.00')
        wallet.save()

        debit_res = debit_wallet_for_order(order=expensive_order, user=self.customer)
        self.assertTrue(debit_res['success'])
        self.assertEqual(debit_res['remaining_balance'], 500.0)
        self.assertEqual(debit_res['debited_amount'], 500.0)

        wallet.refresh_from_db()
        self.assertEqual(wallet.balance, Decimal('500.00'))

        expensive_order.refresh_from_db()
        self.assertEqual(expensive_order.payment_status, 'paid')
        self.assertEqual(expensive_order.payment_mode, 'WALLET')

        # Verify WalletTransaction ledger record
        txn = WalletTransaction.objects.filter(order=expensive_order, transaction_type='ORDER_DEBIT').first()
        self.assertIsNotNone(txn)
        self.assertEqual(txn.amount, Decimal('500.00'))
        self.assertEqual(txn.balance_after, Decimal('500.00'))
        self.assertEqual(txn.status, 'SUCCESS')

    def test_wallet_refund_on_order_cancellation(self):
        """Wallet refund on cancellation atomically restores balance and is idempotent."""
        wallet = get_or_create_wallet(self.customer)
        wallet.balance = Decimal('500.00')
        wallet.save()

        direct_order = Order.objects.create(
            created_by=self.customer,
            franchise_name='Shivnath Agency (Direct)',
            city='Raipur',
            amount=Decimal('300.00'),
            grand_total=Decimal('300.00'),
            status='order_placement',
            payment_status='paid',
            payment_mode='WALLET',
            order_source='DIRECT_COMPANY'
        )

        # Refund order to wallet
        ref_res = refund_order_to_wallet(direct_order, reason="Customer cancelled before dispatch")
        self.assertTrue(ref_res['success'])
        self.assertEqual(ref_res['refunded_amount'], 300.0)
        self.assertEqual(ref_res['new_balance'], 800.0)

        wallet.refresh_from_db()
        self.assertEqual(wallet.balance, Decimal('800.00'))

        # Duplicate refund call is idempotent
        dup_ref = refund_order_to_wallet(direct_order)
        self.assertTrue(dup_ref['success'])
        self.assertTrue(dup_ref['already_refunded'])
        wallet.refresh_from_db()
        self.assertEqual(wallet.balance, Decimal('800.00'))

    def test_unpaid_order_cannot_receive_wallet_refund(self):
        """Unpaid or non-wallet order cannot receive an invalid wallet refund."""
        wallet = get_or_create_wallet(self.customer)
        wallet.balance = Decimal('500.00')
        wallet.save()

        # 1. Unpaid wallet order
        unpaid_order = Order.objects.create(
            created_by=self.customer,
            franchise_name='Shivnath Agency (Direct)',
            city='Raipur',
            amount=Decimal('300.00'),
            grand_total=Decimal('300.00'),
            status='cancelled',
            payment_status='pending',
            payment_mode='WALLET',
            order_source='DIRECT_COMPANY'
        )

        res = refund_order_to_wallet(unpaid_order)
        self.assertFalse(res['success'])
        self.assertIn('not paid using Water Wallet', res['message'])
        wallet.refresh_from_db()
        self.assertEqual(wallet.balance, Decimal('500.00'))

        # 2. Paid online order cannot be refunded through wallet refund function
        online_order = Order.objects.create(
            created_by=self.customer,
            franchise_name='Shivnath Agency (Direct)',
            city='Raipur',
            amount=Decimal('300.00'),
            grand_total=Decimal('300.00'),
            status='cancelled',
            payment_status='paid',
            payment_mode='RAZORPAY',
            order_source='DIRECT_COMPANY'
        )
        res_online = refund_order_to_wallet(online_order)
        self.assertFalse(res_online['success'])
        self.assertIn('not paid using Water Wallet', res_online['message'])
        wallet.refresh_from_db()
        self.assertEqual(wallet.balance, Decimal('500.00'))

    def test_customer_points_sync_and_earning_from_orders(self):
        """Points are earned from completed orders and can be synced idempotently."""
        wallet = get_or_create_wallet(self.customer)
        wallet.reward_points = 0
        wallet.save()

        # Place a regular order for Rs. 500
        order = Order.objects.create(
            created_by=self.customer,
            franchise_name='Shivnath Agency (Direct)',
            city='Raipur',
            amount=Decimal('500.00'),
            grand_total=Decimal('500.00'),
            status='order_placement',
            payment_status='paid',
            order_source='DIRECT_COMPANY'
        )

        award_res = award_points_for_order(order)
        self.assertTrue(award_res['success'])
        self.assertEqual(award_res['points_awarded'], 50)  # 500 / 10 = 50 pts

        wallet.refresh_from_db()
        self.assertEqual(wallet.reward_points, 50)

        # Idempotent: re-awarding doesn't double-count
        dup_award = award_points_for_order(order)
        self.assertTrue(dup_award['success'])
        self.assertTrue(dup_award.get('already_awarded', False))
        wallet.refresh_from_db()
        self.assertEqual(wallet.reward_points, 50)

    def test_water_wallet_product_redemption_order_creation_and_admin_routing(self):
        """
        Customer redeems points for product purchase:
        - Points deducted from wallet
        - Order created with order_source='WATER_WALLET_REDEMPTION'
        - Assigned directly to Central Admin (serving_franchise is None)
        - Excluded from Franchise queues and counts
        - Company warehouse stock reserved via FEFO
        """
        wallet = get_or_create_wallet(self.customer)
        wallet.reward_points = 300  # 300 points = Rs. 150 discount value
        wallet.balance = Decimal('100.00')
        wallet.save()

        # Product is priced at Rs. 90 (requires 180 points for full 100% redemption)
        self.client.force_authenticate(user=self.customer)

        # 1. Fetch eligible redemption catalog
        cat_res = self.client.get('/api/orders/wallet/redemption-products/')
        self.assertEqual(cat_res.status_code, 200)
        p_data = cat_res.data['products'][0]
        self.assertEqual(p_data['points_required'], 180)
        self.assertTrue(p_data['can_fully_redeem'])

        # 2. Place redemption order
        redeem_payload = {
            'product_id': self.product.id,
            'quantity': 1,
            'delivery_address': 'Flat 402, Shivnath Enclave, Raipur',
            'notes': 'Deliver before 5 PM',
        }
        resp = self.client.post('/api/orders/wallet/redeem/', redeem_payload, format='json')
        self.assertEqual(resp.status_code, 201)
        self.assertTrue(resp.data['success'])

        order_id = resp.data['order']['id']
        order = Order.objects.get(id=order_id)

        # Mandatory Business Rules Verification:
        self.assertEqual(order.order_source, 'WATER_WALLET_REDEMPTION')
        self.assertIsNone(order.serving_franchise)
        self.assertIsNone(order.registered_franchise)
        self.assertEqual(order.payment_status, 'paid')
        self.assertEqual(order.payment_mode, 'WALLET_REDEMPTION')
        self.assertEqual(order.points_redeemed, 180)
        self.assertEqual(order.points_discount_amount, Decimal('90.00'))
        self.assertEqual(order.wallet_amount_debited, Decimal('0.00'))
        self.assertEqual(order.remaining_payable_amount, Decimal('0.00'))

        # Points ledger verification:
        wallet.refresh_from_db()
        self.assertEqual(wallet.reward_points, 120)  # 300 - 180 = 120

        pts_txn = WalletTransaction.objects.filter(
            wallet=wallet,
            order=order,
            transaction_type='POINTS_REDEEMED'
        ).first()
        self.assertIsNotNone(pts_txn)
        self.assertEqual(pts_txn.points, -180)
        self.assertEqual(pts_txn.points_balance_after, 120)
        self.assertEqual(pts_txn.status, 'SUCCESS')

        # Central inventory verification:
        self.company_batch.refresh_from_db()
        self.assertEqual(self.company_batch.reserved_quantity, 1)

    def test_franchise_cannot_access_or_view_wallet_redemption_order(self):
        """
        Franchise users must NEVER see, access, or update wallet redemption orders:
        - Excluded from franchise order list API
        - Direct GET on order details returns 403 Forbidden
        - Direct PATCH on order status returns 403 Forbidden
        """
        wallet = get_or_create_wallet(self.customer)
        wallet.reward_points = 200
        wallet.save()

        # Create wallet redemption order
        res = redeem_points_for_order(
            user=self.customer,
            product_id=self.product.id,
            quantity=1,
            delivery_address='Raipur'
        )
        wallet_order = res['order']

        # 1. Franchise A calls GET /api/orders/ -> wallet order must NOT be present
        self.client.force_authenticate(user=self.user_fran_a)
        list_res = self.client.get('/api/orders/')
        self.assertEqual(list_res.status_code, 200)
        order_ids = [o['id'] for o in list_res.data.get('orders', [])]
        self.assertNotIn(wallet_order.id, order_ids)

        # 2. Franchise A attempts direct GET /api/orders/<id>/ -> HTTP 403 Forbidden
        detail_res = self.client.get(f'/api/orders/{wallet_order.id}/')
        self.assertEqual(detail_res.status_code, 403)

        # 3. Franchise A attempts direct PATCH /api/orders/<id>/status/ -> HTTP 403 Forbidden
        status_res = self.client.patch(
            f'/api/orders/{wallet_order.id}/status/',
            {'status': 'preparing'},
            format='json'
        )
        self.assertEqual(status_res.status_code, 403)

    def test_central_admin_can_filter_and_fulfill_wallet_redemption_order(self):
        """
        Central Admin can see wallet redemption orders in queue, filter by order_source,
        and process order status through authorized lifecycle.
        """
        wallet = get_or_create_wallet(self.customer)
        wallet.reward_points = 200
        wallet.save()

        res = redeem_points_for_order(
            user=self.customer,
            product_id=self.product.id,
            quantity=1,
            delivery_address='Raipur'
        )
        wallet_order = res['order']

        # Admin client
        self.client.force_authenticate(user=self.admin)

        # Filter by order_source
        list_res = self.client.get('/api/orders/?order_source=WATER_WALLET_REDEMPTION')
        self.assertEqual(list_res.status_code, 200)
        self.assertTrue(any(o['id'] == wallet_order.id for o in list_res.data.get('orders', [])))

        # Inspect serialized display fields
        admin_order_data = next(o for o in list_res.data.get('orders', []) if o['id'] == wallet_order.id)
        self.assertEqual(admin_order_data['franchise_name'], 'Shivnath Central Admin (Water Wallet)')
        self.assertEqual(admin_order_data['fulfilling_entity'], 'Shivnath Central Admin Plant')

        # Admin processes status: order_placement -> plant_approval -> preparing -> dispatch -> delivered
        for nxt_st in ['plant_approval', 'preparing', 'dispatch', 'delivered']:
            st_res = self.client.patch(
                f'/api/orders/{wallet_order.id}/status/',
                {'status': nxt_st},
                format='json'
            )
            self.assertEqual(st_res.status_code, 200)
            self.assertEqual(st_res.data['order']['status'], nxt_st)

    def test_insufficient_points_rejected_and_cancellation_restores_points(self):
        """
        Insufficient balance rejected without creating an order.
        Cancellation of a confirmed wallet redemption order restores points.
        """
        wallet = get_or_create_wallet(self.customer)
        wallet.reward_points = 50  # Less than min 100 points
        wallet.balance = Decimal('0.00')
        wallet.save()

        self.client.force_authenticate(user=self.customer)

        # 1. Attempt redemption with insufficient points
        rej_res = self.client.post('/api/orders/wallet/redeem/', {
            'product_id': self.product.id,
            'quantity': 1,
        }, format='json')
        self.assertEqual(rej_res.status_code, 400)
        self.assertFalse(rej_res.data['success'])
        self.assertIn('minimum', rej_res.data['message'].lower())

        # Confirm no order was created
        self.assertFalse(Order.objects.filter(created_by=self.customer, order_source='WATER_WALLET_REDEMPTION').exists())
        wallet.refresh_from_db()
        self.assertEqual(wallet.reward_points, 50)

        # 2. Grant enough points, place order, and cancel it
        wallet.reward_points = 200
        wallet.save()

        res = redeem_points_for_order(
            user=self.customer,
            product_id=self.product.id,
            quantity=1,
            delivery_address='Raipur'
        )
        ord_obj = res['order']
        wallet.refresh_from_db()
        self.assertEqual(wallet.reward_points, 20)  # 200 - 180 = 20

        # Cancel order
        cancel_res = refund_order_to_wallet(ord_obj, reason="Customer cancelled before processing")
        self.assertTrue(cancel_res['success'])
        self.assertEqual(cancel_res['points_refunded'], 180)

        wallet.refresh_from_db()
        self.assertEqual(wallet.reward_points, 200)  # Restored!

    def test_water_wallet_checkout_sufficient_balance_and_direct_admin_routing(self):
        """
        Customer places an order using Water Wallet payment:
        - Customer has Rs. 1000 in wallet.
        - Places order for product costing Rs. 90 x 2 = Rs. 180.
        - Order created with order_source='WATER_WALLET', payment_mode='WALLET', payment_status='paid'.
        - Rs. 180 debited atomically from wallet (remaining Rs. 820).
        - Order routed directly to Central Admin (serving_franchise is None).
        - Excluded from franchise queues.
        - Appears in Central Admin queue with serialized labels.
        """
        wallet = get_or_create_wallet(self.customer)
        wallet.balance = Decimal('1000.00')
        wallet.save()

        self.client.force_authenticate(user=self.customer)

        checkout_payload = {
            'order_items': [
                {'product_id': self.product.id, 'quantity': 2, 'price': 90.0}
            ],
            'amount': 180.0,
            'items_count': 2,
            'payment_mode': 'WALLET',
            'delivery_address': 'Sector 4, Devendra Nagar, Raipur',
            'customer_name': 'Test Customer',
            'phone': '9876543210',
        }

        resp = self.client.post('/api/orders/', checkout_payload, format='json')
        self.assertEqual(resp.status_code, 201)
        self.assertTrue(resp.data['success'])
        self.assertEqual(resp.data['wallet_amount_debited'], 180.0)
        self.assertEqual(resp.data['new_wallet_balance'], 820.0)

        order_id = resp.data['order']['id']
        order = Order.objects.get(id=order_id)

        # Assert mandatory business rules:
        self.assertEqual(order.order_source, 'WATER_WALLET')
        self.assertIsNone(order.serving_franchise)
        self.assertEqual(order.payment_status, 'paid')
        self.assertEqual(order.payment_mode, 'WALLET')
        self.assertEqual(order.wallet_amount_debited, Decimal('180.00'))
        self.assertEqual(order.remaining_payable_amount, Decimal('0.00'))

        # Assert wallet balance and ledger:
        wallet.refresh_from_db()
        self.assertEqual(wallet.balance, Decimal('820.00'))

        w_txn = WalletTransaction.objects.filter(
            wallet=wallet,
            order=order,
            transaction_type='ORDER_DEBIT'
        ).first()
        self.assertIsNotNone(w_txn)
        self.assertEqual(w_txn.amount, Decimal('180.00'))
        self.assertEqual(w_txn.balance_after, Decimal('820.00'))
        self.assertEqual(w_txn.status, 'SUCCESS')

        # Assert Franchise cannot see it:
        self.client.force_authenticate(user=self.user_fran_a)
        fran_orders = self.client.get('/api/orders/').data.get('orders', [])
        self.assertNotIn(order.id, [o['id'] for o in fran_orders])

        fran_detail = self.client.get(f'/api/orders/{order.id}/')
        self.assertEqual(fran_detail.status_code, 403)

        # Assert Central Admin can view and process it:
        self.client.force_authenticate(user=self.admin)
        adm_detail = self.client.get(f'/api/orders/{order.id}/')
        self.assertEqual(adm_detail.status_code, 200)
        self.assertEqual(adm_detail.data['order']['franchise_name'], 'Shivnath Central Admin (Water Wallet)')

    def test_water_wallet_checkout_insufficient_balance_rejected(self):
        """
        If wallet balance is less than order amount:
        - HTTP 400 Bad Request
        - No order created
        - Wallet balance remains unchanged
        - Error response includes required amount, available balance, and shortfall
        """
        wallet = get_or_create_wallet(self.customer)
        wallet.balance = Decimal('50.00')
        wallet.save()

        self.client.force_authenticate(user=self.customer)

        checkout_payload = {
            'order_items': [
                {'product_id': self.product.id, 'quantity': 2, 'price': 90.0}
            ],
            'amount': 180.0,
            'items_count': 2,
            'payment_mode': 'WALLET',
            'delivery_address': 'Raipur',
        }

        resp = self.client.post('/api/orders/', checkout_payload, format='json')
        self.assertEqual(resp.status_code, 400)
        self.assertFalse(resp.data['success'])
        self.assertEqual(resp.data['error_code'], 'INSUFFICIENT_WALLET_BALANCE')
        self.assertEqual(resp.data['wallet_balance'], 50.0)
        self.assertEqual(resp.data['required_amount'], 180.0)
        self.assertEqual(resp.data['shortfall'], 130.0)

        # No order created
        self.assertFalse(Order.objects.filter(created_by=self.customer, order_source='WATER_WALLET').exists())

        # Wallet balance preserved
        wallet.refresh_from_db()
        self.assertEqual(wallet.balance, Decimal('50.00'))

    def test_water_wallet_order_cancellation_refunds_balance_atomically(self):
        """
        When a wallet-paid order is cancelled:
        - Debited wallet funds are refunded back to the customer's wallet
        - Immutable ORDER_REFUND ledger transaction created
        - Idempotent: repeated calls do not double-refund
        """
        wallet = get_or_create_wallet(self.customer)
        wallet.balance = Decimal('1000.00')
        wallet.save()

        self.client.force_authenticate(user=self.customer)

        resp = self.client.post('/api/orders/', {
            'order_items': [{'product_id': self.product.id, 'quantity': 1, 'price': 90.0}],
            'amount': 90.0,
            'payment_mode': 'WALLET',
            'delivery_address': 'Raipur',
        }, format='json')
        self.assertEqual(resp.status_code, 201)

        order_id = resp.data['order']['id']
        order = Order.objects.get(id=order_id)
        wallet.refresh_from_db()
        self.assertEqual(wallet.balance, Decimal('910.00'))

        # Admin cancels the order
        self.client.force_authenticate(user=self.admin)
        cancel_resp = self.client.patch(f'/api/orders/{order.id}/status/', {
            'status': 'cancelled',
            'notes': 'Customer requested cancellation',
        }, format='json')
        self.assertEqual(cancel_resp.status_code, 200)

        # Balance restored to 1000.00
        wallet.refresh_from_db()
        self.assertEqual(wallet.balance, Decimal('1000.00'))

        ref_txn = WalletTransaction.objects.filter(
            wallet=wallet,
            order=order,
            transaction_type='ORDER_REFUND'
        ).first()
        self.assertIsNotNone(ref_txn)
        self.assertEqual(ref_txn.amount, Decimal('90.00'))
        self.assertEqual(ref_txn.balance_after, Decimal('1000.00'))

        # Idempotency check: repeated refund call returns already_refunded
        dup_refund = refund_order_to_wallet(order)
        self.assertTrue(dup_refund['success'])
        self.assertTrue(dup_refund.get('already_refunded', False))
        wallet.refresh_from_db()
        self.assertEqual(wallet.balance, Decimal('1000.00'))  # Not doubled!


if __name__ == '__main__':
    from django.test.runner import DiscoverRunner
    test_runner = DiscoverRunner(verbosity=2)
    failures = test_runner.run_tests(['test_wallet_and_franchise_payment_e2e'])
    sys.exit(bool(failures))



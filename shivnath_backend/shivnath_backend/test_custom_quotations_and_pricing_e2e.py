"""
End-to-End Automated Test Suite:
1. Part 5: Safe Payment & Order Placement in Sandbox Mode (Zero Real Money Spent)
2. Part 6: Authoritative Product Pricing Controls & Tamper Resistance
3. Part 7: Custom Branded Bottle Orders, Margin vs Markup Quotation Costing & Order Conversion
"""

import os
import sys
from decimal import Decimal
from unittest.mock import patch

# Setup Django environment
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
import django
django.setup()

from django.test import TestCase, Client
from django.contrib.auth.models import User
from rest_framework_simplejwt.tokens import RefreshToken
from accounts.models import UserProfile
from products.models import Product, ProductCategory
from orders.models import (
    Order, OrderItem,
    CustomBrandedOrderRequest, CustomOrderQuotation,
    Wallet,
)


class CustomQuotationAndPricingE2ETests(TestCase):
    def setUp(self):
        self.client = Client()

        # Create Admin
        self.admin_user = User.objects.create_superuser(
            username='agency_admin',
            email='admin@shivnath.com',
            password='AdminPassword123!',
        )
        p_admin, _ = UserProfile.objects.get_or_create(user=self.admin_user)
        p_admin.role = 'admin'
        p_admin.save()
        self.admin_token = str(RefreshToken.for_user(self.admin_user).access_token)

        # Create Customer
        self.customer = User.objects.create_user(
            username='corporate_client',
            email='client@acmecorp.com',
            password='ClientPassword123!',
            first_name='Ravi',
            last_name='Verma'
        )
        p_cust, _ = UserProfile.objects.get_or_create(user=self.customer)
        p_cust.role = 'customer'
        p_cust.phone = '9826001234'
        p_cust.city = 'Raipur'
        p_cust.address = 'Plot 42, Telibandha Commercial Complex, Raipur'
        p_cust.save()
        self.customer_token = str(RefreshToken.for_user(self.customer).access_token)

        # Create Category and Standard Product with available inventory
        self.category = ProductCategory.objects.create(name='Packaged Water', is_active=True)
        self.product = Product.objects.create(
            name='Premium Mineral Water 500ml',
            sku='PREM-500ML-01',
            size='500ml',
            category_ref=self.category,
            price=Decimal('10.00'),
            dealer_transfer_price=Decimal('7.00'),
            mrp=Decimal('10.00'),
            stock=1000,
            status='Active'
        )

        # Create active ProductionBatch to satisfy batch stock FEFO checks
        from datetime import date, timedelta
        from inventory.models import ProductionBatch
        self.batch = ProductionBatch.objects.create(
            batch_number='PB-TEST-500ML',
            product=self.product,
            manufacture_date=date.today(),
            expiry_date=date.today() + timedelta(days=180),
            quantity_produced_units=1000,
            quantity_remaining_company=1000,
            status='ACTIVE'
        )

    @property
    def admin_header(self):
        return {'HTTP_AUTHORIZATION': f'Bearer {self.admin_token}'}

    @property
    def customer_header(self):
        return {'HTTP_AUTHORIZATION': f'Bearer {self.customer_token}'}

    # =========================================================================
    # PART 6: PRODUCT PRICING CONTROLS & BACKEND TAMPER RESISTANCE
    # =========================================================================

    def test_admin_can_update_product_price(self):
        """Admin can update retail price and dealer transfer price in backend."""
        response = self.client.patch(
            f'/api/products/{self.product.id}/',
            data={
                'price': '12.50',
                'dealer_transfer_price': '8.50',
                'mrp': '15.00'
            },
            content_type='application/json',
            **self.admin_header
        )
        self.assertEqual(response.status_code, 200)
        self.product.refresh_from_db()
        self.assertEqual(self.product.price, Decimal('12.50'))
        self.assertEqual(self.product.dealer_transfer_price, Decimal('8.50'))
        self.assertEqual(self.product.mrp, Decimal('15.00'))

    def test_client_cannot_tamper_order_price(self):
        """When client sends a modified price, backend recalculates price from database Product."""
        order_payload = {
            'items': [
                {
                    'product_id': self.product.id,
                    'quantity': 10,
                    'price': '1.00',  # Tampered client price!
                }
            ],
            'delivery_address': 'Plot 42, Raipur',
            'city': 'Raipur',
            'payment_mode': 'RAZORPAY',
            'order_source': 'DIRECT_COMPANY'
        }
        response = self.client.post(
            '/api/orders/',
            data=order_payload,
            content_type='application/json',
            **self.customer_header
        )
        self.assertEqual(response.status_code, 201, f"Failed order placement: {response.data}")
        order_id = response.data['id']
        order = Order.objects.get(id=order_id)
        # Authoritative total: 10 units * ₹10.00 = ₹100.00, NOT ₹10.00!
        self.assertEqual(order.grand_total, Decimal('100.00'))
        item = order.items.first()
        self.assertEqual(item.unit_price, Decimal('10.00'))
        self.assertEqual(item.total_price, Decimal('100.00'))

    # =========================================================================
    # PART 7: CUSTOM BRANDED BOTTLE ORDERS & MARGIN VS MARKUP QUOTATIONS
    # =========================================================================

    def test_custom_branded_order_workflow_complete(self):
        """
        Step 1: Customer submits custom branded order request.
        Step 2: Admin reviews request.
        Step 3: Admin enters itemized costs and calculates quotation.
        Step 4: Verify Margin vs Markup math:
                C = 10,000, M = 20%
                Margin: Selling = 10,000 / (1 - 0.20) = 12,500.00 (unit: 12.50)
                Markup: Selling = 10,000 * (1 + 0.20) = 12,000.00 (unit: 12.00)
        Step 5: Verify customer privacy safeguards (internal costs hidden).
        Step 6: Customer accepts quotation -> Creates authoritative locked Order.
        Step 7: Verify immutable price snapshot.
        """
        # Step 1: Customer submits request
        req_res = self.client.post(
            '/api/orders/custom-requests/',
            data={
                'client_name': 'Acme Corporate Hydration',
                'bottle_size': '500ml',
                'package_type': 'BOTTLE',
                'quantity': 1000,
                'label_requirement': 'Silver foil logo with "Purity Guaranteed" badge',
                'printing_requirement': 'Glossy waterproof vinyl stickers',
                'delivery_address': 'Acme Towers, Telibandha, Raipur',
                'delivery_city': 'Raipur',
                'requested_delivery_date': '2026-11-15',
                'additional_notes': 'Palletized carton delivery required.'
            },
            content_type='application/json',
            **self.customer_header
        )
        self.assertEqual(req_res.status_code, 201)
        request_id = req_res.data['request']['id']

        custom_req = CustomBrandedOrderRequest.objects.get(id=request_id)
        self.assertEqual(custom_req.status, 'submitted')
        self.assertEqual(custom_req.quantity, 1000)

        # Step 2 & 3: Admin enters costs and selects MARGIN (20%)
        cost_payload = {
            'bottle_water_cost': '4000.00',
            'sticker_material_cost': '1500.00',
            'printing_cost': '1200.00',
            'packaging_cost': '800.00',
            'labour_production_cost': '1000.00',
            'transport_delivery_cost': '1000.00',
            'setup_design_cost': '500.00',
            'wastage_allowance_cost': '0.00',
            'other_charges': '0.00',
            'calculation_type': 'MARGIN',
            'target_percentage': '20.00',
            'include_breakdown_to_customer': False,  # Internal costs hidden!
            'quotation_validity_days': 30,
            'payment_terms': '50% advance, balance on dispatch',
            'delivery_estimate_days': 7,
            'admin_notes': 'Raw materials reserved at Central Plant inventory.',
            'customer_notes': 'Includes free door delivery in Raipur.',
            'action': 'SEND_TO_CUSTOMER'
        }
        quote_res = self.client.post(
            f'/api/orders/custom-requests/{request_id}/quotations/',
            data=cost_payload,
            content_type='application/json',
            **self.admin_header
        )
        self.assertEqual(quote_res.status_code, 201)
        quote_data = quote_res.data['quotation']

        # Total Cost C = 4000 + 1500 + 1200 + 800 + 1000 + 1000 + 500 = 10,000.00
        self.assertEqual(Decimal(str(quote_data['total_cost'])), Decimal('10000.00'))
        # Margin: Selling = 10000 / (1 - 0.20) = 12,500.00
        self.assertEqual(Decimal(str(quote_data['final_quotation_total'])), Decimal('12500.00'))
        # Unit Quote = 12500 / 1000 = 12.50
        self.assertEqual(Decimal(str(quote_data['unit_quotation_price'])), Decimal('12.50'))
        self.assertEqual(quote_data['status'], 'SENT')

        # Test Markup alternative calculation
        markup_payload = dict(cost_payload)
        markup_payload['calculation_type'] = 'MARKUP'
        markup_payload['target_percentage'] = '20.00'
        markup_res = self.client.post(
            f'/api/orders/custom-requests/{request_id}/quotations/',
            data=markup_payload,
            content_type='application/json',
            **self.admin_header
        )
        self.assertEqual(markup_res.status_code, 201)
        markup_quote_data = markup_res.data['quotation']
        # Markup: Selling = 10000 * (1 + 0.20) = 12,000.00 (unit: 12.00)
        self.assertEqual(Decimal(str(markup_quote_data['final_quotation_total'])), Decimal('12000.00'))
        self.assertEqual(Decimal(str(markup_quote_data['unit_quotation_price'])), Decimal('12.00'))
        # Markup quote is now version 2!
        self.assertEqual(markup_quote_data['version'], 2)
        v2_quotation_id = markup_quote_data['id']

        # Step 5: Safeguard check: Customer viewing quotation does NOT see internal costs
        cust_view_res = self.client.get(
            '/api/orders/custom-requests/',
            **self.customer_header
        )
        self.assertEqual(cust_view_res.status_code, 200)
        req_item = cust_view_res.data['requests'][0]
        active_q = req_item['active_quotation']
        self.assertNotIn('bottle_water_cost', active_q)
        self.assertNotIn('printing_cost', active_q)
        self.assertNotIn('total_cost', active_q)
        self.assertNotIn('admin_notes', active_q)
        self.assertEqual(Decimal(str(active_q['final_quotation_total'])), Decimal('12000.00'))
        self.assertEqual(Decimal(str(active_q['unit_quotation_price'])), Decimal('12.00'))

        # Step 6: Customer accepts quotation -> Converts to authoritative Order
        accept_res = self.client.post(
            f'/api/orders/custom-quotations/{v2_quotation_id}/action/',
            data={'action': 'accept'},
            content_type='application/json',
            **self.customer_header
        )
        self.assertEqual(accept_res.status_code, 201)
        created_order_id = accept_res.data['order_id']
        
        # Verify database Order record
        order = Order.objects.get(id=created_order_id)
        self.assertEqual(order.grand_total, Decimal('12000.00'))
        self.assertEqual(order.client_name, 'Acme Corporate Hydration')
        self.assertEqual(order.order_source, 'DIRECT_COMPANY')
        self.assertEqual(order.status, 'order_placement')
        self.assertEqual(order.payment_status, 'pending')

        order_item = order.items.first()
        self.assertEqual(order_item.quantity, 1000)
        self.assertEqual(order_item.unit_price, Decimal('12.00'))
        self.assertEqual(order_item.total_price, Decimal('12000.00'))

        # Step 7: Price changes to standard catalog do not affect locked custom order
        self.product.price = Decimal('999.00')
        self.product.save()
        order.refresh_from_db()
        self.assertEqual(order.grand_total, Decimal('12000.00'))
        order_item.refresh_from_db()
        self.assertEqual(order_item.total_price, Decimal('12000.00'))

    def test_invalid_costs_and_percentages_rejected(self):
        """Backend rejects negative costs, zero quantity, and margin >= 100%."""
        # 1. Zero quantity rejected
        zero_res = self.client.post(
            '/api/orders/custom-requests/',
            data={
                'client_name': 'Zero Qty Test',
                'quantity': 0,
                'bottle_size': '500ml',
                'delivery_address': 'Raipur'
            },
            content_type='application/json',
            **self.customer_header
        )
        self.assertEqual(zero_res.status_code, 400)

        # Create valid request
        req_res = self.client.post(
            '/api/orders/custom-requests/',
            data={
                'client_name': 'Validation Co',
                'quantity': 500,
                'bottle_size': '250ml',
                'delivery_address': 'Raipur'
            },
            content_type='application/json',
            **self.customer_header
        )
        req_id = req_res.data['request']['id']

        # 2. Negative cost rejected
        neg_res = self.client.post(
            f'/api/orders/custom-requests/{req_id}/quotations/',
            data={
                'bottle_water_cost': '-500.00',
                'calculation_type': 'MARGIN',
                'target_percentage': '20.00'
            },
            content_type='application/json',
            **self.admin_header
        )
        self.assertEqual(neg_res.status_code, 400)

        # 3. Margin >= 100% rejected (division by zero / negative denominator)
        inv_margin_res = self.client.post(
            f'/api/orders/custom-requests/{req_id}/quotations/',
            data={
                'bottle_water_cost': '1000.00',
                'calculation_type': 'MARGIN',
                'target_percentage': '100.00'
            },
            content_type='application/json',
            **self.admin_header
        )
        self.assertEqual(inv_margin_res.status_code, 400)

    # =========================================================================
    # PART 5: SAFE ORDER PLACEMENT & PAYMENT IN SANDBOX
    # =========================================================================

    def test_sandbox_order_payment_via_wallet_no_real_money_spent(self):
        """Customer places order and pays using test Water Wallet with zero real money spent."""
        # Setup wallet with test credits
        wallet, _ = Wallet.objects.get_or_create(user=self.customer)
        wallet.balance = Decimal('500.00')
        wallet.save()

        # Create order
        order = Order.objects.create(
            created_by=self.customer,
            franchise_name='Shivnath Agency Central Plant',
            city='Raipur',
            amount=Decimal('100.00'),
            grand_total=Decimal('100.00'),
            status='order_placement',
            payment_status='pending',
            payment_mode='WALLET',
            order_source='DIRECT_COMPANY'
        )

        pay_res = self.client.post(
            '/api/orders/wallet/pay-order/',
            data={'order_id': order.id},
            content_type='application/json',
            **self.customer_header
        )
        self.assertEqual(pay_res.status_code, 200)

        order.refresh_from_db()
        self.assertEqual(order.payment_status, 'paid')
        self.assertEqual(order.payment_mode, 'WALLET')
        wallet.refresh_from_db()
        self.assertEqual(wallet.balance, Decimal('400.00'))

    def test_tampered_razorpay_verification_rejected(self):
        """Tampered or client-fabricated Razorpay signature is rejected with 400 Bad Request."""
        order = Order.objects.create(
            created_by=self.customer,
            franchise_name='Shivnath Agency Central Plant',
            city='Raipur',
            amount=Decimal('500.00'),
            grand_total=Decimal('500.00'),
            status='order_placement',
            payment_status='pending',
            payment_mode='RAZORPAY',
            order_source='DIRECT_COMPANY',
            razorpay_order_id='order_test_rzp_123'
        )

        with patch.dict(os.environ, {
            'RAZORPAY_KEY_ID': 'rzp_test_sample',
            'RAZORPAY_KEY_SECRET': 'sample_secret_key',
            'RAZORPAY_ENVIRONMENT': 'TEST'
        }):
            res = self.client.post(
                '/api/orders/razorpay/verify-payment/',
                data={
                    'order_id': order.id,
                    'razorpay_order_id': 'order_test_rzp_123',
                    'razorpay_payment_id': 'pay_fake_payment_456',
                    'razorpay_signature': 'forged_fake_signature_not_matching_hmac'
                },
                content_type='application/json',
                **self.customer_header
            )
            self.assertEqual(res.status_code, 400)
            order.refresh_from_db()
            self.assertEqual(order.payment_status, 'pending')  # Never marked as paid!

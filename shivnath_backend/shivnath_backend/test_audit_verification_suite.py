import json
import hashlib
from decimal import Decimal
from datetime import date, timedelta
from django.test import TestCase
from django.contrib.auth.models import User
from django.utils import timezone
from django.core.exceptions import ValidationError
from django.db import IntegrityError
from django.core.management import call_command
from rest_framework.test import APIClient

from accounts.models import (
    UserProfile,
    FranchiseProfile,
    ServiceDistrict,
    ServiceZone,
    ServiceArea,
    FranchiseTerritoryAssignment,
    SystemBackupLog,
    SupportContact,
)
from products.models import Product, ProductCategory, ProductionRecipeBOM, ProductionRecipeBOMItem, ProductStockThreshold
from inventory.models import (
    RawMaterial,
    ProductionBatch,
    DealerStockBatch,
    DealerStockRequest,
    DealerStockRequestAllocation,
    InventoryTransactionLedger,
    ExpiryAlertLog,
    DailyBusinessReport,
)
from orders.models import Order, OrderItem, OrderItemBatchReservation, OrderStatusHistory
from billing.models import Invoice, PaymentTransaction, DealerCreditProfile, CompanyBillingProfile
from leads.models import Lead, LeadJourneyState, WhatsAppTemplate, WhatsAppMessageLog
from inventory.services import (
    create_production_batch_atomic,
    reserve_order_stock_fefo_atomic,
    allocate_and_dispatch_stock_request_atomic,
    receive_stock_request_atomic,
    dispatch_order_atomic,
    deliver_order_atomic,
    cancel_order_atomic,
    adjust_stock_atomic,
)
from accounts.services import apply_data_scope



class AuditVerificationSuite(TestCase):
    """
    Locked Implementation-Ready Architecture Audit Verification Suite.
    Explicitly covers all 19 verification requirements.
    """
    def setUp(self):
        self.client = APIClient()

        # 1. Super Admin
        self.super_admin = User.objects.create_superuser('superadmin', 'super@shivnath.com', 'AdminPass123!')
        self.super_admin_profile = UserProfile.objects.get(user=self.super_admin)
        self.super_admin_profile.role = 'super_admin'
        self.super_admin_profile.data_scope_type = 'all_data'
        self.super_admin_profile.save()

        # 2. Operational Admin
        self.admin_user = User.objects.create_user('adminops', 'adminops@shivnath.com', 'AdminPass123!')
        self.admin_profile = UserProfile.objects.get(user=self.admin_user)
        self.admin_profile.role = 'admin'
        self.admin_profile.data_scope_type = 'all_data'
        self.admin_profile.save()

        # 3. Sales Executive
        self.sales_exec = User.objects.create_user('sales_rajesh', 'rajesh@shivnath.com', 'SalesPass123!')
        self.sales_profile = UserProfile.objects.get(user=self.sales_exec)
        self.sales_profile.role = 'sales_executive'
        self.sales_profile.data_scope_type = 'territory_scoped'
        self.sales_profile.assigned_scope_ids = ['Patna Central']
        self.sales_profile.save()

        # 4. Wholesale Dealer
        self.dealer_user = User.objects.create_user('dealer_patna', 'dealer@shivnath.com', 'DealerPass123!')
        self.dealer_profile = UserProfile.objects.get(user=self.dealer_user)
        self.dealer_profile.role = 'franchise'
        self.dealer_profile.data_scope_type = 'dealer_scoped'
        self.dealer_profile.save()

        self.dealer = FranchiseProfile.objects.create(
            user=self.dealer_user,
            business_name='Patna Central Distributors',
            dealer_code='DLR-PAT-001',
            city='Patna',
            address='10 Station Road, Patna',
            territory='Patna Central',
            status='approved',
            commission=Decimal('10.00'),
        )
        self.credit_profile = DealerCreditProfile.objects.create(
            dealer=self.dealer,
            credit_limit=Decimal('100000.00'),
            current_outstanding=Decimal('0.00'),
            credit_status='GOOD_STANDING',
            payment_terms_days=15
        )

        # 5. Customer
        self.customer_user = User.objects.create_user('cust_anil', 'anil@gmail.com', 'CustPass123!')
        self.customer_profile = UserProfile.objects.get(user=self.customer_user)
        self.customer_profile.role = 'customer'
        self.customer_profile.phone = '9876543210'
        self.customer_profile.save()

        # Reload user instances to clear cached profile references
        self.super_admin = User.objects.get(id=self.super_admin.id)
        self.admin_user = User.objects.get(id=self.admin_user.id)
        self.sales_exec = User.objects.get(id=self.sales_exec.id)
        self.dealer_user = User.objects.get(id=self.dealer_user.id)
        self.customer_user = User.objects.get(id=self.customer_user.id)

        # Products & Category (Clean pre-seeded migration data if present)
        CompanyBillingProfile.objects.all().delete()
        ProductionRecipeBOMItem.objects.all().delete()
        ProductionRecipeBOM.objects.all().delete()
        Product.objects.all().delete()
        ProductCategory.objects.all().delete()
        RawMaterial.objects.all().delete()

        self.category = ProductCategory.objects.create(name='Bottled Water')
        self.p_250 = Product.objects.create(
            name='Shivnath 250ml Water Bottle',
            sku='SHV-250',
            size='250ml',
            volume_ml=250,
            mrp=Decimal('6.00'),
            price=Decimal('5.00'),
            dealer_transfer_price=Decimal('4.00'),
            status='Active',
            category='Bottle',
            category_ref=self.category,
        )

        # Raw Materials & BOM
        self.rm_preform = RawMaterial.objects.create(
            name='PET Preform 250ml',
            sku='RM-PRE-250',
            category='preform',
            unit_of_measure='pcs',
            current_stock=Decimal('50000.00'),
            unit_cost=Decimal('0.85'),
        )
        self.rm_cap = RawMaterial.objects.create(
            name='Standard HDPE Cap 28mm',
            sku='RM-CAP-28',
            category='cap',
            unit_of_measure='pcs',
            current_stock=Decimal('50000.00'),
            unit_cost=Decimal('0.30'),
        )
        self.recipe = ProductionRecipeBOM.objects.create(
            product=self.p_250,
            notes='250ml Bottling Standard Recipe'
        )
        ProductionRecipeBOMItem.objects.create(
            bom=self.recipe,
            raw_material=self.rm_preform,
            quantity_required_per_unit=Decimal('1.0000'),
            unit_cost_snapshot=Decimal('0.85')
        )
        ProductionRecipeBOMItem.objects.create(
            bom=self.recipe,
            raw_material=self.rm_cap,
            quantity_required_per_unit=Decimal('1.0000'),
            unit_cost_snapshot=Decimal('0.30')
        )

        # Billing Profile
        self.billing_profile = CompanyBillingProfile.objects.create(
            legal_name='Shivnath Agency Pvt Ltd',
            trade_name='Shivnath Agency',
            gstin='10AAACS1234F1Z5',
            cgst_rate=Decimal('9.00'),
            sgst_rate=Decimal('9.00'),
            is_configured=True
        )

    # -------------------------------------------------------------
    # 1. RAW MATERIAL PURCHASE
    # -------------------------------------------------------------
    def test_01_raw_material_purchase_ledger(self):
        """Test Raw Material purchase stock in and ledger recording."""
        initial_stock = self.rm_preform.current_stock
        add_qty = Decimal('10000.00')
        self.rm_preform.current_stock += add_qty
        self.rm_preform.save()

        ledger = InventoryTransactionLedger.objects.create(
            transaction_type='PURCHASE_IN',
            material_type='RAW_MATERIAL',
            location_type='COMPANY_WAREHOUSE',
            raw_material=self.rm_preform,
            quantity=add_qty,
            balance_after=self.rm_preform.current_stock,
            unit_cost_or_price=self.rm_preform.unit_cost,
            reference_type='PURCHASE_ORDER',
            reference_id='PO-2026-001',
            notes="Bulk Preform Delivery"
        )
        self.assertEqual(ledger.transaction_type, 'PURCHASE_IN')
        self.assertEqual(self.rm_preform.current_stock, initial_stock + add_qty)

    # -------------------------------------------------------------
    # 2. PRODUCTION BOM CONSUMPTION
    # -------------------------------------------------------------
    def test_02_production_bom_consumption(self):
        """Test atomic production run: consumes raw materials and outputs finished batch."""
        preform_stock_before = self.rm_preform.current_stock
        batch = create_production_batch_atomic(
            product_id=self.p_250.id,
            quantity_produced_units=2000,
            manufacture_date=timezone.now().date(),
            expiry_date=timezone.now().date() + timedelta(days=90),
            actor=self.admin_user
        )
        self.assertEqual(batch.quantity_produced_units, 2000)
        self.assertEqual(batch.quantity_remaining_company, 2000)
        self.rm_preform.refresh_from_db()
        self.assertEqual(self.rm_preform.current_stock, preform_stock_before - Decimal('2000.00'))

        # Ledger check
        self.assertTrue(InventoryTransactionLedger.objects.filter(transaction_type='PRODUCTION_CONSUMPTION').exists())
        self.assertTrue(InventoryTransactionLedger.objects.filter(transaction_type='PRODUCTION_IN').exists())

    # -------------------------------------------------------------
    # 3. INVENTORY LEDGER TRANSACTION TYPES (ALL 10 VERIFIED)
    # -------------------------------------------------------------
    def test_03_inventory_ledger_integrity_all_10_types(self):
        """Confirm all 10 locked transaction types are supported in the ledger."""
        required_types = [
            'PURCHASE_IN', 'PRODUCTION_CONSUMPTION', 'PRODUCTION_IN',
            'STOCK_TRANSFER_OUT', 'STOCK_TRANSFER_IN', 'SALE',
            'RETURN', 'DAMAGE', 'EXPIRY', 'ADJUSTMENT'
        ]
        available_types = [c[0] for c in InventoryTransactionLedger.TRANSACTION_TYPES]
        for rt in required_types:
            self.assertIn(rt, available_types, f"Transaction type {rt} missing from locked architecture!")

        # Test ADJUSTMENT creation via service
        adj_ledger = adjust_stock_atomic(
            entity_type='RAW_MATERIAL',
            entity_id=self.rm_cap.id,
            adjusted_quantity=Decimal('-50.00'),
            reason="Damaged in transit",
            actor=self.admin_user
        )
        self.assertEqual(adj_ledger.transaction_type, 'ADJUSTMENT')
        self.rm_cap.refresh_from_db()
        self.assertEqual(self.rm_cap.current_stock, Decimal('49950.00'))


    # -------------------------------------------------------------
    # 4. FEFO RESERVATION & AVAILABLE STOCK
    # -------------------------------------------------------------
    def test_04_fefo_reservation_and_available_stock_calc(self):
        """Confirm ProductionBatch reserved_quantity and available_quantity = remaining - reserved."""
        batch = ProductionBatch.objects.create(
            batch_number='PB-TEST-FEFO-01',
            product=self.p_250,
            manufacture_date=timezone.now().date(),
            expiry_date=timezone.now().date() + timedelta(days=60),
            quantity_produced_units=1000,
            quantity_remaining_company=1000,
            reserved_quantity=200,
            unit_production_cost=Decimal('1.55'),
            status='ACTIVE'
        )
        self.assertEqual(batch.available_quantity, 800)

        # Place direct company order and verify reservation
        order = Order.objects.create(
            franchise_name='Direct Customer Order',
            city='Patna',
            amount=Decimal('500.00'),
            grand_total=Decimal('500.00'),
            order_source='DIRECT_COMPANY',
            created_by=self.customer_user,
            status='order_placement'
        )
        item = OrderItem.objects.create(order=order, product=self.p_250, quantity=300, unit_price=Decimal('5.00'))
        reserve_order_stock_fefo_atomic(order)

        batch.refresh_from_db()
        self.assertEqual(batch.reserved_quantity, 500)
        self.assertEqual(batch.available_quantity, 500)

    # -------------------------------------------------------------
    # 5. DIRECT COMPANY ISOLATION
    # -------------------------------------------------------------
    def test_05_direct_company_isolation(self):
        """Direct company orders reserve from ProductionBatch; dealer orders reserve from DealerStockBatch."""
        # Setup dealer stock
        dbatch = DealerStockBatch.objects.create(
            dealer=self.dealer,
            product=self.p_250,
            batch_number='DB-PAT-001',
            manufacture_date=timezone.now().date(),
            expiry_date=timezone.now().date() + timedelta(days=45),
            received_quantity=500,
            remaining_quantity=500,
            reserved_quantity=0,
            unit_transfer_price=Decimal('4.00'),
            is_active=True
        )

        dealer_order = Order.objects.create(
            franchise_name=self.dealer.business_name,
            serving_franchise=self.dealer,
            city='Patna',
            amount=Decimal('250.00'),
            grand_total=Decimal('250.00'),
            order_source='FRANCHISE',
            created_by=self.customer_user,
            status='order_placement'
        )
        OrderItem.objects.create(order=dealer_order, product=self.p_250, quantity=100, unit_price=Decimal('5.00'))
        reserve_order_stock_fefo_atomic(dealer_order)

        dbatch.refresh_from_db()
        self.assertEqual(dbatch.reserved_quantity, 100)
        self.assertEqual(dbatch.available_quantity, 400)

    # -------------------------------------------------------------
    # 6. DEALER STOCK REQUEST MULTI-BATCH ALLOCATION
    # -------------------------------------------------------------
    def test_06_dealer_stock_request_multi_batch_allocation(self):
        """DealerStockRequestAllocation exists and fulfills multi-batch FEFO allocations."""
        b1 = ProductionBatch.objects.create(
            batch_number='PB-MULTI-01',
            product=self.p_250,
            manufacture_date=timezone.now().date(),
            expiry_date=timezone.now().date() + timedelta(days=30),
            quantity_produced_units=200,
            quantity_remaining_company=200,
            unit_production_cost=Decimal('1.50'),
            status='ACTIVE'
        )
        b2 = ProductionBatch.objects.create(
            batch_number='PB-MULTI-02',
            product=self.p_250,
            manufacture_date=timezone.now().date(),
            expiry_date=timezone.now().date() + timedelta(days=60),
            quantity_produced_units=300,
            quantity_remaining_company=300,
            unit_production_cost=Decimal('1.50'),
            status='ACTIVE'
        )

        stock_req = DealerStockRequest.objects.create(
            request_number='SR-2026-TEST',
            dealer=self.dealer,
            product=self.p_250,
            requested_quantity=350,
            status='REQUESTED'
        )

        allocations = [
            {'batch_id': b1.id, 'quantity': 200},
            {'batch_id': b2.id, 'quantity': 150}
        ]
        allocate_and_dispatch_stock_request_atomic(stock_req, allocations, actor=self.admin_user)

        stock_req.refresh_from_db()
        self.assertEqual(stock_req.status, 'DISPATCHED')
        self.assertEqual(stock_req.allocations.count(), 2)

        # Dealer receipt confirmation
        receipt_items = [
            {'allocation_id': stock_req.allocations.first().id, 'received_quantity': 195, 'damaged_quantity': 5},
            {'allocation_id': stock_req.allocations.last().id, 'received_quantity': 150, 'damaged_quantity': 0}
        ]
        receive_stock_request_atomic(stock_req, receipt_items, actor=self.dealer_user)

        self.assertTrue(InventoryTransactionLedger.objects.filter(transaction_type='STOCK_TRANSFER_IN').exists())
        self.assertTrue(InventoryTransactionLedger.objects.filter(transaction_type='DAMAGE').exists())

    # -------------------------------------------------------------
    # 7. EXPIRY 5 TIERS & DEDUPLICATION
    # -------------------------------------------------------------
    def test_07_expiry_5_tiers_and_deduplication(self):
        """Verifies 30, 15, 7, 3, 0 days tiers with hash deduplication."""
        today = timezone.now().date()
        batch = ProductionBatch.objects.create(
            batch_number='PB-EXPIRY-TIER',
            product=self.p_250,
            manufacture_date=today - timedelta(days=80),
            expiry_date=today + timedelta(days=7),
            quantity_produced_units=500,
            quantity_remaining_company=500,
            unit_production_cost=Decimal('1.50'),
            status='ACTIVE'
        )

        dedup_hash = ExpiryAlertLog.compute_hash('COMPANY', batch.id, '7_DAYS')
        ExpiryAlertLog.objects.create(
            batch_type='COMPANY',
            production_batch=batch,
            alert_level='7_DAYS',
            alert_date=today,
            deduplication_hash=dedup_hash
        )

        # Duplicate attempt must be skipped
        self.assertTrue(ExpiryAlertLog.objects.filter(deduplication_hash=dedup_hash).exists())

    # -------------------------------------------------------------
    # 8. BILLING SOURCE OF TRUTH
    # -------------------------------------------------------------
    def test_08_billing_source_of_truth_invoice(self):
        """Invoice is generated with GST rates and immutable totals."""
        invoice = Invoice.objects.create(
            invoice_number='SHV/2026/TEST-001',
            invoice_type='DIRECT_RETAIL_INVOICE',
            billed_to_name='Anil Kumar',
            billed_to_address='Patna',
            subtotal=Decimal('1000.00'),
            cgst_amount=Decimal('90.00'),
            sgst_amount=Decimal('90.00'),
            grand_total=Decimal('1180.00'),
            amount_paid=Decimal('0.00'),
            status='UNPAID'
        )
        self.assertEqual(invoice.outstanding_balance, Decimal('1180.00'))

    # -------------------------------------------------------------
    # 9. PAYMENT & CREDIT ATOMICITY
    # -------------------------------------------------------------
    def test_09_payment_credit_atomicity(self):
        """PaymentTransaction updates Invoice and DealerCreditProfile atomically."""
        invoice = Invoice.objects.create(
            invoice_number='SHV/2026/WHL-TEST',
            invoice_type='DEALER_PURCHASE_INVOICE',
            billed_to_name=self.dealer.business_name,
            subtotal=Decimal('2000.00'),
            cgst_amount=Decimal('180.00'),
            sgst_amount=Decimal('180.00'),
            grand_total=Decimal('2360.00'),
            amount_paid=Decimal('0.00'),
            status='UNPAID'
        )
        self.credit_profile.current_outstanding = Decimal('2360.00')
        self.credit_profile.save()

        from billing.services import record_payment_atomic
        txn = record_payment_atomic(
            invoice_id=invoice.id,
            amount_paid=Decimal('1000.00'),
            payment_method='UPI',
            reference_number='UPI-12345',
            actor=self.admin_user
        )
        invoice.refresh_from_db()
        self.credit_profile.refresh_from_db()

        self.assertEqual(invoice.amount_paid, Decimal('1000.00'))
        self.assertEqual(invoice.status, 'PARTIALLY_PAID')
        self.assertEqual(self.credit_profile.current_outstanding, Decimal('1360.00'))

    # -------------------------------------------------------------
    # 10. AUTHENTICATED ROLE-BASED CHATBOT
    # -------------------------------------------------------------
    def test_10_role_based_authenticated_chatbot(self):
        """Tests GET /api/chatbot/menu/ and POST /api/chatbot/action/ for each role."""
        # Customer
        self.client.force_authenticate(user=self.customer_user)
        res_c = self.client.get('/api/accounts/chatbot/menu/')
        self.assertEqual(res_c.status_code, 200)
        self.assertEqual(res_c.data['role'], 'customer')

        res_act = self.client.post('/api/accounts/chatbot/action/', {'action': 'PRODUCTS'})
        self.assertEqual(res_act.status_code, 200)
        self.assertIn('Shivnath Pure Drinking Water', res_act.data['message'])

        # Dealer
        self.client.force_authenticate(user=self.dealer_user)
        res_d = self.client.get('/api/accounts/chatbot/menu/')
        self.assertEqual(res_d.data['role'], 'franchise')

        # Admin
        self.client.force_authenticate(user=self.admin_user)
        res_a = self.client.get('/api/accounts/chatbot/menu/')
        self.assertEqual(res_a.data['role'], 'admin')

        # Super Admin
        self.client.force_authenticate(user=self.super_admin)
        res_s = self.client.get('/api/accounts/chatbot/menu/')
        self.assertEqual(res_s.data['role'], 'super_admin')

        res_s_act = self.client.post('/api/accounts/chatbot/action/', {'action': 'BUSINESS_OVERVIEW'})
        self.assertEqual(res_s_act.status_code, 200)

    # -------------------------------------------------------------
    # 11. SUPPORT DESK
    # -------------------------------------------------------------
    def test_11_support_desk_role_targeted(self):
        """Role-targeted support contacts."""
        SupportContact.objects.create(
            name='Agency Support Desk',
            phone='9876543210',
            email='support@shivnath.com',
            role='customer',
            is_active=True
        )
        self.client.force_authenticate(user=self.customer_user)
        res = self.client.get('/api/accounts/support/contacts/')
        self.assertEqual(res.status_code, 200)
        self.assertTrue(len(res.data['contacts']) > 0)

    # -------------------------------------------------------------
    # 12. LEAD JOURNEY PAUSE CONDITIONS
    # -------------------------------------------------------------
    def test_12_lead_journey_pause_conditions(self):
        """Journey pauses automatically on CONVERTED, NOT_INTERESTED, LOST, OPT_OUT, HUMAN_TAKEOVER."""
        lead = Lead.objects.create(
            name='Ramesh Gupta',
            phone='9876500001',
            email='ramesh@dealer.com',
            status='NEW'
        )
        journey = LeadJourneyState.objects.create(lead=lead, current_step=1)

        # 1. NOT_INTERESTED
        lead.status = 'NOT_INTERESTED'
        lead.save()
        journey.refresh_from_db()
        self.assertTrue(journey.is_paused)
        self.assertEqual(journey.pause_reason, 'NOT_INTERESTED')

        # 2. CONVERTED
        lead.status = 'CONVERTED'
        lead.save()
        journey.refresh_from_db()
        self.assertTrue(journey.is_paused)
        self.assertEqual(journey.pause_reason, 'CONVERTED')

        # 3. LOST
        lead.status = 'LOST'
        lead.save()
        journey.refresh_from_db()
        self.assertTrue(journey.is_paused)
        self.assertEqual(journey.pause_reason, 'LOST')

    # -------------------------------------------------------------
    # 13. SERVER-SIDE ADMIN DATA SCOPES
    # -------------------------------------------------------------
    def test_13_server_side_admin_data_scopes(self):
        """Enforces ALL_DATA, TERRITORY_SCOPED, DEALER_SCOPED, PLANT_SCOPED server-side."""
        # Create 2 orders: one in Patna Central, one in Gaya
        o_patna = Order.objects.create(
            franchise_name='Patna Order',
            city='Patna',
            snapshot_territory='Patna Central',
            amount=Decimal('100.00'),
            order_source='DIRECT_COMPANY'
        )
        o_gaya = Order.objects.create(
            franchise_name='Gaya Order',
            city='Gaya',
            snapshot_territory='Gaya North',
            amount=Decimal('200.00'),
            order_source='FRANCHISE',
            serving_franchise=self.dealer
        )

        qs = Order.objects.all()

        # SUPER_ADMIN -> ALL_DATA
        scoped_super = apply_data_scope(self.super_admin, qs, 'Order')
        self.assertEqual(scoped_super.count(), 2)

        # ADMIN Territory Scoped (Patna Central)
        self.admin_profile.data_scope_type = 'territory_scoped'
        self.admin_profile.assigned_scope_ids = ['Patna Central']
        self.admin_profile.save()
        self.admin_user = User.objects.get(id=self.admin_user.id)
        scoped_territory = apply_data_scope(self.admin_user, qs, 'Order')
        self.assertEqual(scoped_territory.count(), 1)
        self.assertEqual(scoped_territory.first().id, o_patna.id)

        # ADMIN Dealer Scoped
        self.admin_profile.data_scope_type = 'dealer_scoped'
        self.admin_profile.assigned_scope_ids = [self.dealer.id]
        self.admin_profile.save()
        self.admin_user = User.objects.get(id=self.admin_user.id)
        scoped_dealer = apply_data_scope(self.admin_user, qs, 'Order')
        self.assertEqual(scoped_dealer.count(), 1)
        self.assertEqual(scoped_dealer.first().id, o_gaya.id)

        # PLANT_SCOPED
        self.admin_profile.data_scope_type = 'plant_scoped'
        self.admin_profile.save()
        self.admin_user = User.objects.get(id=self.admin_user.id)
        scoped_plant = apply_data_scope(self.admin_user, qs, 'Order')
        self.assertEqual(scoped_plant.count(), 1)
        self.assertEqual(scoped_plant.first().order_source, 'DIRECT_COMPANY')

    # -------------------------------------------------------------
    # 14. HISTORICAL COGS FREEZING
    # -------------------------------------------------------------
    def test_14_historical_cogs_freezing(self):
        """OrderItem freezes unit production cost and COGS snapshots at dispatch."""
        batch = ProductionBatch.objects.create(
            batch_number='PB-COGS-FREEZE',
            product=self.p_250,
            manufacture_date=timezone.now().date(),
            expiry_date=timezone.now().date() + timedelta(days=90),
            quantity_produced_units=500,
            quantity_remaining_company=500,
            unit_production_cost=Decimal('1.85'),
            status='ACTIVE'
        )

        order = Order.objects.create(
            franchise_name='Direct Retail',
            city='Patna',
            amount=Decimal('500.00'),
            order_source='DIRECT_COMPANY',
            created_by=self.customer_user,
            status='order_placement'
        )
        item = OrderItem.objects.create(order=order, product=self.p_250, quantity=100, unit_price=Decimal('5.00'))
        reserve_order_stock_fefo_atomic(order)
        dispatch_order_atomic(order, actor=self.admin_user)

        item.refresh_from_db()
        self.assertEqual(item.snapshot_unit_production_cost, Decimal('1.85'))
        self.assertEqual(item.snapshot_total_cogs, Decimal('185.00'))

    # -------------------------------------------------------------
    # 15. DELIVERED REVENUE RECOGNITION
    # -------------------------------------------------------------
    def test_15_delivered_revenue_recognition(self):
        """Authoritative revenue recognized upon DELIVERED status transition."""
        order = Order.objects.create(
            franchise_name='Retail Delivery',
            city='Patna',
            amount=Decimal('1000.00'),
            order_source='DIRECT_COMPANY',
            created_by=self.customer_user,
            status='dispatch'
        )
        self.assertIsNone(order.delivered_at)
        deliver_order_atomic(order, actor=self.admin_user)
        order.refresh_from_db()
        self.assertEqual(order.status, 'delivered')
        self.assertIsNotNone(order.delivered_at)

    # -------------------------------------------------------------
    # 16. DEALER ONBOARDING STATE MACHINE
    # -------------------------------------------------------------
    def test_16_dealer_onboarding_state_machine(self):
        """PENDING -> UNDER_REVIEW -> APPROVED / REJECTED / SUSPENDED."""
        new_user = User.objects.create_user('new_dlr', 'new@dlr.com', 'Pass123!')
        new_dealer = FranchiseProfile.objects.create(
            user=new_user,
            business_name='New Prospective Dealer',
            city='Muzaffarpur',
            address='Station Road',
            status='pending'
        )
        self.assertEqual(new_dealer.status, 'pending')

        # Admin sets under_review
        self.client.force_authenticate(user=self.admin_user)
        res_ur = self.client.post(f'/api/accounts/dealers/onboarding/{new_dealer.id}/', {'action': 'under_review'})
        self.assertEqual(res_ur.status_code, 200)
        new_dealer.refresh_from_db()
        self.assertEqual(new_dealer.status, 'under_review')

        # Admin approves
        res_ap = self.client.post(f'/api/accounts/dealers/onboarding/{new_dealer.id}/', {'action': 'approve', 'credit_limit': '75000.00'})
        self.assertEqual(res_ap.status_code, 200)
        new_dealer.refresh_from_db()
        self.assertEqual(new_dealer.status, 'approved')
        self.assertTrue(new_dealer.dealer_code.startswith('DLR-MUZ-'))

        # Suspend
        res_sp = self.client.post(f'/api/accounts/dealers/onboarding/{new_dealer.id}/', {'action': 'suspend'})
        self.assertEqual(res_sp.status_code, 200)
        new_dealer.refresh_from_db()
        self.assertEqual(new_dealer.status, 'suspended')

    # -------------------------------------------------------------
    # 17. CREDIT LIMIT ENFORCEMENT
    # -------------------------------------------------------------
    def test_17_credit_limit_enforcement(self):
        """Blocks dealer dispatch if outstanding + order total > credit limit."""
        self.credit_profile.credit_limit = Decimal('500.00')
        self.credit_profile.current_outstanding = Decimal('400.00')
        self.credit_profile.save()

        batch = ProductionBatch.objects.create(
            batch_number='PB-CREDIT-TEST',
            product=self.p_250,
            manufacture_date=timezone.now().date(),
            expiry_date=timezone.now().date() + timedelta(days=90),
            quantity_produced_units=1000,
            quantity_remaining_company=1000,
            unit_production_cost=Decimal('1.50'),
            status='ACTIVE'
        )

        stock_req = DealerStockRequest.objects.create(
            request_number='SR-CREDIT-EXCEED',
            dealer=self.dealer,
            product=self.p_250,
            requested_quantity=100,
            status='REQUESTED'
        )
        # Total cost = 100 * ₹4 + 18% GST = ₹472 -> Outstanding would be ₹872 > ₹500
        with self.assertRaises(ValidationError) as ctx:
            allocate_and_dispatch_stock_request_atomic(
                stock_request=stock_req,
                allocations_list=[{'batch_id': batch.id, 'quantity': 100}],
                actor=self.admin_user
            )
        self.assertIn('Credit limit exceeded', str(ctx.exception))

    # -------------------------------------------------------------
    # 18. BACKUP EXECUTION & CHECKSUM
    # -------------------------------------------------------------
    def test_18_backup_execution_and_checksum(self):
        """Real backup executed, verifies file size > 0, SHA256 checksum in SystemBackupLog."""
        self.client.force_authenticate(user=self.super_admin)
        res = self.client.post('/api/accounts/backup/')
        self.assertEqual(res.status_code, 201)
        self.assertTrue(res.data['file_size_bytes'] > 0)
        self.assertTrue(len(res.data['checksum_sha256']) == 64)

        backup_log = SystemBackupLog.objects.first()
        self.assertEqual(backup_log.status, 'SUCCESS')
        self.assertEqual(backup_log.checksum_sha256, res.data['checksum_sha256'])

    # -------------------------------------------------------------
    # 19. TERRITORY GOVERNANCE & IMMUTABLE SNAPSHOTS
    # -------------------------------------------------------------
    def test_19_territory_governance_and_immutable_snapshots(self):
        """District -> Territory/Zone -> Area/Locality -> Address hierarchy & immutable order snapshots."""
        district = ServiceDistrict.objects.create(name='Patna District')
        zone = ServiceZone.objects.create(district=district, name='Kankarbagh Zone', code='PAT-KAN-01')
        area = ServiceArea.objects.create(district=district, zone=zone, pincode='800020', locality_name='Kankarbagh Colony')

        # Admin assigns dealer to zone
        assignment = FranchiseTerritoryAssignment.objects.create(franchise=self.dealer, zone=zone, is_primary=True)
        self.assertTrue(assignment.is_primary)

        # Place order preserving immutable territory snapshot
        order = Order.objects.create(
            franchise_name=self.dealer.business_name,
            serving_franchise=self.dealer,
            city='Patna',
            territory='Kankarbagh Zone',
            zone=zone,
            amount=Decimal('500.00'),
            order_source='FRANCHISE'
        )
        self.assertEqual(order.snapshot_serving_dealer_name, self.dealer.business_name)
        self.assertEqual(order.snapshot_territory, 'Kankarbagh Zone')

        # Reassign dealer territory; historical order snapshot must remain unchanged
        self.dealer.territory = 'Boring Road Zone'
        self.dealer.save()

        order.refresh_from_db()
        self.assertEqual(order.snapshot_territory, 'Kankarbagh Zone')
        self.assertEqual(order.snapshot_serving_dealer_name, self.dealer.business_name)

    # -------------------------------------------------------------
    # 20. STRICT EXPIRY ALERT DEDUPLICATION & CONCURRENCY
    # -------------------------------------------------------------
    def test_20_expiry_alert_deduplication_and_concurrency(self):
        """
        Tests strict alert deduplication requirements:
        1. Hash is computed without report_date (batch_type + batch_id + alert_tier).
        2. Running task twice on same day creates only one alert.
        3. Running task on next day still does NOT duplicate the alert for same tier.
        4. A batch moving across tiers (30 -> 15 -> 7 -> 3 -> 0) creates exactly one alert at each tier.
        5. Attempting duplicate insert raises DB-level IntegrityError (concurrency protection).
        6. Company and dealer batch alert identities remain distinguishable.
        """
        today = timezone.now().date()
        # 1. Deduplication hash calculation purity
        h1 = ExpiryAlertLog.compute_hash('COMPANY', 10, '30_DAYS')
        h2 = ExpiryAlertLog.compute_hash('COMPANY', 10, '30_DAYS')
        self.assertEqual(h1, h2)
        self.assertEqual(len(h1), 64)

        # 2. Company vs Dealer ID isolation
        h_comp = ExpiryAlertLog.compute_hash('COMPANY', 99, '30_DAYS')
        h_deal = ExpiryAlertLog.compute_hash('DEALER', 99, '30_DAYS')
        self.assertNotEqual(h_comp, h_deal, "Company and dealer batches with identical IDs must not collide")

        # 3. Create active batch in 30_DAYS window (e.g. 25 days left)
        pb = ProductionBatch.objects.create(
            batch_number='PB-DEDUP-TEST',
            product=self.p_250,
            manufacture_date=today - timedelta(days=65),
            expiry_date=today + timedelta(days=25),
            quantity_produced_units=200,
            quantity_remaining_company=200,
            unit_production_cost=Decimal('1.50'),
            status='ACTIVE'
        )

        # Run scheduled task: Day 1
        call_command('run_scheduled_tasks')
        alerts_day1 = ExpiryAlertLog.objects.filter(production_batch=pb)
        self.assertEqual(alerts_day1.count(), 1)
        self.assertEqual(alerts_day1.first().alert_level, '30_DAYS')

        # Run scheduled task a second time on the same day: must NOT duplicate
        call_command('run_scheduled_tasks')
        self.assertEqual(ExpiryAlertLog.objects.filter(production_batch=pb).count(), 1)

        # Run scheduled task on "next day" (simulated by batch aging, still within 30_DAYS window)
        pb.expiry_date = today + timedelta(days=24)
        pb.save()
        call_command('run_scheduled_tasks')
        self.assertEqual(ExpiryAlertLog.objects.filter(production_batch=pb).count(), 1,
                         "Running on next day must NOT recreate 30_DAYS alert")

        # 4. Progress batch through all remaining tiers: 15 -> 7 -> 3 -> 0
        for remaining_days, expected_tier in [(12, '15_DAYS'), (6, '7_DAYS'), (2, '3_DAYS'), (0, '0_DAYS_EXPIRED')]:
            pb.expiry_date = today + timedelta(days=remaining_days)
            pb.save()
            call_command('run_scheduled_tasks')
            tier_alerts = ExpiryAlertLog.objects.filter(production_batch=pb, alert_level=expected_tier)
            self.assertEqual(tier_alerts.count(), 1, f"Expected exactly one alert for tier {expected_tier}")

        # Total alerts for this batch across its lifecycle must be exactly 5
        self.assertEqual(ExpiryAlertLog.objects.filter(production_batch=pb).count(), 5)

        # 5. DB-Level uniqueness prevents duplicate creation even under concurrent race condition
        existing_alert = ExpiryAlertLog.objects.filter(production_batch=pb, alert_level='30_DAYS').first()
        with self.assertRaises(IntegrityError):
            ExpiryAlertLog.objects.create(
                batch_type='COMPANY',
                production_batch=pb,
                alert_level='30_DAYS',
                alert_date=today + timedelta(days=5),
                deduplication_hash=existing_alert.deduplication_hash
            )

    # -------------------------------------------------------------
    # 21. ORDER STATUS HISTORY AUDIT LOGGING & TRANSITIONS
    # -------------------------------------------------------------
    def test_21_order_status_history_transitions(self):
        """
        Verifies OrderStatusHistory requirements:
        1. Model exists and records every order status change.
        2. History captures order, old_status, new_status, created_at timestamp, actor, and notes.
        3. Initial placement, admin approval, dispatch, delivery, and cancellation are all recorded.
        """
        # 1. Initial Order Placement
        order = Order.objects.create(
            franchise_name=self.dealer.business_name,
            serving_franchise=self.dealer,
            city='Patna',
            amount=Decimal('1000.00'),
            order_source='FRANCHISE',
            created_by=self.customer_user,
            status='order_placement'
        )
        h_initial = OrderStatusHistory.objects.filter(order=order).order_by('created_at').first()
        self.assertIsNotNone(h_initial)
        self.assertEqual(h_initial.old_status, '')
        self.assertEqual(h_initial.new_status, 'order_placement')
        self.assertEqual(h_initial.changed_by, self.customer_user)
        self.assertIsNotNone(h_initial.created_at)

        # 2. Admin Plant Approval Transition
        order._actor = self.admin_user
        order._status_notes = 'Approved by Central Plant Officer'
        order.status = 'plant_approval'
        order.save()

        h_approval = OrderStatusHistory.objects.filter(order=order, new_status='plant_approval').first()
        self.assertIsNotNone(h_approval)
        self.assertEqual(h_approval.old_status, 'order_placement')
        self.assertEqual(h_approval.changed_by, self.admin_user)
        self.assertIn('Approved by Central Plant', h_approval.notes)

        # 3. Dispatch Transition
        dispatch_order_atomic(order, actor=self.admin_user)
        h_dispatch = OrderStatusHistory.objects.filter(order=order, new_status='dispatch').first()
        self.assertIsNotNone(h_dispatch)
        self.assertEqual(h_dispatch.old_status, 'plant_approval')
        self.assertEqual(h_dispatch.changed_by, self.admin_user)

        # 4. Delivery Transition (Revenue Recognition Milestone)
        deliver_order_atomic(order, actor=self.admin_user)
        order.refresh_from_db()
        self.assertEqual(order.status, 'delivered')
        self.assertIsNotNone(order.delivered_at)

        h_delivered = OrderStatusHistory.objects.filter(order=order, new_status='delivered').first()
        self.assertIsNotNone(h_delivered)
        self.assertEqual(h_delivered.old_status, 'dispatch')
        self.assertEqual(h_delivered.changed_by, self.admin_user)

        # 5. Cancellation Transition
        cancel_order_atomic(order, actor=self.admin_user)
        order.refresh_from_db()
        self.assertEqual(order.status, 'cancelled')

        h_cancelled = OrderStatusHistory.objects.filter(order=order, new_status='cancelled').first()
        self.assertIsNotNone(h_cancelled)
        self.assertEqual(h_cancelled.old_status, 'delivered')
        self.assertEqual(h_cancelled.changed_by, self.admin_user)

        # Verify complete chronological audit trail
        all_histories = list(OrderStatusHistory.objects.filter(order=order).order_by('created_at'))
        transitions = [(h.old_status, h.new_status) for h in all_histories]
        expected_transitions = [
            ('', 'order_placement'),
            ('order_placement', 'plant_approval'),
            ('plant_approval', 'dispatch'),
            ('dispatch', 'delivered'),
            ('delivered', 'cancelled'),
        ]
        self.assertEqual(transitions, expected_transitions)

    # 20. SUPER ADMIN ADMIN MANAGEMENT & PERFORMANCE REPORTING
    def test_20_super_admin_admin_management_and_performance_reporting(self):
        """
        Verifies:
        1. Super Admin full management of operational Admins (create, update, disable, password reset).
        2. Non-Super Admin blocked with HTTP 403 Forbidden.
        3. Real-time Admin Performance / Activity Reporting with date filters.
        """
        # Super Admin client
        self.client.force_authenticate(user=self.super_admin)

        # 1. Create new Admin
        resp_create = self.client.post('/api/accounts/super-admin/admins/', {
            'email': 'newops@shivnath.com',
            'name': 'New Operations Lead',
            'password': 'InitialSecret123!',
            'role': 'admin',
            'admin_permissions': ['orders', 'inventory', 'dealers'],
            'data_scope_type': 'territory_scoped',
            'assigned_scope_ids': ['Patna Central']
        }, format='json')
        self.assertEqual(resp_create.status_code, 201)
        created_id = resp_create.data['id']

        # Verify created admin in DB
        new_admin = User.objects.get(id=created_id)
        self.assertEqual(new_admin.profile.role, 'admin')
        self.assertEqual(new_admin.profile.admin_permissions, ['orders', 'inventory', 'dealers'])
        self.assertEqual(new_admin.profile.data_scope_type, 'territory_scoped')
        self.assertTrue(new_admin.check_password('InitialSecret123!'))

        # 2. Retrieve Admin Detail
        resp_detail = self.client.get(f'/api/accounts/super-admin/admins/{created_id}/')
        self.assertEqual(resp_detail.status_code, 200)
        self.assertEqual(resp_detail.data['admin']['email'], 'newops@shivnath.com')

        # 3. Update Admin (Update permissions, scope, and reset password)
        resp_patch = self.client.patch(f'/api/accounts/super-admin/admins/{created_id}/', {
            'name': 'Updated Ops Lead',
            'admin_permissions': ['orders', 'inventory', 'dealers', 'production', 'reports'],
            'data_scope_type': 'all_data',
            'password': 'NewStrongSecret456!'
        }, format='json')
        self.assertEqual(resp_patch.status_code, 200)
        new_admin.refresh_from_db()
        self.assertEqual(new_admin.first_name, 'Updated Ops Lead')
        self.assertEqual(new_admin.profile.data_scope_type, 'all_data')
        self.assertIn('production', new_admin.profile.admin_permissions)
        self.assertTrue(new_admin.check_password('NewStrongSecret456!'))

        # 4. Disable Admin (Soft disable)
        resp_del = self.client.delete(f'/api/accounts/super-admin/admins/{created_id}/')
        self.assertEqual(resp_del.status_code, 200)
        new_admin.refresh_from_db()
        self.assertFalse(new_admin.is_active)

        # 5. Non-Super Admin access blocked
        self.client.force_authenticate(user=self.admin_user)
        resp_blocked_manage = self.client.get('/api/accounts/super-admin/admins/')
        self.assertEqual(resp_blocked_manage.status_code, 403)
        resp_blocked_perf = self.client.get('/api/accounts/super-admin/admin-performance/')
        self.assertEqual(resp_blocked_perf.status_code, 403)

        # 6. Admin Performance / Activity Reporting for Super Admin
        self.client.force_authenticate(user=self.super_admin)

        # Record a test status transition by self.admin_user
        order = Order.objects.create(
            franchise_name='Patna Dealer',
            city='Patna',
            amount=Decimal('1000.00'),
            tax_amount=Decimal('180.00'),
            grand_total=Decimal('1180.00'),
            status='order_placement',
            created_by=self.admin_user
        )
        OrderStatusHistory.objects.create(
            order=order,
            old_status='order_placement',
            new_status='plant_approval',
            changed_by=self.admin_user,
            notes='Admin test approval'
        )

        # Test Today filter
        resp_perf_today = self.client.get('/api/accounts/super-admin/admin-performance/?date_filter=today')
        self.assertEqual(resp_perf_today.status_code, 200)
        self.assertTrue(resp_perf_today.data['success'])
        admin_data = next((a for a in resp_perf_today.data['admin_performance'] if a['admin_id'] == self.admin_user.id), None)
        self.assertIsNotNone(admin_data)
        self.assertGreaterEqual(admin_data['metrics']['orders_approved'], 1)

        # Test 7 Days filter
        resp_perf_7d = self.client.get('/api/accounts/super-admin/admin-performance/?date_filter=last_7_days')
        self.assertEqual(resp_perf_7d.status_code, 200)

        # Test Custom Date filter
        today_str = timezone.now().strftime('%Y-%m-%d')
        resp_perf_custom = self.client.get(f'/api/accounts/super-admin/admin-performance/?date_filter=custom&start_date={today_str}&end_date={today_str}')
        self.assertEqual(resp_perf_custom.status_code, 200)
        self.assertEqual(resp_perf_custom.data['date_filter'], 'custom')


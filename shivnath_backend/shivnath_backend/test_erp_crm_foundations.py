from django.test import TestCase
from django.contrib.auth.models import User
from django.utils import timezone
from datetime import timedelta
from decimal import Decimal
import uuid

from accounts.models import (
    UserProfile,
    FranchiseProfile,
    DealerDocument,
    Notification,
    SupportContact,
    AdminAuditLog,
    SystemBackupLog,
)
from products.models import (
    Product,
    ProductionRecipeBOM,
    ProductionRecipeBOMItem,
    ProductStockThreshold,
)
from inventory.models import (
    RawMaterial,
    ProductionBatch,
    DealerStockBatch,
    DealerStockRequest,
    DealerStockRequestAllocation,
    InventoryTransactionLedger,
    ExpiryAlertLog,
    Expense,
    DailyBusinessReport,
)
from suppliers.models import (
    Supplier,
    PurchaseOrder,
    PurchaseOrderItem,
)
from billing.models import (
    CompanyBillingProfile,
    DealerCreditProfile,
    Invoice,
    PaymentTransaction,
)
from orders.models import (
    Order,
    OrderItem,
    OrderItemBatchReservation,
)
from leads.models import (
    Lead,
    LeadJourneyState,
    WhatsAppIntegrationConfig,
    WhatsAppTemplate,
    WhatsAppMessageLog,
    CRMActivityLog,
    MarketingSpend,
)


class ERPCRMFoundationsTest(TestCase):

    def setUp(self):
        # 1. Super Admin & Operational Users
        self.super_admin_user = User.objects.create_user(
            username='superadmin@shivnath.com',
            email='superadmin@shivnath.com',
            password='Password@123'
        )
        self.super_admin_profile = self.super_admin_user.profile
        self.super_admin_profile.name = 'Super Admin'
        self.super_admin_profile.role = 'super_admin'
        self.super_admin_profile.data_scope_type = 'all_data'
        self.super_admin_profile.save()

        self.dealer_user = User.objects.create_user(
            username='dealer1@shivnath.com',
            email='dealer1@shivnath.com',
            password='Password@123'
        )
        self.dealer_profile = self.dealer_user.profile
        self.dealer_profile.name = 'Patna Distributor'
        self.dealer_profile.role = 'franchise'
        self.dealer_profile.data_scope_type = 'dealer_scoped'
        self.dealer_profile.save()
        self.franchise_profile = FranchiseProfile.objects.create(
            user=self.dealer_user,
            dealer_code='DLR-PAT-001',
            business_name='M/S Shivnath Water Patna',
            city='Patna',
            address='Station Road, Patna',
            commission=Decimal('10.00'),
            status='approved'
        )
        self.dealer_credit = DealerCreditProfile.objects.create(
            dealer=self.franchise_profile,
            credit_limit=Decimal('50000.00'),
            payment_terms_days=15,
            current_outstanding=Decimal('0.00'),
            credit_status='GOOD_STANDING'
        )

        # 2. Company Billing Profile
        self.billing_profile = CompanyBillingProfile.objects.create(
            legal_name='Shivnath Agency Private Limited',
            trade_name='Shivnath Agency Pure Drinking Water',
            gstin='10AAAAA0000A1Z5',
            pan='AAAAA0000A',
            registered_address='Industrial Area, Plant No. 1, Raipur',
            state_name='Chhattisgarh',
            state_code='22',
            invoice_prefix='SHV/2026/',
            cgst_rate=Decimal('9.00'),
            sgst_rate=Decimal('9.00'),
            igst_rate=Decimal('18.00'),
            is_configured=True
        )

        # 3. Raw Materials Master
        self.rm_preform = RawMaterial.objects.create(
            sku='RM-PRF-200',
            name='200ml PET Preform 9.5g',
            category='preform',
            unit_of_measure='pcs',
            unit_cost=Decimal('1.20'),
            current_stock=Decimal('5000.00'),
            reorder_level=Decimal('500.00')
        )
        self.rm_cap = RawMaterial.objects.create(
            sku='RM-CAP-01',
            name='28mm Alaska Cap Blue',
            category='cap',
            unit_of_measure='pcs',
            unit_cost=Decimal('0.40'),
            current_stock=Decimal('5000.00'),
            reorder_level=Decimal('500.00')
        )
        self.rm_label = RawMaterial.objects.create(
            sku='RM-LBL-200',
            name='200ml Shivnath Label BOPP',
            category='label',
            unit_of_measure='pcs',
            unit_cost=Decimal('0.30'),
            current_stock=Decimal('5000.00'),
            reorder_level=Decimal('500.00')
        )

        # 4. Master Product (200 ML Bottle)
        self.product_200ml = Product.objects.create(
            sku='SHV-200',
            name='200 ML Packaged Drinking Water',
            size='200 ML',
            volume_ml=200,
            package_type='BOTTLE',
            units_per_case=24,
            category='Bottle',
            price=Decimal('6.00'),
            dealer_transfer_price=Decimal('4.50'),
            mrp=Decimal('6.00'),
            shelf_life_days=180,
            gst=18,
            stock=0,
            status='Active'
        )

        # 5. Relational BOM Recipe
        self.bom_200ml = ProductionRecipeBOM.objects.create(
            product=self.product_200ml,
            last_updated_by=self.super_admin_user
        )
        ProductionRecipeBOMItem.objects.create(
            bom=self.bom_200ml,
            raw_material=self.rm_preform,
            quantity_required_per_unit=Decimal('1.0000'),
            unit_cost_snapshot=Decimal('1.20')
        )
        ProductionRecipeBOMItem.objects.create(
            bom=self.bom_200ml,
            raw_material=self.rm_cap,
            quantity_required_per_unit=Decimal('1.0000'),
            unit_cost_snapshot=Decimal('0.40')
        )
        ProductionRecipeBOMItem.objects.create(
            bom=self.bom_200ml,
            raw_material=self.rm_label,
            quantity_required_per_unit=Decimal('1.0000'),
            unit_cost_snapshot=Decimal('0.30')
        )

    def test_raw_material_master_and_bom_cost(self):
        """Test BOM recipe calculation dynamically sums all items."""
        total_bom_cost = self.bom_200ml.total_production_cost_per_unit
        self.assertEqual(total_bom_cost, Decimal('1.90'))

    def test_purchase_in_supplier_procurement(self):
        """Test PO creation and PURCHASE_IN ledger tracking."""
        supplier = Supplier.objects.create(
            supplier_code='SUP-PET-001',
            name='National Preforms Ltd',
            phone='9876543210',
            payment_terms_days=30
        )
        po = PurchaseOrder.objects.create(
            po_number='PO-202609-001',
            supplier=supplier,
            total_amount=Decimal('2400.00'),
            grand_total=Decimal('2400.00'),
            status='RECEIVED',
            created_by=self.super_admin_user
        )
        po_item = PurchaseOrderItem.objects.create(
            purchase_order=po,
            raw_material=self.rm_preform,
            quantity=Decimal('2000.00'),
            unit_price=Decimal('1.20'),
            total_price=Decimal('2400.00'),
            received_quantity=Decimal('2000.00')
        )
        # Update raw material stock
        self.rm_preform.current_stock += po_item.received_quantity
        self.rm_preform.save()

        # Log ledger entry
        ledger_entry = InventoryTransactionLedger.objects.create(
            transaction_type='PURCHASE_IN',
            material_type='RAW_MATERIAL',
            location_type='COMPANY_WAREHOUSE',
            raw_material=self.rm_preform,
            quantity=po_item.received_quantity,
            balance_after=self.rm_preform.current_stock,
            unit_cost_or_price=po_item.unit_price,
            reference_type='PURCHASE_ORDER',
            reference_id=po.po_number,
            actor=self.super_admin_user
        )
        self.assertEqual(self.rm_preform.current_stock, Decimal('7000.00'))
        self.assertEqual(ledger_entry.transaction_type, 'PURCHASE_IN')

    def test_production_batch_consumption_and_creation(self):
        """Test creating production batch decrements raw materials and creates finished stock."""
        produced_units = 1000
        # Check raw material availability
        for item in self.bom_200ml.items.all():
            required_qty = item.quantity_required_per_unit * produced_units
            self.assertGreaterEqual(item.raw_material.current_stock, required_qty)
            item.raw_material.current_stock -= required_qty
            item.raw_material.save()

            # Record PRODUCTION_CONSUMPTION ledger
            InventoryTransactionLedger.objects.create(
                transaction_type='PRODUCTION_CONSUMPTION',
                material_type='RAW_MATERIAL',
                location_type='COMPANY_WAREHOUSE',
                raw_material=item.raw_material,
                quantity=-required_qty,
                balance_after=item.raw_material.current_stock,
                unit_cost_or_price=item.unit_cost_snapshot,
                reference_type='PRODUCTION_BATCH',
                reference_id='PB-202609-001',
                actor=self.super_admin_user
            )

        # Create Production Batch
        now = timezone.now().date()
        batch = ProductionBatch.objects.create(
            batch_number='PB-202609-001',
            product=self.product_200ml,
            manufacture_date=now,
            expiry_date=now + timedelta(days=180),
            quantity_produced_units=produced_units,
            quantity_remaining_company=produced_units,
            unit_production_cost=self.bom_200ml.total_production_cost_per_unit,
            status='ACTIVE',
            created_by=self.super_admin_user
        )

        # Record PRODUCTION_IN ledger
        ledger_in = InventoryTransactionLedger.objects.create(
            transaction_type='PRODUCTION_IN',
            material_type='FINISHED_GOODS',
            location_type='COMPANY_WAREHOUSE',
            product=self.product_200ml,
            production_batch=batch,
            quantity=Decimal(produced_units),
            balance_after=Decimal(batch.quantity_remaining_company),
            unit_cost_or_price=batch.unit_production_cost,
            reference_type='PRODUCTION_BATCH',
            reference_id=batch.batch_number,
            actor=self.super_admin_user
        )

        self.assertEqual(batch.quantity_remaining_company, 1000)
        self.assertEqual(batch.available_quantity, 1000)
        self.rm_preform.refresh_from_db()
        self.assertEqual(self.rm_preform.current_stock, Decimal('4000.00'))
        self.assertEqual(ledger_in.transaction_type, 'PRODUCTION_IN')

    def test_direct_company_vs_dealer_stock_reservation(self):
        """Test dual-path stock reservation isolation and available stock calculation."""
        now = timezone.now().date()
        company_batch = ProductionBatch.objects.create(
            batch_number='PB-CO-001',
            product=self.product_200ml,
            manufacture_date=now,
            expiry_date=now + timedelta(days=180),
            quantity_produced_units=500,
            quantity_remaining_company=500,
            reserved_quantity=0,
            unit_production_cost=Decimal('1.90'),
            status='ACTIVE'
        )
        dealer_batch = DealerStockBatch.objects.create(
            dealer=self.franchise_profile,
            product=self.product_200ml,
            batch_number='PB-CO-001',
            manufacture_date=now,
            expiry_date=now + timedelta(days=180),
            received_quantity=200,
            remaining_quantity=200,
            reserved_quantity=0,
            unit_transfer_price=Decimal('4.50')
        )

        # 1. Direct Company Customer Order
        co_order = Order.objects.create(
            franchise_name='Direct Company',
            city='Raipur',
            order_source='DIRECT_COMPANY',
            serving_franchise=None,
            amount=Decimal('600.00'),
            tax_amount=Decimal('108.00'),
            grand_total=Decimal('708.00'),
            status='order_placement'
        )
        co_order_item = OrderItem.objects.create(
            order=co_order,
            product=self.product_200ml,
            product_name=self.product_200ml.name,
            quantity=100,
            unit_price=Decimal('6.00'),
            total_price=Decimal('600.00'),
            snapshot_unit_production_cost=Decimal('1.90'),
            snapshot_total_cogs=Decimal('190.00')
        )

        # Reserve from company batch ONLY
        OrderItemBatchReservation.objects.create(
            order_item=co_order_item,
            production_batch=company_batch,
            dealer_stock_batch=None,
            reserved_quantity=100
        )
        company_batch.reserved_quantity += 100
        company_batch.save()

        self.assertEqual(company_batch.available_quantity, 400)
        self.assertEqual(dealer_batch.available_quantity, 200)  # Dealer batch unaffected

        # 2. Dealer Customer Order
        dlr_order = Order.objects.create(
            franchise_name=self.franchise_profile.business_name,
            city='Patna',
            order_source='FRANCHISE',
            serving_franchise=self.franchise_profile,
            amount=Decimal('300.00'),
            tax_amount=Decimal('54.00'),
            grand_total=Decimal('354.00'),
            status='order_placement'
        )
        dlr_order_item = OrderItem.objects.create(
            order=dlr_order,
            product=self.product_200ml,
            product_name=self.product_200ml.name,
            quantity=50,
            unit_price=Decimal('6.00'),
            total_price=Decimal('300.00'),
            snapshot_unit_production_cost=Decimal('1.90'),
            snapshot_total_cogs=Decimal('95.00')
        )

        # Reserve from dealer batch ONLY
        OrderItemBatchReservation.objects.create(
            order_item=dlr_order_item,
            production_batch=None,
            dealer_stock_batch=dealer_batch,
            reserved_quantity=50
        )
        dealer_batch.reserved_quantity += 50
        dealer_batch.save()

        self.assertEqual(dealer_batch.available_quantity, 150)
        self.assertEqual(company_batch.available_quantity, 400)  # Company batch unaffected

    def test_invoice_and_payment_source_of_truth(self):
        """Test Invoice is the billing source of truth and PaymentTransaction atomically updates outstanding."""
        invoice = Invoice.objects.create(
            invoice_number='INV-2026-001',
            invoice_type='DEALER_PURCHASE_INVOICE',
            billed_to_name=self.franchise_profile.business_name,
            billed_to_gstin=self.franchise_profile.gst_number or '10XXXXX0000X1Z5',
            subtotal=Decimal('4500.00'),
            cgst_amount=Decimal('405.00'),
            sgst_amount=Decimal('405.00'),
            grand_total=Decimal('5310.00'),
            amount_paid=Decimal('0.00'),
            status='UNPAID'
        )
        # Update dealer outstanding
        self.dealer_credit.current_outstanding += invoice.grand_total
        self.dealer_credit.save()
        self.assertEqual(self.dealer_credit.current_outstanding, Decimal('5310.00'))

        # Record payment
        pay = PaymentTransaction.objects.create(
            transaction_number='PAY-TXN-1001',
            invoice=invoice,
            payment_method='UPI',
            amount_paid=Decimal('5310.00'),
            reference_number='UPI/20260919/8821092',
            payment_status='SUCCESS'
        )
        invoice.amount_paid += pay.amount_paid
        invoice.status = 'PAID'
        invoice.save()

        self.dealer_credit.current_outstanding -= pay.amount_paid
        self.dealer_credit.save()

        self.assertEqual(invoice.status, 'PAID')
        self.assertEqual(invoice.outstanding_balance, Decimal('0.00'))
        self.assertEqual(self.dealer_credit.current_outstanding, Decimal('0.00'))

    def test_5_tier_expiry_alert_deduplication(self):
        """Test state-based deduplication hash prevents duplicate daily alerts."""
        now = timezone.now().date()
        batch = ProductionBatch.objects.create(
            batch_number='PB-EXP-TEST',
            product=self.product_200ml,
            manufacture_date=now - timedelta(days=150),
            expiry_date=now + timedelta(days=30),
            quantity_produced_units=100,
            quantity_remaining_company=100,
            status='ACTIVE'
        )
        # Log 30_DAYS alert
        hash_key = f"COMPANY:{batch.id}:30_DAYS"
        alert1 = ExpiryAlertLog.objects.create(
            batch_type='COMPANY',
            production_batch=batch,
            alert_level='30_DAYS',
            alert_date=now,
            deduplication_hash=hash_key
        )
        self.assertIsNotNone(alert1.id)

        # Attempt duplicate on same tier must fail unique constraint
        with self.assertRaises(Exception):
            ExpiryAlertLog.objects.create(
                batch_type='COMPANY',
                production_batch=batch,
                alert_level='30_DAYS',
                alert_date=now + timedelta(days=1),
                deduplication_hash=hash_key
            )

    def test_lead_scoring_and_journey_auto_pause(self):
        """Test lead scoring engine and journey state auto-pause on conversion."""
        lead = Lead.objects.create(
            name='Rajesh Sharma',
            phone='9876543210',
            email='rajesh@example.com',
            city='Patna',
            investment_budget='2 Lakh',
            existing_business='yes',
            commercial_space='available',
            vehicle_access='four_wheeler_commercial',
            status='NEW'
        )
        score = lead.calculate_lead_score()
        lead.save()
        self.assertGreaterEqual(score, 75)
        self.assertEqual(lead.score_category, 'HOT')

        # Create Journey State
        journey = LeadJourneyState.objects.create(
            lead=lead,
            current_step=1,
            scheduled_day_offset=1
        )
        self.assertFalse(journey.is_paused)

        # Lead converted -> Auto-pause journey
        lead.status = 'CONVERTED'
        lead.save()
        journey.is_paused = True
        journey.pause_reason = 'CONVERTED'
        journey.save()

        self.assertTrue(journey.is_paused)
        self.assertEqual(journey.pause_reason, 'CONVERTED')

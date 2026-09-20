import json
from decimal import Decimal
from datetime import date, timedelta
from django.test import TestCase
from django.contrib.auth.models import User
from django.utils import timezone
from rest_framework.test import APIClient

from accounts.models import UserProfile, FranchiseProfile, DealerDocument, SupportContact
from products.models import Product, ProductCategory, ProductionRecipeBOM, ProductionRecipeBOMItem
from inventory.models import (
    RawMaterial,
    ProductionBatch,
    DealerStockBatch,
    DealerStockRequest,
    DealerStockRequestAllocation,
    InventoryTransactionLedger,
    Expense,
)
from billing.models import Invoice, PaymentTransaction, DealerCreditProfile, CompanyBillingProfile
from leads.models import Lead, LeadJourneyState, WhatsAppTemplate, WhatsAppMessageLog, MarketingSpend


class Phase2ServicesAndApisTest(TestCase):
    def setUp(self):
        self.client = APIClient()

        # Super Admin
        self.super_admin = User.objects.create_superuser('superadmin', 'super@shivnath.com', 'AdminPass123!')
        self.super_admin_profile = UserProfile.objects.get(user=self.super_admin)
        self.super_admin_profile.role = 'super_admin'
        self.super_admin_profile.save()
        self.super_admin = User.objects.get(id=self.super_admin.id)

        # Operational Admin
        self.admin_user = User.objects.create_user('adminops', 'adminops@shivnath.com', 'AdminPass123!')
        self.admin_profile = UserProfile.objects.get(user=self.admin_user)
        self.admin_profile.role = 'admin'
        self.admin_profile.save()
        self.admin_user = User.objects.get(id=self.admin_user.id)

        # Wholesale Dealer
        self.dealer_user = User.objects.create_user('dealer_patna', 'dealer@shivnath.com', 'DealerPass123!')
        self.dealer_profile = UserProfile.objects.get(user=self.dealer_user)
        self.dealer_profile.role = 'franchise'
        self.dealer_profile.save()
        self.dealer_user = User.objects.get(id=self.dealer_user.id)

        self.franchise = FranchiseProfile.objects.create(
            user=self.dealer_user,
            business_name='Patna Central Distributors',
            dealer_code='DLR-PATNA-01',
            city='Patna',
            territory='Patna Central',
            status='approved',
            commission=Decimal('10.00'),
        )
        self.credit_profile, _ = DealerCreditProfile.objects.get_or_create(
            dealer=self.franchise,
            defaults={
                'payment_terms_days': 15,
                'credit_limit': Decimal('500000.00'),
            }
        )

        # Products
        self.category = ProductCategory.objects.create(name='Bottles')
        self.p_250 = Product.objects.create(
            name='Shivnath 250ml Water Bottle',
            sku='SHV-250',
            size='250ml',
            volume_ml=250,
            package_type='BOTTLE',
            units_per_case=24,
            category='Bottle',
            category_ref=self.category,
            price=Decimal('6.00'),
            dealer_transfer_price=Decimal('3.50'),
            mrp=Decimal('6.00'),
            gst=18,
            stock=1000
        )

        # Raw Materials
        self.rm_preform = RawMaterial.objects.create(
            name='PET Preform 250ml',
            sku='RM-PRF-250',
            category='preform',
            unit_of_measure='pcs',
            unit_cost=Decimal('1.20'),
            current_stock=Decimal('10000.00')
        )
        self.rm_cap = RawMaterial.objects.create(
            name='Plastic Cap 28mm',
            sku='RM-CAP-28',
            category='cap',
            unit_of_measure='pcs',
            unit_cost=Decimal('0.30'),
            current_stock=Decimal('10000.00')
        )

    def test_01_bom_recipe_and_pricing_api(self):
        """Test Super Admin BOM Recipe Editor & Master Pricing APIs."""
        self.client.force_authenticate(user=self.super_admin)

        # 1. Add BOM items
        url_bom_item = f"/api/products/{self.p_250.id}/bom-items/"
        resp1 = self.client.post(url_bom_item, {
            'raw_material_id': self.rm_preform.id,
            'quantity_required_per_unit': '1.0000',
            'unit_cost_snapshot': '1.20',
            'notes': 'Bottle preform'
        })
        self.assertEqual(resp1.status_code, 201)

        resp2 = self.client.post(url_bom_item, {
            'raw_material_id': self.rm_cap.id,
            'quantity_required_per_unit': '1.0000',
            'unit_cost_snapshot': '0.30',
            'notes': '28mm cap'
        })
        self.assertEqual(resp2.status_code, 201)
        # Total cost per unit: 1.20 + 0.30 = 1.50
        self.assertAlmostEqual(float(resp2.data['total_production_cost_per_unit']), 1.50, places=2)

        # 2. Retrieve Product BOM
        url_bom = f"/api/products/{self.p_250.id}/bom/"
        resp_bom = self.client.get(url_bom)
        self.assertEqual(resp_bom.status_code, 200)
        self.assertEqual(len(resp_bom.data['bom']['items']), 2)

        # 3. Master Pricing Update (Super Admin)
        url_pricing = f"/api/products/{self.p_250.id}/pricing/"
        resp_pricing = self.client.patch(url_pricing, {
            'price': '7.00',
            'dealer_transfer_price': '4.00',
            'mrp': '7.00',
            'gst': 18
        })
        self.assertEqual(resp_pricing.status_code, 200)
        self.p_250.refresh_from_db()
        self.assertEqual(self.p_250.price, Decimal('7.00'))
        self.assertEqual(self.p_250.dealer_transfer_price, Decimal('4.00'))

    def test_02_public_chatbot_lead_capture_and_scoring(self):
        """Test Public Inbound Chatbot API validation and deterministic scoring."""
        # 1. Validation failure: missing/invalid email & phone
        resp_invalid = self.client.post('/api/leads/public/chatbot/', {
            'name': 'Test Inquirer',
            'phone': '12345',
            'email': 'not-an-email'
        })
        self.assertEqual(resp_invalid.status_code, 400)
        self.assertFalse(resp_invalid.data['success'])

        # 2. Valid Dealer Lead creation -> HOT lead
        resp_valid = self.client.post('/api/leads/public/chatbot/', {
            'name': 'Rajesh Kumar',
            'phone': '9876543210',
            'email': 'rajesh@patnawater.com',
            'district': 'Patna',
            'territory': 'Patna Central',
            'locality': 'Boring Road',
            'inquiry_type': 'WHOLESALE_DEALER',
            'investment_budget': '5L - 10L',
            'existing_business': 'yes',
            'commercial_space': 'available'
        })
        self.assertEqual(resp_valid.status_code, 201)
        self.assertTrue(resp_valid.data['success'])
        lead_id = resp_valid.data['lead_id']

        lead = Lead.objects.get(id=lead_id)
        self.assertEqual(lead.score.upper(), 'HOT')
        self.assertEqual(lead.status, 'NEW')

        # Verify 15-day journey initiated
        journey = LeadJourneyState.objects.get(lead=lead)
        self.assertFalse(journey.is_paused)
        self.assertEqual(journey.current_step, 1)

    def test_03_whatsapp_webhook_interaction(self):
        """Test incoming WhatsApp reply webhook and auto-pause behavior."""
        lead = Lead.objects.create(
            name='Amit Verma',
            phone='9123456780',
            email='amit@verma.com',
            status='NEW',
            score='WARM'
        )
        journey = LeadJourneyState.objects.create(
            lead=lead,
            current_step=2,
            is_paused=False
        )

        # Incoming WhatsApp reply with high-intent keyword
        resp = self.client.post('/api/leads/whatsapp/webhook/', {
            'from': '9123456780',
            'text': 'I am interested in becoming a dealer, please arrange site visit.'
        })
        self.assertEqual(resp.status_code, 200)
        self.assertTrue(resp.data['success'])

        lead.refresh_from_db()
        journey.refresh_from_db()
        # Drip journey should be auto-paused to allow human sales executive intervention
        self.assertTrue(journey.is_paused)
        self.assertEqual(journey.pause_reason, 'HUMAN_TAKEOVER')

        # Message should be logged in WhatsAppMessageLog
        log_entry = WhatsAppMessageLog.objects.filter(recipient_phone='9123456780', direction='INBOUND').first()
        self.assertIsNotNone(log_entry)

    def test_04_marketing_spend_and_cac(self):
        """Test Marketing Spend tracking and Cost-Per-Lead (CPL) analytics."""
        self.client.force_authenticate(user=self.admin_user)

        # Create 2 leads in date range
        Lead.objects.create(name='L1', phone='9000000001', email='l1@test.com')
        Lead.objects.create(name='L2', phone='9000000002', email='l2@test.com')

        today = date.today()
        resp = self.client.post('/api/leads/marketing-spend/', {
            'campaign_name': 'Meta Summer Dealership Push',
            'campaign_source': 'META_ADS',
            'period_start': (today - timedelta(days=5)).isoformat(),
            'period_end': today.isoformat(),
            'total_spend_inr': '1000.00',
            'notes': 'Meta lead gen ad'
        })
        self.assertEqual(resp.status_code, 201)
        # CPL should be 1000 / 2 = 500.0
        self.assertEqual(resp.data['spend']['cpl'], 500.0)

    def test_05_dealer_stock_request_lifecycle(self):
        """Test Dealer Stock Request: Request -> Admin Dispatch -> Dealer Receipt."""
        # 1. Company plant creates a production batch
        p_batch = ProductionBatch.objects.create(
            batch_number='PB-2026-001',
            product=self.p_250,
            quantity_produced_units=1000,
            quantity_remaining_company=1000,
            manufacture_date=date.today(),
            expiry_date=date.today() + timedelta(days=180),
            unit_production_cost=Decimal('1.50'),
            status='ACTIVE'
        )

        # 2. Dealer creates a stock request
        self.client.force_authenticate(user=self.dealer_user)
        resp_req = self.client.post('/api/inventory/dealer-stock-requests/', {
            'product_id': self.p_250.id,
            'requested_quantity': 500,
            'dealer_notes': 'Stock needed for wedding season'
        })
        self.assertEqual(resp_req.status_code, 201)
        req_id = resp_req.data['id']

        # 3. Admin allocates and dispatches stock
        self.client.force_authenticate(user=self.admin_user)
        url_dispatch = f"/api/inventory/dealer-stock-requests/{req_id}/dispatch/"
        resp_dispatch = self.client.post(url_dispatch, {
            'allocations': [
                {'batch_id': p_batch.id, 'quantity': 500}
            ]
        }, format='json')
        self.assertEqual(resp_dispatch.status_code, 200)

        # Check invoice was generated
        invoice_id = resp_dispatch.data['invoice_id']
        invoice = Invoice.objects.get(id=invoice_id)
        self.assertEqual(invoice.invoice_type, 'DEALER_PURCHASE_INVOICE')
        # 500 units * 3.50 = 1750.00 subtotal + 18% GST (315.00) = 2065.00
        self.assertEqual(invoice.grand_total, Decimal('2065.00'))

        # Check company batch quantity deducted
        p_batch.refresh_from_db()
        self.assertEqual(p_batch.quantity_remaining_company, 500)

        stock_req = DealerStockRequest.objects.get(id=req_id)
        # Check STOCK_TRANSFER_OUT in ledger
        ledger_entry = InventoryTransactionLedger.objects.filter(
            transaction_type='STOCK_TRANSFER_OUT',
            reference_id=stock_req.request_number
        ).first()
        self.assertIsNotNone(ledger_entry)

        # 4. Dealer receives stock (480 good, 20 damaged)
        self.client.force_authenticate(user=self.dealer_user)
        alloc = DealerStockRequestAllocation.objects.filter(stock_request_id=req_id).first()
        url_receive = f"/api/inventory/dealer-stock-requests/{req_id}/receive/"
        resp_receive = self.client.post(url_receive, {
            'receipt_items': [
                {
                    'allocation_id': alloc.id,
                    'received_quantity': 480,
                    'damaged_quantity': 20,
                    'damage_notes': 'Carton crushed in transit'
                }
            ]
        }, format='json')
        self.assertEqual(resp_receive.status_code, 200)

        # Dealer batch created with 480 units
        dealer_batch = DealerStockBatch.objects.filter(dealer=self.franchise, product=self.p_250).first()
        self.assertIsNotNone(dealer_batch)
        self.assertEqual(dealer_batch.received_quantity, 480)
        self.assertEqual(dealer_batch.remaining_quantity, 480)

        # Damage logged in ledger
        damage_entry = InventoryTransactionLedger.objects.filter(
            transaction_type='DAMAGE',
            reference_id=stock_req.request_number
        ).first()
        self.assertIsNotNone(damage_entry)
        self.assertEqual(damage_entry.quantity, Decimal('-20.00'))

    def test_06_billing_payment_and_aging(self):
        """Test recording payment against invoice, updating dealer outstanding and aging report."""
        self.client.force_authenticate(user=self.admin_user)

        # Create wholesale invoice for dealer
        invoice = Invoice.objects.create(
            invoice_number='INV-TEST-001',
            invoice_type='DEALER_PURCHASE_INVOICE',
            billed_to_name=self.franchise.business_name,
            subtotal=Decimal('10000.00'),
            cgst_amount=Decimal('900.00'),
            sgst_amount=Decimal('900.00'),
            grand_total=Decimal('11800.00'),
            status='UNPAID',
            due_date=date.today() + timedelta(days=15)
        )
        self.credit_profile.current_outstanding = Decimal('11800.00')
        self.credit_profile.save()

        # Record partial payment of 5000
        url_payment = f"/api/billing/invoices/{invoice.id}/payments/"
        resp_pay = self.client.post(url_payment, {
            'amount': '5000.00',
            'payment_mode': 'NEFT_RTGS',
            'transaction_reference': 'UTR1234567890',
            'notes': 'First installment'
        })
        self.assertEqual(resp_pay.status_code, 201)

        invoice.refresh_from_db()
        self.assertEqual(invoice.amount_paid, Decimal('5000.00'))
        self.assertEqual(invoice.status, 'PARTIALLY_PAID')

        self.credit_profile.refresh_from_db()
        self.assertEqual(self.credit_profile.current_outstanding, Decimal('6800.00'))

        # Fetch aging report
        resp_aging = self.client.get(f"/api/billing/dealers/{self.franchise.id}/aging/")
        self.assertEqual(resp_aging.status_code, 200)
        self.assertEqual(resp_aging.data['dealer_code'], 'DLR-PATNA-01')
        self.assertAlmostEqual(float(resp_aging.data['total_outstanding']), 6800.00, places=2)

from django.test import TestCase
from django.contrib.auth.models import User
from django.contrib.auth.hashers import make_password
from django.utils import timezone
from rest_framework.test import APIClient
from rest_framework import status
from decimal import Decimal
from datetime import timedelta

from accounts.models import UserProfile, AdminAuditLog, FranchiseProfile
from inventory.models import (
    InventoryItem,
    RawMaterial,
    ProductionBatch,
    InventoryTransactionLedger,
    StockRequest,
    DealerStockRequest,
    DealerStockBatch,
)
from products.models import Product, ProductCategory, ProductionRecipeBOM, ProductionRecipeBOMItem
from billing.models import Invoice, CompanyBillingProfile, DealerCreditProfile


class StockManagerAccessControlTestCase(TestCase):
    def setUp(self):
        self.client = APIClient()

        # 1. Super Admin Account
        self.super_admin_user = User.objects.create(
            username='superadmin_test',
            email='superadmin@waterwala.com',
            password=make_password('SuperPass123!'),
            is_active=True,
            is_staff=True,
            is_superuser=True,
        )
        self.super_admin_profile, _ = UserProfile.objects.get_or_create(user=self.super_admin_user)
        self.super_admin_profile.role = 'super_admin'
        self.super_admin_profile.status = 'active'
        self.super_admin_profile.name = 'Super Admin Test'
        self.super_admin_profile.save()
        self.super_admin_user = User.objects.select_related('profile').get(id=self.super_admin_user.id)

        # 2. Main Admin Account
        self.admin_user = User.objects.create(
            username='admin_test',
            email='admin@waterwala.com',
            password=make_password('AdminPass123!'),
            is_active=True,
            is_staff=True,
        )
        self.admin_profile, _ = UserProfile.objects.get_or_create(user=self.admin_user)
        self.admin_profile.role = 'admin'
        self.admin_profile.status = 'active'
        self.admin_profile.name = 'Plant Admin Test'
        self.admin_profile.save()
        self.admin_user = User.objects.select_related('profile').get(id=self.admin_user.id)

        # 3. Stock Manager Account
        self.stock_manager_user = User.objects.create(
            username='stockmgr_test',
            email='stockmgr@waterwala.com',
            password=make_password('StockPass123!'),
            is_active=True,
        )
        self.stock_manager_profile, _ = UserProfile.objects.get_or_create(user=self.stock_manager_user)
        self.stock_manager_profile.role = 'stock_manager'
        self.stock_manager_profile.status = 'active'
        self.stock_manager_profile.name = 'Stock Manager Test'
        self.stock_manager_profile.save()
        self.stock_manager_user = User.objects.select_related('profile').get(id=self.stock_manager_user.id)

        # 4. Dealer / Franchise Account
        self.dealer_user = User.objects.create(
            username='dealer_test',
            email='dealer@waterwala.com',
            password=make_password('DealerPass123!'),
            is_active=True,
        )
        self.dealer_profile, _ = UserProfile.objects.get_or_create(user=self.dealer_user)
        self.dealer_profile.role = 'franchise'
        self.dealer_profile.status = 'active'
        self.dealer_profile.name = 'Dealer User'
        self.dealer_profile.save()
        self.dealer_user = User.objects.select_related('profile').get(id=self.dealer_user.id)

        self.franchise, _ = FranchiseProfile.objects.get_or_create(
            user=self.dealer_user,
            defaults={
                'business_name': 'Shivnath Water Dealer Raipur',
                'city': 'Raipur',
                'status': 'approved'
            }
        )

        # 5. Product & BOM
        self.category = ProductCategory.objects.create(
            name='Packaged Water',
            slug='packaged-water'
        )
        self.product = Product.objects.create(
            name='Water Wala 1L Premium Bottle',
            sku='WW-1L-001',
            price=Decimal('20.00'),
            dealer_transfer_price=Decimal('12.00'),
            mrp=Decimal('20.00'),
            units_per_case=24,
            category_ref=self.category,
        )

        # Raw Material
        self.raw_material = RawMaterial.objects.create(
            sku='RM-PET-PREFORM',
            name='PET Preform 20g',
            category='PREFORM',
            unit_of_measure='PCS',
            unit_cost=Decimal('1.85'),
            current_stock=Decimal('5000.00'),
            reorder_level=Decimal('1000.00'),
            is_active=True
        )

        # BOM Recipe linking product and raw material
        self.bom = ProductionRecipeBOM.objects.create(
            product=self.product,
            notes='Standard Recipe'
        )
        ProductionRecipeBOMItem.objects.create(
            bom=self.bom,
            raw_material=self.raw_material,
            quantity_required_per_unit=Decimal('1.0000'),
            unit_cost_snapshot=Decimal('1.85')
        )

        # Existing Production Batch
        today = timezone.now().date()
        self.batch = ProductionBatch.objects.create(
            batch_number='BATCH-202610-0001',
            product=self.product,
            manufacture_date=today - timedelta(days=2),
            expiry_date=today + timedelta(days=180),
            quantity_produced_units=2000,
            quantity_remaining_company=2000,
            reserved_quantity=0,
            quantity_dispatched=0,
            unit_production_cost=Decimal('8.50'),
            status='ACTIVE'
        )

        # Inventory Item (legacy model)
        self.inventory_item = InventoryItem.objects.create(
            name='Water Wala 1L Finished Goods',
            sku='INV-WW-1L',
            item_type='finished_product',
            stock=1500,
            min_stock=200,
            purchase_rate=Decimal('8.50')
        )

        # Invoice for financial negative testing
        self.invoice = Invoice.objects.create(
            invoice_number='INV-202610-0099',
            invoice_type='DEALER_PURCHASE',
            status='UNPAID',
            subtotal=Decimal('2400.00'),
            grand_total=Decimal('2832.00'),
            amount_paid=Decimal('0.00'),
            billed_to_name=self.franchise.business_name
        )

    # =========================================================================
    # 1. ADMIN LIFECYCLE MANAGEMENT OF STOCK MANAGER
    # =========================================================================

    def test_super_admin_creates_stock_manager(self):
        """Super Admin can provision a new Stock Manager account via /api/accounts/admins/."""
        self.client.force_authenticate(user=self.super_admin_user)
        payload = {
            'email': 'new_stock_mgr@waterwala.com',
            'username': 'new_stock_mgr',
            'name': 'New Warehouse Supervisor',
            'phone': '9876543210',
            'password': 'SecurePassword123!',
            'confirm_password': 'SecurePassword123!',
            'role': 'stock_manager',
            'status': 'active',
            'data_scope_type': 'all_data',
        }
        resp = self.client.post('/api/accounts/super-admin/admins/', payload, format='json')
        self.assertEqual(resp.status_code, status.HTTP_201_CREATED)
        self.assertTrue(resp.data.get('success'))

        # Verify DB records
        created_user = User.objects.get(email='new_stock_mgr@waterwala.com')
        self.assertEqual(created_user.profile.role, 'stock_manager')
        self.assertEqual(created_user.profile.status, 'active')
        self.assertTrue(created_user.is_active)

    def test_super_admin_lists_stock_managers(self):
        """Super Admin can view stock managers in the admin management directory."""
        self.client.force_authenticate(user=self.super_admin_user)
        resp = self.client.get('/api/accounts/super-admin/admins/')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        emails = [a['email'] for a in resp.data.get('admins', [])]
        self.assertIn('stockmgr@waterwala.com', emails)

    def test_super_admin_deactivates_and_revokes_stock_manager(self):
        """Super Admin can deactivate or soft-delete a Stock Manager account."""
        self.client.force_authenticate(user=self.super_admin_user)

        # Deactivate via PATCH
        resp = self.client.patch(f'/api/accounts/super-admin/admins/{self.stock_manager_user.id}/', {
            'status': 'inactive',
            'is_active': False
        }, format='json')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)

        self.stock_manager_user.refresh_from_db()
        self.stock_manager_profile.refresh_from_db()
        self.assertFalse(self.stock_manager_user.is_active)
        self.assertEqual(self.stock_manager_profile.status, 'inactive')

        # Deactivated user is denied on stock endpoints
        self.client.force_authenticate(user=self.stock_manager_user)
        resp = self.client.get('/api/inventory/items/')
        self.assertEqual(resp.status_code, status.HTTP_403_FORBIDDEN)

    # =========================================================================
    # 2. POSITIVE PERMISSION TESTS (AUTHORIZED INVENTORY OPERATIONS)
    # =========================================================================

    def test_stock_manager_can_view_inventory_items_and_stats(self):
        """Stock Manager can view inventory item lists and summary statistics."""
        self.client.force_authenticate(user=self.stock_manager_user)

        resp = self.client.get('/api/inventory/items/')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        self.assertTrue(resp.data.get('success'))

        resp = self.client.get('/api/inventory/stats/')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        self.assertTrue(resp.data.get('success'))

    def test_stock_manager_can_create_and_receive_raw_materials(self):
        """Stock Manager can record incoming raw materials."""
        self.client.force_authenticate(user=self.stock_manager_user)
        payload = {
            'sku': 'RM-CAP-BLUE-30MM',
            'name': 'HDPE 30mm Blue Bottle Caps',
            'category': 'cap',
            'unit_of_measure': 'pcs',
            'unit_cost': '0.45',
            'current_stock': '10000.00',
            'reorder_level': '2000.00',
            'is_active': True,
        }
        resp = self.client.post('/api/inventory/raw-materials/', payload, format='json')
        self.assertEqual(resp.status_code, status.HTTP_201_CREATED)

        # Verify DB persistence
        rm = RawMaterial.objects.get(sku='RM-CAP-BLUE-30MM')
        self.assertEqual(rm.name, 'HDPE 30mm Blue Bottle Caps')
        self.assertEqual(rm.current_stock, Decimal('10000.00'))

    def test_stock_manager_can_create_production_batch(self):
        """Stock Manager can record production output, consuming BOM raw materials atomically."""
        self.client.force_authenticate(user=self.stock_manager_user)
        initial_rm_stock = self.raw_material.current_stock

        payload = {
            'product_id': self.product.id,
            'quantity_produced_units': 500,
            'manufacture_date': str(timezone.now().date()),
            'expiry_date': str(timezone.now().date() + timedelta(days=180)),
            'batch_number': 'BATCH-TEST-500',
        }
        resp = self.client.post('/api/inventory/production-batches/', payload, format='json')
        self.assertEqual(resp.status_code, status.HTTP_201_CREATED)
        self.assertTrue(resp.data.get('success'))

        # Verify DB batch created
        batch = ProductionBatch.objects.get(batch_number='BATCH-TEST-500')
        self.assertEqual(batch.quantity_produced_units, 500)
        self.assertEqual(batch.quantity_remaining_company, 500)

        # Verify BOM consumption of raw material (500 units consumed)
        self.raw_material.refresh_from_db()
        self.assertEqual(self.raw_material.current_stock, initial_rm_stock - Decimal('500.00'))

    def test_stock_manager_can_record_batch_collection(self):
        """Stock Manager can record finished goods dispatch/collection from central batch."""
        self.client.force_authenticate(user=self.stock_manager_user)
        initial_remaining = self.batch.quantity_remaining_company

        payload = {
            'quantity_collected': 300,
            'client_name': 'Digital Marketing Wala Event',
            'notes': 'Authorized collection for event supply'
        }
        resp = self.client.post(f'/api/inventory/production-batches/{self.batch.id}/collection/', payload, format='json')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        self.assertTrue(resp.data.get('success'))

        # Verify remaining stock decreased
        self.batch.refresh_from_db()
        self.assertEqual(self.batch.quantity_remaining_company, initial_remaining - 300)

    def test_stock_manager_can_adjust_stock_with_mandatory_reason(self):
        """Stock Manager can record manual stock corrections with mandatory audit reasons."""
        self.client.force_authenticate(user=self.stock_manager_user)
        initial_rm_stock = self.raw_material.current_stock

        payload = {
            'entity_type': 'RAW_MATERIAL',
            'entity_id': self.raw_material.id,
            'adjusted_quantity': '-50.00',
            'reason': 'Damaged preforms discarded during quality check',
        }
        resp = self.client.post('/api/inventory/stock/adjust/', payload, format='json')
        self.assertEqual(resp.status_code, status.HTTP_201_CREATED)
        self.assertTrue(resp.data.get('success'))

        # Verify DB balance updated
        self.raw_material.refresh_from_db()
        self.assertEqual(self.raw_material.current_stock, initial_rm_stock - Decimal('50.00'))

        # Verify audit ledger entry created
        ledger = InventoryTransactionLedger.objects.filter(
            transaction_type='ADJUSTMENT',
            raw_material=self.raw_material
        ).latest('timestamp')
        self.assertEqual(ledger.actor, self.stock_manager_user)
        self.assertEqual(ledger.notes, 'Damaged preforms discarded during quality check')
        self.assertEqual(ledger.balance_after, self.raw_material.current_stock)

    def test_stock_manager_can_view_pending_expiry_alerts(self):
        """Stock Manager can view real DB-backed expiry alerts."""
        self.client.force_authenticate(user=self.stock_manager_user)
        resp = self.client.get('/api/inventory/pending-stock-expiry-alerts/')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        self.assertTrue(resp.data.get('success'))

    # =========================================================================
    # 3. NEGATIVE PERMISSION TESTS (ACCESS OUTSIDE SCOPE STRICTLY DENIED)
    # =========================================================================

    def test_stock_manager_denied_invoices_list(self):
        """Stock Manager is denied access to customer/dealer invoices list (HTTP 403)."""
        self.client.force_authenticate(user=self.stock_manager_user)
        resp = self.client.get('/api/billing/invoices/')
        self.assertEqual(resp.status_code, status.HTTP_403_FORBIDDEN)

    def test_stock_manager_denied_invoice_detail(self):
        """Stock Manager is denied access to individual invoice details (HTTP 403)."""
        self.client.force_authenticate(user=self.stock_manager_user)
        resp = self.client.get(f'/api/billing/invoices/{self.invoice.id}/')
        self.assertEqual(resp.status_code, status.HTTP_403_FORBIDDEN)

    def test_stock_manager_denied_recording_invoice_payments(self):
        """Stock Manager cannot record or manipulate invoice payments (HTTP 403)."""
        self.client.force_authenticate(user=self.stock_manager_user)
        payload = {
            'amount': '2832.00',
            'payment_method': 'CASH',
            'notes': 'Attempted unauthorized cash collection'
        }
        resp = self.client.post(f'/api/billing/invoices/{self.invoice.id}/payments/', payload, format='json')
        self.assertEqual(resp.status_code, status.HTTP_403_FORBIDDEN)

    def test_stock_manager_denied_daily_pl_report(self):
        """Stock Manager cannot view company profit and loss / COGS / revenue reports (HTTP 403)."""
        self.client.force_authenticate(user=self.stock_manager_user)
        resp = self.client.get('/api/inventory/daily-reports/')
        self.assertEqual(resp.status_code, status.HTTP_403_FORBIDDEN)

    def test_stock_manager_denied_company_expenses(self):
        """Stock Manager cannot view or record company expenses (HTTP 403)."""
        self.client.force_authenticate(user=self.stock_manager_user)
        resp = self.client.get('/api/inventory/expenses/')
        self.assertEqual(resp.status_code, status.HTTP_403_FORBIDDEN)

        resp = self.client.post('/api/inventory/expenses/', {
            'category': 'SALARY',
            'amount': '15000.00',
            'description': 'Attempted unauthorized expense'
        }, format='json')
        self.assertEqual(resp.status_code, status.HTTP_403_FORBIDDEN)

    def test_stock_manager_denied_company_billing_profile(self):
        """Stock Manager cannot view or modify company GSTIN, bank details, or billing config (HTTP 403)."""
        self.client.force_authenticate(user=self.stock_manager_user)
        resp = self.client.get('/api/billing/company-profile/')
        self.assertEqual(resp.status_code, status.HTTP_403_FORBIDDEN)

    def test_stock_manager_denied_dealer_credit_profiles(self):
        """Stock Manager cannot view or edit dealer credit limits or aging reports (HTTP 403)."""
        self.client.force_authenticate(user=self.stock_manager_user)
        resp = self.client.get(f'/api/billing/dealers/{self.franchise.id}/credit-profile/')
        self.assertEqual(resp.status_code, status.HTTP_403_FORBIDDEN)

        resp = self.client.get(f'/api/billing/dealers/{self.franchise.id}/aging/')
        self.assertEqual(resp.status_code, status.HTTP_403_FORBIDDEN)

    def test_stock_manager_denied_selling_price_changes(self):
        """Stock Manager cannot change product selling prices, MRP, or dealer transfer prices (HTTP 403)."""
        self.client.force_authenticate(user=self.stock_manager_user)
        payload = {
            'price': '25.00',
            'dealer_transfer_price': '15.00',
        }
        resp = self.client.patch(f'/api/products/{self.product.id}/pricing/', payload, format='json')
        self.assertEqual(resp.status_code, status.HTTP_403_FORBIDDEN)

    def test_stock_manager_denied_user_admin_management_and_self_promotion(self):
        """Stock Manager cannot access admin management endpoints or promote themselves (HTTP 403)."""
        self.client.force_authenticate(user=self.stock_manager_user)

        # GET admins
        resp = self.client.get('/api/accounts/super-admin/admins/')
        self.assertEqual(resp.status_code, status.HTTP_403_FORBIDDEN)

        # POST new admin
        resp = self.client.post('/api/accounts/super-admin/admins/', {
            'email': 'hacker@waterwala.com',
            'username': 'hacker',
            'password': 'Password123!',
            'role': 'super_admin'
        }, format='json')
        self.assertEqual(resp.status_code, status.HTTP_403_FORBIDDEN)

        # PATCH self to super_admin
        resp = self.client.patch(f'/api/accounts/super-admin/admins/{self.stock_manager_user.id}/', {
            'role': 'super_admin'
        }, format='json')
        self.assertEqual(resp.status_code, status.HTTP_403_FORBIDDEN)

    def test_stock_manager_denied_wallet_reconciliation(self):
        """Stock Manager cannot view or execute customer wallet reconciliation (HTTP 403)."""
        self.client.force_authenticate(user=self.stock_manager_user)
        resp = self.client.get('/api/orders/wallet/reconcile/')
        self.assertEqual(resp.status_code, status.HTTP_403_FORBIDDEN)

    # =========================================================================
    # 4. BUSINESS RULES & INTEGRITY ENFORCEMENT
    # =========================================================================

    def test_stock_adjustment_requires_mandatory_reason(self):
        """Stock adjustment is rejected with HTTP 400 if reason is omitted or empty."""
        self.client.force_authenticate(user=self.stock_manager_user)
        payload = {
            'entity_type': 'RAW_MATERIAL',
            'entity_id': self.raw_material.id,
            'adjusted_quantity': '10.00',
            'reason': '   ',  # Empty/whitespace
        }
        resp = self.client.post('/api/inventory/stock/adjust/', payload, format='json')
        self.assertEqual(resp.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('Reason is mandatory', resp.data.get('error', ''))

    def test_stock_adjustment_cannot_create_negative_stock(self):
        """Stock adjustment is rejected with HTTP 400 if it would create negative stock."""
        self.client.force_authenticate(user=self.stock_manager_user)
        # Attempt to deduct 999999 units from remaining 2000 units
        payload = {
            'entity_type': 'PRODUCTION_BATCH',
            'entity_id': self.batch.id,
            'adjusted_quantity': '-5000',
            'reason': 'Unauthorized large deduction test',
        }
        resp = self.client.post('/api/inventory/stock/adjust/', payload, format='json')
        self.assertEqual(resp.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('Cannot adjust stock below zero', resp.data.get('error', ''))

        # Verify batch remaining was unchanged
        self.batch.refresh_from_db()
        self.assertEqual(self.batch.quantity_remaining_company, 2000)

    def test_confidential_costs_masked_from_stock_manager(self):
        """Supplier costs and unit production costs are masked from serialized responses for Stock Manager."""
        # 1. Stock Manager query
        self.client.force_authenticate(user=self.stock_manager_user)
        resp = self.client.get(f'/api/inventory/production-batches/')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        batch_data = next((b for b in resp.data if b['id'] == self.batch.id), None)
        self.assertIsNotNone(batch_data)
        self.assertNotIn('unit_production_cost', batch_data)

        # 2. Super Admin query - retains cost
        self.client.force_authenticate(user=self.super_admin_user)
        resp = self.client.get(f'/api/inventory/production-batches/')
        self.assertEqual(resp.status_code, status.HTTP_200_OK)
        admin_batch_data = next((b for b in resp.data if b['id'] == self.batch.id), None)
        self.assertIsNotNone(admin_batch_data)
        self.assertIn('unit_production_cost', admin_batch_data)
        self.assertEqual(Decimal(str(admin_batch_data['unit_production_cost'])), Decimal('8.50'))

import datetime
from decimal import Decimal
from django.test import TestCase
from django.contrib.auth import get_user_model
from django.utils import timezone

from accounts.models import FranchiseProfile, UserProfile
from products.models import Product
from billing.models import Invoice, PaymentTransaction, DealerCreditProfile, CompanyBillingProfile
from inventory.models import DealerStockRequest, DealerStockBatch
from billing.services import (
    record_payment_transaction,
    _process_payment_verification,
    get_dealer_aging_report,
    get_dealer_account_statement,
    get_dealer_stock_payment_reconciliation,
)

User = get_user_model()


class FranchiseBillingAndReconciliationTests(TestCase):
    def setUp(self):
        # Admin user
        self.admin = User.objects.create_superuser(
            username='admin_franchise_test',
            email='admin_ft@example.com',
            password='Password@123'
        )
        UserProfile.objects.update_or_create(user=self.admin, defaults={'role': 'admin'})

        # Franchise user
        self.franchise_user = User.objects.create_user(
            username='franchise_test_user',
            email='franchise_ft@example.com',
            password='Password@123'
        )
        UserProfile.objects.update_or_create(user=self.franchise_user, defaults={'role': 'franchise'})
        self.dealer = FranchiseProfile.objects.create(
            user=self.franchise_user,
            business_name='Shivnath Raipur Franchise Unit',
            city='Raipur',
            address='VIP Road, Raipur',
            dealer_code='DLR-RAIPUR-01',
            status='approved'
        )

        # Company billing profile
        CompanyBillingProfile.objects.get_or_create(
            is_configured=True,
            defaults={
                'legal_name': 'Shivnath Agencies Private Limited',
                'trade_name': 'Shivnath Agencies',
                'cgst_rate': Decimal('9.00'),
                'sgst_rate': Decimal('9.00'),
                'invoice_prefix': 'SHV/2026/',
            }
        )

        # Product
        self.product = Product.objects.create(
            name='20L Purified Water Jar',
            sku='JAR-20L-001',
            size='20L',
            volume_ml=20000,
            package_type='JAR',
            category='Jar',
            price=Decimal('80.00'),
            dealer_transfer_price=Decimal('50.00'),
            status='Active'
        )

    def test_franchise_purchase_invoice_and_instalment_payments(self):
        """
        P1: Test franchise purchase invoice generation, multiple instalment payments,
        outstanding balance reduction, and ledger reconciliation.
        """
        # Create credit profile with 10,000 limit
        credit_profile, _ = DealerCreditProfile.objects.get_or_create(
            dealer=self.dealer,
            defaults={
                'credit_limit': Decimal('10000.00'),
                'current_outstanding': Decimal('0.00'),
                'payment_terms_days': 15,
            }
        )

        # 1. Create a Dealer Purchase Invoice for 100 jars @ 50 = 5,000 + 18% GST (900) = 5,900
        subtotal = Decimal('5000.00')
        cgst = Decimal('450.00')
        sgst = Decimal('450.00')
        grand_total = Decimal('5900.00')

        inv = Invoice.objects.create(
            invoice_number='SHV/2026/WHL-0001',
            invoice_type='DEALER_PURCHASE_INVOICE',
            billed_to_name=self.dealer.business_name,
            billed_to_gstin='22AAAAA0000A1Z5',
            billed_to_address=self.dealer.address,
            subtotal=subtotal,
            cgst_amount=cgst,
            sgst_amount=sgst,
            grand_total=grand_total,
            amount_paid=Decimal('0.00'),
            status='UNPAID'
        )
        credit_profile.current_outstanding = grand_total
        credit_profile.save()

        self.assertEqual(inv.outstanding_balance, grand_total)
        self.assertEqual(inv.status, 'UNPAID')

        # 2. Franchise submits first instalment of 2,500
        txn1 = record_payment_transaction(
            invoice_id=inv.id,
            amount_paid=Decimal('2500.00'),
            payment_method='UPI',
            reference_number='UTR111222333',
            actor=self.franchise_user,
            notes='First instalment'
        )
        self.assertEqual(txn1.payment_status, 'PENDING_VERIFICATION')

        # Admin approves first instalment
        _process_payment_verification(txn1.id, 'approve', self.admin)
        inv.refresh_from_db()
        credit_profile.refresh_from_db()

        self.assertEqual(inv.amount_paid, Decimal('2500.00'))
        self.assertEqual(inv.outstanding_balance, Decimal('3400.00'))
        self.assertEqual(inv.status, 'PARTIALLY_PAID')
        self.assertEqual(credit_profile.current_outstanding, Decimal('3400.00'))

        # 3. Franchise submits second instalment of 3,400 (remaining balance)
        txn2 = record_payment_transaction(
            invoice_id=inv.id,
            amount_paid=Decimal('3400.00'),
            payment_method='Bank Transfer',
            reference_number='UTR444555666',
            actor=self.franchise_user,
            notes='Second final instalment'
        )
        self.assertEqual(txn2.payment_status, 'PENDING_VERIFICATION')

        # Admin approves second instalment
        _process_payment_verification(txn2.id, 'approve', self.admin)
        inv.refresh_from_db()
        credit_profile.refresh_from_db()

        self.assertEqual(inv.amount_paid, Decimal('5900.00'))
        self.assertEqual(inv.outstanding_balance, Decimal('0.00'))
        self.assertEqual(inv.status, 'PAID')
        self.assertEqual(credit_profile.current_outstanding, Decimal('0.00'))
        self.assertEqual(credit_profile.credit_status, 'GOOD_STANDING')

    def test_dealer_account_statement_generation(self):
        """
        P1: Test chronological account statement with running balance and entries.
        """
        credit_profile, _ = DealerCreditProfile.objects.get_or_create(
            dealer=self.dealer,
            defaults={
                'credit_limit': Decimal('15000.00'),
                'current_outstanding': Decimal('1000.00'),
            }
        )

        inv = Invoice.objects.create(
            invoice_number='SHV/2026/WHL-0002',
            invoice_type='DEALER_PURCHASE_INVOICE',
            billed_to_name=self.dealer.business_name,
            subtotal=Decimal('3000.00'),
            grand_total=Decimal('3540.00'),
            amount_paid=Decimal('2540.00'),
            status='PARTIALLY_PAID'
        )

        PaymentTransaction.objects.create(
            transaction_number='PAY-20261024-00010',
            invoice=inv,
            payment_method='UPI',
            amount_paid=Decimal('2540.00'),
            payment_status='SUCCESS',
            received_by=self.admin
        )

        statement = get_dealer_account_statement(self.dealer.id)
        self.assertEqual(statement['dealer_id'], self.dealer.id)
        self.assertEqual(statement['dealer_name'], self.dealer.business_name)
        self.assertEqual(len(statement['ledger_entries']), 2)
        # Entry 1: Invoice Debit 3540
        self.assertEqual(statement['ledger_entries'][0]['type'], 'DEBIT_INVOICE')
        self.assertEqual(statement['ledger_entries'][0]['debit'], Decimal('3540.00'))
        # Entry 2: Payment Credit 2540
        self.assertEqual(statement['ledger_entries'][1]['type'], 'CREDIT_PAYMENT')
        self.assertEqual(statement['ledger_entries'][1]['credit'], Decimal('2540.00'))
        self.assertEqual(statement['ledger_entries'][1]['running_balance'], Decimal('1000.00'))
        self.assertEqual(statement['statement_balance'], Decimal('1000.00'))

    def test_dealer_stock_payment_reconciliation(self):
        """
        P1: Test reconciliation between physical dealer stock batches, invoiced amount, and payments.
        """
        # Create stock batch in dealer warehouse
        DealerStockBatch.objects.create(
            dealer=self.dealer,
            product=self.product,
            batch_number='BATCH-WH-001',
            manufacture_date=timezone.now().date(),
            expiry_date=timezone.now().date() + datetime.timedelta(days=30),
            received_quantity=100,
            remaining_quantity=80,
            damaged_quantity=2,
            unit_transfer_price=Decimal('50.00')
        )

        DealerCreditProfile.objects.get_or_create(
            dealer=self.dealer,
            defaults={
                'credit_limit': Decimal('10000.00'),
                'current_outstanding': Decimal('1000.00'),
            }
        )

        inv = Invoice.objects.create(
            invoice_number='SHV/2026/WHL-0003',
            invoice_type='DEALER_PURCHASE_INVOICE',
            billed_to_name=self.dealer.business_name,
            subtotal=Decimal('5000.00'),
            grand_total=Decimal('5900.00'),
            amount_paid=Decimal('4900.00'),
            status='PARTIALLY_PAID'
        )

        PaymentTransaction.objects.create(
            transaction_number='PAY-20261024-00011',
            invoice=inv,
            payment_method='UPI',
            amount_paid=Decimal('4900.00'),
            payment_status='SUCCESS',
            received_by=self.admin
        )

        recon = get_dealer_stock_payment_reconciliation(self.dealer.id)
        self.assertEqual(recon['stock_summary']['total_received_units'], 100)
        self.assertEqual(recon['stock_summary']['total_remaining_units'], 80)
        self.assertEqual(recon['stock_summary']['total_damaged_units'], 2)
        self.assertEqual(recon['stock_summary']['current_stock_valuation'], Decimal('4000.00'))  # 80 * 50
        self.assertTrue(recon['financial_summary']['is_reconciled'])
        self.assertEqual(recon['financial_summary']['current_outstanding'], Decimal('1000.00'))

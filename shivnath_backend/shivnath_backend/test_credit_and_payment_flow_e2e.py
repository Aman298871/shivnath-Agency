import json
from decimal import Decimal
from django.test import TestCase
from django.contrib.auth.models import User
from django.utils import timezone
from rest_framework.test import APIClient

from accounts.models import UserProfile, FranchiseProfile, AdminNotification
from products.models import Product, ProductCategory
from inventory.models import DealerStockRequest, DealerStockBatch
from billing.models import DealerCreditProfile, Invoice, PaymentTransaction
from billing.services import submit_payment_for_verification, verify_payment_transaction, _process_payment_verification


class CreditAndPaymentFlowE2ETest(TestCase):
    def setUp(self):
        self.client = APIClient()

        # Admin user
        self.admin_user = User.objects.create_user(
            username='admin_test',
            email='admin@test.com',
            password='pass',
            is_staff=True
        )
        admin_profile, _ = UserProfile.objects.get_or_create(user=self.admin_user)
        admin_profile.role = 'admin'
        admin_profile.save()

        self.admin_user.refresh_from_db()

        # Franchise user
        self.franchise_user = User.objects.create_user(
            username='franchise_test',
            email='franchise@test.com',
            password='pass'
        )
        franchise_profile, _ = UserProfile.objects.get_or_create(user=self.franchise_user)
        franchise_profile.role = 'franchise'
        franchise_profile.save()
        self.franchise = FranchiseProfile.objects.create(
            user=self.franchise_user,
            business_name='Shivnath Test Franchise',
            dealer_code='STF-001',
            status='approved',
            city='Raipur'
        )
        self.franchise_user.refresh_from_db()

        # Product
        self.cat = ProductCategory.objects.create(name='Packaged Water', slug='water')
        self.product = Product.objects.create(
            sku='SHV-500-TEST',
            name='Shivnath 500ml Test',
            category=self.cat,
            price=Decimal('20.00'),
            dealer_transfer_price=Decimal('12.00')
        )

    def test_full_credit_and_payment_lifecycle(self):
        # 1. Admin configures Franchise Credit Limit = ₹100,000 & 15 days terms
        self.client.force_authenticate(user=self.admin_user)
        res = self.client.put(
            f'/api/billing/dealers/{self.franchise.id}/credit-profile/',
            data={'credit_limit': '100000.00', 'payment_terms_days': 15, 'credit_status': 'GOOD_STANDING'},
            format='json'
        )
        if res.status_code != 200:
            print("ERROR IN PUT CREDIT PROFILE:", res.status_code, res.data)
        self.assertEqual(res.status_code, 200)

        credit_prof = DealerCreditProfile.objects.get(dealer=self.franchise)
        self.assertEqual(credit_prof.credit_limit, Decimal('100000.00'))
        self.assertEqual(credit_prof.current_outstanding, Decimal('0.00'))

        # Check API serializer available credit
        get_res = self.client.get(f'/api/billing/dealers/{self.franchise.id}/credit-profile/')
        self.assertEqual(get_res.status_code, 200)
        self.assertEqual(Decimal(str(get_res.data['available_credit'])), Decimal('100000.00'))

        # 2. Franchise owes ₹40,000 for a wholesale stock dispatch invoice
        invoice = Invoice.objects.create(
            invoice_number='INV-TEST-001',
            invoice_type='DEALER_PURCHASE_INVOICE',
            billed_to_name=self.franchise.business_name,
            subtotal=Decimal('40000.00'),
            grand_total=Decimal('40000.00'),
            amount_paid=Decimal('0.00'),
            status='UNPAID'
        )
        credit_prof.current_outstanding = Decimal('40000.00')
        credit_prof.save()

        # Outstanding is ₹40,000, Available Credit is ₹60,000
        get_res = self.client.get(f'/api/billing/dealers/{self.franchise.id}/credit-profile/')
        self.assertEqual(Decimal(str(get_res.data['current_outstanding'])), Decimal('40000.00'))
        self.assertEqual(Decimal(str(get_res.data['available_credit'])), Decimal('60000.00'))

        # 3. Franchise submits partial payment of ₹15,000
        self.client.force_authenticate(user=self.franchise_user)
        pay_res = self.client.post(
            f'/api/billing/invoices/{invoice.id}/payments/',
            data={
                'amount': '15000.00',
                'payment_method': 'UPI',
                'reference_number': 'UTR987654321',
                'notes': 'Advance for 500ml stock'
            },
            format='json'
        )
        self.assertEqual(pay_res.status_code, 201)
        self.assertTrue(pay_res.data.get('is_pending_verification'))

        # Verify transaction status in DB is PENDING_VERIFICATION
        txn = PaymentTransaction.objects.get(invoice=invoice)
        self.assertEqual(txn.payment_status, 'PENDING_VERIFICATION')
        self.assertEqual(txn.amount_paid, Decimal('15000.00'))

        # Before admin approval, outstanding MUST remain ₹40,000
        credit_prof.refresh_from_db()
        self.assertEqual(credit_prof.current_outstanding, Decimal('40000.00'))

        # 4. Admin checks pending payments endpoint
        self.client.force_authenticate(user=self.admin_user)
        pending_res = self.client.get('/api/billing/pending-payments/')
        self.assertEqual(pending_res.status_code, 200)
        self.assertEqual(len(pending_res.data['payments']), 1)
        item = pending_res.data['payments'][0]
        self.assertEqual(item['franchise_name'], self.franchise.business_name)
        self.assertEqual(item['amount'], 15000.00)
        self.assertEqual(item['reference_number'], 'UTR987654321')

        # 5. Admin approves the ₹15,000 payment
        appr_res = self.client.post(
            f'/api/billing/payments/{txn.id}/verify/',
            data={'notes': 'Confirmed received in ICICI bank'},
            format='json'
        )
        self.assertEqual(appr_res.status_code, 200)

        # 6. Verify ledger & credit updates after approval
        txn.refresh_from_db()
        self.assertEqual(txn.payment_status, 'SUCCESS')

        invoice.refresh_from_db()
        self.assertEqual(invoice.status, 'PARTIALLY_PAID')
        self.assertEqual(invoice.amount_paid, Decimal('15000.00'))
        self.assertEqual(invoice.outstanding_balance, Decimal('25000.00'))

        credit_prof.refresh_from_db()
        self.assertEqual(credit_prof.current_outstanding, Decimal('25000.00'))

        # Available Credit increases to ₹75,000
        get_res = self.client.get(f'/api/billing/dealers/{self.franchise.id}/credit-profile/')
        self.assertEqual(Decimal(str(get_res.data['available_credit'])), Decimal('75000.00'))

        # 7. Franchise submits remaining ₹25,000 payment
        self.client.force_authenticate(user=self.franchise_user)
        pay_res2 = self.client.post(
            f'/api/billing/invoices/{invoice.id}/payments/',
            data={
                'amount': '25000.00',
                'payment_method': 'Bank Transfer',
                'reference_number': 'NEFT555666777',
            },
            format='json'
        )
        self.assertEqual(pay_res2.status_code, 201)

        txn2 = PaymentTransaction.objects.filter(invoice=invoice, payment_status='PENDING_VERIFICATION').first()
        self.assertIsNotNone(txn2)

        # 8. Admin approves the second payment
        self.client.force_authenticate(user=self.admin_user)
        appr_res2 = self.client.post(
            f'/api/billing/payments/{txn2.id}/verify/',
            data={'notes': 'Full clearance verified'},
            format='json'
        )
        self.assertEqual(appr_res2.status_code, 200)

        # 9. Verify final state: Outstanding = 0, Available Credit = 100,000, Invoice = PAID
        invoice.refresh_from_db()
        self.assertEqual(invoice.status, 'PAID')
        self.assertEqual(invoice.amount_paid, Decimal('40000.00'))
        self.assertEqual(invoice.outstanding_balance, Decimal('0.00'))

        credit_prof.refresh_from_db()
        self.assertEqual(credit_prof.current_outstanding, Decimal('0.00'))

        get_res = self.client.get(f'/api/billing/dealers/{self.franchise.id}/credit-profile/')
        self.assertEqual(Decimal(str(get_res.data['current_outstanding'])), Decimal('0.00'))
        self.assertEqual(Decimal(str(get_res.data['available_credit'])), Decimal('100000.00'))

        # 10. Overpayment test: cannot pay more than invoice balance (balance is now 0)
        self.client.force_authenticate(user=self.franchise_user)
        bad_res = self.client.post(
            f'/api/billing/invoices/{invoice.id}/payments/',
            data={'amount': '500.00'},
            format='json'
        )
        self.assertEqual(bad_res.status_code, 400)

    def test_franchise_order_partial_collection_direct_settlement(self):
        """Franchise records partial collection on customer order; settles immediately without admin verification bottleneck."""
        from orders.models import Order
        order = Order.objects.create(
            created_by=self.franchise_user,
            serving_franchise=self.franchise,
            franchise_name=self.franchise.business_name,
            city='Raipur',
            amount=Decimal('1200.00'),
            grand_total=Decimal('1200.00'),
            status='delivered',
            payment_status='pending',
            payment_mode='FRANCHISE_COLLECTION',
            order_source='FRANCHISE'
        )

        # 1. Franchise records partial collection of ₹500
        self.client.force_authenticate(user=self.franchise_user)
        pay_res = self.client.post(
            f'/api/billing/orders/{order.id}/payments/',
            data={
                'payment_type': 'PARTIAL',
                'amount': '500.00',
                'payment_method': 'CASH',
                'notes': 'Partial cash collected on delivery'
            },
            format='json'
        )
        self.assertEqual(pay_res.status_code, 201)
        self.assertFalse(pay_res.data.get('is_pending_verification'))

        txn = PaymentTransaction.objects.filter(invoice__order=order).first()
        self.assertIsNotNone(txn)
        self.assertEqual(txn.payment_status, 'SUCCESS')
        self.assertEqual(txn.amount_paid, Decimal('500.00'))

        # Immediate update: invoice amount_paid is 500 and order payment_status is partial
        order.refresh_from_db()
        self.assertEqual(order.payment_status, 'partial')
        invoice = txn.invoice
        invoice.refresh_from_db()
        self.assertEqual(invoice.amount_paid, Decimal('500.00'))
        self.assertEqual(invoice.outstanding_balance, Decimal('916.00'))  # ₹1200 + 18% GST (1416) - 500

    def test_dealer_purchase_payment_rejection_leaves_invoice_unpaid(self):
        """Admin rejection of wholesale dealer purchase payment leaves dealer invoice unpaid."""
        invoice = Invoice.objects.create(
            invoice_number='INV-DLR-REJ-001',
            invoice_type='DEALER_PURCHASE_INVOICE',
            billed_to_name=self.franchise.business_name,
            subtotal=Decimal('600.00'),
            grand_total=Decimal('600.00'),
            amount_paid=Decimal('0.00'),
            status='UNPAID'
        )

        # 1. Franchise submits wholesale payment for verification
        txn = submit_payment_for_verification(
            invoice_id=invoice.id,
            amount_paid=Decimal('600.00'),
            payment_method='UPI',
            reference_number='DLR_UPI_REF_001',
            actor=self.franchise_user,
            notes='Wholesale payment via UPI'
        )
        self.assertEqual(txn.payment_status, 'PENDING_VERIFICATION')

        # 2. Admin rejects wholesale payment
        self.client.force_authenticate(user=self.admin_user)
        rej_res = self.client.post(
            f'/api/billing/payments/{txn.id}/reject/',
            data={'notes': 'Fraudulent screenshot submitted'},
            format='json'
        )
        self.assertEqual(rej_res.status_code, 200)

        txn.refresh_from_db()
        self.assertEqual(txn.payment_status, 'REJECTED')

        invoice.refresh_from_db()
        self.assertEqual(invoice.amount_paid, Decimal('0.00'))
        self.assertEqual(invoice.outstanding_balance, Decimal('600.00'))
        self.assertEqual(invoice.status, 'UNPAID')

        # 3. Attempting to approve rejected transaction fails
        bad_appr = self.client.post(f'/api/billing/payments/{txn.id}/verify/', format='json')
        self.assertEqual(bad_appr.status_code, 400)

    def test_franchise_overpayment_handled_and_rejected(self):
        """Collection amounts greater than outstanding are strictly rejected on order collection endpoints."""
        from orders.models import Order
        order = Order.objects.create(
            created_by=self.franchise_user,
            serving_franchise=self.franchise,
            franchise_name=self.franchise.business_name,
            city='Raipur',
            amount=Decimal('500.00'),
            grand_total=Decimal('500.00'),
            status='delivered',
            payment_status='pending',
            payment_mode='FRANCHISE_COLLECTION',
            order_source='FRANCHISE'
        )
        self.client.force_authenticate(user=self.franchise_user)
        # Outstanding is ₹590 (500 + 18% GST).
        # Submitting ₹1000 exceeds remaining balance (₹590.00) and is rejected with HTTP 400
        pay_res = self.client.post(
            f'/api/billing/orders/{order.id}/payments/',
            data={
                'payment_type': 'PARTIAL',
                'amount': '1000.00',
                'payment_method': 'CASH',
            },
            format='json'
        )
        self.assertEqual(pay_res.status_code, 400)
        self.assertIn('exceed', str(pay_res.data).lower())


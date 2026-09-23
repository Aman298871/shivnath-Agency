from django.db import transaction
from django.utils import timezone
from decimal import Decimal
import datetime

from billing.models import CompanyBillingProfile, DealerCreditProfile, Invoice, PaymentTransaction
from orders.models import Order


@transaction.atomic
def generate_invoice_for_order(order):
    """
    Generates an authoritative GST invoice for an Order based on CompanyBillingProfile.
    """
    if hasattr(order, 'invoice') and order.invoice:
        return order.invoice

    billing_profile = CompanyBillingProfile.objects.filter(is_configured=True).first()
    subtotal = order.amount
    cgst_rate = billing_profile.cgst_rate if billing_profile else Decimal('9.00')
    sgst_rate = billing_profile.sgst_rate if billing_profile else Decimal('9.00')
    cgst_amt = (subtotal * cgst_rate) / Decimal('100.00')
    sgst_amt = (subtotal * sgst_rate) / Decimal('100.00')
    grand_total = subtotal + cgst_amt + sgst_amt

    inv_count = Invoice.objects.count() + 1
    prefix = billing_profile.invoice_prefix if billing_profile else 'SHV/2026/'
    inv_type = 'DIRECT_COMPANY_SALE_INVOICE' if order.order_source == 'DIRECT_COMPANY' else 'CUSTOMER_SALE_INVOICE'
    inv_number = f"{prefix}RET-{inv_count:04d}"

    customer_name = order.created_by.get_full_name() if order.created_by and order.created_by.get_full_name() else (order.created_by.email if order.created_by else order.franchise_name)

    invoice = Invoice.objects.create(
        invoice_number=inv_number,
        order=order,
        invoice_type=inv_type,
        billed_to_name=customer_name,
        billed_to_address=order.delivery_address or order.city,
        subtotal=subtotal,
        cgst_amount=cgst_amt,
        sgst_amount=sgst_amt,
        grand_total=grand_total,
        amount_paid=Decimal('0.00'),
        status='UNPAID'
    )
    return invoice


@transaction.atomic
def record_payment_transaction(invoice_id, amount_paid, payment_method='UPI', reference_number='', actor=None, receipt_file=None, notes=''):
    """
    Atomically records a payment transaction, updates invoice status and dealer credit profile.
    """
    invoice = Invoice.objects.select_for_update().get(id=invoice_id)
    amount_paid_dec = Decimal(str(amount_paid))

    count = PaymentTransaction.objects.count() + 1
    txn_number = f"PAY-{timezone.now().strftime('%Y%m%d')}-{count:05d}"

    txn = PaymentTransaction.objects.create(
        transaction_number=txn_number,
        invoice=invoice,
        payment_method=payment_method,
        amount_paid=amount_paid_dec,
        reference_number=reference_number,
        payment_status='SUCCESS',
        receipt_file=receipt_file,
        received_by=actor,
        notes=notes
    )

    invoice.amount_paid = Decimal(str(invoice.amount_paid or '0.00')) + amount_paid_dec
    if invoice.amount_paid >= invoice.grand_total:
        invoice.status = 'PAID'
    elif invoice.amount_paid > Decimal('0.00'):
        invoice.status = 'PARTIALLY_PAID'
    invoice.save()

    # If this is a dealer purchase invoice, update DealerCreditProfile
    if invoice.invoice_type == 'DEALER_PURCHASE_INVOICE':
        dealer = None
        if invoice.stock_request:
            dealer = invoice.stock_request.dealer
        else:
            from accounts.models import FranchiseProfile
            dealer = FranchiseProfile.objects.filter(business_name=invoice.billed_to_name).first()

        if dealer:
            credit_profile, _ = DealerCreditProfile.objects.select_for_update().get_or_create(dealer=dealer)
            current_out = Decimal(str(credit_profile.current_outstanding or '0.00'))
            limit = Decimal(str(credit_profile.credit_limit or '0.00'))
            credit_profile.current_outstanding = max(Decimal('0.00'), current_out - amount_paid_dec)
            credit_profile.last_payment_date = timezone.now().date()
            if credit_profile.current_outstanding <= limit:
                credit_profile.credit_status = 'GOOD_STANDING'
            credit_profile.save()


    return txn


def get_dealer_aging_report(dealer_id):
    """
    Calculates 0-30, 31-60, 61-90, 90+ days aging breakdown for a dealer.
    """
    from django.db.models import Q
    dealer_credit = DealerCreditProfile.objects.filter(dealer_id=dealer_id).first()
    invoices = Invoice.objects.filter(
        Q(stock_request__dealer_id=dealer_id) | (Q(billed_to_name=dealer_credit.dealer.business_name) if dealer_credit else Q()),
        invoice_type='DEALER_PURCHASE_INVOICE'
    ).exclude(status='PAID')

    today = timezone.now().date()
    current_bucket = Decimal('0.00')  # 0 to 15 / payment_terms
    bucket_30 = Decimal('0.00')       # 16 to 30 days
    bucket_60 = Decimal('0.00')       # 31 to 60 days
    bucket_90_plus = Decimal('0.00')  # 61+ days

    for inv in invoices:
        balance = inv.outstanding_balance
        age_days = (today - inv.issued_at.date()).days
        if age_days <= (dealer_credit.payment_terms_days if dealer_credit else 15):
            current_bucket += balance
        elif age_days <= 30:
            bucket_30 += balance
        elif age_days <= 60:
            bucket_60 += balance
        else:
            bucket_90_plus += balance

    return {
        'dealer_id': dealer_id,
        'dealer_code': dealer_credit.dealer.dealer_code if dealer_credit else '',
        'dealer_name': dealer_credit.dealer.business_name if dealer_credit else '',
        'credit_limit': dealer_credit.credit_limit if dealer_credit else Decimal('0.00'),
        'total_outstanding': dealer_credit.current_outstanding if dealer_credit else Decimal('0.00'),
        'credit_status': dealer_credit.credit_status if dealer_credit else 'GOOD_STANDING',
        'current_terms_bucket': current_bucket,
        'bucket_16_to_30': bucket_30,
        'bucket_31_to_60': bucket_60,
        'bucket_60_plus': bucket_90_plus
    }


# Alias for audit test compatibility
record_payment_atomic = record_payment_transaction


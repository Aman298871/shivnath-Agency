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
def submit_payment_for_verification(invoice_id, amount_paid, payment_method='UPI', reference_number='', actor=None, receipt_file=None, notes=''):
    """
    Submits a payment for verification by the admin.
    """
    invoice = Invoice.objects.select_for_update().get(id=invoice_id)
    amount_paid_dec = Decimal(str(amount_paid))

    if amount_paid_dec <= Decimal('0.00'):
        raise ValueError("Payment amount must be greater than zero.")

    if amount_paid_dec > invoice.outstanding_balance:
        raise ValueError(
            f"Payment amount (₹{amount_paid_dec}) cannot exceed invoice outstanding balance (₹{invoice.outstanding_balance})."
        )

    method_upper = str(payment_method).upper().strip()
    if 'CASH' in method_upper:
        clean_method = 'CASH'
    elif 'CHEQUE' in method_upper or 'CHECK' in method_upper:
        clean_method = 'CHEQUE'
    elif any(x in method_upper for x in ['BANK', 'NEFT', 'RTGS', 'TRANSFER', 'IMPS']):
        clean_method = 'NEFT_RTGS'
    else:
        clean_method = 'UPI'

    count = PaymentTransaction.objects.count() + 1
    txn_number = f"PAY-PEND-{timezone.now().strftime('%Y%m%d')}-{count:05d}"

    txn = PaymentTransaction.objects.create(
        transaction_number=txn_number,
        invoice=invoice,
        payment_method=clean_method,
        amount_paid=amount_paid_dec,
        reference_number=reference_number or '',
        payment_status='PENDING_VERIFICATION',
        receipt_file=receipt_file,
        received_by=actor,
        notes=notes or ''
    )
    return txn


@transaction.atomic
def record_payment_transaction(invoice_id, amount_paid, payment_method='UPI', reference_number='', actor=None, receipt_file=None, notes=''):
    """
    Records payment. If actor is a franchise dealer, it is submitted for verification
    to prevent unilateral marking of unpaid invoices as paid.
    If actor is admin/staff, it is settled immediately.
    """
    is_admin = False
    if actor:
        is_admin = (
            actor.is_staff or 
            actor.is_superuser or 
            (hasattr(actor, 'profile') and actor.profile.role in ['super_admin', 'admin'])
        )

    if not is_admin:
        return submit_payment_for_verification(
            invoice_id=invoice_id,
            amount_paid=amount_paid,
            payment_method=payment_method,
            reference_number=reference_number,
            actor=actor,
            receipt_file=receipt_file,
            notes=notes
        )

    # Actor is Admin: immediate settlement
    from accounts.models import FranchiseProfile, Notification
    invoice = Invoice.objects.select_for_update().get(id=invoice_id)
    amount_paid_dec = Decimal(str(amount_paid))

    if amount_paid_dec <= Decimal('0.00'):
        raise ValueError("Payment amount must be greater than zero.")

    if amount_paid_dec > invoice.outstanding_balance:
        raise ValueError(
            f"Payment amount (₹{amount_paid_dec}) cannot exceed invoice outstanding balance (₹{invoice.outstanding_balance})."
        )

    method_upper = str(payment_method).upper().strip()
    if 'CASH' in method_upper:
        clean_method = 'CASH'
    elif 'CHEQUE' in method_upper or 'CHECK' in method_upper:
        clean_method = 'CHEQUE'
    elif any(x in method_upper for x in ['BANK', 'NEFT', 'RTGS', 'TRANSFER', 'IMPS']):
        clean_method = 'NEFT_RTGS'
    elif 'CREDIT' in method_upper:
        clean_method = 'CREDIT_ADJUSTMENT'
    else:
        clean_method = 'UPI'

    count = PaymentTransaction.objects.count() + 1
    txn_number = f"PAY-{timezone.now().strftime('%Y%m%d')}-{count:05d}"

    txn = PaymentTransaction.objects.create(
        transaction_number=txn_number,
        invoice=invoice,
        payment_method=clean_method,
        amount_paid=amount_paid_dec,
        reference_number=reference_number or '',
        payment_status='SUCCESS',
        receipt_file=receipt_file,
        received_by=actor,
        notes=notes or ''
    )

    invoice.amount_paid = Decimal(str(invoice.amount_paid or '0.00')) + amount_paid_dec
    if invoice.amount_paid >= invoice.grand_total:
        invoice.status = 'PAID'
    elif invoice.amount_paid > Decimal('0.00'):
        invoice.status = 'PARTIALLY_PAID'
    invoice.save(update_fields=['amount_paid', 'status'])

    # Synchronize linked Order payment_status if present
    if invoice.order:
        order = invoice.order
        if invoice.status == 'PAID':
            order.payment_status = 'paid'
        elif invoice.status == 'PARTIALLY_PAID':
            order.payment_status = 'partial'
        order.save(update_fields=['payment_status', 'updated_at'])

    # If this is a dealer purchase invoice, update DealerCreditProfile
    if invoice.invoice_type == 'DEALER_PURCHASE_INVOICE':
        dealer = None
        if invoice.stock_request and invoice.stock_request.dealer:
            dealer = invoice.stock_request.dealer
        else:
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

            if dealer.user:
                try:
                    Notification.objects.create(
                        recipient=dealer.user,
                        notification_type='PAYMENT_REMINDER',
                        title='Payment Received & Recorded',
                        message=f"Admin recorded receipt of ₹{amount_paid_dec} for Invoice {invoice.invoice_number}. Your ledger is updated.",
                        entity_type='invoice',
                        entity_id=invoice.id
                    )
                except Exception:
                    pass

    return txn


def get_dealer_aging_report(dealer_id):
    """
    Calculates 0-30, 31-60, 61-90, 90+ days aging breakdown for a dealer.
    Enriches with both current_outstanding and current_balance and all bucket keys.
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

    out = dealer_credit.current_outstanding if dealer_credit else Decimal('0.00')
    limit = dealer_credit.credit_limit if dealer_credit else Decimal('0.00')

    return {
        'dealer_id': dealer_id,
        'dealer_code': dealer_credit.dealer.dealer_code if dealer_credit else '',
        'dealer_name': dealer_credit.dealer.business_name if dealer_credit else '',
        'credit_limit': limit,
        'total_outstanding': out,
        'current_outstanding': out,
        'current_balance': out,
        'credit_status': dealer_credit.credit_status if dealer_credit else 'GOOD_STANDING',
        'current_terms_bucket': current_bucket,
        'bucket_16_to_30': bucket_30,
        'bucket_31_to_60': bucket_60,
        'bucket_60_plus': bucket_90_plus,
        # Aliases for frontend compatibility
        'current': current_bucket,
        'days_1_15': current_bucket,
        'days_16_30': bucket_30,
        'days_over_30': bucket_60 + bucket_90_plus,
    }


# Alias for audit test compatibility
record_payment_atomic = record_payment_transaction


@transaction.atomic
def _process_payment_verification(txn_id, action, admin_user, notes=''):
    """
    Verifies or rejects a pending payment transaction.
    """
    from accounts.models import FranchiseProfile, Notification
    txn = PaymentTransaction.objects.select_for_update().get(id=txn_id)
    
    if txn.payment_status != 'PENDING_VERIFICATION':
        raise ValueError(f"Transaction {txn_id} is already processed.")

    if action == 'approve':
        txn.payment_status = 'SUCCESS'
        txn.notes = f"{txn.notes}\nApproved by {admin_user.email}: {notes}".strip()
        txn.save()

        invoice = txn.invoice
        amount_paid_dec = txn.amount_paid
        invoice.amount_paid = Decimal(str(invoice.amount_paid or '0.00')) + amount_paid_dec
        if invoice.amount_paid >= invoice.grand_total:
            invoice.status = 'PAID'
        elif invoice.amount_paid > Decimal('0.00'):
            invoice.status = 'PARTIALLY_PAID'
        invoice.save(update_fields=['amount_paid', 'status'])

        if invoice.order:
            order = invoice.order
            if invoice.status == 'PAID':
                order.payment_status = 'paid'
            elif invoice.status == 'PARTIALLY_PAID':
                order.payment_status = 'partial'
            order.save(update_fields=['payment_status', 'updated_at'])

        if invoice.invoice_type == 'DEALER_PURCHASE_INVOICE':
            dealer = None
            if invoice.stock_request and invoice.stock_request.dealer:
                dealer = invoice.stock_request.dealer
            else:
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

                if dealer.user:
                    try:
                        Notification.objects.create(
                            recipient=dealer.user,
                            notification_type='PAYMENT_REMINDER',
                            title='Payment Verified',
                            message=f"Admin verified your payment of ₹{amount_paid_dec} for Invoice {invoice.invoice_number}. Your ledger is updated.",
                            entity_type='invoice',
                            entity_id=invoice.id
                        )
                    except Exception:
                        pass
        return txn
    elif action == 'reject':
        txn.payment_status = 'FAILED'
        txn.notes = f"{txn.notes}\nRejected by {admin_user.email}: {notes}".strip()
        txn.save()

        if txn.received_by:
            try:
                Notification.objects.create(
                    recipient=txn.received_by,
                    notification_type='PAYMENT_REMINDER',
                    title='Payment Rejected',
                    message=f"Admin rejected your payment of ₹{txn.amount_paid} for Invoice {txn.invoice.invoice_number}. Reason: {notes}",
                    entity_type='invoice',
                    entity_id=txn.invoice.id
                )
            except Exception:
                pass
        return txn
    else:
        raise ValueError(f"Invalid action {action}.")


@transaction.atomic
def verify_payment_transaction(invoice_id, actor, notes=''):
    """
    Verifies a pending payment for the given invoice.
    """
    txn = PaymentTransaction.objects.filter(invoice_id=invoice_id, payment_status='PENDING_VERIFICATION').first()
    if not txn:
        raise ValueError("No pending payment found for this invoice.")
    return _process_payment_verification(txn.id, 'approve', actor, notes)


@transaction.atomic
def reject_payment_transaction(invoice_id, actor, rejection_reason=''):
    """
    Rejects a pending payment for the given invoice.
    """
    txn = PaymentTransaction.objects.filter(invoice_id=invoice_id, payment_status='PENDING_VERIFICATION').first()
    if not txn:
        raise ValueError("No pending payment found for this invoice.")
    return _process_payment_verification(txn.id, 'reject', actor, rejection_reason)



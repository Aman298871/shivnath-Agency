from accounts.fcm_services import logger
from django.db import transaction, models
from django.utils import timezone
from decimal import Decimal
import datetime

from billing.models import CompanyBillingProfile, DealerCreditProfile, Invoice, PaymentTransaction
from orders.models import Order
from billing.tax_calculator import calculate_order_tax_and_totals


@transaction.atomic
def generate_invoice_for_order(order):
    """
    Generates or finalizes an authoritative, immutable GST invoice for an Order based on CompanyBillingProfile.
    Guarantees idempotency, collision safety, accurate tax calculation, delivery charges,
    and distinct handling of reward points, wallet money, and gateway/cash collections.
    """
    billing_profile = CompanyBillingProfile.objects.filter(is_configured=True).first() or CompanyBillingProfile.objects.first()

    # If invoice already exists for this order, retrieve and refresh payment status atomically
    existing_inv = Invoice.objects.select_for_update().filter(order=order).first()
    if existing_inv:
        verified_payments = existing_inv.payments.filter(payment_status='SUCCESS').aggregate(s=models.Sum('amount_paid'))['s'] or Decimal('0.00')
        wallet_debit = getattr(order, 'wallet_amount_debited', Decimal('0.00')) or Decimal('0.00')

        total_settled = verified_payments + wallet_debit
        if getattr(order, 'payment_status', '').lower() == 'paid' or (existing_inv.grand_total > Decimal('0.00') and total_settled >= existing_inv.grand_total):
            existing_inv.amount_paid = existing_inv.grand_total
            existing_inv.status = 'PAID'
            if getattr(order, 'payment_status', '').lower() != 'paid':
                order.payment_status = 'paid'
                order.save(update_fields=['payment_status', 'updated_at'])
        elif total_settled > Decimal('0.00'):
            existing_inv.amount_paid = min(existing_inv.grand_total, total_settled)
            existing_inv.status = 'PAID' if existing_inv.amount_paid >= existing_inv.grand_total else 'PARTIALLY_PAID'
            new_ord_status = 'paid' if existing_inv.status == 'PAID' else 'partial'
            if getattr(order, 'payment_status', '').lower() != new_ord_status:
                order.payment_status = new_ord_status
                order.save(update_fields=['payment_status', 'updated_at'])
        elif getattr(order, 'payment_status', '').lower() == 'partial':
            existing_inv.amount_paid = Decimal('0.00')
            existing_inv.status = 'PARTIALLY_PAID'
        else:
            existing_inv.amount_paid = Decimal('0.00')
            existing_inv.status = 'UNPAID'
        existing_inv.save(update_fields=['amount_paid', 'status'])
        return existing_inv

    # Calculations for new invoice
    subtotal = order.amount or Decimal('0.00')
    delivery_fee = getattr(order, 'delivery_charges', Decimal('0.00')) or Decimal('0.00')
    points_discount = getattr(order, 'points_discount_amount', Decimal('0.00')) or Decimal('0.00')
    wallet_debited = getattr(order, 'wallet_amount_debited', Decimal('0.00')) or Decimal('0.00')
    promo_discount = getattr(order, 'discount_amount', Decimal('0.00')) if hasattr(order, 'discount_amount') else Decimal('0.00')
    total_discount = points_discount + promo_discount

    # Tax configuration from authoritative CompanyBillingProfile
    company_gstin = billing_profile.gstin if billing_profile else ''
    is_gst_req = getattr(order, 'is_gst_requested', False) or bool(getattr(order, 'gstin', ''))
    is_gst = bool(is_gst_req and company_gstin)

    # Place of supply: check customer state vs company state
    company_state = (billing_profile.state_name if billing_profile and billing_profile.state_name else 'Chhattisgarh').strip().lower()
    customer_state = (getattr(order, 'gst_state_name', '') or 'Chhattisgarh').strip().lower()
    is_intra_state = (not customer_state) or (customer_state == company_state)

    if billing_profile and billing_profile.default_gst_rate is not None:
        configured_gst_rate = Decimal(str(billing_profile.default_gst_rate))
        is_price_inclusive = getattr(billing_profile, 'is_price_inclusive_gst', True)
        is_delivery_taxable = getattr(billing_profile, 'is_delivery_taxable', False)
    elif billing_profile and billing_profile.cgst_rate and billing_profile.sgst_rate:
        configured_gst_rate = Decimal(str(billing_profile.cgst_rate + billing_profile.sgst_rate))
        is_price_inclusive = getattr(billing_profile, 'is_price_inclusive_gst', True)
        is_delivery_taxable = getattr(billing_profile, 'is_delivery_taxable', False)
    else:
        # If no billing profile exists (e.g. unconfigured database or legacy test setups):
        configured_gst_rate = Decimal('0.00')
        is_price_inclusive = True
        is_delivery_taxable = False
        if getattr(order, 'grand_total', None) is not None:
            net_no_tax = subtotal - total_discount - wallet_debited + delivery_fee
            tax_18 = round((max(Decimal('0.00'), subtotal - total_discount) * Decimal('18.00')) / Decimal('100.00'), 2)
            net_18_tax = net_no_tax + tax_18
            if abs(order.grand_total - net_18_tax) < Decimal('0.05'):
                configured_gst_rate = Decimal('18.00')
                is_price_inclusive = False
                is_delivery_taxable = False
            elif abs(order.grand_total - net_no_tax) < Decimal('0.05'):
                configured_gst_rate = Decimal('0.00')
                is_price_inclusive = True
                is_delivery_taxable = False

    tax_calc = calculate_order_tax_and_totals(
        subtotal=subtotal,
        delivery_fee=delivery_fee,
        promo_discount=promo_discount,
        points_discount=points_discount,
        wallet_debited=wallet_debited,
        is_intra_state=is_intra_state,
        gst_rate=configured_gst_rate,
        is_price_inclusive_gst=is_price_inclusive,
        is_delivery_taxable=is_delivery_taxable,
    )

    cgst_rate = tax_calc['cgst_rate']
    sgst_rate = tax_calc['sgst_rate']
    igst_rate = tax_calc['igst_rate']

    # Check if order already has an authoritative grand_total matching either inclusive or exclusive:
    net_order_total = subtotal - promo_discount - points_discount - wallet_debited + delivery_fee
    exclusive_tax_on_product = round((max(Decimal('0.00'), subtotal - total_discount) * configured_gst_rate) / Decimal('100.00'), 2) if configured_gst_rate > Decimal('0.00') else Decimal('0.00')
    exclusive_tax_with_delivery = round((max(Decimal('0.00'), subtotal - total_discount + delivery_fee) * configured_gst_rate) / Decimal('100.00'), 2) if configured_gst_rate > Decimal('0.00') else Decimal('0.00')

    if getattr(order, 'grand_total', None) is not None and order.grand_total > Decimal('0.00'):
        if abs(order.grand_total - net_order_total) < Decimal('0.05'):
            # The order was placed with inclusive pricing or zero extra tax
            if is_price_inclusive and configured_gst_rate > Decimal('0.00'):
                taxable_subtotal = tax_calc['taxable_amount']
                cgst_amt = tax_calc['cgst_amount']
                sgst_amt = tax_calc['sgst_amount']
                igst_amt = tax_calc['igst_amount']
                total_tax = tax_calc['total_tax']
            else:
                total_tax = Decimal('0.00')
                cgst_amt = Decimal('0.00')
                sgst_amt = Decimal('0.00')
                igst_amt = Decimal('0.00')
                taxable_subtotal = max(Decimal('0.00'), net_order_total - delivery_fee)
            grand_total = order.grand_total
        elif abs(order.grand_total - (net_order_total + exclusive_tax_on_product)) < Decimal('0.05'):
            # The order was placed with exclusive pricing (tax on product only)
            total_tax = exclusive_tax_on_product
            if is_intra_state:
                cgst_amt = round(total_tax / Decimal('2.00'), 2)
                sgst_amt = total_tax - cgst_amt
                igst_amt = Decimal('0.00')
            else:
                cgst_amt = Decimal('0.00')
                sgst_amt = Decimal('0.00')
                igst_amt = total_tax
            taxable_subtotal = max(Decimal('0.00'), subtotal - total_discount)
            grand_total = order.grand_total
        elif abs(order.grand_total - (net_order_total + exclusive_tax_with_delivery)) < Decimal('0.05'):
            # The order was placed with exclusive pricing (tax on product + delivery)
            total_tax = exclusive_tax_with_delivery
            if is_intra_state:
                cgst_amt = round(total_tax / Decimal('2.00'), 2)
                sgst_amt = total_tax - cgst_amt
                igst_amt = Decimal('0.00')
            else:
                cgst_amt = Decimal('0.00')
                sgst_amt = Decimal('0.00')
                igst_amt = total_tax
            taxable_subtotal = max(Decimal('0.00'), subtotal - total_discount + delivery_fee)
            grand_total = order.grand_total
        else:
            grand_total = tax_calc['grand_total']
            taxable_subtotal = tax_calc['taxable_amount']
            cgst_amt = tax_calc['cgst_amount']
            sgst_amt = tax_calc['sgst_amount']
            igst_amt = tax_calc['igst_amount']
            total_tax = tax_calc['total_tax']
    else:
        grand_total = tax_calc['grand_total']
        taxable_subtotal = tax_calc['taxable_amount']
        cgst_amt = tax_calc['cgst_amount']
        sgst_amt = tax_calc['sgst_amount']
        igst_amt = tax_calc['igst_amount']
        total_tax = tax_calc['total_tax']

    # Synchronize order totals if necessary so Order and Invoice never diverge
    if order.grand_total != grand_total or order.tax_amount != total_tax:
        order.tax_amount = total_tax
        order.grand_total = grand_total
        order.save(update_fields=['tax_amount', 'grand_total', 'updated_at'])

    # Guaranteed unique invoice number using order ID and year prefix
    prefix = billing_profile.invoice_prefix if billing_profile and billing_profile.invoice_prefix else f'SHV/{timezone.now().year}/'
    inv_type = 'DIRECT_COMPANY_SALE_INVOICE' if order.order_source == 'DIRECT_COMPANY' else 'CUSTOMER_SALE_INVOICE'

    base_inv_number = f"{prefix}INV-{order.id:04d}"
    inv_number = base_inv_number
    collision_counter = 1
    while Invoice.objects.filter(invoice_number=inv_number).exists():
        inv_number = f"{base_inv_number}-{collision_counter}"
        collision_counter += 1

    customer_name = order.gst_legal_name if (is_gst_req and order.gst_legal_name) else (
        order.created_by.get_full_name() if order.created_by and order.created_by.get_full_name() else (
            order.created_by.email if order.created_by else (order.client_name or 'Customer')
        )
    )
    customer_gstin = getattr(order, 'gstin', '') or ''
    billing_addr = order.gst_billing_address if (is_gst_req and order.gst_billing_address) else (order.delivery_address or order.city)

    # Calculate actual verified settlement
    is_prepaid_full = (
        getattr(order, 'payment_status', '').lower() == 'paid' or
        getattr(order, 'payment', '').lower() == 'paid' or
        (wallet_debited + points_discount >= grand_total)
    )

    if is_prepaid_full:
        inv_status = 'PAID'
        amt_paid = grand_total
    elif wallet_debited > Decimal('0.00'):
        amt_paid = min(grand_total, wallet_debited)
        inv_status = 'PAID' if (amt_paid >= grand_total or (grand_total - amt_paid) <= Decimal('0.05')) else 'PARTIALLY_PAID'
    elif getattr(order, 'payment_status', '').lower() == 'partial':
        inv_status = 'PARTIALLY_PAID'
        amt_paid = Decimal('0.00')
    else:
        amt_paid = Decimal('0.00')
        inv_status = 'UNPAID'

    order_items_snapshot = []
    if hasattr(order, 'items'):
        for it in order.items.select_related('product').all():
            size_str = str(it.size or '').upper().strip()
            name_str = str(it.product_name or (it.product.name if it.product else '')).upper().strip()
            pkg_attr = str(getattr(it.product, 'package_type', '')).upper() if it.product else ''

            is_jar = (
                pkg_attr == 'JAR' or
                'JAR' in name_str or
                any(x in size_str for x in ['20L', '20 L', '20-L', '20LTR', '20 LITRE', '20 LITER'])
            ) and ('ML' not in size_str)

            is_box = not is_jar and (
                pkg_attr in ('BOX', 'CARTON', 'CASE', 'CTN') or
                any(x in name_str for x in ['BOX', 'CARTON', 'CASE', 'CTN']) or
                any(x in size_str for x in ['BOX', 'CARTON', 'CASE', 'CTN'])
            )

            # Check packaging conversion rule from MinimumOrderPackagingRule
            units_per_carton = 1
            if it.product:
                from products.models import MinimumOrderPackagingRule
                rule = MinimumOrderPackagingRule.objects.filter(product=it.product).first()
                if not rule and getattr(it.product, 'category_id', None):
                    rule = MinimumOrderPackagingRule.objects.filter(category_id=it.product.category_id).first()
                if rule and rule.units_per_carton:
                    units_per_carton = rule.units_per_carton

            if is_jar:
                pkg_type = 'JAR'
                uom = 'Jars'
                packaging_display = f"{it.quantity} Jars"
                cartons_count = 0
            elif units_per_carton > 1 and it.quantity >= units_per_carton and (it.quantity % units_per_carton == 0):
                pkg_type = 'CARTON'
                cartons_count = it.quantity // units_per_carton
                uom = 'Bottles'
                packaging_display = f"{cartons_count} Cartons ({it.quantity} Bottles)"
            elif units_per_carton > 1 and it.quantity >= units_per_carton:
                pkg_type = 'CARTON'
                cartons_count = it.quantity // units_per_carton
                rem = it.quantity % units_per_carton
                uom = 'Bottles'
                packaging_display = f"{cartons_count} Cartons + {rem} Bottles ({it.quantity} Bottles)"
            elif is_box:
                pkg_type = 'BOX'
                uom = 'Boxes'
                packaging_display = f"{it.quantity} Boxes"
                cartons_count = it.quantity
            else:
                pkg_type = 'BOTTLE'
                uom = 'Bottles'
                packaging_display = f"{it.quantity} Bottles"
                cartons_count = 0

            order_items_snapshot.append({
                'product_id': it.product_id,
                'name': it.product_name or (it.product.name if it.product else 'Packaged Water'),
                'size': it.size or (it.product.size if it.product else ''),
                'quantity': it.quantity,
                'uom': uom,
                'uom_display': uom,
                'unit_of_measure': uom,
                'unit_price': float(it.unit_price),
                'total_price': float(it.total_price),
                'line_total': float(it.total_price),
                'units_per_carton': units_per_carton,
                'cartons_count': cartons_count,
                'packaging_display': packaging_display,
            })

    financial_snapshot = {
        'order_source': order.order_source,
        'order_code': order.order_code,
        'serving_franchise_id': order.serving_franchise_id,
        'serving_franchise_name': order.serving_franchise.business_name if order.serving_franchise else (order.snapshot_serving_dealer_name or ''),
        'serving_franchise_code': f"FRN-{order.serving_franchise.id:04d}" if order.serving_franchise else (f"FRN-{order.snapshot_serving_dealer_id:04d}" if order.snapshot_serving_dealer_id else ''),
        'payment_mode': order.payment_mode,
        'payment_status': order.payment_status,
        'items': order_items_snapshot,
        'subtotal': float(subtotal),
        'delivery_charges': float(delivery_fee),
        'delivery_distance_km': float(order.delivery_distance_km) if getattr(order, 'delivery_distance_km', None) is not None else None,
        'points_discount_amount': float(points_discount),
        'wallet_amount_debited': float(wallet_debited),
        'promotional_discount': float(promo_discount),
        'taxable_amount': float(taxable_subtotal),
        'gst_rate': float(configured_gst_rate),
        'cgst_rate': float(cgst_rate),
        'sgst_rate': float(sgst_rate),
        'igst_rate': float(igst_rate),
        'cgst_amount': float(cgst_amt),
        'sgst_amount': float(sgst_amt),
        'igst_amount': float(igst_amt),
        'total_tax': float(total_tax),
        'grand_total': float(grand_total),
        'amount_paid': float(amt_paid),
        'outstanding_balance': float(max(Decimal('0.00'), grand_total - amt_paid)),
        'is_price_inclusive_gst': is_price_inclusive,
        'is_delivery_taxable': is_delivery_taxable,
        'place_of_supply': customer_state or 'chhattisgarh',
        'is_gst_invoice': is_gst,
        'generated_at': timezone.now().isoformat(),
    }

    invoice = Invoice.objects.create(
        invoice_number=inv_number,
        order=order,
        invoice_type=inv_type,
        billed_to_name=customer_name,
        billed_to_gstin=customer_gstin,
        billed_to_address=billing_addr,
        subtotal=subtotal,
        delivery_charges=delivery_fee,
        tax_rate=configured_gst_rate,
        taxable_amount=taxable_subtotal,
        is_price_inclusive_gst=is_price_inclusive,
        is_delivery_taxable=is_delivery_taxable,
        cgst_amount=cgst_amt,
        sgst_amount=sgst_amt,
        igst_amount=igst_amt,
        discount_amount=promo_discount,
        points_discount_amount=points_discount,
        wallet_amount_debited=wallet_debited,
        grand_total=grand_total,
        amount_paid=amt_paid,
        is_gst_invoice=is_gst,
        place_of_supply=customer_state or 'Chhattisgarh',
        state_code='22' if is_intra_state else getattr(order, 'gstin', '22')[:2],
        financial_snapshot=financial_snapshot,
        status=inv_status
    )

    # If wallet debited or points paid, record payment transaction ledger entry
    if wallet_debited > Decimal('0.00'):
        PaymentTransaction.objects.create(
            transaction_number=f"TXN-WAL-{order.id:04d}-{timezone.now().strftime('%Y%m%d%H%M%S')}",
            invoice=invoice,
            amount_paid=wallet_debited,
            payment_method='CREDIT_ADJUSTMENT',
            reference_number=f"WALLET-DEBIT-{order.order_code}",
            payment_status='SUCCESS',
            notes=f"Auto-settled via Water Wallet prepaid debit for {order.order_code}"
        )

    return invoice


@transaction.atomic
def submit_payment_for_verification(invoice_id, amount_paid, payment_method='UPI', reference_number='', actor=None, receipt_file=None, notes=''):
    """
    Submits a payment for verification by the admin.
    """
    invoice = Invoice.objects.select_for_update().get(id=invoice_id)
    amount_paid_dec = Decimal(str(amount_paid))

    if invoice.status == 'PAID' or invoice.outstanding_balance <= Decimal('0.00'):
        raise ValueError("Invoice is already fully paid. No further payments can be recorded.")

    if amount_paid_dec <= Decimal('0.00'):
        raise ValueError("Payment amount must be greater than zero.")

    if amount_paid_dec > invoice.outstanding_balance:
        raise ValueError(
            f"Payment amount (₹{amount_paid_dec}) cannot exceed invoice outstanding balance (₹{invoice.outstanding_balance})."
        )

    # Check for duplicate pending submission
    if reference_number and str(reference_number).strip():
        dup_pending = PaymentTransaction.objects.filter(
            invoice=invoice,
            reference_number=str(reference_number).strip(),
            payment_status__in=['SUCCESS', 'PENDING', 'PENDING_VERIFICATION']
        ).first()
        if dup_pending:
            raise ValueError(f"A payment with reference number '{str(reference_number).strip()}' has already been submitted for this invoice.")

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

    # Authoritative alert to Admin & Super Admin
    try:
        from accounts.models import AdminNotification
        franchise_name = "Franchise"
        order_code = ""
        customer_name = invoice.billed_to_name or "Customer"
        if invoice.order:
            order_code = f"#{invoice.order.order_code}"
            if invoice.order.serving_franchise:
                franchise_name = invoice.order.serving_franchise.business_name
            elif invoice.order.franchise_name:
                franchise_name = invoice.order.franchise_name

        remaining = max(Decimal('0.00'), invoice.outstanding_balance - amount_paid_dec)
        payment_type = "FULL" if remaining <= Decimal('0.00') else "PARTIAL"

        title = f"Payment Verification Required: {franchise_name}"
        msg = (
            f"Payment submitted for verification.\n"
            f"Franchise: {franchise_name}\n"
            f"Order: {order_code}\n"
            f"Customer: {customer_name}\n"
            f"Total: ₹{invoice.grand_total}\n"
            f"Payment submitted: ₹{amount_paid_dec}\n"
            f"Mode: {clean_method}\n"
            f"Type: {payment_type}\n"
            f"Remaining: ₹{remaining}\n"
            f"Ref: {reference_number or 'N/A'}"
        )
        AdminNotification.objects.create(
            title=title,
            message=msg,
            notification_type='payment_verification',
            reference_id=invoice.id,
        )
        from accounts.fcm_services import send_fcm_notification
        from django.contrib.auth import get_user_model
        User = get_user_model()
        admins = list(User.objects.filter(is_superuser=True)) + list(User.objects.filter(profile__role__in=['admin', 'super_admin']).exclude(is_superuser=True))
        send_fcm_notification(
            users=list(set(admins)),
            title=f"Payment Verification Required: ₹{amount_paid_dec}",
            body=f"{franchise_name} submitted ₹{amount_paid_dec} ({clean_method}) for {order_code}. Tap to review.",
            data={'invoice_id': invoice.id, 'screen': 'admin_billing', 'action': 'verify_payment'},
            notification_type='payment_verification',
            reference_id=invoice.id
        )
    except Exception:
        pass

    return txn


@transaction.atomic
def record_payment_transaction(invoice_id, amount_paid, payment_method='UPI', reference_number='', actor=None, receipt_file=None, notes='', is_direct_collection=False):
    """
    Records payment against an Invoice.
    - If this is a Customer Sale / Order Collection (or is_direct_collection=True),
      the fulfilling Franchise or Admin records customer payment immediately as SUCCESS,
      updating invoice.amount_paid and order.payment_status.
    - If this is a Dealer Wholesale Purchase Invoice (DEALER_PURCHASE_INVOICE) submitted
      by a dealer to clear wholesale credit, it is submitted for Admin verification.
    - If actor is Admin, it is settled immediately in all cases.
    """
    from accounts.models import FranchiseProfile, Notification
    invoice = Invoice.objects.select_for_update().get(id=invoice_id)
    amount_paid_dec = Decimal(str(amount_paid))

    is_admin = False
    if actor:
        is_admin = (
            actor.is_staff or 
            actor.is_superuser or 
            (hasattr(actor, 'profile') and actor.profile.role in ['super_admin', 'admin'])
        )

    # Wholesale purchase invoices from dealers require Admin bank verification
    is_wholesale_transfer = (invoice.invoice_type == 'DEALER_PURCHASE_INVOICE')
    if not is_admin and is_wholesale_transfer and not is_direct_collection:
        return submit_payment_for_verification(
            invoice_id=invoice_id,
            amount_paid=amount_paid,
            payment_method=payment_method,
            reference_number=reference_number,
            actor=actor,
            receipt_file=receipt_file,
            notes=notes
        )

    if invoice.status == 'PAID' or invoice.outstanding_balance <= Decimal('0.00'):
        raise ValueError("Invoice is already fully paid. No further payments can be recorded.")

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

    # Duplicate check on reference_number
    if reference_number and str(reference_number).strip():
        existing_txn = PaymentTransaction.objects.filter(
            invoice=invoice,
            reference_number=str(reference_number).strip(),
            payment_status__in=['SUCCESS', 'PENDING', 'PENDING_VERIFICATION']
        ).first()
        if existing_txn:
            raise ValueError(
                f"A payment with reference number '{str(reference_number).strip()}' has already been recorded for this invoice."
            )

    # Prevent rapid repeat duplicate taps / retries within 30 seconds
    cutoff_time = timezone.now() - datetime.timedelta(seconds=30)
    recent_dup = PaymentTransaction.objects.filter(
        invoice=invoice,
        amount_paid=amount_paid_dec,
        payment_method=clean_method,
        payment_status__in=['SUCCESS', 'PENDING', 'PENDING_VERIFICATION'],
        payment_date__gte=cutoff_time
    ).first()
    if recent_dup:
        raise ValueError("Duplicate payment submission detected. This payment was already recorded.")

    count = PaymentTransaction.objects.count() + 1
    txn_number = f"PAY-{timezone.now().strftime('%Y%m%d')}-{count:05d}"

    formatted_notes = str(notes or '')
    if not is_admin:
        tags = []
        if '[FRANCHISE_COLLECTED]' not in formatted_notes:
            tags.append('[FRANCHISE_COLLECTED]')
        if actor and getattr(actor, 'username', None) and f'COLLECTED_BY:{actor.username}' not in formatted_notes:
            tags.append(f'COLLECTED_BY:{actor.username}')
        if tags:
            tag_str = " ".join(tags)
            formatted_notes = f"{tag_str} {formatted_notes}".strip()

    txn = PaymentTransaction.objects.create(
        transaction_number=txn_number,
        invoice=invoice,
        payment_method=clean_method,
        amount_paid=amount_paid_dec,
        reference_number=reference_number or '',
        payment_status='SUCCESS',
        receipt_file=receipt_file,
        received_by=actor,
        notes=formatted_notes
    )

    invoice.amount_paid = Decimal(str(invoice.amount_paid or '0.00')) + amount_paid_dec
    if invoice.grand_total > Decimal('0.00') and (
        invoice.amount_paid >= invoice.grand_total or
        (invoice.amount_paid > Decimal('0.00') and (invoice.grand_total - invoice.amount_paid) <= Decimal('0.05'))
    ):
        invoice.amount_paid = invoice.grand_total
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
        if invoice.grand_total > Decimal('0.00') and (
            invoice.amount_paid >= invoice.grand_total or
            (invoice.amount_paid > Decimal('0.00') and (invoice.grand_total - invoice.amount_paid) <= Decimal('0.05'))
        ):
            invoice.amount_paid = invoice.grand_total
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

            try:
                from accounts.fcm_services import notify_payment_received
                notify_payment_received(order, amount_paid_dec, actor_name=admin_user.get_full_name() or admin_user.username, is_pending=False, invoice=invoice)
            except Exception as e:
                logger.warning("FCM: Customer payment approval push error: %s", e)

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

                if dealer:
                    try:
                        from accounts.models import FranchiseNotification
                        from accounts.fcm_services import send_fcm_notification
                        FranchiseNotification.objects.create(
                            franchise=dealer,
                            title='Payment Approved & Verified',
                            message=f"Admin verified your payment of ₹{amount_paid_dec:,.2f} for Invoice {invoice.invoice_number}. Your ledger and available credit have been updated.",
                            notification_type='payment_approved',
                            reference_id=invoice.id,
                        )
                        if dealer.user:
                            send_fcm_notification(
                                users=[dealer.user],
                                title='Payment Approved ✅',
                                body=f"Your payment of ₹{amount_paid_dec:,.2f} for Invoice {invoice.invoice_number} is approved and ledger updated.",
                                data={'invoice_id': invoice.id, 'screen': 'franchise_billing'},
                                notification_type='payment_approved',
                                reference_id=invoice.id,
                            )
                    except Exception:
                        pass
        return txn
    elif action == 'reject':
        txn.payment_status = 'REJECTED'
        rejection_notes = notes or 'Payment details could not be verified with bank receipt.'
        txn.notes = f"{txn.notes}\nRejected by {admin_user.email}: {rejection_notes}".strip()
        txn.save()

        # Notify dealer/submitter
        try:
            from accounts.models import FranchiseProfile, FranchiseNotification
            from accounts.fcm_services import send_fcm_notification
            dealer = None
            if invoice.order and invoice.order.serving_franchise:
                dealer = invoice.order.serving_franchise
            elif hasattr(invoice, 'dealer_stock_request') and invoice.dealer_stock_request:
                dealer = invoice.dealer_stock_request.dealer
            elif txn.received_by:
                dealer = FranchiseProfile.objects.filter(user=txn.received_by).first()

            if dealer:
                FranchiseNotification.objects.create(
                    franchise=dealer,
                    title='Payment Rejected',
                    message=f"Admin rejected payment of ₹{txn.amount_paid:,.2f} for Invoice {txn.invoice.invoice_number}. Reason: {rejection_notes}",
                    notification_type='payment_rejected',
                    reference_id=txn.invoice.id,
                )
                if dealer.user:
                    send_fcm_notification(
                        users=[dealer.user],
                        title='Payment Rejected ❌',
                        body=f"Payment of ₹{txn.amount_paid:,.2f} for Invoice {txn.invoice.invoice_number} was rejected: {rejection_notes}",
                        data={'invoice_id': txn.invoice.id, 'screen': 'franchise_billing'},
                        notification_type='payment_rejected',
                        reference_id=txn.invoice.id,
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


def get_dealer_account_statement(dealer_id, start_date=None, end_date=None):
    """
    Generates a complete chronological account statement for a franchise dealer.
    Combines Dealer Purchase Invoices (Debits) and Payment Transactions (Credits)
    with running balance and status.
    """
    from accounts.models import FranchiseProfile
    from django.db.models import Q

    dealer = FranchiseProfile.objects.filter(id=dealer_id).first()
    if not dealer:
        dealer = FranchiseProfile.objects.filter(user_id=dealer_id).first()
    if not dealer:
        raise ValueError(f"Dealer with ID {dealer_id} not found.")

    credit_profile, _ = DealerCreditProfile.objects.get_or_create(dealer=dealer)

    invoices = Invoice.objects.filter(
        Q(stock_request__dealer=dealer) | Q(billed_to_name=dealer.business_name),
        invoice_type='DEALER_PURCHASE_INVOICE'
    ).select_related('stock_request', 'stock_request__product')

    if start_date:
        invoices = invoices.filter(issued_at__date__gte=start_date)
    if end_date:
        invoices = invoices.filter(issued_at__date__lte=end_date)

    inv_ids = list(invoices.values_list('id', flat=True))

    payments = PaymentTransaction.objects.filter(
        invoice_id__in=inv_ids
    ).select_related('invoice')

    ledger_entries = []

    for inv in invoices:
        desc = "Stock Purchase Invoice"
        if inv.stock_request and inv.stock_request.product:
            desc = f"Stock Purchase: {inv.stock_request.product.name} (Qty: {inv.stock_request.quantity_requested})"
        ledger_entries.append({
            'date': inv.issued_at.isoformat() if inv.issued_at else '',
            'type': 'DEBIT_INVOICE',
            'doc_type': 'Invoice',
            'doc_number': inv.invoice_number,
            'invoice_id': inv.id,
            'description': desc,
            'debit': Decimal(str(inv.grand_total)),
            'credit': Decimal('0.00'),
            'status': inv.status,
            'payment_status': inv.status,
            'amount_paid': Decimal(str(inv.amount_paid)),
            'outstanding': Decimal(str(inv.outstanding_balance)),
        })

    for p in payments:
        ledger_entries.append({
            'date': p.payment_date.isoformat() if p.payment_date else '',
            'type': 'CREDIT_PAYMENT',
            'doc_type': 'Payment',
            'doc_number': p.transaction_number,
            'invoice_id': p.invoice_id,
            'invoice_number': p.invoice.invoice_number if p.invoice else '',
            'description': f"Payment via {p.payment_method}" + (f" (Ref: {p.reference_number})" if p.reference_number else ""),
            'debit': Decimal('0.00'),
            'credit': Decimal(str(p.amount_paid)),
            'status': p.payment_status,
            'payment_status': p.payment_status,
            'amount_paid': Decimal(str(p.amount_paid)),
            'outstanding': Decimal('0.00'),
        })

    ledger_entries.sort(key=lambda x: x['date'])

    running_balance = Decimal('0.00')
    total_debits = Decimal('0.00')
    total_credits = Decimal('0.00')
    total_pending_credits = Decimal('0.00')

    for entry in ledger_entries:
        if entry['type'] == 'DEBIT_INVOICE':
            running_balance += entry['debit']
            total_debits += entry['debit']
        elif entry['type'] == 'CREDIT_PAYMENT':
            if entry['status'] == 'SUCCESS':
                running_balance = max(Decimal('0.00'), running_balance - entry['credit'])
                total_credits += entry['credit']
            elif entry['status'] == 'PENDING_VERIFICATION':
                total_pending_credits += entry['credit']
        entry['running_balance'] = running_balance

    limit = Decimal(str(credit_profile.credit_limit or '0.00'))
    current_out = Decimal(str(credit_profile.current_outstanding or '0.00'))
    available = max(Decimal('0.00'), limit - current_out) if limit > Decimal('0.00') else Decimal('0.00')

    return {
        'dealer_id': dealer.id,
        'dealer_name': dealer.business_name,
        'dealer_code': dealer.dealer_code,
        'gst_number': dealer.gst_number,
        'phone': getattr(dealer, 'phone', getattr(getattr(dealer.user, 'profile', None), 'phone', '')),
        'address': dealer.address,
        'credit_limit': limit,
        'current_outstanding': current_out,
        'available_credit': available,
        'payment_terms_days': credit_profile.payment_terms_days,
        'credit_status': credit_profile.credit_status,
        'last_payment_date': credit_profile.last_payment_date,
        'total_invoiced': total_debits,
        'total_paid_cleared': total_credits,
        'total_pending_verification': total_pending_credits,
        'statement_balance': running_balance,
        'ledger_entries': ledger_entries,
    }


def get_dealer_stock_payment_reconciliation(dealer_id):
    """
    Reconciles physical & allocated stock versus wholesale billing & payments.
    """
    from accounts.models import FranchiseProfile
    from inventory.models import DealerStockBatch, DealerStockRequest
    from django.db.models import Q

    dealer = FranchiseProfile.objects.filter(id=dealer_id).first()
    if not dealer:
        dealer = FranchiseProfile.objects.filter(user_id=dealer_id).first()
    if not dealer:
        raise ValueError(f"Dealer with ID {dealer_id} not found.")

    credit_profile, _ = DealerCreditProfile.objects.get_or_create(dealer=dealer)

    stock_batches = DealerStockBatch.objects.filter(dealer=dealer).select_related('product')
    total_received_units = sum(b.received_quantity for b in stock_batches)
    total_remaining_units = sum(b.remaining_quantity for b in stock_batches)
    total_damaged_units = sum(b.damaged_quantity for b in stock_batches)
    total_stock_value = sum(
        Decimal(str(b.remaining_quantity)) * Decimal(str(b.unit_transfer_price or b.product.dealer_transfer_price or '0.00'))
        for b in stock_batches
    )

    stock_requests = DealerStockRequest.objects.filter(dealer=dealer)
    total_requests_count = stock_requests.count()
    fulfilled_requests_count = stock_requests.filter(status='FULFILLED').count()

    invoices = Invoice.objects.filter(
        Q(stock_request__dealer=dealer) | Q(billed_to_name=dealer.business_name),
        invoice_type='DEALER_PURCHASE_INVOICE'
    )
    total_invoiced_amt = sum((inv.grand_total for inv in invoices), Decimal('0.00'))
    total_invoices_paid_amt = sum((inv.amount_paid for inv in invoices), Decimal('0.00'))
    unpaid_invoices_balance = sum((inv.outstanding_balance for inv in invoices), Decimal('0.00'))

    payments = PaymentTransaction.objects.filter(invoice__in=invoices)
    cleared_payments_amt = sum(
        (p.amount_paid for p in payments.filter(payment_status='SUCCESS')),
        Decimal('0.00')
    )
    pending_payments_amt = sum(
        (p.amount_paid for p in payments.filter(payment_status='PENDING_VERIFICATION')),
        Decimal('0.00')
    )

    current_outstanding = Decimal(str(credit_profile.current_outstanding or '0.00'))
    expected_outstanding = max(Decimal('0.00'), total_invoiced_amt - cleared_payments_amt)
    discrepancy = abs(current_outstanding - expected_outstanding)
    is_reconciled = discrepancy <= Decimal('0.05')

    cover_ratio = (
        round((total_stock_value / current_outstanding) * Decimal('100.00'), 2)
        if current_outstanding > Decimal('0.00')
        else Decimal('100.00')
    )

    return {
        'dealer_id': dealer.id,
        'dealer_name': dealer.business_name,
        'dealer_code': dealer.dealer_code,
        'stock_summary': {
            'total_received_units': total_received_units,
            'total_remaining_units': total_remaining_units,
            'total_damaged_units': total_damaged_units,
            'current_stock_valuation': total_stock_value,
            'total_requests_count': total_requests_count,
            'fulfilled_requests_count': fulfilled_requests_count,
        },
        'financial_summary': {
            'credit_limit': credit_profile.credit_limit,
            'current_outstanding': current_outstanding,
            'expected_outstanding': expected_outstanding,
            'total_invoiced': total_invoiced_amt,
            'cleared_payments': cleared_payments_amt,
            'pending_verification_payments': pending_payments_amt,
            'unpaid_invoices_balance': unpaid_invoices_balance,
            'is_reconciled': is_reconciled,
            'discrepancy_amount': discrepancy,
            'stock_cover_ratio_percent': cover_ratio,
        }
    }



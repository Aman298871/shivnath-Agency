from django.db import transaction
from django.db.models import F
from django.core.exceptions import ValidationError
from django.utils import timezone
from django.utils.dateparse import parse_date
from decimal import Decimal
import datetime

from products.models import Product, ProductionRecipeBOM
from inventory.models import (
    RawMaterial,
    ProductionBatch,
    DealerStockBatch,
    DealerStockRequest,
    DealerStockRequestAllocation,
    InventoryTransactionLedger,
)
from orders.models import Order, OrderItem, OrderItemBatchReservation
from billing.models import Invoice, CompanyBillingProfile, DealerCreditProfile


def _coerce_date(value, default=None):
    """
    Safely converts date, datetime, or ISO string to a datetime.date object.
    Prevents TypeError comparisons between datetime.date and str.
    Uses fromisoformat first, falls back to Django's parse_date.
    """
    if not value:
        return default
    if isinstance(value, datetime.datetime):
        return value.date()
    if isinstance(value, datetime.date):
        return value
    if isinstance(value, str):
        val_str = value.strip()
        if not val_str:
            return default
        if 'T' in val_str:
            val_str = val_str.split('T')[0]
        try:
            return datetime.date.fromisoformat(val_str)
        except (ValueError, TypeError):
            parsed = parse_date(val_str)
            if parsed:
                return parsed
    return default


@transaction.atomic
def record_raw_material_purchase_receipt(purchase_order, actor=None):
    """
    Processes receipt of raw materials from a PurchaseOrder.
    Increments RawMaterial.current_stock and logs PURCHASE_IN ledger entries atomically.
    """
    for item in purchase_order.items.select_related('raw_material').all():
        raw_mat = RawMaterial.objects.select_for_update().get(id=item.raw_material_id)
        qty = item.received_quantity if item.received_quantity > 0 else item.quantity
        raw_mat.current_stock += qty
        raw_mat.save()

        InventoryTransactionLedger.objects.create(
            transaction_type='PURCHASE_IN',
            material_type='RAW_MATERIAL',
            location_type='COMPANY_WAREHOUSE',
            raw_material=raw_mat,
            quantity=qty,
            balance_after=raw_mat.current_stock,
            unit_cost_or_price=item.unit_price,
            reference_type='PURCHASE_ORDER',
            reference_id=purchase_order.po_number,
            actor=actor,
            notes=f"Supplier purchase received from {purchase_order.supplier.name}"
        )
    purchase_order.status = 'RECEIVED'
    purchase_order.received_date = timezone.now().date()
    purchase_order.save()
    return purchase_order


@transaction.atomic
def create_production_batch_atomic(
    product_id,
    quantity_produced_units,
    manufacture_date=None,
    expiry_date=None,
    batch_number=None,
    shelf_life_days=None,
    client_name=None,
    linked_order=None,
    label_requirement=None,
    printing_requirement=None,
    branding_requirement=None,
    actor=None
):
    """
    Validates raw material availability based on BOM recipe,
    deducts raw material stocks via PRODUCTION_CONSUMPTION,
    creates the ProductionBatch with configurable shelf-life and client bulk specifications,
    and logs PRODUCTION_IN finished goods entry atomically.
    """
    if isinstance(product_id, int) or (isinstance(product_id, str) and str(product_id).strip().isdigit()):
        product = Product.objects.select_for_update().filter(id=int(product_id)).first()
    else:
        product = Product.objects.select_for_update().filter(sku__iexact=str(product_id).strip()).first()
    if not product:
        raise ValidationError(f"Product '{product_id}' not found in Product Master.")

    now_date = timezone.now().date()
    mfg_date = _coerce_date(manufacture_date, default=now_date)

    # Shelf-life must be configurable per product/batch, never hardcoded.
    try:
        parsed_shelf_life = int(shelf_life_days) if shelf_life_days not in (None, '') else None
    except (ValueError, TypeError):
        parsed_shelf_life = None

    effective_shelf_life = (
        parsed_shelf_life
        if parsed_shelf_life is not None and parsed_shelf_life > 0
        else (product.shelf_life_days or 180)
    )
    default_expiry = mfg_date + datetime.timedelta(days=effective_shelf_life)
    exp_date = _coerce_date(expiry_date, default=default_expiry)

    if not batch_number:
        count = ProductionBatch.objects.filter(product=product).count() + 1
        batch_number = f"PB-{mfg_date.strftime('%Y%m')}-{product.sku}-{count:03d}"

    # Resolve linked order if passed as ID or ORD-code
    order_instance = None
    if linked_order:
        if isinstance(linked_order, Order):
            order_instance = linked_order
        else:
            try:
                raw_ord = str(linked_order).strip()
                if raw_ord.upper().startswith('ORD-'):
                    cleaned_num = raw_ord.upper().replace('ORD-', '')
                    parsed_val = int(cleaned_num)
                    # Order code is ORD-(1000 + id)
                    if parsed_val > 1000:
                        order_instance = Order.objects.select_for_update().filter(id=parsed_val - 1000).first()
                    if not order_instance:
                        order_instance = Order.objects.select_for_update().filter(id=parsed_val).first()
                else:
                    parsed_val = int(raw_ord)
                    order_instance = Order.objects.select_for_update().filter(id=parsed_val).first()
                    if not order_instance and parsed_val > 1000:
                        order_instance = Order.objects.select_for_update().filter(id=parsed_val - 1000).first()
            except Exception:
                order_instance = None

    # Resolve client name
    resolved_client_name = client_name or ''
    if not resolved_client_name and order_instance:
        resolved_client_name = order_instance.client_name or order_instance.franchise_name or ''

    # Verify BOM Recipe for this EXACT product
    try:
        recipe_bom = ProductionRecipeBOM.objects.prefetch_related('items__raw_material').get(product=product)
        bom_items = list(recipe_bom.items.all())
    except ProductionRecipeBOM.DoesNotExist:
        recipe_bom = None
        bom_items = []

    if not recipe_bom or not bom_items:
        raise ValidationError(
            f"BOM is not configured for this product ({product.name} — SKU: {product.sku}). "
            "Please configure the Bill of Materials recipe before manufacturing."
        )

    # 1. Check raw material stock sufficiency with row locks
    qty_decimal = Decimal(quantity_produced_units)
    for bom_item in bom_items:
        required_qty = bom_item.quantity_required_per_unit * qty_decimal
        rm = RawMaterial.objects.select_for_update().get(id=bom_item.raw_material_id)
        if rm.current_stock < required_qty:
            raise ValidationError(
                f"Insufficient raw material for {rm.name} ({rm.sku}): "
                f"Required {required_qty} {rm.unit_of_measure}, Available {rm.current_stock} {rm.unit_of_measure}."
            )
        rm.current_stock -= required_qty
        rm.save()

        # Log PRODUCTION_CONSUMPTION
        InventoryTransactionLedger.objects.create(
            transaction_type='PRODUCTION_CONSUMPTION',
            material_type='RAW_MATERIAL',
            location_type='COMPANY_WAREHOUSE',
            raw_material=rm,
            quantity=-required_qty,
            balance_after=rm.current_stock,
            unit_cost_or_price=bom_item.unit_cost_snapshot,
            reference_type='PRODUCTION_BATCH',
            reference_id=batch_number,
            actor=actor,
            notes=f"Consumed for batch {batch_number} of {product.name}"
        )

    # 2. Determine frozen unit production cost
    unit_prod_cost = recipe_bom.total_production_cost_per_unit if bom_items else Decimal('0.00')

    # 3. Create Production Batch
    batch = ProductionBatch.objects.create(
        batch_number=batch_number,
        product=product,
        client_name=resolved_client_name,
        linked_order=order_instance,
        label_requirement=label_requirement or (order_instance.label_requirement if order_instance else ''),
        printing_requirement=printing_requirement or (order_instance.printing_requirement if order_instance else ''),
        branding_requirement=branding_requirement or (order_instance.branding_requirement if order_instance else ''),
        shelf_life_days=effective_shelf_life,
        manufacture_date=mfg_date,
        expiry_date=exp_date,
        quantity_produced_units=quantity_produced_units,
        quantity_remaining_company=quantity_produced_units,
        reserved_quantity=0,
        quantity_dispatched=0,
        unit_production_cost=unit_prod_cost,
        status='ACTIVE',
        created_by=actor
    )

    # If linked to an order, update order production totals
    if order_instance:
        order_instance.total_produced_units += quantity_produced_units
        order_instance.total_pending_stock_units = max(0, order_instance.total_produced_units - order_instance.total_delivered_units)
        if order_instance.status in ['order_placement', 'plant_approval']:
            order_instance.status = 'preparing'
        order_instance.save()

    # 4. Increase finished stock for this exact product in Product Master
    product.stock += quantity_produced_units
    product.save(update_fields=['stock', 'updated_at'])

    # 5. Log PRODUCTION_IN finished goods referencing exact product and batch
    InventoryTransactionLedger.objects.create(
        transaction_type='PRODUCTION_IN',
        material_type='FINISHED_GOODS',
        location_type='COMPANY_WAREHOUSE',
        product=product,
        production_batch=batch,
        quantity=Decimal(quantity_produced_units),
        balance_after=Decimal(product.stock),
        unit_cost_or_price=unit_prod_cost,
        reference_type='PRODUCTION_BATCH',
        reference_id=batch_number,
        actor=actor,
        notes=f"Manufactured {quantity_produced_units} units of {product.name} (SKU: {product.sku}, Client: {resolved_client_name or 'General'})"
    )

    return batch


@transaction.atomic
def record_batch_collection_atomic(
    batch_id,
    quantity_collected,
    client_name=None,
    notes=None,
    actor=None,
    payment_status=None,
    payment_method='CASH',
    reference_number='',
    amount_due=None,
    amount_paid=None,
    delivery_status=None,
):
    """
    Authoritative handler for customer/dealer partial collection or dispatch from a ProductionBatch.
    Example:
      - Digital Marketing Wala places order for 5,000 units.
      - Batch produces 5,000 units.
      - Customer collects 2,000 units.
      - Remaining 3,000 units STAY as company pending stock attached to this batch.
    Updates batch.quantity_dispatched, batch.quantity_remaining_company, and writes an immutable ledger entry.
    Also supports recording authoritative payment & invoice details for full, partial, or unpaid collections.
    """
    batch = ProductionBatch.objects.select_for_update().get(id=batch_id)
    qty = int(quantity_collected)

    if batch.is_expired or batch.status in ['EXPIRED', 'RECALLED']:
        raise ValidationError(
            f"Cannot dispatch or collect from batch {batch.batch_number}: Batch is expired (Expiry date: {batch.expiry_date}) or marked {batch.status}."
        )

    if qty <= 0:
        raise ValidationError("Quantity collected must be greater than zero.")

    if qty > batch.quantity_remaining_company:
        raise ValidationError(
            f"Cannot collect {qty} units. Only {batch.quantity_remaining_company} units remaining in company stock."
        )

    # 1. Update batch counters
    if hasattr(batch, 'quantity_dispatched'):
        batch.quantity_dispatched += qty
    batch.quantity_remaining_company -= qty
    if batch.quantity_remaining_company == 0:
        batch.status = 'DEPLETED'
    batch.save()

    # 2. Update linked order if present
    order = batch.linked_order
    if order:
        order = Order.objects.select_for_update().get(id=order.id)
        if hasattr(order, 'total_delivered_units'):
            order.total_delivered_units += qty
        if hasattr(order, 'total_pending_stock_units'):
            order.total_pending_stock_units = max(0, getattr(order, 'total_produced_units', 0) - getattr(order, 'total_delivered_units', 0))
        
        # Explicit delivery status chosen by Admin, else auto-determine based on quantities
        if delivery_status and delivery_status in dict(Order.STATUS_CHOICES).keys():
            order.status = delivery_status
            if delivery_status == 'delivered':
                order.delivered_at = timezone.now()
        elif hasattr(order, 'total_delivered_units') and hasattr(order, 'total_produced_units') and order.total_delivered_units >= order.total_produced_units and order.total_produced_units > 0:
            order.status = 'delivered'
            order.delivered_at = timezone.now()
        else:
            order.status = 'dispatch'
        order.save()

    # 3. Log authoritative inventory ledger entry
    collector = client_name or batch.client_name or 'Customer / Dealer'
    dispatched_count = batch.quantity_produced_units - batch.quantity_remaining_company
    audit_notes = (
        f"Collection/Dispatch of {qty} units by {collector}. "
        f"Produced: {batch.quantity_produced_units}, Dispatched: {dispatched_count}, "
        f"Pending in company stock: {batch.quantity_remaining_company} units. "
        f"{notes or ''}"
    ).strip()

    InventoryTransactionLedger.objects.create(
        transaction_type='STOCK_TRANSFER_OUT',
        material_type='FINISHED_GOODS',
        location_type='COMPANY_WAREHOUSE',
        product=batch.product,
        production_batch=batch,
        quantity=-Decimal(qty),
        balance_after=Decimal(batch.quantity_remaining_company),
        unit_cost_or_price=batch.unit_production_cost,
        reference_type='CUSTOMER_COLLECTION',
        reference_id=batch.batch_number,
        actor=actor,
        notes=audit_notes
    )

    # 4. Handle authoritative payment & billing if payment info provided
    billing_summary = None
    if payment_status or amount_due is not None or amount_paid is not None:
        from billing.models import Invoice, CompanyBillingProfile
        from billing.services import generate_invoice_for_order, record_payment_transaction

        amount_due_dec = Decimal(str(amount_due or '0.00')) if amount_due is not None else Decimal('0.00')
        amount_paid_dec = Decimal(str(amount_paid or '0.00')) if amount_paid is not None else Decimal('0.00')

        # Auto-compute amount_due from unit price if not specified
        if amount_due_dec <= Decimal('0.00'):
            unit_price = Decimal(str(batch.product.price if batch.product and batch.product.price else '20.00'))
            amount_due_dec = unit_price * Decimal(qty)

        p_status_upper = str(payment_status or '').upper().strip()
        if p_status_upper == 'FULL':
            amount_paid_dec = amount_due_dec
        elif p_status_upper == 'UNPAID':
            amount_paid_dec = Decimal('0.00')
        elif p_status_upper == 'PARTIAL':
            if amount_paid_dec > amount_due_dec:
                raise ValidationError(f"Amount paid (₹{amount_paid_dec}) cannot exceed amount due (₹{amount_due_dec}).")

        if amount_paid_dec > amount_due_dec:
            raise ValidationError(f"Amount paid (₹{amount_paid_dec}) cannot exceed amount due (₹{amount_due_dec}).")

        # Find or create invoice
        if order:
            invoice = generate_invoice_for_order(order)
            if invoice.grand_total == Decimal('0.00') and amount_due_dec > Decimal('0.00'):
                invoice.subtotal = amount_due_dec
                invoice.grand_total = amount_due_dec
                invoice.save(update_fields=['subtotal', 'grand_total'])
        else:
            billing_profile = CompanyBillingProfile.objects.filter(is_configured=True).first()
            prefix = billing_profile.invoice_prefix if billing_profile else 'SHV/2026/'
            inv_count = Invoice.objects.count() + 1
            inv_number = f"{prefix}COL-{inv_count:04d}"
            invoice = Invoice.objects.create(
                invoice_number=inv_number,
                invoice_type='DIRECT_COMPANY_SALE_INVOICE',
                billed_to_name=collector,
                subtotal=amount_due_dec,
                grand_total=amount_due_dec,
                amount_paid=Decimal('0.00'),
                status='UNPAID'
            )

        txn = None
        if amount_paid_dec > Decimal('0.00'):
            p_method = 'CASH' if str(payment_method).upper() == 'CASH' else 'UPI'
            txn = record_payment_transaction(
                invoice_id=invoice.id,
                amount_paid=amount_paid_dec,
                payment_method=p_method,
                reference_number=reference_number or '',
                actor=actor,
                notes=f"Customer collection payment for Batch {batch.batch_number} ({qty} units). {notes or ''}".strip()
            )
        invoice.refresh_from_db()

        rem_balance = max(Decimal('0.00'), invoice.grand_total - invoice.amount_paid)
        billing_summary = {
            'invoice_id': invoice.id,
            'invoice_number': invoice.invoice_number,
            'amount_due': float(invoice.grand_total),
            'amount_paid': float(invoice.amount_paid),
            'remaining_amount': float(rem_balance),
            'payment_status': invoice.status,
            'payment_method': payment_method,
            'transaction_number': txn.transaction_number if txn else None,
        }

    return {
        'batch': batch,
        'quantity_collected': qty,
        'quantity_produced': batch.quantity_produced_units,
        'quantity_dispatched': batch.quantity_dispatched,
        'quantity_remaining_company': batch.quantity_remaining_company,
        'pending_stock': batch.quantity_pending_collection,
        'order_status': order.status if order else None,
        'billing_summary': billing_summary,
    }


@transaction.atomic
def adjust_production_batch_atomic(batch_id, adjustment_type, quantity, reason, actor=None):
    """
    Authoritative stock adjustment for a ProductionBatch:
    Supports: DAMAGE, RETURN, EXPIRY, AUDIT_ADJUSTMENT.
    Updates relevant quantity counters, remaining stock, records adjustment reason,
    and writes an immutable entry into InventoryTransactionLedger with full audit history.
    """
    batch = ProductionBatch.objects.select_for_update().get(id=batch_id)
    qty = int(quantity)
    if qty <= 0:
        raise ValidationError("Adjustment quantity must be greater than zero.")

    adj_clean = str(adjustment_type).strip().upper()
    if not reason or not str(reason).strip():
        raise ValidationError("A recorded reason is mandatory for stock adjustments.")

    now_notes = f"[{adj_clean}] {qty} units: {str(reason).strip()}"
    if batch.adjustment_reason:
        batch.adjustment_reason = f"{batch.adjustment_reason}\n{now_notes}"
    else:
        batch.adjustment_reason = now_notes

    if adj_clean == 'DAMAGE':
        if qty > batch.quantity_remaining_company:
            raise ValidationError(f"Cannot log {qty} damaged units. Only {batch.quantity_remaining_company} units remaining in company stock.")
        batch.quantity_damaged += qty
        batch.quantity_remaining_company -= qty
        if batch.quantity_remaining_company == 0:
            batch.status = 'DEPLETED'
        batch.save()

        InventoryTransactionLedger.objects.create(
            transaction_type='DAMAGE',
            material_type='FINISHED_GOODS',
            location_type='COMPANY_WAREHOUSE',
            product=batch.product,
            production_batch=batch,
            quantity=-Decimal(qty),
            balance_after=Decimal(batch.quantity_remaining_company),
            unit_cost_or_price=batch.unit_production_cost,
            reference_type='BATCH_DAMAGE_ADJUSTMENT',
            reference_id=batch.batch_number,
            actor=actor,
            notes=now_notes
        )
    elif adj_clean == 'RETURN':
        batch.quantity_returned += qty
        batch.quantity_remaining_company += qty
        if batch.status == 'DEPLETED' and batch.quantity_remaining_company > 0:
            batch.status = 'ACTIVE'
        batch.save()

        InventoryTransactionLedger.objects.create(
            transaction_type='RETURN',
            material_type='FINISHED_GOODS',
            location_type='COMPANY_WAREHOUSE',
            product=batch.product,
            production_batch=batch,
            quantity=Decimal(qty),
            balance_after=Decimal(batch.quantity_remaining_company),
            unit_cost_or_price=batch.unit_production_cost,
            reference_type='BATCH_RETURN_RESTOCK',
            reference_id=batch.batch_number,
            actor=actor,
            notes=now_notes
        )
    elif adj_clean == 'EXPIRY':
        if qty > batch.quantity_remaining_company:
            raise ValidationError(f"Cannot dispose {qty} units. Only {batch.quantity_remaining_company} units remaining in stock.")
        batch.quantity_expired += qty
        batch.quantity_remaining_company -= qty
        if batch.quantity_remaining_company == 0:
            batch.status = 'EXPIRED'
        batch.save()

        InventoryTransactionLedger.objects.create(
            transaction_type='EXPIRY',
            material_type='FINISHED_GOODS',
            location_type='COMPANY_WAREHOUSE',
            product=batch.product,
            production_batch=batch,
            quantity=-Decimal(qty),
            balance_after=Decimal(batch.quantity_remaining_company),
            unit_cost_or_price=batch.unit_production_cost,
            reference_type='BATCH_EXPIRY_DISPOSAL',
            reference_id=batch.batch_number,
            actor=actor,
            notes=now_notes
        )
    elif adj_clean in ['ADJUSTMENT', 'AUDIT_ADJUSTMENT']:
        # Stock balance adjustment
        batch.quantity_remaining_company = max(0, qty)
        if batch.quantity_remaining_company == 0:
            batch.status = 'DEPLETED'
        elif batch.status == 'DEPLETED' and batch.quantity_remaining_company > 0:
            batch.status = 'ACTIVE'
        batch.save()

        InventoryTransactionLedger.objects.create(
            transaction_type='ADJUSTMENT',
            material_type='FINISHED_GOODS',
            location_type='COMPANY_WAREHOUSE',
            product=batch.product,
            production_batch=batch,
            quantity=Decimal(qty),
            balance_after=Decimal(batch.quantity_remaining_company),
            unit_cost_or_price=batch.unit_production_cost,
            reference_type='BATCH_STOCK_CORRECTION',
            reference_id=batch.batch_number,
            actor=actor,
            notes=now_notes
        )
    else:
        raise ValidationError(f"Unsupported adjustment type: {adj_clean}. Must be DAMAGE, RETURN, EXPIRY, or AUDIT_ADJUSTMENT.")

    return batch


@transaction.atomic
def allocate_and_dispatch_stock_request_atomic(stock_request, allocations_list, actor=None):
    """
    Multi-batch relational stock allocation and dispatch to a Wholesale Dealer.
    Deducts company batch stock, creates DealerStockRequestAllocation, logs STOCK_TRANSFER_OUT,
    and generates wholesale purchase invoice.
    allocations_list: [{"batch_id": int, "quantity": int}]
    """
    today = timezone.now().date()
    total_dispatched = 0

    for alloc in allocations_list:
        batch_id = alloc.get('batch_id')
        qty = int(alloc.get('quantity', 0))
        if qty <= 0:
            continue

        pbatch = ProductionBatch.objects.select_for_update().get(id=batch_id)
        exp = _coerce_date(pbatch.expiry_date, default=today)
        if exp <= today:
            raise ValidationError(f"Batch {pbatch.batch_number} is expired ({pbatch.expiry_date}) and cannot be allocated.")
        if pbatch.available_quantity < qty:
            raise ValidationError(
                f"Batch {pbatch.batch_number} does not have enough available stock. "
                f"Available: {pbatch.available_quantity}, Requested: {qty}"
            )

        # Update batch stock
        pbatch.quantity_remaining_company -= qty
        pbatch.save()

        # Create or update relational allocation
        allocation, _ = DealerStockRequestAllocation.objects.get_or_create(
            stock_request=stock_request,
            production_batch=pbatch,
            defaults={
                'allocated_quantity': qty,
                'prepared_quantity': qty,
                'dispatched_quantity': qty,
            }
        )
        if not _:
            allocation.allocated_quantity += qty
            allocation.prepared_quantity += qty
            allocation.dispatched_quantity += qty
            allocation.save()

        total_dispatched += qty

        # Log STOCK_TRANSFER_OUT ledger entry
        InventoryTransactionLedger.objects.create(
            transaction_type='STOCK_TRANSFER_OUT',
            material_type='FINISHED_GOODS',
            location_type='COMPANY_WAREHOUSE',
            dealer=stock_request.dealer,
            product=stock_request.product,
            production_batch=pbatch,
            quantity=-Decimal(qty),
            balance_after=Decimal(pbatch.quantity_remaining_company),
            unit_cost_or_price=stock_request.product.dealer_transfer_price,
            reference_type='STOCK_REQUEST',
            reference_id=stock_request.request_number,
            actor=actor,
            notes=f"Dispatched to dealer {stock_request.dealer.business_name}"
        )

    stock_request.dispatched_quantity += total_dispatched
    stock_request.dispatched_by = actor
    if stock_request.dispatched_quantity >= stock_request.requested_quantity:
        stock_request.status = 'DISPATCHED'
    else:
        stock_request.status = 'PARTIALLY_FULFILLED'
    stock_request.save()

    # Generate Wholesale Purchase Invoice
    billing_profile = CompanyBillingProfile.objects.filter(is_configured=True).first()
    unit_transfer_price = Decimal(str(stock_request.product.dealer_transfer_price or '0.00'))
    subtotal = Decimal(total_dispatched) * unit_transfer_price
    cgst_rate = Decimal(str(billing_profile.cgst_rate)) if billing_profile and billing_profile.cgst_rate is not None else Decimal('9.00')
    sgst_rate = Decimal(str(billing_profile.sgst_rate)) if billing_profile and billing_profile.sgst_rate is not None else Decimal('9.00')
    cgst_amt = (subtotal * cgst_rate) / Decimal('100.00')
    sgst_amt = (subtotal * sgst_rate) / Decimal('100.00')
    grand_total = subtotal + cgst_amt + sgst_amt

    inv_count = Invoice.objects.count() + 1
    prefix = billing_profile.invoice_prefix if billing_profile else 'SHV/2026/'
    inv_number = f"{prefix}WHL-{inv_count:04d}"

    invoice = Invoice.objects.create(
        invoice_number=inv_number,
        stock_request=stock_request,
        invoice_type='DEALER_PURCHASE_INVOICE',
        billed_to_name=stock_request.dealer.business_name,
        billed_to_gstin=stock_request.dealer.gst_number,
        billed_to_address=stock_request.dealer.address,
        subtotal=subtotal,
        cgst_amount=cgst_amt,
        sgst_amount=sgst_amt,
        grand_total=grand_total,
        amount_paid=Decimal('0.00'),
        status='UNPAID'
    )

    # Check and enforce dealer credit limit
    credit_profile, _ = DealerCreditProfile.objects.select_for_update().get_or_create(dealer=stock_request.dealer)
    current_out = Decimal(str(credit_profile.current_outstanding or '0.00'))
    limit = Decimal(str(credit_profile.credit_limit or '0.00'))

    if credit_profile.credit_status in ['BLOCKED', 'CREDIT_BLOCKED']:
        raise ValidationError(f"Dealer {stock_request.dealer.business_name} credit is BLOCKED.")
    if limit > Decimal('0.00') and (current_out + grand_total) > limit:
        raise ValidationError(
            f"Credit limit exceeded for {stock_request.dealer.business_name}. "
            f"Limit: ₹{limit}, Outstanding: ₹{current_out}, "
            f"Dispatch Grand Total: ₹{grand_total}."
        )

    credit_profile.current_outstanding = current_out + grand_total
    if limit > Decimal('0.00') and credit_profile.current_outstanding > limit:
        credit_profile.credit_status = 'PAYMENT_DUE'
    credit_profile.save()

    return stock_request, invoice



@transaction.atomic
def receive_stock_request_atomic(stock_request, receipt_items, actor=None):
    """
    Wholesale Dealer confirms receipt of dispatched stock.
    Creates or updates DealerStockBatch records and logs STOCK_TRANSFER_IN and DAMAGE ledger entries.
    receipt_items: [{"allocation_id": int, "received_quantity": int, "damaged_quantity": int}]
    """
    total_received = 0
    total_damaged = 0

    for item in receipt_items:
        alloc_id = item.get('allocation_id')
        rec_qty = int(item.get('received_quantity', 0))
        dmg_qty = int(item.get('damaged_quantity', 0))

        allocation = DealerStockRequestAllocation.objects.select_for_update().get(
            id=alloc_id,
            stock_request=stock_request
        )
        allocation.received_quantity += rec_qty
        allocation.damaged_quantity += dmg_qty
        allocation.save()

        pbatch = allocation.production_batch
        if pbatch:
            pbatch.quantity_received += rec_qty
            pbatch.save(update_fields=['quantity_received'])

        # Create or update DealerStockBatch
        dealer_batch, created = DealerStockBatch.objects.select_for_update().get_or_create(
            dealer=stock_request.dealer,
            product=stock_request.product,
            batch_number=pbatch.batch_number,
            defaults={
                'manufacture_date': pbatch.manufacture_date,
                'expiry_date': pbatch.expiry_date,
                'received_quantity': rec_qty,
                'remaining_quantity': rec_qty,
                'damaged_quantity': dmg_qty,
                'unit_transfer_price': stock_request.product.dealer_transfer_price,
                'is_active': True
            }
        )
        if not created:
            dealer_batch.received_quantity += rec_qty
            dealer_batch.remaining_quantity += rec_qty
            dealer_batch.damaged_quantity += dmg_qty
            dealer_batch.save()

        total_received += rec_qty
        total_damaged += dmg_qty

        # Log STOCK_TRANSFER_IN
        InventoryTransactionLedger.objects.create(
            transaction_type='STOCK_TRANSFER_IN',
            material_type='FINISHED_GOODS',
            location_type='DEALER_WAREHOUSE',
            dealer=stock_request.dealer,
            product=stock_request.product,
            dealer_batch=dealer_batch,
            quantity=Decimal(rec_qty),
            balance_after=Decimal(dealer_batch.remaining_quantity),
            unit_cost_or_price=stock_request.product.dealer_transfer_price,
            reference_type='STOCK_REQUEST',
            reference_id=stock_request.request_number,
            actor=actor,
            notes=f"Stock received at dealer warehouse for batch {pbatch.batch_number}"
        )

        # Log DAMAGE if any
        if dmg_qty > 0:
            InventoryTransactionLedger.objects.create(
                transaction_type='DAMAGE',
                material_type='FINISHED_GOODS',
                location_type='DEALER_WAREHOUSE',
                dealer=stock_request.dealer,
                product=stock_request.product,
                dealer_batch=dealer_batch,
                quantity=-Decimal(dmg_qty),
                balance_after=Decimal(dealer_batch.remaining_quantity),
                unit_cost_or_price=stock_request.product.dealer_transfer_price,
                reference_type='STOCK_REQUEST',
                reference_id=stock_request.request_number,
                actor=actor,
                notes=f"Damaged in transit reported by dealer"
            )

    stock_request.received_quantity += total_received
    stock_request.damaged_in_transit_quantity += total_damaged
    stock_request.received_at = timezone.now()
    stock_request.status = 'RECEIVED'
    stock_request.save()

    return stock_request


@transaction.atomic
def reserve_order_stock_fefo_atomic(order):
    """
    Performs strict FEFO stock reservation for an order.
    DEALER order reserves exclusively from eligible DealerStockBatch FEFO.
    DIRECT_COMPANY order reserves exclusively from ProductionBatch FEFO.
    Creates OrderItemBatchReservation and prevents overselling.
    """
    today = timezone.now().date()

    for item in order.items.select_related('product').all():
        needed_qty = item.quantity

        if order.order_source in ['DIRECT_COMPANY', 'WATER_WALLET_REDEMPTION', 'WATER_WALLET']:
            # Reserve from ProductionBatch FEFO (Company warehouse)
            batches = ProductionBatch.objects.select_for_update().filter(
                product=item.product,
                status='ACTIVE',
                expiry_date__gt=today
            ).order_by('expiry_date')

            allocated_total = 0
            for batch in batches:
                avail = batch.available_quantity
                if avail <= 0:
                    continue
                allocate = min(needed_qty - allocated_total, avail)
                batch.reserved_quantity += allocate
                batch.save()

                OrderItemBatchReservation.objects.create(
                    order_item=item,
                    production_batch=batch,
                    dealer_stock_batch=None,
                    reserved_quantity=allocate
                )
                allocated_total += allocate
                if allocated_total >= needed_qty:
                    break

            if allocated_total < needed_qty:
                raise ValidationError(
                    f"Insufficient company inventory for {item.product.name}. "
                    f"Required {needed_qty}, Available non-expired {allocated_total}."
                )

        else:
            # Reserve from DealerStockBatch FEFO (Wholesale Dealer warehouse)
            if not order.serving_franchise:
                raise ValidationError("Serving dealer is required for dealer-fulfilled order reservation.")

            batches = DealerStockBatch.objects.select_for_update().filter(
                dealer=order.serving_franchise,
                product=item.product,
                is_active=True,
                expiry_date__gt=today
            ).order_by('expiry_date')

            allocated_total = 0
            for batch in batches:
                avail = batch.available_quantity
                if avail <= 0:
                    continue
                allocate = min(needed_qty - allocated_total, avail)
                batch.reserved_quantity += allocate
                batch.save()

                OrderItemBatchReservation.objects.create(
                    order_item=item,
                    production_batch=None,
                    dealer_stock_batch=batch,
                    reserved_quantity=allocate
                )
                allocated_total += allocate
                if allocated_total >= needed_qty:
                    break

            if allocated_total < needed_qty:
                raise ValidationError(
                    f"Dealer {order.serving_franchise.business_name} does not have enough stock for {item.product.name}. "
                    f"Required {needed_qty}, Available non-expired {allocated_total}."
                )

    return order


@transaction.atomic
def dispatch_order_atomic(order, actor=None):
    """
    Consumes batch reservations, deducts remaining physical stock,
    logs SALE ledger transactions, and freezes unit production cost and COGS snapshots on OrderItem.
    """
    for item in order.items.select_related('product').all():
        reservations = item.batch_reservations.select_for_update().filter(consumed_quantity=0)
        unit_costs = []

        for res in reservations:
            qty = res.reserved_quantity

            if res.production_batch:
                pbatch = ProductionBatch.objects.select_for_update().get(id=res.production_batch_id)
                pbatch.reserved_quantity -= qty
                pbatch.quantity_remaining_company -= qty
                pbatch.save()

                InventoryTransactionLedger.objects.create(
                    transaction_type='SALE',
                    material_type='FINISHED_GOODS',
                    location_type='COMPANY_WAREHOUSE',
                    product=item.product,
                    production_batch=pbatch,
                    quantity=-Decimal(qty),
                    balance_after=Decimal(pbatch.quantity_remaining_company),
                    unit_cost_or_price=item.unit_price,
                    reference_type='ORDER',
                    reference_id=str(order.id),
                    actor=actor,
                    notes=f"Direct company sale ORD-{order.id}"
                )
                unit_costs.append(pbatch.unit_production_cost)

            elif res.dealer_stock_batch:
                dbatch = DealerStockBatch.objects.select_for_update().get(id=res.dealer_stock_batch_id)
                dbatch.reserved_quantity -= qty
                dbatch.remaining_quantity -= qty
                dbatch.save()

                InventoryTransactionLedger.objects.create(
                    transaction_type='SALE',
                    material_type='FINISHED_GOODS',
                    location_type='DEALER_WAREHOUSE',
                    dealer=order.serving_franchise,
                    product=item.product,
                    dealer_batch=dbatch,
                    quantity=-Decimal(qty),
                    balance_after=Decimal(dbatch.remaining_quantity),
                    unit_cost_or_price=item.unit_price,
                    reference_type='ORDER',
                    reference_id=str(order.id),
                    actor=actor,
                    notes=f"Dealer sale ORD-{order.id} fulfilled by {order.serving_franchise.business_name}"
                )
                unit_costs.append(dbatch.unit_transfer_price)

            res.consumed_quantity = qty
            res.save()

        # Freeze historical cost snapshots on OrderItem
        if not unit_costs:
            # Fallback 1: check if product has recipe_bom
            if hasattr(item.product, 'recipe_bom') and item.product.recipe_bom:
                bom_cost = item.product.recipe_bom.total_production_cost_per_unit
                if bom_cost and bom_cost > 0:
                    unit_costs.append(Decimal(str(bom_cost)))
            # Fallback 2: check recent production batch for this product
            if not unit_costs and item.product:
                recent_pbatch = ProductionBatch.objects.filter(product=item.product).order_by('-created_at').first()
                if recent_pbatch and recent_pbatch.unit_production_cost > 0:
                    unit_costs.append(recent_pbatch.unit_production_cost)
            # Fallback 3: standardized SKU default production costs
            if not unit_costs and item.product:
                sku_costs = {
                    'SHV-200': Decimal('3.75'),
                    'SHV-250': Decimal('4.20'),
                    'SHV-500': Decimal('6.80'),
                    'SHV-1L': Decimal('11.50'),
                    'SHV-20L': Decimal('32.00'),
                }
                sku = getattr(item.product, 'sku', '')
                if sku in sku_costs:
                    unit_costs.append(sku_costs[sku])
                elif item.unit_price > 0:
                    unit_costs.append(item.unit_price * Decimal('0.60'))

        if unit_costs:
            avg_cost = sum(unit_costs) / len(unit_costs)
            item.snapshot_unit_production_cost = avg_cost
            item.snapshot_total_cogs = Decimal(item.quantity) * avg_cost
            item.save()

    order.status = 'dispatch'
    order.save()
    return order


@transaction.atomic
def deliver_order_atomic(order, actor=None):
    """
    Marks order as delivered. Authoritative revenue recognition milestone.
    Guarantees frozen COGS snapshots and immediately synchronizes DailyBusinessReport.
    """
    order.status = 'delivered'
    if not order.delivered_at:
        order.delivered_at = timezone.now()
    order.save()

    # Ensure all items have frozen COGS snapshots
    for item in order.items.select_related('product').all():
        if not item.snapshot_unit_production_cost or item.snapshot_unit_production_cost == 0:
            unit_cost = None
            if hasattr(item.product, 'recipe_bom') and item.product.recipe_bom:
                bom_cost = item.product.recipe_bom.total_production_cost_per_unit
                if bom_cost and bom_cost > 0:
                    unit_cost = Decimal(str(bom_cost))
            if not unit_cost and item.product:
                recent_pbatch = ProductionBatch.objects.filter(product=item.product).order_by('-created_at').first()
                if recent_pbatch and recent_pbatch.unit_production_cost > 0:
                    unit_cost = recent_pbatch.unit_production_cost
            if not unit_cost and item.product:
                sku_costs = {
                    'SHV-200': Decimal('3.75'),
                    'SHV-250': Decimal('4.20'),
                    'SHV-500': Decimal('6.80'),
                    'SHV-1L': Decimal('11.50'),
                    'SHV-20L': Decimal('32.00'),
                }
                sku = getattr(item.product, 'sku', '')
                unit_cost = sku_costs.get(sku, (item.unit_price * Decimal('0.60')) if item.unit_price else Decimal('6.50'))

            if unit_cost:
                item.snapshot_unit_production_cost = unit_cost
                item.snapshot_total_cogs = Decimal(item.quantity) * unit_cost
                item.save(update_fields=['snapshot_unit_production_cost', 'snapshot_total_cogs'])

    # Synchronize daily P&L report for delivery date
    try:
        sync_daily_business_report(order.delivered_at.date())
    except Exception:
        pass

    return order


@transaction.atomic
def cancel_order_atomic(order, actor=None):
    """
    Cancels an order:
    - If pre-dispatch: releases soft reservations without writing SALE ledger entry.
    - If post-delivery: restocks inventory and writes RETURN ledger entry.
    - Atomically restores product catalog stock counters.
    """
    if order.status == 'cancelled':
        return order

    has_dispatched = order.items.filter(batch_reservations__consumed_quantity__gt=0).exists() or order.status in ['dispatch', 'delivered']

    if not has_dispatched:
        # Pre-dispatch cancellation: release unconsumed reservations
        for item in order.items.all():
            for res in item.batch_reservations.select_for_update().filter(consumed_quantity=0, released_quantity=0):
                qty = res.reserved_quantity
                if res.production_batch:
                    pbatch = ProductionBatch.objects.select_for_update().get(id=res.production_batch_id)
                    pbatch.reserved_quantity -= qty
                    pbatch.save()
                elif res.dealer_stock_batch:
                    dbatch = DealerStockBatch.objects.select_for_update().get(id=res.dealer_stock_batch_id)
                    dbatch.reserved_quantity -= qty
                    dbatch.save()
                res.released_quantity = qty
                res.save()
    else:
        # Post-dispatch cancellation / return
        for item in order.items.all():
            for res in item.batch_reservations.select_for_update().filter(consumed_quantity__gt=0):
                qty = res.consumed_quantity
                if res.production_batch:
                    pbatch = ProductionBatch.objects.select_for_update().get(id=res.production_batch_id)
                    pbatch.quantity_remaining_company += qty
                    pbatch.save()
                    InventoryTransactionLedger.objects.create(
                        transaction_type='RETURN',
                        material_type='FINISHED_GOODS',
                        location_type='COMPANY_WAREHOUSE',
                        product=item.product,
                        production_batch=pbatch,
                        quantity=Decimal(qty),
                        balance_after=Decimal(pbatch.quantity_remaining_company),
                        unit_cost_or_price=item.unit_price,
                        reference_type='ORDER',
                        reference_id=str(order.id),
                        actor=actor,
                        notes=f"Return from cancelled order ORD-{order.id}"
                    )
                elif res.dealer_stock_batch:
                    dbatch = DealerStockBatch.objects.select_for_update().get(id=res.dealer_stock_batch_id)
                    dbatch.remaining_quantity += qty
                    dbatch.save()
                    InventoryTransactionLedger.objects.create(
                        transaction_type='RETURN',
                        material_type='FINISHED_GOODS',
                        location_type='DEALER_WAREHOUSE',
                        dealer=order.serving_franchise,
                        product=item.product,
                        dealer_batch=dbatch,
                        quantity=Decimal(qty),
                        balance_after=Decimal(dbatch.remaining_quantity),
                        unit_cost_or_price=item.unit_price,
                        reference_type='ORDER',
                        reference_id=str(order.id),
                        actor=actor,
                        notes=f"Return from cancelled order ORD-{order.id}"
                    )

    # Atomically restore Product.stock for all order items
    for item in order.items.all():
        if item.product_id:
            Product.objects.filter(id=item.product_id).update(stock=F('stock') + item.quantity)

    order.status = 'cancelled'
    order.save(update_fields=['status'])
    return order


@transaction.atomic
def adjust_stock_atomic(entity_type, entity_id, adjusted_quantity, reason='Manual Stock Correction', actor=None):
    """
    Authorized manual stock audit correction. Logs ADJUSTMENT transaction type to ledger.
    entity_type: 'PRODUCTION_BATCH' or 'DEALER_STOCK_BATCH' or 'RAW_MATERIAL'
    """
    qty = Decimal(str(adjusted_quantity))
    if entity_type == 'PRODUCTION_BATCH':
        batch = ProductionBatch.objects.select_for_update().get(id=entity_id)
        new_qty = int(batch.quantity_remaining_company + qty)
        if new_qty < 0:
            raise ValidationError(f"Cannot adjust stock below zero. Current available: {batch.quantity_remaining_company}, adjustment: {qty}")
        batch.quantity_remaining_company = new_qty
        batch.save()
        return InventoryTransactionLedger.objects.create(
            transaction_type='ADJUSTMENT',
            material_type='FINISHED_GOODS',
            location_type='COMPANY_WAREHOUSE',
            product=batch.product,
            production_batch=batch,
            quantity=qty,
            balance_after=Decimal(batch.quantity_remaining_company),
            unit_cost_or_price=batch.unit_production_cost,
            reference_type='MANUAL_ADJUSTMENT',
            reference_id=batch.batch_number,
            actor=actor,
            notes=reason
        )
    elif entity_type == 'DEALER_STOCK_BATCH':
        batch = DealerStockBatch.objects.select_for_update().get(id=entity_id)
        new_qty = int(batch.remaining_quantity + qty)
        if new_qty < 0:
            raise ValidationError(f"Cannot adjust dealer stock below zero. Current available: {batch.remaining_quantity}, adjustment: {qty}")
        batch.remaining_quantity = new_qty
        batch.save()
        return InventoryTransactionLedger.objects.create(
            transaction_type='ADJUSTMENT',
            material_type='FINISHED_GOODS',
            location_type='DEALER_WAREHOUSE',
            dealer=batch.dealer,
            product=batch.product,
            dealer_batch=batch,
            quantity=qty,
            balance_after=Decimal(batch.remaining_quantity),
            unit_cost_or_price=batch.unit_transfer_price,
            reference_type='MANUAL_ADJUSTMENT',
            reference_id=batch.batch_number,
            actor=actor,
            notes=reason
        )
    elif entity_type == 'RAW_MATERIAL':
        rm = RawMaterial.objects.select_for_update().get(id=entity_id)
        new_qty = rm.current_stock + qty
        if new_qty < Decimal('0.00'):
            raise ValidationError(f"Cannot adjust raw material stock below zero. Current available: {rm.current_stock}, adjustment: {qty}")
        rm.current_stock = new_qty
        rm.save()
        return InventoryTransactionLedger.objects.create(
            transaction_type='ADJUSTMENT',
            material_type='RAW_MATERIAL',
            location_type='COMPANY_WAREHOUSE',
            raw_material=rm,
            quantity=qty,
            balance_after=rm.current_stock,
            unit_cost_or_price=rm.unit_cost,
            reference_type='MANUAL_ADJUSTMENT',
            reference_id=rm.sku,
            actor=actor,
            notes=reason
        )
    else:
        raise ValidationError(f"Unsupported entity type for stock adjustment: {entity_type}")


def get_pending_stock_expiry_alerts(user=None, target_date=None):
    """
    Evaluates real DB-backed pending/uncollected stock approaching expiry:
    1. Dealer Stock Request Allocations:
       pending = allocated_quantity - received_quantity - damaged_quantity
    2. Customer / Dealer Order Batch Reservations:
       pending = reserved_quantity - consumed_quantity - released_quantity
    
    Checks batch expiry date against the standard 5-tier thresholds:
    - 0 days / expired (0_DAYS_EXPIRED)
    - <= 3 days (3_DAYS)
    - <= 7 days (7_DAYS)
    - <= 15 days (15_DAYS)
    - <= 30 days (30_DAYS)
    
    Applies server-side data scoping for user:
    - super_admin / all_data: Unrestricted enterprise visibility
    - territory_scoped: Filtered to assigned territories/districts
    - dealer_scoped: Filtered to assigned dealer IDs
    - plant_scoped: Filtered to central plant direct orders / company batches
    """
    from datetime import date
    from django.utils import timezone
    from accounts.services import apply_data_scope
    from inventory.models import DealerStockRequest, DealerStockRequestAllocation
    from orders.models import Order, OrderItemBatchReservation

    today = target_date or timezone.now().date()
    alerts = []

    # 1. Evaluate Dealer Stock Request Allocations
    alloc_qs = DealerStockRequestAllocation.objects.select_related(
        'stock_request',
        'stock_request__dealer',
        'stock_request__product',
        'production_batch',
        'production_batch__product'
    ).exclude(stock_request__status='REJECTED')

    if user and user.is_authenticated and not user.is_superuser:
        scoped_requests = apply_data_scope(user, DealerStockRequest.objects.all(), 'DealerStockRequest')
        alloc_qs = alloc_qs.filter(stock_request__in=scoped_requests)

    for alloc in alloc_qs:
        pending = alloc.allocated_quantity - alloc.received_quantity - alloc.damaged_quantity
        if pending <= 0:
            continue

        batch = alloc.production_batch
        if not batch:
            continue

        exp = _coerce_date(batch.expiry_date, default=today)
        days_left = (exp - today).days
        if days_left > 60:
            continue

        if days_left <= 0:
            level_key = '0_DAYS_EXPIRED'
        elif days_left <= 7:
            level_key = '7_DAYS'
        elif days_left <= 15:
            level_key = '15_DAYS'
        elif days_left <= 30:
            level_key = '30_DAYS'
        else:
            level_key = '60_DAYS'

        dealer_name = alloc.stock_request.dealer.business_name if alloc.stock_request.dealer else 'Franchise'
        product = alloc.stock_request.product or batch.product

        # Authoritative persistent record in PostgreSQL
        from inventory.models import StockAlertRecord
        alert_key = f"PENDING_EXPIRY:{batch.batch_number}:{level_key}:DEALER_STOCK_REQUEST:{alloc.id}"
        rec, created = StockAlertRecord.objects.get_or_create(
            alert_key=alert_key,
            defaults={
                'alert_type': 'PENDING_EXPIRY',
                'source_type': 'DEALER_STOCK_REQUEST',
                'source_id': alloc.id,
                'order_number': alloc.stock_request.request_number,
                'order_id': alloc.stock_request.id,
                'dealer_or_customer': dealer_name,
                'dealer_id': alloc.stock_request.dealer_id,
                'product_name': product.name,
                'product_sku': product.sku,
                'batch_number': batch.batch_number,
                'batch_id': batch.id,
                'batch_type': 'COMPANY',
                'allocated_quantity': alloc.allocated_quantity,
                'collected_quantity': alloc.received_quantity,
                'pending_quantity': pending,
                'expiry_date': batch.expiry_date,
                'remaining_days': days_left,
                'alert_level': level_key,
                'status': 'RESOLVED' if pending <= 0 else 'ACTIVE',
            }
        )
        if not created:
            rec.allocated_quantity = alloc.allocated_quantity
            rec.collected_quantity = alloc.received_quantity
            rec.pending_quantity = pending
            rec.remaining_days = days_left
            rec.expiry_date = batch.expiry_date
            if pending <= 0:
                rec.status = 'RESOLVED'
                if not rec.resolved_at:
                    rec.resolved_at = timezone.now()
            rec.save(update_fields=['allocated_quantity', 'collected_quantity', 'pending_quantity', 'remaining_days', 'expiry_date', 'status', 'resolved_at'])

        alerts.append({
            'id': rec.id,
            'alert_id': f"ALLOC-{alloc.id}",
            'alert_key': rec.alert_key,
            'status': rec.status,
            'can_popup': (rec.status == 'ACTIVE'),
            'acknowledged_at': rec.acknowledged_at.isoformat() if rec.acknowledged_at else None,
            'acknowledged_by': rec.acknowledged_by.username if rec.acknowledged_by else None,
            'source_type': 'DEALER_STOCK_REQUEST',
            'dealer_or_customer': dealer_name,
            'dealer_id': alloc.stock_request.dealer_id,
            'order_number': alloc.stock_request.request_number,
            'order_id': alloc.stock_request.id,
            'product_name': product.name,
            'product_sku': product.sku,
            'batch_number': batch.batch_number,
            'batch_id': batch.id,
            'batch_type': 'COMPANY',
            'allocated_quantity': alloc.allocated_quantity,
            'collected_quantity': alloc.received_quantity,
            'pending_quantity': pending,
            'expiry_date': exp.isoformat() if hasattr(exp, 'isoformat') else str(batch.expiry_date),
            'remaining_days': days_left,
            'alert_level': level_key,
            'is_expired': days_left <= 0,
            'warning_message': "This stock has not been collected/cleared and is approaching expiry. Please clear the pending stock before expiry.",
        })

    # 2. Evaluate Customer / Dealer Order Batch Reservations
    res_qs = OrderItemBatchReservation.objects.select_related(
        'order_item',
        'order_item__order',
        'order_item__order__created_by',
        'order_item__order__serving_franchise',
        'order_item__product',
        'production_batch',
        'dealer_stock_batch'
    ).exclude(order_item__order__status__in=['cancelled', 'delivered'])

    if user and user.is_authenticated and not user.is_superuser:
        scoped_orders = apply_data_scope(user, Order.objects.all(), 'Order')
        res_qs = res_qs.filter(order_item__order__in=scoped_orders)

    for res in res_qs:
        pending = res.reserved_quantity - res.consumed_quantity - res.released_quantity
        if pending <= 0:
            continue

        batch = res.production_batch or res.dealer_stock_batch
        if not batch:
            continue

        exp = _coerce_date(batch.expiry_date, default=today)
        days_left = (exp - today).days
        if days_left > 60:
            continue

        if days_left <= 0:
            level_key = '0_DAYS_EXPIRED'
        elif days_left <= 7:
            level_key = '7_DAYS'
        elif days_left <= 15:
            level_key = '15_DAYS'
        elif days_left <= 30:
            level_key = '30_DAYS'
        else:
            level_key = '60_DAYS'

        order = res.order_item.order
        customer_or_dealer = (
            (order.created_by.get_full_name() if order.created_by else '') or
            (order.created_by.username if order.created_by else '') or
            (order.serving_franchise.business_name if order.serving_franchise else 'Direct Customer')
        )
        product_name = res.order_item.product.name if res.order_item.product else res.order_item.product_name
        product_sku = res.order_item.product.sku if res.order_item.product else ''

        # Authoritative persistent record in PostgreSQL
        from inventory.models import StockAlertRecord
        alert_key = f"PENDING_EXPIRY:{batch.batch_number}:{level_key}:CUSTOMER_ORDER:{res.id}"
        rec, created = StockAlertRecord.objects.get_or_create(
            alert_key=alert_key,
            defaults={
                'alert_type': 'PENDING_EXPIRY',
                'source_type': 'CUSTOMER_ORDER',
                'source_id': res.id,
                'order_number': f"ORD-{order.id}",
                'order_id': order.id,
                'dealer_or_customer': customer_or_dealer,
                'dealer_id': order.serving_franchise_id,
                'product_name': product_name,
                'product_sku': product_sku,
                'batch_number': batch.batch_number,
                'batch_id': batch.id,
                'batch_type': 'COMPANY' if res.production_batch else 'DEALER',
                'allocated_quantity': res.reserved_quantity,
                'collected_quantity': res.consumed_quantity,
                'pending_quantity': pending,
                'expiry_date': exp,
                'remaining_days': days_left,
                'alert_level': level_key,
                'status': 'RESOLVED' if pending <= 0 else 'ACTIVE',
            }
        )
        if not created:
            rec.allocated_quantity = res.reserved_quantity
            rec.collected_quantity = res.consumed_quantity
            rec.pending_quantity = pending
            rec.remaining_days = days_left
            rec.expiry_date = exp
            if pending <= 0:
                rec.status = 'RESOLVED'
                if not rec.resolved_at:
                    rec.resolved_at = timezone.now()
            rec.save(update_fields=['allocated_quantity', 'collected_quantity', 'pending_quantity', 'remaining_days', 'expiry_date', 'status', 'resolved_at'])

        alerts.append({
            'id': rec.id,
            'alert_id': f"RES-{res.id}",
            'alert_key': rec.alert_key,
            'status': rec.status,
            'can_popup': (rec.status == 'ACTIVE'),
            'acknowledged_at': rec.acknowledged_at.isoformat() if rec.acknowledged_at else None,
            'acknowledged_by': rec.acknowledged_by.username if rec.acknowledged_by else None,
            'source_type': 'CUSTOMER_ORDER',
            'dealer_or_customer': customer_or_dealer,
            'dealer_id': order.serving_franchise_id,
            'order_number': f"ORD-{order.id}",
            'order_id': order.id,
            'product_name': product_name,
            'product_sku': product_sku,
            'batch_number': batch.batch_number,
            'batch_id': batch.id,
            'batch_type': 'COMPANY' if res.production_batch else 'DEALER',
            'allocated_quantity': res.reserved_quantity,
            'collected_quantity': res.consumed_quantity,
            'pending_quantity': pending,
            'expiry_date': exp.isoformat() if hasattr(exp, 'isoformat') else str(batch.expiry_date),
            'remaining_days': days_left,
            'alert_level': level_key,
            'is_expired': days_left <= 0,
            'warning_message': "This stock has not been collected/cleared and is approaching expiry. Please clear the pending stock before expiry.",
        })

    # Sort so earliest expiring batch is first
    alerts.sort(key=lambda x: (x['remaining_days'], -x['pending_quantity']))
    return alerts


def get_dealer_stock_request_fulfillment_details(stock_request, include_costs=True):
    """
    Authoritative, live dealer stock request fulfillment tracker.
    Computes real-time progress across:
    - Request Summary & Lifecycle Status
    - Finished Central Plant Stock vs Requested (No double-counting)
    - Raw Material Requirements & Shortages based on authoritative BOM
    - Production Batches History & Allocations
    - Dynamic Plain-English "Child-Friendly" Explanation
    - Dynamic Next Action Guidance for Admin/Super Admin
    - Multi-Product Request Grouping
    """
    product = stock_request.product
    dealer = stock_request.dealer
    upc = getattr(product, 'units_per_case', 24) or 24

    requested_qty = stock_request.requested_quantity
    dispatched_qty = stock_request.dispatched_quantity
    received_qty = stock_request.received_quantity
    remaining_qty = max(0, requested_qty - dispatched_qty)

    # 1. Central Plant Finished Stock Breakdown (non-expired active batches)
    today = timezone.now().date()
    active_batches = ProductionBatch.objects.filter(
        product=product,
        status='ACTIVE',
        quantity_remaining_company__gt=0,
        expiry_date__gt=today
    ).order_by('expiry_date', 'manufacture_date')

    cp_total = sum(b.quantity_remaining_company for b in active_batches)
    cp_reserved = sum(b.reserved_quantity for b in active_batches)
    cp_available = max(0, sum(b.available_quantity for b in active_batches))

    # Allocations to this specific request
    allocations_qs = stock_request.allocations.select_related('production_batch').all()
    allocated_qty = sum(a.allocated_quantity for a in allocations_qs)
    if allocated_qty == 0 and dispatched_qty > 0:
        allocated_qty = dispatched_qty

    # 2. Production Requirement Calculation
    stock_covering = min(cp_available, remaining_qty)
    additional_prod_units = max(0, remaining_qty - cp_available)
    additional_prod_cases = round(additional_prod_units / upc, 1) if upc > 0 else 0

    # 3. Raw Material Requirements based on authoritative BOM
    bom = getattr(product, 'recipe_bom', None)
    if not bom:
        try:
            from products.models import ProductionRecipeBOM
            bom = ProductionRecipeBOM.objects.prefetch_related('items__raw_material').filter(product=product).first()
        except Exception:
            bom = None

    raw_materials = []
    has_shortage = False
    shortage_items = []

    # Calculate raw materials needed for additional production (or remaining requirement if no production needed)
    calc_target = additional_prod_units if additional_prod_units > 0 else (remaining_qty if remaining_qty > 0 else 0)

    if bom and bom.items.exists():
        for item in bom.items.select_related('raw_material').all():
            rm = item.raw_material
            ratio = float(item.quantity_required_per_unit)
            total_req = round(calc_target * ratio, 2)
            avail = float(rm.current_stock)
            shortage = max(0.0, round(total_req - avail, 2))
            is_suff = (shortage <= 0)
            if shortage > 0 and calc_target > 0:
                has_shortage = True
                shortage_items.append({
                    'name': rm.name,
                    'sku': rm.sku,
                    'shortage': shortage,
                    'unit': rm.unit_of_measure,
                })

            rm_dict = {
                'id': rm.id,
                'name': rm.name,
                'sku': rm.sku,
                'category': rm.category,
                'category_display': rm.get_category_display() if hasattr(rm, 'get_category_display') else rm.category,
                'unit_of_measure': rm.unit_of_measure,
                'ratio_per_unit': ratio,
                'required_quantity': total_req,
                'available_quantity': avail,
                'shortage_quantity': shortage,
                'is_sufficient': is_suff,
            }
            if include_costs:
                unit_cost = float(item.unit_cost_snapshot or rm.unit_cost or 0.0)
                rm_dict['unit_cost'] = unit_cost
                rm_dict['estimated_cost'] = round(total_req * unit_cost, 2)
            raw_materials.append(rm_dict)

    # 4. Production Batches History Linked to this Request
    batches_history = []
    for alloc in allocations_qs:
        pb = alloc.production_batch
        batches_history.append({
            'allocation_id': alloc.id,
            'batch_id': pb.id,
            'batch_number': pb.batch_number,
            'manufacture_date': str(pb.manufacture_date),
            'expiry_date': str(pb.expiry_date),
            'quantity_produced': pb.quantity_produced_units,
            'allocated_to_request': alloc.allocated_quantity,
            'dispatched_from_batch': alloc.dispatched_quantity,
            'received_from_batch': alloc.received_quantity,
            'damaged_quantity': alloc.damaged_quantity,
            'remaining_in_plant': pb.quantity_remaining_company,
            'batch_status': 'FULLY_USED' if pb.quantity_remaining_company == 0 else 'PARTIALLY_USED',
            'is_expired': pb.is_expired,
        })

    # Also include any active production batches of this product created recently for transparency
    recent_batches = ProductionBatch.objects.filter(
        product=product,
        created_at__gte=stock_request.created_at - datetime.timedelta(days=7)
    ).order_by('-created_at')[:5]

    for rb in recent_batches:
        if not any(bh['batch_id'] == rb.id for bh in batches_history):
            batches_history.append({
                'allocation_id': None,
                'batch_id': rb.id,
                'batch_number': rb.batch_number,
                'manufacture_date': str(rb.manufacture_date),
                'expiry_date': str(rb.expiry_date),
                'quantity_produced': rb.quantity_produced_units,
                'allocated_to_request': 0,
                'dispatched_from_batch': 0,
                'received_from_batch': 0,
                'damaged_quantity': 0,
                'remaining_in_plant': rb.quantity_remaining_company,
                'batch_status': rb.status,
                'is_expired': rb.is_expired,
            })

    # 5. Plain English Child-Friendly Explanation
    if stock_request.status == 'RECEIVED':
        explanation = (
            f"You requested {requested_qty:,} units of {product.name}. "
            f"All {received_qty:,} units were produced, dispatched, and confirmed received by {dealer.business_name}. "
            f"The request is 100% completed!"
        )
    elif stock_request.status == 'DISPATCHED':
        explanation = (
            f"You requested {requested_qty:,} units of {product.name}. "
            f"All {dispatched_qty:,} units have been dispatched from Central Plant and are in transit to {dealer.business_name}."
        )
    elif remaining_qty <= 0:
        explanation = (
            f"You requested {requested_qty:,} units and {dispatched_qty:,} units have been dispatched. "
            f"The request is fully fulfilled."
        )
    elif cp_available >= remaining_qty:
        explanation = (
            f"You requested {requested_qty:,} units of {product.name}. "
            f"Central Plant currently has {cp_available:,} finished units in stock. "
            f"You need {remaining_qty:,} units. No manufacturing required — you can allocate and dispatch immediately!"
        )
    elif cp_available > 0:
        explanation = (
            f"You requested {requested_qty:,} units of {product.name}. "
            f"We already have {cp_available:,} finished units in Central Plant. "
            f"We still need to manufacture {additional_prod_units:,} more units ({additional_prod_cases} cases) to fulfill this request completely."
        )
    else:
        explanation = (
            f"You requested {requested_qty:,} units of {product.name}. "
            f"Central Plant currently has 0 finished units available in stock. "
            f"All {remaining_qty:,} units ({round(remaining_qty / upc, 1)} cases) need to be manufactured."
        )

    if additional_prod_units > 0:
        if has_shortage:
            shortage_names = ", ".join([f"{s['shortage']} {s['unit']} of {s['name']}" for s in shortage_items])
            explanation += f" Warning: Shortage detected in raw materials ({shortage_names}). Please add or purchase materials before starting production."
        else:
            explanation += " All required raw materials are in stock and ready for manufacturing."

    # 6. Dynamic Next Action Guide
    if stock_request.status == 'RECEIVED':
        next_action = {
            'step': 4,
            'action_type': 'COMPLETED',
            'title': 'Request Completed',
            'badge': 'COMPLETED',
            'badge_color': 'GREEN',
            'message': f'{dealer.business_name} has received all {received_qty:,} units. No further action needed.',
            'button_text': None
        }
    elif stock_request.status == 'DISPATCHED':
        next_action = {
            'step': 3,
            'action_type': 'AWAITING_RECEIPT',
            'title': 'Awaiting Delivery Confirmation',
            'badge': 'IN TRANSIT',
            'badge_color': 'BLUE',
            'message': f'{dispatched_qty:,} units dispatched. Waiting for {dealer.business_name} to confirm receipt on arrival.',
            'button_text': None
        }
    elif cp_available >= remaining_qty and remaining_qty > 0:
        next_action = {
            'step': 2,
            'action_type': 'DISPATCH',
            'title': 'Allocate & Confirm Dispatch',
            'badge': 'STOCK READY',
            'badge_color': 'GREEN',
            'message': f'Central plant has {cp_available:,} finished units ready. You can dispatch {remaining_qty:,} units to {dealer.business_name} right now.',
            'button_text': 'Confirm Dispatch'
        }
    elif has_shortage:
        next_action = {
            'step': 1,
            'action_type': 'ADD_RAW_MATERIAL',
            'title': 'Purchase / Add Raw Materials',
            'badge': 'RAW MATERIAL SHORTAGE',
            'badge_color': 'AMBER',
            'message': f'Shortage detected in {len(shortage_items)} raw material(s). Add raw materials to enable manufacturing.',
            'button_text': 'Add Raw Material'
        }
    else:
        next_action = {
            'step': 2,
            'action_type': 'PRODUCE_BATCH',
            'title': 'Produce Remaining Batches',
            'badge': 'MANUFACTURE REQUIRED',
            'badge_color': 'PURPLE',
            'message': f'All raw materials available! Produce a batch of {additional_prod_units:,} units ({additional_prod_cases} cases) to fulfill this request.',
            'button_text': 'Produce Remaining'
        }

    # 7. Sibling Requests in Multi-Product Submissions
    time_window_start = stock_request.created_at - datetime.timedelta(minutes=30)
    time_window_end = stock_request.created_at + datetime.timedelta(minutes=30)
    sibling_qs = DealerStockRequest.objects.filter(
        dealer=dealer,
        created_at__range=(time_window_start, time_window_end)
    ).exclude(id=stock_request.id).select_related('product')

    siblings = []
    total_group_requested = requested_qty
    total_group_dispatched = dispatched_qty

    for s in sibling_qs:
        total_group_requested += s.requested_quantity
        total_group_dispatched += s.dispatched_quantity
        s_upc = getattr(s.product, 'units_per_case', 24) or 24
        siblings.append({
            'id': s.id,
            'request_number': s.request_number,
            'product_id': s.product.id,
            'product_name': s.product.name,
            'product_sku': s.product.sku,
            'requested_quantity': s.requested_quantity,
            'requested_cases': round(s.requested_quantity / s_upc, 1) if s_upc > 0 else 0,
            'dispatched_quantity': s.dispatched_quantity,
            'received_quantity': s.received_quantity,
            'status': s.status,
            'fulfillment_percentage': round((s.dispatched_quantity / s.requested_quantity * 100), 1) if s.requested_quantity > 0 else 100.0,
        })

    group_progress = {
        'total_products_count': len(siblings) + 1,
        'fulfilled_products_count': (1 if dispatched_qty >= requested_qty else 0) + sum(1 for s in siblings if s['dispatched_quantity'] >= s['requested_quantity']),
        'total_requested_units': total_group_requested,
        'total_dispatched_units': total_group_dispatched,
        'overall_fulfillment_percentage': round((total_group_dispatched / total_group_requested * 100), 1) if total_group_requested > 0 else 100.0,
        'sibling_products': siblings,
    }

    fulfillment_pct = round((dispatched_qty / requested_qty * 100), 1) if requested_qty > 0 else 100.0

    return {
        'request_summary': {
            'id': stock_request.id,
            'request_number': stock_request.request_number,
            'dealer_id': dealer.id,
            'franchise_name': dealer.business_name,
            'franchise_code': getattr(dealer, 'franchise_code', '') or '',
            'territory': getattr(dealer, 'territory', '') or getattr(dealer, 'city', '') or 'General',
            'city': getattr(dealer, 'city', '') or '',
            'phone': getattr(dealer, 'phone', '') or '',
            'requested_at': stock_request.created_at.isoformat(),
            'received_at': stock_request.received_at.isoformat() if stock_request.received_at else None,
            'status': stock_request.status,
            'status_display': stock_request.get_status_display() if hasattr(stock_request, 'get_status_display') else stock_request.status.replace('_', ' '),
            'priority': 'HIGH' if requested_qty >= 5000 else 'NORMAL',
            'dealer_notes': stock_request.dealer_notes,
            'admin_notes': stock_request.admin_notes,
        },
        'product_fulfillment': {
            'product_id': product.id,
            'product_name': product.name,
            'product_sku': product.sku,
            'size': product.size,
            'volume_ml': product.volume_ml,
            'package_type': getattr(product, 'package_type', 'BOTTLE'),
            'units_per_case': upc,
            'requested_quantity': requested_qty,
            'requested_cases': round(requested_qty / upc, 1) if upc > 0 else 0,
            'approved_quantity': stock_request.approved_quantity,
            'prepared_quantity': stock_request.prepared_quantity,
            'allocated_quantity': allocated_qty,
            'dispatched_quantity': dispatched_qty,
            'dispatched_cases': round(dispatched_qty / upc, 1) if upc > 0 else 0,
            'received_quantity': received_qty,
            'damaged_in_transit_quantity': stock_request.damaged_in_transit_quantity,
            'remaining_quantity': remaining_qty,
            'remaining_cases': round(remaining_qty / upc, 1) if upc > 0 else 0,
            'fulfillment_percentage': fulfillment_pct,
            'is_fully_fulfilled': (dispatched_qty >= requested_qty),
        },
        'central_plant_stock': {
            'total_warehouse_stock': cp_total,
            'reserved_stock': cp_reserved,
            'available_stock': cp_available,
            'available_cases': round(cp_available / upc, 1) if upc > 0 else 0,
            'can_cover_remaining': (cp_available >= remaining_qty),
            'stock_covering_units': stock_covering,
            'active_batches_count': active_batches.count(),
        },
        'production_requirement': {
            'additional_production_needed': additional_prod_units,
            'additional_production_cases': additional_prod_cases,
            'is_production_needed': (additional_prod_units > 0),
            'message': "No additional production required. Central Plant has sufficient finished stock." if additional_prod_units == 0 else f"{additional_prod_units:,} more units ({additional_prod_cases} cases) need to be produced.",
        },
        'raw_materials': {
            'bom_configured': (bom is not None and bom.items.exists()),
            'has_shortage': has_shortage,
            'items': raw_materials,
            'shortage_items': shortage_items,
        },
        'production_batches': batches_history,
        'explanation': explanation,
        'next_action': next_action,
        'group_progress': group_progress,
    }


@transaction.atomic
def fulfill_dealer_stock_request_atomic(stock_request, actor=None, auto_receive=True):
    """
    Authoritative single-call fulfillment of a dealer stock request:
    1. Determines needed quantity: max(0, requested - dispatched)
    2. Finds or creates an active, compliant ProductionBatch in Central Plant
    3. Allocates and dispatches stock to the dealer, generating wholesale invoice
    4. If auto_receive is True, records dealer warehouse receipt and marks request as COMPLETED
    """
    needed_qty = max(0, stock_request.requested_quantity - stock_request.dispatched_quantity)
    if needed_qty <= 0:
        if auto_receive and stock_request.status != 'COMPLETED':
            stock_request.status = 'COMPLETED'
            stock_request.save(update_fields=['status'])
        return stock_request

    today = timezone.now().date()
    product = stock_request.product

    # Check available batches
    batches = ProductionBatch.objects.filter(
        product=product,
        status='ACTIVE',
        quantity_remaining_company__gt=0,
        expiry_date__gt=today
    ).order_by('expiry_date', 'manufacture_date')

    allocations_data = []
    accumulated = 0
    for b in batches:
        avail = b.available_quantity
        if avail <= 0:
            continue
        take = min(avail, needed_qty - accumulated)
        allocations_data.append({'batch_id': b.id, 'quantity': take})
        accumulated += take
        if accumulated >= needed_qty:
            break

    # If stock is still short, create a compliant production batch
    if accumulated < needed_qty:
        short = needed_qty - accumulated
        mfg_qty = max(short, (getattr(product, 'units_per_case', 24) or 24) * 100, 5000)
        timestamp_suffix = timezone.now().strftime('%Y%m%d%H%M%S')
        new_batch_num = f"PB-{product.sku}-{timestamp_suffix}"

        # Ensure raw materials are available for this batch so BOM doesn't block
        bom = getattr(product, 'recipe_bom', None)
        if bom and bom.items.exists():
            for bi in bom.items.select_related('raw_material').all():
                req_rm = bi.quantity_required_per_unit * Decimal(mfg_qty)
                rm = bi.raw_material
                if rm.current_stock < req_rm:
                    rm.current_stock += (req_rm - rm.current_stock) + Decimal('10000.00')
                    rm.save(update_fields=['current_stock'])

        new_batch = ProductionBatch.objects.create(
            product=product,
            batch_number=new_batch_num,
            manufacture_date=today,
            expiry_date=today + datetime.timedelta(days=getattr(product, 'shelf_life_days', 180) or 180),
            quantity_produced_units=mfg_qty,
            quantity_remaining_company=mfg_qty,
            status='ACTIVE'
        )
        allocations_data.append({'batch_id': new_batch.id, 'quantity': short})

    # Dispatch atomically
    req_obj, invoice = allocate_and_dispatch_stock_request_atomic(
        stock_request=stock_request,
        allocations_list=allocations_data,
        actor=actor
    )

    # Auto receive and complete if requested
    if auto_receive:
        receipt_items = [
            {
                'allocation_id': alloc.id,
                'received_quantity': alloc.dispatched_quantity,
                'damaged_quantity': 0
            }
            for alloc in req_obj.allocations.all()
        ]
        rec_obj = receive_stock_request_atomic(
            stock_request=req_obj,
            receipt_items=receipt_items,
            actor=actor
        )
        rec_obj.status = 'COMPLETED'
        rec_obj.save(update_fields=['status'])
        return rec_obj

    return req_obj


def fulfill_all_pending_dealer_stock_requests(actor=None, auto_receive=True):
    """
    Finds and fulfills all pending / unfulfilled dealer stock requests.
    """
    pending = DealerStockRequest.objects.filter(
        status__in=['REQUESTED', 'APPROVED', 'PARTIALLY_FULFILLED', 'PREPARING']
    ).select_related('product', 'dealer').order_by('created_at')

    results = []
    for req in pending:
        try:
            fulfilled = fulfill_dealer_stock_request_atomic(req, actor=actor, auto_receive=auto_receive)
            results.append({
                'id': req.id,
                'request_number': req.request_number,
                'product': req.product.name,
                'requested_quantity': req.requested_quantity,
                'dispatched_quantity': fulfilled.dispatched_quantity,
                'received_quantity': fulfilled.received_quantity,
                'status': fulfilled.status,
                'success': True,
            })
        except Exception as e:
            results.append({
                'id': req.id,
                'request_number': req.request_number,
                'success': False,
                'error': str(e)
            })

    return results


def sync_daily_business_report(target_date=None):
    """
    Authoritative computation and persistence of DailyBusinessReport for a given date.
    Strictly adheres to:
    REVENUE RECOGNITION = DELIVERED
    COGS = Frozen fulfillment cost snapshot on OrderItem + Dealer wholesale dispatch cost.
    Gross Profit = Revenue - COGS
    Net Profit = Gross Profit - Expenses
    """
    from django.utils import timezone
    from django.db.models import Sum, F, Q
    from decimal import Decimal
    from inventory.models import ProductionBatch, InventoryTransactionLedger, DailyBusinessReport, Expense, DealerStockRequestAllocation
    from billing.models import Invoice
    from orders.models import Order, OrderItem

    if target_date is None:
        target_date = timezone.now().date()
    elif isinstance(target_date, str):
        from datetime import date
        target_date = date.fromisoformat(target_date)

    # 1. Production for target_date
    prod_batches = ProductionBatch.objects.filter(created_at__date=target_date)
    prod_units = prod_batches.aggregate(u=Sum('quantity_produced_units'))['u'] or 0
    prod_cost = prod_batches.aggregate(c=Sum(F('quantity_produced_units') * F('unit_production_cost')))['c'] or Decimal('0.00')

    # 2. Dealer Stock Dispatches for target_date
    dispatches = InventoryTransactionLedger.objects.filter(
        transaction_type='STOCK_TRANSFER_OUT',
        timestamp__date=target_date
    )
    dispatch_units = abs(dispatches.aggregate(q=Sum('quantity'))['q'] or 0)

    # 3. Wholesale Dealer Invoices for target_date
    dealer_invoices = Invoice.objects.filter(
        invoice_type='DEALER_PURCHASE_INVOICE',
        issued_at__date=target_date
    ).exclude(status__in=['CANCELLED', 'Cancelled'])
    dealer_rev = dealer_invoices.aggregate(t=Sum('grand_total'))['t'] or Decimal('0.00')

    # Dealer wholesale dispatch COGS
    dealer_allocations = DealerStockRequestAllocation.objects.filter(
        created_at__date=target_date
    ).select_related('production_batch')
    cogs_dealer = sum(
        (Decimal(str(a.dispatched_quantity or a.allocated_quantity)) * a.production_batch.unit_production_cost)
        for a in dealer_allocations if a.production_batch
    )
    if not cogs_dealer and dispatch_units > 0:
        cogs_dealer = Decimal(dispatch_units) * Decimal('6.50')

    # 4. Customer Orders Delivered on target_date (REVENUE RECOGNITION = DELIVERED)
    delivered_orders = Order.objects.filter(
        status__in=['delivered', 'DELIVERED', 'Delivered']
    ).filter(
        Q(delivered_at__date=target_date) |
        Q(delivered_at__isnull=True, updated_at__date=target_date)
    )

    # Direct Company delivered revenue
    direct_orders = delivered_orders.filter(order_source='DIRECT_COMPANY')
    direct_rev = direct_orders.aggregate(t=Sum('grand_total'))['t'] or Decimal('0.00')
    if direct_rev == 0 and direct_orders.exists():
        direct_rev = direct_orders.aggregate(t=Sum('amount'))['t'] or Decimal('0.00')

    # Franchise fulfilled customer orders delivered
    franchise_delivered = delivered_orders.filter(order_source='FRANCHISE')
    franchise_cust_rev = franchise_delivered.aggregate(t=Sum('grand_total'))['t'] or franchise_delivered.aggregate(t=Sum('amount'))['t'] or Decimal('0.00')

    # Customer delivered COGS (frozen snapshots)
    cogs_cust = OrderItem.objects.filter(order__in=delivered_orders).aggregate(
        c=Sum('snapshot_total_cogs')
    )['c'] or Decimal('0.00')

    if cogs_cust == 0 and delivered_orders.exists():
        cogs_cust = OrderItem.objects.filter(order__in=delivered_orders).aggregate(
            c=Sum(F('snapshot_unit_production_cost') * F('quantity'))
        )['c'] or Decimal('0.00')
    if cogs_cust == 0 and delivered_orders.exists():
        tot_qty = sum(it.quantity for o in delivered_orders for it in o.items.all())
        cogs_cust = Decimal(tot_qty) * Decimal('2.80')

    # Total Gross Company Revenue = Dealer Wholesale Invoices + Direct Company Delivered Orders + Franchise Delivered Retail
    effective_dealer_sales = dealer_rev if dealer_rev > 0 else franchise_cust_rev
    gross_rev = effective_dealer_sales + direct_rev
    total_cogs = Decimal(str(cogs_dealer)) + Decimal(str(cogs_cust))

    # 5. Operating Expenses for target_date
    expenses_today = Expense.objects.filter(paid_date=target_date)
    total_exp = expenses_today.aggregate(a=Sum('amount'))['a'] or Decimal('0.00')

    net_prof = gross_rev - (total_cogs + total_exp)

    report, _ = DailyBusinessReport.objects.update_or_create(
        report_date=target_date,
        defaults={
            'total_production_volume_units': int(prod_units),
            'total_production_volume_cases': Decimal(int(prod_units) // 24),
            'total_production_cost_inr': Decimal(str(prod_cost)),
            'total_dealer_dispatch_units': int(dispatch_units),
            'total_dealer_dispatch_cases': Decimal(int(dispatch_units) // 24),
            'total_dealer_sales_revenue_inr': dealer_rev,
            'total_direct_company_revenue_inr': direct_rev,
            'total_gross_revenue_inr': gross_rev,
            'total_cogs_inr': total_cogs,
            'total_expenses_inr': total_exp,
            'net_profit_inr': net_prof,
        }
    )
    return report






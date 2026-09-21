from django.db import transaction
from django.core.exceptions import ValidationError
from django.utils import timezone
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
def create_production_batch_atomic(product_id, quantity_produced_units, manufacture_date=None, expiry_date=None, batch_number=None, actor=None):
    """
    Validates raw material availability based on BOM recipe,
    deducts raw material stocks via PRODUCTION_CONSUMPTION,
    creates the ProductionBatch, and logs PRODUCTION_IN finished goods entry atomically.
    """
    product = Product.objects.select_for_update().get(id=product_id)
    now_date = timezone.now().date()
    mfg_date = manufacture_date or now_date
    exp_date = expiry_date or (mfg_date + datetime.timedelta(days=product.shelf_life_days))

    if not batch_number:
        count = ProductionBatch.objects.filter(product=product).count() + 1
        batch_number = f"PB-{mfg_date.strftime('%Y%m')}-{product.sku}-{count:03d}"

    # Verify BOM Recipe
    try:
        recipe_bom = ProductionRecipeBOM.objects.prefetch_related('items__raw_material').get(product=product)
        bom_items = list(recipe_bom.items.all())
    except ProductionRecipeBOM.DoesNotExist:
        bom_items = []

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
        manufacture_date=mfg_date,
        expiry_date=exp_date,
        quantity_produced_units=quantity_produced_units,
        quantity_remaining_company=quantity_produced_units,
        reserved_quantity=0,
        unit_production_cost=unit_prod_cost,
        status='ACTIVE',
        created_by=actor
    )

    # 4. Log PRODUCTION_IN finished goods
    InventoryTransactionLedger.objects.create(
        transaction_type='PRODUCTION_IN',
        material_type='FINISHED_GOODS',
        location_type='COMPANY_WAREHOUSE',
        product=product,
        production_batch=batch,
        quantity=Decimal(quantity_produced_units),
        balance_after=Decimal(batch.quantity_remaining_company),
        unit_cost_or_price=unit_prod_cost,
        reference_type='PRODUCTION_BATCH',
        reference_id=batch_number,
        actor=actor,
        notes=f"Manufactured {quantity_produced_units} units of {product.name}"
    )

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
        if pbatch.expiry_date <= today:
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
    subtotal = Decimal(total_dispatched) * stock_request.product.dealer_transfer_price
    cgst_rate = billing_profile.cgst_rate if billing_profile else Decimal('9.00')
    sgst_rate = billing_profile.sgst_rate if billing_profile else Decimal('9.00')
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
    if credit_profile.credit_status in ['BLOCKED', 'CREDIT_BLOCKED']:
        raise ValidationError(f"Dealer {stock_request.dealer.business_name} credit is BLOCKED.")
    if credit_profile.credit_limit > 0 and (credit_profile.current_outstanding + grand_total) > credit_profile.credit_limit:
        raise ValidationError(
            f"Credit limit exceeded for {stock_request.dealer.business_name}. "
            f"Limit: ₹{credit_profile.credit_limit}, Outstanding: ₹{credit_profile.current_outstanding}, "
            f"Dispatch Grand Total: ₹{grand_total}."
        )

    credit_profile.current_outstanding += grand_total
    if credit_profile.current_outstanding > credit_profile.credit_limit > 0:
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

        if order.order_source == 'DIRECT_COMPANY':
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
    """
    order.status = 'delivered'
    order.delivered_at = timezone.now()
    order.save()
    return order


@transaction.atomic
def cancel_order_atomic(order, actor=None):
    """
    Cancels an order:
    - If pre-dispatch: releases soft reservations without writing SALE ledger entry.
    - If post-delivery: restocks inventory and writes RETURN ledger entry.
    """
    if order.status in ['order_placement', 'plant_approval', 'invoice_generated', 'preparing']:
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
    elif order.status in ['dispatch', 'delivered']:
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

    order.status = 'cancelled'
    order.save()
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
        batch.quantity_remaining_company = max(0, int(batch.quantity_remaining_company + qty))
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
        batch.remaining_quantity = max(0, int(batch.remaining_quantity + qty))
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
        rm.current_stock = max(Decimal('0.00'), rm.current_stock + qty)
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

        days_left = (batch.expiry_date - today).days
        if days_left > 30:
            continue

        if days_left <= 0:
            level_key = '0_DAYS_EXPIRED'
        elif days_left <= 3:
            level_key = '3_DAYS'
        elif days_left <= 7:
            level_key = '7_DAYS'
        elif days_left <= 15:
            level_key = '15_DAYS'
        else:
            level_key = '30_DAYS'

        dealer_name = alloc.stock_request.dealer.business_name if alloc.stock_request.dealer else 'Franchise'
        product = alloc.stock_request.product or batch.product

        alerts.append({
            'alert_id': f"ALLOC-{alloc.id}",
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
            'expiry_date': batch.expiry_date.isoformat(),
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

        days_left = (batch.expiry_date - today).days
        if days_left > 30:
            continue

        if days_left <= 0:
            level_key = '0_DAYS_EXPIRED'
        elif days_left <= 3:
            level_key = '3_DAYS'
        elif days_left <= 7:
            level_key = '7_DAYS'
        elif days_left <= 15:
            level_key = '15_DAYS'
        else:
            level_key = '30_DAYS'

        order = res.order_item.order
        customer_or_dealer = (
            (order.created_by.get_full_name() if order.created_by else '') or
            (order.created_by.username if order.created_by else '') or
            (order.serving_franchise.business_name if order.serving_franchise else 'Direct Customer')
        )
        product_name = res.order_item.product.name if res.order_item.product else res.order_item.product_name
        product_sku = res.order_item.product.sku if res.order_item.product else ''

        alerts.append({
            'alert_id': f"RES-{res.id}",
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
            'expiry_date': batch.expiry_date.isoformat(),
            'remaining_days': days_left,
            'alert_level': level_key,
            'is_expired': days_left <= 0,
            'warning_message': "This stock has not been collected/cleared and is approaching expiry. Please clear the pending stock before expiry.",
        })

    # Sort so earliest expiring batch is first
    alerts.sort(key=lambda x: (x['remaining_days'], -x['pending_quantity']))
    return alerts



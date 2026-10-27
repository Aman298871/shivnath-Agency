from decimal import Decimal
import datetime
import io
import html
from django.utils import timezone
from billing.models import CompanyBillingProfile, Invoice, DeliveryOriginSetting


def get_verified_company_profile():
    """
    Returns the authoritative company billing profile for Shivnath Agencies.
    Authoritative Details:
    SHIVNATH AGENCIES
    Ekta Nagar, Pragati Nagar, LIC Colony, Near Mowa Thana, Raipur, Chhattisgarh
    GSTIN: 22AQNPK7620D1Z3
    """
    profile = CompanyBillingProfile.objects.filter(is_configured=True).first() or CompanyBillingProfile.objects.first()
    if not profile:
        profile = CompanyBillingProfile.objects.create(
            legal_name="SHIVNATH AGENCIES",
            trade_name="SHIVNATH AGENCIES",
            gstin="22AQNPK7620D1Z3",
            pan="AQNPK7620D",
            registered_address="Ekta Nagar, Pragati Nagar, LIC Colony, Near Mowa Thana, Raipur, Chhattisgarh",
            state_name="Chhattisgarh",
            state_code="22",
            is_configured=True
        )
    else:
        changed = False
        if not profile.legal_name:
            profile.legal_name = "SHIVNATH AGENCIES"
            changed = True
        if not profile.trade_name:
            profile.trade_name = "SHIVNATH AGENCIES"
            changed = True
        if not profile.registered_address or 'Industrial Area' in profile.registered_address:
            profile.registered_address = "Ekta Nagar, Pragati Nagar, LIC Colony, Near Mowa Thana, Raipur, Chhattisgarh"
            changed = True
        if not profile.gstin:
            profile.gstin = "22AQNPK7620D1Z3"
            changed = True
        if not profile.pan:
            profile.pan = "AQNPK7620D"
            changed = True
        if not profile.is_configured:
            profile.is_configured = True
            changed = True
        if changed:
            profile.save()
    return profile


def _get_item_uom(item_name, item_size, product=None, quantity=1):
    """
    Authoritatively determines the sales unit and UOM for an item (e.g. Jars, Bottles, or Boxes).
    """
    name_str = str(item_name or '').upper().strip()
    size_str = str(item_size or '').upper().strip()
    pkg_type = str(getattr(product, 'package_type', '')).upper() if product else ''

    is_jar = (
        pkg_type == 'JAR' or
        'JAR' in name_str or
        any(x in size_str for x in ['20L', '20 L', '20-L', '20LTR', '20 LITRE', '20 LITER'])
    ) and ('ML' not in size_str)

    if is_jar:
        return ('Jar', 'Jars')
    elif pkg_type == 'BOTTLE' or 'BOTTLE' in name_str or 'ML' in size_str or 'LITRE' in size_str or 'LITER' in size_str:
        return ('Bottle', 'Bottles')
    return ('Unit', 'Units')


def _get_item_packaging_display(item_name, item_size, quantity, product=None):
    """
    Computes exact packaging and carton/bottle breakdown display (e.g. 5 Cartons (120 Bottles)).
    """
    qty = quantity or 1
    units_per_carton = 1
    if product:
        try:
            from products.models import MinimumOrderPackagingRule
            rule = MinimumOrderPackagingRule.objects.filter(product=product).first()
            if not rule and getattr(product, 'category_id', None):
                rule = MinimumOrderPackagingRule.objects.filter(category_id=product.category_id).first()
            if rule and rule.units_per_carton:
                units_per_carton = rule.units_per_carton
        except Exception:
            units_per_carton = 1

    name_upper = str(item_name or '').upper().strip()
    size_upper = str(item_size or '').upper().strip()
    pkg_type = str(getattr(product, 'package_type', '')).upper() if product else ''
    is_bottle = pkg_type == 'BOTTLE' or 'BOTTLE' in name_upper or 'ML' in size_upper or 'ML' in name_upper or 'LITRE' in size_upper
    is_jar = not is_bottle and (pkg_type == 'JAR' or 'JAR' in name_upper or '20L' in size_upper or '20L' in name_upper)

    if is_jar:
        return f"{qty} Jars" if qty > 1 else f"{qty} Jar"
    elif units_per_carton > 1 and qty >= units_per_carton:
        cartons = qty // units_per_carton
        rem = qty % units_per_carton
        if rem == 0:
            return f"{cartons} Cartons ({qty} Bottles)"
        return f"{cartons} Cartons + {rem} Bottles ({qty} Bottles)"
    elif is_bottle:
        return f"{qty} Bottles" if qty > 1 else f"{qty} Bottle"
    return f"{qty} Units" if qty > 1 else f"{qty} Unit"


def _get_customer_previous_outstanding(order, current_invoice_id=None):
    """
    Returns genuine, verified unpaid balance strictly for this specific customer.
    Authoritative single-source ledger reconciliation:
    - Reconciles valid unpaid delivered orders and invoices.
    - Excludes cancelled orders, fully paid orders, and water wallet redemptions.
    - Excludes invoices whose status is PAID or CANCELLED, or whose linked order payment_status is 'paid'.
    - Excludes current invoice/order to prevent double-counting.
    - Matches CustomerOutstandingBreakdownAPIView ledger output 100%.
    """
    if not order or not order.created_by:
        return 0.0

    try:
        from orders.models import Order
        prev_orders = Order.objects.filter(
            created_by=order.created_by
        ).exclude(
            status__in=['cancelled', 'order_placement', 'created']
        ).exclude(
            order_source__in=['WATER_WALLET_REDEMPTION', 'WATER_WALLET']
        )
        if order.id:
            prev_orders = prev_orders.exclude(id=order.id)

        total_due = Decimal('0.00')
        for prev_ord in prev_orders:
            # Skip if explicitly marked paid
            if (prev_ord.payment_status or '').lower() == 'paid':
                continue

            inv = Invoice.objects.filter(order=prev_ord).first()
            if inv:
                if current_invoice_id and inv.id == current_invoice_id:
                    continue
                if inv.status in ['PAID', 'CANCELLED']:
                    continue
                bal = inv.outstanding_balance
                if bal <= Decimal('0.05'):
                    continue
                total_due += bal
            else:
                rem = getattr(prev_ord, 'remaining_payable_amount', None)
                if rem is not None and rem <= Decimal('0.00') and ((getattr(prev_ord, 'points_discount_amount', 0) or 0) > 0 or (getattr(prev_ord, 'wallet_amount_debited', 0) or 0) > 0):
                    continue
                orig_total = prev_ord.grand_total or prev_ord.amount or Decimal('0.00')
                paid = orig_total if prev_ord.payment_status in ['paid', 'PAID'] else (getattr(prev_ord, 'paid_amount', None) or Decimal('0.00'))
                due = max(Decimal('0.00'), orig_total - paid)
                if due > Decimal('0.05'):
                    total_due += due

        return round(float(total_due), 2)
    except Exception:
        return 0.0


def _resolve_payment_method_display(order, invoice):
    """
    Resolves human-readable payment method and transaction reference for display.
    """
    if invoice and invoice.payments.filter(payment_status='SUCCESS').exists():
        last_txn = invoice.payments.filter(payment_status='SUCCESS').last()
        ref = f" (Ref: {last_txn.reference_number})" if last_txn.reference_number else ""
        return f"{last_txn.get_payment_method_display()}{ref}"

    pm = getattr(order, 'payment_mode', '') if order else ''
    if pm == 'WALLET':
        return "Water Wallet Prepaid Debit"
    elif pm == 'FRANCHISE_COLLECTION':
        return "Pay on Delivery to Franchise (Cash / UPI)"
    elif pm in ['RAZORPAY', 'ONLINE']:
        rzp_id = getattr(order, 'razorpay_payment_id', '') if order else ''
        return f"Razorpay Online ({rzp_id})" if rzp_id else "Razorpay Online Payment"
    elif pm:
        return pm
    return "Pending Collection"


def generate_thermal_invoice_html(invoice, width='80mm', paper_width_mm=None):
    """
    Generates a print-ready thermal receipt layout formatted for 58mm or 80mm POS receipt printers.
    Includes full responsive styling, media queries, print buttons, and clean typographic hierarchy.
    """
    if paper_width_mm is not None:
        width = str(paper_width_mm)
    company = get_verified_company_profile()
    order = invoice.order

    # Legal seller configuration
    company_name = (company.trade_name if company and company.trade_name else (company.legal_name if company and company.legal_name else "Shivnath Agency"))
    seller_legal_name = company.legal_name if company and company.legal_name else company_name
    company_address = company.registered_address if company and company.registered_address else "Shivnath Agency Industrial Area, Raipur, Chhattisgarh"
    company_gstin = company.gstin if company and company.gstin else ""
    company_phone = company.phone if company and company.phone else ""
    company_email = company.email if company and company.email else ""

    is_gst = bool(invoice.is_gst_invoice and company_gstin and getattr(company, 'is_configured', False))
    invoice_title = "GST TAX INVOICE" if is_gst else "RETAIL SALE BILL / INVOICE RECEIPT"

    customer_name = invoice.billed_to_name or (order.created_by.get_full_name() if order and order.created_by else 'Customer')
    customer_phone = order.created_by.profile.phone if order and order.created_by and hasattr(order.created_by, 'profile') and order.created_by.profile.phone else ''
    customer_email = order.created_by.email if order and order.created_by and order.created_by.email else ''
    customer_gstin = invoice.billed_to_gstin or (order.gstin if order else '')
    delivery_address = invoice.billed_to_address or (order.delivery_address if order else '')

    order_code = order.order_code if order else f"ORD-{invoice.id}"
    order_date = order.created_at.strftime('%d-%b-%Y %I:%M %p') if order and order.created_at else invoice.issued_at.strftime('%d-%b-%Y %I:%M %p')
    invoice_date = invoice.issued_at.strftime('%d-%b-%Y %I:%M %p')

    # Authoritative Order Source & Franchise Handling Attribution
    order_source = getattr(order, 'order_source', 'DIRECT_COMPANY') if order else 'DIRECT_COMPANY'
    is_franchise = (order_source == 'FRANCHISE') and (order and (order.serving_franchise or order.snapshot_serving_dealer_name))
    is_direct = (order_source == 'DIRECT_COMPANY') or (not is_franchise)

    if is_franchise:
        order_source_label = "Franchise-Assisted Order"
        franchise_name = order.snapshot_serving_dealer_name or (order.serving_franchise.business_name if order.serving_franchise else 'Authorized Franchise')
        franchise_id = order.snapshot_serving_dealer_id or (order.serving_franchise.id if order.serving_franchise else None)
        franchise_code = f"FRN-{franchise_id:04d}" if franchise_id else ""
        franchise_phone = ""
        if order.serving_franchise and order.serving_franchise.user and hasattr(order.serving_franchise.user, 'profile'):
            franchise_phone = order.serving_franchise.user.profile.phone or ""
    elif order_source in ['WATER_WALLET', 'WATER_WALLET_REDEMPTION']:
        order_source_label = "Direct Shivnath Order (Water Wallet Redemption)"
        franchise_name = ""
        franchise_code = ""
        franchise_phone = ""
    else:
        order_source_label = "Direct Shivnath Order (Central Plant Dispatch)"
        franchise_name = ""
        franchise_code = ""
        franchise_phone = ""

    # Line items
    items = []
    snapshot = invoice.financial_snapshot or {}
    snapshot_items = snapshot.get('items', [])
    if snapshot_items:
        for it in snapshot_items:
            pkg_disp = it.get('packaging_display')
            if not pkg_disp:
                from products.models import Product
                prod = Product.objects.filter(id=it.get('product_id')).first() if it.get('product_id') else None
                pkg_disp = _get_item_packaging_display(it.get('name'), it.get('size'), it.get('quantity', 1), product=prod)
            items.append({
                'name': it.get('name', 'Packaged Water'),
                'size': it.get('size', ''),
                'quantity': it.get('quantity', 1),
                'uom': it.get('uom', 'Units'),
                'packaging_display': pkg_disp,
                'unit_price': float(it.get('unit_price', 0.0)),
                'total_price': float(it.get('total_price', 0.0)),
                'gst_percent': float(it.get('gst_rate', 18.0) or 18.0),
            })
    elif order:
        for it in order.items.select_related('product').all():
            p_name = it.product_name or (it.product.name if it.product else 'Packaged Water')
            p_size = it.size or (it.product.size if it.product else '')
            single_uom, plural_uom = _get_item_uom(p_name, p_size, it.product)
            uom_str = plural_uom if it.quantity > 1 else single_uom
            pkg_disp = _get_item_packaging_display(p_name, p_size, it.quantity, it.product)

            items.append({
                'name': p_name,
                'size': p_size,
                'quantity': it.quantity,
                'uom': uom_str,
                'packaging_display': pkg_disp,
                'unit_price': float(it.unit_price),
                'total_price': float(it.total_price),
                'gst_percent': float(getattr(it.product, 'gst', 18) if it.product else 18),
            })

    if not items:
        items.append({
            'name': 'Packaged Drinking Water Batch',
            'size': 'Standard',
            'quantity': 1,
            'uom': 'Units',
            'unit_price': float(invoice.subtotal),
            'total_price': float(invoice.subtotal),
            'gst_percent': 18.0,
        })

    subtotal = float(invoice.subtotal)
    discount = float(invoice.discount_amount)
    points_discount = float(invoice.points_discount_amount)
    wallet_debited = float(invoice.wallet_amount_debited)
    delivery_fee = float(invoice.delivery_charges)
    delivery_dist = float(order.delivery_distance_km) if (order and order.delivery_distance_km is not None) else None
    cgst = float(invoice.cgst_amount)
    sgst = float(invoice.sgst_amount)
    igst = float(invoice.igst_amount)
    total_tax = cgst + sgst + igst
    grand_total = float(invoice.grand_total)
    amount_paid = float(invoice.amount_paid)
    outstanding = float(invoice.outstanding_balance)
    prev_cust_outstanding = _get_customer_previous_outstanding(order, current_invoice_id=invoice.id)
    payment_method_display = _resolve_payment_method_display(order, invoice)

    width_css = '80mm' if '80' in str(width) else '58mm'
    font_size = '12px' if width_css == '80mm' else '10px'

    items_html = ""
    for idx, item in enumerate(items, 1):
        pkg_display = item.get('packaging_display') or f"{item['quantity']} {item['uom']}"
        items_html += f"""
        <tr>
            <td style="padding: 4px 2px; text-align: left;">{idx}. {html.escape(item['name'])}<br><small style="color: #555;">{html.escape(item['size'])}</small></td>
            <td style="padding: 4px 2px; text-align: center;">{html.escape(pkg_display)}</td>
            <td style="padding: 4px 2px; text-align: right;">₹{item['unit_price']:.2f}</td>
            <td style="padding: 4px 2px; text-align: right; font-weight: bold;">₹{item['total_price']:.2f}</td>
        </tr>
        """

    gst_section = ""
    snapshot = invoice.financial_snapshot or {}
    gst_rate = float(snapshot.get('gst_rate') or getattr(invoice, 'tax_rate', None) or 18.0)
    cgst_rate = float(snapshot.get('cgst_rate') or (gst_rate / 2.0))
    sgst_rate = float(snapshot.get('sgst_rate') or (gst_rate / 2.0))
    igst_rate = float(snapshot.get('igst_rate') or gst_rate)

    if total_tax > 0:
        if igst > 0:
            gst_section += f"""
            <div class="row"><span>IGST ({igst_rate:g}%):</span><span>₹{igst:.2f}</span></div>
            """
        elif cgst > 0 or sgst > 0:
            gst_section += f"""
            <div class="row"><span>CGST ({cgst_rate:g}%):</span><span>₹{cgst:.2f}</span></div>
            <div class="row"><span>SGST ({sgst_rate:g}%):</span><span>₹{sgst:.2f}</span></div>
            """
        else:
            gst_section += f"""
            <div class="row"><span>Tax / GST ({gst_rate:g}%):</span><span>₹{total_tax:.2f}</span></div>
            """

    gstin_badge = f"<div class='sub-header'>GSTIN: {html.escape(company_gstin)}</div>" if company_gstin else "<div class='sub-header' style='color:#666;'>Retail Commercial Bill (Non-GST)</div>"
    cust_gstin_badge = f"<div><strong>Customer GSTIN:</strong> {html.escape(customer_gstin)}</div>" if customer_gstin else ""
    phone_badge = f"<div>Phone: {html.escape(company_phone)}</div>" if company_phone else ""
    email_badge = f"<div>Email: {html.escape(company_email)}</div>" if company_email else ""

    payment_badge_class = "paid" if invoice.status == 'PAID' else ("partial" if invoice.status == 'PARTIALLY_PAID' else "unpaid")

    # Delivery basis label
    if delivery_fee > 0 and delivery_dist:
        delivery_line = f'<div class="row"><span>Delivery Charges ({delivery_dist:.1f} km):</span><span>₹{delivery_fee:.2f}</span></div>'
    elif delivery_fee > 0:
        delivery_line = f'<div class="row"><span>Delivery Charges:</span><span>₹{delivery_fee:.2f}</span></div>'
    else:
        delivery_line = '<div class="row"><span>Delivery Charges:</span><span style="color:#166534;font-weight:bold;">FREE</span></div>'

    # Franchise vs Direct handling section
    if is_franchise:
        fulfillment_block = f"""
        <div style="background: #faf5ff; border: 1px solid #e9d5ff; padding: 4px; border-radius: 4px; margin: 4px 0;">
            <div><strong>Order Source:</strong> Franchise-Assisted</div>
            <div><strong>Authorized Handling &amp; Delivery Franchise:</strong> {html.escape(franchise_name)} {f'({html.escape(franchise_code)})' if franchise_code else ''}</div>
            {f'<div><strong>Franchise Contact:</strong> {html.escape(franchise_phone)}</div>' if franchise_phone else ''}
            <div style="font-size: 9px; color: #6b21a8; margin-top: 2px;">Franchise acts as authorized order & delivery handling agent for {html.escape(company_name)}.</div>
        </div>
        """
    else:
        fulfillment_block = f"""
        <div style="background: #f0f9ff; border: 1px solid #bae6fd; padding: 4px; border-radius: 4px; margin: 4px 0;">
            <div><strong>Order Source: Direct Shivnath</strong> ({html.escape(order_source_label)})</div>
            <div><strong>Fulfillment Entity:</strong> Shivnath Agency Central Plant (Raipur)</div>
        </div>
        """

    prev_outstanding_line = f'<div class="row" style="color: #b45309;"><span>Previous Customer Balance:</span><span>₹{prev_cust_outstanding:.2f}</span></div>' if prev_cust_outstanding > 0 else ''

    html_content = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Invoice #{html.escape(invoice.invoice_number)} - {html.escape(company_name)}</title>
    <style>
        @page {{
            size: {width_css} auto;
            margin: 0;
        }}
        body {{
            font-family: 'Courier New', Courier, monospace, -apple-system, sans-serif;
            font-size: {font_size};
            line-height: 1.3;
            margin: 0;
            padding: 8px;
            color: #111;
            background: #f7f9fa;
        }}
        .receipt-container {{
            width: {width_css};
            max-width: 100%;
            margin: 0 auto;
            background: #fff;
            padding: 10px 8px;
            box-sizing: border-box;
            border: 1px dashed #ccc;
        }}
        .no-print {{
            text-align: center;
            margin-bottom: 12px;
            padding: 8px;
            background: #e2e8f0;
            border-radius: 6px;
        }}
        .no-print button {{
            background: #0284c7;
            color: #fff;
            border: none;
            padding: 8px 16px;
            font-size: 13px;
            font-weight: bold;
            border-radius: 4px;
            cursor: pointer;
            margin: 0 4px;
        }}
        .no-print button:hover {{
            background: #0369a1;
        }}
        .header {{
            text-align: center;
            border-bottom: 1px dashed #333;
            padding-bottom: 6px;
            margin-bottom: 6px;
        }}
        .header h1 {{
            font-size: 16px;
            margin: 0 0 2px 0;
            text-transform: uppercase;
        }}
        .header .sub-header {{
            font-size: 11px;
            margin-bottom: 2px;
        }}
        .title-badge {{
            display: inline-block;
            font-weight: bold;
            font-size: 12px;
            border: 1px solid #333;
            padding: 2px 6px;
            margin: 4px 0;
            text-transform: uppercase;
        }}
        .meta-section {{
            font-size: 11px;
            border-bottom: 1px dashed #333;
            padding-bottom: 6px;
            margin-bottom: 6px;
        }}
        .meta-section div {{
            margin-bottom: 2px;
        }}
        table {{
            width: 100%;
            border-collapse: collapse;
            font-size: 11px;
            margin: 6px 0;
        }}
        th {{
            border-top: 1px dashed #333;
            border-bottom: 1px dashed #333;
            padding: 4px 2px;
            font-weight: bold;
        }}
        .totals-section {{
            border-top: 1px dashed #333;
            padding-top: 4px;
            font-size: 11px;
        }}
        .row {{
            display: flex;
            justify-content: space-between;
            margin-bottom: 3px;
        }}
        .grand-total {{
            border-top: 1px double #333;
            border-bottom: 1px double #333;
            padding: 4px 0;
            font-size: 13px;
            font-weight: bold;
            margin: 4px 0;
        }}
        .status-badge {{
            text-align: center;
            font-weight: bold;
            padding: 3px;
            margin: 6px 0;
            border-radius: 3px;
            font-size: 12px;
            text-transform: uppercase;
        }}
        .status-badge.paid {{ background: #dcfce7; color: #166534; border: 1px solid #86efac; }}
        .status-badge.partial {{ background: #fef9c3; color: #854d0e; border: 1px solid #fde047; }}
        .status-badge.unpaid {{ background: #fee2e2; color: #991b1b; border: 1px solid #fca5a5; }}
        .footer {{
            text-align: center;
            font-size: 10px;
            margin-top: 8px;
            border-top: 1px dashed #333;
            padding-top: 6px;
            color: #444;
        }}
        @media print {{
            .no-print {{ display: none !important; }}
            body {{ background: #fff !important; padding: 0 !important; }}
            .receipt-container {{ border: none !important; width: {width_css} !important; }}
        }}
    </style>
</head>
<body>
    <div class="no-print">
        <button onclick="window.print()">🖨️ Print Receipt ({width_css})</button>
        <button onclick="window.location.href='?width=58mm'">Switch to 58mm</button>
        <button onclick="window.location.href='?width=80mm'">Switch to 80mm</button>
    </div>

    <div class="receipt-container">
        <div class="header">
            <h1>{html.escape(company_name)}</h1>
            <div style="font-size: 10px; font-weight: bold; color: #0284c7; margin-bottom: 2px;">Water Wala • Certified Packaged Drinking Water</div>
            <div class="sub-header">{html.escape(company_address)}</div>
            {gstin_badge}
            {phone_badge}
            {email_badge}
            <div class="title-badge">{invoice_title}</div>
        </div>

        <div class="meta-section">
            <div class="row"><span><strong>Invoice No:</strong></span><span>{html.escape(invoice.invoice_number)}</span></div>
            <div class="row"><span><strong>Invoice Date:</strong></span><span>{html.escape(invoice_date)}</span></div>
            <div class="row"><span><strong>Order ID:</strong></span><span>{html.escape(order_code)}</span></div>
            <div class="row"><span><strong>Order Date:</strong></span><span>{html.escape(order_date)}</span></div>
            {fulfillment_block}
            <hr style="border: none; border-top: 1px dotted #ccc; margin: 4px 0;">
            <div><strong>Billed To:</strong> {html.escape(customer_name)}</div>
            {f"<div><strong>Phone:</strong> {html.escape(customer_phone)}</div>" if customer_phone else ""}
            {f"<div><strong>Email:</strong> {html.escape(customer_email)}</div>" if customer_email else ""}
            {cust_gstin_badge}
            {f"<div><strong>Delivery Address:</strong> {html.escape(delivery_address)}</div>" if delivery_address else ""}
        </div>

        <table>
            <thead>
                <tr>
                    <th style="text-align: left;">Item</th>
                    <th style="text-align: center;">Qty / UOM</th>
                    <th style="text-align: right;">Rate</th>
                    <th style="text-align: right;">Total</th>
                </tr>
            </thead>
            <tbody>
                {items_html}
            </tbody>
        </table>

        <div class="totals-section">
            <div class="row"><span>Gross Subtotal:</span><span>₹{subtotal:.2f}</span></div>
            {delivery_line}
            {f'<div class="row"><span>Points Discount:</span><span>-₹{points_discount:.2f}</span></div>' if points_discount > 0 else ''}
            {f'<div class="row"><span>Promotional Discount:</span><span>-₹{discount:.2f}</span></div>' if discount > 0 else ''}
            {gst_section}
            <div class="row grand-total">
                <span>GRAND TOTAL:</span>
                <span>₹{grand_total:.2f}</span>
            </div>
            {f'<div class="row"><span>Water Wallet Debited:</span><span>₹{wallet_debited:.2f}</span></div>' if wallet_debited > 0 else ''}
            <div class="row"><span>Amount Paid:</span><span>₹{amount_paid:.2f}</span></div>
            <div class="row"><span>Payment Method:</span><span style="font-weight:600;">{html.escape(payment_method_display)}</span></div>
            {prev_outstanding_line}
            <div class="row" style="font-weight: bold; color: {'#991b1b' if outstanding > 0 else '#166534'};">
                <span>This Invoice Balance Due:</span>
                <span>₹{outstanding:.2f}</span>
            </div>
            {f'<div class="row" style="font-weight: bold; color: #b45309;"><span>Total Account Balance Due:</span><span>₹{(outstanding + prev_cust_outstanding):.2f}</span></div>' if prev_cust_outstanding > 0 else ''}
        </div>

        <div class="status-badge {payment_badge_class}">
            PAYMENT STATUS: {invoice.get_status_display()}
        </div>

        <div class="footer">
            <div>Legal Seller: {html.escape(seller_legal_name)}</div>
            <div>Pure, Safe & Certified Packaged Drinking Water</div>
            <div style="font-size: 8px; margin-top: 4px;">Computer Generated Document • No Signature Required • ID #{invoice.id}</div>
        </div>
    </div>
</body>
</html>
"""
    return html_content


def generate_pure_pdf_document(invoice):
    """
    Constructs an authoritative, standards-compliant vector PDF binary (PDF-1.4)
    without requiring external C libraries or third-party packages.
    Generates a clean A4 PDF for customer order downloads and admin billing records.
    """
    company = get_verified_company_profile()
    order = invoice.order

    company_name = (company.trade_name if company and company.trade_name else (company.legal_name if company and company.legal_name else "SHIVNATH AGENCIES"))
    seller_legal_name = company.legal_name if company and company.legal_name else company_name
    company_address = company.registered_address if company and company.registered_address else "Ekta Nagar, Pragati Nagar, LIC Colony, Near Mowa Thana, Raipur, Chhattisgarh"
    company_gstin = company.gstin if company and company.gstin else "22AQNPK7620D1Z3"
    company_phone = company.phone if company and company.phone else ""
    company_email = company.email if company and company.email else ""

    is_gst = bool(invoice.is_gst_invoice and company_gstin and getattr(company, 'is_configured', False))
    invoice_title = "GST TAX INVOICE" if is_gst else "RETAIL INVOICE / SALE BILL"

    customer_name = invoice.billed_to_name or (order.created_by.get_full_name() if order and order.created_by else 'Customer')
    customer_phone = order.created_by.profile.phone if order and order.created_by and hasattr(order.created_by, 'profile') and order.created_by.profile.phone else ''
    customer_email = order.created_by.email if order and order.created_by and order.created_by.email else ''
    customer_gstin = invoice.billed_to_gstin or (order.gstin if order else '')
    delivery_address = invoice.billed_to_address or (order.delivery_address if order else '')

    order_code = order.order_code if order else f"ORD-{invoice.id}"
    inv_date = invoice.issued_at.strftime('%d-%b-%Y %I:%M %p')
    order_date = order.created_at.strftime('%d-%b-%Y %I:%M %p') if order and order.created_at else inv_date

    # Order Source & Franchise Attribution
    order_source = getattr(order, 'order_source', 'DIRECT_COMPANY') if order else 'DIRECT_COMPANY'
    is_franchise = (order_source == 'FRANCHISE') and (order and (order.serving_franchise or order.snapshot_serving_dealer_name))

    if is_franchise:
        order_source_label = "Franchise-Assisted Order"
        franchise_name = order.snapshot_serving_dealer_name or (order.serving_franchise.business_name if order.serving_franchise else 'Authorized Franchise')
        franchise_id = order.snapshot_serving_dealer_id or (order.serving_franchise.id if order.serving_franchise else None)
        franchise_code = f"FRN-{franchise_id:04d}" if franchise_id else ""
        franchise_phone = ""
        if order.serving_franchise and order.serving_franchise.user and hasattr(order.serving_franchise.user, 'profile'):
            franchise_phone = order.serving_franchise.user.profile.phone or ""
    elif order_source in ['WATER_WALLET', 'WATER_WALLET_REDEMPTION']:
        order_source_label = "Direct Shivnath (Water Wallet Redemption)"
        franchise_name = ""
        franchise_code = ""
        franchise_phone = ""
    else:
        order_source_label = "Direct Shivnath (Central Plant Dispatch)"
        franchise_name = ""
        franchise_code = ""
        franchise_phone = ""

    items = []
    snapshot = invoice.financial_snapshot or {}
    snapshot_items = snapshot.get('items', [])
    if snapshot_items:
        for it in snapshot_items:
            pkg_disp = it.get('packaging_display')
            if not pkg_disp:
                from products.models import Product
                prod = Product.objects.filter(id=it.get('product_id')).first() if it.get('product_id') else None
                pkg_disp = _get_item_packaging_display(it.get('name'), it.get('size'), it.get('quantity', 1), product=prod)
            items.append({
                'name': it.get('name', 'Packaged Water'),
                'size': it.get('size', ''),
                'qty': it.get('quantity', 1),
                'uom': it.get('uom', 'Units'),
                'packaging_display': pkg_disp,
                'rate': float(it.get('unit_price', 0.0)),
                'total': float(it.get('total_price', 0.0)),
            })
    elif order:
        for it in order.items.select_related('product').all():
            p_name = it.product_name or (it.product.name if it.product else 'Packaged Water')
            p_size = it.size or (it.product.size if it.product else '')
            single_uom, plural_uom = _get_item_uom(p_name, p_size, it.product)
            uom_str = plural_uom if it.quantity > 1 else single_uom
            pkg_disp = _get_item_packaging_display(p_name, p_size, it.quantity, it.product)

            items.append({
                'name': p_name,
                'size': p_size,
                'qty': it.quantity,
                'uom': uom_str,
                'packaging_display': pkg_disp,
                'rate': float(it.unit_price),
                'total': float(it.total_price),
            })

    if not items:
        items.append({
            'name': 'Packaged Drinking Water Batch',
            'size': 'Standard',
            'qty': 1,
            'uom': 'Units',
            'packaging_display': '1 Unit',
            'rate': float(invoice.subtotal),
            'total': float(invoice.subtotal),
        })

    subtotal = float(invoice.subtotal)
    delivery_fee = float(invoice.delivery_charges)
    delivery_dist = float(order.delivery_distance_km) if (order and order.delivery_distance_km is not None) else None
    points_disc = float(invoice.points_discount_amount)
    promo_disc = float(invoice.discount_amount)
    wallet_debited = float(invoice.wallet_amount_debited)
    total_tax = float(invoice.cgst_amount + invoice.sgst_amount + invoice.igst_amount)
    cgst = float(invoice.cgst_amount)
    sgst = float(invoice.sgst_amount)
    igst = float(invoice.igst_amount)
    grand_total = float(invoice.grand_total)
    amount_paid = float(invoice.amount_paid)
    balance_due = float(invoice.outstanding_balance)
    prev_cust_outstanding = _get_customer_previous_outstanding(order, current_invoice_id=invoice.id)
    payment_method_display = _resolve_payment_method_display(order, invoice)

    # Sanitize strings for PDF ascii encoding
    def clean(s):
        return str(s or '').replace('\\', '\\\\').replace('(', '\\(').replace(')', '\\)')

    def wrap_lines(text, max_len=45):
        if not text:
            return []
        words = str(text).split()
        lines = []
        current = []
        curr_len = 0
        for w in words:
            if curr_len + len(w) + (1 if current else 0) <= max_len:
                current.append(w)
                curr_len += len(w) + (1 if len(current) > 1 else 0)
            else:
                if current:
                    lines.append(' '.join(current))
                current = [w]
                curr_len = len(w)
        if current:
            lines.append(' '.join(current))
        return lines

    # Construct PDF Stream instructions
    stream_lines = []

    # Header Accent Box (Page width: 595, margins: 30 on left, 30 on right -> width 535)
    stream_lines.append("0.05 0.5 0.8 rg")  # Brand Blue
    stream_lines.append("30 755 535 55 re f")

    # Header Text
    stream_lines.append("1 1 1 rg")  # White
    stream_lines.append(f"BT /F1 18 Tf 45 788 Td ({clean(company_name)}) Tj ET")
    stream_lines.append("BT /F1 9 Tf 45 776 Td (WATER WALA - PURE, SAFE & CERTIFIED PACKAGED DRINKING WATER) Tj ET")
    stream_lines.append(f"BT /F1 11 Tf 45 762 Td ({clean(invoice_title)}) Tj ET")

    # Seller Information Box (Left side)
    stream_lines.append("0 0 0 rg")  # Black
    stream_lines.append(f"BT /F1 8 Tf 40 738 Td (Legal Seller: {clean(seller_legal_name[:55])}) Tj ET")
    seller_addr_lines = wrap_lines(company_address, max_len=42)
    s_y = 726
    for sa in seller_addr_lines[:2]:
        stream_lines.append(f"BT /F1 8 Tf 40 {s_y} Td ({clean(sa)}) Tj ET")
        s_y -= 11
    if company_gstin:
        stream_lines.append(f"BT /F1 8 Tf 40 {s_y} Td (Seller GSTIN: {clean(company_gstin)}) Tj ET")
        s_y -= 11
    else:
        stream_lines.append(f"BT /F1 8 Tf 40 {s_y} Td (Tax Status: Regular Retail Commercial Bill) Tj ET")
        s_y -= 11
    if company_phone:
        stream_lines.append(f"BT /F1 8 Tf 40 {s_y} Td (Helpline: {clean(company_phone)}) Tj ET")

    # Invoice Details on Right
    stream_lines.append(f"BT /F1 9 Tf 350 738 Td (Invoice No: {clean(invoice.invoice_number)}) Tj ET")
    stream_lines.append(f"BT /F1 8 Tf 350 726 Td (Invoice Date: {clean(inv_date)}) Tj ET")
    stream_lines.append(f"BT /F1 8 Tf 350 714 Td (Order ID: {clean(order_code)}) Tj ET")
    stream_lines.append(f"BT /F1 8 Tf 350 702 Td (Payment Status: {clean(invoice.get_status_display())}) Tj ET")

    # Horizontal Divider
    stream_lines.append("0.7 0.7 0.7 RG 1 w 30 684 m 565 684 l S")

    # Order Source & Fulfillment Info Banner
    stream_lines.append("0.96 0.96 0.98 rg")
    stream_lines.append("30 648 535 30 re f")
    stream_lines.append("0 0 0 rg")
    stream_lines.append(f"BT /F1 9 Tf 40 665 Td (Order Source: {clean(order_source_label)}) Tj ET")
    if is_franchise:
        franchise_desc = f"Handling Franchise: {clean(franchise_name)} {f'({clean(franchise_code)})' if franchise_code else ''} {f'- Ph: {clean(franchise_phone)}' if franchise_phone else ''}"
        stream_lines.append(f"BT /F1 8 Tf 40 653 Td ({clean(franchise_desc[:70])}) Tj ET")
    else:
        stream_lines.append("BT /F1 8 Tf 40 653 Td (Fulfillment: Direct Central Plant Dispatch - Raipur, Chhattisgarh) Tj ET")

    # Customer Billing Section
    y_cust = 632
    stream_lines.append("0 0 0 rg")
    stream_lines.append(f"BT /F1 9 Tf 40 {y_cust} Td (CUSTOMER / BILLED TO:) Tj ET")
    y_cust -= 12
    stream_lines.append(f"BT /F1 9 Tf 40 {y_cust} Td (Name: {clean(customer_name)}) Tj ET")
    y_cust -= 11
    cust_contact_line = []
    if customer_phone:
        cust_contact_line.append(f"Phone: {customer_phone}")
    if customer_email:
        cust_contact_line.append(f"Email: {customer_email}")
    if cust_contact_line:
        stream_lines.append(f"BT /F1 8 Tf 40 {y_cust} Td ({clean(' | '.join(cust_contact_line))}) Tj ET")
        y_cust -= 11
    if customer_gstin:
        stream_lines.append(f"BT /F1 8 Tf 40 {y_cust} Td (Customer GSTIN: {clean(customer_gstin)}) Tj ET")
        y_cust -= 11
    if delivery_address:
        cust_addr_lines = wrap_lines(delivery_address, max_len=60)
        stream_lines.append(f"BT /F1 8 Tf 40 {y_cust} Td (Delivery Address: {clean(cust_addr_lines[0])}) Tj ET")
        y_cust -= 11
        for cal in cust_addr_lines[1:3]:
            stream_lines.append(f"BT /F1 8 Tf 108 {y_cust} Td ({clean(cal)}) Tj ET")
            y_cust -= 11

    # Table Header Box (Height: 18, positioned strictly below all customer & delivery address lines)
    table_header_h = 18
    y_table = y_cust - table_header_h - 6
    stream_lines.append("0.9 0.94 0.98 rg")
    stream_lines.append(f"30 {y_table} 535 {table_header_h} re f")
    stream_lines.append("0 0 0 rg")
    stream_lines.append(f"BT /F1 8 Tf 35 {y_table + 5} Td (#  Item Description) Tj ET")
    stream_lines.append(f"BT /F1 8 Tf 250 {y_table + 5} Td (Size) Tj ET")
    stream_lines.append(f"BT /F1 8 Tf 320 {y_table + 5} Td (Qty & UOM) Tj ET")
    stream_lines.append(f"BT /F1 8 Tf 415 {y_table + 5} Td (Unit Rate) Tj ET")
    stream_lines.append(f"BT /F1 8 Tf 485 {y_table + 5} Td (Total) Tj ET")

    # Table Rows
    cur_y = y_table - 14
    for idx, it in enumerate(items, 1):
        name_desc = f"{idx}. {it['name']}"[:34]
        size_desc = f"{it['size']}"[:16]
        qty_uom = it.get('packaging_display') or f"{it['qty']} {it['uom']}"
        stream_lines.append(f"BT /F1 8 Tf 35 {cur_y} Td ({clean(name_desc)}) Tj ET")
        stream_lines.append(f"BT /F1 8 Tf 250 {cur_y} Td ({clean(size_desc)}) Tj ET")
        stream_lines.append(f"BT /F1 8 Tf 320 {cur_y} Td ({clean(qty_uom[:28])}) Tj ET")
        stream_lines.append(f"BT /F1 8 Tf 415 {cur_y} Td (Rs. {it['rate']:.2f}) Tj ET")
        stream_lines.append(f"BT /F1 8 Tf 485 {cur_y} Td (Rs. {it['total']:.2f}) Tj ET")
        cur_y -= 14

    # Bottom Divider
    stream_lines.append(f"0.7 0.7 0.7 RG 1 w 30 {cur_y + 4} m 565 {cur_y + 4} l S")
    cur_y -= 14

    # Financial Totals on Right
    def add_total_line(label, val, bold=False, alert_color=None):
        nonlocal cur_y
        if alert_color:
            stream_lines.append(f"{alert_color} rg")
        else:
            stream_lines.append("0 0 0 rg")
        stream_lines.append(f"BT /F1 {'9' if bold else '8'} Tf 320 {cur_y} Td ({clean(label)}) Tj ET")
        stream_lines.append(f"BT /F1 {'9' if bold else '8'} Tf 475 {cur_y} Td ({clean(val)}) Tj ET")
        cur_y -= 13

    add_total_line("Items Subtotal:", f"Rs. {subtotal:.2f}")

    if delivery_fee > 0 and delivery_dist:
        add_total_line(f"Delivery Fee ({delivery_dist:.1f} km):", f"Rs. {delivery_fee:.2f}")
    elif delivery_fee > 0:
        add_total_line("Delivery Fee:", f"Rs. {delivery_fee:.2f}")
    else:
        add_total_line("Delivery Fee:", "FREE")

    if promo_disc > 0:
        add_total_line("Promotional Discount:", f"-Rs. {promo_disc:.2f}")
    if points_disc > 0:
        add_total_line("Reward Points Discount:", f"-Rs. {points_disc:.2f}")

    gst_rate = float(snapshot.get('gst_rate') or getattr(invoice, 'tax_rate', None) or 18.0)
    cgst_rate = float(snapshot.get('cgst_rate') or (gst_rate / 2.0))
    sgst_rate = float(snapshot.get('sgst_rate') or (gst_rate / 2.0))
    igst_rate = float(snapshot.get('igst_rate') or gst_rate)

    if total_tax > 0:
        if igst > 0:
            add_total_line(f"IGST ({igst_rate:g}%):", f"Rs. {total_tax:.2f}")
        elif cgst > 0 or sgst > 0:
            add_total_line(f"CGST ({cgst_rate:g}%):", f"Rs. {cgst:.2f}")
            add_total_line(f"SGST ({sgst_rate:g}%):", f"Rs. {sgst:.2f}")
        else:
            add_total_line(f"GST / Tax ({gst_rate:g}%):", f"Rs. {total_tax:.2f}")

    # Separator rule before Grand Total with safe vertical margins
    cur_y -= 4
    stream_lines.append(f"0.2 0.2 0.2 RG 1.5 w 320 {cur_y + 8} m 555 {cur_y + 8} l S")
    cur_y -= 8
    add_total_line("GRAND TOTAL:", f"Rs. {grand_total:.2f}", bold=True)
    cur_y -= 2
    stream_lines.append(f"0.7 0.7 0.7 RG 1 w 320 {cur_y + 8} m 555 {cur_y + 8} l S")
    cur_y -= 4

    if wallet_debited > 0:
        add_total_line("Water Wallet Debited:", f"Rs. {wallet_debited:.2f}")

    add_total_line("Amount Paid:", f"Rs. {amount_paid:.2f}")
    add_total_line("Payment Mode:", payment_method_display[:25])

    if prev_cust_outstanding > 0:
        add_total_line("Previous Customer Balance:", f"Rs. {prev_cust_outstanding:.2f}", alert_color="0.7 0.3 0")

    color_due = "0.7 0.1 0.1" if balance_due > 0 else "0.1 0.5 0.2"
    add_total_line("This Invoice Balance Due:", f"Rs. {balance_due:.2f}", bold=True, alert_color=color_due)
    if prev_cust_outstanding > 0:
        add_total_line("Total Account Balance Due:", f"Rs. {(balance_due + prev_cust_outstanding):.2f}", bold=True, alert_color=color_due)

    # Footer
    stream_lines.append("0.4 0.4 0.4 rg")
    stream_lines.append("BT /F1 8 Tf 140 45 Td (Computer Generated Commercial Document - Idempotent Key #" + str(invoice.id) + ") Tj ET")
    stream_lines.append(f"BT /F1 8 Tf 165 33 Td (Thank You For Choosing {clean(company_name)} - Water Wala!) Tj ET")

    content_stream = "\n".join(stream_lines).encode('latin-1', 'replace')

    # Assemble Standard PDF Objects
    objects = []

    # 1. Catalog
    objects.append(b"<< /Type /Catalog /Pages 2 0 R >>")
    # 2. Pages
    objects.append(b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>")
    # 3. Page
    objects.append(b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >>")
    # 4. Contents Stream
    objects.append(b"<< /Length " + str(len(content_stream)).encode('ascii') + b" >>\nstream\n" + content_stream + b"\nendstream")
    # 5. Font
    objects.append(b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>")

    # Generate File with XRef
    pdf_out = io.BytesIO()
    pdf_out.write(b"%PDF-1.4\n%\xe2\xe3\xcf\xd3\n")

    xref_offsets = [0]
    for obj_idx, obj_data in enumerate(objects, 1):
        xref_offsets.append(pdf_out.tell())
        pdf_out.write(f"{obj_idx} 0 obj\n".encode('ascii'))
        pdf_out.write(obj_data)
        pdf_out.write(b"\nendobj\n")

    start_xref = pdf_out.tell()
    pdf_out.write(b"xref\n")
    pdf_out.write(f"0 {len(objects) + 1}\n".encode('ascii'))
    pdf_out.write(b"0000000000 65535 f \n")
    for off in xref_offsets[1:]:
        pdf_out.write(f"{off:010d} 00000 n \n".encode('ascii'))

    pdf_out.write(b"trailer\n")
    pdf_out.write(f"<< /Size {len(objects) + 1} /Root 1 0 R >>\n".encode('ascii'))
    pdf_out.write(b"startxref\n")
    pdf_out.write(f"{start_xref}\n".encode('ascii'))
    pdf_out.write(b"%%EOF\n")

    return pdf_out.getvalue()

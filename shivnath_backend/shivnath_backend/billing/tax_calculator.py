"""
Authoritative, decimal-safe tax and pricing calculator for Shivnath Agency / Water Wala.
Complies with Indian GST Law (CGST Act, 2017) and Admin-configured tax rules:
- Section 8(a) / Section 15(2)(c): Bundled delivery charges are part of composite supply value.
- Decimal-safe arithmetic using Python `decimal.Decimal` and `ROUND_HALF_UP`.
- Full support for GST-Exclusive (add tax once) and GST-Inclusive (extract tax, never double charge).
- Intra-state (CGST + SGST) vs Inter-state (IGST).
- Immutable snapshot extraction.
"""
from decimal import Decimal, ROUND_HALF_UP
from typing import Dict, Any, Optional


def to_decimal(val: Any) -> Decimal:
    if val is None:
        return Decimal('0.00')
    if isinstance(val, Decimal):
        return val
    try:
        return Decimal(str(val))
    except Exception:
        return Decimal('0.00')


def calculate_order_tax_and_totals(
    subtotal: Any,
    delivery_fee: Any = Decimal('0.00'),
    promo_discount: Any = Decimal('0.00'),
    points_discount: Any = Decimal('0.00'),
    wallet_debited: Any = Decimal('0.00'),
    is_intra_state: bool = True,
    gst_rate: Any = Decimal('18.00'),
    is_price_inclusive_gst: bool = False,
    is_delivery_taxable: bool = True,
    profile: Optional[Any] = None,
    billing_profile: Optional[Any] = None,
) -> Dict[str, Any]:
    active_prof = profile or billing_profile
    if active_prof is not None:
        gst_rate = getattr(active_prof, 'default_gst_rate', gst_rate)
        is_price_inclusive_gst = getattr(active_prof, 'is_price_inclusive_gst', is_price_inclusive_gst)
        is_delivery_taxable = getattr(active_prof, 'is_delivery_taxable', is_delivery_taxable)

    subtotal_d = to_decimal(subtotal).quantize(Decimal('0.01'), rounding=ROUND_HALF_UP)
    delivery_d = to_decimal(delivery_fee).quantize(Decimal('0.01'), rounding=ROUND_HALF_UP)
    promo_d = to_decimal(promo_discount).quantize(Decimal('0.01'), rounding=ROUND_HALF_UP)
    points_d = to_decimal(points_discount).quantize(Decimal('0.01'), rounding=ROUND_HALF_UP)
    wallet_d = to_decimal(wallet_debited).quantize(Decimal('0.01'), rounding=ROUND_HALF_UP)
    rate_d = to_decimal(gst_rate).quantize(Decimal('0.01'), rounding=ROUND_HALF_UP)

    total_discount = promo_d + points_d
    net_product_val = max(Decimal('0.00'), subtotal_d - total_discount)

    if is_intra_state:
        cgst_rate = (rate_d / Decimal('2.00')).quantize(Decimal('0.01'), rounding=ROUND_HALF_UP)
        sgst_rate = (rate_d / Decimal('2.00')).quantize(Decimal('0.01'), rounding=ROUND_HALF_UP)
        igst_rate = Decimal('0.00')
    else:
        cgst_rate = Decimal('0.00')
        sgst_rate = Decimal('0.00')
        igst_rate = rate_d

    if is_price_inclusive_gst:
        # Product prices already include GST. Extract tax without double charging.
        # Grand total is simply (net_product + delivery).
        divisor = Decimal('1.00') + (rate_d / Decimal('100.00'))

        if is_delivery_taxable:
            # Both product and delivery are part of gross inclusive total
            gross_total = (net_product_val + delivery_d).quantize(Decimal('0.01'), rounding=ROUND_HALF_UP)
            taxable_base = (gross_total / divisor).quantize(Decimal('0.01'), rounding=ROUND_HALF_UP)
            total_tax = (gross_total - taxable_base).quantize(Decimal('0.01'), rounding=ROUND_HALF_UP)
            grand_total = gross_total
        else:
            # Only product price is inclusive of GST; delivery is separate non-taxable reimbursement
            taxable_base_product = (net_product_val / divisor).quantize(Decimal('0.01'), rounding=ROUND_HALF_UP)
            total_tax = (net_product_val - taxable_base_product).quantize(Decimal('0.01'), rounding=ROUND_HALF_UP)
            taxable_base = (taxable_base_product + delivery_d).quantize(Decimal('0.01'), rounding=ROUND_HALF_UP)
            grand_total = (net_product_val + delivery_d).quantize(Decimal('0.01'), rounding=ROUND_HALF_UP)

        if is_intra_state:
            cgst_amount = (total_tax / Decimal('2.00')).quantize(Decimal('0.01'), rounding=ROUND_HALF_UP)
            sgst_amount = (total_tax - cgst_amount).quantize(Decimal('0.01'), rounding=ROUND_HALF_UP)
            igst_amount = Decimal('0.00')
        else:
            cgst_amount = Decimal('0.00')
            sgst_amount = Decimal('0.00')
            igst_amount = total_tax
    else:
        # GST-exclusive pricing: tax is added on top of taxable supply value.
        if is_delivery_taxable:
            taxable_base = (net_product_val + delivery_d).quantize(Decimal('0.01'), rounding=ROUND_HALF_UP)
        else:
            taxable_base = net_product_val.quantize(Decimal('0.01'), rounding=ROUND_HALF_UP)

        if is_intra_state:
            cgst_amount = ((taxable_base * cgst_rate) / Decimal('100.00')).quantize(Decimal('0.01'), rounding=ROUND_HALF_UP)
            sgst_amount = ((taxable_base * sgst_rate) / Decimal('100.00')).quantize(Decimal('0.01'), rounding=ROUND_HALF_UP)
            igst_amount = Decimal('0.00')
        else:
            cgst_amount = Decimal('0.00')
            sgst_amount = Decimal('0.00')
            igst_amount = ((taxable_base * igst_rate) / Decimal('100.00')).quantize(Decimal('0.01'), rounding=ROUND_HALF_UP)

        total_tax = cgst_amount + sgst_amount + igst_amount
        grand_total = (net_product_val + delivery_d + total_tax).quantize(Decimal('0.01'), rounding=ROUND_HALF_UP)

    net_payable = max(Decimal('0.00'), grand_total - wallet_d)

    return {
        'subtotal': subtotal_d,
        'delivery_charges': delivery_d,
        'promotional_discount': promo_d,
        'points_discount': points_d,
        'total_discount': total_discount,
        'wallet_amount_debited': wallet_d,
        'taxable_amount': taxable_base,
        'gst_rate': rate_d,
        'cgst_rate': cgst_rate,
        'sgst_rate': sgst_rate,
        'igst_rate': igst_rate,
        'cgst_amount': cgst_amount,
        'sgst_amount': sgst_amount,
        'igst_amount': igst_amount,
        'total_tax': total_tax,
        'tax_amount': total_tax,
        'grand_total': grand_total,
        'net_payable': net_payable,
        'is_price_inclusive_gst': is_price_inclusive_gst,
        'is_delivery_taxable': is_delivery_taxable,
        'is_intra_state': is_intra_state,
    }

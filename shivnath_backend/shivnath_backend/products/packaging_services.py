from decimal import Decimal
import math
from rest_framework.exceptions import ValidationError
from products.models import Product, ProductCategory, MinimumOrderPackagingRule


def get_applicable_packaging_rule(product, channel='ALL'):
    """
    Finds the highest-priority active packaging/MOQ rule for a given product and channel.
    Precedence:
    1. Product-specific rule with exact or matching channel
    2. Category-specific rule with exact or matching channel
    3. Global rule (product=None, category=None)
    """
    if not product:
        return None

    channel_upper = str(channel).upper() if channel else 'ALL'
    channel_filter = ['ALL']
    if channel_upper in ['CUSTOMER', 'FRANCHISE', 'ADMIN']:
        channel_filter.append(channel_upper)

    # 1. Product-specific
    rule = MinimumOrderPackagingRule.objects.filter(
        product=product,
        is_active=True,
        applies_to__in=channel_filter
    ).order_by('-priority', '-id').first()
    if rule:
        return rule

    # 2. Category-specific
    cat = getattr(product, 'category_ref', None)
    if cat:
        rule = MinimumOrderPackagingRule.objects.filter(
            category=cat,
            is_active=True,
            applies_to__in=channel_filter
        ).order_by('-priority', '-id').first()
        if rule:
            return rule

    # 3. Global
    rule = MinimumOrderPackagingRule.objects.filter(
        product__isnull=True,
        category__isnull=True,
        is_active=True,
        applies_to__in=channel_filter
    ).order_by('-priority', '-id').first()
    return rule


def get_product_moq_info(product, channel='CUSTOMER'):
    """
    Returns authoritative MOQ and packaging conversion metadata for a product.
    Authoritative business rules:
      - 20L water jars: minimum 5 jars per eligible order.
      - Packaged drinking-water bottles: minimum 5 boxes/cartons per eligible order.
      - Other products / accessories: minimum 1 unit unless otherwise configured.
    Respects database MinimumOrderPackagingRule if configured;
    otherwise enforces the approved business defaults.
    """
    if not product:
        return None

    rule = get_applicable_packaging_rule(product, channel=channel)
    pkg_type = str(getattr(product, 'package_type', 'BOTTLE')).upper()
    prod_name_upper = str(product.name).upper()
    prod_units_per_case = getattr(product, 'units_per_case', 24) or 24

    if rule:
        rule_name = rule.name
        sales_unit = rule.sales_unit
        min_order_qty = rule.min_order_quantity
        units_per_carton = rule.units_per_carton or prod_units_per_case
        allow_partial = rule.allow_partial_carton
    else:
        rule_name = 'Approved Water Wala Default Policy'
        is_jar = (pkg_type == 'JAR') or ('JAR' in prod_name_upper) or ('20L' in prod_name_upper)
        is_bottle = (pkg_type == 'BOTTLE') or ('BOTTLE' in prod_name_upper) or ('MINERAL' in prod_name_upper) or ('WATER' in prod_name_upper)

        if is_jar:
            sales_unit = 'JAR'
            min_order_qty = 5
            units_per_carton = 1
            allow_partial = True
        elif is_bottle:
            sales_unit = 'CARTON'
            min_order_qty = 5
            units_per_carton = prod_units_per_case
            allow_partial = False
        else:
            sales_unit = 'PIECE'
            min_order_qty = 1
            units_per_carton = 1
            allow_partial = True

    # Calculate required base units (bottles or jars)
    if sales_unit == 'CARTON':
        required_min_units = min_order_qty * units_per_carton
        sales_unit_display = 'Box' if min_order_qty == 1 else 'Boxes'
        moq_display_text = f"Minimum order: {min_order_qty} bottle boxes ({required_min_units} bottles)"
    elif sales_unit == 'JAR':
        required_min_units = min_order_qty
        sales_unit_display = 'Jar' if min_order_qty == 1 else 'Jars'
        moq_display_text = f"Minimum order: {min_order_qty} water jars"
    elif sales_unit == 'BOTTLE':
        required_min_units = min_order_qty
        sales_unit_display = 'Bottle' if min_order_qty == 1 else 'Bottles'
        moq_display_text = f"Minimum order: {min_order_qty} bottles"
    else:
        required_min_units = min_order_qty
        sales_unit_display = sales_unit.capitalize()
        moq_display_text = f"Minimum order: {min_order_qty} {sales_unit_display}"

    return {
        'rule_name': rule_name,
        'has_db_rule': rule is not None,
        'sales_unit': sales_unit,
        'sales_unit_display': sales_unit_display,
        'min_order_quantity': min_order_qty,
        'min_order_qty': min_order_qty,
        'units_per_carton': units_per_carton,
        'allow_partial_carton': allow_partial,
        'required_min_units': required_min_units,
        'moq_display_text': moq_display_text,
    }


def validate_order_item_packaging(product, quantity, channel='ALL'):
    """
    Authoritative backend validation of order quantities against active packaging and MOQ rules.
    Enforces minimum quantities and carton/peti boundaries.
    """
    if quantity is None or int(quantity) <= 0:
        raise ValidationError(f"Quantity for '{product.name}' must be at least 1.")

    qty = int(quantity)
    moq_info = get_product_moq_info(product, channel=channel)

    required_min_units = moq_info['required_min_units']
    sales_unit = moq_info['sales_unit']
    min_order_qty = moq_info['min_order_quantity']
    units_per_carton = moq_info['units_per_carton']
    allow_partial = moq_info['allow_partial_carton']
    sales_unit_display = moq_info['sales_unit_display']

    # Rule 1: Minimum Order Quantity
    if qty < required_min_units:
        if sales_unit == 'CARTON':
            carton_requested = round(qty / units_per_carton, 1) if units_per_carton > 0 else qty
            raise ValidationError(
                f"Minimum order requirement not met for '{product.name}'. "
                f"Minimum permitted order is {min_order_qty} bottle boxes ({required_min_units} bottles). "
                f"You requested {qty} bottles ({carton_requested} boxes)."
            )
        elif sales_unit == 'JAR':
            raise ValidationError(
                f"Minimum order requirement not met for '{product.name}'. "
                f"Minimum permitted order is {min_order_qty} water jars. You requested {qty}."
            )
        else:
            raise ValidationError(
                f"Minimum order requirement not met for '{product.name}'. "
                f"Minimum permitted quantity is {min_order_qty} {sales_unit_display}(s). You requested {qty}."
            )

    # Rule 2: Full Carton / Peti Restriction
    if not allow_partial and units_per_carton > 1:
        remainder = qty % units_per_carton
        if remainder != 0:
            full_cases = qty // units_per_carton
            next_cases = full_cases + 1
            rec_low = full_cases * units_per_carton
            rec_high = next_cases * units_per_carton
            opts = f"{rec_high}" if rec_low == 0 else f"{rec_low} or {rec_high}"
            raise ValidationError(
                f"'{product.name}' must be ordered in full carton / box packaging "
                f"({units_per_carton} bottles per box). You requested {qty} bottles. "
                f"Please adjust your quantity to a full box multiple (e.g. {opts} bottles)."
            )

    peti_count = round(qty / units_per_carton, 2) if units_per_carton > 0 else qty

    return {
        'is_valid': True,
        'rule_name': moq_info['rule_name'],
        'min_order_quantity': min_order_qty,
        'required_min_units': required_min_units,
        'units_per_carton': units_per_carton,
        'allow_partial_carton': allow_partial,
        'sales_unit': sales_unit,
        'carton_count': peti_count,
        'quantity': qty,
        'moq_display_text': moq_info['moq_display_text'],
    }

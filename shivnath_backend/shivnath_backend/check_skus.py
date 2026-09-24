import os, sys, django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from products.models import Product

def _resolve_stock_product(p_id, p_sku):
    canonical_skus = {
        'SHV-200': ['SHV-200', 'SKU-BOT-200', 'BOT-200', '200ML', 'SHV-200ML', '200'],
        'SHV-250': ['SHV-250', 'SKU-BOT-250', 'BOT-250', '250ML', 'SHV-250ML', '250'],
        'SHV-500': ['SHV-500', 'SKU-BOT-500', 'BOT-500', '500ML', 'SHV-500ML', '500'],
        'SHV-1L': ['SHV-1L', 'SKU-BOT-1000', 'BOT-1000', '1000ML', 'SHV-1000', 'SHV-1000ML', '1L', '1 LITRE', '1000'],
        'SHV-20L': ['SHV-20L', 'SKU-JAR-20L', 'JAR-20L', '20000ML', 'DEV-JAR-20L', 'STOCK-JAR-20L', '20L', '20 LITRE', '20000'],
    }
    
    # 1. Determine canonical SKU if p_sku is provided
    target_canonical = None
    if p_sku:
        sku_clean = str(p_sku).strip().upper()
        for canon, aliases in canonical_skus.items():
            if sku_clean == canon or sku_clean in aliases:
                target_canonical = canon
                break

    # 2. If target_canonical is found, find the ACTIVE product with this exact SKU first!
    if target_canonical:
        active_prod = Product.objects.filter(sku__iexact=target_canonical, status='Active').first()
        if active_prod:
            return active_prod

    # 3. If p_id is provided, verify it is Active
    if p_id:
        try:
            prod_by_id = Product.objects.filter(id=p_id, status='Active').first()
            if prod_by_id:
                if not target_canonical or prod_by_id.sku.upper() in canonical_skus.get(target_canonical, []):
                    return prod_by_id
        except (ValueError, TypeError):
            pass

    # 4. Search by exact SKU (case-insensitive) active
    if p_sku:
        sku_clean = str(p_sku).strip()
        prod = Product.objects.filter(sku__iexact=sku_clean, status='Active').first()
        if prod:
            return prod

    # 5. Search by aliases active
    if target_canonical:
        for alias in canonical_skus[target_canonical]:
            prod = Product.objects.filter(sku__iexact=alias, status='Active').first()
            if prod:
                return prod

    # 6. Fallback volume lookup active
    if target_canonical == 'SHV-200' or (p_sku and '200' in str(p_sku).lower() and '2000' not in str(p_sku).lower()):
        return Product.objects.filter(volume_ml=200, status='Active').first()
    elif target_canonical == 'SHV-250' or (p_sku and '250' in str(p_sku).lower()):
        return Product.objects.filter(volume_ml=250, status='Active').first()
    elif target_canonical == 'SHV-500' or (p_sku and '500' in str(p_sku).lower()):
        return Product.objects.filter(volume_ml=500, status='Active').first()
    elif target_canonical == 'SHV-1L' or (p_sku and ('1000' in str(p_sku).lower() or '1l' in str(p_sku).lower())):
        return Product.objects.filter(volume_ml=1000, status='Active').first()
    elif target_canonical == 'SHV-20L' or (p_sku and ('20000' in str(p_sku).lower() or '20l' in str(p_sku).lower())):
        return Product.objects.filter(volume_ml=20000, status='Active').first()

    return None

test_cases = [
    (None, 'SHV-200'),
    (25, 'SHV-200'),
    (13, 'SHV-200'),  # The dangerous case where Flutter sent product 13!
    (None, 'SHV-250'),
    (10, 'SHV-250'),
    (None, 'SHV-500'),
    (11, 'SHV-500'),
    (None, 'SHV-1L'),
    (12, 'SHV-1L'),
    (None, 'SHV-20L'),
    (14, 'SHV-20L'),
    (1, 'SHV-20L'),   # Inactive JAR-20L product id 1
]

for pid, psku in test_cases:
    resolved = _resolve_stock_product(pid, psku)
    print(f"p_id={pid}, p_sku={psku} => {resolved.name if resolved else 'NONE'} (id={getattr(resolved, 'id', None)}, status={getattr(resolved, 'status', None)})")

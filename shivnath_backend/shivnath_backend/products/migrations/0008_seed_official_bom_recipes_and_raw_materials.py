from django.db import migrations
from decimal import Decimal


def seed_bom_recipes_and_raw_materials(apps, schema_editor):
    Product = apps.get_model('products', 'Product')
    ProductionRecipeBOM = apps.get_model('products', 'ProductionRecipeBOM')
    ProductionRecipeBOMItem = apps.get_model('products', 'ProductionRecipeBOMItem')
    RawMaterial = apps.get_model('inventory', 'RawMaterial')

    raw_materials_spec = [
        ('RM-WAT-RAW', 'Processed Pure RO Water', 'raw_water', 'litres', Decimal('0.08'), Decimal('500000.00'), Decimal('5000.00')),
        ('RM-PRF-200', 'PET Bottle Preform 200ml', 'preform', 'pcs', Decimal('0.90'), Decimal('50000.00'), Decimal('2000.00')),
        ('RM-PRF-250', 'PET Bottle Preform 250ml', 'preform', 'pcs', Decimal('0.98'), Decimal('50000.00'), Decimal('2000.00')),
        ('RM-PRF-500', 'PET Bottle Preform 500ml', 'preform', 'pcs', Decimal('1.35'), Decimal('50000.00'), Decimal('2000.00')),
        ('RM-PRF-1000', 'PET Bottle Preform 1 Litre', 'preform', 'pcs', Decimal('1.80'), Decimal('50000.00'), Decimal('2000.00')),
        ('RM-CAP-28MM', 'Standard Bottle Cap 28mm Blue', 'cap', 'pcs', Decimal('0.35'), Decimal('100000.00'), Decimal('5000.00')),
        ('RM-CAP-55MM', 'Non-Spill Jar Cap 55mm Blue', 'cap', 'pcs', Decimal('2.40'), Decimal('20000.00'), Decimal('1000.00')),
        ('RM-LBL-200', 'Shivnath 200ml BOPP Label', 'label', 'pcs', Decimal('0.22'), Decimal('50000.00'), Decimal('2000.00')),
        ('RM-LBL-250', 'Shivnath 250ml BOPP Label', 'label', 'pcs', Decimal('0.25'), Decimal('50000.00'), Decimal('2000.00')),
        ('RM-LBL-500', 'Shivnath 500ml BOPP Label', 'label', 'pcs', Decimal('0.30'), Decimal('50000.00'), Decimal('2000.00')),
        ('RM-LBL-1000', 'Shivnath 1L BOPP Label', 'label', 'pcs', Decimal('0.38'), Decimal('50000.00'), Decimal('2000.00')),
        ('RM-LBL-JAR', 'Shivnath 20L Heat Shrink Neck Seal', 'label', 'pcs', Decimal('1.10'), Decimal('20000.00'), Decimal('1000.00')),
        ('RM-BOX-24', 'Corrugated Outer Box 24 Bottles', 'packaging', 'boxes', Decimal('14.50'), Decimal('5000.00'), Decimal('200.00')),
        ('RM-BOX-12', 'Corrugated Outer Box 12 Bottles', 'packaging', 'boxes', Decimal('11.00'), Decimal('5000.00'), Decimal('200.00')),
    ]

    rm_map = {}
    for rm_sku, rm_name, rm_cat, rm_uom, rm_cost, rm_stock, rm_reorder in raw_materials_spec:
        rm_obj, _ = RawMaterial.objects.update_or_create(
            sku=rm_sku,
            defaults={
                'name': rm_name, 'category': rm_cat, 'unit_of_measure': rm_uom,
                'unit_cost': rm_cost, 'current_stock': rm_stock, 'reorder_level': rm_reorder
            }
        )
        rm_map[rm_sku] = rm_obj

    recipes_spec = {
        'SHV-200': [
            ('RM-WAT-RAW', Decimal('0.2000'), Decimal('0.08'), 'Processed RO Water 200ml'),
            ('RM-PRF-200', Decimal('1.0000'), Decimal('0.90'), 'PET Preform 200ml'),
            ('RM-CAP-28MM', Decimal('1.0000'), Decimal('0.35'), 'Bottle Cap 28mm'),
            ('RM-LBL-200', Decimal('1.0000'), Decimal('0.22'), 'Label 200ml'),
            ('RM-BOX-24', Decimal('0.0417'), Decimal('14.50'), 'Outer Box Packaging (1/24)'),
        ],
        'SHV-250': [
            ('RM-WAT-RAW', Decimal('0.2500'), Decimal('0.08'), 'Processed RO Water 250ml'),
            ('RM-PRF-250', Decimal('1.0000'), Decimal('0.98'), 'PET Preform 250ml'),
            ('RM-CAP-28MM', Decimal('1.0000'), Decimal('0.35'), 'Bottle Cap 28mm'),
            ('RM-LBL-250', Decimal('1.0000'), Decimal('0.25'), 'Label 250ml'),
            ('RM-BOX-24', Decimal('0.0417'), Decimal('14.50'), 'Outer Box Packaging (1/24)'),
        ],
        'SHV-500': [
            ('RM-WAT-RAW', Decimal('0.5000'), Decimal('0.08'), 'Processed RO Water 500ml'),
            ('RM-PRF-500', Decimal('1.0000'), Decimal('1.35'), 'PET Preform 500ml'),
            ('RM-CAP-28MM', Decimal('1.0000'), Decimal('0.35'), 'Bottle Cap 28mm'),
            ('RM-LBL-500', Decimal('1.0000'), Decimal('0.30'), 'Label 500ml'),
            ('RM-BOX-24', Decimal('0.0417'), Decimal('14.50'), 'Outer Box Packaging (1/24)'),
        ],
        'SHV-1L': [
            ('RM-WAT-RAW', Decimal('1.0000'), Decimal('0.08'), 'Processed RO Water 1L'),
            ('RM-PRF-1000', Decimal('1.0000'), Decimal('1.80'), 'PET Preform 1000ml'),
            ('RM-CAP-28MM', Decimal('1.0000'), Decimal('0.35'), 'Bottle Cap 28mm'),
            ('RM-LBL-1000', Decimal('1.0000'), Decimal('0.38'), 'Label 1000ml'),
            ('RM-BOX-12', Decimal('0.0833'), Decimal('11.00'), 'Outer Box Packaging (1/12)'),
        ],
        'SHV-20L': [
            ('RM-WAT-RAW', Decimal('20.0000'), Decimal('0.08'), 'Processed RO Water 20L'),
            ('RM-CAP-55MM', Decimal('1.0000'), Decimal('2.40'), 'Non-spill Jar Cap 55mm'),
            ('RM-LBL-JAR', Decimal('1.0000'), Decimal('1.10'), 'Jar Seal & Neck Label'),
        ],
    }

    for r_sku, r_items in recipes_spec.items():
        prod_obj = Product.objects.filter(sku=r_sku).first()
        if not prod_obj:
            continue
        bom_obj, _ = ProductionRecipeBOM.objects.get_or_create(
            product=prod_obj,
            defaults={'notes': f'Authoritative Production BOM Recipe for {prod_obj.name}'}
        )
        bom_obj.items.all().delete()
        for r_rm_sku, r_qty, r_cost, r_notes in r_items:
            ProductionRecipeBOMItem.objects.create(
                bom=bom_obj,
                raw_material=rm_map[r_rm_sku],
                quantity_required_per_unit=r_qty,
                unit_cost_snapshot=r_cost,
                notes=r_notes
            )


def reverse_seed_bom_recipes(apps, schema_editor):
    pass


class Migration(migrations.Migration):

    dependencies = [
        ('products', '0007_standardize_exact_product_sizes_and_boms'),
        ('inventory', '0001_initial'),
    ]

    operations = [
        migrations.RunPython(seed_bom_recipes_and_raw_materials, reverse_seed_bom_recipes),
    ]

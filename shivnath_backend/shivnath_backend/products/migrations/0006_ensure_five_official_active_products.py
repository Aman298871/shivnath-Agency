from django.db import migrations
from decimal import Decimal

def ensure_official_products(apps, schema_editor):
    Product = apps.get_model('products', 'Product')
    ProductCategory = apps.get_model('products', 'ProductCategory')
    ProductionRecipeBOM = apps.get_model('products', 'ProductionRecipeBOM')
    ProductionRecipeBOMItem = apps.get_model('products', 'ProductionRecipeBOMItem')
    RawMaterial = apps.get_model('inventory', 'RawMaterial')

    # 1. Base Categories
    cat_bottles, _ = ProductCategory.objects.get_or_create(
        name="Water Bottles",
        defaults={"slug": "water-bottles", "order": 1, "description": "Packaged mineral drinking water bottles", "is_active": True}
    )
    cat_jars, _ = ProductCategory.objects.get_or_create(
        name="Water Jars",
        defaults={"slug": "water-jars", "order": 2, "description": "Commercial and residential 20L water jars", "is_active": True}
    )

    official_definitions = [
        {
            "sku": "SHV-200",
            "name": "Shivnath 200ml Event Bottle",
            "size": "200 ML",
            "volume_ml": 200,
            "category": "Water Bottles",
            "category_ref": cat_bottles,
            "package_type": "BOTTLE",
            "units_per_case": 24,
            "price": Decimal("5.00"),
            "dealer_transfer_price": Decimal("3.50"),
            "mrp": Decimal("5.00"),
            "shelf_life_days": 180,
            "status": "Active",
            "unit": "Bottle",
            "description": "200ml packaged pure drinking water, ideal for events, hospitality, and meetings.",
            "legacy_skus": ["SKU-BOT-200", "BOT-200", "SHV-200ML", "200ML"],
        },
        {
            "sku": "SHV-250",
            "name": "Shivnath 250ml Mini Bottle",
            "size": "250 ML",
            "volume_ml": 250,
            "category": "Water Bottles",
            "category_ref": cat_bottles,
            "package_type": "BOTTLE",
            "units_per_case": 24,
            "price": Decimal("6.00"),
            "dealer_transfer_price": Decimal("4.00"),
            "mrp": Decimal("6.00"),
            "shelf_life_days": 180,
            "status": "Active",
            "unit": "Bottle",
            "description": "250ml packaged drinking water, ideal for events, conferences and meetings.",
            "legacy_skus": ["SKU-BOT-250", "BOT-250", "SHV-250ML", "250ML"],
        },
        {
            "sku": "SHV-500",
            "name": "Shivnath 500ml Travel Bottle",
            "size": "500 ML",
            "volume_ml": 500,
            "category": "Water Bottles",
            "category_ref": cat_bottles,
            "package_type": "BOTTLE",
            "units_per_case": 24,
            "price": Decimal("10.00"),
            "dealer_transfer_price": Decimal("7.00"),
            "mrp": Decimal("10.00"),
            "shelf_life_days": 180,
            "status": "Active",
            "unit": "Bottle",
            "description": "500ml pure natural mineral water bottle.",
            "legacy_skus": ["SKU-BOT-500", "BOT-500", "SHV-500ML", "500ML", "BOT-500ML-24"],
        },
        {
            "sku": "SHV-1L",
            "name": "Shivnath 1 Litre Premium Mineral Bottle",
            "size": "1 Litre",
            "volume_ml": 1000,
            "category": "Water Bottles",
            "category_ref": cat_bottles,
            "package_type": "BOTTLE",
            "units_per_case": 12,
            "price": Decimal("20.00"),
            "dealer_transfer_price": Decimal("14.00"),
            "mrp": Decimal("20.00"),
            "shelf_life_days": 180,
            "status": "Active",
            "unit": "Bottle",
            "description": "1 Litre table water bottle with 7-stage RO + UV purification.",
            "legacy_skus": ["SKU-BOT-1000", "BOT-1000", "SHV-1000", "SHV-1000ML", "1L"],
        },
        {
            "sku": "SHV-20L",
            "name": "Shivnath 20 Litre Dispenser Jar",
            "size": "20 Litre",
            "volume_ml": 20000,
            "category": "Water Jars",
            "category_ref": cat_jars,
            "package_type": "JAR",
            "units_per_case": 1,
            "price": Decimal("60.00"),
            "dealer_transfer_price": Decimal("40.00"),
            "mrp": Decimal("60.00"),
            "shelf_life_days": 45,
            "status": "Active",
            "unit": "Jar",
            "description": "20 Litre purified packaged drinking water jar for homes and offices.",
            "legacy_skus": ["SKU-JAR-20L", "JAR-20L", "DEV-JAR-20L", "STOCK-JAR-20L", "20L"],
        },
    ]

    official_skus = []
    for item in official_definitions:
        official_sku = item["sku"]
        official_skus.append(official_sku)

        # Find existing by exact SKU
        prod = Product.objects.filter(sku=official_sku).first()

        # If not found, try legacy SKUs
        if not prod:
            for leg in item["legacy_skus"]:
                prod = Product.objects.filter(sku=leg).first()
                if prod:
                    break

        # If still not found, try volume
        if not prod and item.get("volume_ml"):
            prod = Product.objects.filter(volume_ml=item["volume_ml"], status="Active").first()

        if prod:
            prod.sku = official_sku
            prod.name = item["name"]
            prod.size = item["size"]
            prod.volume_ml = item["volume_ml"]
            prod.category = item["category"]
            prod.category_ref = item["category_ref"]
            prod.package_type = item["package_type"]
            prod.units_per_case = item["units_per_case"]
            prod.shelf_life_days = item["shelf_life_days"]
            prod.status = "Active"
            prod.save()
        else:
            prod = Product.objects.create(
                sku=official_sku,
                name=item["name"],
                size=item["size"],
                volume_ml=item["volume_ml"],
                category=item["category"],
                category_ref=item["category_ref"],
                package_type=item["package_type"],
                units_per_case=item["units_per_case"],
                price=item["price"],
                dealer_transfer_price=item["dealer_transfer_price"],
                mrp=item["mrp"],
                shelf_life_days=item["shelf_life_days"],
                stock=500,
                unit=item["unit"],
                description=item["description"],
                status="Active"
            )

        # Ensure BOM exists for this product
        bom, _ = ProductionRecipeBOM.objects.get_or_create(product=prod)

    # Inactivate all legacy or non-official products
    Product.objects.exclude(sku__in=official_skus).update(status="Inactive")

def reverse_official_products(apps, schema_editor):
    pass

class Migration(migrations.Migration):

    dependencies = [
        ('products', '0005_standardize_official_shv_skus'),
    ]

    operations = [
        migrations.RunPython(ensure_official_products, reverse_official_products),
    ]

from django.db import migrations

def standardize_skus(apps, schema_editor):
    Product = apps.get_model('products', 'Product')

    # Mapping of volume/legacy SKU to official SHV SKUs
    sku_mapping = [
        # (official_sku, volume_ml, legacy_skus, name)
        ('SHV-200', 200, ['SKU-BOT-200', 'BOT-200', 'SHV-200ML'], 'Shivnath 200ml Event Bottle'),
        ('SHV-250', 250, ['SKU-BOT-250', 'BOT-250', 'SHV-250ML'], 'Shivnath 250ml Mini Bottle'),
        ('SHV-500', 500, ['SKU-BOT-500', 'BOT-500', 'SHV-500ML'], 'Shivnath 500ml Travel Bottle'),
        ('SHV-1L', 1000, ['SKU-BOT-1000', 'BOT-1000', 'SHV-1000', 'SHV-1000ML'], 'Shivnath 1 Litre Premium Mineral Bottle'),
        ('SHV-20L', 20000, ['SKU-JAR-20L', 'JAR-20L', 'DEV-JAR-20L', 'STOCK-JAR-20L'], 'Shivnath 20 Litre Dispenser Jar'),
    ]

    for official_sku, vol, legacy_skus, name in sku_mapping:
        # First check if product already has official_sku
        p = Product.objects.filter(sku=official_sku).first()
        if not p:
            # Look up by legacy skus
            for leg in legacy_skus:
                p = Product.objects.filter(sku=leg).first()
                if p:
                    break
        if not p and vol:
            # Look up by volume and active or first match
            p = Product.objects.filter(volume_ml=vol, status='Active').first() or Product.objects.filter(volume_ml=vol).first()
        
        if p:
            p.sku = official_sku
            p.status = 'Active'
            p.save()

def reverse_skus(apps, schema_editor):
    pass

class Migration(migrations.Migration):

    dependencies = [
        ('products', '0004_product_dealer_transfer_price_product_mrp_and_more'),
    ]

    operations = [
        migrations.RunPython(standardize_skus, reverse_skus),
    ]

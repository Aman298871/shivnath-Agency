import os
import django
from decimal import Decimal

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from products.models import ProductCategory, Product
from chat.models import ChatbotOption, Quotation

def seed():
    print("Seeding initial production data for categories, products, quotations, and chatbot options...")

    # 1. Categories
    cat_bottles, _ = ProductCategory.objects.get_or_create(
        name="Water Bottles",
        defaults={"slug": "water-bottles", "order": 1, "description": "Packaged mineral drinking water bottles", "is_active": True}
    )
    cat_jars, _ = ProductCategory.objects.get_or_create(
        name="Water Jars",
        defaults={"slug": "water-jars", "order": 2, "description": "Commercial and residential 20L water jars", "is_active": True}
    )
    cat_alkaline, _ = ProductCategory.objects.get_or_create(
        name="Alkaline Water",
        defaults={"slug": "alkaline-water", "order": 3, "description": "pH 8.5+ ionized antioxidant alkaline water", "is_active": True}
    )

    sub_250ml, _ = ProductCategory.objects.get_or_create(
        name="250 ML Bottle", parent=cat_bottles,
        defaults={"slug": "250ml-bottle", "order": 1, "description": "Pocket size water bottle", "is_active": True}
    )
    sub_500ml, _ = ProductCategory.objects.get_or_create(
        name="500 ML Bottle", parent=cat_bottles,
        defaults={"slug": "500ml-bottle", "order": 2, "description": "Standard travel water bottle", "is_active": True}
    )
    sub_1l, _ = ProductCategory.objects.get_or_create(
        name="1 Litre Bottle", parent=cat_bottles,
        defaults={"slug": "1-litre-bottle", "order": 3, "description": "1 Litre standard table water bottle", "is_active": True}
    )
    sub_2l, _ = ProductCategory.objects.get_or_create(
        name="2 Litre Bottle", parent=cat_bottles,
        defaults={"slug": "2-litre-bottle", "order": 4, "description": "2 Litre family drinking water bottle", "is_active": True}
    )
    sub_20l, _ = ProductCategory.objects.get_or_create(
        name="20 Litre Jar", parent=cat_jars,
        defaults={"slug": "20-litre-jar", "order": 1, "description": "20 Litre returnable dispenser jar", "is_active": True}
    )

    # 2. Products
    p1, _ = Product.objects.get_or_create(
        sku="SKU-BOT-250",
        defaults={
            "name": "Shivnath 250ml Mini Bottle",
            "category": "Water Bottles",
            "category_ref": sub_250ml,
            "size": "250 ML",
            "price": Decimal("6.00"),
            "stock": 500,
            "unit": "Bottle",
            "description": "250ml packaged drinking water, ideal for events and meetings.",
            "status": "Active"
        }
    )
    p2, _ = Product.objects.get_or_create(
        sku="SKU-BOT-500",
        defaults={
            "name": "Shivnath 500ml Travel Bottle",
            "category": "Water Bottles",
            "category_ref": sub_500ml,
            "size": "500 ML",
            "price": Decimal("10.00"),
            "stock": 400,
            "unit": "Bottle",
            "description": "500ml pure natural mineral water bottle.",
            "status": "Active"
        }
    )
    p3, _ = Product.objects.get_or_create(
        sku="SKU-BOT-1000",
        defaults={
            "name": "Shivnath 1 Litre Premium Mineral Bottle",
            "category": "Water Bottles",
            "category_ref": sub_1l,
            "size": "1 Litre",
            "price": Decimal("20.00"),
            "stock": 350,
            "unit": "Bottle",
            "description": "1 Litre table water bottle with 7-stage RO + UV purification.",
            "status": "Active"
        }
    )
    p4, _ = Product.objects.get_or_create(
        sku="SKU-BOT-2000",
        defaults={
            "name": "Shivnath 2 Litre Family Mineral Bottle",
            "category": "Water Bottles",
            "category_ref": sub_2l,
            "size": "2 Litre",
            "price": Decimal("30.00"),
            "stock": 250,
            "unit": "Bottle",
            "description": "2 Litre large family packaged drinking water bottle.",
            "status": "Active"
        }
    )
    p5, _ = Product.objects.get_or_create(
        sku="SKU-JAR-20L",
        defaults={
            "name": "Shivnath 20 Litre Dispenser Jar",
            "category": "Water Jars",
            "category_ref": sub_20l,
            "size": "20 Litre",
            "price": Decimal("60.00"),
            "stock": 180,
            "unit": "Jar",
            "description": "20 Litre purified packaged drinking water jar for homes and offices.",
            "status": "Active"
        }
    )

    # 3. Quotations
    q1, _ = Quotation.objects.get_or_create(
        title="20L Jar Monthly Office Subscription",
        defaults={
            "quotation_type": "jar",
            "target_audience": "customer",
            "product": p5,
            "quantity_tier": "30 Jars / Month",
            "unit_price": Decimal("50.00"),
            "total_price": Decimal("1500.00"),
            "applicable_terms": "Daily morning delivery included. Security deposit of Rs 150 per empty jar.",
            "notes": "Discounted rate for corporate and office daily delivery.",
            "validity": "30 days",
            "is_active": True
        }
    )
    q2, _ = Quotation.objects.get_or_create(
        title="Shivnath Standard Franchise Setup Package",
        defaults={
            "quotation_type": "franchise",
            "target_audience": "franchise",
            "quantity_tier": "Complete Plant & Distribution Territory",
            "unit_price": Decimal("350000.00"),
            "total_price": Decimal("350000.00"),
            "applicable_terms": "Includes RO plant setup, initial stock, branding materials, and marketing support.",
            "notes": "Estimated 35% - 42% operational margin with territorial exclusivity.",
            "validity": "60 days",
            "is_active": True
        }
    )
    q3, _ = Quotation.objects.get_or_create(
        title="Bulk 1 Litre Bottle Wholesale Pack",
        defaults={
            "quotation_type": "bulk",
            "target_audience": "both",
            "product": p3,
            "quantity_tier": "100+ Boxes (1200 Bottles)",
            "unit_price": Decimal("14.00"),
            "total_price": Decimal("16800.00"),
            "applicable_terms": "Free transport within Raipur, Bilaspur, and Durg-Bhilai.",
            "notes": "Special direct wholesale pricing for distributors and retailers.",
            "validity": "45 days",
            "is_active": True
        }
    )

    # 4. Chatbot Options Hierarchy (Admin Configurable)
    cust_root, _ = ChatbotOption.objects.get_or_create(
        title="Customer / Product Inquiry",
        defaults={"inquiry_type": "customer", "order": 1, "is_active": True}
    )
    fran_root, _ = ChatbotOption.objects.get_or_create(
        title="Franchise Inquiry",
        defaults={"inquiry_type": "franchise", "order": 2, "is_active": True}
    )

    # Customer Sub-Options
    c_sub1, _ = ChatbotOption.objects.get_or_create(
        title="Product Pricing & Sizes", parent=cust_root,
        defaults={"inquiry_type": "customer", "order": 1, "is_active": True,
                  "answer_text": "Shivnath Agency provides:\n- 250ml Bottle: Rs 6\n- 500ml Bottle: Rs 10\n- 1 Litre Bottle: Rs 20\n- 2 Litre Bottle: Rs 30\n- 20 Litre Jar: Rs 60\n\nAll products undergo 7-stage RO + UV + Ozonation purification."}
    )
    c_sub2, _ = ChatbotOption.objects.get_or_create(
        title="Bottle Inquiry", parent=cust_root,
        defaults={"inquiry_type": "customer", "order": 2, "is_active": True,
                  "answer_text": "We offer 250ml, 500ml, 1 Litre, and 2 Litre packaged mineral water bottles with tamper-evident seal and BIS IS:14543 certification."}
    )
    c_sub3, _ = ChatbotOption.objects.get_or_create(
        title="20L Jar Delivery", parent=cust_root,
        defaults={"inquiry_type": "customer", "order": 3, "product": p5, "quotation": q1, "is_active": True,
                  "answer_text": "Shivnath 20 Litre Jars are delivered daily to homes and offices. Price is Rs 60 per jar, with monthly subscription discounts at Rs 50/jar."}
    )
    c_sub4, _ = ChatbotOption.objects.get_or_create(
        title="Bulk Quantity / Quotation", parent=cust_root,
        defaults={"inquiry_type": "customer", "order": 4, "quotation": q3, "is_active": True,
                  "answer_text": "Special wholesale discounts available for orders over 50+ units. Contact our bulk sales desk at +91 98062 47194 for customized contract rates."}
    )

    # Franchise Sub-Options
    f_sub1, _ = ChatbotOption.objects.get_or_create(
        title="Investment Requirement", parent=fran_root,
        defaults={"inquiry_type": "franchise", "order": 1, "is_active": True, "is_lead_trigger": True, "lead_inquiry_type": "franchise",
                  "answer_text": "Shivnath Franchise investment ranges from ₹3.5 Lakhs to ₹7.5 Lakhs depending on the territorial model and distribution capacity."}
    )
    f_sub2, _ = ChatbotOption.objects.get_or_create(
        title="Profit / Margin Information", parent=fran_root,
        defaults={"inquiry_type": "franchise", "order": 2, "is_active": True, "is_lead_trigger": True, "lead_inquiry_type": "franchise",
                  "answer_text": "Shivnath Franchise partners earn an estimated gross margin of 35% - 42% on bottle lines and 50% on 20L jar delivery networks."}
    )
    f_sub3, _ = ChatbotOption.objects.get_or_create(
        title="Territory & Location Availability", parent=fran_root,
        defaults={"inquiry_type": "franchise", "order": 3, "is_active": True, "is_lead_trigger": True, "lead_inquiry_type": "franchise",
                  "answer_text": "Territory exclusivity is granted per district or commercial zone across Chhattisgarh, Odisha, and MP. Submit your contact details for territory verification."}
    )
    f_sub4, _ = ChatbotOption.objects.get_or_create(
        title="Talk to Franchise Sales / Submit Lead", parent=fran_root,
        defaults={"inquiry_type": "franchise", "order": 4, "is_active": True, "is_lead_trigger": True, "lead_inquiry_type": "franchise", "quotation": q2,
                  "answer_text": "Our franchise development team will reach out to you within 24 business hours."}
    )

    print("Seeding completed successfully with real production database records.")

if __name__ == '__main__':
    seed()

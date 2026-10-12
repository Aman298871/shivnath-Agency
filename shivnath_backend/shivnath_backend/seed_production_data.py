import os
import django
from decimal import Decimal

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from django.contrib.auth.models import User
from accounts.models import UserProfile, AdminNotification
from products.models import ProductCategory, Product
from chat.models import ChatbotOption, Quotation
from leads.models import Lead, LeadActivity

def seed():
    print("Seeding initial production data for categories, products, quotations, customers, notifications, and chatbot options...")

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
    cat_dispensers, _ = ProductCategory.objects.get_or_create(
        name="Dispensers & Accessories",
        defaults={"slug": "dispensers-accessories", "order": 4, "description": "Water dispensers, stands, and automatic pumps", "is_active": True}
    )

    sub_200ml, _ = ProductCategory.objects.get_or_create(
        name="200 ML Bottle", parent=cat_bottles,
        defaults={"slug": "200ml-bottle", "order": 1, "description": "Hospitality and event water bottle", "is_active": True}
    )
    sub_250ml, _ = ProductCategory.objects.get_or_create(
        name="250 ML Bottle", parent=cat_bottles,
        defaults={"slug": "250ml-bottle", "order": 2, "description": "Small personal travel bottle", "is_active": True}
    )
    sub_500ml, _ = ProductCategory.objects.get_or_create(
        name="500 ML Bottle", parent=cat_bottles,
        defaults={"slug": "500ml-bottle", "order": 3, "description": "Standard travel water bottle", "is_active": True}
    )
    sub_1l, _ = ProductCategory.objects.get_or_create(
        name="1 Litre Bottle", parent=cat_bottles,
        defaults={"slug": "1-litre-bottle", "order": 4, "description": "1 Litre standard table water bottle", "is_active": True}
    )
    sub_20l, _ = ProductCategory.objects.get_or_create(
        name="20 Litre Jar", parent=cat_jars,
        defaults={"slug": "20-litre-jar", "order": 1, "description": "20 Litre returnable dispenser jar", "is_active": True}
    )

    # 2. Products - Exactly 5 Official Products
    p0, _ = Product.objects.update_or_create(
        sku="SHV-200",
        defaults={
            "name": "Shivnath 200ml Event Bottle",
            "category": "Water Bottles",
            "category_ref": sub_200ml,
            "size": "200 ML",
            "volume_ml": 200,
            "package_type": "BOTTLE",
            "units_per_case": 24,
            "price": Decimal("5.00"),
            "dealer_transfer_price": Decimal("3.50"),
            "mrp": Decimal("5.00"),
            "shelf_life_days": 180,
            "stock": 500,
            "unit": "Bottle",
            "image": "products/shv_200.jpg",
            "description": "200ml packaged pure drinking water, ideal for events, hospitality, and meetings.",
            "status": "Active"
        }
    )
    p1, _ = Product.objects.update_or_create(
        sku="SHV-250",
        defaults={
            "name": "Shivnath 250ml Mini Bottle",
            "category": "Water Bottles",
            "category_ref": sub_250ml,
            "size": "250 ML",
            "volume_ml": 250,
            "package_type": "BOTTLE",
            "units_per_case": 24,
            "price": Decimal("6.00"),
            "dealer_transfer_price": Decimal("4.00"),
            "mrp": Decimal("6.00"),
            "shelf_life_days": 180,
            "stock": 500,
            "unit": "Bottle",
            "image": "products/shv_250.jpg",
            "description": "250ml packaged drinking water, ideal for events, conferences and meetings.",
            "status": "Active"
        }
    )
    p2, _ = Product.objects.update_or_create(
        sku="SHV-500",
        defaults={
            "name": "Shivnath 500ml Travel Bottle",
            "category": "Water Bottles",
            "category_ref": sub_500ml,
            "size": "500 ML",
            "volume_ml": 500,
            "package_type": "BOTTLE",
            "units_per_case": 24,
            "price": Decimal("10.00"),
            "dealer_transfer_price": Decimal("7.00"),
            "mrp": Decimal("10.00"),
            "shelf_life_days": 180,
            "stock": 400,
            "unit": "Bottle",
            "image": "products/shv_500.jpg",
            "description": "500ml pure natural mineral water bottle.",
            "status": "Active"
        }
    )
    p3, _ = Product.objects.update_or_create(
        sku="SHV-1L",
        defaults={
            "name": "Shivnath 1 Litre Premium Mineral Bottle",
            "category": "Water Bottles",
            "category_ref": sub_1l,
            "size": "1 Litre",
            "volume_ml": 1000,
            "package_type": "BOTTLE",
            "units_per_case": 12,
            "price": Decimal("20.00"),
            "dealer_transfer_price": Decimal("14.00"),
            "mrp": Decimal("20.00"),
            "shelf_life_days": 180,
            "stock": 350,
            "unit": "Bottle",
            "image": "products/shv_1l.jpg",
            "description": "1 Litre table water bottle with 7-stage RO + UV purification.",
            "status": "Active"
        }
    )
    p4, _ = Product.objects.update_or_create(
        sku="SKU-BOT-2000",
        defaults={
            "name": "Shivnath 2 Litre Family Mineral Bottle",
            "category": "Water Bottles",
            "size": "2 Litre",
            "volume_ml": 2000,
            "package_type": "BOTTLE",
            "units_per_case": 9,
            "price": Decimal("30.00"),
            "dealer_transfer_price": Decimal("22.00"),
            "mrp": Decimal("30.00"),
            "shelf_life_days": 180,
            "stock": 0,
            "unit": "Bottle",
            "description": "2 Litre large family packaged drinking water bottle.",
            "status": "Inactive"
        }
    )
    p5, _ = Product.objects.update_or_create(
        sku="SHV-20L",
        defaults={
            "name": "Shivnath 20 Litre Dispenser Jar",
            "category": "Water Jars",
            "category_ref": sub_20l,
            "size": "20 Litre",
            "volume_ml": 20000,
            "package_type": "JAR",
            "units_per_case": 1,
            "price": Decimal("60.00"),
            "dealer_transfer_price": Decimal("40.00"),
            "mrp": Decimal("60.00"),
            "shelf_life_days": 45,
            "stock": 180,
            "unit": "Jar",
            "image": "products/shv_20l.jpg",
            "description": "20 Litre purified packaged drinking water jar for homes and offices.",
            "status": "Active"
        }
    )
    p6, _ = Product.objects.update_or_create(
        sku="SKU-ALK-1000",
        defaults={
            "name": "Shivnath 1L Alkaline Mineral Water",
            "category": "Alkaline Water",
            "size": "1 Litre",
            "price": Decimal("25.00"),
            "stock": 200,
            "unit": "Bottle",
            "description": "Enriched with essential minerals, high TDS and balanced 8.5+ pH for active wellness.",
            "status": "Inactive"
        }
    )
    p7, _ = Product.objects.update_or_create(
        sku="SKU-ACC-STAND",
        defaults={
            "name": "Shivnath Metal Jar Stand with Tap",
            "category": "Dispensers & Accessories",
            "size": "Standard",
            "price": Decimal("350.00"),
            "stock": 100,
            "unit": "Piece",
            "description": "Heavy duty powder-coated stainless steel table stand for 20L jars.",
            "status": "Inactive"
        }
    )
    p8, _ = Product.objects.update_or_create(
        sku="SKU-ACC-PUMP",
        defaults={
            "name": "Automatic USB Rechargeable Water Pump",
            "category": "Dispensers & Accessories",
            "size": "Universal 20L",
            "price": Decimal("450.00"),
            "stock": 120,
            "unit": "Piece",
            "description": "One-touch electric wireless water dispenser pump with long-lasting battery.",
            "status": "Inactive"
        }
    )

    # Inactivate any legacy SKUs or non-official products
    Product.objects.exclude(sku__in=["SHV-200", "SHV-250", "SHV-500", "SHV-1L", "SHV-20L"]).update(status="Inactive")

    # 3. Quotations with PDF Generation Metadata
    q1, _ = Quotation.objects.get_or_create(
        title="20L Jar Monthly Office Subscription",
        defaults={
            "quotation_type": "jar",
            "target_audience": "customer",
            "product": p5,
            "quantity_tier": "30 Jars / Month",
            "unit_price": Decimal("50.00"),
            "total_price": Decimal("1500.00"),
            "applicable_terms": "Daily morning doorstep delivery included in Raipur. Security deposit of Rs 150 per empty jar (Refundable).",
            "notes": "Discounted rate for corporate and office daily delivery.",
            "validity": "Valid for 30 days from generation",
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
            "applicable_terms": "Includes RO purification unit setup, initial product inventory stock, ERP billing software, and territory branding.",
            "notes": "Guaranteed 25% - 35% operational margin with exclusive 5 KM radius territorial rights.",
            "validity": "Valid for 60 days from generation",
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
            "applicable_terms": "Free transport within Raipur, Bilaspur, and Durg-Bhilai city limits.",
            "notes": "Special direct wholesale pricing for distributors, hotels, and retail outlets.",
            "validity": "Valid for 45 days from generation",
            "is_active": True
        }
    )
    q4, _ = Quotation.objects.get_or_create(
        title="Corporate & Event 2 Litre Family Pack Quotation",
        defaults={
            "quotation_type": "customer",
            "target_audience": "customer",
            "product": p4,
            "quantity_tier": "50+ Crates (450 Bottles)",
            "unit_price": Decimal("26.00"),
            "total_price": Decimal("11700.00"),
            "applicable_terms": "Includes direct venue vehicle dispatch with GST invoice and tamper-proof verification.",
            "notes": "Special catering and banquet hall bulk contract quotation.",
            "validity": "Valid for 30 days from generation",
            "is_active": True
        }
    )

    # 4. Registered Dummy Customers
    dummy_customers = [
        {"username": "ramesh_agarwal", "name": "Ramesh Agarwal", "phone": "9826112345", "email": "ramesh.agarwal@example.com", "city": "Raipur", "district": "Raipur", "address": "Plot 42, Shankar Nagar, Raipur"},
        {"username": "priya_sharma", "name": "Priya Sharma", "phone": "9827223456", "email": "priya.sharma@example.com", "city": "Bilaspur", "district": "Bilaspur", "address": "Shop 12, Vyapar Vihar, Bilaspur"},
        {"username": "vikram_patel", "name": "Vikram Patel", "phone": "9828334567", "email": "vikram.patel@example.com", "city": "Durg", "district": "Durg", "address": "G.E. Road, Malviya Nagar, Durg"},
        {"username": "sunita_dewangan", "name": "Sunita Dewangan", "phone": "9829445678", "email": "sunita.dewangan@example.com", "city": "Raipur", "district": "Raipur", "address": "Sector 2, Devendra Nagar, Raipur"},
    ]

    for c in dummy_customers:
        user, _ = User.objects.get_or_create(
            username=c["username"],
            defaults={"email": c["email"], "first_name": c["name"].split()[0], "last_name": c["name"].split()[-1]}
        )
        user.set_password("shivnath12")
        user.save()

        UserProfile.objects.get_or_create(
            user=user,
            defaults={
                "name": c["name"],
                "phone": c["phone"],
                "city": c["city"],
                "district": c["district"],
                "address": c["address"],
                "role": "customer",
                "status": "active"
            }
        )

    # 5. Dummy Admin Notifications
    notifications_data = [
        {"title": "New Order #1042 Received", "message": "Order #1042 placed by Ramesh Agarwal (Raipur) for 5x 20L Jars (₹300.00).", "type": "order_placed", "read": False},
        {"title": "Low Stock Warning: 2 Litre Bottles", "message": "Inventory for 2 Litre Mineral Water is at 45 units. Please initiate production bottling batch.", "type": "general", "read": False},
        {"title": "New Franchise Lead: Amit Sharma", "message": "Franchise inquiry received from Amit Sharma for Bilaspur North Zone (Budget: ₹10 Lakhs).", "type": "franchise_registration", "read": False},
        {"title": "Quotation Downloaded: 50+ Jars Quote", "message": "Official PDF Quotation was generated and downloaded for Corporate Office Subscription.", "type": "general", "read": True},
        {"title": "Customer Registered: Priya Sharma", "message": "New customer Priya Sharma verified mobile number and registered profile from Bilaspur.", "type": "customer_registration", "read": True},
        {"title": "Delivery Dispatched: Morning Route", "message": "Vehicle CG-04-1122 has departed plant for Shankar Nagar & Pandri scheduled morning jar deliveries.", "type": "general", "read": True},
    ]

    for n in notifications_data:
        AdminNotification.objects.get_or_create(
            title=n["title"],
            defaults={"message": n["message"], "notification_type": n["type"], "is_read": n["read"]}
        )

    # 6. Chatbot Options Hierarchy (Multi-Level Tree with Quotation PDF Download)
    cust_root, _ = ChatbotOption.objects.get_or_create(
        title="Customer / Product Inquiry",
        defaults={"inquiry_type": "customer", "order": 1, "is_active": True}
    )
    fran_root, _ = ChatbotOption.objects.get_or_create(
        title="Franchise Inquiry",
        defaults={"inquiry_type": "franchise", "order": 2, "is_active": True}
    )

    # 6A. CUSTOMER TREE
    c_bottles, _ = ChatbotOption.objects.get_or_create(
        title="Water Bottles", parent=cust_root,
        defaults={"inquiry_type": "customer", "order": 1, "is_active": True,
                  "answer_text": "We offer 250ml, 500ml, 1 Litre, and 2 Litre packaged mineral water bottles with BIS IS:14543 certification."}
    )
    c_bottle_2l, _ = ChatbotOption.objects.get_or_create(
        title="2 Litre Bottle", parent=c_bottles,
        defaults={"inquiry_type": "customer", "order": 1, "product": p4, "is_active": True,
                  "answer_text": "Shivnath 2 Litre Mineral Water Bottle is priced at Rs 30 per unit (Crate of 9: Rs 260)."}
    )
    ChatbotOption.objects.get_or_create(
        title="Price", parent=c_bottle_2l,
        defaults={"inquiry_type": "customer", "order": 1, "is_active": True, "is_lead_trigger": False,
                  "answer_text": "Shivnath 2 Litre Packaged Drinking Water is Rs 30 per unit. Box of 9 bottles is Rs 260."}
    )
    ChatbotOption.objects.get_or_create(
        title="Product Details", parent=c_bottle_2l,
        defaults={"inquiry_type": "customer", "order": 2, "product": p4, "is_active": True, "is_lead_trigger": True, "lead_inquiry_type": "customer",
                  "answer_text": "Shivnath 2 Litre Family Pack is bottled in our BIS IS:14543 certified plant with 7-stage RO + UV + Ozonation purification and balanced 7.2 pH minerals."}
    )
    ChatbotOption.objects.get_or_create(
        title="Bulk Order / Quotation", parent=c_bottle_2l,
        defaults={"inquiry_type": "customer", "order": 3, "quotation": q4, "is_active": True, "is_lead_trigger": True, "lead_inquiry_type": "customer",
                  "answer_text": "Wholesale discount: Rs 250 per box for orders exceeding 10+ boxes. You can download the official quotation PDF below."}
    )

    c_bottle_1l, _ = ChatbotOption.objects.get_or_create(
        title="1 Litre Bottle", parent=c_bottles,
        defaults={"inquiry_type": "customer", "order": 2, "product": p3, "is_active": True,
                  "answer_text": "Shivnath 1 Litre Packaged Water is Rs 20 per bottle (Box of 12: Rs 220)."}
    )
    ChatbotOption.objects.get_or_create(
        title="Price", parent=c_bottle_1l,
        defaults={"inquiry_type": "customer", "order": 1, "is_active": True, "is_lead_trigger": False,
                  "answer_text": "Shivnath 1 Litre Bottle is Rs 20 per bottle. Box of 12 bottles is Rs 220."}
    )
    ChatbotOption.objects.get_or_create(
        title="Product Details", parent=c_bottle_1l,
        defaults={"inquiry_type": "customer", "order": 2, "product": p3, "is_active": True, "is_lead_trigger": True, "lead_inquiry_type": "customer",
                  "answer_text": "1 Litre personal hydration bottle with tamper-evident seal and active minerals."}
    )

    c_jars, _ = ChatbotOption.objects.get_or_create(
        title="20 Litre Water Jar", parent=cust_root,
        defaults={"inquiry_type": "customer", "order": 2, "product": p5, "quotation": q1, "is_active": True,
                  "answer_text": "Shivnath 20 Litre Jars are delivered daily to homes and offices. Price is Rs 60 per refill."}
    )
    ChatbotOption.objects.get_or_create(
        title="Price & Security Deposit", parent=c_jars,
        defaults={"inquiry_type": "customer", "order": 1, "is_active": True, "is_lead_trigger": False,
                  "answer_text": "20L Jar Refill: Rs 60 per jar. First-time refundable security deposit: Rs 150 per jar."}
    )
    ChatbotOption.objects.get_or_create(
        title="Home / Office Subscription", parent=c_jars,
        defaults={"inquiry_type": "customer", "order": 2, "quotation": q1, "is_active": True, "is_lead_trigger": True, "lead_inquiry_type": "customer",
                  "answer_text": "Monthly subscription plan: Rs 50 per jar with daily morning doorstep delivery across Raipur city. Official contract quotation available for download."}
    )

    c_quotes, _ = ChatbotOption.objects.get_or_create(
        title="Official Quotations & Bulk Orders", parent=cust_root,
        defaults={"inquiry_type": "customer", "order": 3, "quotation": q3, "is_active": True,
                  "answer_text": "We provide special wholesale contract quotes for events, hotels, corporates and institutions."}
    )
    ChatbotOption.objects.get_or_create(
        title="Corporate / Event Bulk Quotation", parent=c_quotes,
        defaults={"inquiry_type": "customer", "order": 1, "quotation": q3, "is_active": True, "is_lead_trigger": True, "lead_inquiry_type": "customer",
                  "answer_text": "Tiered discounts of 15-20% available for orders of 50+ units with priority transport and GST invoices. Tap the button below to download the official quotation PDF."}
    )
    ChatbotOption.objects.get_or_create(
        title="Talk to Sales Executive", parent=c_quotes,
        defaults={"inquiry_type": "customer", "order": 2, "is_active": True, "is_lead_trigger": True, "lead_inquiry_type": "customer",
                  "answer_text": "Direct sales hotline: +91 98062 47194. Our representative will contact you with a customized quote."}
    )

    # 6B. FRANCHISE TREE
    f_territory, _ = ChatbotOption.objects.get_or_create(
        title="Territory Model & Availability", parent=fran_root,
        defaults={"inquiry_type": "franchise", "order": 1, "is_active": True,
                  "answer_text": "Exclusive 5 KM radius territory protection with direct bottling plant distribution rights."}
    )
    ChatbotOption.objects.get_or_create(
        title="Territory Model Details", parent=f_territory,
        defaults={"inquiry_type": "franchise", "order": 1, "is_active": True, "is_lead_trigger": False,
                  "answer_text": "Shivnath Agency assigns protected geographic territories to prevent intra-brand competition."}
    )
    ChatbotOption.objects.get_or_create(
        title="Check Territory Availability", parent=f_territory,
        defaults={"inquiry_type": "franchise", "order": 2, "is_active": True, "is_lead_trigger": True, "lead_inquiry_type": "franchise",
                  "answer_text": "Territory verification in progress for Chhattisgarh, Odisha, and MP. Submit your location details for instant feasibility check."}
    )

    f_invest, _ = ChatbotOption.objects.get_or_create(
        title="Investment & Space Requirements", parent=fran_root,
        defaults={"inquiry_type": "franchise", "order": 2, "is_active": True,
                  "answer_text": "Franchise investment ranges from Rs 3.5 Lakhs to Rs 7.5 Lakhs depending on territorial zone tier."}
    )
    ChatbotOption.objects.get_or_create(
        title="Investment Breakdown", parent=f_invest,
        defaults={"inquiry_type": "franchise", "order": 1, "quotation": q2, "is_active": True, "is_lead_trigger": True, "lead_inquiry_type": "franchise",
                  "answer_text": "Investment covers initial product inventory, security deposit, billing software, and local branding. You can download the complete franchise package quotation PDF below."}
    )
    ChatbotOption.objects.get_or_create(
        title="Space & Vehicle Requirements", parent=f_invest,
        defaults={"inquiry_type": "franchise", "order": 2, "is_active": True, "is_lead_trigger": False,
                  "answer_text": "Requires 500 to 1200 sq.ft commercial storage and 1 delivery 3-wheeler or mini-truck."}
    )

    f_margin, _ = ChatbotOption.objects.get_or_create(
        title="Profit Margins & ROI", parent=fran_root,
        defaults={"inquiry_type": "franchise", "order": 3, "is_active": True,
                  "answer_text": "Franchise partners earn an estimated gross margin of 25% - 35% on bottles and up to 50% on 20L jars."}
    )
    ChatbotOption.objects.get_or_create(
        title="Margin & ROI Calculation", parent=f_margin,
        defaults={"inquiry_type": "franchise", "order": 1, "is_active": True, "is_lead_trigger": True, "lead_inquiry_type": "franchise",
                  "answer_text": "Average break-even ROI is achieved within 6 to 9 months with an established route."}
    )

    ChatbotOption.objects.get_or_create(
        title="Apply for Franchise (Qualify Now)", parent=fran_root,
        defaults={"inquiry_type": "franchise", "order": 4, "quotation": q2, "is_active": True, "is_lead_trigger": True, "lead_inquiry_type": "franchise",
                  "answer_text": "Let us capture your franchise details and pre-qualify your preferred location. You can also review the franchise setup quotation PDF."}
    )

    ChatbotOption.objects.get_or_create(
        title="Contact Franchise Desk", parent=fran_root,
        defaults={"inquiry_type": "franchise", "order": 5, "is_active": True, "is_lead_trigger": True, "lead_inquiry_type": "franchise",
                  "answer_text": "Franchise Hotline: +91 98062 47194. Head Office: H Block, Farishta Complex, Raipur, CG."}
    )

    # =====================================================================
    # 7. [TEST / DEMO SEED DATA] MASTER TERRITORY & FRANCHISE ASSIGNMENTS
    # =====================================================================
    print("Seeding [TEST / DEMO SEED DATA] for territory, zones, PIN mappings, and franchise territory assignments...")
    from accounts.models import (
        ServiceDistrict, ServiceZone, ServiceArea,
        FranchiseProfile, FranchiseTerritoryAssignment
    )

    # All 33 Official Chhattisgarh Districts & Zones
    cg_districts_data = {
        "Raipur": [("East Raipur", "RPR-EAST"), ("West Raipur", "RPR-WEST"), ("North Raipur", "RPR-NORTH"), ("South Raipur", "RPR-SOUTH")],
        "Durg": [("Central Durg", "DURG-CENTRAL"), ("Bhilai Urban", "DURG-BHL-URBAN"), ("Durg Rural", "DURG-RURAL")],
        "Bilaspur": [("Bilaspur Central", "BIL-CENTRAL"), ("Bilaspur North", "BIL-NORTH"), ("Bilaspur South", "BIL-SOUTH")],
        "Rajnandgaon": [("Rajnandgaon Central", "RJN-CENTRAL"), ("Rajnandgaon Rural", "RJN-RURAL")],
        "Korba": [("Korba City", "KRB-CITY"), ("Korba Industrial", "KRB-IND")],
        "Raigarh": [("Raigarh City", "RGH-CITY"), ("Raigarh Rural", "RGH-RURAL")],
        "Bastar": [("Jagdalpur City", "BST-JGD-CITY"), ("Bastar Rural", "BST-RURAL")],
        "Surguja": [("Ambikapur City", "SRG-AMB-CITY"), ("Surguja Rural", "SRG-RURAL")],
        "Dhamtari": [("Dhamtari City", "DHM-CITY"), ("Dhamtari Rural", "DHM-RURAL")],
        "Mahasamund": [("Mahasamund Central", "MHS-CENTRAL"), ("Saraipali", "MHS-SRP")],
        "Balod": [("Balod Central", "BLD-CENTRAL"), ("Dondi Lohara", "BLD-DND")],
        "Bemetara": [("Bemetara Central", "BMT-CENTRAL"), ("Berla", "BMT-BRL")],
        "Baloda Bazar - Bhatapara": [("Baloda Bazar Central", "BBB-CENTRAL"), ("Bhatapara Urban", "BBB-BHT")],
        "Gariaband": [("Gariaband Central", "GRB-CENTRAL"), ("Rajim", "GRB-RJM")],
        "Janjgir-Champa": [("Janjgir City", "JJC-CITY"), ("Champa Urban", "JJC-CMP")],
        "Sakti": [("Sakti Central", "SKT-CENTRAL"), ("Jaijaipur", "SKT-JJP")],
        "Mungeli": [("Mungeli Central", "MNG-CENTRAL"), ("Lormi", "MNG-LRM")],
        "Gaurela-Pendra-Marwahi": [("Gaurela Central", "GPM-CENTRAL"), ("Pendra", "GPM-PND")],
        "Kabirdham (Kawardha)": [("Kawardha City", "KBD-KWD-CITY"), ("Pandariya", "KBD-PND")],
        "Khairagarh-Chhuikhadan-Gandai": [("Khairagarh Central", "KCG-CENTRAL"), ("Chhuikhadan", "KCG-CHK")],
        "Mohla-Manpur-Ambagarh Chowki": [("Mohla Central", "MMA-CENTRAL"), ("Manpur", "MMA-MNP")],
        "Kanker": [("Kanker Central", "KNK-CENTRAL"), ("Charama", "KNK-CHM")],
        "Kondagaon": [("Kondagaon Central", "KND-CENTRAL"), ("Keshkal", "KND-KSH")],
        "Narayanpur": [("Narayanpur Central", "NRY-CENTRAL"), ("Orchha", "NRY-ORC")],
        "Dantewada": [("Dantewada Central", "DNT-CENTRAL"), ("Kirandul", "DNT-KRN")],
        "Bijapur": [("Bijapur Central", "BJP-CENTRAL"), ("Bhopalpatnam", "BJP-BHP")],
        "Sukma": [("Sukma Central", "SKM-CENTRAL"), ("Konta", "SKM-KNT")],
        "Koriya": [("Baikunthpur Central", "KRY-BKP"), ("Sonhat", "KRY-SNH")],
        "Manendragarh-Chirmiri-Bharatpur": [("Manendragarh City", "MCB-MND"), ("Chirmiri Urban", "MCB-CHM")],
        "Surajpur": [("Surajpur Central", "SRP-CENTRAL"), ("Bhaiyathan", "SRP-BHY")],
        "Balrampur-Ramanujganj": [("Balrampur Central", "BLR-CENTRAL"), ("Ramanujganj", "BLR-RMN")],
        "Jashpur": [("Jashpur Nagar", "JSH-NGR"), ("Kunkuri", "JSH-KNK")],
        "Sarangarh-Bilaigarh": [("Sarangarh Central", "SGB-CENTRAL"), ("Bilaigarh", "SGB-BLG")],
    }

    created_zones = {}
    for dist_name, zones_list in cg_districts_data.items():
        d_obj, _ = ServiceDistrict.objects.get_or_create(name=dist_name, defaults={"state": "Chhattisgarh", "is_active": True})
        if not d_obj.is_active:
            d_obj.is_active = True
            d_obj.save(update_fields=["is_active"])
        for z_name, z_code in zones_list:
            z_obj, _ = ServiceZone.objects.get_or_create(district=d_obj, name=z_name, defaults={"code": z_code, "is_active": True})
            if not z_obj.is_active:
                z_obj.is_active = True
                z_obj.save(update_fields=["is_active"])
            created_zones[(dist_name, z_name)] = z_obj

    d_raipur = ServiceDistrict.objects.get(name="Raipur")
    d_durg = ServiceDistrict.objects.get(name="Durg")
    d_bilaspur = ServiceDistrict.objects.get(name="Bilaspur")
    z_east_raipur = created_zones[("Raipur", "East Raipur")]
    z_west_raipur = created_zones[("Raipur", "West Raipur")]
    z_central_durg = created_zones[("Durg", "Central Durg")]
    z_central_bilaspur = created_zones[("Bilaspur", "Bilaspur Central")]

    # Service Areas (PIN mappings) [TEST / DEMO DATA]
    ServiceArea.objects.get_or_create(district=d_raipur, zone=z_east_raipur, pincode="492001", locality_name="Pandri", defaults={"is_active": True})
    ServiceArea.objects.get_or_create(district=d_raipur, zone=z_east_raipur, pincode="492001", locality_name="Devendra Nagar", defaults={"is_active": True})
    ServiceArea.objects.get_or_create(district=d_raipur, zone=z_east_raipur, pincode="492006", locality_name="Telibandha", defaults={"is_active": True})
    ServiceArea.objects.get_or_create(district=d_raipur, zone=z_west_raipur, pincode="492002", locality_name="Gudhiyari", defaults={"is_active": True})
    # Ambiguous test PIN (maps to two different zones)
    ServiceArea.objects.get_or_create(district=d_raipur, zone=z_east_raipur, pincode="492099", locality_name="North Pandri Border", defaults={"is_active": True})
    ServiceArea.objects.get_or_create(district=d_raipur, zone=z_west_raipur, pincode="492099", locality_name="Gudhiyari East Border", defaults={"is_active": True})
    # Durg & Bilaspur test areas
    ServiceArea.objects.get_or_create(district=d_durg, zone=z_central_durg, pincode="490006", locality_name="Bhilai Sector 1-6", defaults={"is_active": True})
    ServiceArea.objects.get_or_create(district=d_bilaspur, zone=z_central_bilaspur, pincode="495001", locality_name="Vyapar Vihar", defaults={"is_active": True})

    # Super Admin [OFFICIAL PRODUCTION ACCOUNT]
    for adm_email in ["admin@gmail.com", "admin@shivnath.com"]:
        u_adm, _ = User.objects.get_or_create(
            username=adm_email,
            defaults={"email": adm_email, "first_name": "Shivnath", "last_name": "SuperAdmin", "is_superuser": True, "is_staff": True, "is_active": True}
        )
        u_adm.is_superuser = True
        u_adm.is_staff = True
        u_adm.is_active = True
        u_adm.set_password("shivnath12")
        u_adm.save()
        p_adm, _ = UserProfile.objects.get_or_create(
            user=u_adm,
            defaults={"name": "Shivnath Super Admin", "phone": "9806247194", "role": "super_admin", "status": "active", "city": "Raipur", "district": "Raipur"}
        )
        p_adm.role = "super_admin"
        p_adm.status = "active"
        p_adm.save(update_fields=['role', 'status'])

    # Plant Admin [OFFICIAL PRODUCTION ACCOUNT]
    u_plant, _ = User.objects.get_or_create(
        username="plant@shivnath.com",
        defaults={"email": "plant@shivnath.com", "first_name": "Plant", "last_name": "Manager", "is_superuser": False, "is_staff": True, "is_active": True}
    )
    u_plant.is_staff = True
    u_plant.is_active = True
    u_plant.set_password("shivnath12")
    u_plant.save()
    p_plant, _ = UserProfile.objects.get_or_create(user=u_plant, defaults={"name": "Central Plant Admin", "phone": "9806247195", "role": "admin", "status": "active", "city": "Raipur", "district": "Raipur"})
    p_plant.role = "admin"
    p_plant.status = "active"
    p_plant.save(update_fields=['role', 'status'])

    # Headquarters Franchise [TEST / DEMO SEED DATA]
    u_hq, _ = User.objects.get_or_create(
        username="hq@shivnath.com",
        defaults={"email": "hq@shivnath.com", "first_name": "Shivnath Central HQ", "is_active": True}
    )
    u_hq.set_password("shivnath12")
    u_hq.save()
    p_hq, _ = UserProfile.objects.get_or_create(user=u_hq, defaults={"name": "Shivnath Central HQ", "phone": "9806247194", "role": "franchise", "status": "active", "city": "Raipur", "district": "Raipur"})
    p_hq.role = "franchise"
    p_hq.status = "active"
    p_hq.save(update_fields=['role', 'status'])
    f_hq, _ = FranchiseProfile.objects.get_or_create(
        user=u_hq,
        defaults={
            "business_name": "Shivnath Agency Central HQ",
            "city": "Raipur",
            "address": "Farishta Complex, G.E. Road, Raipur",
            "territory": "All Chhattisgarh",
            "is_headquarters": True,
            "status": "approved",
            "security_deposit": Decimal("100000.00"),
            "commission": Decimal("15.00"),
            "agreement_status": "uploaded",
        }
    )
    f_hq.is_headquarters = True
    f_hq.status = "approved"
    f_hq.save(update_fields=['is_headquarters', 'status'])

    # Primary Franchise for East Raipur [TEST / DEMO SEED DATA]
    u_f1, _ = User.objects.get_or_create(
        username="franchise_east@shivnath.com",
        defaults={"email": "franchise_east@shivnath.com", "first_name": "Ramesh Kumar (East)", "is_active": True}
    )
    u_f1.set_password("shivnath12")
    u_f1.save()
    up1, _ = UserProfile.objects.get_or_create(user=u_f1, defaults={"name": "Ramesh Kumar", "phone": "9826123456", "role": "franchise", "status": "active", "city": "Raipur", "district": "Raipur"})
    up1.role = "franchise"
    up1.status = "active"
    up1.save()
    f_east, _ = FranchiseProfile.objects.get_or_create(
        user=u_f1,
        defaults={
            "business_name": "Shivnath Water Raipur East",
            "city": "Raipur",
            "address": "Shop 12, Pandri Market, Raipur",
            "territory": "East Raipur",
            "is_headquarters": False,
            "status": "approved",
            "security_deposit": Decimal("50000.00"),
            "commission": Decimal("10.00"),
            "agreement_status": "uploaded",
        }
    )
    f_east.status = "approved"
    f_east.save()
    FranchiseTerritoryAssignment.objects.get_or_create(
        franchise=f_east, zone=z_east_raipur,
        defaults={"is_primary": True, "is_active": True}
    )

    # Secondary Franchise for East Raipur [TEST / DEMO SEED DATA]
    u_f2, _ = User.objects.get_or_create(
        username="pureflow_east@shivnath.com",
        defaults={"email": "pureflow_east@shivnath.com", "first_name": "Sunil Agrawal", "is_active": True}
    )
    u_f2.set_password("shivnath12")
    u_f2.save()
    if not u_f2.has_usable_password():
        u_f2.set_password("franchise123456")
        u_f2.save()
    up2, _ = UserProfile.objects.get_or_create(user=u_f2, defaults={"name": "Sunil Agrawal", "phone": "9826987654", "role": "franchise", "status": "active", "city": "Raipur", "district": "Raipur"})
    up2.role = "franchise"
    up2.status = "active"
    up2.save()
    f_east_sec, _ = FranchiseProfile.objects.get_or_create(
        user=u_f2,
        defaults={
            "business_name": "Pure Flow Water East Zone",
            "city": "Raipur",
            "address": "Telibandha Main Road, Raipur",
            "territory": "East Raipur",
            "is_headquarters": False,
            "status": "approved",
            "security_deposit": Decimal("50000.00"),
            "commission": Decimal("10.00"),
            "agreement_status": "uploaded",
        }
    )
    f_east_sec.status = "approved"
    f_east_sec.save()
    FranchiseTerritoryAssignment.objects.get_or_create(
        franchise=f_east_sec, zone=z_east_raipur,
        defaults={"is_primary": False, "is_active": True}
    )

    # Primary Franchise for Central Durg [TEST / DEMO SEED DATA]
    u_f3, _ = User.objects.get_or_create(
        username="franchise_durg@shivnath.com",
        defaults={"email": "franchise_durg@shivnath.com", "first_name": "Vijay Verma (Durg)", "is_active": True}
    )
    u_f3.set_password("shivnath12")
    u_f3.save()
    up3, _ = UserProfile.objects.get_or_create(user=u_f3, defaults={"name": "Vijay Verma", "phone": "9827112233", "role": "franchise", "status": "active", "city": "Durg", "district": "Durg"})
    up3.role = "franchise"
    up3.status = "active"
    up3.save()
    f_durg, _ = FranchiseProfile.objects.get_or_create(
        user=u_f3,
        defaults={
            "business_name": "Shivnath Water Durg",
            "city": "Durg",
            "address": "Station Road, Durg",
            "territory": "Central Durg",
            "is_headquarters": False,
            "status": "approved",
            "security_deposit": Decimal("50000.00"),
            "commission": Decimal("10.00"),
            "agreement_status": "uploaded",
        }
    )
    FranchiseTerritoryAssignment.objects.get_or_create(
        franchise=f_durg, zone=z_central_durg,
        defaults={"is_primary": True, "is_active": True}
    )

    # 7. Customer Franchise Relationships, Orders, Inventory & Stock Requests
    import datetime
    from django.utils import timezone
    from accounts.models import CustomerFranchiseRelationship
    from orders.models import Order, OrderItem
    from inventory.models import DealerStockBatch, DealerStockRequest

    today = timezone.now().date()
    now = timezone.now()

    u_ramesh = User.objects.get(username="ramesh_agarwal")
    u_priya = User.objects.get(username="priya_sharma")
    u_vikram = User.objects.get(username="vikram_patel")
    u_sunita = User.objects.get(username="sunita_dewangan")

    CustomerFranchiseRelationship.objects.update_or_create(
        customer=u_ramesh,
        defaults={
            "registered_franchise": f_east,
            "current_serving_franchise": f_east,
            "district": d_raipur,
            "zone": z_east_raipur,
            "service_status": "active",
        }
    )
    CustomerFranchiseRelationship.objects.update_or_create(
        customer=u_sunita,
        defaults={
            "registered_franchise": f_east,
            "current_serving_franchise": f_east,
            "district": d_raipur,
            "zone": z_east_raipur,
            "service_status": "active",
        }
    )
    CustomerFranchiseRelationship.objects.update_or_create(
        customer=u_vikram,
        defaults={
            "registered_franchise": f_durg,
            "current_serving_franchise": f_durg,
            "district": d_durg,
            "zone": z_central_durg,
            "service_status": "active",
        }
    )

    DealerStockBatch.objects.update_or_create(
        batch_number="DSB-EAST-20L-01",
        defaults={
            "dealer": f_east,
            "product": p5,
            "manufacture_date": today - datetime.timedelta(days=2),
            "expiry_date": today + datetime.timedelta(days=43),
            "received_quantity": 200,
            "remaining_quantity": 160,
            "reserved_quantity": 20,
            "damaged_quantity": 0,
            "unit_transfer_price": Decimal("40.00"),
            "is_active": True,
        }
    )
    DealerStockBatch.objects.update_or_create(
        batch_number="DSB-EAST-1L-01",
        defaults={
            "dealer": f_east,
            "product": p3,
            "manufacture_date": today - datetime.timedelta(days=5),
            "expiry_date": today + datetime.timedelta(days=175),
            "received_quantity": 240,
            "remaining_quantity": 200,
            "reserved_quantity": 0,
            "damaged_quantity": 0,
            "unit_transfer_price": Decimal("14.00"),
            "is_active": True,
        }
    )

    o1, _ = Order.objects.update_or_create(
        id=101,
        defaults={
            "created_by": u_ramesh,
            "franchise_name": f_east.business_name,
            "serving_franchise": f_east,
            "city": "Raipur",
            "territory": "East Raipur",
            "amount": Decimal("1200.00"),
            "tax_amount": Decimal("216.00"),
            "grand_total": Decimal("1416.00"),
            "status": "delivered",
            "payment_status": "paid",
            "payment_mode": "ONLINE",
            "order_source": "FRANCHISE",
            "items_count": 20,
            "delivered_at": now - datetime.timedelta(hours=2),
        }
    )
    OrderItem.objects.update_or_create(
        order=o1, product=p5,
        defaults={
            "product_name": p5.name,
            "quantity": 20,
            "unit_price": p5.price,
            "total_price": Decimal("1200.00"),
        }
    )

    o2, _ = Order.objects.update_or_create(
        id=102,
        defaults={
            "created_by": u_ramesh,
            "franchise_name": f_east.business_name,
            "serving_franchise": f_east,
            "city": "Raipur",
            "territory": "East Raipur",
            "amount": Decimal("480.00"),
            "tax_amount": Decimal("86.40"),
            "grand_total": Decimal("566.40"),
            "status": "order_placement",
            "payment_status": "pending",
            "payment_mode": "ONLINE",
            "order_source": "FRANCHISE",
            "items_count": 24,
        }
    )
    OrderItem.objects.update_or_create(
        order=o2, product=p3,
        defaults={
            "product_name": p3.name,
            "quantity": 24,
            "unit_price": p3.price,
            "total_price": Decimal("480.00"),
        }
    )

    o3, _ = Order.objects.update_or_create(
        id=103,
        defaults={
            "created_by": u_priya,
            "franchise_name": "Shivnath Agency Central Plant",
            "serving_franchise": None,
            "city": "Bilaspur",
            "territory": "Bilaspur Central",
            "amount": Decimal("2400.00"),
            "tax_amount": Decimal("432.00"),
            "grand_total": Decimal("2832.00"),
            "status": "preparing",
            "payment_status": "paid",
            "payment_mode": "ONLINE",
            "order_source": "DIRECT_COMPANY",
            "items_count": 240,
        }
    )
    OrderItem.objects.update_or_create(
        order=o3, product=p2,
        defaults={
            "product_name": p2.name,
            "quantity": 240,
            "unit_price": p2.price,
            "total_price": Decimal("2400.00"),
        }
    )

    o4, _ = Order.objects.update_or_create(
        id=104,
        defaults={
            "created_by": u_sunita,
            "franchise_name": f_east.business_name,
            "serving_franchise": f_east,
            "city": "Raipur",
            "territory": "East Raipur",
            "amount": Decimal("300.00"),
            "tax_amount": Decimal("54.00"),
            "grand_total": Decimal("354.00"),
            "status": "dispatch",
            "payment_status": "pending",
            "payment_mode": "ONLINE",
            "order_source": "FRANCHISE",
            "items_count": 5,
        }
    )
    OrderItem.objects.update_or_create(
        order=o4, product=p5,
        defaults={
            "product_name": p5.name,
            "quantity": 5,
            "unit_price": p5.price,
            "total_price": Decimal("300.00"),
        }
    )

    DealerStockRequest.objects.update_or_create(
        request_number="SR-EAST-2026-001",
        defaults={
            "dealer": f_east,
            "product": p5,
            "requested_quantity": 50,
            "approved_quantity": 50,
            "status": "APPROVED",
            "dealer_notes": "Replenishment request for 20L jars in East Raipur zone.",
            "admin_notes": "Approved for dispatch from Central Plant.",
        }
    )

    print("Seeding completed successfully with rich production products, customers, franchises, orders, inventory, and territories.")

if __name__ == '__main__':
    seed()


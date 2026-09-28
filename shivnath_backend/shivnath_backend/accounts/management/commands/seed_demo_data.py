import datetime
from decimal import Decimal
from django.core.management.base import BaseCommand
from django.contrib.auth.models import User
from django.contrib.auth.hashers import make_password
from django.utils import timezone
from django.conf import settings
from django.db import transaction

from accounts.models import (
    UserProfile,
    FranchiseProfile,
    ServiceDistrict,
    ServiceZone,
    AdminNotification,
    AdminAuditLog,
    Notification,
    SupportContact,
    DealerDocument,
)
from products.models import (
    Product,
    ProductCategory,
    ProductionRecipeBOM,
    ProductionRecipeBOMItem,
    ProductStockThreshold,
)
from inventory.models import (
    RawMaterial,
    ProductionBatch,
    DealerStockBatch,
    DealerStockRequest,
    DealerStockRequestAllocation,
    InventoryTransactionLedger,
    ExpiryAlertLog,
    Expense,
    DailyBusinessReport,
)
from suppliers.models import (
    Supplier,
    PurchaseOrder,
    PurchaseOrderItem,
)
from orders.models import (
    Order,
    OrderItem,
    OrderItemBatchReservation,
    OrderStatusHistory,
)
from billing.models import (
    CompanyBillingProfile,
    DealerCreditProfile,
    Invoice,
    PaymentTransaction,
)
from leads.models import (
    Lead,
    LeadActivity,
    CRMActivityLog,
)
from followups.models import (
    FollowUp,
)


class Command(BaseCommand):
    help = "Seeds complete, authoritative, idempotent development demo dataset for Shivnath Agency ERP/CRM."

    def add_arguments(self, parser):
        parser.add_argument(
            '--force',
            action='store_true',
            help='Force seeding even if settings.DEBUG is False',
        )

    def handle(self, *args, **options):
        force = options.get('force', False)
        if not settings.DEBUG and not force:
            self.stdout.write(self.style.ERROR(
                "CRITICAL SAFETY WARNING: settings.DEBUG is False. "
                "Demo seed data should not be run against production without --force. Aborting."
            ))
            return

        self.stdout.write(self.style.NOTICE("=== Starting Complete Shivnath Agency ERP/CRM Demo Data Seeding ==="))

        with transaction.atomic():
            self._seed_company_billing_profile()
            admins = self._seed_admin_accounts()
            self._seed_territories()
            products = self._seed_products()
            raw_materials = self._seed_raw_materials()
            suppliers = self._seed_suppliers(raw_materials, admins)
            self._seed_boms(products, raw_materials)
            dealers = self._seed_dealers()
            customers = self._seed_customers()
            batches = self._seed_production_batches(products)
            self._seed_dealer_batches(dealers, products, batches)
            orders = self._seed_orders(products, dealers, customers, batches)
            self._seed_stock_requests(dealers, products, batches)
            self._seed_inventory_ledger(products, raw_materials, dealers, batches)
            self._seed_billing_and_payments(orders, dealers)
            self._seed_crm_leads_and_activities(dealers, admins)
            self._seed_notifications(dealers, orders)
            self._seed_support_contacts()
            self._seed_daily_reports_and_expenses(admins)
            self._seed_audit_logs(admins)

        self.stdout.write(self.style.SUCCESS("=== Shivnath Agency Demo Dataset Seeded Successfully (Idempotent) ==="))

    def _seed_company_billing_profile(self):
        self.stdout.write("0. Seeding Company Billing Profile...")
        CompanyBillingProfile.objects.update_or_create(
            id=1,
            defaults={
                "legal_name": "Shivnath Beverages & Packaged Drinking Water Pvt. Ltd.",
                "trade_name": "Shivnath Agency",
                "gstin": "22AABCS1234F1Z5",
                "pan": "AABCS1234F",
                "registered_address": "Plot 42-45, Industrial Growth Centre, Phase-II, Raipur, Chhattisgarh - 492001",
                "state_name": "Chhattisgarh",
                "state_code": "22",
                "invoice_prefix": "SHV/2026/",
                "cgst_rate": Decimal("9.00"),
                "sgst_rate": Decimal("9.00"),
                "igst_rate": Decimal("18.00"),
                "bank_name": "State Bank of India, SME Branch Raipur",
                "bank_account_number": "38491029485",
                "bank_ifsc_code": "SBIN0004521",
                "upi_id": "shivnathagency@sbi",
                "is_configured": True,
            }
        )

    def _seed_admin_accounts(self):
        self.stdout.write("1. Seeding Demo Admin & Staff Accounts...")
        admins_data = [
            {
                "username": "demo_superadmin@shivnath.local",
                "email": "demo_superadmin@shivnath.local",
                "name": "Demo Super Admin",
                "phone": "9800000001",
                "role": "super_admin",
                "data_scope_type": "all_data",
                "assigned_scope_ids": [],
                "permissions": [
                    "orders", "inventory", "dealers", "customers", "leads", "products",
                    "production", "stock_requests", "followups", "reports", "notifications",
                    "support", "admin_management", "pricing", "audit"
                ],
            },
            {
                "username": "demo_admin@shivnath.local",
                "email": "demo_admin@shivnath.local",
                "name": "Central Plant Admin",
                "phone": "9800000002",
                "role": "admin",
                "data_scope_type": "all_data",
                "assigned_scope_ids": [],
                "permissions": [
                    "orders", "inventory", "dealers", "customers", "products",
                    "production", "stock_requests", "reports", "notifications"
                ],
            },
            {
                "username": "demo_sales_raipur@shivnath.local",
                "email": "demo_sales_raipur@shivnath.local",
                "name": "Sales Executive (Raipur Territory)",
                "phone": "9800000003",
                "role": "sales_executive",
                "data_scope_type": "territory_scoped",
                "assigned_scope_ids": ["Raipur Central", "Raipur Industrial"],
                "permissions": ["leads", "followups", "orders", "customers"],
            },
            {
                "username": "demo_sales_bilaspur@shivnath.local",
                "email": "demo_sales_bilaspur@shivnath.local",
                "name": "Sales Executive (Bilaspur Zone)",
                "phone": "9800000004",
                "role": "sales_executive",
                "data_scope_type": "territory_scoped",
                "assigned_scope_ids": ["Bilaspur East", "Bilaspur City"],
                "permissions": ["leads", "followups", "orders", "customers"],
            },
        ]

        test_password_hash = make_password("DemoAdmin@2026!")
        admin_users = {}

        for a in admins_data:
            user, created = User.objects.get_or_create(
                username=a["username"],
                defaults={
                    "email": a["email"],
                    "first_name": a["name"],
                    "password": test_password_hash,
                    "is_active": True,
                    "is_staff": a["role"] in ["super_admin", "admin"],
                    "is_superuser": a["role"] == "super_admin",
                }
            )
            if not created:
                user.first_name = a["name"]
                user.is_active = True
                user.save()

            prof, _ = UserProfile.objects.get_or_create(user=user)
            prof.name = a["name"]
            prof.phone = a["phone"]
            prof.role = a["role"]
            prof.status = "active"
            prof.data_scope_type = a["data_scope_type"]
            prof.assigned_scope_ids = a["assigned_scope_ids"]
            prof.admin_permissions = a["permissions"]
            prof.save()
            admin_users[a["role"]] = user

        return admin_users

    def _seed_territories(self):
        self.stdout.write("2. Seeding Service Districts & Zones...")
        districts = {
            "Raipur": ["Raipur Central", "Raipur Industrial"],
            "Bilaspur": ["Bilaspur East", "Bilaspur City"],
            "Durg": ["Durg-Bhilai Commercial", "Bhilai Sector"],
            "Rajnandgaon": ["Rajnandgaon Central", "Dongargarh Road"],
            "Korba": ["Korba Industrial Power Hub", "Transport Nagar"],
        }
        for dist_name, zones in districts.items():
            dist, _ = ServiceDistrict.objects.get_or_create(
                name=dist_name,
                defaults={"state": "Chhattisgarh", "is_active": True}
            )
            for z_name in zones:
                z_code = f"ZN-{dist_name[:3].upper()}-{z_name.split()[-1][:3].upper()}"
                ServiceZone.objects.get_or_create(
                    district=dist,
                    name=z_name,
                    defaults={"code": z_code, "is_active": True}
                )

    def _seed_products(self):
        self.stdout.write("3. Seeding Exactly 5 Official Products...")
        cat_bottles, _ = ProductCategory.objects.get_or_create(
            slug="water-bottles",
            defaults={"name": "Packaged Water Bottles", "order": 1, "is_active": True}
        )
        cat_jars, _ = ProductCategory.objects.get_or_create(
            slug="water-jars",
            defaults={"name": "20L Water Jars", "order": 2, "is_active": True}
        )

        official_products = [
            {
                "sku": "SKU-BOT-200",
                "name": "Shivnath 200ml Event Bottle",
                "size": "200 ML",
                "volume_ml": 200,
                "package_type": "BOTTLE",
                "units_per_case": 24,
                "price": Decimal("5.00"),
                "dealer_transfer_price": Decimal("3.50"),
                "mrp": Decimal("5.00"),
                "stock": 3500,
                "unit": "Bottle",
                "category": "Bottle",
                "category_ref": cat_bottles,
                "shelf_life_days": 180,
                "status": "Active",
                "description": "200ml compact drinking water bottle ideal for events, caterers, and conferences.",
            },
            {
                "sku": "SKU-BOT-250",
                "name": "Shivnath 250ml Mini Bottle",
                "size": "250 ML",
                "volume_ml": 250,
                "package_type": "BOTTLE",
                "units_per_case": 24,
                "price": Decimal("6.00"),
                "dealer_transfer_price": Decimal("4.20"),
                "mrp": Decimal("6.00"),
                "stock": 4200,
                "unit": "Bottle",
                "category": "Bottle",
                "category_ref": cat_bottles,
                "shelf_life_days": 180,
                "status": "Active",
                "description": "250ml handy water bottle designed for hotels, restaurants, and corporate meetings.",
            },
            {
                "sku": "SKU-BOT-500",
                "name": "Shivnath 500ml Travel Bottle",
                "size": "500 ML",
                "volume_ml": 500,
                "package_type": "BOTTLE",
                "units_per_case": 24,
                "price": Decimal("10.00"),
                "dealer_transfer_price": Decimal("7.00"),
                "mrp": Decimal("10.00"),
                "stock": 6000,
                "unit": "Bottle",
                "category": "Bottle",
                "category_ref": cat_bottles,
                "shelf_life_days": 180,
                "status": "Active",
                "description": "500ml on-the-go pure mineral drinking water bottle.",
            },
            {
                "sku": "SKU-BOT-1000",
                "name": "Shivnath 1 Litre Premium Mineral Bottle",
                "size": "1 Litre",
                "volume_ml": 1000,
                "package_type": "BOTTLE",
                "units_per_case": 12,
                "price": Decimal("20.00"),
                "dealer_transfer_price": Decimal("14.00"),
                "mrp": Decimal("20.00"),
                "stock": 8500,
                "unit": "Bottle",
                "category": "Bottle",
                "category_ref": cat_bottles,
                "shelf_life_days": 180,
                "status": "Active",
                "description": "1 Litre flagship packaged mineral drinking water bottle with advanced multi-stage RO purification.",
            },
            {
                "sku": "SKU-JAR-20L",
                "name": "Shivnath 20 Litre Dispenser Jar",
                "size": "20 Litre",
                "volume_ml": 20000,
                "package_type": "JAR",
                "units_per_case": 1,
                "price": Decimal("60.00"),
                "dealer_transfer_price": Decimal("40.00"),
                "mrp": Decimal("60.00"),
                "stock": 1800,
                "unit": "Jar",
                "category": "Jar",
                "category_ref": cat_jars,
                "shelf_life_days": 30,
                "status": "Active",
                "description": "20 Litre returnable dispenser jar for homes, offices, schools, and hospitals.",
            },
        ]

        created_products = {}
        for pdata in official_products:
            sku = pdata["sku"]
            p, _ = Product.objects.update_or_create(sku=sku, defaults=pdata)
            created_products[sku] = p
            ProductStockThreshold.objects.update_or_create(
                product=p,
                defaults={
                    "company_low_stock_threshold": 500 if "BOT" in sku else 150,
                    "dealer_low_stock_threshold": 50 if "BOT" in sku else 20,
                    "alert_enabled": True,
                }
            )

        # Ensure only the 5 official products are active; deactivate all other variants (2L, 5L, legacy jars, accessories)
        Product.objects.exclude(sku__in=[p["sku"] for p in official_products]).update(status="Inactive")
        return created_products

    def _seed_raw_materials(self):
        self.stdout.write("4. Seeding Realistic Raw Materials Master...")
        raw_materials_data = [
            {
                "sku": "RM-WAT-RAW",
                "name": "Purified Deep RO Mineral Water Input",
                "category": "raw_water",
                "unit_of_measure": "litres",
                "unit_cost": Decimal("0.08"),
                "current_stock": Decimal("95000.00"),
                "reorder_level": Decimal("15000.00"),
            },
            {
                "sku": "RM-PRF-200",
                "name": "200ml Virgin PET Preform (11.5g)",
                "category": "preform",
                "unit_of_measure": "pcs",
                "unit_cost": Decimal("0.90"),
                "current_stock": Decimal("40000.00"),
                "reorder_level": Decimal("8000.00"),
            },
            {
                "sku": "RM-PRF-250",
                "name": "250ml Virgin PET Preform (12.5g)",
                "category": "preform",
                "unit_of_measure": "pcs",
                "unit_cost": Decimal("0.98"),
                "current_stock": Decimal("35000.00"),
                "reorder_level": Decimal("8000.00"),
            },
            {
                "sku": "RM-PRF-500",
                "name": "500ml Virgin PET Preform (18.5g)",
                "category": "preform",
                "unit_of_measure": "pcs",
                "unit_cost": Decimal("1.35"),
                "current_stock": Decimal("50000.00"),
                "reorder_level": Decimal("10000.00"),
            },
            {
                "sku": "RM-PRF-1000",
                "name": "1000ml Virgin PET Preform (23.5g)",
                "category": "preform",
                "unit_of_measure": "pcs",
                "unit_cost": Decimal("1.80"),
                "current_stock": Decimal("60000.00"),
                "reorder_level": Decimal("12000.00"),
            },
            {
                "sku": "RM-CAP-28MM",
                "name": "28mm Tamper-Evident HDPE Screw Cap",
                "category": "cap",
                "unit_of_measure": "pcs",
                "unit_cost": Decimal("0.35"),
                "current_stock": Decimal("150000.00"),
                "reorder_level": Decimal("25000.00"),
            },
            {
                "sku": "RM-CAP-55MM",
                "name": "55mm Non-Spill Dispenser Jar Cap with Seal",
                "category": "cap",
                "unit_of_measure": "pcs",
                "unit_cost": Decimal("2.40"),
                "current_stock": Decimal("18000.00"),
                "reorder_level": Decimal("3500.00"),
            },
            {
                "sku": "RM-LBL-200",
                "name": "200ml Metallized BOPP Wrap-Around Label",
                "category": "label",
                "unit_of_measure": "pcs",
                "unit_cost": Decimal("0.22"),
                "current_stock": Decimal("45000.00"),
                "reorder_level": Decimal("10000.00"),
            },
            {
                "sku": "RM-LBL-250",
                "name": "250ml Metallized BOPP Wrap-Around Label",
                "category": "label",
                "unit_of_measure": "pcs",
                "unit_cost": Decimal("0.25"),
                "current_stock": Decimal("40000.00"),
                "reorder_level": Decimal("10000.00"),
            },
            {
                "sku": "RM-LBL-500",
                "name": "500ml Metallized BOPP Wrap-Around Label",
                "category": "label",
                "unit_of_measure": "pcs",
                "unit_cost": Decimal("0.30"),
                "current_stock": Decimal("55000.00"),
                "reorder_level": Decimal("10000.00"),
            },
            {
                "sku": "RM-LBL-1000",
                "name": "1000ml Metallized BOPP Wrap-Around Label",
                "category": "label",
                "unit_of_measure": "pcs",
                "unit_cost": Decimal("0.38"),
                "current_stock": Decimal("65000.00"),
                "reorder_level": Decimal("12000.00"),
            },
            {
                "sku": "RM-LBL-JAR",
                "name": "20L Jar Screen Printed Shrink Sleeve",
                "category": "label",
                "unit_of_measure": "pcs",
                "unit_cost": Decimal("1.10"),
                "current_stock": Decimal("15000.00"),
                "reorder_level": Decimal("3000.00"),
            },
            {
                "sku": "RM-PKG-STR",
                "name": "Heavy Duty Packaging Shrink Film Roll",
                "category": "packaging",
                "unit_of_measure": "kg",
                "unit_cost": Decimal("125.00"),
                "current_stock": Decimal("1200.00"),
                "reorder_level": Decimal("200.00"),
            },
            {
                "sku": "RM-BOX-24",
                "name": "Corrugated Outer Shipper Box (24 Bottles)",
                "category": "packaging",
                "unit_of_measure": "boxes",
                "unit_cost": Decimal("14.50"),
                "current_stock": Decimal("4000.00"),
                "reorder_level": Decimal("800.00"),
            },
            {
                "sku": "RM-BOX-12",
                "name": "Corrugated Outer Shipper Box (12 Bottles)",
                "category": "packaging",
                "unit_of_measure": "boxes",
                "unit_cost": Decimal("11.00"),
                "current_stock": Decimal("3500.00"),
                "reorder_level": Decimal("600.00"),
            },
            # LOW STOCK ALERT DEMONSTRATION ITEM:
            {
                "sku": "RM-JAR-20L-POLY",
                "name": "20L Virgin Polycarbonate Commercial Jar Body",
                "category": "packaging",
                "unit_of_measure": "pcs",
                "unit_cost": Decimal("145.00"),
                "current_stock": Decimal("85.00"),  # Below reorder level!
                "reorder_level": Decimal("250.00"),
            },
        ]

        rms = {}
        for rdata in raw_materials_data:
            sku = rdata["sku"]
            rm, _ = RawMaterial.objects.update_or_create(sku=sku, defaults=rdata)
            rms[sku] = rm
        return rms

    def _seed_suppliers(self, raw_materials, admins):
        self.stdout.write("5. Seeding Raw Material Suppliers & Purchase Orders...")
        super_admin = admins.get("super_admin")
        suppliers_spec = [
            ("SUP-PRE-001", "Crystal Polymers Ltd.", "Rajesh Goyal", "9893011001", "sales@crystalpolymers.com", "Preforms", "22AAACR1234F1Z1", "Raipur", 15),
            ("SUP-CAP-002", "Apex Closures & Caps Pvt Ltd", "Vikram Mehta", "9893011002", "contact@apexclosures.in", "Caps", "23AAACP5678G1Z2", "Indore", 30),
            ("SUP-LBL-003", "Shivam Flexipack & Print Systems", "Anil Jain", "9893011003", "orders@shivamflexipack.com", "Labels", "27AAACS9012H1Z3", "Nagpur", 15),
            ("SUP-BOX-004", "Chhattisgarh Corrugated Containers", "Manoj Agarwal", "9893011004", "info@cgcontainers.com", "Packaging", "22AAACC3456J1Z4", "Bhilai", 21),
            ("SUP-JAR-005", "National Jar Molding Corp", "Suresh Patel", "9893011005", "suresh@nationaljarmolding.com", "20L Jars", "24AAACN7890K1Z5", "Ahmedabad", 30),
        ]

        suppliers = {}
        for code, name, contact, phone, email, cat, gst, city, terms in suppliers_spec:
            sup, _ = Supplier.objects.update_or_create(
                phone=phone,
                defaults={
                    "supplier_code": code,
                    "name": name,
                    "contact": contact,
                    "email": email,
                    "category": cat,
                    "gst": gst,
                    "city": city,
                    "payment_terms_days": terms,
                    "status": "Active",
                }
            )
            suppliers[code] = sup

        # Seed Purchase Orders for Suppliers
        po_spec = [
            ("PO-DEMO-001", suppliers["SUP-PRE-001"], raw_materials.get("RM-PRF-500"), 20000, Decimal("1.35"), "RECEIVED"),
            ("PO-DEMO-002", suppliers["SUP-CAP-002"], raw_materials.get("RM-CAP-28MM"), 50000, Decimal("0.35"), "RECEIVED"),
            ("PO-DEMO-003", suppliers["SUP-LBL-003"], raw_materials.get("RM-LBL-500"), 30000, Decimal("0.30"), "ORDERED"),
            ("PO-DEMO-004", suppliers["SUP-JAR-005"], raw_materials.get("RM-JAR-20L-POLY"), 500, Decimal("145.00"), "DRAFT"),
        ]

        for po_num, sup, rm, qty, unit_price, status_val in po_spec:
            subtotal = Decimal(qty) * unit_price
            tax = (subtotal * Decimal("0.18")).quantize(Decimal("0.01"))
            grand_total = subtotal + tax
            po, _ = PurchaseOrder.objects.update_or_create(
                po_number=po_num,
                defaults={
                    "supplier": sup,
                    "total_amount": subtotal,
                    "tax_amount": tax,
                    "grand_total": grand_total,
                    "status": status_val,
                    "created_by": super_admin,
                    "notes": f"Standard procurement run {po_num} for plant inventory replenishment.",
                }
            )
            if rm:
                PurchaseOrderItem.objects.update_or_create(
                    purchase_order=po,
                    raw_material=rm,
                    defaults={
                        "quantity": qty,
                        "unit_price": unit_price,
                        "total_price": subtotal,
                        "received_quantity": qty if status_val == "RECEIVED" else 0,
                    }
                )

        return suppliers

    def _seed_boms(self, products, raw_materials):
        self.stdout.write("6. Seeding Product BOM Recipes (Bill of Materials)...")
        recipes = {
            "SKU-BOT-200": [
                ("RM-WAT-RAW", Decimal("0.2000"), Decimal("0.08"), "Processed RO Water 200ml"),
                ("RM-PRF-200", Decimal("1.0000"), Decimal("0.90"), "PET Preform 200ml"),
                ("RM-CAP-28MM", Decimal("1.0000"), Decimal("0.35"), "Bottle Cap 28mm"),
                ("RM-LBL-200", Decimal("1.0000"), Decimal("0.22"), "Label 200ml"),
                ("RM-BOX-24", Decimal("0.0417"), Decimal("14.50"), "Outer Box Packaging (1/24)"),
            ],
            "SKU-BOT-250": [
                ("RM-WAT-RAW", Decimal("0.2500"), Decimal("0.08"), "Processed RO Water 250ml"),
                ("RM-PRF-250", Decimal("1.0000"), Decimal("0.98"), "PET Preform 250ml"),
                ("RM-CAP-28MM", Decimal("1.0000"), Decimal("0.35"), "Bottle Cap 28mm"),
                ("RM-LBL-250", Decimal("1.0000"), Decimal("0.25"), "Label 250ml"),
                ("RM-BOX-24", Decimal("0.0417"), Decimal("14.50"), "Outer Box Packaging (1/24)"),
            ],
            "SKU-BOT-500": [
                ("RM-WAT-RAW", Decimal("0.5000"), Decimal("0.08"), "Processed RO Water 500ml"),
                ("RM-PRF-500", Decimal("1.0000"), Decimal("1.35"), "PET Preform 500ml"),
                ("RM-CAP-28MM", Decimal("1.0000"), Decimal("0.35"), "Bottle Cap 28mm"),
                ("RM-LBL-500", Decimal("1.0000"), Decimal("0.30"), "Label 500ml"),
                ("RM-BOX-24", Decimal("0.0417"), Decimal("14.50"), "Outer Box Packaging (1/24)"),
            ],
            "SKU-BOT-1000": [
                ("RM-WAT-RAW", Decimal("1.0000"), Decimal("0.08"), "Processed RO Water 1L"),
                ("RM-PRF-1000", Decimal("1.0000"), Decimal("1.80"), "PET Preform 1000ml"),
                ("RM-CAP-28MM", Decimal("1.0000"), Decimal("0.35"), "Bottle Cap 28mm"),
                ("RM-LBL-1000", Decimal("1.0000"), Decimal("0.38"), "Label 1000ml"),
                ("RM-BOX-12", Decimal("0.0833"), Decimal("11.00"), "Outer Box Packaging (1/12)"),
            ],
            "SKU-JAR-20L": [
                ("RM-WAT-RAW", Decimal("20.0000"), Decimal("0.08"), "Processed RO Water 20L"),
                ("RM-CAP-55MM", Decimal("1.0000"), Decimal("2.40"), "Non-spill Jar Cap 55mm"),
                ("RM-LBL-JAR", Decimal("1.0000"), Decimal("1.10"), "Jar Seal & Neck Label"),
            ],
        }

        for sku, items in recipes.items():
            product = products.get(sku)
            if not product:
                continue
            bom, _ = ProductionRecipeBOM.objects.get_or_create(
                product=product,
                defaults={"notes": f"Authoritative Production BOM Recipe for {product.name}"}
            )
            # Recreate items cleanly
            bom.items.all().delete()
            for rm_sku, qty_per_unit, cost_snap, notes in items:
                rm = raw_materials.get(rm_sku)
                if not rm:
                    continue
                ProductionRecipeBOMItem.objects.create(
                    bom=bom,
                    raw_material=rm,
                    quantity_required_per_unit=qty_per_unit,
                    unit_cost_snapshot=cost_snap,
                    notes=notes,
                )

    def _seed_dealers(self):
        self.stdout.write("7. Seeding Separate Demo Wholesale Dealers (Preserving user-created accounts)...")
        dealers_spec = [
            {
                "username": "demo_dealer_raipur@shivnath.local",
                "email": "demo_dealer_raipur@shivnath.local",
                "name": "Maa Durga Distributors",
                "contact_name": "Rakesh Agrawal",
                "phone": "9876543001",
                "dealer_code": "DLR-DEMO-01",
                "city": "Raipur",
                "territory": "Raipur Central",
                "credit_limit": Decimal("250000.00"),
                "outstanding": Decimal("42500.00"),
                "terms_days": 15,
                "status": "approved",
            },
            {
                "username": "demo_dealer_bilaspur@shivnath.local",
                "email": "demo_dealer_bilaspur@shivnath.local",
                "name": "Shiv Shakti Beverages",
                "contact_name": "Santosh Tiwari",
                "phone": "9876543002",
                "dealer_code": "DLR-DEMO-02",
                "city": "Bilaspur",
                "territory": "Bilaspur East",
                "credit_limit": Decimal("180000.00"),
                "outstanding": Decimal("78000.00"),
                "terms_days": 30,
                "status": "approved",
            },
            {
                "username": "demo_dealer_durg@shivnath.local",
                "email": "demo_dealer_durg@shivnath.local",
                "name": "Chhattisgarh Pure Water Co.",
                "contact_name": "Vikas Sahu",
                "phone": "9876543003",
                "dealer_code": "DLR-DEMO-03",
                "city": "Durg",
                "territory": "Durg-Bhilai Commercial",
                "credit_limit": Decimal("120000.00"),
                "outstanding": Decimal("15000.00"),
                "terms_days": 7,
                "status": "approved",
            },
            {
                "username": "demo_dealer_rajnandgaon@shivnath.local",
                "email": "demo_dealer_rajnandgaon@shivnath.local",
                "name": "Royal Oasis Wholesale Depot",
                "contact_name": "Harish Baghel",
                "phone": "9876543004",
                "dealer_code": "DLR-DEMO-04",
                "city": "Rajnandgaon",
                "territory": "Rajnandgaon Central",
                "credit_limit": Decimal("100000.00"),
                "outstanding": Decimal("0.00"),
                "terms_days": 15,
                "status": "under_review",  # Demonstrating pending review state
            },
            {
                "username": "demo_dealer_korba@shivnath.local",
                "email": "demo_dealer_korba@shivnath.local",
                "name": "Korba Industrial Refreshments",
                "contact_name": "Nitin Dewangan",
                "phone": "9876543005",
                "dealer_code": "DLR-DEMO-05",
                "city": "Korba",
                "territory": "Korba Industrial Power Hub",
                "credit_limit": Decimal("50000.00"),
                "outstanding": Decimal("48000.00"),
                "terms_days": 7,
                "status": "suspended",  # Demonstrating suspended state
            },
        ]

        pwd_hash = make_password("DemoDealer@2026!")
        dealers = []

        for d in dealers_spec:
            u, _ = User.objects.get_or_create(
                username=d["username"],
                defaults={
                    "email": d["email"],
                    "first_name": d["contact_name"],
                    "password": pwd_hash,
                    "is_active": True,
                }
            )
            prof, _ = UserProfile.objects.get_or_create(user=u)
            prof.name = d["contact_name"]
            prof.phone = d["phone"]
            prof.role = "franchise"
            prof.city = d["city"]
            prof.territory = d["territory"]
            prof.status = "active" if d["status"] != "suspended" else "inactive"
            prof.save()

            f_prof, _ = FranchiseProfile.objects.update_or_create(
                user=u,
                defaults={
                    "dealer_code": d["dealer_code"],
                    "business_name": d["name"],
                    "city": d["city"],
                    "address": f"Plot {d['dealer_code']}, Industrial Estate, {d['city']}",
                    "territory": d["territory"],
                    "assigned_territories": [d["territory"]],
                    "status": d["status"],
                    "security_deposit": Decimal("50000.00"),
                    "commission": Decimal("15.00"),
                }
            )

            DealerCreditProfile.objects.update_or_create(
                dealer=f_prof,
                defaults={
                    "credit_limit": d["credit_limit"],
                    "current_outstanding": d["outstanding"],
                    "payment_terms_days": d["terms_days"],
                    "credit_status": "GOOD_STANDING" if d["outstanding"] < d["credit_limit"] else "PAYMENT_DUE",
                }
            )

            # Add Demo KYC Document for Dealer
            DealerDocument.objects.update_or_create(
                dealer=f_prof,
                document_type="GST",
                defaults={
                    "document_number": f"22AABCA{1000 + f_prof.id}F1Z0",
                    "verification_status": "VERIFIED" if d["status"] == "approved" else "PENDING",
                }
            )
            dealers.append(f_prof)

        return dealers

    def _seed_customers(self):
        self.stdout.write("8. Seeding Separate Demo Customers (Preserving user-created accounts)...")
        cust_spec = [
            {"username": "demo_cust_anand@shivnath.local", "name": "Anand Verma", "phone": "9876543010", "city": "Raipur", "territory": "Raipur Central"},
            {"username": "demo_cust_sneha@shivnath.local", "name": "Sneha Patel", "phone": "9876543011", "city": "Bilaspur", "territory": "Bilaspur East"},
            {"username": "demo_cust_rahul@shivnath.local", "name": "Rahul Dewangan", "phone": "9876543012", "city": "Durg", "territory": "Durg-Bhilai Commercial"},
            {"username": "demo_cust_hotel@shivnath.local", "name": "Hotel Grand Chhattisgarh", "phone": "9876543013", "city": "Raipur", "territory": "Raipur Central"},
            {"username": "demo_cust_cafe@shivnath.local", "name": "Chai & Conversations Cafe", "phone": "9876543014", "city": "Bilaspur", "territory": "Bilaspur City"},
            {"username": "demo_cust_hospital@shivnath.local", "name": "Sanjeevani Super Specialty Hospital", "phone": "9876543015", "city": "Raipur", "territory": "Raipur Industrial"},
        ]
        pwd_hash = make_password("DemoCust@2026!")
        customers = []
        for c in cust_spec:
            u, _ = User.objects.get_or_create(
                username=c["username"],
                defaults={
                    "email": c["username"],
                    "first_name": c["name"],
                    "password": pwd_hash,
                    "is_active": True,
                }
            )
            prof, _ = UserProfile.objects.get_or_create(user=u)
            prof.name = c["name"]
            prof.phone = c["phone"]
            prof.role = "customer"
            prof.city = c["city"]
            prof.territory = c["territory"]
            prof.status = "active"
            prof.save()
            customers.append(u)
        return customers

    def _seed_production_batches(self, products):
        self.stdout.write("9. Seeding Production Batches (Including Approaching Expiry)...")
        today = timezone.now().date()

        batches_spec = [
            {
                "batch_number": "PB-DEMO-500-01",
                "product_sku": "SKU-BOT-500",
                "mfg_date": today - datetime.timedelta(days=15),
                "exp_date": today + datetime.timedelta(days=165),
                "produced": 10000,
                "remaining": 8500,
                "reserved": 500,
                "cost": Decimal("2.65"),
                "status": "ACTIVE",
            },
            {
                "batch_number": "PB-DEMO-1000-01",
                "product_sku": "SKU-BOT-1000",
                "mfg_date": today - datetime.timedelta(days=10),
                "exp_date": today + datetime.timedelta(days=170),
                "produced": 12000,
                "remaining": 9200,
                "reserved": 800,
                "cost": Decimal("3.20"),
                "status": "ACTIVE",
            },
            {
                "batch_number": "PB-DEMO-200-01",
                "product_sku": "SKU-BOT-200",
                "mfg_date": today - datetime.timedelta(days=5),
                "exp_date": today + datetime.timedelta(days=175),
                "produced": 8000,
                "remaining": 7000,
                "reserved": 0,
                "cost": Decimal("2.10"),
                "status": "ACTIVE",
            },
            {
                "batch_number": "PB-DEMO-JAR-01",
                "product_sku": "SKU-JAR-20L",
                "mfg_date": today - datetime.timedelta(days=3),
                "exp_date": today + datetime.timedelta(days=27),
                "produced": 2500,
                "remaining": 1600,
                "reserved": 200,
                "cost": Decimal("5.10"),
                "status": "ACTIVE",
            },
            # FULLY DEPLETED BATCH DEMO:
            {
                "batch_number": "PB-DEMO-500-DEP",
                "product_sku": "SKU-BOT-500",
                "mfg_date": today - datetime.timedelta(days=60),
                "exp_date": today + datetime.timedelta(days=120),
                "produced": 5000,
                "remaining": 0,
                "reserved": 0,
                "cost": Decimal("2.60"),
                "status": "DEPLETED",
            },
            # CRITICAL EXPIRY ALERT BATCH (B-DEMO-EXPIRY-001 & B-DEMO-001):
            # Produced: 5,000, Cleared/Sold: 2,000, Pending: 3,000, Expiry: 45 days (1.5 Months)
            {
                "batch_number": "B-DEMO-EXPIRY-001",
                "product_sku": "SKU-BOT-500",
                "mfg_date": today - datetime.timedelta(days=135),
                "exp_date": today + datetime.timedelta(days=45),  # 45 days remaining (1.5 months)
                "produced": 5000,
                "remaining": 3000,
                "reserved": 3000,
                "cost": Decimal("2.60"),
                "status": "ACTIVE",
            },
            {
                "batch_number": "B-DEMO-001",
                "product_sku": "SKU-BOT-500",
                "mfg_date": today - datetime.timedelta(days=135),
                "exp_date": today + datetime.timedelta(days=45),
                "produced": 5000,
                "remaining": 3000,
                "reserved": 3000,
                "cost": Decimal("2.60"),
                "status": "ACTIVE",
            },
        ]

        created_batches = {}
        for b in batches_spec:
            p = products.get(b["product_sku"])
            if not p:
                continue
            batch, _ = ProductionBatch.objects.update_or_create(
                batch_number=b["batch_number"],
                defaults={
                    "product": p,
                    "manufacture_date": b["mfg_date"],
                    "expiry_date": b["exp_date"],
                    "quantity_produced_units": b["produced"],
                    "quantity_remaining_company": b["remaining"],
                    "reserved_quantity": b["reserved"],
                    "unit_production_cost": b["cost"],
                    "status": b["status"],
                }
            )
            created_batches[b["batch_number"]] = batch

        return created_batches

    def _seed_dealer_batches(self, dealers, products, batches):
        self.stdout.write("10. Seeding Dealer Warehouse Stock Batches...")
        today = timezone.now().date()
        if not dealers:
            return
        d1 = dealers[0]
        d2 = dealers[1] if len(dealers) > 1 else d1
        p_500 = products.get("SKU-BOT-500")
        p_1000 = products.get("SKU-BOT-1000")
        p_jar = products.get("SKU-JAR-20L")

        dealer_batches = [
            (d1, p_500, "DLR-B-500-01", 12, 168, 2400, 1800, 200, 400, 0, 0),
            (d1, p_1000, "DLR-B-1000-01", 8, 172, 1200, 900, 100, 200, 0, 0),
            (d1, p_jar, "DLR-B-JAR-01", 4, 26, 500, 380, 50, 60, 10, 0),
            (d2, p_500, "DLR-B-500-02", 10, 170, 1500, 1100, 100, 300, 0, 0),
            (d2, p_1000, "DLR-B-1000-02", 6, 174, 1000, 800, 50, 150, 0, 0),
        ]

        for dlr, prod, b_num, mfg_offset, exp_offset, rec_q, rem_q, res_q, sold_q, ret_q, dmg_q in dealer_batches:
            if not prod:
                continue
            DealerStockBatch.objects.update_or_create(
                dealer=dlr,
                batch_number=b_num,
                defaults={
                    "product": prod,
                    "manufacture_date": today - datetime.timedelta(days=mfg_offset),
                    "expiry_date": today + datetime.timedelta(days=exp_offset),
                    "received_quantity": rec_q,
                    "remaining_quantity": rem_q,
                    "reserved_quantity": res_q,
                    "damaged_quantity": dmg_q,
                    "unit_transfer_price": prod.dealer_transfer_price,
                    "is_active": True,
                }
            )

    def _seed_orders(self, products, dealers, customers, batches):
        self.stdout.write("11. Seeding Orders Across All 7 Statuses & Direct Company Orders...")
        now = timezone.now()
        d_raipur = dealers[0] if dealers else None
        d_bilaspur = dealers[1] if len(dealers) > 1 else d_raipur
        p_500 = products.get("SKU-BOT-500")
        p_1000 = products.get("SKU-BOT-1000")
        p_jar = products.get("SKU-JAR-20L")
        p_200 = products.get("SKU-BOT-200")
        exp_batch = batches.get("B-DEMO-EXPIRY-001") or batches.get("B-DEMO-001")

        orders_spec = [
            # 1. New Order Placement
            (1001, "order_placement", customers[0], d_raipur, "FRANCHISE", Decimal("2400.00"), p_500, 240, now - datetime.timedelta(hours=2), "Initial customer order placement via mobile app."),
            # 2. Plant Approval
            (1002, "plant_approval", customers[1], d_bilaspur, "FRANCHISE", Decimal("4800.00"), p_1000, 240, now - datetime.timedelta(hours=6), "Awaiting central plant dispatch schedule."),
            # 3. Invoice Generated
            (1003, "invoice_generated", customers[2], d_raipur, "FRANCHISE", Decimal("1800.00"), p_jar, 30, now - datetime.timedelta(days=1), "Tax invoice SHV/2026/003 generated."),
            # 4. Preparing / Packaging (Direct Company Order)
            (1004, "preparing", customers[3], None, "DIRECT_COMPANY", Decimal("7200.00"), p_500, 720, now - datetime.timedelta(days=1), "Direct bulk corporate order being bottled."),
            # 5. Out for Dispatch
            (1005, "dispatch", customers[4] if len(customers) > 4 else customers[0], d_bilaspur, "FRANCHISE", Decimal("3600.00"), p_1000, 180, now - datetime.timedelta(hours=4), "Loaded on delivery vehicle CG-04-E-1234."),
            # 6. Delivered Today
            (1006, "delivered", customers[0], d_raipur, "FRANCHISE", Decimal("5400.00"), p_500, 540, now - datetime.timedelta(hours=1), "Customer signature & OTP verification confirmed."),
            # 7. Cancelled Order
            (1007, "cancelled", customers[1], d_raipur, "FRANCHISE", Decimal("1200.00"), p_jar, 20, now - datetime.timedelta(days=2), "Cancelled per customer request: duplicate booking."),
            # 8. Delivered 7 Days Ago (historical reporting)
            (1008, "delivered", customers[2], d_raipur, "FRANCHISE", Decimal("8400.00"), p_1000, 420, now - datetime.timedelta(days=7), "Delivered last week."),
            # 9. Delivered 14 Days Ago (historical reporting)
            (1009, "delivered", customers[3], d_bilaspur, "FRANCHISE", Decimal("12000.00"), p_500, 1200, now - datetime.timedelta(days=14), "Delivered two weeks ago."),
            # 10. Delivered 25 Days Ago (historical reporting)
            (1010, "delivered", customers[0], None, "DIRECT_COMPANY", Decimal("15000.00"), p_jar, 250, now - datetime.timedelta(days=25), "Delivered last month."),
        ]

        created_orders = {}
        for order_id, status_val, cust_user, dealer_inst, source_val, amt, prod, qty, order_time, notes in orders_spec:
            order, _ = Order.objects.update_or_create(
                id=order_id,
                defaults={
                    "created_by": cust_user,
                    "franchise_name": dealer_inst.business_name if dealer_inst else "Shivnath Central Plant",
                    "serving_franchise": dealer_inst,
                    "city": cust_user.profile.city if hasattr(cust_user, 'profile') and cust_user.profile.city else "Raipur",
                    "territory": cust_user.profile.territory if hasattr(cust_user, 'profile') and cust_user.profile.territory else "Raipur Central",
                    "amount": amt,
                    "grand_total": (amt * Decimal("1.18")).quantize(Decimal("0.01")),
                    "status": status_val,
                    "payment_status": "paid" if status_val == "delivered" else ("cancelled" if status_val == "cancelled" else "pending"),
                    "order_source": source_val,
                    "items_count": 1,
                    "delivered_at": now - datetime.timedelta(hours=1) if status_val == "delivered" else None,
                }
            )
            item, _ = OrderItem.objects.update_or_create(
                order=order,
                product=prod,
                defaults={
                    "product_name": prod.name if prod else "Drinking Water",
                    "quantity": qty,
                    "unit_price": prod.price if prod else Decimal("10.00"),
                    "total_price": amt,
                }
            )

            # Seed explicit OrderStatusHistory transitions
            if status_val == "delivered":
                dealer = serving_franchise or (dealers[0] if dealers else None)
                dealer_user = dealer.user if dealer and hasattr(dealer, 'user') and dealer.user else None
                dealer_name = dealer.business_name if dealer else "Shivnath Central Plant"
                cust_disp = cust_user.get_full_name() or cust_user.username

                steps = [
                    ("order_placement", f"Order placed by client {cust_disp}", cust_user, now - datetime.timedelta(days=1, hours=4)),
                    ("plant_approval", "Plant approval confirmed by Shivnath Central Admin", admin_user, now - datetime.timedelta(days=1, hours=2)),
                    ("invoice_generated", f"Tax invoice generated by {dealer_name}", dealer_user or admin_user, now - datetime.timedelta(hours=18)),
                    ("preparing", f"Bottles packaged and staged at {dealer_name}", dealer_user or admin_user, now - datetime.timedelta(hours=8)),
                    ("dispatch", f"Dispatched on delivery vehicle by {dealer_name}", dealer_user or admin_user, now - datetime.timedelta(hours=3)),
                    ("delivered", f"Successfully delivered to {cust_disp} by {dealer_name}", dealer_user or admin_user, now - datetime.timedelta(hours=1)),
                ]
                old_st = ""
                for new_st, step_note, step_actor, step_time in steps:
                    hist, _ = OrderStatusHistory.objects.get_or_create(
                        order=order,
                        old_status=old_st,
                        new_status=new_st,
                        defaults={
                            "changed_by": step_actor,
                            "notes": step_note,
                        }
                    )
                    old_st = new_st
            elif status_val == "cancelled":
                cust_disp = cust_user.get_full_name() or cust_user.username
                OrderStatusHistory.objects.get_or_create(
                    order=order,
                    old_status="order_placement",
                    new_status="cancelled",
                    defaults={"changed_by": cust_user, "notes": f"Order cancelled by client {cust_disp}"}
                )

            created_orders[order_id] = order

        # 11.2 CRITICAL EXPIRY ALERT ORDER: ORD-DEMO-1025 linked to B-DEMO-EXPIRY-001
        cust_hotel = customers[3] if len(customers) > 3 else customers[0]
        expiry_order, _ = Order.objects.update_or_create(
            id=1025,
            defaults={
                "created_by": cust_hotel,
                "franchise_name": d_raipur.business_name if d_raipur else "Shivnath Central Plant",
                "serving_franchise": d_raipur,
                "city": "Raipur",
                "territory": "Raipur Central",
                "amount": Decimal("30000.00"),
                "grand_total": Decimal("35400.00"),
                "status": "plant_approval",
                "payment_status": "partial",
                "order_source": "DIRECT_COMPANY",
                "items_count": 1,
            }
        )
        exp_item, _ = OrderItem.objects.update_or_create(
            order=expiry_order,
            product=p_500,
            defaults={
                "product_name": p_500.name if p_500 else "Shivnath 500ml Bottle",
                "quantity": 5000,
                "unit_price": Decimal("6.00"),
                "total_price": Decimal("30000.00"),
            }
        )
        if exp_batch:
            OrderItemBatchReservation.objects.update_or_create(
                order_item=exp_item,
                production_batch=exp_batch,
                defaults={
                    "reserved_quantity": 5000,
                    "consumed_quantity": 2000,  # 3000 pending!
                    "released_quantity": 0,
                }
            )
            # Log in ExpiryAlertLog table
            dedup_hash = ExpiryAlertLog.compute_hash('COMPANY', exp_batch.id, 'WARNING')
            ExpiryAlertLog.objects.update_or_create(
                deduplication_hash=dedup_hash,
                defaults={
                    "batch_type": "COMPANY",
                    "production_batch": exp_batch,
                    "alert_level": "WARNING",
                    "alert_date": now.date(),
                }
            )
        created_orders[1025] = expiry_order

        return created_orders

    def _seed_stock_requests(self, dealers, products, batches):
        self.stdout.write("12. Seeding Dealer Stock Requests Across Full Lifecycle...")
        if not dealers:
            return
        d1 = dealers[0]
        d2 = dealers[1] if len(dealers) > 1 else d1
        p_500 = products.get("SKU-BOT-500")
        p_1000 = products.get("SKU-BOT-1000")
        p_jar = products.get("SKU-JAR-20L")
        pb_500 = batches.get("PB-DEMO-500-01")

        reqs = [
            ("DSR-DEMO-001", d1, p_500, 2400, 0, 0, 0, 0, "REQUESTED"),
            ("DSR-DEMO-002", d2, p_1000, 1200, 1200, 0, 0, 0, "APPROVED"),
            # PARTIAL ALLOCATION & FULFILLMENT EXAMPLE
            ("DSR-DEMO-003", d1, p_500, 3000, 3000, 1500, 1500, 1500, "PARTIALLY_FULFILLED"),
            ("DSR-DEMO-004", d2, p_500, 1200, 1200, 1200, 0, 0, "PREPARED"),
            ("DSR-DEMO-005", d1, p_jar, 200, 200, 200, 200, 0, "DISPATCHED"),
            ("DSR-DEMO-006", d2, p_1000, 2400, 2400, 2400, 2400, 2400, "RECEIVED"),
        ]

        for num, dlr, prod, req_q, app_q, prep_q, disp_q, rec_q, st in reqs:
            sr, _ = DealerStockRequest.objects.update_or_create(
                request_number=num,
                defaults={
                    "dealer": dlr,
                    "product": prod,
                    "requested_quantity": req_q,
                    "approved_quantity": app_q,
                    "prepared_quantity": prep_q,
                    "dispatched_quantity": disp_q,
                    "received_quantity": rec_q,
                    "status": st,
                    "dealer_notes": f"Standard wholesale stock replenishment {num}",
                    "admin_notes": "Reviewed and scheduled per plant production schedule.",
                }
            )
            if app_q > 0 and pb_500 and prod == p_500:
                DealerStockRequestAllocation.objects.update_or_create(
                    stock_request=sr,
                    production_batch=pb_500,
                    defaults={
                        "allocated_quantity": app_q,
                        "prepared_quantity": prep_q,
                        "dispatched_quantity": disp_q,
                        "received_quantity": rec_q,
                    }
                )

    def _seed_inventory_ledger(self, products, raw_materials, dealers, batches):
        self.stdout.write("13. Seeding Authoritative Inventory Transaction Ledger (All 10 Types)...")
        p_500 = products.get("SKU-BOT-500")
        p_jar = products.get("SKU-JAR-20L")
        rm_prf = raw_materials.get("RM-PRF-500")
        d1 = dealers[0] if dealers else None
        pb_500 = batches.get("PB-DEMO-500-01")

        InventoryTransactionLedger.objects.filter(reference_id__startswith="DEMO-").delete()

        ledger_entries = [
            ("PURCHASE_IN", "RAW_MATERIAL", "COMPANY_WAREHOUSE", None, None, rm_prf, Decimal("50000.00"), Decimal("50000.00"), Decimal("1.35"), "PURCHASE_ORDER", "DEMO-PO-001", "Raw material preform delivery received from supplier"),
            ("PRODUCTION_CONSUMPTION", "RAW_MATERIAL", "COMPANY_WAREHOUSE", None, None, rm_prf, Decimal("-10000.00"), Decimal("40000.00"), Decimal("1.35"), "PRODUCTION_BATCH", "DEMO-PB-500", "Consumed in bottling production run"),
            ("PRODUCTION_IN", "FINISHED_GOODS", "COMPANY_WAREHOUSE", None, p_500, None, Decimal("10000.00"), Decimal("10000.00"), Decimal("2.65"), "PRODUCTION_BATCH", "DEMO-PB-500", "Manufactured 10,000 bottles 500ml"),
            ("STOCK_TRANSFER_OUT", "FINISHED_GOODS", "COMPANY_WAREHOUSE", d1, p_500, None, Decimal("-2400.00"), Decimal("7600.00"), Decimal("7.00"), "STOCK_REQUEST", "DEMO-DSR-001", "Dispatched to Raipur Wholesale Dealer"),
            ("STOCK_TRANSFER_IN", "FINISHED_GOODS", "DEALER_WAREHOUSE", d1, p_500, None, Decimal("2400.00"), Decimal("2400.00"), Decimal("7.00"), "STOCK_REQUEST", "DEMO-DSR-001", "Received at Raipur Dealer Warehouse"),
            ("SALE", "FINISHED_GOODS", "DEALER_WAREHOUSE", d1, p_500, None, Decimal("-300.00"), Decimal("2100.00"), Decimal("10.00"), "ORDER", "DEMO-ORD-001", "Sold to retail customer Hotel Grand"),
            ("RETURN", "FINISHED_GOODS", "DEALER_WAREHOUSE", d1, p_jar, None, Decimal("25.00"), Decimal("380.00"), Decimal("60.00"), "CUSTOMER_RETURN", "DEMO-RET-001", "Customer empty jars returned and restocked"),
            ("DAMAGE", "FINISHED_GOODS", "COMPANY_WAREHOUSE", None, p_500, None, Decimal("-15.00"), Decimal("7585.00"), Decimal("2.65"), "DAMAGE_LOG", "DEMO-DMG-001", "Transit leakage in plant loading bay"),
            ("EXPIRY", "FINISHED_GOODS", "DEALER_WAREHOUSE", d1, p_jar, None, Decimal("-5.00"), Decimal("375.00"), Decimal("40.00"), "EXPIRY_LOG", "DEMO-EXP-001", "Damaged seal jars safely disposed"),
            ("ADJUSTMENT", "FINISHED_GOODS", "COMPANY_WAREHOUSE", None, p_500, None, Decimal("10.00"), Decimal("7595.00"), Decimal("2.65"), "STOCK_AUDIT", "DEMO-ADJ-001", "Monthly stock physical audit count correction"),
        ]

        for tx_type, mat_type, loc_type, dealer_ref, prod_ref, rm_ref, qty, bal, price, ref_type, ref_id, notes in ledger_entries:
            InventoryTransactionLedger.objects.create(
                transaction_type=tx_type,
                material_type=mat_type,
                location_type=loc_type,
                dealer=dealer_ref,
                product=prod_ref,
                raw_material=rm_ref,
                production_batch=pb_500 if prod_ref else None,
                quantity=qty,
                balance_after=bal,
                unit_cost_or_price=price,
                reference_type=ref_type,
                reference_id=ref_id,
                notes=notes,
            )

    def _seed_billing_and_payments(self, orders, dealers):
        self.stdout.write("14. Seeding Invoices & Payment Transactions...")
        now = timezone.now()
        ord_1006 = orders.get(1006)
        ord_1001 = orders.get(1001)
        ord_1002 = orders.get(1002)

        invoices_spec = [
            ("INV-DEMO-001", ord_1006, "CUSTOMER_SALE_INVOICE", "Anand Verma", Decimal("5400.00"), Decimal("486.00"), Decimal("486.00"), Decimal("6372.00"), Decimal("6372.00"), "PAID"),
            ("INV-DEMO-002", ord_1001, "CUSTOMER_SALE_INVOICE", "Anand Verma", Decimal("2400.00"), Decimal("216.00"), Decimal("216.00"), Decimal("2832.00"), Decimal("0.00"), "UNPAID"),
            ("INV-DEMO-003", None, "DEALER_PURCHASE_INVOICE", "Shiv Shakti Beverages", Decimal("78000.00"), Decimal("7020.00"), Decimal("7020.00"), Decimal("92040.00"), Decimal("40000.00"), "PARTIALLY_PAID"),
            ("INV-DEMO-004", orders.get(1004), "DIRECT_COMPANY_SALE_INVOICE", "Hotel Grand Chhattisgarh", Decimal("7200.00"), Decimal("648.00"), Decimal("648.00"), Decimal("8496.00"), Decimal("8496.00"), "PAID"),
            ("INV-DEMO-005", None, "DEALER_PURCHASE_INVOICE", "Maa Durga Distributors", Decimal("42500.00"), Decimal("3825.00"), Decimal("3825.00"), Decimal("50150.00"), Decimal("0.00"), "UNPAID"),
        ]

        created_invoices = {}
        for inv_num, ord_ref, inv_type, billed_to, sub, cgst, sgst, grand, paid_amt, st in invoices_spec:
            inv, _ = Invoice.objects.update_or_create(
                invoice_number=inv_num,
                defaults={
                    "order": ord_ref,
                    "invoice_type": inv_type,
                    "billed_to_name": billed_to,
                    "billed_to_gstin": "22AABCS9999F1Z9",
                    "billed_to_address": f"Commercial Plaza, {billed_to}, Chhattisgarh",
                    "subtotal": sub,
                    "cgst_amount": cgst,
                    "sgst_amount": sgst,
                    "grand_total": grand,
                    "amount_paid": paid_amt,
                    "status": st,
                    "due_date": (now + datetime.timedelta(days=15)).date(),
                }
            )
            created_invoices[inv_num] = inv

        # Seed Payment Transactions
        payments_spec = [
            ("PAY-DEMO-001", created_invoices["INV-DEMO-001"], "UPI", Decimal("6372.00"), "UPI-REF-98124501", "SUCCESS"),
            ("PAY-DEMO-002", created_invoices["INV-DEMO-003"], "NEFT_RTGS", Decimal("40000.00"), "NEFT-SBIN-29384", "SUCCESS"),
            ("PAY-DEMO-003", created_invoices["INV-DEMO-004"], "UPI", Decimal("8496.00"), "UPI-HDFC-918230", "SUCCESS"),
            ("PAY-DEMO-004", created_invoices["INV-DEMO-005"], "CHEQUE", Decimal("20000.00"), "CHQ-002931", "PENDING"),
        ]

        for p_num, inv_ref, method, amt, ref_id, st in payments_spec:
            PaymentTransaction.objects.update_or_create(
                transaction_number=p_num,
                defaults={
                    "invoice": inv_ref,
                    "payment_method": method,
                    "amount_paid": amt,
                    "reference_number": ref_id,
                    "payment_status": st,
                    "notes": f"Payment receipt for {inv_ref.invoice_number}",
                }
            )

    def _seed_crm_leads_and_activities(self, dealers, admins):
        self.stdout.write("15. Seeding CRM Leads (All 12 Statuses), Follow-ups & Nurturing Journey...")
        today = timezone.now()
        d_raipur = dealers[0] if dealers else None
        sales_rep = admins.get("sales_executive") or admins.get("super_admin")

        leads_data = [
            ("Gupta Kirana & General Store", "NEW", "hot", "HOT", "Ashok Gupta", "9826111111", "Raipur", "Raipur Central", 1),
            ("Shri Ram Beverages & Retail", "CONTACTED", "warm", "WARM", "Ram Prakash", "9826111112", "Bilaspur", "Bilaspur East", 3),
            ("Sunrise Departmental Store", "INTERESTED", "hot", "HOT", "Sunil Verma", "9826111113", "Durg", "Durg-Bhilai Commercial", 5),
            ("Royal Oasis Banquet & Events", "HOT_LEAD", "hot", "HOT", "Harish Agrawal", "9826111114", "Raipur", "Raipur Central", 7),
            ("City Mart Supermarket", "FOLLOW_UP_REQUIRED", "warm", "WARM", "Pankaj Jain", "9826111115", "Bilaspur", "Bilaspur City", 10),
            ("Apex Hospital Food Court", "SITE_VISIT_SCHEDULED", "hot", "HOT", "Dr. Rajesh Sen", "9826111116", "Raipur", "Raipur Central", 15),
            ("Kalinga Beverage Depot", "SITE_VISIT_COMPLETED", "warm", "WARM", "Kailash Patel", "9826111117", "Durg", "Durg-Bhilai Commercial", 2),
            ("New Chhattisgarh Traders", "AGREEMENT_PENDING", "hot", "HOT", "Naresh Goyal", "9826111118", "Raipur", "Raipur Central", 4),
            ("Sai Wholesale Water Hub", "FRANCHISE_CONFIRMED", "hot", "HOT", "Suresh Dewangan", "9826111119", "Bilaspur", "Bilaspur East", 6),
            ("Maa Annapurna Daily Needs", "CONVERTED", "warm", "WARM", "Deepak Sharma", "9826111120", "Durg", "Durg-Bhilai Commercial", 8),
            ("Local Corner Chai Shop", "NOT_INTERESTED", "cold", "COLD", "Gopal Yadav", "9826111121", "Raipur", "Raipur Industrial", 12),
            ("Metro Highway Dhaba", "LOST", "cold", "COLD", "Manoj Shukla", "9826111122", "Bilaspur", "Bilaspur East", 18),
        ]

        for name, st, sc, score_cat, contact_person, phone, city, terr, journey_day in leads_data:
            lead, _ = Lead.objects.update_or_create(
                phone=phone,
                defaults={
                    "name": name,
                    "status": st,
                    "score": sc,
                    "score_category": score_cat,
                    "source": "Inbound Website & App Lead",
                    "city": city,
                    "district": city,
                    "territory": terr,
                    "investment_budget": "20L - 30L" if "Wholesale" in name or "Hub" in name else "2L - 5L",
                    "notes": f"Prospective distributor/retailer {name} in {city}. Journey day: Day {journey_day}.",
                }
            )

            # Seed Follow-ups: Today, Tomorrow, Overdue, and Upcoming
            fu_time = today
            fu_status = "Pending"
            if st in ["CONVERTED", "NOT_INTERESTED", "LOST"]:
                fu_time = today - datetime.timedelta(days=2)
                fu_status = "Completed"
            elif st == "NEW":
                fu_time = today  # Today!
            elif st == "HOT_LEAD":
                fu_time = today + datetime.timedelta(days=1)  # Tomorrow!
            elif st == "FOLLOW_UP_REQUIRED":
                fu_time = today - datetime.timedelta(days=1)  # Overdue!
            else:
                fu_time = today + datetime.timedelta(days=4)  # Upcoming!

            FollowUp.objects.update_or_create(
                lead=lead,
                defaults={
                    "followup_datetime": fu_time,
                    "followup_type": "Phone Call" if journey_day in [1, 5, 10] else "Site Visit",
                    "note": f"Day {journey_day} Nurturing Touchpoint: Discuss pricing, margin terms, and delivery route with {contact_person}",
                    "status": fu_status,
                }
            )

            # Seed Lead Activity Log
            LeadActivity.objects.get_or_create(
                lead=lead,
                activity_type="call" if journey_day < 7 else "visit",
                defaults={
                    "description": f"Field interaction with {contact_person} at {name}.",
                    "performed_by": sales_rep,
                }
            )

            # Seed CRM Activity Log
            CRMActivityLog.objects.get_or_create(
                lead=lead,
                activity_type="STATUS_CHANGED" if journey_day <= 3 else "NOTE_ADDED",
                defaults={
                    "description": f"CRM Audit: Lead {name} is at stage {st} with score {score_cat}. Scheduled Day {journey_day} outreach.",
                }
            )

        # Seed 2 Demo Chatbot Conversations linked to Leads
        from chat.models import ChatSession, ChatMessage
        lead_gupta = Lead.objects.filter(phone="9826111111").first()
        if lead_gupta:
            sess, _ = ChatSession.objects.get_or_create(
                session_id="DEMO-CHAT-GUPTA-01",
                defaults={
                    "customer_name": "Ashok Gupta",
                    "customer_phone": "9826111111",
                    "customer_email": "ashok.gupta@demo.local",
                    "app_type": "customer",
                    "chatbot_mode": "public",
                    "inquiry_type": "customer",
                    "lead": lead_gupta,
                    "lead_capture_completed": True,
                }
            )
            sess.lead = lead_gupta
            sess.save()
            ChatMessage.objects.get_or_create(
                session=sess,
                role="user",
                content="Hi, what is the wholesale rate for 500ml Shivnath packaged water bottles in Raipur?",
            )
            ChatMessage.objects.get_or_create(
                session=sess,
                role="assistant",
                content="Hello Ashok Ji! Welcome to Shivnath Agency. Our 500ml water bottles are ₹6/unit with tiered wholesale margins for retail distributors. Would you like to schedule a delivery?",
            )

        lead_shri_ram = Lead.objects.filter(phone="9826111112").first()
        if lead_shri_ram:
            sess2, _ = ChatSession.objects.get_or_create(
                session_id="DEMO-CHAT-SHRIRAM-02",
                defaults={
                    "customer_name": "Ram Prakash",
                    "customer_phone": "9826111112",
                    "customer_email": "ramprakash@shriram.local",
                    "app_type": "customer",
                    "chatbot_mode": "public",
                    "inquiry_type": "franchise",
                    "lead": lead_shri_ram,
                    "lead_capture_completed": True,
                }
            )
            sess2.lead = lead_shri_ram
            sess2.save()
            ChatMessage.objects.get_or_create(
                session=sess2,
                role="user",
                content="I want to apply for a Shivnath franchise dealership in Bilaspur East territory.",
            )
            ChatMessage.objects.get_or_create(
                session=sess2,
                role="assistant",
                content="Thank you for your interest in partnering with Shivnath Agency! Your franchise inquiry has been logged and our territory manager will coordinate with you.",
            )

    def _seed_notifications(self, dealers, orders):
        self.stdout.write("16. Seeding Admin Notifications & System Alerts...")
        ord_1001 = orders.get(1001)
        notifs = [
            ("New Order Placed: ORD-1001", "New order placed by Anand Verma for 240 units of 500ml Water Bottle.", "order_placed", 1001),
            ("Wholesale Stock Request: DSR-DEMO-001", "M/s Maa Durga Distributors submitted stock replenishment request for 2,400 units.", "stock_alert", 1),
            ("⚠️ High Priority: Low Stock Warning", "Raw Material '20L Virgin Polycarbonate Commercial Jar Body' is at 85 units (Below Reorder Level 250).", "stock_alert", 1),
            ("STOCK EXPIRY ALERT: Batch B-DEMO-EXPIRY-001", "Batch B-DEMO-EXPIRY-001 has 3,000 uncollected units expiring in 7 days. Urgent clearance required.", "stock_alert", 1025),
            ("Payment Received: ₹40,000.00", "Received NEFT transfer from Shiv Shakti Beverages against invoice INV-DEMO-003.", "general", 3),
            ("Outstanding Balance Alert", "Shiv Shakti Beverages has outstanding balance of ₹78,000.00 approaching 30-day payment term.", "general", 2),
            ("New Wholesale Dealer In Review", "Royal Oasis Wholesale Depot applied for dealership in Rajnandgaon. Verification pending.", "franchise_registration", 4),
            ("Follow-up Overdue: City Mart Supermarket", "Follow-up call with Pankaj Jain is overdue since yesterday.", "general", 5),
        ]

        for title, msg, n_type, ref_id in notifs:
            AdminNotification.objects.update_or_create(
                title=title,
                defaults={
                    "message": msg,
                    "notification_type": n_type,
                    "reference_id": ref_id,
                    "is_read": False,
                }
            )

    def _seed_support_contacts(self):
        self.stdout.write("17. Seeding Authoritative DB-backed Support Contacts...")
        contacts = [
            ("public_customer", "Shivnath Customer Care Helpline", "+91 9800001000", "+91 9800001000", "support@shivnathagency.com", "Hello! How can we assist with your drinking water order?", "8:00 AM - 9:00 PM"),
            ("public_franchise", "Wholesale Dealership Inquiries", "+91 9800002000", "+91 9800002000", "dealers@shivnathagency.com", "Interested in becoming an authorized Shivnath drinking water dealer? Connect with our team.", "9:00 AM - 7:00 PM"),
            ("customer", "Shivnath Priority Consumer Desk", "+91 9800003000", "+91 9800003000", "care@shivnathagency.com", "Priority doorstep delivery and dispenser support.", "8:00 AM - 9:00 PM"),
            ("franchise", "Wholesale Partner Operations Desk", "+91 9800004000", "+91 9800004000", "partnerdesk@shivnathagency.com", "Wholesale stock dispatch, credit management, and billing assistance.", "9:00 AM - 8:00 PM"),
            ("admin", "Central Plant IT & Operations Cell", "+91 9800005000", "+91 9800005000", "plantops@shivnathagency.com", "Central plant operations, production server, and logistics control.", "24x7 Operations"),
        ]

        for role_val, name, phone, wa, email, template, hours in contacts:
            SupportContact.objects.update_or_create(
                role=role_val,
                defaults={
                    "name": name,
                    "phone": phone,
                    "whatsapp_number": wa,
                    "email": email,
                    "message_template": template,
                    "available_hours": hours,
                    "is_active": True,
                }
            )

    def _seed_daily_reports_and_expenses(self, admins):
        self.stdout.write("18. Seeding Daily Business P&L Reports & Operational Expenses...")
        today = timezone.now().date()
        super_admin = admins.get("super_admin")

        # Operational Expenses for current month
        expenses_data = [
            ("EXP-DEMO-001", "RAW_MATERIALS", "Procurement of 500ml preforms and caps from Crystal Polymers", Decimal("45000.00"), today - datetime.timedelta(days=12)),
            ("EXP-DEMO-002", "ELECTRICITY_WATER", "Plant electricity bill & deep RO raw borewell power consumption", Decimal("28500.00"), today - datetime.timedelta(days=8)),
            ("EXP-DEMO-003", "LABOUR_SALARY", "Bottling line operators, packaging staff & loader weekly wages", Decimal("35000.00"), today - datetime.timedelta(days=5)),
            ("EXP-DEMO-004", "FUEL_TRANSPORT", "Diesel for 3 logistics delivery trucks covering Raipur & Durg routes", Decimal("18200.00"), today - datetime.timedelta(days=3)),
            ("EXP-DEMO-005", "PACKAGING_LABELS", "Rolls of printed 500ml and 1L metallized BOPP labels", Decimal("14500.00"), today - datetime.timedelta(days=2)),
            ("EXP-DEMO-006", "MAINTENANCE_REPAIRS", "Quarterly replacement of 0.2 micron RO membrane filters and UV lamps", Decimal("12000.00"), today - datetime.timedelta(days=1)),
        ]

        for exp_num, cat, desc, amt, p_date in expenses_data:
            Expense.objects.update_or_create(
                expense_number=exp_num,
                defaults={
                    "category": cat,
                    "description": desc,
                    "amount": amt,
                    "payment_method": "NEFT / Bank",
                    "paid_date": p_date,
                    "recorded_by": super_admin,
                }
            )

        # 14 Days of Daily Business Reports for Rich Charts & Visual Analytics
        for day_offset in range(14, -1, -1):
            r_date = today - datetime.timedelta(days=day_offset)
            base_units = 10000 + (day_offset * 650)
            base_cases = Decimal(base_units // 24)
            prod_cost = Decimal(base_units) * Decimal("2.80")
            dlr_units = int(base_units * 0.75)
            dlr_cases = Decimal(dlr_units // 24)
            dlr_rev = Decimal(dlr_units) * Decimal("7.00")
            dir_rev = Decimal(int(base_units * 0.15)) * Decimal("10.00")
            gross_rev = dlr_rev + dir_rev
            cogs = Decimal(dlr_units + int(base_units * 0.15)) * Decimal("2.80")
            daily_exp = Decimal("4500.00") if day_offset % 3 == 0 else Decimal("2200.00")
            net_prof = gross_rev - cogs - daily_exp

            DailyBusinessReport.objects.update_or_create(
                report_date=r_date,
                defaults={
                    "total_production_volume_units": base_units,
                    "total_production_volume_cases": base_cases,
                    "total_production_cost_inr": prod_cost,
                    "total_dealer_dispatch_units": dlr_units,
                    "total_dealer_dispatch_cases": dlr_cases,
                    "total_dealer_sales_revenue_inr": dlr_rev,
                    "total_direct_company_revenue_inr": dir_rev,
                    "total_gross_revenue_inr": gross_rev,
                    "total_cogs_inr": cogs,
                    "total_expenses_inr": daily_exp,
                    "net_profit_inr": net_prof,
                    "new_leads_count": 3 + (day_offset % 4),
                    "leads_converted_count": 1 if day_offset % 2 == 0 else 0,
                }
            )

    def _seed_audit_logs(self, admins):
        self.stdout.write("19. Seeding Admin Audit Logs & Activity Trail...")
        super_admin = admins.get("super_admin")
        audit_records = [
            ("Created Dealer Account", "FranchiseProfile", "DLR-DEMO-01", {"business_name": "Maa Durga Distributors", "credit_limit": 250000}),
            ("Approved Stock Request", "DealerStockRequest", "DSR-DEMO-002", {"status": "APPROVED", "approved_quantity": 1200}),
            ("Updated Product BOM Recipe", "ProductionRecipeBOM", "SKU-BOT-500", {"action": "Updated raw material recipe ratios"}),
            ("Issued Tax Invoice", "Invoice", "INV-DEMO-001", {"total": 6372.00, "status": "PAID"}),
            ("Adjusted Inventory", "InventoryTransactionLedger", "DEMO-ADJ-001", {"quantity": 10, "notes": "Monthly physical audit count"}),
            ("Generated Daily P&L Report", "DailyBusinessReport", timezone.now().date().isoformat(), {"gross_revenue": "Authoritative P&L calculated"}),
        ]

        for action, res_type, res_id, changes in audit_records:
            AdminAuditLog.objects.get_or_create(
                actor=super_admin,
                action=action,
                resource_type=res_type,
                resource_id=res_id,
                defaults={
                    "ip_address": "127.0.0.1",
                    "changes": changes,
                }
            )

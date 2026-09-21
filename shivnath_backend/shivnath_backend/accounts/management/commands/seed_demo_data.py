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
)
from orders.models import (
    Order,
    OrderItem,
    OrderItemBatchReservation,
    OrderStatusHistory,
)
from billing.models import (
    DealerCreditProfile,
    Invoice,
)
from leads.models import (
    Lead,
)
from followups.models import (
    FollowUp,
)


class Command(BaseCommand):
    help = "Seeds comprehensive, idempotent demo business data for Shivnath Agency ERP/CRM."

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

        self.stdout.write(self.style.NOTICE("=== Starting Shivnath Agency Demo Data Seeding ==="))

        with transaction.atomic():
            self._seed_admin_accounts()
            self._seed_territories()
            products = self._seed_products()
            raw_materials = self._seed_raw_materials()
            self._seed_boms(products, raw_materials)
            dealers = self._seed_dealers()
            customers = self._seed_customers()
            batches = self._seed_production_batches(products)
            self._seed_dealer_batches(dealers, products, batches)
            self._seed_orders_and_expiry_alert(products, dealers, customers, batches)
            self._seed_stock_requests(dealers, products, batches)
            self._seed_inventory_ledger(products, raw_materials, dealers, batches)
            self._seed_crm_leads()
            self._seed_notifications()

        self.stdout.write(self.style.SUCCESS("=== Shivnath Agency Demo Data Seeded Successfully (Idempotent) ==="))

    def _seed_admin_accounts(self):
        self.stdout.write("1. Seeding Demo Admin Accounts...")
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
                    "production", "stock_requests", "followups", "reports", "notifications", "support"
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
                "username": "demo_sales@shivnath.local",
                "email": "demo_sales@shivnath.local",
                "name": "Sales Executive (Raipur)",
                "phone": "9800000003",
                "role": "sales_executive",
                "data_scope_type": "territory_scoped",
                "assigned_scope_ids": ["Raipur Central", "Raipur Industrial"],
                "permissions": ["leads", "followups", "orders", "customers"],
            },
        ]

        test_password_hash = make_password("DemoAdmin@2026!")

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

    def _seed_territories(self):
        self.stdout.write("2. Seeding Service Districts & Zones...")
        districts = {
            "Raipur": ["Raipur Central", "Raipur Industrial"],
            "Bilaspur": ["Bilaspur East", "Bilaspur City"],
            "Durg": ["Durg-Bhilai Commercial", "Bhilai Sector"],
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

        # Deactivate any legacy non-official variants (2L, pumps, stands)
        Product.objects.filter(sku__in=["SKU-BOT-2000", "DEV-JAR-20L", "SKU-ACC-PUMP", "SKU-ACC-STAND"]).update(status="Inactive")
        return created_products

    def _seed_raw_materials(self):
        self.stdout.write("4. Seeding Realistic Raw Materials...")
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
        ]

        rms = {}
        for rdata in raw_materials_data:
            sku = rdata["sku"]
            rm, _ = RawMaterial.objects.update_or_create(sku=sku, defaults=rdata)
            rms[sku] = rm
        return rms

    def _seed_boms(self, products, raw_materials):
        self.stdout.write("5. Seeding Product BOM Recipes (Bill of Materials)...")
        recipes = {
            "SKU-BOT-200": [
                ("RM-WAT-RAW", Decimal("0.2000"), Decimal("0.08"), "Processed RO Water 200ml"),
                ("RM-PRF-200", Decimal("1.0000"), Decimal("0.90"), "PET Preform"),
                ("RM-CAP-28MM", Decimal("1.0000"), Decimal("0.35"), "Bottle Cap"),
                ("RM-LBL-200", Decimal("1.0000"), Decimal("0.22"), "Label"),
                ("RM-BOX-24", Decimal("0.0417"), Decimal("14.50"), "1/24 Box packaging"),
            ],
            "SKU-BOT-250": [
                ("RM-WAT-RAW", Decimal("0.2500"), Decimal("0.08"), "Processed RO Water 250ml"),
                ("RM-PRF-250", Decimal("1.0000"), Decimal("0.98"), "PET Preform"),
                ("RM-CAP-28MM", Decimal("1.0000"), Decimal("0.35"), "Bottle Cap"),
                ("RM-LBL-250", Decimal("1.0000"), Decimal("0.25"), "Label"),
                ("RM-BOX-24", Decimal("0.0417"), Decimal("14.50"), "1/24 Box packaging"),
            ],
            "SKU-BOT-500": [
                ("RM-WAT-RAW", Decimal("0.5000"), Decimal("0.08"), "Processed RO Water 500ml"),
                ("RM-PRF-500", Decimal("1.0000"), Decimal("1.35"), "PET Preform"),
                ("RM-CAP-28MM", Decimal("1.0000"), Decimal("0.35"), "Bottle Cap"),
                ("RM-LBL-500", Decimal("1.0000"), Decimal("0.30"), "Label"),
                ("RM-BOX-24", Decimal("0.0417"), Decimal("14.50"), "1/24 Box packaging"),
            ],
            "SKU-BOT-1000": [
                ("RM-WAT-RAW", Decimal("1.0000"), Decimal("0.08"), "Processed RO Water 1L"),
                ("RM-PRF-1000", Decimal("1.0000"), Decimal("1.80"), "PET Preform"),
                ("RM-CAP-28MM", Decimal("1.0000"), Decimal("0.35"), "Bottle Cap"),
                ("RM-LBL-1000", Decimal("1.0000"), Decimal("0.38"), "Label"),
                ("RM-BOX-12", Decimal("0.0833"), Decimal("11.00"), "1/12 Box packaging"),
            ],
            "SKU-JAR-20L": [
                ("RM-WAT-RAW", Decimal("20.0000"), Decimal("0.08"), "Processed RO Water 20L"),
                ("RM-CAP-55MM", Decimal("1.0000"), Decimal("2.40"), "Non-spill Jar Cap"),
                ("RM-LBL-JAR", Decimal("1.0000"), Decimal("1.10"), "Jar Seal/Label"),
            ],
        }

        for sku, items in recipes.items():
            product = products.get(sku)
            if not product:
                continue
            bom, _ = ProductionRecipeBOM.objects.get_or_create(
                product=product,
                defaults={"notes": f"Authoritative Production Recipe for {product.name}"}
            )
            # Remove old demo items to keep clean
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
        self.stdout.write("6. Seeding 3 Demo Wholesale Dealers...")
        dealers_spec = [
            {
                "username": "dealer_raipur@shivnath.local",
                "email": "dealer_raipur@shivnath.local",
                "name": "Maa Durga Distributors",
                "contact_name": "Rakesh Agrawal",
                "phone": "9876543001",
                "dealer_code": "DLR-DEMO-01",
                "city": "Raipur",
                "territory": "Raipur Central",
                "credit_limit": Decimal("250000.00"),
                "outstanding": Decimal("42500.00"),
                "terms_days": 15,
            },
            {
                "username": "dealer_bilaspur@shivnath.local",
                "email": "dealer_bilaspur@shivnath.local",
                "name": "Shiv Shakti Beverages",
                "contact_name": "Santosh Tiwari",
                "phone": "9876543002",
                "dealer_code": "DLR-DEMO-02",
                "city": "Bilaspur",
                "territory": "Bilaspur East",
                "credit_limit": Decimal("180000.00"),
                "outstanding": Decimal("78000.00"),
                "terms_days": 30,
            },
            {
                "username": "dealer_durg@shivnath.local",
                "email": "dealer_durg@shivnath.local",
                "name": "Chhattisgarh Pure Water Co.",
                "contact_name": "Vikas Sahu",
                "phone": "9876543003",
                "dealer_code": "DLR-DEMO-03",
                "city": "Durg",
                "territory": "Durg-Bhilai Commercial",
                "credit_limit": Decimal("120000.00"),
                "outstanding": Decimal("15000.00"),
                "terms_days": 7,
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
            prof.status = "active"
            prof.save()

            f_prof, _ = FranchiseProfile.objects.update_or_create(
                user=u,
                defaults={
                    "dealer_code": d["dealer_code"],
                    "business_name": d["name"],
                    "city": d["city"],
                    "address": f"Plot {d['dealer_code']}, Industrial Area, {d['city']}",
                    "territory": d["territory"],
                    "assigned_territories": [d["territory"]],
                    "status": "approved",
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
                    "credit_status": "GOOD_STANDING",
                }
            )
            dealers.append(f_prof)
        return dealers

    def _seed_customers(self):
        self.stdout.write("7. Seeding Demo Customers...")
        cust_spec = [
            {"username": "cust_anand@shivnath.local", "name": "Anand Verma", "phone": "9876543010", "city": "Raipur", "territory": "Raipur Central"},
            {"username": "cust_sneha@shivnath.local", "name": "Sneha Patel", "phone": "9876543011", "city": "Bilaspur", "territory": "Bilaspur East"},
            {"username": "cust_rahul@shivnath.local", "name": "Rahul Dewangan", "phone": "9876543012", "city": "Durg", "territory": "Durg-Bhilai Commercial"},
            {"username": "cust_hotel@shivnath.local", "name": "Hotel Grand Chhattisgarh", "phone": "9876543013", "city": "Raipur", "territory": "Raipur Central"},
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
        self.stdout.write("8. Seeding Production Batches (Including Approaching Expiry)...")
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
            },
            # CRITICAL: BATCH APPROACHING EXPIRY IN 7 DAYS (As requested by user!)
            # Produced: 5,000, Allocated/sold: 2,000, Pending: 3,000, Expiry: 7 days
            {
                "batch_number": "B-DEMO-001",
                "product_sku": "SKU-BOT-500",
                "mfg_date": today - datetime.timedelta(days=173),
                "exp_date": today + datetime.timedelta(days=7),  # Exactly 7 days remaining
                "produced": 5000,
                "remaining": 3000,
                "reserved": 3000,
                "cost": Decimal("2.60"),
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
                    "status": "ACTIVE",
                }
            )
            created_batches[b["batch_number"]] = batch
        return created_batches

    def _seed_dealer_batches(self, dealers, products, batches):
        self.stdout.write("9. Seeding Dealer Warehouse Stock Batches...")
        today = timezone.now().date()
        if not dealers:
            return
        d1 = dealers[0]
        p_500 = products.get("SKU-BOT-500")
        p_1000 = products.get("SKU-BOT-1000")
        p_jar = products.get("SKU-JAR-20L")

        if p_500:
            DealerStockBatch.objects.update_or_create(
                dealer=d1,
                batch_number="DLR-B-500-01",
                defaults={
                    "product": p_500,
                    "manufacture_date": today - datetime.timedelta(days=12),
                    "expiry_date": today + datetime.timedelta(days=168),
                    "received_quantity": 2400,
                    "remaining_quantity": 1800,
                    "reserved_quantity": 200,
                    "unit_transfer_price": p_500.dealer_transfer_price,
                    "is_active": True,
                }
            )
        if p_1000:
            DealerStockBatch.objects.update_or_create(
                dealer=d1,
                batch_number="DLR-B-1000-01",
                defaults={
                    "product": p_1000,
                    "manufacture_date": today - datetime.timedelta(days=8),
                    "expiry_date": today + datetime.timedelta(days=172),
                    "received_quantity": 1200,
                    "remaining_quantity": 900,
                    "reserved_quantity": 100,
                    "unit_transfer_price": p_1000.dealer_transfer_price,
                    "is_active": True,
                }
            )
        if p_jar:
            DealerStockBatch.objects.update_or_create(
                dealer=d1,
                batch_number="DLR-B-JAR-01",
                defaults={
                    "product": p_jar,
                    "manufacture_date": today - datetime.timedelta(days=4),
                    "expiry_date": today + datetime.timedelta(days=26),
                    "received_quantity": 500,
                    "remaining_quantity": 380,
                    "reserved_quantity": 50,
                    "unit_transfer_price": p_jar.dealer_transfer_price,
                    "is_active": True,
                }
            )

    def _seed_orders_and_expiry_alert(self, products, dealers, customers, batches):
        self.stdout.write("10. Seeding Orders Across Full Lifecycle & Expiry Alert Linking...")
        today = timezone.now().date()
        d_raipur = dealers[0] if dealers else None
        p_500 = products.get("SKU-BOT-500")
        p_1000 = products.get("SKU-BOT-1000")
        p_jar = products.get("SKU-JAR-20L")
        exp_batch = batches.get("B-DEMO-001")

        # 10.1 Normal Orders across all 7 Lifecycle Statuses
        statuses = [
            ("ORD-DEMO-001", "order_placement", customers[0], d_raipur, Decimal("2400.00"), p_500, 240),
            ("ORD-DEMO-002", "plant_approval", customers[1], d_raipur, Decimal("4800.00"), p_1000, 240),
            ("ORD-DEMO-003", "invoice_generated", customers[2], d_raipur, Decimal("1800.00"), p_jar, 30),
            ("ORD-DEMO-004", "preparing", customers[3], d_raipur, Decimal("7200.00"), p_500, 720),
            ("ORD-DEMO-005", "dispatch", customers[0], d_raipur, Decimal("3600.00"), p_1000, 180),
            ("ORD-DEMO-006", "delivered", customers[1], d_raipur, Decimal("5400.00"), p_500, 540),
            ("ORD-DEMO-007", "cancelled", customers[2], d_raipur, Decimal("1200.00"), p_jar, 20),
        ]

        for code, status_val, cust_user, dealer_inst, amt, prod, qty in statuses:
            order_id = int(code.split('-')[-1])
            order, _ = Order.objects.update_or_create(
                id=order_id,
                defaults={
                    "created_by": cust_user,
                    "franchise_name": dealer_inst.business_name if dealer_inst else "Direct Company",
                    "serving_franchise": dealer_inst,
                    "city": cust_user.profile.city if hasattr(cust_user, 'profile') else "Raipur",
                    "territory": cust_user.profile.territory if hasattr(cust_user, 'profile') else "Raipur Central",
                    "amount": amt,
                    "grand_total": amt,
                    "status": status_val,
                    "payment_status": "paid" if status_val == "delivered" else "pending",
                    "order_source": "FRANCHISE",
                    "items_count": 1,
                    "delivered_at": timezone.now() if status_val == "delivered" else None,
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

        # 10.2 CRITICAL EXPIRY ALERT ORDER: ORD-DEMO-1025 linked to B-DEMO-001 (5000 produced, 2000 collected, 3000 pending)
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
                "grand_total": Decimal("30000.00"),
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
                    "consumed_quantity": 2000,
                    "released_quantity": 0,
                }
            )

    def _seed_stock_requests(self, dealers, products, batches):
        self.stdout.write("11. Seeding Dealer Stock Requests Across Full Partial Lifecycle...")
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
        self.stdout.write("12. Seeding Authoritative Inventory Transaction Ledger (All 10 Types)...")
        p_500 = products.get("SKU-BOT-500")
        p_jar = products.get("SKU-JAR-20L")
        rm_prf = raw_materials.get("RM-PRF-500")
        d1 = dealers[0] if dealers else None
        pb_500 = batches.get("PB-DEMO-500-01")

        # Clear previous demo ledger transactions to avoid endless buildup
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

    def _seed_crm_leads(self):
        self.stdout.write("13. Seeding CRM Leads Covering All 12 Statuses & Follow-ups...")
        today = timezone.now()
        leads_data = [
            ("Gupta Kirana & General Store", "NEW", "hot", "HOT", "Ashok Gupta", "9826111111", "Raipur", "Raipur Central"),
            ("Shri Ram Beverages & Retail", "CONTACTED", "warm", "WARM", "Ram Prakash", "9826111112", "Bilaspur", "Bilaspur East"),
            ("Sunrise Departmental Store", "INTERESTED", "hot", "HOT", "Sunil Verma", "9826111113", "Durg", "Durg-Bhilai Commercial"),
            ("Royal Oasis Banquet & Events", "HOT_LEAD", "hot", "HOT", "Harish Agrawal", "9826111114", "Raipur", "Raipur Central"),
            ("City Mart Supermarket", "FOLLOW_UP_REQUIRED", "warm", "WARM", "Pankaj Jain", "9826111115", "Bilaspur", "Bilaspur City"),
            ("Apex Hospital Food Court", "SITE_VISIT_SCHEDULED", "hot", "HOT", "Dr. Rajesh Sen", "9826111116", "Raipur", "Raipur Central"),
            ("Kalinga Beverage Depot", "SITE_VISIT_COMPLETED", "warm", "WARM", "Kailash Patel", "9826111117", "Durg", "Durg-Bhilai Commercial"),
            ("New Chhattisgarh Traders", "AGREEMENT_PENDING", "hot", "HOT", "Naresh Goyal", "9826111118", "Raipur", "Raipur Central"),
            ("Sai Wholesale Water Hub", "FRANCHISE_CONFIRMED", "hot", "HOT", "Suresh Dewangan", "9826111119", "Bilaspur", "Bilaspur East"),
            ("Maa Annapurna Daily Needs", "CONVERTED", "warm", "WARM", "Deepak Sharma", "9826111120", "Durg", "Durg-Bhilai Commercial"),
            ("Local Corner Chai Shop", "NOT_INTERESTED", "cold", "COLD", "Gopal Yadav", "9826111121", "Raipur", "Raipur Industrial"),
            ("Metro Highway Dhaba", "LOST", "cold", "COLD", "Manoj Shukla", "9826111122", "Bilaspur", "Bilaspur East"),
        ]

        for name, st, sc, score_cat, contact_person, phone, city, terr in leads_data:
            lead, _ = Lead.objects.update_or_create(
                phone=phone,
                defaults={
                    "name": name,
                    "status": st,
                    "score": sc,
                    "score_category": score_cat,
                    "source": "Chatbot & Direct Inbound",
                    "city": city,
                    "district": city,
                    "territory": terr,
                    "investment_budget": "20L - 30L",
                    "notes": f"Demo prospective client {name} in {city} for bottled drinking water.",
                }
            )
            # Create FollowUp for this lead
            FollowUp.objects.update_or_create(
                lead=lead,
                defaults={
                    "followup_datetime": today + datetime.timedelta(days=2),
                    "followup_type": "Phone Call",
                    "note": f"Follow-up regarding franchise quotation and supply terms with {contact_person}",
                    "status": "Pending" if st not in ["CONVERTED", "NOT_INTERESTED", "LOST"] else "Completed",
                }
            )

    def _seed_notifications(self):
        self.stdout.write("14. Seeding Realistic Admin Notifications...")
        notifs = [
            ("Order Placed: ORD-DEMO-001", "New order placed by Anand Verma for 240 units of 500ml Water Bottle.", "order_placed", 1),
            ("Stock Request: DSR-DEMO-001", "M/s Maa Durga Distributors submitted stock replenishment request for 2,400 units.", "stock_alert", 2),
            ("Approaching Expiry Alert: Batch B-DEMO-001", "Batch B-DEMO-001 has 3,000 pending units expiring in 7 days. Action required.", "stock_alert", 1025),
            ("New Wholesale Dealer Inquiry", "Royal Oasis Banquet & Events expressed interest in wholesale distributor tier.", "franchise_registration", 4),
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

import datetime
from django.core.management.base import BaseCommand
from django.contrib.auth.models import User
from django.utils import timezone
from accounts.models import (
    UserProfile,
    FranchiseProfile,
    ServiceDistrict,
    ServiceZone,
    ServiceArea,
    CustomerFranchiseRelationship,
    CustomerStockCycle,
    SupportContact,
)
from products.models import Product, ProductCategory
from orders.models import Order


class Command(BaseCommand):
    help = "Seeds development and testing data clearly tagged [DEV/TEST]. Safe and idempotent."

    def handle(self, *args, **options):
        self.stdout.write(self.style.NOTICE("--- Starting Dev Seed Script ---"))

        # 1. Support Contacts
        contacts_data = [
            {
                "role": "public_customer",
                "name": "[DEV] Shivnath Customer Care",
                "phone": "9800000001",
                "email": "dev-support@shivnath.test",
                "message_template": "Namaste Support, I have a product inquiry [DEV].",
            },
            {
                "role": "public_franchise",
                "name": "[DEV] Franchise Inquiry Desk",
                "phone": "9800000002",
                "email": "dev-franchise@shivnath.test",
                "message_template": "Namaste Partner Support, I am inquiring about franchise partnership [DEV].",
            },
            {
                "role": "customer",
                "name": "[DEV] Customer Water Helpline",
                "phone": "9800000003",
                "email": "dev-care@shivnath.test",
                "message_template": "Namaste Helpline, I need assistance with my drinking water delivery [DEV].",
            },
            {
                "role": "franchise",
                "name": "[DEV] Franchise Admin Desk",
                "phone": "9800000004",
                "email": "dev-partner@shivnath.test",
                "message_template": "Namaste Admin Support, I am reaching out from franchise desk [DEV].",
            },
            {
                "role": "admin",
                "name": "[DEV] Central Administration",
                "phone": "9800000005",
                "email": "dev-admin@shivnath.test",
                "message_template": "Namaste Central Desk, System inquiry [DEV].",
            },
        ]

        for c_data in contacts_data:
            contact, created = SupportContact.objects.update_or_create(
                role=c_data["role"],
                defaults=c_data,
            )
            self.stdout.write(f"SupportContact ({contact.role}): {contact.phone} (created={created})")

        # 2. District & Zone
        district, _ = ServiceDistrict.objects.get_or_create(
            name="Raipur",
            defaults={"state": "Chhattisgarh", "is_active": True},
        )
        zone_north, _ = ServiceZone.objects.get_or_create(
            name="Raipur North Zone",
            district=district,
            defaults={"code": "RP-NORTH", "is_active": True},
        )
        zone_south, _ = ServiceZone.objects.get_or_create(
            name="Raipur South Zone",
            district=district,
            defaults={"code": "RP-SOUTH", "is_active": True},
        )

        # 3. Product Category & Product
        jar_cat, _ = ProductCategory.objects.get_or_create(
            name="Jar",
            defaults={"description": "Standard 20L Water Jars", "order": 1, "is_active": True},
        )
        jar_product, _ = Product.objects.get_or_create(
            sku="DEV-JAR-20L",
            defaults={
                "name": "[DEV] 20L Pure Mineral Water Jar",
                "size": "20 Litres",
                "category": "Jar",
                "category_ref": jar_cat,
                "price": 80.00,
                "gst": 18,
                "stock": 500,
                "status": "Active",
                "unit": "Jar",
                "description": "Standard 20 litre drinking water refill [DEV/TEST]",
            },
        )

        # 4. Franchise A & Franchise B
        # Franchise A: Raipur North
        u_fa, _ = User.objects.get_or_create(
            username="franchise_a@shivnath.test",
            defaults={
                "email": "franchise_a@shivnath.test",
                "first_name": "[DEV] Franchise A Owner",
                "is_active": True,
            },
        )
        u_fa.set_password("testpass123")
        u_fa.save()
        prof_fa, _ = UserProfile.objects.get_or_create(user=u_fa)
        prof_fa.name = "[DEV] Franchise A Owner"
        prof_fa.role = "franchise"
        prof_fa.phone = "9800000010"
        prof_fa.city = "Raipur"
        prof_fa.district = "Raipur"
        prof_fa.zone = zone_north
        prof_fa.status = "active"
        prof_fa.save()

        franchise_a, _ = FranchiseProfile.objects.get_or_create(
            user=u_fa,
            defaults={
                "business_name": "[DEV] Raipur North Test Franchise",
                "city": "Raipur",
                "territory": "North Raipur",
                "status": "approved",
                "security_deposit": 50000,
                "commission": 15,
            },
        )

        # Franchise B: Raipur South
        u_fb, _ = User.objects.get_or_create(
            username="franchise_b@shivnath.test",
            defaults={
                "email": "franchise_b@shivnath.test",
                "first_name": "[DEV] Franchise B Owner",
                "is_active": True,
            },
        )
        u_fb.set_password("testpass123")
        u_fb.save()
        prof_fb, _ = UserProfile.objects.get_or_create(user=u_fb)
        prof_fb.name = "[DEV] Franchise B Owner"
        prof_fb.role = "franchise"
        prof_fb.phone = "9800000020"
        prof_fb.city = "Raipur"
        prof_fb.district = "Raipur"
        prof_fb.zone = zone_south
        prof_fb.status = "active"
        prof_fb.save()

        franchise_b, _ = FranchiseProfile.objects.get_or_create(
            user=u_fb,
            defaults={
                "business_name": "[DEV] Raipur South Test Franchise",
                "city": "Raipur",
                "territory": "South Raipur",
                "status": "approved",
                "security_deposit": 50000,
                "commission": 15,
            },
        )

        self.stdout.write(f"Franchise A: {franchise_a.business_name} (ID: {franchise_a.id})")
        self.stdout.write(f"Franchise B: {franchise_b.business_name} (ID: {franchise_b.id})")

        # 5. Customers: A, B, C, X
        today = timezone.now().date()

        customers_spec = [
            {
                "code": "cust_a",
                "email": "customer_a@shivnath.test",
                "name": "[DEV] Arjun Test",
                "phone": "9811111111",
                "reg_f": franchise_a,
                "serving_f": franchise_a,
                "zone": zone_north,
                "cycle_status": "active",
                "days_offset": 15,
                "hold_days": None,
            },
            {
                "code": "cust_b",
                "email": "customer_b@shivnath.test",
                "name": "[DEV] Bhavna Test",
                "phone": "9822222222",
                "reg_f": franchise_a,
                "serving_f": franchise_a,
                "zone": zone_north,
                "cycle_status": "active",
                "days_offset": 4,  # Low stock (< 7 days)
                "hold_days": None,
            },
            {
                "code": "cust_c",
                "email": "customer_c@shivnath.test",
                "name": "[DEV] Charan Test",
                "phone": "9833333333",
                "reg_f": franchise_a,
                "serving_f": franchise_a,
                "zone": zone_north,
                "cycle_status": "hold",
                "days_offset": 10,
                "hold_days": 10,  # Paused at 10 days
            },
            {
                "code": "cust_x",
                "email": "customer_x@shivnath.test",
                "name": "[DEV] Xavier Test",
                "phone": "9844444444",
                "reg_f": franchise_a,   # Registered under A
                "serving_f": franchise_b, # Currently served by B!
                "zone": zone_south,
                "cycle_status": "active",
                "days_offset": 20,
                "hold_days": None,
            },
        ]

        for spec in customers_spec:
            u, _ = User.objects.get_or_create(
                username=spec["email"],
                defaults={
                    "email": spec["email"],
                    "first_name": spec["name"],
                    "is_active": True,
                },
            )
            u.set_password("testpass123")
            u.save()

            prof, _ = UserProfile.objects.get_or_create(user=u)
            prof.name = spec["name"]
            prof.phone = spec["phone"]
            prof.role = "customer"
            prof.city = "Raipur"
            prof.district = "Raipur"
            prof.zone = spec["zone"]
            prof.status = "active"
            prof.save()

            # Relationship
            rel, _ = CustomerFranchiseRelationship.objects.update_or_create(
                customer=u,
                defaults={
                    "registered_franchise": spec["reg_f"],
                    "current_serving_franchise": spec["serving_f"],
                    "district": district,
                    "zone": spec["zone"],
                    "service_status": spec["cycle_status"],
                },
            )

            # Stock Cycle
            start_d = today - datetime.timedelta(days=10)
            end_d = today + datetime.timedelta(days=spec["days_offset"])

            cycle, _ = CustomerStockCycle.objects.update_or_create(
                customer=u,
                defaults={
                    "product": jar_product,
                    "quantity": 1,
                    "duration_choice": "1 Month",
                    "duration_days": 30,
                    "start_date": start_d,
                    "expected_end_date": end_d,
                    "service_status": spec["cycle_status"],
                    "remaining_days_at_hold": spec["hold_days"],
                    "registered_franchise": spec["reg_f"],
                    "serving_franchise": spec["serving_f"],
                    "zone": spec["zone"],
                },
            )

            # Representative Order
            Order.objects.update_or_create(
                created_by=u,
                franchise_name=spec["serving_f"].business_name,
                defaults={
                    "city": "Raipur",
                    "items_count": 1,
                    "amount": 80.00,
                    "status": "delivered" if spec["code"] != "cust_x" else "order_placement",
                    "payment_status": "paid" if spec["code"] != "cust_x" else "pending",
                    "serving_franchise": spec["serving_f"],
                    "registered_franchise": spec["reg_f"],
                    "zone": spec["zone"],
                },
            )

            self.stdout.write(
                f"Customer {spec['name']} ({spec['email']}): "
                f"Reg={spec['reg_f'].business_name}, Serving={spec['serving_f'].business_name}, "
                f"Stock={spec['cycle_status']} (days={spec['days_offset']})"
            )

        self.stdout.write(self.style.SUCCESS("--- Dev Seed Script Completed Successfully ---"))
        self.stdout.write("Credentials: all dev users have password 'testpass123'")

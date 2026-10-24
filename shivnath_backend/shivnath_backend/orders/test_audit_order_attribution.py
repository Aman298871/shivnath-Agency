from io import StringIO
from decimal import Decimal
from django.test import TestCase
from django.core.management import call_command
from django.contrib.auth.models import User
from orders.models import Order
from accounts.models import FranchiseProfile, UserProfile


class AuditOrderAttributionCommandTests(TestCase):
    def setUp(self):
        self.user = User.objects.create_user("cust_audit", "cust@example.com", "pass123", first_name="Aman", last_name="Verma")
        UserProfile.objects.update_or_create(user=self.user, defaults={"role": "customer", "phone": "9998887770"})

        self.franchise_user = User.objects.create_user("fran_audit", "fran@example.com", "pass123")
        UserProfile.objects.update_or_create(user=self.franchise_user, defaults={"role": "franchise", "phone": "9998887771"})
        self.franchise = FranchiseProfile.objects.create(
            user=self.franchise_user,
            business_name="Capital Franchise Agency",
            dealer_code="DLR-CAPITAL-01",
            city="Raipur",
            address="VIP Road",
            status="approved"
        )

    def test_audit_detects_and_repairs_misattribution(self):
        # Create an order where franchise_name was wrongly populated with the customer's name
        order = Order.objects.create(
            created_by=self.user,
            client_name="Aman Verma",
            franchise_name="Aman Verma", # Misattribution bug
            order_source="DIRECT_COMPANY",
            city="Raipur",
            amount=Decimal("200.00"),
            grand_total=Decimal("200.00"),
            items_count=2,
        )

        # 1. Dry run
        out = StringIO()
        call_command("audit_order_attribution", stdout=out)
        output_str = out.getvalue()
        self.assertIn("Identified 1 misattributed order record", output_str)
        self.assertIn("Aman Verma", output_str)

        # Verify not yet changed
        order.refresh_from_db()
        self.assertEqual(order.franchise_name, "Aman Verma")

        # 2. Commit run
        out_commit = StringIO()
        call_command("audit_order_attribution", "--commit", stdout=out_commit)
        commit_output_str = out_commit.getvalue()
        self.assertIn("Successfully repaired 1 order record", commit_output_str)

        order.refresh_from_db()
        self.assertEqual(order.franchise_name, "Shivnath Central Admin (Direct)")
        self.assertEqual(order.order_source, "DIRECT_COMPANY")

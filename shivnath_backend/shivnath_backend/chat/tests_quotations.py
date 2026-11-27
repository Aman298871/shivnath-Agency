from django.test import TestCase
from django.contrib.auth import get_user_model
from django.utils import timezone
from rest_framework.test import APIClient
from rest_framework import status
from accounts.models import FranchiseProfile, UserProfile
from chat.models import Quotation
from products.models import Product

User = get_user_model()

class QuotationVisibilityAndActionTests(TestCase):
    def setUp(self):
        self.client = APIClient()

        # Create Admin
        self.admin_user = User.objects.create_user(
            username="admin_user",
            email="admin@shivnath.com",
            password="AdminPassword123!",
            is_staff=True,
            is_superuser=True,
        )

        # Create Franchise 1 (Krishna)
        self.franchise_user = User.objects.create_user(
            username="krishna",
            email="krishna@gmail.com",
            password="FranchisePassword123!",
        )
        self.franchise_profile = FranchiseProfile.objects.create(
            user=self.franchise_user,
            business_name="Krishna Agency",
            dealer_code="FRN-KRI-001",
            city="Raipur",
            address="Farishta Complex",
            status="approved",
        )

        # Create Franchise 2 (Other)
        self.other_user = User.objects.create_user(
            username="other_frn",
            email="other@gmail.com",
            password="OtherPassword123!",
        )
        self.other_profile = FranchiseProfile.objects.create(
            user=self.other_user,
            business_name="Other Agency",
            dealer_code="FRN-OTH-002",
            city="Bilaspur",
            address="Vyapar Vihar",
            status="approved",
        )

        # Update profiles created by post_save signal
        UserProfile.objects.filter(user=self.admin_user).update(role="admin", status="active")
        UserProfile.objects.filter(user=self.franchise_user).update(role="franchise", status="active")
        UserProfile.objects.filter(user=self.other_user).update(role="franchise", status="active")

        # Create Product
        self.product = Product.objects.create(
            name="Shivnath 1 Litre Premium",
            size="1L",
            price=20.0,
            stock=500,
        )

    def test_general_quotation_visible_to_all_franchises(self):
        # 1. Admin creates quotation for ALL FRANCHISES (franchise=None)
        q_general = Quotation.objects.create(
            title="General Franchise Policy Quotation",
            quotation_number="Q-ALL-001",
            quotation_type="franchise",
            target_audience="franchise",
            status="published",
            franchise=None,
            product=self.product,
            quantity_tier="100+ Boxes",
            unit_price=14.0,
            total_price=16800.0,
            valid_until=timezone.now().date() + timezone.timedelta(days=30),
        )

        # 2. Franchise 1 (Krishna) logs in and lists quotations
        self.client.force_authenticate(user=self.franchise_user)
        response = self.client.get("/api/chat/quotations/")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertTrue(response.data.get("success"))
        quotation_ids = [q["id"] for q in response.data.get("quotations", [])]
        self.assertIn(q_general.id, quotation_ids, "General policy quotation must be visible to Franchise 1")

        # 3. Franchise 1 views details
        detail_res = self.client.get(f"/api/chat/quotations/{q_general.id}/")
        self.assertEqual(detail_res.status_code, status.HTTP_200_OK)
        self.assertTrue(detail_res.data.get("success"))

        # 4. Franchise 1 accepts quotation
        action_res = self.client.post(f"/api/chat/quotations/{q_general.id}/action/", {"action": "accept"})
        self.assertEqual(action_res.status_code, status.HTTP_200_OK)
        self.assertTrue(action_res.data.get("success"))

        # Verify status is accepted
        q_general.refresh_from_db()
        self.assertEqual(q_general.status, "accepted")

    def test_specific_franchise_quotation_not_leaked_to_other_franchise(self):
        # Specific quotation for Franchise 1 only
        q_specific = Quotation.objects.create(
            title="Exclusive Krishna Agency Offer",
            quotation_number="Q-KRI-001",
            quotation_type="franchise",
            target_audience="franchise",
            status="published",
            franchise=self.franchise_profile,
            product=self.product,
            unit_price=12.0,
            total_price=12000.0,
        )

        # Franchise 2 logs in
        self.client.force_authenticate(user=self.other_user)
        response = self.client.get("/api/chat/quotations/")
        quotation_ids = [q["id"] for q in response.data.get("quotations", [])]
        self.assertNotIn(q_specific.id, quotation_ids, "Specific quotation for Krishna must NOT be visible to Other franchise")

        # Attempting direct detail access by Franchise 2 must be Forbidden
        detail_res = self.client.get(f"/api/chat/quotations/{q_specific.id}/")
        self.assertEqual(detail_res.status_code, status.HTTP_403_FORBIDDEN)

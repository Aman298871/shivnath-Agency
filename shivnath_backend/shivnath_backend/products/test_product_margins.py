from decimal import Decimal
from django.test import TestCase
from products.models import Product
from products.serializers import ProductSerializer


class ProductPricingMarginTests(TestCase):
    def setUp(self):
        self.product = Product.objects.create(
            name="1 Litre Packaged Drinking Water",
            sku="SHV-1L-TEST",
            size="1 Litre",
            price=Decimal("20.00"),
            dealer_transfer_price=Decimal("14.00"),
            mrp=Decimal("20.00"),
            gst=18,
            stock=1000,
            status="Active",
            package_type="BOTTLE",
            category="Bottle"
        )

    def test_franchise_margin_calculation(self):
        serializer = ProductSerializer(self.product)
        data = serializer.data

        self.assertEqual(data["price"], "20.00")
        self.assertEqual(data["dealer_transfer_price"], "14.00")
        self.assertEqual(data["franchise_margin"], 6.0)
        self.assertEqual(data["franchise_margin_pct"], 30.0)

    def test_zero_margin_when_wholesale_equals_retail(self):
        self.product.dealer_transfer_price = Decimal("20.00")
        self.product.save()

        serializer = ProductSerializer(self.product)
        data = serializer.data

        self.assertEqual(data["franchise_margin"], 0.0)
        self.assertEqual(data["franchise_margin_pct"], 0.0)

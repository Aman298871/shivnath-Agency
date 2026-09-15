from rest_framework import serializers

from .models import Product


class ProductSerializer(serializers.ModelSerializer):

    class Meta:

        model = Product

        fields = [
            "id",

            "name",
            "sku",
            "size",
            "category",

            "price",
            "gst",

            "stock",

            "status",

            "created_at",
            "updated_at",
        ]

        read_only_fields = [
            "id",
            "created_at",
            "updated_at",
        ]

    # ------------------------------------
    # Name
    # ------------------------------------

    def validate_name(self, value):

        value = value.strip()

        if not value:
            raise serializers.ValidationError(
                "Product name is required."
            )

        return value

    # ------------------------------------
    # SKU
    # ------------------------------------

    def validate_sku(self, value):

        value = value.strip().upper()

        qs = Product.objects.filter(
            sku=value,
        )

        if self.instance:
            qs = qs.exclude(
                pk=self.instance.pk,
            )

        if qs.exists():

            raise serializers.ValidationError(
                "SKU already exists."
            )

        return value

    # ------------------------------------
    # Size
    # ------------------------------------

    def validate_size(self, value):

        value = value.strip()

        if not value:
            raise serializers.ValidationError(
                "Size is required."
            )

        return value

    # ------------------------------------
    # Price
    # ------------------------------------

    def validate_price(self, value):

        if value < 0:

            raise serializers.ValidationError(
                "Price cannot be negative."
            )

        return value

    # ------------------------------------
    # GST
    # ------------------------------------

    def validate_gst(self, value):

        if value < 0 or value > 100:

            raise serializers.ValidationError(
                "GST must be between 0 and 100."
            )

        return value

    # ------------------------------------
    # Stock
    # ------------------------------------

    def validate_stock(self, value):

        if value < 0:

            raise serializers.ValidationError(
                "Stock cannot be negative."
            )

        return value

    # ------------------------------------
    # Final Validation
    # ------------------------------------

    def validate(self, attrs):

        return attrs
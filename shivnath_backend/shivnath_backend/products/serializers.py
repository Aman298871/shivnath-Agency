from rest_framework import serializers

from .models import Product, ProductCategory


class ProductCategorySerializer(serializers.ModelSerializer):
    subcategories = serializers.SerializerMethodField()
    parent_name = serializers.CharField(source="parent.name", read_only=True)
    product_count = serializers.SerializerMethodField()

    class Meta:
        model = ProductCategory
        fields = [
            "id",
            "name",
            "slug",
            "parent",
            "parent_name",
            "description",
            "order",
            "is_active",
            "subcategories",
            "product_count",
            "created_at",
            "updated_at",
        ]
        read_only_fields = ["id", "created_at", "updated_at"]

    def get_subcategories(self, obj):
        children = obj.subcategories.filter(is_active=True).order_by("order", "name")
        return ProductCategorySerializer(children, many=True).data

    def get_product_count(self, obj):
        return obj.products.count()


class ProductSerializer(serializers.ModelSerializer):
    category_name = serializers.CharField(source="category", read_only=True)
    category_ref_id = serializers.PrimaryKeyRelatedField(
        queryset=ProductCategory.objects.all(),
        source="category_ref",
        required=False,
        allow_null=True,
    )
    category_hierarchy = serializers.SerializerMethodField()

    class Meta:
        model = Product
        fields = [
            "id",
            "name",
            "sku",
            "size",
            "category",
            "category_ref",
            "category_ref_id",
            "category_name",
            "category_hierarchy",
            "price",
            "gst",
            "stock",
            "unit",
            "description",
            "status",
            "created_at",
            "updated_at",
        ]
        read_only_fields = [
            "id",
            "category_name",
            "category_hierarchy",
            "created_at",
            "updated_at",
        ]

    def get_category_hierarchy(self, obj):
        if obj.category_ref:
            return obj.category_ref.full_path
        return obj.category or ""

    def validate_name(self, value):
        value = value.strip()
        if not value:
            raise serializers.ValidationError("Product name is required.")
        return value

    def validate_sku(self, value):
        value = value.strip().upper()
        qs = Product.objects.filter(sku=value)
        if self.instance:
            qs = qs.exclude(pk=self.instance.pk)
        if qs.exists():
            raise serializers.ValidationError("SKU already exists.")
        return value

    def validate_size(self, value):
        value = value.strip()
        if not value:
            raise serializers.ValidationError("Size is required.")
        return value

    def validate_price(self, value):
        if value < 0:
            raise serializers.ValidationError("Price cannot be negative.")
        return value

    def validate_gst(self, value):
        if value < 0 or value > 100:
            raise serializers.ValidationError("GST must be between 0 and 100.")
        return value

    def validate_stock(self, value):
        if value < 0:
            raise serializers.ValidationError("Stock cannot be negative.")
        return value

    def validate(self, attrs):
        return attrs
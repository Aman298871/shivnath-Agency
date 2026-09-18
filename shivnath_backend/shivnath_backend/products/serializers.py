from rest_framework import serializers

from .models import Product, ProductCategory


class ProductCategorySerializer(serializers.ModelSerializer):
    children = serializers.SerializerMethodField()
    subcategories = serializers.SerializerMethodField()
    parent_name = serializers.CharField(source="parent.name", read_only=True)
    full_path = serializers.CharField(read_only=True)
    product_count = serializers.SerializerMethodField()

    class Meta:
        model = ProductCategory
        fields = [
            "id",
            "name",
            "slug",
            "parent",
            "parent_name",
            "full_path",
            "description",
            "order",
            "is_active",
            "children",
            "subcategories",
            "product_count",
            "created_at",
            "updated_at",
        ]
        read_only_fields = ["id", "parent_name", "full_path", "created_at", "updated_at"]

    def get_children(self, obj):
        request = self.context.get("request")
        include_inactive = False
        if request and hasattr(request, "query_params"):
            include_inactive = request.query_params.get("include_inactive", "").lower() in ["true", "1"]

        qs = obj.children.all()
        if not include_inactive:
            qs = qs.filter(is_active=True)
        children = qs.order_by("order", "name")
        return ProductCategorySerializer(children, many=True, context=self.context).data

    def get_subcategories(self, obj):
        return self.get_children(obj)

    def get_product_count(self, obj):
        return obj.products.count()

    def validate_name(self, value):
        value = value.strip()
        if not value:
            raise serializers.ValidationError("Category name is required.")
        if len(value) > 150:
            raise serializers.ValidationError("Category name cannot exceed 150 characters.")
        return value

    def validate(self, attrs):
        name = attrs.get("name")
        if name is None and self.instance:
            name = self.instance.name

        parent = attrs.get("parent")
        if "parent" not in attrs and self.instance:
            parent = self.instance.parent

        if name:
            name_clean = name.strip()
            # Sibling duplicate check (case-insensitive)
            if parent:
                qs = ProductCategory.objects.filter(parent=parent, name__iexact=name_clean)
            else:
                qs = ProductCategory.objects.filter(parent__isnull=True, name__iexact=name_clean)

            if self.instance:
                qs = qs.exclude(pk=self.instance.pk)

            if qs.exists():
                raise serializers.ValidationError(
                    {"name": f"A category named '{name_clean}' already exists at this level."}
                )

        # Self-parent and circular hierarchy check
        if parent and self.instance:
            if parent.id == self.instance.id:
                raise serializers.ValidationError(
                    {"parent": "A category cannot be its own parent."}
                )

            curr = parent
            while curr is not None:
                if curr.id == self.instance.id:
                    raise serializers.ValidationError(
                        {"parent": "Circular category hierarchy is not allowed."}
                    )
                curr = curr.parent

        return attrs


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
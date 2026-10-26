from rest_framework import serializers

from .models import (
    Product, ProductCategory, ProductionRecipeBOM, ProductionRecipeBOMItem,
    ProductStockThreshold, MinimumOrderPackagingRule
)
from inventory.models import RawMaterial


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
        from django.db.models import Q
        descendant_ids = obj.get_descendant_ids()
        return Product.objects.filter(
            status="Active"
        ).filter(
            Q(category_ref_id__in=descendant_ids)
            | Q(category__iexact=obj.name)
            | Q(category_ref__slug=obj.slug)
        ).distinct().count()

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


class ProductionRecipeBOMItemSerializer(serializers.ModelSerializer):
    raw_material_name = serializers.CharField(source="raw_material.name", read_only=True)
    raw_material_sku = serializers.CharField(source="raw_material.sku", read_only=True)
    raw_material_unit = serializers.CharField(source="raw_material.unit_of_measure", read_only=True)
    calculated_cost_per_unit = serializers.DecimalField(max_digits=12, decimal_places=2, read_only=True)

    class Meta:
        model = ProductionRecipeBOMItem
        fields = [
            "id",
            "bom",
            "raw_material",
            "raw_material_name",
            "raw_material_sku",
            "raw_material_unit",
            "quantity_required_per_unit",
            "unit_cost_snapshot",
            "calculated_cost_per_unit",
            "notes",
        ]
        read_only_fields = ["id", "calculated_cost_per_unit"]


class ProductionRecipeBOMSerializer(serializers.ModelSerializer):
    items = ProductionRecipeBOMItemSerializer(many=True, read_only=True)
    total_production_cost_per_unit = serializers.DecimalField(max_digits=12, decimal_places=2, read_only=True)
    product_name = serializers.CharField(source="product.name", read_only=True)
    product_sku = serializers.CharField(source="product.sku", read_only=True)

    class Meta:
        model = ProductionRecipeBOM
        fields = [
            "id",
            "product",
            "product_name",
            "product_sku",
            "notes",
            "total_production_cost_per_unit",
            "items",
            "updated_at",
        ]
        read_only_fields = ["id", "updated_at", "total_production_cost_per_unit"]


class ProductStockThresholdSerializer(serializers.ModelSerializer):
    class Meta:
        model = ProductStockThreshold
        fields = [
            "id",
            "product",
            "company_low_stock_threshold",
            "dealer_low_stock_threshold",
            "alert_enabled",
        ]


class ProductSerializer(serializers.ModelSerializer):
    category_name = serializers.CharField(source="category", read_only=True)
    category_ref_id = serializers.PrimaryKeyRelatedField(
        queryset=ProductCategory.objects.all(),
        source="category_ref",
        required=False,
        allow_null=True,
    )
    category_hierarchy = serializers.SerializerMethodField()
    production_cost_per_unit = serializers.SerializerMethodField()

    class Meta:
        model = Product
        fields = [
            "id",
            "name",
            "sku",
            "size",
            "volume_ml",
            "package_type",
            "units_per_case",
            "category",
            "category_ref",
            "category_ref_id",
            "category_name",
            "category_hierarchy",
            "price",
            "dealer_transfer_price",
            "mrp",
            "is_price_inclusive_gst",
            "carton_price",
            "calculated_carton_price",
            "discount_price",
            "effective_price",
            "shelf_life_days",
            "production_cost_per_unit",
            "gst",
            "stock",
            "unit",
            "description",
            "status",
            "image",
            "created_at",
            "updated_at",
        ]
        read_only_fields = [
            "id",
            "category_name",
            "category_hierarchy",
            "production_cost_per_unit",
            "calculated_carton_price",
            "effective_price",
            "created_at",
            "updated_at",
        ]

    def get_category_hierarchy(self, obj):
        if obj.category_ref:
            return obj.category_ref.full_path
        return obj.category or ""

    def get_production_cost_per_unit(self, obj):
        bom = getattr(obj, "recipe_bom", None)
        if bom:
            return float(bom.total_production_cost_per_unit)
        return 0.0

    def to_representation(self, instance):
        ret = super().to_representation(instance)
        try:
            from inventory.models import ProductionBatch, DealerStockBatch
            from django.db.models import Sum
            from datetime import date
            today = date.today()

            cp_stock = ProductionBatch.objects.filter(
                product=instance,
                status='ACTIVE',
                expiry_date__gt=today
            ).aggregate(s=Sum('quantity_remaining_company'))['s'] or 0

            dealer_stock = DealerStockBatch.objects.filter(
                product=instance,
                is_active=True,
                expiry_date__gt=today
            ).aggregate(s=Sum('remaining_quantity'))['s'] or 0

            # Franchise-specific stock resolution
            request = self.context.get('request')
            franchise_id = None
            if request and hasattr(request, 'query_params'):
                franchise_id = request.query_params.get('franchise_id') or request.query_params.get('serving_franchise_id')
            if not franchise_id:
                franchise_id = self.context.get('franchise_id')

            if franchise_id:
                try:
                    f_stock = DealerStockBatch.objects.filter(
                        product=instance,
                        dealer_id=franchise_id,
                        is_active=True,
                        expiry_date__gt=today
                    ).aggregate(s=Sum('remaining_quantity'))['s'] or 0
                    ret['franchise_stock'] = int(f_stock)
                    ret['stock'] = int(f_stock)
                except Exception:
                    ret['franchise_stock'] = 0
            else:
                total_batch_stock = int(cp_stock) + int(dealer_stock)
                effective_stock = max(instance.stock, total_batch_stock)
                if effective_stock != instance.stock and total_batch_stock > 0:
                    Product.objects.filter(pk=instance.pk).update(stock=effective_stock)
                ret['stock'] = effective_stock

            ret['central_stock'] = int(cp_stock)
            ret['dealer_stock'] = int(dealer_stock)
        except Exception:
            pass

        # Guarantee full URL for product image
        if ret.get('image') and not str(ret['image']).startswith(('http://', 'https://')):
            from django.conf import settings
            base_url = getattr(settings, 'BACKEND_URL', 'https://shivnath-agency.onrender.com').rstrip('/')
            img_path = ret['image'] if str(ret['image']).startswith('/') else f"/{ret['image']}"
            ret['image'] = f"{base_url}{img_path}"

        # Standard business rule margins
        from decimal import Decimal
        price = Decimal(str(instance.price or '0.00'))
        transfer_price = Decimal(str(instance.dealer_transfer_price or '0.00'))
        prod_cost = Decimal(str(ret.get('production_cost_per_unit') or '0.00'))

        franchise_margin = max(Decimal('0.00'), price - transfer_price)
        franchise_margin_pct = round((franchise_margin / price * Decimal('100.00')), 2) if price > Decimal('0.00') else Decimal('0.00')
        company_margin = max(Decimal('0.00'), transfer_price - prod_cost)
        company_margin_pct = round((company_margin / transfer_price * Decimal('100.00')), 2) if transfer_price > Decimal('0.00') else Decimal('0.00')

        ret['franchise_margin'] = float(franchise_margin)
        ret['franchise_margin_pct'] = float(franchise_margin_pct)
        ret['company_gross_margin'] = float(company_margin)
        ret['company_gross_margin_pct'] = float(company_margin_pct)

        # Authoritative pricing & packaging fields
        ret['is_price_inclusive_gst'] = bool(instance.is_price_inclusive_gst)
        ret['carton_price'] = float(instance.carton_price or 0.0)
        ret['calculated_carton_price'] = float(instance.calculated_carton_price or 0.0)
        ret['discount_price'] = float(instance.discount_price or 0.0)
        ret['effective_price'] = float(instance.effective_price or instance.price or 0.0)
        ret['gst_rate'] = int(instance.gst)
        ret['units_per_carton'] = int(instance.units_per_case)
        ret['dealer_wholesale_price'] = float(instance.dealer_transfer_price or 0.0)
        ret['retail_mrp'] = float(instance.mrp or instance.price or 0.0)
        ret['customer_price'] = float(instance.price or 0.0)

        return ret

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

    def validate_dealer_transfer_price(self, value):
        if value < 0:
            raise serializers.ValidationError("Dealer transfer price cannot be negative.")
        return value

    def validate_carton_price(self, value):
        if value is not None and value < 0:
            raise serializers.ValidationError("Carton price cannot be negative.")
        return value

    def validate_discount_price(self, value):
        if value is not None and value < 0:
            raise serializers.ValidationError("Discount price cannot be negative.")
        return value

    def validate_units_per_case(self, value):
        if value is not None and value < 1:
            raise serializers.ValidationError("Units per carton/case must be at least 1.")
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
        # Support common aliases seamlessly
        if 'customer_price' in self.initial_data and 'price' not in attrs:
            attrs['price'] = self.initial_data['customer_price']
        if 'dealer_wholesale_price' in self.initial_data and 'dealer_transfer_price' not in attrs:
            attrs['dealer_transfer_price'] = self.initial_data['dealer_wholesale_price']
        if 'retail_mrp' in self.initial_data and 'mrp' not in attrs:
            attrs['mrp'] = self.initial_data['retail_mrp']
        if 'units_per_carton' in self.initial_data and 'units_per_case' not in attrs:
            attrs['units_per_case'] = self.initial_data['units_per_carton']
        if 'gst_rate' in self.initial_data and 'gst' not in attrs:
            attrs['gst'] = self.initial_data['gst_rate']
        return attrs


class MinimumOrderPackagingRuleSerializer(serializers.ModelSerializer):
    name = serializers.CharField(required=False, allow_blank=True, default='')
    product_name = serializers.CharField(source='product.name', read_only=True)
    category_name = serializers.CharField(source='category.name', read_only=True)
    franchise_name = serializers.CharField(source='franchise.business_name', read_only=True)

    class Meta:
        model = MinimumOrderPackagingRule
        fields = [
            'id',
            'name',
            'product',
            'product_name',
            'category',
            'category_name',
            'franchise',
            'franchise_name',
            'allow_franchise_override',
            'max_franchise_moq',
            'sales_unit',
            'min_order_quantity',
            'units_per_carton',
            'allow_partial_carton',
            'applies_to',
            'is_active',
            'priority',
            'created_at',
            'updated_at',
        ]
        read_only_fields = ['id', 'created_at', 'updated_at']
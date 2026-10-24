from rest_framework import serializers
import datetime

from .models import (
    InventoryItem,
    StockRequest,
)


class InventoryItemSerializer(serializers.ModelSerializer):

    type_display = serializers.CharField(
        source='get_item_type_display',
        read_only=True,
    )

    unit_display = serializers.CharField(
        source='get_unit_display',
        read_only=True,
    )

    is_low_stock = serializers.SerializerMethodField()
    stock_value = serializers.SerializerMethodField()

    class Meta:
        model = InventoryItem

        fields = [
            'id',
            'name',
            'item_type',
            'type_display',
            'sku',
            'unit',
            'unit_display',
            'stock',
            'min_stock',
            'purchase_rate',
            'batch',
            'supplier',
            'is_low_stock',
            'stock_value',
            'created_at',
            'updated_at',
        ]

        read_only_fields = [
            'id',
            'type_display',
            'unit_display',
            'is_low_stock',
            'stock_value',
            'created_at',
            'updated_at',
        ]

    def get_is_low_stock(self, obj):
        return obj.stock <= obj.min_stock

    def get_stock_value(self, obj):
        return float(obj.stock * obj.purchase_rate)

    def validate_name(self, value):
        value = value.strip()

        if not value:
            raise serializers.ValidationError(
                'Item name is required.'
            )

        return value

    def validate_stock(self, value):
        if value < 0:
            raise serializers.ValidationError(
                'Stock cannot be negative.'
            )
        return value

    def validate_min_stock(self, value):
        if value < 0:
            raise serializers.ValidationError(
                'Minimum stock cannot be negative.'
            )
        return value

    def validate_purchase_rate(self, value):
        if value < 0:
            raise serializers.ValidationError(
                'Purchase rate cannot be negative.'
            )
        return value


class StockRequestSerializer(serializers.ModelSerializer):

    item_id = serializers.PrimaryKeyRelatedField(
        source='item',
        queryset=InventoryItem.objects.all(),
    )

    item_name = serializers.CharField(
        source='item.name',
        read_only=True,
    )

    type_display = serializers.CharField(
        source='get_request_type_display',
        read_only=True,
    )

    status_display = serializers.CharField(
        source='get_status_display',
        read_only=True,
    )

    requested_by_name = serializers.SerializerMethodField()

    class Meta:
        model = StockRequest

        fields = [
            'id',
            'item_id',
            'item_name',
            'request_type',
            'type_display',
            'quantity',
            'reason',
            'rejection_reason',
            'status',
            'status_display',
            'requested_by_name',
            'created_at',
            'approved_at',
        ]

        read_only_fields = [
            'id',
            'item_name',
            'type_display',
            'status_display',
            'requested_by_name',
            'status',
            'rejection_reason',
            'approved_at',
            'created_at',
        ]

    def get_requested_by_name(self, obj):
        if not obj.requested_by:
            return ''

        return (
            obj.requested_by.get_full_name()
            or obj.requested_by.username
        )

    def validate_quantity(self, value):
        if value <= 0:
            raise serializers.ValidationError(
                'Quantity must be greater than zero.'
            )
        return value


# =====================================================================
# AUTHORITATIVE ERP SERIALIZERS
# =====================================================================

from .models import (
    RawMaterial,
    ProductionBatch,
    DealerStockBatch,
    DealerStockRequest,
    DealerStockRequestAllocation,
    InventoryTransactionLedger,
    Expense,
    DailyBusinessReport,
    ExpiryAlertLog,
)


class RawMaterialSerializer(serializers.ModelSerializer):
    category_display = serializers.CharField(source='get_category_display', read_only=True)
    is_low_stock = serializers.SerializerMethodField()

    class Meta:
        model = RawMaterial
        fields = [
            'id',
            'sku',
            'name',
            'category',
            'category_display',
            'unit_of_measure',
            'unit_cost',
            'current_stock',
            'reorder_level',
            'is_low_stock',
            'is_active',
            'created_at',
            'updated_at',
        ]

    def get_is_low_stock(self, obj):
        return obj.current_stock <= obj.reorder_level

    def to_representation(self, instance):
        ret = super().to_representation(instance)
        request = self.context.get('request')
        if request and hasattr(request, 'user'):
            user = request.user
            is_admin = user.is_superuser or (hasattr(user, 'profile') and user.profile.role in ['super_admin', 'admin'])
            if not is_admin:
                ret.pop('unit_cost', None)
        return ret


class ProductionBatchSerializer(serializers.ModelSerializer):
    product_name = serializers.CharField(source='product.name', read_only=True)
    product_sku = serializers.CharField(source='product.sku', read_only=True)
    available_quantity = serializers.IntegerField(read_only=True)
    is_expired = serializers.SerializerMethodField()
    linked_order_code = serializers.SerializerMethodField()
    order_name = serializers.SerializerMethodField()
    order_number = serializers.SerializerMethodField()
    client_name = serializers.SerializerMethodField()
    order_details = serializers.SerializerMethodField()
    quantity_taken = serializers.IntegerField(read_only=True)
    quantity_pending_collection = serializers.IntegerField(read_only=True)
    dynamic_remaining_company = serializers.IntegerField(read_only=True)

    class Meta:
        model = ProductionBatch
        fields = [
            'id',
            'batch_number',
            'product',
            'product_name',
            'product_sku',
            'client_name',
            'linked_order',
            'linked_order_code',
            'order_name',
            'order_number',
            'order_details',
            'label_requirement',
            'printing_requirement',
            'branding_requirement',
            'shelf_life_days',
            'manufacture_date',
            'expiry_date',
            'quantity_produced_units',
            'quantity_remaining_company',
            'reserved_quantity',
            'quantity_dispatched',
            'quantity_taken',
            'quantity_pending_collection',
            'dynamic_remaining_company',
            'quantity_damaged',
            'quantity_returned',
            'available_quantity',
            'unit_production_cost',
            'status',
            'is_expired',
            'created_at',
        ]

    def get_client_name(self, obj):
        if obj.client_name and obj.client_name.strip():
            return obj.client_name.strip()
        if obj.linked_order:
            return (obj.linked_order.client_name or obj.linked_order.franchise_name or f"Order #{obj.linked_order.id}").strip()
        return ""

    def get_order_name(self, obj):
        if obj.linked_order:
            name = (obj.linked_order.client_name or obj.linked_order.franchise_name or "").strip()
            code = obj.linked_order.order_code
            if name:
                return f"{code} - {name}"
            return code
        if obj.client_name and obj.client_name.strip():
            return obj.client_name.strip()
        return ""

    def get_order_number(self, obj):
        if obj.linked_order:
            try:
                return obj.linked_order.order_code
            except Exception:
                return f"ORD-{1000 + obj.linked_order.id}"
        if obj.client_name:
            import re
            m = re.search(r'(ORD-?\d+)', obj.client_name, re.IGNORECASE)
            if m:
                return m.group(1).upper()
        return ""

    def get_order_details(self, obj):
        if not obj.linked_order:
            return None
        ord_obj = obj.linked_order
        return {
            'id': ord_obj.id,
            'order_code': ord_obj.order_code,
            'client_name': ord_obj.client_name or '',
            'franchise_name': ord_obj.franchise_name or '',
            'status': ord_obj.status,
            'payment_status': ord_obj.payment_status,
            'items_count': ord_obj.items_count,
            'grand_total': float(ord_obj.grand_total or 0),
            'order_source': ord_obj.order_source,
        }

    def get_linked_order_code(self, obj):
        if obj.linked_order:
            return obj.linked_order.order_code
        return None

    def get_is_expired(self, obj):
        try:
            return bool(obj.is_expired)
        except Exception:
            try:
                from django.utils import timezone
                from django.utils.dateparse import parse_date
                exp = obj.expiry_date
                if isinstance(exp, str):
                    exp = parse_date(exp.strip().split('T')[0])
                elif isinstance(exp, datetime.datetime):
                    exp = exp.date()
                if not exp:
                    return False
                return timezone.now().date() >= exp
            except Exception:
                return False

    def to_representation(self, instance):
        ret = super().to_representation(instance)
        request = self.context.get('request')
        if request and hasattr(request, 'user'):
            user = request.user
            is_admin = user.is_superuser or (hasattr(user, 'profile') and user.profile.role in ['super_admin', 'admin'])
            if not is_admin:
                ret.pop('unit_production_cost', None)
        return ret


class DealerStockBatchSerializer(serializers.ModelSerializer):
    product_name = serializers.CharField(source='product.name', read_only=True)
    product_sku = serializers.CharField(source='product.sku', read_only=True)
    dealer_name = serializers.CharField(source='dealer.business_name', read_only=True)
    available_quantity = serializers.IntegerField(read_only=True)
    is_expired = serializers.SerializerMethodField()

    class Meta:
        model = DealerStockBatch
        fields = [
            'id',
            'dealer',
            'dealer_name',
            'product',
            'product_name',
            'product_sku',
            'batch_number',
            'manufacture_date',
            'expiry_date',
            'received_quantity',
            'remaining_quantity',
            'reserved_quantity',
            'available_quantity',
            'damaged_quantity',
            'unit_transfer_price',
            'is_active',
            'is_expired',
            'created_at',
            'updated_at',
        ]

    def get_is_expired(self, obj):
        try:
            return bool(obj.is_expired)
        except Exception:
            try:
                from django.utils import timezone
                from django.utils.dateparse import parse_date
                exp = obj.expiry_date
                if isinstance(exp, str):
                    exp = parse_date(exp.strip().split('T')[0])
                elif isinstance(exp, datetime.datetime):
                    exp = exp.date()
                if not exp:
                    return False
                return timezone.now().date() >= exp
            except Exception:
                return False


class DealerStockRequestAllocationSerializer(serializers.ModelSerializer):
    batch_number = serializers.CharField(source='production_batch.batch_number', read_only=True)
    expiry_date = serializers.SerializerMethodField()

    class Meta:
        model = DealerStockRequestAllocation
        fields = [
            'id',
            'stock_request',
            'production_batch',
            'batch_number',
            'expiry_date',
            'allocated_quantity',
            'prepared_quantity',
            'dispatched_quantity',
            'received_quantity',
            'damaged_quantity',
            'created_at',
            'updated_at',
        ]

    def get_expiry_date(self, obj):
        try:
            exp = obj.production_batch.expiry_date
            if not exp:
                return None
            if isinstance(exp, str):
                from django.utils.dateparse import parse_date
                exp = parse_date(exp.strip().split('T')[0])
            elif isinstance(exp, datetime.datetime):
                exp = exp.date()
            return exp.isoformat() if exp else None
        except Exception:
            return None

class DealerStockRequestSerializer(serializers.ModelSerializer):
    dealer_name = serializers.CharField(source='dealer.business_name', read_only=True)
    dealer_code = serializers.CharField(source='dealer.dealer_code', read_only=True)
    product_name = serializers.CharField(source='product.name', read_only=True)
    product_sku = serializers.CharField(source='product.sku', read_only=True)
    allocations = DealerStockRequestAllocationSerializer(many=True, read_only=True)
    pending_dispatch_quantity = serializers.IntegerField(read_only=True)
    pending_approval_quantity = serializers.IntegerField(read_only=True)

    class Meta:
        model = DealerStockRequest
        fields = [
            'id',
            'request_number',
            'dealer',
            'dealer_name',
            'dealer_code',
            'product',
            'product_name',
            'product_sku',
            'requested_quantity',
            'approved_quantity',
            'prepared_quantity',
            'dispatched_quantity',
            'received_quantity',
            'damaged_in_transit_quantity',
            'pending_dispatch_quantity',
            'pending_approval_quantity',
            'status',
            'dealer_notes',
            'admin_notes',
            'received_at',
            'created_at',
            'allocations',
        ]


class InventoryTransactionLedgerSerializer(serializers.ModelSerializer):
    product_name = serializers.CharField(source='product.name', read_only=True)
    raw_material_name = serializers.CharField(source='raw_material.name', read_only=True)
    dealer_name = serializers.CharField(source='dealer.business_name', read_only=True)
    actor_name = serializers.CharField(source='actor.get_full_name', read_only=True)

    class Meta:
        model = InventoryTransactionLedger
        fields = [
            'transaction_id',
            'transaction_type',
            'material_type',
            'location_type',
            'dealer',
            'dealer_name',
            'product',
            'product_name',
            'raw_material',
            'raw_material_name',
            'production_batch',
            'dealer_batch',
            'quantity',
            'balance_after',
            'unit_cost_or_price',
            'reference_type',
            'reference_id',
            'actor',
            'actor_name',
            'notes',
            'timestamp',
        ]

    def to_representation(self, instance):
        ret = super().to_representation(instance)
        request = self.context.get('request')
        if request and hasattr(request, 'user'):
            user = request.user
            is_admin = user.is_superuser or (hasattr(user, 'profile') and user.profile.role in ['super_admin', 'admin'])
            if not is_admin:
                ret.pop('unit_cost_or_price', None)
        return ret


class ExpenseSerializer(serializers.ModelSerializer):
    recorded_by_name = serializers.CharField(source='recorded_by.get_full_name', read_only=True)

    class Meta:
        model = Expense
        fields = [
            'id',
            'expense_number',
            'category',
            'description',
            'amount',
            'payment_method',
            'receipt_image',
            'paid_date',
            'recorded_by',
            'recorded_by_name',
            'created_at',
        ]


class DailyBusinessReportSerializer(serializers.ModelSerializer):
    # ── Flutter-compatible aliases ───────────────────────────────────────────
    # The model uses verbose field names (total_gross_revenue_inr etc.) but
    # the Flutter screen and synthetic report entries expect the short names.
    gross_revenue = serializers.SerializerMethodField()
    cogs = serializers.SerializerMethodField()
    total_operating_expenses = serializers.SerializerMethodField()
    net_profit_or_loss = serializers.SerializerMethodField()
    total_units_produced = serializers.SerializerMethodField()
    total_units_dispatched = serializers.SerializerMethodField()
    direct_company_revenue = serializers.SerializerMethodField()
    franchise_revenue = serializers.SerializerMethodField()
    gross_profit = serializers.SerializerMethodField()

    class Meta:
        model = DailyBusinessReport
        fields = '__all__'

    def get_gross_revenue(self, obj):
        return float(obj.total_gross_revenue_inr or 0)

    def get_cogs(self, obj):
        return float(obj.total_cogs_inr or 0)

    def get_total_operating_expenses(self, obj):
        return float(obj.total_expenses_inr or 0)

    def get_net_profit_or_loss(self, obj):
        return float(obj.net_profit_inr or 0)

    def get_total_units_produced(self, obj):
        return int(obj.total_production_volume_units or 0)

    def get_total_units_dispatched(self, obj):
        return int(obj.total_dealer_dispatch_units or 0)

    def get_direct_company_revenue(self, obj):
        return float(obj.total_direct_company_revenue_inr or 0)

    def get_franchise_revenue(self, obj):
        return float(obj.total_dealer_sales_revenue_inr or 0)

    def get_gross_profit(self, obj):
        gross = float(obj.total_gross_revenue_inr or 0)
        cogs = float(obj.total_cogs_inr or 0)
        return round(gross - cogs, 2)

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


class ProductionBatchSerializer(serializers.ModelSerializer):
    product_name = serializers.CharField(source='product.name', read_only=True)
    product_sku = serializers.CharField(source='product.sku', read_only=True)
    available_quantity = serializers.IntegerField(read_only=True)
    is_expired = serializers.SerializerMethodField()
    linked_order_code = serializers.SerializerMethodField()
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
    class Meta:
        model = DailyBusinessReport
        fields = '__all__'
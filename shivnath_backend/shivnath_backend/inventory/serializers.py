from rest_framework import serializers

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
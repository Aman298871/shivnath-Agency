from rest_framework import serializers

from .models import Order, OrderItem, OrderStatusHistory


class OrderItemSerializer(serializers.ModelSerializer):
    class Meta:
        model = OrderItem
        fields = [
            'id',
            'product',
            'product_name',
            'size',
            'quantity',
            'unit_price',
            'total_price',
        ]


class OrderSerializer(serializers.ModelSerializer):

    order_id = serializers.CharField(
        source='order_code',
        read_only=True,
    )

    status_display = serializers.CharField(
        source='get_status_display',
        read_only=True,
    )

    payment_display = serializers.CharField(
        source='get_payment_status_display',
        read_only=True,
    )

    created_by_name = serializers.SerializerMethodField()
    serving_franchise_name = serializers.SerializerMethodField()
    registered_franchise_name = serializers.SerializerMethodField()
    zone_name = serializers.SerializerMethodField()
    items = OrderItemSerializer(many=True, read_only=True)

    class Meta:
        model = Order

        fields = [
            'id',
            'order_id',

            'franchise_name',
            'serving_franchise',
            'serving_franchise_name',
            'registered_franchise',
            'registered_franchise_name',
            'zone',
            'zone_name',
            'city',
            'territory',
            'delivery_address',
            'order_source',

            'order_date',
            'duration_choice',
            'duration_days',
            'expected_end_date',

            'items_count',
            'amount',

            'status',
            'status_display',

            'payment_status',
            'payment_display',

            'created_by',
            'created_by_name',
            'items',

            'created_at',
            'updated_at',
        ]

        read_only_fields = [
            'id',
            'order_id',
            'order_date',
            'status_display',
            'payment_display',
            'created_by',
            'created_by_name',
            'serving_franchise_name',
            'registered_franchise_name',
            'zone_name',
            'items',
            'created_at',
            'updated_at',
        ]

    def get_serving_franchise_name(self, obj):
        if obj.serving_franchise:
            return obj.serving_franchise.business_name
        return obj.franchise_name or ''

    def get_registered_franchise_name(self, obj):
        if obj.registered_franchise:
            return obj.registered_franchise.business_name
        return ''

    def get_zone_name(self, obj):
        if obj.zone:
            return obj.zone.name
        return ''

    def get_created_by_name(self, obj):
        if not obj.created_by:
            return ''

        return (
            obj.created_by.get_full_name()
            or obj.created_by.username
        )

    def validate_franchise_name(self, value):
        value = value.strip()

        if not value:
            raise serializers.ValidationError(
                'Franchise name is required.'
            )

        return value

    def validate_city(self, value):
        value = value.strip()

        if not value:
            raise serializers.ValidationError(
                'City is required.'
            )

        return value

    def validate_items_count(self, value):
        if value < 0:
            raise serializers.ValidationError(
                'Items count cannot be negative.'
            )
        return value

    def validate_amount(self, value):
        if value < 0:
            raise serializers.ValidationError(
                'Amount cannot be negative.'
            )
        return value
from rest_framework import serializers

from .models import Order, OrderItem, OrderStatusHistory


class OrderItemSerializer(serializers.ModelSerializer):
    sku = serializers.CharField(source='product.sku', read_only=True)
    product_sku = serializers.CharField(source='product.sku', read_only=True)

    class Meta:
        model = OrderItem
        fields = [
            'id',
            'product',
            'sku',
            'product_sku',
            'product_name',
            'size',
            'quantity',
            'unit_price',
            'total_price',
        ]


class OrderStatusHistorySerializer(serializers.ModelSerializer):
    changed_by_name = serializers.SerializerMethodField()

    class Meta:
        model = OrderStatusHistory
        fields = [
            'id',
            'old_status',
            'new_status',
            'changed_by',
            'changed_by_name',
            'notes',
            'created_at',
        ]

    def get_changed_by_name(self, obj):
        if not obj.changed_by:
            return 'System'
        return obj.changed_by.get_full_name() or obj.changed_by.username


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
    customer_name = serializers.SerializerMethodField()
    customer_phone = serializers.SerializerMethodField()
    customer_email = serializers.SerializerMethodField()
    serving_franchise_name = serializers.SerializerMethodField()
    registered_franchise_name = serializers.SerializerMethodField()
    zone_name = serializers.SerializerMethodField()
    items = OrderItemSerializer(many=True, read_only=True)
    status_history = OrderStatusHistorySerializer(many=True, read_only=True)

    amount_paid = serializers.SerializerMethodField()
    outstanding_balance = serializers.SerializerMethodField()
    outstanding_amount = serializers.SerializerMethodField()

    previous_outstanding = serializers.SerializerMethodField()
    current_order_amount = serializers.SerializerMethodField()
    total_exposure = serializers.SerializerMethodField()
    credit_limit = serializers.SerializerMethodField()
    payment_terms_days = serializers.SerializerMethodField()
    credit_status = serializers.SerializerMethodField()

    class Meta:
        model = Order

        fields = [
            'id',
            'order_id',
            'amount_paid',
            'outstanding_balance',
            'outstanding_amount',

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

            'client_name',
            'customer_name',
            'customer_phone',
            'customer_email',
            'label_requirement',
            'printing_requirement',
            'branding_requirement',
            'custom_shelf_life_days',
            'total_produced_units',
            'total_delivered_units',
            'total_pending_stock_units',

            'order_date',
            'duration_choice',
            'duration_days',
            'expected_end_date',

            'items_count',
            'amount',

            'previous_outstanding',
            'current_order_amount',
            'total_exposure',
            'credit_limit',
            'payment_terms_days',
            'credit_status',

            'status',
            'status_display',

            'payment_status',
            'payment_display',

            'created_by',
            'created_by_name',
            'items',
            'status_history',

            'created_at',
            'updated_at',
        ]

        read_only_fields = [
            'id',
            'order_id',
            'order_date',
            'previous_outstanding',
            'current_order_amount',
            'total_exposure',
            'credit_limit',
            'payment_terms_days',
            'credit_status',
            'amount_paid',
            'outstanding_balance',
            'outstanding_amount',
            'status_display',
            'payment_display',
            'created_by',
            'created_by_name',
            'customer_name',
            'customer_phone',
            'customer_email',
            'serving_franchise_name',
            'registered_franchise_name',
            'zone_name',
            'items',
            'status_history',
            'created_at',
            'updated_at',
        ]

    def get_customer_name(self, obj):
        if obj.created_by:
            name = obj.created_by.get_full_name() or obj.created_by.username
            if name:
                return name
        return obj.client_name or obj.franchise_name or 'Customer'

    def get_customer_phone(self, obj):
        if obj.created_by:
            prof = getattr(obj.created_by, 'profile', None)
            if prof and prof.phone:
                return prof.phone
        return ''

    def get_customer_email(self, obj):
        if obj.created_by:
            return obj.created_by.email or ''
        return ''

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

    def get_previous_outstanding(self, obj):
        try:
            from billing.models import Invoice
            if obj.serving_franchise:
                cp = getattr(obj.serving_franchise, 'credit_profile', None)
                if cp:
                    return float(cp.current_outstanding)
            if obj.created_by:
                invs = Invoice.objects.filter(
                    order__created_by=obj.created_by
                ).exclude(order_id=obj.id).exclude(status__in=['PAID', 'CANCELLED'])
                total_prev = sum(float(inv.outstanding_balance) for inv in invs)
                return round(total_prev, 2)
        except Exception:
            pass
        return 0.0

    def get_current_order_amount(self, obj):
        return round(float(obj.amount or 0.0), 2)

    def get_total_exposure(self, obj):
        prev = self.get_previous_outstanding(obj)
        curr = self.get_current_order_amount(obj)
        return round(prev + curr, 2)

    def get_amount_paid(self, obj):
        if hasattr(obj, 'invoice') and obj.invoice:
            return float(obj.invoice.amount_paid)
        return 0.0

    def get_outstanding_balance(self, obj):
        if hasattr(obj, 'invoice') and obj.invoice:
            return float(obj.invoice.outstanding_balance)
        return float(obj.grand_total or obj.amount or 0.0)

    def get_outstanding_amount(self, obj):
        return self.get_outstanding_balance(obj)

    def get_credit_limit(self, obj):
        if obj.serving_franchise:
            cp = getattr(obj.serving_franchise, 'credit_profile', None)
            if cp:
                return float(cp.credit_limit)
        return 0.0

    def get_payment_terms_days(self, obj):
        if obj.serving_franchise:
            cp = getattr(obj.serving_franchise, 'credit_profile', None)
            if cp:
                return cp.payment_terms_days
        return 15

    def get_credit_status(self, obj):
        if obj.serving_franchise:
            cp = getattr(obj.serving_franchise, 'credit_profile', None)
            if cp:
                return cp.credit_status
        return 'GOOD_STANDING'

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

    def to_representation(self, instance):
        data = super().to_representation(instance)
        # Authoritative franchise name: always show serving/registered franchise business name, never customer name
        if instance.serving_franchise:
            data['franchise_name'] = instance.serving_franchise.business_name
        elif instance.registered_franchise:
            data['franchise_name'] = instance.registered_franchise.business_name
        elif instance.order_source == 'DIRECT_COMPANY':
            data['franchise_name'] = 'Shivnath Agency (Direct)'
        else:
            fn = str(data.get('franchise_name') or '').strip()
            cust = str(data.get('customer_name') or '').strip()
            if not fn or fn.lower() == cust.lower() or fn.lower() == 'customer order':
                data['franchise_name'] = 'Shivnath Agency (Direct)'
        return data
from decimal import Decimal
from rest_framework import serializers
from billing.models import CompanyBillingProfile, DealerCreditProfile, Invoice, PaymentTransaction


class CompanyBillingProfileSerializer(serializers.ModelSerializer):
    class Meta:
        model = CompanyBillingProfile
        fields = '__all__'


class DealerCreditProfileSerializer(serializers.ModelSerializer):
    dealer = serializers.PrimaryKeyRelatedField(read_only=True)
    dealer_name = serializers.CharField(source='dealer.business_name', read_only=True)
    dealer_code = serializers.CharField(source='dealer.dealer_code', read_only=True)
    current_balance = serializers.DecimalField(source='current_outstanding', max_digits=12, decimal_places=2, read_only=True)
    available_credit = serializers.SerializerMethodField()

    def get_available_credit(self, obj):
        limit = obj.credit_limit or Decimal('0.00')
        out = obj.current_outstanding or Decimal('0.00')
        return max(Decimal('0.00'), limit - out)

    class Meta:
        model = DealerCreditProfile
        fields = [
            'id',
            'dealer',
            'dealer_name',
            'dealer_code',
            'credit_limit',
            'payment_terms_days',
            'current_outstanding',
            'current_balance',
            'available_credit',
            'credit_status',
            'last_payment_date',
            'updated_at',
        ]


class PaymentTransactionSerializer(serializers.ModelSerializer):
    recorded_by_name = serializers.CharField(source='received_by.get_full_name', read_only=True)
    invoice_number = serializers.CharField(source='invoice.invoice_number', read_only=True)
    order_code = serializers.SerializerMethodField()
    franchise_name = serializers.SerializerMethodField()

    def get_order_code(self, obj):
        if obj.invoice and obj.invoice.order:
            return obj.invoice.order.order_code
        return ''

    def get_franchise_name(self, obj):
        if not obj.invoice:
            return 'Shivnath Central'
        inv = obj.invoice
        if inv.order and inv.order.order_source == 'DIRECT_COMPANY':
            return 'Direct (Shivnath)'
        if inv.stock_request and inv.stock_request.dealer:
            return inv.stock_request.dealer.business_name
        if inv.order and inv.order.serving_franchise:
            return inv.order.serving_franchise.business_name
        if obj.received_by and hasattr(obj.received_by, 'franchise_profile'):
            return obj.received_by.franchise_profile.business_name
        if inv.invoice_type == 'DEALER_PURCHASE_INVOICE':
            return inv.billed_to_name or 'Dealer'
        return 'Direct (Shivnath)'

    class Meta:
        model = PaymentTransaction
        fields = [
            'id',
            'transaction_number',
            'invoice',
            'invoice_number',
            'order_code',
            'franchise_name',
            'payment_method',
            'amount_paid',
            'reference_number',
            'payment_status',
            'receipt_file',
            'received_by',
            'recorded_by_name',
            'notes',
            'payment_date',
        ]


class InvoiceSerializer(serializers.ModelSerializer):
    payments = PaymentTransactionSerializer(many=True, read_only=True)
    outstanding_balance = serializers.DecimalField(max_digits=12, decimal_places=2, read_only=True)
    total_amount = serializers.DecimalField(source='grand_total', max_digits=12, decimal_places=2, read_only=True)
    invoice_date = serializers.DateTimeField(source='issued_at', read_only=True)
    dealer_name = serializers.SerializerMethodField()
    franchise_name = serializers.SerializerMethodField()
    customer_name = serializers.SerializerMethodField()
    order_source = serializers.SerializerMethodField()
    order_number = serializers.SerializerMethodField()
    latest_pending_payment = serializers.SerializerMethodField()

    class Meta:
        model = Invoice
        fields = [
            'id',
            'invoice_number',
            'order',
            'order_number',
            'order_source',
            'stock_request',
            'invoice_type',
            'billed_to_name',
            'billed_to_gstin',
            'billed_to_address',
            'customer_name',
            'dealer_name',
            'franchise_name',
            'subtotal',
            'cgst_amount',
            'sgst_amount',
            'igst_amount',
            'delivery_charges',
            'discount_amount',
            'points_discount_amount',
            'wallet_amount_debited',
            'grand_total',
            'total_amount',
            'amount_paid',
            'outstanding_balance',
            'status',
            'is_gst_invoice',
            'place_of_supply',
            'state_code',
            'financial_snapshot',
            'issued_at',
            'invoice_date',
            'due_date',
            'payments',
            'latest_pending_payment',
        ]

    def get_order_number(self, obj):
        if obj.order:
            return obj.order.order_code
        return ''

    def get_order_source(self, obj):
        if obj.order:
            return obj.order.order_source
        return 'DIRECT_COMPANY' if obj.invoice_type == 'DIRECT_COMPANY_SALE_INVOICE' else 'FRANCHISE'

    def get_customer_name(self, obj):
        return obj.billed_to_name or (
            obj.order.created_by.get_full_name() if obj.order and obj.order.created_by else 'Customer'
        )

    def get_franchise_name(self, obj):
        if obj.order:
            if obj.order.order_source == 'DIRECT_COMPANY':
                return None
            if obj.order.serving_franchise:
                return obj.order.serving_franchise.business_name
            if obj.order.franchise_name and 'Shivnath' not in obj.order.franchise_name and 'Direct' not in obj.order.franchise_name:
                return obj.order.franchise_name
            return None
        if obj.stock_request and obj.stock_request.dealer:
            return obj.stock_request.dealer.business_name
        if obj.invoice_type == 'DEALER_PURCHASE_INVOICE':
            return obj.billed_to_name
        return None

    def get_dealer_name(self, obj):
        return self.get_franchise_name(obj)

    def get_latest_pending_payment(self, obj):
        pending = obj.payments.filter(payment_status='PENDING').order_by('-payment_date').first()
        if pending:
            return PaymentTransactionSerializer(pending).data
        return None

    def to_representation(self, instance):
        ret = super().to_representation(instance)
        try:
            amt_paid = Decimal(str(ret.get('amount_paid') or '0.00'))
            grand_tot = Decimal(str(ret.get('grand_total') or '0.00'))
            is_order_paid = False
            if instance.order and getattr(instance.order, 'payment_status', '').lower() == 'paid':
                is_order_paid = True
            if grand_tot > Decimal('0.00') and (amt_paid >= grand_tot or is_order_paid or (grand_tot - amt_paid) <= Decimal('0.05')):
                ret['status'] = 'PAID'
                ret['amount_paid'] = str(grand_tot)
                ret['outstanding_balance'] = '0.00'
            elif amt_paid > Decimal('0.00') and ret.get('status') == 'UNPAID':
                ret['status'] = 'PARTIALLY_PAID'
        except Exception:
            pass
        return ret


class DeliveryOriginSettingSerializer(serializers.ModelSerializer):
    class Meta:
        from billing.models import DeliveryOriginSetting
        model = DeliveryOriginSetting
        fields = [
            'id',
            'name',
            'address',
            'latitude',
            'longitude',
            'phone',
            'is_active',
            'updated_at',
        ]
        read_only_fields = ['id', 'updated_at']


class DeliveryDistanceBandSerializer(serializers.ModelSerializer):
    class Meta:
        from billing.models import DeliveryDistanceBand
        model = DeliveryDistanceBand
        fields = [
            'id',
            'name',
            'min_distance_km',
            'max_distance_km',
            'delivery_charge',
            'is_active',
            'is_supported',
            'applies_to',
            'order',
            'created_at',
            'updated_at',
        ]
        read_only_fields = ['id', 'created_at', 'updated_at']


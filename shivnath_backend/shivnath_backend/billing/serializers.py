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
            return 'Franchise'
        inv = obj.invoice
        if inv.stock_request and inv.stock_request.dealer:
            return inv.stock_request.dealer.business_name
        if inv.order and inv.order.serving_franchise:
            return inv.order.serving_franchise.business_name
        if obj.received_by and hasattr(obj.received_by, 'franchise_profile'):
            return obj.received_by.franchise_profile.business_name
        return inv.billed_to_name or 'Franchise'

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
    dealer_name = serializers.CharField(source='billed_to_name', read_only=True)
    franchise_name = serializers.CharField(source='billed_to_name', read_only=True)
    latest_pending_payment = serializers.SerializerMethodField()

    class Meta:
        model = Invoice
        fields = [
            'id',
            'invoice_number',
            'order',
            'stock_request',
            'invoice_type',
            'billed_to_name',
            'billed_to_gstin',
            'billed_to_address',
            'dealer_name',
            'franchise_name',
            'subtotal',
            'cgst_amount',
            'sgst_amount',
            'igst_amount',
            'grand_total',
            'total_amount',
            'amount_paid',
            'outstanding_balance',
            'status',
            'issued_at',
            'invoice_date',
            'due_date',
            'payments',
            'latest_pending_payment',
        ]

    def get_latest_pending_payment(self, obj):
        pending = obj.payments.filter(payment_status='PENDING').order_by('-payment_date').first()
        if pending:
            return PaymentTransactionSerializer(pending).data
        return None

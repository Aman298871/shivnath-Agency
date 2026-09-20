from rest_framework import serializers
from billing.models import CompanyBillingProfile, DealerCreditProfile, Invoice, PaymentTransaction


class CompanyBillingProfileSerializer(serializers.ModelSerializer):
    class Meta:
        model = CompanyBillingProfile
        fields = '__all__'


class DealerCreditProfileSerializer(serializers.ModelSerializer):
    dealer_name = serializers.CharField(source='dealer.business_name', read_only=True)
    dealer_code = serializers.CharField(source='dealer.dealer_code', read_only=True)

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
            'credit_status',
            'last_payment_date',
            'updated_at',
        ]


class PaymentTransactionSerializer(serializers.ModelSerializer):
    recorded_by_name = serializers.CharField(source='received_by.get_full_name', read_only=True)

    class Meta:
        model = PaymentTransaction
        fields = [
            'id',
            'transaction_number',
            'invoice',
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
            'subtotal',
            'cgst_amount',
            'sgst_amount',
            'igst_amount',
            'grand_total',
            'amount_paid',
            'outstanding_balance',
            'status',
            'issued_at',
            'due_date',
            'payments',
        ]

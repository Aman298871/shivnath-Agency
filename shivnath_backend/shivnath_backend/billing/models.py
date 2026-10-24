from decimal import Decimal
from django.db import models
from django.contrib.auth.models import User
import uuid


class CompanyBillingProfile(models.Model):
    """
    Authoritative company billing/tax configuration for Shivnath Agency.
    Governs invoice prefixes, registered address, GSTIN, PAN, and tax percentages.
    """
    legal_name = models.CharField(max_length=255, blank=True, default='')
    trade_name = models.CharField(max_length=255, blank=True, default='')
    gstin = models.CharField(max_length=30, blank=True, default='')
    pan = models.CharField(max_length=20, blank=True, default='')
    registered_address = models.TextField(blank=True, default='')
    state_name = models.CharField(max_length=100, blank=True, default='')
    state_code = models.CharField(max_length=10, blank=True, default='')
    invoice_prefix = models.CharField(max_length=30, default='SHV/2026/')
    cgst_rate = models.DecimalField(max_digits=5, decimal_places=2, default=Decimal('9.00'))
    sgst_rate = models.DecimalField(max_digits=5, decimal_places=2, default=Decimal('9.00'))
    igst_rate = models.DecimalField(max_digits=5, decimal_places=2, default=Decimal('18.00'))
    bank_name = models.CharField(max_length=150, blank=True, default='')
    bank_account_number = models.CharField(max_length=50, blank=True, default='')
    bank_ifsc_code = models.CharField(max_length=30, blank=True, default='')
    upi_id = models.CharField(max_length=100, blank=True, default='')
    phone = models.CharField(max_length=20, blank=True, default='')
    email = models.EmailField(blank=True, default='')
    is_configured = models.BooleanField(default=False)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = 'Company Billing Profile'
        verbose_name_plural = 'Company Billing Profiles'

    def __str__(self):
        return f"{self.trade_name or self.legal_name or 'Unconfigured Company Profile'} ({self.gstin or 'No GST'})"


class DeliveryOriginSetting(models.Model):
    """
    Authoritative dispatch origin for distance-based delivery calculations.
    """
    name = models.CharField(max_length=150, default="Shivnath Agency Central Dispatch")
    address = models.TextField(default="Ekta Nagar, Pragati Nagar, LIC Colony, near Mowa Thana, Raipur, Chhattisgarh")
    latitude = models.DecimalField(max_digits=9, decimal_places=6, default=Decimal('21.267800'), help_text="Origin Latitude")
    longitude = models.DecimalField(max_digits=9, decimal_places=6, default=Decimal('81.671100'), help_text="Origin Longitude")
    phone = models.CharField(max_length=20, blank=True, default='')
    is_active = models.BooleanField(default=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = 'Delivery Origin Setting'
        verbose_name_plural = 'Delivery Origin Settings'

    def __str__(self):
        return f"{self.name} ({self.latitude}, {self.longitude}) [{'Active' if self.is_active else 'Inactive'}]"

    @classmethod
    def get_active_origin(cls):
        origin = cls.objects.filter(is_active=True).first()
        if not origin:
            origin = cls.objects.create(
                name="Shivnath Agency Central Dispatch",
                address="Ekta Nagar, Pragati Nagar, LIC Colony, near Mowa Thana, Raipur, Chhattisgarh",
                latitude=Decimal('21.267800'),
                longitude=Decimal('81.671100'),
                is_active=True
            )
        return origin


class DeliveryDistanceBand(models.Model):
    """
    Admin-configurable distance bands and delivery pricing.
    Example:
    0 to 2 km: ₹30
    >2 to 5 km: ₹60
    >5 to 10 km: ₹120
    >10 km: Unsupported / Custom Admin quote
    """
    CHANNEL_CHOICES = [
        ('ALL', 'All Orders'),
        ('CUSTOMER', 'Customer Orders Only'),
        ('FRANCHISE', 'Franchise Orders Only'),
    ]

    name = models.CharField(max_length=100, help_text="e.g. '0-2 km Standard Local Delivery'")
    min_distance_km = models.DecimalField(max_digits=6, decimal_places=2, default=Decimal('0.00'), help_text="Lower bound in km (inclusive for band 0, exclusive for higher bands)")
    max_distance_km = models.DecimalField(max_digits=6, decimal_places=2, null=True, blank=True, help_text="Upper bound in km (null for open-ended final band)")
    delivery_charge = models.DecimalField(max_digits=8, decimal_places=2, default=Decimal('0.00'), help_text="Authoritative delivery fee in INR")
    is_active = models.BooleanField(default=True)
    is_supported = models.BooleanField(default=True, help_text="Set to False if orders beyond this distance are not serviceable")
    applies_to = models.CharField(max_length=20, choices=CHANNEL_CHOICES, default='ALL')
    order = models.PositiveIntegerField(default=0, help_text="Display/evaluation order")
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['order', 'min_distance_km']
        verbose_name = 'Delivery Distance Band'
        verbose_name_plural = 'Delivery Distance Bands'

    def __str__(self):
        upper = f"{self.max_distance_km} km" if self.max_distance_km is not None else "Above"
        return f"{self.name}: {self.min_distance_km} to {upper} -> ₹{self.delivery_charge} ({self.applies_to})"


class DealerCreditProfile(models.Model):
    """
    Tracks credit limit, payment terms, and outstanding balances per wholesale dealer.
    """
    STATUS_CHOICES = [
        ('GOOD_STANDING', 'Good Standing'),
        ('PAYMENT_DUE', 'Payment Due'),
        ('CREDIT_BLOCKED', 'Credit Blocked'),
    ]

    dealer = models.OneToOneField(
        'accounts.FranchiseProfile',
        on_delete=models.CASCADE,
        related_name='credit_profile'
    )
    credit_limit = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        default=Decimal('0.00')
    )
    payment_terms_days = models.PositiveIntegerField(
        default=15,
        help_text="Configurable payment terms (e.g. 0/Immediate, 7, 15, 30, custom days)"
    )
    current_outstanding = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        default=Decimal('0.00')
    )

    credit_status = models.CharField(
        max_length=30,
        choices=STATUS_CHOICES,
        default='GOOD_STANDING'
    )
    last_payment_date = models.DateField(
        null=True,
        blank=True
    )
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = 'Dealer Credit Profile'
        verbose_name_plural = 'Dealer Credit Profiles'

    def __str__(self):
        return f"{self.dealer.business_name} - Outstanding: ₹{self.current_outstanding} / Limit: ₹{self.credit_limit} ({self.credit_status})"


class Invoice(models.Model):
    """
    Authoritative financial and billing record for customer sales and dealer wholesale stock transfers.
    """
    INVOICE_TYPE_CHOICES = [
        ('DEALER_PURCHASE_INVOICE', 'Dealer Purchase Invoice (Wholesale Transfer)'),
        ('CUSTOMER_SALE_INVOICE', 'Customer Sale Invoice (Dealer Fulfilled)'),
        ('DIRECT_COMPANY_SALE_INVOICE', 'Direct Company Sale Invoice'),
    ]

    STATUS_CHOICES = [
        ('UNPAID', 'Unpaid'),
        ('PARTIALLY_PAID', 'Partially Paid'),
        ('PAYMENT_PENDING_VERIFICATION', 'Payment Submitted (Pending Verification)'),
        ('PAID', 'Paid'),
        ('CANCELLED', 'Cancelled'),
    ]

    invoice_number = models.CharField(
        max_length=100,
        unique=True,
        db_index=True
    )
    order = models.OneToOneField(
        'orders.Order',
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name='invoice'
    )
    stock_request = models.OneToOneField(
        'inventory.DealerStockRequest',
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name='invoice'
    )
    invoice_type = models.CharField(
        max_length=40,
        choices=INVOICE_TYPE_CHOICES,
        default='CUSTOMER_SALE_INVOICE'
    )
    billed_to_name = models.CharField(max_length=255)
    billed_to_gstin = models.CharField(max_length=30, blank=True, default='')
    billed_to_address = models.TextField(blank=True, default='')
    subtotal = models.DecimalField(max_digits=12, decimal_places=2, default=0.00)
    cgst_amount = models.DecimalField(max_digits=12, decimal_places=2, default=0.00)
    sgst_amount = models.DecimalField(max_digits=12, decimal_places=2, default=0.00)
    igst_amount = models.DecimalField(max_digits=12, decimal_places=2, default=0.00)
    delivery_charges = models.DecimalField(max_digits=12, decimal_places=2, default=Decimal('0.00'))
    discount_amount = models.DecimalField(max_digits=12, decimal_places=2, default=Decimal('0.00'))
    points_discount_amount = models.DecimalField(max_digits=12, decimal_places=2, default=Decimal('0.00'))
    wallet_amount_debited = models.DecimalField(max_digits=12, decimal_places=2, default=Decimal('0.00'))
    grand_total = models.DecimalField(max_digits=12, decimal_places=2, default=0.00)
    amount_paid = models.DecimalField(max_digits=12, decimal_places=2, default=0.00)
    is_gst_invoice = models.BooleanField(default=False)
    place_of_supply = models.CharField(max_length=100, blank=True, default='Chhattisgarh')
    state_code = models.CharField(max_length=10, blank=True, default='22')
    financial_snapshot = models.JSONField(default=dict, blank=True)
    status = models.CharField(
        max_length=40,
        choices=STATUS_CHOICES,
        default='UNPAID'
    )
    issued_at = models.DateTimeField(auto_now_add=True)
    due_date = models.DateField(null=True, blank=True)

    class Meta:
        ordering = ['-issued_at']
        verbose_name = 'Invoice'
        verbose_name_plural = 'Invoices'

    def __str__(self):
        return f"{self.invoice_number} - {self.billed_to_name} (₹{self.grand_total}) [{self.status}]"

    @property
    def outstanding_balance(self):
        if self.status == 'PAID' or (self.grand_total - self.amount_paid) <= Decimal('0.05'):
            return Decimal('0.00')
        return max(Decimal('0.00'), self.grand_total - self.amount_paid)

    @property
    def order_source(self):
        return self.order.order_source if self.order else 'DIRECT_COMPANY'

    @property
    def serving_franchise(self):
        return self.order.serving_franchise if self.order else None

    @property
    def payment_status(self):
        return self.status


class PaymentTransaction(models.Model):
    """
    Authoritative payment receipt record. Updates Invoice and DealerCreditProfile atomically.
    """
    PAYMENT_METHOD_CHOICES = [
        ('CASH', 'Cash'),
        ('UPI', 'UPI'),
        ('RAZORPAY', 'Razorpay Online Payment'),
        ('NEFT_RTGS', 'NEFT / RTGS / Bank Transfer'),
        ('CHEQUE', 'Cheque'),
        ('CREDIT_ADJUSTMENT', 'Credit / Ledger Adjustment'),
    ]

    STATUS_CHOICES = [
        ('SUCCESS', 'Success'),
        ('PENDING', 'Pending Verification'),
        ('REJECTED', 'Rejected'),
        ('FAILED', 'Failed'),
    ]

    transaction_number = models.CharField(
        max_length=100,
        unique=True,
        db_index=True
    )
    invoice = models.ForeignKey(
        Invoice,
        on_delete=models.CASCADE,
        related_name='payments'
    )
    payment_method = models.CharField(
        max_length=30,
        choices=PAYMENT_METHOD_CHOICES,
        default='RAZORPAY'
    )
    amount_paid = models.DecimalField(
        max_digits=12,
        decimal_places=2
    )
    reference_number = models.CharField(
        max_length=100,
        blank=True,
        default='',
        help_text="UTR / Cheque No / Payment Gateway Reference ID"
    )
    razorpay_order_id = models.CharField(
        max_length=100,
        blank=True,
        default='',
        help_text="Razorpay Order ID"
    )
    razorpay_payment_id = models.CharField(
        max_length=100,
        blank=True,
        default='',
        help_text="Razorpay Payment ID"
    )
    razorpay_signature = models.CharField(
        max_length=255,
        blank=True,
        default='',
        help_text="Razorpay Signature"
    )
    payment_status = models.CharField(
        max_length=30,
        choices=STATUS_CHOICES,
        default='SUCCESS'
    )
    receipt_file = models.FileField(
        upload_to='payment_receipts/',
        null=True,
        blank=True
    )
    received_by = models.ForeignKey(
        User,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name='recorded_payments'
    )
    notes = models.TextField(blank=True, default='')
    payment_date = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-payment_date']
        verbose_name = 'Payment Transaction'
        verbose_name_plural = 'Payment Transactions'

    def __str__(self):
        return f"PAY-{self.transaction_number} -> {self.invoice.invoice_number} (₹{self.amount_paid}) [{self.payment_status}]"

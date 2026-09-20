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
    cgst_rate = models.DecimalField(max_digits=5, decimal_places=2, default=9.00)
    sgst_rate = models.DecimalField(max_digits=5, decimal_places=2, default=9.00)
    igst_rate = models.DecimalField(max_digits=5, decimal_places=2, default=18.00)
    bank_name = models.CharField(max_length=150, blank=True, default='')
    bank_account_number = models.CharField(max_length=50, blank=True, default='')
    bank_ifsc_code = models.CharField(max_length=30, blank=True, default='')
    upi_id = models.CharField(max_length=100, blank=True, default='')
    is_configured = models.BooleanField(default=False)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = 'Company Billing Profile'
        verbose_name_plural = 'Company Billing Profiles'

    def __str__(self):
        return f"{self.trade_name or self.legal_name or 'Unconfigured Company Profile'} ({self.gstin or 'No GST'})"


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
        default=0.00
    )
    payment_terms_days = models.PositiveIntegerField(
        default=15,
        help_text="Configurable payment terms (e.g. 0/Immediate, 7, 15, 30, custom days)"
    )
    current_outstanding = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        default=0.00
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
    grand_total = models.DecimalField(max_digits=12, decimal_places=2, default=0.00)
    amount_paid = models.DecimalField(max_digits=12, decimal_places=2, default=0.00)
    status = models.CharField(
        max_length=20,
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
        return max(0, self.grand_total - self.amount_paid)


class PaymentTransaction(models.Model):
    """
    Authoritative payment receipt record. Updates Invoice and DealerCreditProfile atomically.
    """
    PAYMENT_METHOD_CHOICES = [
        ('CASH', 'Cash'),
        ('UPI', 'UPI'),
        ('NEFT_RTGS', 'NEFT / RTGS / Bank Transfer'),
        ('CHEQUE', 'Cheque'),
        ('CREDIT_ADJUSTMENT', 'Credit / Ledger Adjustment'),
    ]

    STATUS_CHOICES = [
        ('SUCCESS', 'Success'),
        ('PENDING', 'Pending Verification'),
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
        default='UPI'
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
    payment_status = models.CharField(
        max_length=20,
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

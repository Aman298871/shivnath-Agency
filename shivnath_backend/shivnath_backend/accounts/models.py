from django.db import models
from django.contrib.auth.models import User


class UserProfile(models.Model):

    ROLE_CHOICES = [
        ('super_admin', 'Super Admin'),
        ('admin', 'Admin'),
        ('sales_executive', 'Sales Executive'),
        ('customer', 'Customer'),
        ('franchise', 'Franchise'),
        ('staff', 'Staff'),
    ]

    STATUS_CHOICES = [
        ('active', 'Active'),
        ('inactive', 'Inactive'),
        ('pending', 'Pending'),
    ]

    DATA_SCOPE_CHOICES = [
        ('all_data', 'All Data'),
        ('territory_scoped', 'Territory Scoped'),
        ('dealer_scoped', 'Dealer Scoped'),
        ('plant_scoped', 'Plant Scoped'),
    ]

    user = models.OneToOneField(
        User,
        on_delete=models.CASCADE,
        related_name='profile'
    )

    name = models.CharField(
        max_length=150,
        blank=True,
        default=''
    )

    phone = models.CharField(
        max_length=15,
        blank=True
    )

    city = models.CharField(
        max_length=100,
        blank=True,
        default=''
    )

    district = models.CharField(
        max_length=100,
        blank=True,
        default=''
    )

    address = models.TextField(
        blank=True,
        default=''
    )

    pincode = models.CharField(
        max_length=10,
        blank=True,
        default=''
    )

    locality = models.CharField(
        max_length=150,
        blank=True,
        default=''
    )

    territory = models.CharField(
        max_length=150,
        blank=True,
        default=''
    )

    zone = models.ForeignKey(
        'ServiceZone',
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name='user_profiles'
    )

    status = models.CharField(
        max_length=20,
        choices=STATUS_CHOICES,
        default='active'
    )

    role = models.CharField(
        max_length=20,
        choices=ROLE_CHOICES,
        default='customer'
    )

    admin_permissions = models.JSONField(
        default=list,
        blank=True,
        help_text="List of granular permissions for operational admins"
    )

    data_scope_type = models.CharField(
        max_length=30,
        choices=DATA_SCOPE_CHOICES,
        default='all_data',
        help_text="Backend data scope boundary for queries"
    )

    assigned_scope_ids = models.JSONField(
        default=list,
        blank=True,
        help_text="Territory/Dealer/Plant IDs authorized for this user"
    )

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f'{self.user.email} - {self.role}'


class AdminNotification(models.Model):
    NOTIFICATION_TYPES = [
        ('customer_registration', 'Customer Registration'),
        ('franchise_registration', 'Franchise Registration'),
        ('order_placed', 'Order Placed'),
        ('bulk_order', 'Bulk Order Placed'),
        ('stock_alert', 'Stock Alert'),
        ('service_status', 'Service Status Update'),
        ('payment_verification', 'Payment Verification Required'),
        ('general', 'General'),
    ]

    title = models.CharField(max_length=200)
    message = models.TextField()
    notification_type = models.CharField(
        max_length=40,
        choices=NOTIFICATION_TYPES,
        default='customer_registration'
    )
    reference_id = models.PositiveIntegerField(null=True, blank=True)
    is_read = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['-created_at']),
            models.Index(fields=['is_read']),
            models.Index(fields=['notification_type']),
        ]

    def __str__(self):
        return f'{self.title} - {self.created_at.strftime("%d/%m/%Y %H:%M")}'


class DeviceToken(models.Model):
    user = models.ForeignKey(
        'auth.User',
        on_delete=models.CASCADE,
        related_name='device_tokens'
    )
    token = models.CharField(max_length=255, unique=True)
    device_type = models.CharField(
        max_length=20,
        default='android',
        choices=[('android', 'Android'), ('ios', 'iOS'), ('web', 'Web')]
    )
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-updated_at']
        indexes = [
            models.Index(fields=['user', 'is_active']),
            models.Index(fields=['token']),
        ]

    def __str__(self):
        return f"{self.user.username} ({self.device_type}) - {self.token[:12]}..."



class FranchiseProfile(models.Model):
    STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('under_review', 'Under Review'),
        ('approved', 'Approved'),
        ('rejected', 'Rejected'),
        ('inactive', 'Inactive'),
        ('suspended', 'Suspended'),
    ]

    AGREEMENT_CHOICES = [
        ('pending', 'Pending'),
        ('uploaded', 'Uploaded'),
    ]

    user = models.OneToOneField(
        User,
        on_delete=models.CASCADE,
        related_name='franchise_profile'
    )

    dealer_code = models.CharField(
        max_length=50,
        blank=True,
        default='',
        db_index=True,
        help_text="Authoritative unique dealer code (e.g. DLR-PAT-001)"
    )

    business_name = models.CharField(max_length=200)

    city = models.CharField(max_length=100)

    address = models.TextField()

    territory = models.CharField(
        max_length=150,
        blank=True
    )

    assigned_territories = models.JSONField(
        default=list,
        blank=True,
        help_text="List of assigned territory/zone codes"
    )

    is_headquarters = models.BooleanField(
        default=False,
        db_index=True,
        help_text="Designates this franchise as the primary central agency headquarters for fallback."
    )

    gst_number = models.CharField(
        max_length=30,
        blank=True
    )

    pan_number = models.CharField(
        max_length=20,
        blank=True
    )

    aadhaar_number = models.CharField(
        max_length=20,
        blank=True
    )

    # FSSAI Regulatory & Verification Fields
    fssai_number = models.CharField(
        max_length=14,
        blank=True,
        default='',
        db_index=True,
        help_text="14-digit FSSAI Food License / Registration number"
    )
    fssai_business_name = models.CharField(
        max_length=200,
        blank=True,
        default='',
        help_text="FBO / Business name registered with FSSAI"
    )
    fssai_premises_address = models.TextField(
        blank=True,
        default='',
        help_text="Registered premises address as per FSSAI"
    )
    fssai_state = models.CharField(
        max_length=100,
        blank=True,
        default='Chhattisgarh'
    )
    fssai_district = models.CharField(
        max_length=100,
        blank=True,
        default=''
    )
    fssai_expiry_date = models.DateField(
        null=True,
        blank=True,
        help_text="Validity / Expiry date of the FSSAI license"
    )
    fssai_verification_status = models.CharField(
        max_length=30,
        choices=[
            ('PENDING_VERIFICATION', 'Pending Verification'),
            ('UNDER_VERIFICATION', 'Under Verification'),
            ('VERIFIED', 'Verified'),
            ('FAILED', 'Failed'),
            ('EXPIRED', 'Expired'),
            ('MANUAL_REVIEW_REQUIRED', 'Manual Review Required'),
        ],
        default='PENDING_VERIFICATION',
        db_index=True,
        help_text="Authoritative verification state machine"
    )
    fssai_verification_source = models.CharField(
        max_length=120,
        blank=True,
        default='',
        help_text="Official FoSCoS portal, authoritative verification service, etc."
    )
    fssai_verified_at = models.DateTimeField(
        null=True,
        blank=True
    )
    fssai_verified_by = models.ForeignKey(
        User,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name='verified_franchise_fssai'
    )
    fssai_rejection_reason = models.TextField(
        blank=True,
        default=''
    )
    fssai_notes = models.TextField(
        blank=True,
        default=''
    )
    fssai_verification_attempts = models.PositiveIntegerField(
        default=0
    )

    security_deposit = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        default=0
    )

    commission = models.DecimalField(
        max_digits=5,
        decimal_places=2,
        default=0,
        help_text="Configurable dealer commission percentage"
    )

    renewal_date = models.DateField(
        null=True,
        blank=True
    )

    agreement_status = models.CharField(
        max_length=20,
        choices=AGREEMENT_CHOICES,
        default='pending'
    )

    status = models.CharField(
        max_length=20,
        choices=STATUS_CHOICES,
        default='pending'
    )

    rejection_reason = models.TextField(
        blank=True
    )

    approved_at = models.DateTimeField(
        null=True,
        blank=True
    )

    created_at = models.DateTimeField(
        auto_now_add=True
    )

    updated_at = models.DateTimeField(
        auto_now=True
    )

    def __str__(self):
        return f'{self.business_name} - {self.status}'


# =====================================================================
# MASTER TERRITORY & SERVICE AREA MODELS
# =====================================================================

class ServiceDistrict(models.Model):
    name = models.CharField(max_length=100, unique=True)
    state = models.CharField(max_length=100, default='Chhattisgarh')
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['name']

    def __str__(self):
        return f"{self.name}, {self.state}"


class ServiceZone(models.Model):
    district = models.ForeignKey(
        ServiceDistrict,
        on_delete=models.CASCADE,
        related_name='zones'
    )
    name = models.CharField(max_length=100)
    code = models.CharField(max_length=50, unique=True)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['district__name', 'name']
        unique_together = ('district', 'name')

    def __str__(self):
        return f"{self.name} ({self.district.name})"


class ServiceArea(models.Model):
    district = models.ForeignKey(
        ServiceDistrict,
        on_delete=models.CASCADE,
        related_name='areas'
    )
    zone = models.ForeignKey(
        ServiceZone,
        on_delete=models.CASCADE,
        related_name='areas'
    )
    pincode = models.CharField(max_length=10, db_index=True)
    locality_name = models.CharField(max_length=150)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['pincode', 'locality_name']
        indexes = [
            models.Index(fields=['pincode', 'district']),
        ]

    def __str__(self):
        return f"{self.pincode} - {self.locality_name} -> {self.zone.name}"


class FranchiseTerritoryAssignment(models.Model):
    franchise = models.ForeignKey(
        FranchiseProfile,
        on_delete=models.CASCADE,
        related_name='territory_assignments'
    )
    zone = models.ForeignKey(
        ServiceZone,
        on_delete=models.CASCADE,
        related_name='franchise_assignments'
    )
    is_primary = models.BooleanField(
        default=False,
        help_text="Designates this franchise as the primary assigned franchise for customer registrations in this zone."
    )
    is_active = models.BooleanField(default=True)
    assigned_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-is_primary', '-assigned_at']
        unique_together = ('franchise', 'zone')

    def __str__(self):
        primary_tag = " [PRIMARY]" if self.is_primary else ""
        return f"{self.franchise.business_name} -> {self.zone.name}{primary_tag}"


# =====================================================================
# CUSTOMER FRANCHISE RELATIONSHIPS & SERVICE LIFECYCLE
# =====================================================================

class CustomerFranchiseRelationship(models.Model):
    SERVICE_STATUS_CHOICES = [
        ('active', 'Active'),
        ('hold', 'On Hold'),
        ('inactive', 'Inactive'),
    ]

    customer = models.OneToOneField(
        User,
        on_delete=models.CASCADE,
        related_name='customer_relationship'
    )
    registered_franchise = models.ForeignKey(
        FranchiseProfile,
        on_delete=models.PROTECT,
        related_name='assigned_customers',
        help_text="Authoritative franchise associated at customer registration; never overwritten by orders."
    )
    current_serving_franchise = models.ForeignKey(
        FranchiseProfile,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='latest_served_customers',
        help_text="Convenience pointer to latest serving franchise. Historical orders retain their own permanent serving franchise."
    )
    district = models.ForeignKey(
        ServiceDistrict,
        on_delete=models.SET_NULL,
        null=True,
        blank=True
    )
    zone = models.ForeignKey(
        ServiceZone,
        on_delete=models.SET_NULL,
        null=True,
        blank=True
    )
    service_area = models.ForeignKey(
        ServiceArea,
        on_delete=models.SET_NULL,
        null=True,
        blank=True
    )
    pincode = models.CharField(max_length=10, blank=True, default='')
    locality = models.CharField(max_length=150, blank=True, default='')
    service_status = models.CharField(
        max_length=20,
        choices=SERVICE_STATUS_CHOICES,
        default='active'
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"Customer {self.customer.email} -> Registered with {self.registered_franchise.business_name} ({self.service_status})"


class CustomerStockCycle(models.Model):
    SERVICE_STATUS_CHOICES = [
        ('active', 'Active'),
        ('hold', 'On Hold'),
        ('expired', 'Expired'),
        ('completed', 'Completed'),
    ]

    customer = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='stock_cycles'
    )
    order = models.ForeignKey(
        'orders.Order',
        on_delete=models.PROTECT,
        null=True,
        blank=True,
        related_name='stock_cycles',
        help_text="Permanent authoritative link to the exact order that originated this stock cycle."
    )
    product = models.ForeignKey(
        'products.Product',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='stock_cycles'
    )
    product_name = models.CharField(max_length=200, blank=True, default='')
    variant_size = models.CharField(max_length=100, blank=True, default='')
    quantity = models.PositiveIntegerField(default=1)
    serving_franchise = models.ForeignKey(
        FranchiseProfile,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='fulfilled_stock_cycles',
        help_text="The exact franchise fulfilling this cycle. Permanent ownership."
    )
    registered_franchise = models.ForeignKey(
        FranchiseProfile,
        on_delete=models.PROTECT,
        null=True,
        blank=True,
        related_name='registered_customer_stock_cycles',
        help_text="The franchise under which the customer was originally registered."
    )
    district = models.ForeignKey(
        'ServiceDistrict',
        on_delete=models.SET_NULL,
        null=True,
        blank=True
    )
    zone = models.ForeignKey(
        'ServiceZone',
        on_delete=models.SET_NULL,
        null=True,
        blank=True
    )
    service_area = models.ForeignKey(
        'ServiceArea',
        on_delete=models.SET_NULL,
        null=True,
        blank=True
    )
    pincode = models.CharField(max_length=10, blank=True, default='')
    start_date = models.DateField()
    duration_choice = models.CharField(max_length=50, default='1 Month')
    duration_days = models.PositiveIntegerField(default=30)
    expected_end_date = models.DateField()
    service_status = models.CharField(
        max_length=20,
        choices=SERVICE_STATUS_CHOICES,
        default='active'
    )
    remaining_days_at_hold = models.IntegerField(null=True, blank=True)
    hold_timestamp = models.DateTimeField(null=True, blank=True)
    hold_by = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='+'
    )
    hold_reason = models.TextField(blank=True, default='')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']

    @property
    def days_remaining(self):
        from django.utils import timezone
        if self.service_status == 'hold' and self.remaining_days_at_hold is not None:
            return self.remaining_days_at_hold
        today = timezone.now().date()
        diff = (self.expected_end_date - today).days
        return max(0, diff) if self.service_status != 'expired' else 0

    @property
    def computed_status(self):
        from django.utils import timezone
        if self.service_status == 'hold':
            return 'On Hold'
        if self.service_status in ['expired', 'completed']:
            return 'Expired'
        today = timezone.now().date()
        if (self.expected_end_date - today).days <= 0:
            return 'Expired'
        return 'Active'

    @property
    def is_low_stock(self):
        from django.utils import timezone
        if self.service_status != 'active':
            return False
        today = timezone.now().date()
        days = (self.expected_end_date - today).days
        return 1 <= days <= 7

    def __str__(self):
        return f"StockCycle #{self.id} for {self.customer.email}: {self.product_name or 'Stock'} ({self.duration_choice}) until {self.expected_end_date}"



class ServiceHoldHistory(models.Model):
    ACTION_CHOICES = [
        ('hold', 'Hold'),
        ('resume', 'Resume'),
    ]

    stock_cycle = models.ForeignKey(
        CustomerStockCycle,
        on_delete=models.CASCADE,
        related_name='hold_logs'
    )
    customer = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='hold_logs'
    )
    action = models.CharField(max_length=20, choices=ACTION_CHOICES)
    actor = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='service_actions_performed'
    )
    actor_role = models.CharField(max_length=20)
    remaining_days = models.IntegerField()
    notes = models.TextField(blank=True, default='')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.action.upper()} by {self.actor_role} ({self.remaining_days} days left) on {self.created_at.strftime('%Y-%m-%d %H:%M')}"


class CustomerBulkOrder(models.Model):
    STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('confirmed', 'Confirmed'),
        ('dispatched', 'Dispatched'),
        ('delivered', 'Delivered'),
        ('rejected', 'Rejected'),
    ]

    customer = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='bulk_orders'
    )
    product = models.ForeignKey(
        'products.Product',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='bulk_orders'
    )
    product_name = models.CharField(max_length=200)
    variant_size = models.CharField(max_length=100, blank=True, default='')
    quantity = models.PositiveIntegerField()
    duration_choice = models.CharField(max_length=50, default='One-time')
    required_date = models.DateField()
    delivery_address = models.TextField()
    district = models.CharField(max_length=100)
    zone_name = models.CharField(max_length=100)
    serving_franchise = models.ForeignKey(
        FranchiseProfile,
        on_delete=models.PROTECT,
        related_name='bulk_orders_received'
    )
    status = models.CharField(
        max_length=20,
        choices=STATUS_CHOICES,
        default='pending'
    )
    additional_notes = models.TextField(blank=True, default='')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"BulkOrder #{self.id}: {self.quantity}x {self.product_name} for {self.customer.email}"


class FranchiseNotification(models.Model):
    NOTIFICATION_TYPES = [
        ('new_customer', 'New Customer Added'),
        ('order_placed', 'New Order Placed'),
        ('bulk_order', 'New Bulk Order Request'),
        ('stock_alert', 'Low Stock Alert'),
        ('service_status', 'Customer Service Status Changed'),
        ('general', 'General'),
    ]

    franchise = models.ForeignKey(
        FranchiseProfile,
        on_delete=models.CASCADE,
        related_name='notifications'
    )
    title = models.CharField(max_length=200)
    message = models.TextField()
    notification_type = models.CharField(
        max_length=40,
        choices=NOTIFICATION_TYPES,
        default='general'
    )
    reference_id = models.PositiveIntegerField(null=True, blank=True)
    is_read = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['franchise', '-created_at']),
            models.Index(fields=['franchise', 'is_read']),
        ]

    def __str__(self):
        return f"[{self.franchise.business_name}] {self.title} - {self.created_at.strftime('%d/%m/%Y %H:%M')}"


class StockAlertLog(models.Model):
    RECIPIENT_CHOICES = [
        ('customer', 'Customer'),
        ('franchise', 'Serving Franchise'),
        ('admin', 'Admin'),
    ]

    stock_cycle = models.ForeignKey(
        CustomerStockCycle,
        on_delete=models.CASCADE,
        related_name='alert_logs'
    )
    alert_date = models.DateField(db_index=True)
    recipient_type = models.CharField(max_length=20, choices=RECIPIENT_CHOICES)
    recipient_id = models.PositiveIntegerField()
    notification_type = models.CharField(max_length=40, default='low_stock')
    days_remaining = models.IntegerField(default=7)
    status = models.CharField(max_length=20, default='sent')  # 'sent', 'failed'
    error_message = models.TextField(blank=True, default='')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']
        constraints = [
            models.UniqueConstraint(
                fields=['stock_cycle', 'alert_date', 'recipient_type', 'recipient_id'],
                condition=models.Q(status='sent'),
                name='unique_successful_stock_alert_per_recipient_per_day'
            )
        ]

    def __str__(self):
        return f"Alert for Stock #{self.stock_cycle_id} to {self.recipient_type} #{self.recipient_id} on {self.alert_date} ({self.status})"


class CustomerNotification(models.Model):
    NOTIFICATION_TYPES = [
        ('low_stock', 'Low Stock Alert'),
        ('order_update', 'Order Update'),
        ('service_status', 'Service Status Changed'),
        ('general', 'General'),
    ]

    customer = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='customer_notifications'
    )
    title = models.CharField(max_length=200)
    message = models.TextField()
    notification_type = models.CharField(
        max_length=40,
        choices=NOTIFICATION_TYPES,
        default='general'
    )
    stock_cycle = models.ForeignKey(
        CustomerStockCycle,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='customer_notifications'
    )
    reference_id = models.PositiveIntegerField(null=True, blank=True)
    is_read = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['customer', '-created_at']),
            models.Index(fields=['customer', 'is_read']),
        ]

    def __str__(self):
        return f"[{self.customer.email}] {self.title} - {self.created_at.strftime('%d/%m/%Y %H:%M')}"


class SupportContact(models.Model):
    ROLE_CHOICES = [
        ('public_customer',  'Public / Anonymous Customer Inquiry'),
        ('public_franchise', 'Public / Anonymous Franchise Inquiry'),
        ('customer',         'Authenticated Customer'),
        ('franchise',        'Authenticated Franchise'),
        ('admin',            'Admin / Super Admin'),
        ('sales_executive',  'Sales Executive'),
    ]
    role             = models.CharField(max_length=50, choices=ROLE_CHOICES, unique=True)
    name             = models.CharField(max_length=150)
    phone            = models.CharField(max_length=20)
    whatsapp_number  = models.CharField(max_length=20, blank=True, default='')
    email            = models.EmailField(blank=True, default='')
    message_template = models.TextField(blank=True, default='')
    available_hours  = models.CharField(max_length=100, blank=True, default='9:00 AM - 7:00 PM')
    is_active        = models.BooleanField(default=True)

    class Meta:
        verbose_name = 'Support Contact'
        verbose_name_plural = 'Support Contacts'

    def __str__(self):
        return f'{self.get_role_display()} -> {self.name} ({self.phone})'


class DealerDocument(models.Model):
    DOCUMENT_TYPES = [
        ('FSSAI_CERTIFICATE', 'FSSAI License / Registration Certificate'),
        ('GST', 'GST Registration Certificate'),
        ('PAN', 'PAN Card'),
        ('AADHAAR', 'Aadhaar Card'),
        ('AGREEMENT', 'Distributor / Wholesale Agreement'),
        ('TRADE_LICENSE', 'Trade License'),
        ('OTHER', 'Other KYC Document'),
    ]

    STATUS_CHOICES = [
        ('PENDING', 'Pending Review'),
        ('VERIFIED', 'Verified / Approved'),
        ('REJECTED', 'Rejected'),
    ]

    dealer = models.ForeignKey(
        FranchiseProfile,
        on_delete=models.CASCADE,
        related_name='kyc_documents'
    )
    document_type = models.CharField(max_length=30, choices=DOCUMENT_TYPES)
    document_number = models.CharField(max_length=100, blank=True, default='')
    document_file = models.FileField(upload_to='dealer_documents/')
    verification_status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='PENDING')
    rejection_reason = models.TextField(blank=True, default='')
    uploaded_by = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='uploaded_dealer_documents'
    )
    verified_by = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='verified_dealer_documents'
    )
    uploaded_at = models.DateTimeField(auto_now_add=True)
    verified_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ['-uploaded_at']
        verbose_name = 'Dealer KYC Document'
        verbose_name_plural = 'Dealer KYC Documents'

    def __str__(self):
        return f"{self.dealer.business_name} - {self.get_document_type_display()} [{self.verification_status}]"


class FSSAIVerificationLog(models.Model):
    franchise = models.ForeignKey(
        FranchiseProfile,
        on_delete=models.CASCADE,
        related_name='fssai_audit_logs'
    )
    fssai_number = models.CharField(max_length=14, db_index=True)
    previous_status = models.CharField(max_length=30)
    new_status = models.CharField(max_length=30)
    verification_source = models.CharField(max_length=120, default='FoSCoS Portal Manual Review')
    mismatch_reason = models.TextField(blank=True, default='')
    official_reference = models.TextField(blank=True, default='')
    notes = models.TextField(blank=True, default='')
    verified_by = models.ForeignKey(
        User,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name='fssai_verification_logs'
    )
    action_taken = models.CharField(max_length=100)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']
        verbose_name = 'FSSAI Verification Audit Log'
        verbose_name_plural = 'FSSAI Verification Audit Logs'

    def __str__(self):
        return f"Franchise #{self.franchise_id} FSSAI {self.fssai_number} -> {self.new_status} at {self.created_at}"


class Notification(models.Model):
    NOTIFICATION_TYPES = [
        ('EXPIRY_ALERT', 'Batch Expiry Alert'),
        ('LOW_STOCK_ALERT', 'Low Stock Alert'),
        ('PAYMENT_REMINDER', 'Payment Due / Overdue Reminder'),
        ('STOCK_DISPATCHED', 'Stock Dispatched to Dealer'),
        ('STOCK_RECEIVED', 'Stock Receipt Confirmed'),
        ('LEAD_ASSIGNED', 'New CRM Lead Assigned'),
        ('ORDER_UPDATE', 'Order Status Update'),
        ('SYSTEM', 'System Alert'),
    ]

    recipient = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        null=True,
        blank=True,
        related_name='user_notifications'
    )
    role_target = models.CharField(max_length=30, blank=True, default='')
    notification_type = models.CharField(max_length=40, choices=NOTIFICATION_TYPES, default='SYSTEM')
    title = models.CharField(max_length=255)
    message = models.TextField()
    entity_type = models.CharField(max_length=50, blank=True, default='')
    entity_id = models.PositiveIntegerField(null=True, blank=True)
    idempotency_key = models.CharField(max_length=150, null=True, blank=True, db_index=True)
    is_read = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']
        verbose_name = 'System Notification'
        verbose_name_plural = 'System Notifications'

    def __str__(self):
        return f"{self.title} -> {self.recipient or self.role_target} ({self.created_at.strftime('%Y-%m-%d %H:%M')})"


class AdminAuditLog(models.Model):
    actor = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='admin_audit_logs'
    )
    action = models.CharField(max_length=150)
    resource_type = models.CharField(max_length=100)
    resource_id = models.CharField(max_length=100, blank=True, default='')
    ip_address = models.GenericIPAddressField(null=True, blank=True)
    changes = models.JSONField(default=dict, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']
        verbose_name = 'Admin Audit Log'
        verbose_name_plural = 'Admin Audit Logs'

    def __str__(self):
        actor_name = self.actor.email if self.actor else 'System'
        return f"[{self.created_at.strftime('%Y-%m-%d %H:%M')}] {actor_name} -> {self.action} on {self.resource_type}:{self.resource_id}"


class SystemBackupLog(models.Model):
    STATUS_CHOICES = [
        ('IN_PROGRESS', 'In Progress'),
        ('SUCCESS', 'Success'),
        ('FAILED', 'Failed'),
    ]

    triggered_by = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='triggered_backups'
    )
    backup_filename = models.CharField(max_length=255)
    file_size_bytes = models.BigIntegerField(default=0)
    storage_path = models.TextField(blank=True, default='')
    checksum_sha256 = models.CharField(max_length=64, blank=True, default='')
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='IN_PROGRESS')
    error_message = models.TextField(blank=True, default='')
    started_at = models.DateTimeField(auto_now_add=True)
    completed_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ['-started_at']
        verbose_name = 'System Backup Log'
        verbose_name_plural = 'System Backup Logs'

    def __str__(self):
        return f"{self.backup_filename} [{self.status}] at {self.started_at.strftime('%Y-%m-%d %H:%M')}"


class PasswordResetToken(models.Model):
    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='password_reset_tokens'
    )
    token_hash = models.CharField(max_length=64, db_index=True)
    email_or_phone = models.CharField(max_length=150)
    created_at = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField(db_index=True)
    is_used = models.BooleanField(default=False, db_index=True)
    used_at = models.DateTimeField(null=True, blank=True)
    verification_attempts = models.PositiveIntegerField(default=0)
    ip_address = models.GenericIPAddressField(null=True, blank=True)

    class Meta:
        ordering = ['-created_at']
        verbose_name = 'Password Reset Token'
        verbose_name_plural = 'Password Reset Tokens'

    @property
    def is_valid(self):
        from django.utils import timezone
        return not self.is_used and timezone.now() <= self.expires_at and self.verification_attempts < 5

    def __str__(self):
        status_str = "USED" if self.is_used else ("VALID" if self.is_valid else "EXPIRED")
        return f"Reset Token for {self.user.username} ({self.email_or_phone}) [{status_str}]"





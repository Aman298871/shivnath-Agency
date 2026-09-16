from django.db import models
from django.contrib.auth.models import User


class UserProfile(models.Model):

    ROLE_CHOICES = [
        ('customer', 'Customer'),
        ('franchise', 'Franchise'),
        ('staff', 'Staff'),
        ('admin', 'Admin'),
    ]

    STATUS_CHOICES = [
        ('active', 'Active'),
        ('inactive', 'Inactive'),
        ('pending', 'Pending'),
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

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f'{self.user.email} - {self.role}'


class AdminNotification(models.Model):
    NOTIFICATION_TYPES = [
        ('customer_registration', 'Customer Registration'),
        ('franchise_registration', 'Franchise Registration'),
        ('order_placed', 'Order Placed'),
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

    def __str__(self):
        return f'{self.title} - {self.created_at.strftime("%d/%m/%Y %H:%M")}'


class FranchiseProfile(models.Model):
    STATUS_CHOICES = [
        ('pending', 'Pending'),
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

    business_name = models.CharField(max_length=200)

    city = models.CharField(max_length=100)

    address = models.TextField()

    territory = models.CharField(
        max_length=150,
        blank=True
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

    security_deposit = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        default=0
    )

    commission = models.DecimalField(
        max_digits=5,
        decimal_places=2,
        default=0
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
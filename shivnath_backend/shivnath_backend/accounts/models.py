from django.db import models
from django.contrib.auth.models import User


class UserProfile(models.Model):

    ROLE_CHOICES = [
        ('customer', 'Customer'),
        ('franchise', 'Franchise'),
        ('admin', 'Admin'),
    ]

    user = models.OneToOneField(
        User,
        on_delete=models.CASCADE,
        related_name='profile'
    )

    phone = models.CharField(
        max_length=15,
        blank=True
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
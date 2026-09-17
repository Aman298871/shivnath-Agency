from django.db import models
from django.contrib.auth.models import User


class Lead(models.Model):

    # -----------------------------------------
    # LEAD SCORE
    # -----------------------------------------

    SCORE_CHOICES = [
        ('hot', 'Hot'),
        ('warm', 'Warm'),
        ('cold', 'Cold'),
    ]

    # -----------------------------------------
    # LEAD STATUS / PIPELINE
    # -----------------------------------------

    STATUS_CHOICES = [
        ('new_lead', 'New Lead'),
        ('contacted', 'Contacted'),
        ('followup_1', 'Follow-up 1'),
        ('followup_2', 'Follow-up 2'),
        ('interested', 'Interested'),
        (
            'site_visit_scheduled',
            'Site Visit Scheduled'
        ),
        (
            'agreement_pending',
            'Agreement Pending'
        ),
        (
            'franchise_confirmed',
            'Franchise Confirmed'
        ),
        ('lost', 'Lost'),
    ]

    # -----------------------------------------
    # EXISTING BUSINESS
    # -----------------------------------------

    EXISTING_BUSINESS_CHOICES = [
        ('yes', 'Yes'),
        ('no', 'No'),
    ]

    # -----------------------------------------
    # COMMERCIAL SPACE
    # -----------------------------------------

    COMMERCIAL_SPACE_CHOICES = [
        ('no', 'No'),
        ('available', 'Available'),
        ('searching', 'Searching'),
    ]

    # =========================================
    # CONTACT INFORMATION
    # =========================================

    name = models.CharField(
        max_length=150
    )

    phone = models.CharField(
        max_length=15
    )

    email = models.EmailField(
        max_length=200,
        blank=True,
        default=''
    )

    city = models.CharField(
        max_length=100
    )

    district = models.CharField(
        max_length=100,
        blank=True
    )

    # =========================================
    # BUSINESS / FRANCHISE DETAILS
    # =========================================

    investment_budget = models.CharField(
        max_length=50,
        blank=True
    )

    existing_business = models.CharField(
        max_length=20,
        choices=EXISTING_BUSINESS_CHOICES,
        default='no'
    )

    commercial_space = models.CharField(
        max_length=20,
        choices=COMMERCIAL_SPACE_CHOICES,
        default='no'
    )

    previous_experience = models.CharField(
        max_length=200,
        blank=True
    )

    preferred_location = models.CharField(
        max_length=200,
        blank=True
    )

    # =========================================
    # LEAD MANAGEMENT
    # =========================================

    score = models.CharField(
        max_length=20,
        choices=SCORE_CHOICES,
        default='warm'
    )

    status = models.CharField(
        max_length=50,
        choices=STATUS_CHOICES,
        default='new_lead'
    )

    # Sales Executive mobile app/module nahi hai.
    # Isliye filhal simple name store karenge.
    assigned_executive = models.CharField(
        max_length=150,
        blank=True
    )

    next_followup = models.DateTimeField(
        null=True,
        blank=True
    )

    # =========================================
    # EXTRA CRM FIELDS
    # =========================================

    source = models.CharField(
        max_length=100,
        blank=True
    )

    notes = models.TextField(
        blank=True
    )

    created_by = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='created_leads'
    )

    created_at = models.DateTimeField(
        auto_now_add=True
    )

    updated_at = models.DateTimeField(
        auto_now=True
    )

    class Meta:
        ordering = [
            '-created_at'
        ]

        indexes = [
            models.Index(
                fields=['phone']
            ),
            models.Index(
                fields=['city']
            ),
            models.Index(
                fields=['status']
            ),
            models.Index(
                fields=['score']
            ),
            models.Index(
                fields=['next_followup']
            ),
        ]

    def __str__(self):
        return (
            f'{self.name} - '
            f'{self.phone}'
        )


# =================================================
# LEAD ACTIVITY / TIMELINE
# =================================================

class LeadActivity(models.Model):

    ACTIVITY_TYPE_CHOICES = [
        ('call', 'Call'),
        ('whatsapp', 'WhatsApp'),
        ('note', 'Note'),
        ('meeting', 'Meeting'),
        ('document', 'Document'),
        (
            'status_change',
            'Status Change'
        ),
    ]

    lead = models.ForeignKey(
        Lead,
        on_delete=models.CASCADE,
        related_name='activities'
    )

    activity_type = models.CharField(
        max_length=30,
        choices=ACTIVITY_TYPE_CHOICES
    )

    title = models.CharField(
        max_length=200
    )

    description = models.TextField(
        blank=True
    )

    created_by = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='created_lead_activities'
    )

    created_at = models.DateTimeField(
        auto_now_add=True
    )

    class Meta:
        ordering = [
            '-created_at'
        ]

    def __str__(self):
        return (
            f'{self.lead.name} - '
            f'{self.get_activity_type_display()}'
        )
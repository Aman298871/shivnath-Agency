from django.db import models
from django.contrib.auth.models import User


class Lead(models.Model):

    SCORE_CHOICES = [
        ('HOT', 'Hot (High Interest / Qualified)'),
        ('WARM', 'Warm (Follow-up Required)'),
        ('COLD', 'Cold (Low Priority)'),
        ('hot', 'Hot'),
        ('warm', 'Warm'),
        ('cold', 'Cold'),
    ]

    STATUS_CHOICES = [
        ('NEW', 'New Inquiry'),
        ('CONTACTED', 'Contacted by Sales'),
        ('INTERESTED', 'Interested'),
        ('HOT_LEAD', 'Hot Lead'),
        ('FOLLOW_UP_REQUIRED', 'Follow-up Required'),
        ('SITE_VISIT_SCHEDULED', 'Site Visit Scheduled'),
        ('SITE_VISIT_COMPLETED', 'Site Visit Completed'),
        ('AGREEMENT_PENDING', 'Agreement / KYC Pending'),
        ('FRANCHISE_CONFIRMED', 'Wholesale Dealer / Franchise Confirmed'),
        ('CONVERTED', 'Converted to Active Dealer/Customer'),
        ('NOT_INTERESTED', 'Not Interested'),
        ('LOST', 'Lost / Dropped'),
        # Legacy status values for backward compatibility
        ('new_lead', 'New Lead'),
        ('new', 'New'),
        ('contacted', 'Contacted'),
        ('interested', 'Interested'),
        ('hot_lead', 'Hot Lead'),
        ('followup_required', 'Follow-up Required'),
        ('followup_1', 'Follow-up 1'),
        ('followup_2', 'Follow-up 2'),
        ('site_visit_scheduled', 'Site Visit Scheduled'),
        ('site_visit_completed', 'Site Visit Completed'),
        ('converted', 'Converted'),
        ('agreement_pending', 'Agreement Pending'),
        ('franchise_confirmed', 'Franchise Confirmed'),
        ('not_interested', 'Not Interested'),
        ('lost', 'Lost'),
    ]

    EXISTING_BUSINESS_CHOICES = [
        ('yes', 'Yes'),
        ('no', 'No'),
    ]

    COMMERCIAL_SPACE_CHOICES = [
        ('no', 'No'),
        ('available', 'Available'),
        ('searching', 'Searching'),
    ]

    VEHICLE_ACCESS_CHOICES = [
        ('two_wheeler', 'Two Wheeler'),
        ('four_wheeler_commercial', 'Commercial Four Wheeler / Pickup'),
        ('none', 'None'),
    ]

    LEAD_TYPE_CHOICES = [
        ('CUSTOMER', 'Customer Inquiry'),
        ('FRANCHISE', 'Franchise / Dealership Inquiry'),
    ]

    lead_type = models.CharField(
        max_length=20,
        choices=LEAD_TYPE_CHOICES,
        default='CUSTOMER',
        db_index=True,
        help_text="Inquiry category: CUSTOMER or FRANCHISE"
    )

    lead_number = models.CharField(
        max_length=50,
        blank=True,
        default='',
        db_index=True,
        help_text="e.g. LD-202609-001"
    )

    name = models.CharField(
        max_length=150
    )

    phone = models.CharField(
        max_length=15,
        db_index=True
    )

    email = models.EmailField(
        max_length=200,
        blank=True,
        default='',
        db_index=True,
        help_text="Required for all qualified chatbot inquiries"
    )

    city = models.CharField(
        max_length=100
    )

    district = models.CharField(
        max_length=100,
        blank=True,
        default=''
    )

    territory = models.CharField(
        max_length=150,
        blank=True,
        default=''
    )

    locality = models.CharField(
        max_length=150,
        blank=True,
        default=''
    )

    assigned_franchise = models.ForeignKey(
        'accounts.FranchiseProfile',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='assigned_leads'
    )

    investment_budget = models.CharField(
        max_length=50,
        blank=True,
        default=''
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

    commercial_space_sqft = models.PositiveIntegerField(
        default=0,
        help_text="Available commercial warehouse space in sq. ft."
    )

    previous_experience = models.CharField(
        max_length=200,
        blank=True,
        default=''
    )

    preferred_location = models.CharField(
        max_length=200,
        blank=True,
        default=''
    )

    vehicle_access = models.CharField(
        max_length=50,
        choices=VEHICLE_ACCESS_CHOICES,
        default='none',
        help_text="Available delivery vehicle capacity"
    )

    response_speed_hours = models.PositiveIntegerField(
        default=24,
        help_text="Hours elapsed between inquiry and customer response"
    )

    lead_score_number = models.PositiveIntegerField(
        default=50,
        help_text="Calculated lead quality score (0 - 100)"
    )

    score_category = models.CharField(
        max_length=10,
        choices=[('HOT', 'Hot'), ('WARM', 'Warm'), ('COLD', 'Cold')],
        default='WARM'
    )

    score = models.CharField(
        max_length=20,
        choices=SCORE_CHOICES,
        default='warm'
    )

    status = models.CharField(
        max_length=50,
        choices=STATUS_CHOICES,
        default='NEW'
    )

    assigned_executive = models.CharField(
        max_length=150,
        blank=True,
        default=''
    )

    assigned_executive_user = models.ForeignKey(
        User,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name='assigned_crm_leads'
    )

    next_followup = models.DateTimeField(
        null=True,
        blank=True
    )

    interest_level = models.CharField(
        max_length=20,
        blank=True,
        default='Medium'
    )

    site_visit_planned = models.BooleanField(
        default=False
    )

    site_visit_completed = models.BooleanField(
        default=False
    )

    site_visit_date = models.DateField(
        null=True,
        blank=True
    )

    site_visit_notes = models.TextField(
        blank=True,
        default=''
    )

    source = models.CharField(
        max_length=100,
        blank=True,
        default='Public Inbound Chatbot'
    )

    marketing_campaign_source = models.CharField(
        max_length=100,
        blank=True,
        default='',
        help_text="Campaign name/tag for Cost-Per-Lead (CPL) reporting"
    )

    notes = models.TextField(
        blank=True,
        default=''
    )

    created_by = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='created_leads'
    )

    converted_user = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='converted_leads'
    )

    created_at = models.DateTimeField(
        auto_now_add=True
    )

    updated_at = models.DateTimeField(
        auto_now=True
    )

    class Meta:
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['phone']),
            models.Index(fields=['email']),
            models.Index(fields=['status']),
            models.Index(fields=['score_category']),
            models.Index(fields=['next_followup']),
        ]

    def __str__(self):
        return f'{self.name} ({self.phone}) - [{self.status}] Score: {self.score_category}'

    def calculate_lead_score(self):
        """
        Deterministic, validated lead scoring based on verified model fields.
        """
        score = 20  # Base score for valid name + mobile + email
        if self.email and '@' in self.email:
            score += 15
        if self.existing_business == 'yes':
            score += 20
        if self.commercial_space in ['available', 'searching']:
            score += 15
        if self.vehicle_access in ['two_wheeler', 'four_wheeler_commercial']:
            score += 15
        if self.investment_budget:
            budget_lower = self.investment_budget.lower()
            if any(k in budget_lower for k in ['lakh', 'lac', '50000', '100000', '200000', '500000', '1l', '2l', '5l', '10l', '20l', '50l', 'cr', 'l -', 'l-']):
                score += 15
        self.lead_score_number = min(100, score)
        if self.lead_score_number >= 75:
            self.score_category = 'HOT'
            self.score = 'HOT'
        elif self.lead_score_number >= 45:
            self.score_category = 'WARM'
            self.score = 'WARM'
        else:
            self.score_category = 'COLD'
            self.score = 'COLD'
        return self.lead_score_number

    def save(self, *args, **kwargs):
        if not self.lead_number and self.id:
            self.lead_number = f"LD-{self.created_at.strftime('%Y%m')}-{self.id:04d}"
        super().save(*args, **kwargs)
        if hasattr(self, 'journey_state'):
            status_upper = (self.status or '').upper()
            if status_upper in ['CONVERTED', 'DEALER_CONVERTED', 'CUSTOMER_CONVERTED']:
                self.journey_state.is_paused = True
                self.journey_state.pause_reason = 'CONVERTED'
                self.journey_state.save()
            elif status_upper in ['NOT_INTERESTED', 'NOT_INTRESTED', 'REJECTED']:
                self.journey_state.is_paused = True
                self.journey_state.pause_reason = 'NOT_INTERESTED'
                self.journey_state.save()
            elif status_upper in ['LOST', 'DROP']:
                self.journey_state.is_paused = True
                self.journey_state.pause_reason = 'LOST'
                self.journey_state.save()
            else:
                if self.journey_state.is_paused and self.journey_state.pause_reason in ['CONVERTED', 'NOT_INTERESTED', 'LOST']:
                    self.journey_state.is_paused = False
                    self.journey_state.pause_reason = ''
                    self.journey_state.save()



class LeadJourneyState(models.Model):
    """
    Tracks state of the automated 15-day WhatsApp nurturing journey (Days 1, 3, 5, 7, 10, 15).
    Pauses automatically upon lead conversion, negative outcome, opt-out, or manual takeover.
    """
    PAUSE_REASONS = [
        ('CONVERTED', 'Lead Converted to Dealer / Customer'),
        ('NOT_INTERESTED', 'Lead Marked Not Interested'),
        ('LOST', 'Lead Marked Lost'),
        ('OPT_OUT', 'Customer Opted Out (STOP keyword)'),
        ('HUMAN_TAKEOVER', 'Sales Executive Human Takeover'),
    ]

    lead = models.OneToOneField(
        Lead,
        on_delete=models.CASCADE,
        related_name='journey_state'
    )
    current_step = models.PositiveIntegerField(
        default=1,
        help_text="Current nurture step (1 to 6)"
    )
    scheduled_day_offset = models.PositiveIntegerField(
        default=1,
        help_text="Target schedule day (1, 3, 5, 7, 10, 15)"
    )
    last_triggered_at = models.DateTimeField(null=True, blank=True)
    next_scheduled_at = models.DateTimeField(null=True, blank=True)
    is_paused = models.BooleanField(default=False)
    pause_reason = models.CharField(max_length=30, choices=PAUSE_REASONS, blank=True, default='')
    completed_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        verbose_name = 'Lead Journey State'
        verbose_name_plural = 'Lead Journey States'

    def __str__(self):
        status_text = f"Paused ({self.pause_reason})" if self.is_paused else f"Step {self.current_step} (Day {self.scheduled_day_offset})"
        return f"Journey for {self.lead.name}: {status_text}"


class WhatsAppIntegrationConfig(models.Model):
    """
    Authoritative provider credentials and configuration. Zero secrets exposed to frontend.
    """
    PROVIDER_CHOICES = [
        ('META_CLOUD_API', 'Meta WhatsApp Cloud API'),
        ('GUPSHUP', 'Gupshup Enterprise API'),
        ('TWILIO', 'Twilio Messaging API'),
        ('MOCK_PROVIDER', 'Mock / Development Provider (Logged to DB)'),
    ]

    provider_name = models.CharField(max_length=30, choices=PROVIDER_CHOICES, default='MOCK_PROVIDER')
    api_endpoint = models.CharField(max_length=255, blank=True, default='')
    api_token_encrypted = models.TextField(blank=True, default='')
    phone_number_id = models.CharField(max_length=100, blank=True, default='')
    webhook_secret_encrypted = models.TextField(blank=True, default='')
    is_active = models.BooleanField(default=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = 'WhatsApp Integration Config'
        verbose_name_plural = 'WhatsApp Integration Configs'

    def __str__(self):
        return f"{self.get_provider_name_display()} ({'Active' if self.is_active else 'Disabled'})"


class WhatsAppTemplate(models.Model):
    """
    Configurable message templates managed by Admin. Avoids hardcoded claims in source code.
    """
    CATEGORY_CHOICES = [
        ('MARKETING', 'Marketing / Promotion'),
        ('UTILITY', 'Utility / Notification / Order Tracking'),
        ('AUTHENTICATION', 'Authentication / OTP'),
    ]

    template_name = models.CharField(max_length=100, unique=True, db_index=True)
    provider_template_id = models.CharField(max_length=100, blank=True, default='')
    category = models.CharField(max_length=20, choices=CATEGORY_CHOICES, default='UTILITY')
    header_text = models.CharField(max_length=255, blank=True, default='')
    body_content = models.TextField(help_text="Supports template placeholders like {{1}}, {{name}}, {{dealer_name}}")
    button_payloads = models.JSONField(default=list, blank=True, help_text="Interactive menu / reply options")
    is_approved_by_provider = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = 'WhatsApp Template'
        verbose_name_plural = 'WhatsApp Templates'

    def __str__(self):
        return f"{self.template_name} ({self.category})"


class WhatsAppMessageLog(models.Model):
    """
    Log of inbound and outbound WhatsApp communications with delivery status and retries.
    """
    DIRECTION_CHOICES = [
        ('OUTBOUND', 'Outbound to User'),
        ('INBOUND', 'Inbound from User'),
    ]

    STATUS_CHOICES = [
        ('QUEUED', 'Queued in Outbox'),
        ('SENT', 'Sent to Provider'),
        ('DELIVERED', 'Delivered to Recipient Device'),
        ('READ', 'Read by Recipient'),
        ('FAILED', 'Failed / Delivery Error'),
    ]

    message_id = models.CharField(max_length=150, blank=True, default='', db_index=True)
    lead = models.ForeignKey(
        Lead,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name='whatsapp_messages'
    )
    recipient_phone = models.CharField(max_length=20, db_index=True)
    direction = models.CharField(max_length=10, choices=DIRECTION_CHOICES, default='OUTBOUND')
    template_used = models.ForeignKey(
        WhatsAppTemplate,
        null=True,
        blank=True,
        on_delete=models.SET_NULL
    )
    raw_content = models.TextField(blank=True, default='')
    delivery_status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='QUEUED', db_index=True)
    error_reason = models.TextField(blank=True, default='')
    retry_count = models.PositiveIntegerField(default=0)
    timestamp = models.DateTimeField(auto_now_add=True, db_index=True)

    class Meta:
        ordering = ['-timestamp']
        verbose_name = 'WhatsApp Message Log'
        verbose_name_plural = 'WhatsApp Message Logs'

    def __str__(self):
        return f"{self.direction} -> {self.recipient_phone} [{self.delivery_status}] at {self.timestamp.strftime('%Y-%m-%d %H:%M')}"


class CRMActivityLog(models.Model):
    """
    Audit log of all CRM activities on a lead.
    """
    ACTIVITY_TYPES = [
        ('CALL_LOGGED', 'Phone Call Logged'),
        ('WHATSAPP_SENT', 'WhatsApp Message Dispatched'),
        ('SITE_VISIT_CONDUCTED', 'Site Visit Conducted'),
        ('NOTE_ADDED', 'Internal Note Added'),
        ('STATUS_CHANGED', 'Pipeline Status Changed'),
        ('AGREEMENT_UPLOADED', 'KYC / Agreement Uploaded'),
    ]

    lead = models.ForeignKey(
        Lead,
        on_delete=models.CASCADE,
        related_name='activity_logs'
    )
    actor = models.ForeignKey(
        User,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name='crm_activities'
    )
    activity_type = models.CharField(max_length=30, choices=ACTIVITY_TYPES)
    description = models.TextField()
    timestamp = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-timestamp']
        verbose_name = 'CRM Activity Log'
        verbose_name_plural = 'CRM Activity Logs'

    def __str__(self):
        actor_name = self.actor.email if self.actor else 'System'
        return f"{self.lead.name}: {self.activity_type} by {actor_name} on {self.timestamp.strftime('%Y-%m-%d %H:%M')}"


class MarketingSpend(models.Model):
    """
    Marketing campaign spend for Cost-Per-Lead (CPL) analytics.
    CPL = (Total Spend for Campaign / Total Leads Generated for Campaign).
    """
    CAMPAIGN_SOURCES = [
        ('META_ADS', 'Meta (Facebook / Instagram) Ads'),
        ('GOOGLE_ADS', 'Google Search / Display Ads'),
        ('PRINT_NEWSPAPER', 'Print / Newspaper Ads'),
        ('OUTDOOR_HOARDING', 'Outdoor Billboards / Hoardings'),
        ('DIRECT_REFERRAL', 'Direct Referral / Field Activations'),
    ]

    campaign_name = models.CharField(max_length=150)
    campaign_source = models.CharField(max_length=30, choices=CAMPAIGN_SOURCES, default='META_ADS')
    period_start = models.DateField()
    period_end = models.DateField()
    total_spend_inr = models.DecimalField(max_digits=12, decimal_places=2, default=0.00)
    notes = models.TextField(blank=True, default='')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-period_start']
        verbose_name = 'Marketing Spend'
        verbose_name_plural = 'Marketing Spends'

    def __str__(self):
        return f"{self.campaign_name} ({self.get_campaign_source_display()}): ₹{self.total_spend_inr} ({self.period_start} to {self.period_end})"


# =================================================
# LEGACY COMPATIBILITY MODELS (PRESERVED)
# =================================================

class LeadActivity(models.Model):
    lead = models.ForeignKey(Lead, on_delete=models.CASCADE, related_name='activities')
    activity_type = models.CharField(max_length=100, blank=True, default='Call')
    title = models.CharField(max_length=200, blank=True, default='')
    action = models.CharField(max_length=200, blank=True, default='')
    description = models.TextField(blank=True, default='')
    created_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True, related_name='created_lead_activities')
    performed_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True, related_name='performed_lead_activities')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']


class LeadFollowup(models.Model):
    STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('completed', 'Completed'),
        ('cancelled', 'Cancelled'),
    ]
    lead = models.ForeignKey(Lead, on_delete=models.CASCADE, related_name='lead_followups')
    scheduled_date = models.DateTimeField()
    notes = models.TextField(blank=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    created_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-scheduled_date']


class LeadQuotation(models.Model):
    lead = models.ForeignKey(Lead, on_delete=models.CASCADE, related_name='quotations')
    quotation_number = models.CharField(max_length=50, unique=True)
    amount = models.DecimalField(max_digits=10, decimal_places=2)
    valid_until = models.DateField()
    pdf_file = models.FileField(upload_to='quotations/', null=True, blank=True)
    created_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']
from django.db import models
from django.contrib.auth.models import User
from products.models import Product


class Quotation(models.Model):
    STATUS_CHOICES = [
        ("draft", "Draft"),
        ("published", "Published"),
        ("accepted", "Accepted"),
        ("rejected", "Rejected"),
        ("expired", "Expired"),
        ("withdrawn", "Withdrawn"),
    ]

    QUOTATION_TYPE_CHOICES = [
        ("franchise", "Franchise Quotation"),
        ("bottle", "Bottle Quotation"),
        ("jar", "Jar Quotation"),
        ("bulk", "Bulk Quantity Quotation"),
        ("custom", "Custom Quotation"),
    ]

    TARGET_AUDIENCE_CHOICES = [
        ("franchise", "Franchise"),
    ]

    title = models.CharField(max_length=200)
    quotation_number = models.CharField(
        max_length=50,
        blank=True,
        default="",
        db_index=True,
        help_text="Official unique reference code e.g. Q-FRN-2026-001"
    )
    status = models.CharField(
        max_length=30,
        choices=STATUS_CHOICES,
        default="published",
        db_index=True,
    )
    franchise = models.ForeignKey(
        "accounts.FranchiseProfile",
        on_delete=models.CASCADE,
        null=True,
        blank=True,
        related_name="quotations",
        help_text="Target franchise for this quotation (Exclusively for Franchises)."
    )
    quotation_type = models.CharField(
        max_length=50,
        choices=QUOTATION_TYPE_CHOICES,
        default="franchise",
    )
    product = models.ForeignKey(
        Product,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="quotations",
    )
    quantity_tier = models.CharField(
        max_length=100,
        blank=True,
        default="1 Unit",
        help_text="e.g. 50+ Jars, 100+ Boxes, 500+ Bottles",
    )
    unit_price = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        default=0.0,
    )
    total_price = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        default=0.0,
    )
    discount_percent = models.DecimalField(
        max_digits=5,
        decimal_places=2,
        default=0.0,
    )
    additional_charges = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        default=0.0,
    )
    final_amount = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        default=0.0,
    )
    applicable_terms = models.TextField(
        blank=True,
        default="Standard delivery, purity warranty, and franchise operating terms apply.",
    )
    notes = models.TextField(blank=True, default="")
    validity = models.CharField(
        max_length=100,
        blank=True,
        default="Valid for 30 days from generation",
    )
    published_at = models.DateTimeField(null=True, blank=True)
    valid_until = models.DateField(null=True, blank=True)
    accepted_at = models.DateTimeField(null=True, blank=True)
    accepted_by = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="accepted_quotations",
    )
    rejection_reason = models.TextField(blank=True, default="")
    status_history = models.JSONField(default=list, blank=True)
    is_read_by_franchise = models.BooleanField(default=False)
    target_audience = models.CharField(
        max_length=30,
        choices=TARGET_AUDIENCE_CHOICES,
        default="franchise",
    )
    pdf_file = models.FileField(
        upload_to="quotations/",
        null=True,
        blank=True,
        help_text="Uploaded official quotation PDF file",
    )
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-updated_at"]

    def save(self, *args, **kwargs):
        is_new = self.pk is None
        # Recalculate final_amount if 0
        from decimal import Decimal
        if not self.final_amount or self.final_amount == 0:
            base = Decimal(str(self.total_price if self.total_price > 0 else self.unit_price))
            disc_pct = Decimal(str(self.discount_percent or 0))
            discount = base * (disc_pct / Decimal('100'))
            add_charges = Decimal(str(self.additional_charges or 0))
            self.final_amount = max(Decimal('0.00'), base - discount + add_charges)

        super().save(*args, **kwargs)

        if not self.quotation_number:
            year = self.created_at.year if self.created_at else 2026
            self.quotation_number = f"Q-FRN-{year}-{self.id:04d}"
            Quotation.objects.filter(pk=self.pk).update(quotation_number=self.quotation_number)

    def __str__(self):
        franchise_name = self.franchise.business_name if self.franchise else "Unassigned"
        return f"{self.quotation_number or self.title} [{franchise_name}] (₹{self.final_amount or self.total_price or self.unit_price})"


class ChatbotOption(models.Model):
    INQUIRY_TYPE_CHOICES = [
        ("customer", "Customer / Product Inquiry"),
        ("franchise", "Franchise Inquiry"),
        ("both", "Both"),
    ]

    title = models.CharField(max_length=200)
    inquiry_type = models.CharField(
        max_length=30,
        choices=INQUIRY_TYPE_CHOICES,
        default="customer",
    )
    parent = models.ForeignKey(
        "self",
        on_delete=models.CASCADE,
        null=True,
        blank=True,
        related_name="children",
    )
    order = models.PositiveIntegerField(default=0)
    is_active = models.BooleanField(default=True)
    is_lead_trigger = models.BooleanField(
        default=False,
        help_text="Triggers lead capture qualification when selected",
    )
    lead_inquiry_type = models.CharField(
        max_length=30,
        choices=INQUIRY_TYPE_CHOICES,
        blank=True,
        default="",
    )
    answer_text = models.TextField(
        blank=True,
        default="",
        help_text="Leaf response or informational message returned to user",
    )
    product = models.ForeignKey(
        Product,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="chatbot_options",
    )
    quotation = models.ForeignKey(
        Quotation,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="chatbot_options",
    )
    keywords = models.TextField(
        blank=True,
        default="",
        help_text="Comma-separated keywords for natural language search matching",
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["order", "title"]

    def __str__(self):
        if self.parent:
            return f"{self.parent.title} -> {self.title}"
        return f"[{self.inquiry_type.upper()}] {self.title}"

    @property
    def has_children(self):
        return self.children.filter(is_active=True).exists()


class ChatSession(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE, null=True, blank=True, related_name='chat_sessions')
    session_id = models.CharField(max_length=100, blank=True, default='')
    customer_name = models.CharField(max_length=150, blank=True, default='')
    customer_phone = models.CharField(max_length=30, blank=True, default='')
    customer_email = models.CharField(max_length=150, blank=True, default='')
    app_type = models.CharField(max_length=30, default='customer')
    chatbot_mode = models.CharField(max_length=30, default='public')
    inquiry_type = models.CharField(max_length=30, blank=True, default='customer')
    lead = models.ForeignKey('leads.Lead', on_delete=models.SET_NULL, null=True, blank=True, related_name='chat_sessions')
    lead_capture_completed = models.BooleanField(default=False)
    status = models.CharField(max_length=30, default='active')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-updated_at']

    def __str__(self):
        user_str = self.user.username if self.user else (self.customer_name or self.session_id or f"Guest-{self.id}")
        return f"ChatSession {self.id}: {user_str} ({self.app_type})"


class ChatMessage(models.Model):
    session = models.ForeignKey(ChatSession, on_delete=models.CASCADE, related_name='messages')
    role = models.CharField(max_length=20)  # user, assistant, system
    content = models.TextField()
    timestamp = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['timestamp']

    def __str__(self):
        return f"{self.role}: {self.content[:30]}..."


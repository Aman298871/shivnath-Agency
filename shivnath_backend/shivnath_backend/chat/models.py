from django.db import models
from django.contrib.auth.models import User
from products.models import Product


class Quotation(models.Model):
    QUOTATION_TYPE_CHOICES = [
        ("customer", "Customer Quotation"),
        ("bottle", "Bottle Quotation"),
        ("jar", "Jar Quotation"),
        ("franchise", "Franchise Quotation"),
        ("bulk", "Bulk Quantity Quotation"),
        ("custom", "Custom Quotation"),
    ]

    TARGET_AUDIENCE_CHOICES = [
        ("customer", "Customer"),
        ("franchise", "Franchise"),
        ("both", "Both"),
    ]

    title = models.CharField(max_length=200)
    quotation_type = models.CharField(
        max_length=50,
        choices=QUOTATION_TYPE_CHOICES,
        default="customer",
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
    applicable_terms = models.TextField(
        blank=True,
        default="Standard delivery and purity warranty terms apply.",
    )
    notes = models.TextField(blank=True, default="")
    validity = models.CharField(
        max_length=100,
        blank=True,
        default="Valid for 30 days from generation",
    )
    target_audience = models.CharField(
        max_length=30,
        choices=TARGET_AUDIENCE_CHOICES,
        default="customer",
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

    def __str__(self):
        return f"{self.title} (₹{self.total_price or self.unit_price})"


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


from django.db import models
from django.contrib.auth.models import User


class Supplier(models.Model):
    STATUS_CHOICES = (
        ("Active", "Active"),
        ("Inactive", "Inactive"),
    )

    supplier_code = models.CharField(
        max_length=50,
        unique=True,
        null=True,
        blank=True,
        db_index=True,
        help_text="e.g. SUP-PRE-001"
    )

    name = models.CharField(max_length=200)

    contact = models.CharField(
        max_length=150,
        blank=True,
        default=""
    )

    phone = models.CharField(
        max_length=15,
        unique=True
    )

    email = models.EmailField(
        blank=True,
        default=""
    )

    category = models.CharField(
        max_length=100,
        blank=True,
        default="",
        help_text="e.g. Preforms, Caps, Labels, Packaging, Water Treatment Chemicals"
    )

    gst = models.CharField(
        max_length=20,
        blank=True,
        default=""
    )

    city = models.CharField(
        max_length=100,
        blank=True,
        default=""
    )

    payment_terms_days = models.PositiveIntegerField(
        default=15,
        help_text="Supplier credit / payment terms in days"
    )

    status = models.CharField(
        max_length=20,
        choices=STATUS_CHOICES,
        default="Active"
    )

    created_at = models.DateTimeField(
        auto_now_add=True
    )

    updated_at = models.DateTimeField(
        auto_now=True
    )

    class Meta:
        ordering = ["-id"]
        verbose_name = "Supplier"
        verbose_name_plural = "Suppliers"

    def __str__(self):
        return f"{self.name} ({self.category or 'General'})"


class PurchaseOrder(models.Model):
    """
    Purchase Order issued to a Supplier for procurement of raw materials.
    Receipt of PO logs PURCHASE_IN ledger transactions and increases RawMaterial stock.
    """
    STATUS_CHOICES = [
        ('DRAFT', 'Draft PO'),
        ('ORDERED', 'Placed / Ordered to Supplier'),
        ('RECEIVED', 'Goods Received & Stock Updated'),
        ('CANCELLED', 'Cancelled'),
    ]

    po_number = models.CharField(
        max_length=50,
        unique=True,
        db_index=True,
        help_text="e.g. PO-202609-001"
    )
    supplier = models.ForeignKey(
        Supplier,
        on_delete=models.PROTECT,
        related_name='purchase_orders'
    )
    total_amount = models.DecimalField(
        max_digits=14,
        decimal_places=2,
        default=0.00
    )
    tax_amount = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        default=0.00
    )
    grand_total = models.DecimalField(
        max_digits=14,
        decimal_places=2,
        default=0.00
    )
    status = models.CharField(
        max_length=20,
        choices=STATUS_CHOICES,
        default='DRAFT'
    )
    order_date = models.DateField(auto_now_add=True)
    received_date = models.DateField(null=True, blank=True)
    created_by = models.ForeignKey(
        User,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name='created_purchase_orders'
    )
    notes = models.TextField(blank=True, default='')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']
        verbose_name = 'Purchase Order'
        verbose_name_plural = 'Purchase Orders'

    def __str__(self):
        return f"{self.po_number} -> {self.supplier.name} (₹{self.grand_total}) [{self.status}]"


class PurchaseOrderItem(models.Model):
    """
    Relational line item in a Purchase Order specifying the exact RawMaterial procured.
    """
    purchase_order = models.ForeignKey(
        PurchaseOrder,
        on_delete=models.CASCADE,
        related_name='items'
    )
    raw_material = models.ForeignKey(
        'inventory.RawMaterial',
        on_delete=models.PROTECT,
        related_name='purchase_order_items'
    )
    quantity = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        help_text="Ordered quantity in raw material unit of measure"
    )
    unit_price = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        help_text="Purchase cost per unit in INR"
    )
    total_price = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        default=0.00
    )
    received_quantity = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        default=0.00,
        help_text="Actually received and accepted quantity"
    )

    class Meta:
        verbose_name = 'Purchase Order Item'
        verbose_name_plural = 'Purchase Order Items'

    def __str__(self):
        return f"{self.raw_material.name}: {self.quantity} {self.raw_material.unit_of_measure} @ ₹{self.unit_price}"

    def save(self, *args, **kwargs):
        if not self.total_price:
            self.total_price = self.quantity * self.unit_price
        super().save(*args, **kwargs)
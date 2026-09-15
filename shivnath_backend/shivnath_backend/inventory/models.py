from django.db import models
from django.contrib.auth.models import User


class InventoryItem(models.Model):

    TYPE_CHOICES = [
        ('raw_material', 'Raw Material'),
        ('finished_product', 'Finished Product'),
    ]

    UNIT_CHOICES = [
        ('pcs', 'Pcs'),
        ('bottles', 'Bottles'),
        ('jars', 'Jars'),
        ('kg', 'Kg'),
    ]

    name = models.CharField(
        max_length=255,
    )

    item_type = models.CharField(
        max_length=20,
        choices=TYPE_CHOICES,
        default='raw_material',
    )

    sku = models.CharField(
        max_length=100,
        blank=True,
    )

    unit = models.CharField(
        max_length=20,
        choices=UNIT_CHOICES,
        default='pcs',
    )

    stock = models.PositiveIntegerField(
        default=0,
    )

    min_stock = models.PositiveIntegerField(
        default=0,
    )

    purchase_rate = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        default=0,
    )

    batch = models.CharField(
        max_length=100,
        blank=True,
    )

    supplier = models.CharField(
        max_length=255,
        blank=True,
    )

    created_by = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='created_inventory_items',
    )

    created_at = models.DateTimeField(
        auto_now_add=True,
    )

    updated_at = models.DateTimeField(
        auto_now=True,
    )

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f'{self.name} ({self.sku})'


class StockRequest(models.Model):

    TYPE_CHOICES = [
        ('stock_in', 'Stock In'),
        ('stock_out', 'Stock Out'),
    ]

    STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('approved', 'Approved'),
        ('rejected', 'Rejected'),
    ]

    item = models.ForeignKey(
        InventoryItem,
        on_delete=models.CASCADE,
        related_name='stock_requests',
    )

    request_type = models.CharField(
        max_length=20,
        choices=TYPE_CHOICES,
    )

    quantity = models.PositiveIntegerField()

    reason = models.TextField(
        blank=True,
    )

    rejection_reason = models.TextField(
        blank=True,
    )

    status = models.CharField(
        max_length=20,
        choices=STATUS_CHOICES,
        default='pending',
    )

    requested_by = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='inventory_requests_made',
    )

    approved_by = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='inventory_requests_approved',
    )

    created_at = models.DateTimeField(
        auto_now_add=True,
    )

    approved_at = models.DateTimeField(
        null=True,
        blank=True,
    )

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return (
            f'{self.request_type} '
            f'- {self.item.name} '
            f'({self.quantity})'
        )
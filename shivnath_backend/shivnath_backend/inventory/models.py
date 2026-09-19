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


class RawMaterialTransfer(models.Model):
    """
    Admin dispatching raw materials to a Franchise.
    """
    STATUS_CHOICES = [
        ('dispatched', 'Dispatched'),
        ('in_transit', 'In Transit'),
        ('received', 'Received'),
        ('cancelled', 'Cancelled'),
    ]

    franchise = models.ForeignKey(
        'accounts.FranchiseProfile',
        on_delete=models.CASCADE,
        related_name='raw_material_transfers',
    )
    item = models.ForeignKey(
        InventoryItem,
        on_delete=models.PROTECT,
        related_name='transfers',
        limit_choices_to={'item_type': 'raw_material'},
    )
    quantity = models.PositiveIntegerField()
    dispatched_by = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='dispatched_transfers',
    )
    received_by = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='received_transfers',
    )
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='dispatched')
    dispatch_date = models.DateField(auto_now_add=True)
    received_date = models.DateField(null=True, blank=True)
    batch_ref = models.CharField(max_length=100, blank=True)
    notes = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"Transfer {self.item.name} x{self.quantity} -> {self.franchise.business_name} [{self.status}]"


class FranchiseRawMaterial(models.Model):
    """
    Local raw material stock at a specific Franchise.
    Updated when transfers are received.
    """
    UNIT_CHOICES = [
        ('pcs', 'Pcs'),
        ('bottles', 'Bottles'),
        ('jars', 'Jars'),
        ('kg', 'Kg'),
        ('litre', 'Litre'),
    ]

    franchise = models.ForeignKey(
        'accounts.FranchiseProfile',
        on_delete=models.CASCADE,
        related_name='raw_material_stocks',
    )
    item = models.ForeignKey(
        InventoryItem,
        on_delete=models.PROTECT,
        related_name='franchise_stocks',
        limit_choices_to={'item_type': 'raw_material'},
    )
    current_stock = models.PositiveIntegerField(default=0)
    unit = models.CharField(max_length=20, choices=UNIT_CHOICES, default='pcs')
    min_alert_level = models.PositiveIntegerField(default=10)
    last_updated = models.DateTimeField(auto_now=True)

    class Meta:
        unique_together = ('franchise', 'item')
        ordering = ['franchise', 'item__name']

    def __str__(self):
        return f"{self.franchise.business_name}: {self.item.name} ({self.current_stock} {self.unit})"


class LocalProductionLog(models.Model):
    """
    Franchise logs local production of finished products from raw materials.
    """
    franchise = models.ForeignKey(
        'accounts.FranchiseProfile',
        on_delete=models.CASCADE,
        related_name='production_logs',
    )
    product = models.ForeignKey(
        'products.Product',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='production_logs',
    )
    product_name = models.CharField(max_length=200, blank=True, default='')
    quantity_produced = models.PositiveIntegerField()
    raw_materials_used = models.JSONField(default=dict, blank=True, help_text="e.g. {'item_id': quantity_used}")
    production_date = models.DateField(auto_now_add=True)
    notes = models.TextField(blank=True)
    logged_by = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='production_logs',
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.franchise.business_name}: {self.product_name} x{self.quantity_produced} on {self.production_date}"


class FranchiseInventoryTransaction(models.Model):
    """
    General ledger transaction for franchise inventory changes (stock in/out).
    """
    TRANSACTION_TYPE_CHOICES = [
        ('stock_in_transfer', 'Stock In - Raw Material Transfer'),
        ('stock_in_production', 'Stock In - Local Production'),
        ('stock_out_sale', 'Stock Out - Sale/Order'),
        ('stock_out_damage', 'Stock Out - Damage/Waste'),
        ('adjustment', 'Manual Adjustment'),
    ]

    franchise = models.ForeignKey(
        'accounts.FranchiseProfile',
        on_delete=models.CASCADE,
        related_name='inventory_transactions',
    )
    item = models.ForeignKey(
        InventoryItem,
        on_delete=models.PROTECT,
        related_name='franchise_transactions',
        null=True,
        blank=True,
    )
    transaction_type = models.CharField(max_length=30, choices=TRANSACTION_TYPE_CHOICES)
    quantity = models.IntegerField(help_text="Positive for stock in, negative for stock out")
    reference_id = models.PositiveIntegerField(null=True, blank=True, help_text="ID of related transfer/production/order")
    notes = models.TextField(blank=True)
    created_by = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='inventory_transactions',
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.franchise.business_name}: {self.transaction_type} {self.quantity}"
from django.db import models
from django.contrib.auth.models import User
from products.models import Product


class Order(models.Model):

    STATUS_CHOICES = [
        ('order_placement', 'Order Placement'),
        ('plant_approval', 'Plant Approval / Admin Approved'),
        ('invoice_generated', 'Invoice Generated'),
        ('preparing', 'Preparing / Bottling'),
        ('dispatch', 'Dispatch / In Transit'),
        ('delivered', 'Delivered'),
        ('payment_collection', 'Payment Collection'),
        ('cancelled', 'Cancelled'),
    ]

    ORDER_SOURCE_CHOICES = [
        ('FRANCHISE', 'Franchise Fulfilled'),
        ('DIRECT_COMPANY', 'Direct Company Fulfilled (Shivnath Agency Central Plant)'),
    ]

    PAYMENT_CHOICES = [
        ('pending', 'Pending'),
        ('partial', 'Partial'),
        ('paid', 'Paid'),
    ]

    franchise_name = models.CharField(
        max_length=255,
    )

    city = models.CharField(
        max_length=100,
    )

    order_date = models.DateField(
        auto_now_add=True,
    )

    items_count = models.PositiveIntegerField(
        default=0,
    )

    amount = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        default=0,
        help_text="Subtotal amount snapshot at placement time"
    )

    tax_amount = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        default=0,
        help_text="Tax amount snapshot at placement time"
    )

    grand_total = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        default=0,
        help_text="Grand total snapshot at placement time"
    )

    status = models.CharField(
        max_length=30,
        choices=STATUS_CHOICES,
        default='order_placement',
    )

    payment_status = models.CharField(
        max_length=20,
        choices=PAYMENT_CHOICES,
        default='pending',
    )

    created_by = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='created_orders',
    )

    serving_franchise = models.ForeignKey(
        'accounts.FranchiseProfile',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='orders_fulfilled',
        help_text="The exact wholesale dealer fulfilling this order (Null for Direct Company orders)."
    )

    registered_franchise = models.ForeignKey(
        'accounts.FranchiseProfile',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='orders_from_registered_customers',
        help_text="The dealer under which the customer was originally registered."
    )

    snapshot_serving_dealer_id = models.PositiveIntegerField(
        null=True,
        blank=True,
        help_text="Permanent immutable snapshot of serving dealer ID"
    )

    snapshot_serving_dealer_name = models.CharField(
        max_length=255,
        blank=True,
        default='',
        help_text="Permanent immutable snapshot of serving dealer business name"
    )

    snapshot_territory = models.CharField(
        max_length=150,
        blank=True,
        default='',
        help_text="Permanent immutable snapshot of territory at order time"
    )

    zone = models.ForeignKey(
        'accounts.ServiceZone',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='orders'
    )

    duration_choice = models.CharField(
        max_length=30,
        default='1 Month'
    )

    duration_days = models.PositiveIntegerField(
        default=30
    )

    expected_end_date = models.DateField(
        null=True,
        blank=True
    )

    order_source = models.CharField(
        max_length=30,
        choices=ORDER_SOURCE_CHOICES,
        default='FRANCHISE',
        help_text="Whether this order is served by a Wholesale Dealer or directly by Shivnath Agency."
    )

    territory = models.CharField(
        max_length=150,
        blank=True,
        default='',
        help_text="Customer's territory/zone at order time (snapshot)."
    )

    delivery_address = models.TextField(
        blank=True,
        default='',
        help_text="Full delivery address for this order."
    )

    delivered_at = models.DateTimeField(
        null=True,
        blank=True,
        help_text="Timestamp when order reached DELIVERED status (authoritative revenue recognition event)"
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
        return f'ORD-{self.id:04d} - {self.franchise_name or self.order_source}'

    @property
    def order_code(self):
        return f'ORD-{1000 + self.id}'

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self._original_status = self.status

    def save(self, *args, **kwargs):
        is_new = self.pk is None
        old_status = getattr(self, '_original_status', '') if not is_new else ''
        new_status = self.status
        if not self.grand_total and self.amount:
            self.grand_total = self.amount + self.tax_amount
        if self.serving_franchise:
            if not self.snapshot_serving_dealer_id:
                self.snapshot_serving_dealer_id = self.serving_franchise.id
            if not self.snapshot_serving_dealer_name:
                self.snapshot_serving_dealer_name = self.serving_franchise.business_name
        if self.territory and not self.snapshot_territory:
            self.snapshot_territory = self.territory
        super().save(*args, **kwargs)
        self._original_status = self.status

        # Enforce automatic OrderStatusHistory record creation on any status transition
        if is_new or (old_status and old_status != new_status):
            from django.utils import timezone
            from datetime import timedelta
            actor = getattr(self, '_actor', None) or self.created_by
            notes = getattr(self, '_status_notes', '')
            if not notes:
                if is_new:
                    notes = 'Initial order placement'
                elif new_status == 'cancelled':
                    notes = 'Order cancelled'
                elif new_status == 'dispatch':
                    notes = 'Order dispatched'
                elif new_status == 'delivered':
                    notes = 'Order delivered'
                elif new_status == 'plant_approval':
                    notes = 'Admin plant approval'
                else:
                    notes = f'Status changed from {old_status} to {new_status}'

            recent = OrderStatusHistory.objects.filter(
                order=self,
                old_status=old_status,
                new_status=new_status,
                created_at__gte=timezone.now() - timedelta(seconds=2)
            ).exists()
            if not recent:
                OrderStatusHistory.objects.create(
                    order=self,
                    old_status=old_status,
                    new_status=new_status,
                    changed_by=actor if getattr(actor, 'is_authenticated', False) else None,
                    notes=notes
                )



class OrderItem(models.Model):
    order = models.ForeignKey(
        Order,
        on_delete=models.CASCADE,
        related_name='items',
    )
    product = models.ForeignKey(
        Product,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='order_items',
    )
    product_name = models.CharField(
        max_length=200,
        default='',
    )
    size = models.CharField(
        max_length=100,
        blank=True,
        default='',
    )
    quantity = models.PositiveIntegerField(
        default=1,
    )
    unit_price = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        default=0,
    )
    total_price = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        default=0,
    )
    snapshot_unit_production_cost = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        default=0.00,
        help_text="Permanently frozen unit production cost at fulfillment time"
    )
    snapshot_total_cogs = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        default=0.00,
        help_text="Permanently frozen total COGS (quantity * snapshot_unit_production_cost)"
    )

    def __str__(self):
        return f"{self.quantity}x {self.product_name} in ORD-{self.order.id}"

    def save(self, *args, **kwargs):
        if not self.total_price:
            self.total_price = self.quantity * self.unit_price
        if self.snapshot_unit_production_cost and not self.snapshot_total_cogs:
            self.snapshot_total_cogs = self.quantity * self.snapshot_unit_production_cost
        super().save(*args, **kwargs)


class OrderItemBatchReservation(models.Model):
    """
    Relational stock reservation model.
    Connects order items to ProductionBatch (Direct Company) or DealerStockBatch (Dealer Order).
    Guarantees available_stock = remaining_quantity - reserved_quantity without double allocation.
    """
    order_item = models.ForeignKey(
        OrderItem,
        on_delete=models.CASCADE,
        related_name='batch_reservations'
    )
    production_batch = models.ForeignKey(
        'inventory.ProductionBatch',
        null=True,
        blank=True,
        on_delete=models.PROTECT,
        related_name='order_reservations',
        help_text="Direct Company fulfillment production batch"
    )
    dealer_stock_batch = models.ForeignKey(
        'inventory.DealerStockBatch',
        null=True,
        blank=True,
        on_delete=models.PROTECT,
        related_name='order_reservations',
        help_text="Dealer fulfillment local stock batch"
    )
    reserved_quantity = models.PositiveIntegerField(
        help_text="Quantity reserved upon order placement/approval"
    )
    released_quantity = models.PositiveIntegerField(
        default=0,
        help_text="Quantity released upon cancellation before dispatch"
    )
    consumed_quantity = models.PositiveIntegerField(
        default=0,
        help_text="Quantity physically deducted upon dispatch"
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = 'Order Item Batch Reservation'
        verbose_name_plural = 'Order Item Batch Reservations'

    def __str__(self):
        batch_ref = self.production_batch.batch_number if self.production_batch else (self.dealer_stock_batch.batch_number if self.dealer_stock_batch else 'No Batch')
        return f"Reservation {self.reserved_quantity} units -> {self.order_item.product_name} (Batch: {batch_ref})"


class OrderStatusHistory(models.Model):
    """
    Immutable audit log of every order status change.
    """
    order = models.ForeignKey(
        Order,
        on_delete=models.CASCADE,
        related_name='status_history',
    )
    old_status = models.CharField(max_length=30, blank=True, default='')
    new_status = models.CharField(max_length=30)
    changed_by = models.ForeignKey(
        'auth.User',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='order_status_changes',
    )
    notes = models.TextField(blank=True, default='')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f'ORD-{self.order.id}: {self.old_status} -> {self.new_status}'
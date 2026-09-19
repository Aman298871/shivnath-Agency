from django.db import models
from django.contrib.auth.models import User
from products.models import Product


class Order(models.Model):

    STATUS_CHOICES = [
        ('order_placement', 'Order Placement'),
        ('plant_approval', 'Plant Approval'),
        ('invoice_generated', 'Invoice Generated'),
        ('dispatch', 'Dispatch'),
        ('delivered', 'Delivered'),
        ('payment_collection', 'Payment Collection'),
        ('cancelled', 'Cancelled'),
    ]

    ORDER_SOURCE_CHOICES = [
        ('FRANCHISE', 'Franchise'),
        ('DIRECT_COMPANY', 'Direct Company / Shivnath Agency'),
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
        help_text="The exact franchise fulfilling this order. Permanent ownership."
    )

    registered_franchise = models.ForeignKey(
        'accounts.FranchiseProfile',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='orders_from_registered_customers',
        help_text="The franchise under which the customer was originally registered."
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
        help_text="Whether this order is served by a Franchise or directly by Shivnath Agency."
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

    created_at = models.DateTimeField(
        auto_now_add=True,
    )

    updated_at = models.DateTimeField(
        auto_now=True,
    )

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f'ORD-{self.id:04d} - {self.franchise_name}'

    @property
    def order_code(self):
        return f'ORD-{1000 + self.id}'


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

    def __str__(self):
        return f"{self.quantity}x {self.product_name} in ORD-{self.order.id}"


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
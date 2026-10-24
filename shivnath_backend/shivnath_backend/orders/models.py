from decimal import Decimal
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
        ('WATER_WALLET_REDEMPTION', 'Water Wallet Redemption (Central Admin Fulfilled)'),
        ('WATER_WALLET', 'Water Wallet Payment (Central Admin Fulfilled)'),
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

    payment_mode = models.CharField(
        max_length=50,
        default='ONLINE',
        help_text="Payment mode snapshot (e.g. ONLINE, RAZORPAY, CASH, NEFT_RTGS)"
    )

    razorpay_order_id = models.CharField(
        max_length=100,
        blank=True,
        default='',
        db_index=True,
        help_text="Razorpay Order ID for online checkout"
    )

    razorpay_payment_id = models.CharField(
        max_length=100,
        blank=True,
        default='',
        db_index=True,
        help_text="Authoritative Razorpay Payment ID"
    )

    razorpay_signature = models.CharField(
        max_length=255,
        blank=True,
        default='',
        help_text="Razorpay HMAC signature"
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

    client_name = models.CharField(
        max_length=255,
        blank=True,
        default='',
        help_text="Direct client / company name placing bulk requirement (e.g. Digital Marketing Wala)"
    )

    label_requirement = models.CharField(
        max_length=255,
        blank=True,
        default='',
        help_text="Customer custom label/sticker requirement"
    )

    printing_requirement = models.CharField(
        max_length=255,
        blank=True,
        default='',
        help_text="Customer printing/branding specification"
    )

    branding_requirement = models.TextField(
        blank=True,
        default='',
        help_text="Customer branding & design instructions"
    )

    custom_shelf_life_days = models.PositiveIntegerField(
        null=True,
        blank=True,
        help_text="Configured shelf life in days requested for this order"
    )

    total_produced_units = models.PositiveIntegerField(
        default=0,
        help_text="Total units manufactured for this bulk order across batches"
    )

    total_delivered_units = models.PositiveIntegerField(
        default=0,
        help_text="Total units collected / delivered to customer so far"
    )

    total_pending_stock_units = models.PositiveIntegerField(
        default=0,
        help_text="Remaining units still held in company stock pending customer collection"
    )

    delivered_at = models.DateTimeField(
        null=True,
        blank=True,
        help_text="Timestamp when order reached DELIVERED status (authoritative revenue recognition event)"
    )

    points_redeemed = models.PositiveIntegerField(
        default=0,
        help_text="Reward points redeemed for this order"
    )

    points_discount_amount = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        default=Decimal('0.00'),
        help_text="Monetary value discount in INR granted by redeemed points"
    )

    discount_amount = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        default=Decimal('0.00'),
        help_text="Promotional or approved discount amount in INR"
    )

    wallet_amount_debited = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        default=Decimal('0.00'),
        help_text="Amount debited from customer Water Wallet prepaid balance in INR"
    )

    remaining_payable_amount = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        default=Decimal('0.00'),
        help_text="Remaining cash or online payable amount in INR after redemption"
    )

    delivery_charges = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        default=Decimal('0.00'),
        help_text="Authoritative delivery fee snapshot in INR"
    )

    delivery_distance_km = models.DecimalField(
        max_digits=8,
        decimal_places=2,
        null=True,
        blank=True,
        help_text="Calculated delivery distance from origin in kilometers"
    )

    delivery_latitude = models.DecimalField(
        max_digits=10,
        decimal_places=6,
        null=True,
        blank=True,
        help_text="Delivery destination latitude"
    )

    delivery_longitude = models.DecimalField(
        max_digits=10,
        decimal_places=6,
        null=True,
        blank=True,
        help_text="Delivery destination longitude"
    )

    is_gst_requested = models.BooleanField(
        default=False,
        help_text="Whether customer requested a formal GST Tax Invoice"
    )

    gstin = models.CharField(
        max_length=30,
        blank=True,
        default='',
        help_text="Customer's business GSTIN snapshot"
    )

    gst_legal_name = models.CharField(
        max_length=255,
        blank=True,
        default='',
        help_text="Customer legal business name for GST"
    )

    gst_billing_address = models.TextField(
        blank=True,
        default='',
        help_text="Customer legal billing address for GST"
    )

    gst_state_name = models.CharField(
        max_length=100,
        blank=True,
        default='',
        help_text="Place of supply / customer state name"
    )

    gst_pincode = models.CharField(
        max_length=10,
        blank=True,
        default='',
        help_text="Customer billing PIN code"
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
            actor = getattr(self, '_actor', None)
            if not actor:
                if is_new:
                    actor = self.created_by
                elif new_status == 'plant_approval':
                    from django.contrib.auth import get_user_model
                    User = get_user_model()
                    actor = User.objects.filter(is_superuser=True).first()
                elif new_status in ['dispatch', 'delivered', 'invoice_generated', 'invoice']:
                    if self.serving_franchise and self.serving_franchise.user:
                        actor = self.serving_franchise.user
                    else:
                        from django.contrib.auth import get_user_model
                        User = get_user_model()
                        actor = User.objects.filter(is_superuser=True).first()
                else:
                    actor = self.created_by

            notes = getattr(self, '_status_notes', '')
            if not notes:
                client_disp = self.client_name or (self.created_by.get_full_name() if self.created_by else '') or 'Client'
                franchise_disp = self.snapshot_serving_dealer_name or (self.serving_franchise.business_name if self.serving_franchise else '') or (self.franchise_name if self.franchise_name and self.franchise_name.lower() != 'direct company' else 'Shivnath Central Plant Admin')
                if is_new:
                    notes = f'Initial order placed by client {client_disp}'
                elif new_status == 'cancelled':
                    notes = f'Order cancelled'
                elif new_status == 'dispatch':
                    notes = f'Dispatched for delivery by {franchise_disp}'
                elif new_status == 'delivered':
                    notes = f'Order successfully delivered to {client_disp} by {franchise_disp}'
                elif new_status == 'plant_approval':
                    notes = f'Plant approval confirmed by Shivnath Central Admin'
                elif new_status in ['invoice_generated', 'invoice']:
                    notes = f'Tax invoice generated by {franchise_disp}'
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


class Wallet(models.Model):
    """
    Authoritative server-managed prepaid wallet for a customer.
    Balance represents the verified available funds for order payments.
    reward_points represents verified redeemable reward points earned from orders.
    """
    user = models.OneToOneField(
        User,
        on_delete=models.CASCADE,
        related_name='water_wallet'
    )
    balance = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        default=Decimal('0.00'),
        help_text="Authoritative server-managed wallet balance in INR"
    )
    reward_points = models.PositiveIntegerField(
        default=0,
        help_text="Authoritative server-managed reward points balance"
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = 'Water Wallet'
        verbose_name_plural = 'Water Wallets'

    def __str__(self):
        return f"Wallet ({self.user.username}): ₹{self.balance} | {self.reward_points} Pts"

    def reconcile_balance(self, auto_fix=False):
        """
        Audit function: Recomputes balance directly from the immutable transaction ledger.
        Ensures consistency between cached balance and ledger history.
        """
        from django.db.models import Sum
        credits = self.transactions.filter(
            status='SUCCESS',
            transaction_type__in=['RECHARGE', 'ORDER_REFUND', 'ADMIN_ADJUSTMENT']
        ).aggregate(s=Sum('amount'))['s'] or Decimal('0.00')

        debits = self.transactions.filter(
            status='SUCCESS',
            transaction_type='ORDER_DEBIT'
        ).aggregate(s=Sum('amount'))['s'] or Decimal('0.00')

        computed = max(Decimal('0.00'), credits - debits)
        matches = (computed == self.balance)
        if not matches and auto_fix:
            self.balance = computed
            self.save(update_fields=['balance', 'updated_at'])
        return matches, computed

    def reconcile_points(self, auto_fix=False):
        """
        Audit function: Recomputes points directly from immutable ledger transactions.
        """
        from django.db.models import Sum
        credits = self.transactions.filter(
            status='SUCCESS',
            transaction_type__in=['POINTS_EARNED', 'POINTS_REFUNDED']
        ).aggregate(s=Sum('points'))['s'] or 0

        debits = self.transactions.filter(
            status='SUCCESS',
            transaction_type='POINTS_REDEEMED'
        ).aggregate(s=Sum('points'))['s'] or 0

        # debits stored as negative or positive? Handled by abs(debits)
        computed = max(0, credits - abs(debits))
        matches = (computed == self.reward_points)
        if not matches and auto_fix:
            self.reward_points = computed
            self.save(update_fields=['reward_points', 'updated_at'])
        return matches, computed


class WalletTransaction(models.Model):
    """
    Immutable ledger of every wallet credit, debit, refund, or adjustment.
    """
    TRANSACTION_TYPE_CHOICES = [
        ('RECHARGE', 'Wallet Top-up / Recharge'),
        ('ORDER_DEBIT', 'Order Payment Debit'),
        ('ORDER_REFUND', 'Order Cancellation Refund'),
        ('POINTS_EARNED', 'Reward Points Earned'),
        ('POINTS_REDEEMED', 'Reward Points Redeemed'),
        ('POINTS_REFUNDED', 'Reward Points Restored'),
        ('ADMIN_ADJUSTMENT', 'Authorized Admin Adjustment'),
    ]

    STATUS_CHOICES = [
        ('PENDING', 'Pending Payment / Processing'),
        ('SUCCESS', 'Success / Completed'),
        ('FAILED', 'Failed / Cancelled'),
        ('REVERSED', 'Reversed'),
    ]

    transaction_id = models.CharField(
        max_length=64,
        unique=True,
        db_index=True,
        help_text="Unique internal transaction reference (e.g. WTX-YYYYMMDD-UUID)"
    )
    wallet = models.ForeignKey(
        Wallet,
        on_delete=models.CASCADE,
        related_name='transactions'
    )
    transaction_type = models.CharField(
        max_length=30,
        choices=TRANSACTION_TYPE_CHOICES,
        db_index=True
    )
    amount = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        default=Decimal('0.00'),
        help_text="Transaction monetary amount in INR"
    )
    points = models.IntegerField(
        default=0,
        help_text="Reward points credited (+) or debited (-) in this transaction"
    )
    balance_after = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        null=True,
        blank=True,
        help_text="Snapshot of wallet balance after this transaction completed"
    )
    points_balance_after = models.PositiveIntegerField(
        null=True,
        blank=True,
        help_text="Snapshot of reward points balance after this transaction completed"
    )
    status = models.CharField(
        max_length=20,
        choices=STATUS_CHOICES,
        default='PENDING',
        db_index=True
    )
    # Payment gateway fields (used for RECHARGE)
    razorpay_order_id = models.CharField(
        max_length=100,
        blank=True,
        default='',
        db_index=True,
        help_text="Razorpay Order ID"
    )
    razorpay_payment_id = models.CharField(
        max_length=100,
        blank=True,
        default='',
        db_index=True,
        help_text="Authoritative Razorpay Payment ID"
    )
    razorpay_signature = models.CharField(
        max_length=255,
        blank=True,
        default='',
        help_text="Cryptographic HMAC signature from Razorpay"
    )
    # Order association (used for ORDER_DEBIT, ORDER_REFUND, POINTS_EARNED, POINTS_REDEEMED)
    order = models.ForeignKey(
        'orders.Order',
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name='wallet_transactions'
    )
    idempotency_key = models.CharField(
        max_length=100,
        unique=True,
        null=True,
        blank=True,
        db_index=True,
        help_text="Client or server idempotency key to prevent replay attacks"
    )
    description = models.TextField(
        blank=True,
        default=''
    )
    created_at = models.DateTimeField(auto_now_add=True)
    completed_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['wallet', '-created_at']),
            models.Index(fields=['status', 'transaction_type']),
        ]

    def __str__(self):
        pts_str = f" | {self.points:+d} Pts" if self.points != 0 else ""
        return f"{self.transaction_id} ({self.transaction_type}): ₹{self.amount}{pts_str} [{self.status}]"


class WalletRedemptionRule(models.Model):
    """
    Authoritative Admin-configurable rules for Water Wallet reward points & product redemption.
    """
    rupees_spent_per_point = models.DecimalField(
        max_digits=8,
        decimal_places=2,
        default=Decimal('10.00'),
        help_text="Amount in ₹ spent on eligible orders to earn 1 reward point (default: 10.00)"
    )
    points_per_rupee_discount = models.DecimalField(
        max_digits=8,
        decimal_places=2,
        default=Decimal('2.00'),
        help_text="Number of points needed for ₹1.00 discount (e.g. 2.00 points = ₹1.00 discount, meaning 100 points = ₹50.00)"
    )
    min_points_to_redeem = models.PositiveIntegerField(
        default=100,
        help_text="Minimum points required to initiate product redemption (default: 100)"
    )
    is_active = models.BooleanField(
        default=True,
        help_text="Whether this redemption rule is actively applied"
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = 'Wallet Redemption Rule'
        verbose_name_plural = 'Wallet Redemption Rules'
        ordering = ['-created_at']

    def __str__(self):
        return f"Rule: ₹{self.rupees_spent_per_point} = 1 Pt | {self.points_per_rupee_discount} Pts = ₹1 | Min: {self.min_points_to_redeem} Pts"

    @classmethod
    def get_active_rule(cls):
        rule = cls.objects.filter(is_active=True).first()
        if not rule:
            rule = cls.objects.create(
                rupees_spent_per_point=Decimal('10.00'),
                points_per_rupee_discount=Decimal('2.00'),
                min_points_to_redeem=100,
                is_active=True,
            )
        return rule


class CustomBrandedOrderRequest(models.Model):
    """
    Customer custom branded drinking water request:
    Allows customers to submit bottle specifications, customized brand/sticker requirements,
    and artwork uploads.
    """
    STATUS_CHOICES = [
        ('submitted', 'Submitted'),
        ('under_review', 'Under Review'),
        ('quoted', 'Quoted'),
        ('accepted', 'Accepted'),
        ('rejected', 'Rejected'),
        ('converted', 'Converted to Order'),
    ]

    customer = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='custom_branded_requests'
    )
    client_name = models.CharField(
        max_length=255,
        help_text="Customer's business or personal brand name (e.g. Acme Tech Solutions, Wedding of Ravi & Priya)"
    )
    bottle_size = models.CharField(
        max_length=100,
        default='500ml',
        help_text="Bottle or Jar size (e.g. 250ml, 500ml, 1000ml, 20L)"
    )
    package_type = models.CharField(
        max_length=50,
        default='BOTTLE',
        help_text="BOTTLE or JAR"
    )
    quantity = models.PositiveIntegerField(
        help_text="Requested quantity (minimum 1)"
    )
    label_requirement = models.TextField(
        blank=True,
        default='',
        help_text="Sticker/label design requirements, branding guidelines, colors"
    )
    printing_requirement = models.TextField(
        blank=True,
        default='',
        help_text="Printing specifications (e.g. Metallic sticker, Glossy finish, UV printing)"
    )
    artwork_file = models.FileField(
        upload_to='custom_orders/artwork/',
        null=True,
        blank=True,
        help_text="Uploaded logo, label artwork, or reference design (PDF, PNG, JPG)"
    )
    delivery_address = models.TextField(
        help_text="Target delivery address"
    )
    delivery_city = models.CharField(
        max_length=100,
        default='Raipur'
    )
    requested_delivery_date = models.DateField(
        null=True,
        blank=True,
        help_text="Target delivery deadline"
    )
    additional_notes = models.TextField(
        blank=True,
        default='',
        help_text="Special requirements, packing instructions"
    )
    status = models.CharField(
        max_length=30,
        choices=STATUS_CHOICES,
        default='submitted'
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"CustomReq #{self.id}: {self.quantity}x {self.bottle_size} for {self.client_name} ({self.customer.username})"


class CustomOrderQuotation(models.Model):
    """
    Cost-based Quotation with Margin vs Markup calculation and audit snapshots:
    Admin inputs itemized costs (bottle, sticker, printing, packaging, labour, transport, setup, wastage),
    selects margin on selling price [C / (1 - M%)] or markup on cost [C * (1 + M%)],
    previews and sends quotation to customer.
    """
    CALC_CHOICES = [
        ('MARGIN', 'Margin on Selling Price [Selling = Cost / (1 - M%)]'),
        ('MARKUP', 'Markup on Cost [Selling = Cost * (1 + M%)]'),
    ]

    STATUS_CHOICES = [
        ('DRAFT', 'Draft'),
        ('SENT', 'Sent to Customer'),
        ('ACCEPTED', 'Accepted by Customer'),
        ('REJECTED', 'Rejected'),
        ('SUPERSEDED', 'Superseded by Revision'),
    ]

    request = models.ForeignKey(
        CustomBrandedOrderRequest,
        on_delete=models.CASCADE,
        related_name='quotations'
    )
    version = models.PositiveIntegerField(default=1)
    created_by = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='created_custom_quotations'
    )
    
    # Cost Breakdown Components (Admin Internal)
    bottle_water_cost = models.DecimalField(max_digits=12, decimal_places=2, default=Decimal('0.00'), help_text="Total bottle & water production cost")
    sticker_material_cost = models.DecimalField(max_digits=12, decimal_places=2, default=Decimal('0.00'), help_text="Sticker label material stock cost")
    printing_cost = models.DecimalField(max_digits=12, decimal_places=2, default=Decimal('0.00'), help_text="Printing, plate/cylinder, ink charges")
    packaging_cost = models.DecimalField(max_digits=12, decimal_places=2, default=Decimal('0.00'), help_text="Carton, corrugated box, shrink wrap packaging")
    labour_production_cost = models.DecimalField(max_digits=12, decimal_places=2, default=Decimal('0.00'), help_text="Labour, machine running & bottling")
    transport_delivery_cost = models.DecimalField(max_digits=12, decimal_places=2, default=Decimal('0.00'), help_text="Freight, loading & delivery cost")
    setup_design_cost = models.DecimalField(max_digits=12, decimal_places=2, default=Decimal('0.00'), help_text="One-time design/setup/die charge")
    wastage_allowance_cost = models.DecimalField(max_digits=12, decimal_places=2, default=Decimal('0.00'), help_text="Wastage & contingency allowance")
    other_charges = models.DecimalField(max_digits=12, decimal_places=2, default=Decimal('0.00'), help_text="Separate customer-facing charges (F)")

    # Calculation logic
    calculation_type = models.CharField(max_length=20, choices=CALC_CHOICES, default='MARGIN')
    target_percentage = models.DecimalField(max_digits=6, decimal_places=2, default=Decimal('20.00'), help_text="Target Margin % or Markup %")
    
    # Computed Totals
    total_cost = models.DecimalField(max_digits=12, decimal_places=2, default=Decimal('0.00'), help_text="Total direct & indirect cost (C)")
    selling_price_before_charges = models.DecimalField(max_digits=12, decimal_places=2, default=Decimal('0.00'), help_text="Selling price before separate charges")
    final_quotation_total = models.DecimalField(max_digits=12, decimal_places=2, default=Decimal('0.00'), help_text="Final quotation grand total")
    unit_quotation_price = models.DecimalField(max_digits=10, decimal_places=2, default=Decimal('0.00'), help_text="Per-unit quotation rate")

    # Safeguards & Customer View
    include_breakdown_to_customer = models.BooleanField(default=False, help_text="Whether to show itemized internal cost breakdown to customer")
    quotation_validity_days = models.PositiveIntegerField(default=30)
    valid_until = models.DateField(null=True, blank=True)
    payment_terms = models.CharField(max_length=255, default='50% advance, balance on dispatch')
    delivery_estimate_days = models.PositiveIntegerField(default=7)
    admin_notes = models.TextField(blank=True, default='', help_text="Internal Admin notes (never shown to customer)")
    customer_notes = models.TextField(blank=True, default='', help_text="Customer-facing terms & conditions")

    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='DRAFT')
    accepted_at = models.DateTimeField(null=True, blank=True)
    converted_order = models.ForeignKey(
        Order,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name='custom_quotation_origin'
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['request', '-version']

    def calculate_totals(self, quantity=None):
        """
        Calculates authoritative totals:
        C = direct & indirect costs
        Margin: selling_before = C / (1 - M / 100)
        Markup: selling_before = C * (1 + M / 100)
        final_total = selling_before + F (other_charges)
        unit_price = final_total / Q
        """
        if quantity is None:
            quantity = self.request.quantity
        if quantity <= 0:
            raise ValueError("Quantity must be greater than zero.")

        # Total Cost C
        c = (
            self.bottle_water_cost +
            self.sticker_material_cost +
            self.printing_cost +
            self.packaging_cost +
            self.labour_production_cost +
            self.transport_delivery_cost +
            self.setup_design_cost +
            self.wastage_allowance_cost
        )
        self.total_cost = c.quantize(Decimal('0.01'))

        # Selling price before separate charges
        p = self.target_percentage
        if self.calculation_type == 'MARGIN':
            if p >= Decimal('100.00'):
                raise ValueError("Margin percentage must be less than 100%.")
            if p < Decimal('0.00'):
                raise ValueError("Margin percentage cannot be negative.")
            # selling = C / (1 - M / 100)
            denominator = Decimal('1.00') - (p / Decimal('100.00'))
            selling_before = c / denominator
        else:  # MARKUP
            if p < Decimal('0.00'):
                raise ValueError("Markup percentage cannot be negative.")
            # selling = C * (1 + M / 100)
            selling_before = c * (Decimal('1.00') + (p / Decimal('100.00')))

        self.selling_price_before_charges = selling_before.quantize(Decimal('0.01'))
        
        # Final quotation total = selling_before + F
        final_total = self.selling_price_before_charges + self.other_charges
        self.final_quotation_total = final_total.quantize(Decimal('0.01'))
        
        # Per unit = Final total / Q
        self.unit_quotation_price = (self.final_quotation_total / Decimal(str(quantity))).quantize(Decimal('0.01'))
        return self.final_quotation_total
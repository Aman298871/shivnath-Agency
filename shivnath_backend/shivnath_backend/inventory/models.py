from django.db import models
from django.contrib.auth.models import User
import uuid
import hashlib


# =====================================================================
# AUTHORITATIVE RAW MATERIALS MASTER
# =====================================================================

class RawMaterial(models.Model):
    """
    Authoritative master for raw materials: raw water, preforms, caps, labels, boxes, chemicals.
    """
    CATEGORY_CHOICES = [
        ('raw_water', 'Raw Water'),
        ('preform', 'Bottle Preform'),
        ('cap', 'Cap / Closure'),
        ('label', 'Label / Sticker'),
        ('packaging', 'Carton / Box / Shrink Wrap'),
        ('chemical', 'Water Treatment Chemical / Consumable'),
    ]

    UNIT_CHOICES = [
        ('litres', 'Litres'),
        ('pcs', 'Pieces'),
        ('rolls', 'Rolls'),
        ('boxes', 'Boxes / Cartons'),
        ('kg', 'Kilograms'),
    ]

    sku = models.CharField(
        max_length=50,
        unique=True,
        db_index=True,
        help_text="Unique SKU (e.g. RM-WAT-01, RM-PRF-200, RM-CAP-01, RM-LBL-200, RM-BOX-24)"
    )
    name = models.CharField(max_length=200)
    category = models.CharField(max_length=30, choices=CATEGORY_CHOICES, default='preform')
    unit_of_measure = models.CharField(max_length=20, choices=UNIT_CHOICES, default='pcs')
    unit_cost = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        default=0.00,
        help_text="Standard unit purchase cost in INR"
    )
    current_stock = models.DecimalField(
        max_digits=14,
        decimal_places=2,
        default=0.00,
        help_text="Available stock quantity at company central plant"
    )
    reorder_level = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        default=100.00,
        help_text="Stock level triggering reorder warning"
    )
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['category', 'name']
        verbose_name = 'Raw Material'
        verbose_name_plural = 'Raw Materials'

    def __str__(self):
        return f"{self.name} ({self.sku}) - {self.current_stock} {self.unit_of_measure}"


# =====================================================================
# AUTHORITATIVE PRODUCTION & FINISHED GOODS BATCHES
# =====================================================================

class ProductionBatch(models.Model):
    """
    Central plant production batch for finished bottled / jar drinking water.
    Supports batch-level FEFO allocation for company dispatches and Direct Company orders.
    """
    STATUS_CHOICES = [
        ('ACTIVE', 'Active / In Stock'),
        ('DEPLETED', 'Fully Depleted'),
        ('EXPIRED', 'Expired / Disposed'),
        ('RECALLED', 'Recalled / Quarantined'),
    ]

    batch_number = models.CharField(
        max_length=100,
        unique=True,
        db_index=True,
        help_text="e.g. PB-202609-001"
    )
    product = models.ForeignKey(
        'products.Product',
        on_delete=models.PROTECT,
        related_name='production_batches'
    )
    manufacture_date = models.DateField(db_index=True)
    expiry_date = models.DateField(db_index=True)
    quantity_produced_units = models.PositiveIntegerField(
        help_text="Total units manufactured in this batch"
    )
    quantity_remaining_company = models.PositiveIntegerField(
        help_text="Remaining units available at company central plant"
    )
    reserved_quantity = models.PositiveIntegerField(
        default=0,
        help_text="Units soft-reserved for placed/approved Direct Company orders"
    )
    unit_production_cost = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        default=0.00,
        help_text="Frozen BOM unit production cost snapshot at manufacture time"
    )
    client_name = models.CharField(
        max_length=255,
        blank=True,
        default='',
        help_text="Customer / client name for bulk custom order (e.g. Digital Marketing Wala)"
    )
    linked_order = models.ForeignKey(
        'orders.Order',
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name='production_batches',
        help_text="Linked Customer / Client Bulk Order"
    )
    label_requirement = models.CharField(
        max_length=255,
        blank=True,
        default='',
        help_text="Custom label / sticker requirement"
    )
    printing_requirement = models.CharField(
        max_length=255,
        blank=True,
        default='',
        help_text="Printing / branding specification"
    )
    branding_requirement = models.TextField(
        blank=True,
        default='',
        help_text="Branding notes / instructions"
    )
    shelf_life_days = models.PositiveIntegerField(
        null=True,
        blank=True,
        help_text="Configured shelf life in days for this batch (Expiry = Mfg + Shelf Life)"
    )
    quantity_dispatched = models.PositiveIntegerField(
        default=0,
        help_text="Quantity collected / taken / dispatched by client or dealer"
    )
    quantity_damaged = models.PositiveIntegerField(
        default=0,
        help_text="Quantity damaged or spoiled"
    )
    quantity_returned = models.PositiveIntegerField(
        default=0,
        help_text="Quantity returned"
    )
    status = models.CharField(
        max_length=20,
        choices=STATUS_CHOICES,
        default='ACTIVE'
    )
    created_by = models.ForeignKey(
        User,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name='created_production_batches'
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['expiry_date', 'manufacture_date']
        verbose_name = 'Production Batch'
        verbose_name_plural = 'Production Batches'

    def __str__(self):
        return f"{self.batch_number} - {self.product.name} (Rem: {self.quantity_remaining_company}, Res: {self.reserved_quantity}, Exp: {self.expiry_date})"

    @property
    def quantity_allocated(self):
        return self.reserved_quantity

    @property
    def quantity_taken(self):
        return self.quantity_dispatched

    @property
    def quantity_pending_collection(self):
        """
        Quantity remaining to be collected by client / customer.
        Example: Produced 5,000 - Taken 2,000 = 3,000 Pending.
        """
        return max(0, self.quantity_produced_units - self.quantity_dispatched - self.quantity_damaged)

    @property
    def dynamic_remaining_company(self):
        """
        Dynamically calculated remaining stock in central company warehouse:
        Produced - Dispatched - Damaged + Returned
        """
        return max(0, self.quantity_produced_units - self.quantity_dispatched - self.quantity_damaged + self.quantity_returned)

    @property
    def available_quantity(self):
        return max(0, self.quantity_remaining_company - self.reserved_quantity)

    @property
    def is_expired(self):
        from django.utils import timezone
        return timezone.now().date() >= self.expiry_date


class DealerStockBatch(models.Model):
    """
    Wholesale Dealer local warehouse stock batch.
    Received from company dispatches. Supports strict FEFO allocation for retail/consumer orders.
    """
    dealer = models.ForeignKey(
        'accounts.FranchiseProfile',
        on_delete=models.CASCADE,
        related_name='stock_batches'
    )
    product = models.ForeignKey(
        'products.Product',
        on_delete=models.PROTECT,
        related_name='dealer_batches'
    )
    batch_number = models.CharField(max_length=100, db_index=True)
    manufacture_date = models.DateField()
    expiry_date = models.DateField(db_index=True)
    received_quantity = models.PositiveIntegerField(default=0)
    remaining_quantity = models.PositiveIntegerField(default=0)
    reserved_quantity = models.PositiveIntegerField(
        default=0,
        help_text="Units soft-reserved for active customer orders assigned to this dealer"
    )
    damaged_quantity = models.PositiveIntegerField(default=0)
    unit_transfer_price = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        default=0.00,
        help_text="Wholesale purchase price paid by dealer per unit"
    )
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['expiry_date', 'manufacture_date']
        verbose_name = 'Dealer Stock Batch'
        verbose_name_plural = 'Dealer Stock Batches'

    def __str__(self):
        return f"[{self.dealer.business_name}] {self.product.name} ({self.batch_number}) Rem: {self.remaining_quantity}, Res: {self.reserved_quantity} (Exp: {self.expiry_date})"

    @property
    def available_quantity(self):
        return max(0, self.remaining_quantity - self.reserved_quantity)

    @property
    def is_expired(self):
        from django.utils import timezone
        return timezone.now().date() >= self.expiry_date


# =====================================================================
# DEALER STOCK REQUEST LIFECYCLE & RELATIONAL ALLOCATION
# =====================================================================

class DealerStockRequest(models.Model):
    """
    Wholesale Dealer request to company for finished product stock.
    Supports full partial lifecycle: Requested -> Approved -> Prepared -> Dispatched -> Received.
    """
    STATUS_CHOICES = [
        ('REQUESTED', 'Requested by Dealer'),
        ('APPROVED', 'Approved by Admin (Can be partial)'),
        ('PREPARED', 'Prepared in Plant Warehouse'),
        ('DISPATCHED', 'Dispatched to Dealer (Can be partial)'),
        ('RECEIVED', 'Received & Confirmed by Dealer'),
        ('PARTIALLY_FULFILLED', 'Partially Fulfilled'),
        ('REJECTED', 'Rejected by Admin'),
    ]

    request_number = models.CharField(max_length=50, unique=True, db_index=True)
    dealer = models.ForeignKey(
        'accounts.FranchiseProfile',
        on_delete=models.CASCADE,
        related_name='dealer_stock_requests'
    )
    product = models.ForeignKey(
        'products.Product',
        on_delete=models.PROTECT,
        related_name='dealer_stock_requests'
    )
    requested_quantity = models.PositiveIntegerField()
    approved_quantity = models.PositiveIntegerField(default=0)
    prepared_quantity = models.PositiveIntegerField(default=0)
    dispatched_quantity = models.PositiveIntegerField(default=0)
    received_quantity = models.PositiveIntegerField(default=0)
    damaged_in_transit_quantity = models.PositiveIntegerField(default=0)
    status = models.CharField(max_length=30, choices=STATUS_CHOICES, default='REQUESTED')
    dealer_notes = models.TextField(blank=True, default='')
    admin_notes = models.TextField(blank=True, default='')
    approved_by = models.ForeignKey(
        User,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name='approved_dealer_stock_requests'
    )
    dispatched_by = models.ForeignKey(
        User,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name='dispatched_dealer_stock_requests'
    )
    received_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']
        verbose_name = 'Dealer Stock Request'
        verbose_name_plural = 'Dealer Stock Requests'

    def __str__(self):
        return f"{self.request_number} - {self.dealer.business_name}: {self.product.name} ({self.requested_quantity} req) [{self.status}]"

    @property
    def pending_dispatch_quantity(self):
        return max(0, self.approved_quantity - self.dispatched_quantity)

    @property
    def pending_approval_quantity(self):
        return max(0, self.requested_quantity - self.approved_quantity)


class DealerStockRequestAllocation(models.Model):
    """
    Relational multi-batch allocation for a DealerStockRequest.
    Connects a stock request to specific ProductionBatch records across the lifecycle.
    """
    stock_request = models.ForeignKey(
        DealerStockRequest,
        on_delete=models.CASCADE,
        related_name='allocations'
    )
    production_batch = models.ForeignKey(
        ProductionBatch,
        on_delete=models.PROTECT,
        related_name='dealer_request_allocations'
    )
    allocated_quantity = models.PositiveIntegerField(
        default=0,
        help_text="Quantity approved/allocated from this production batch"
    )
    prepared_quantity = models.PositiveIntegerField(
        default=0,
        help_text="Quantity prepared/packaged from this batch"
    )
    dispatched_quantity = models.PositiveIntegerField(
        default=0,
        help_text="Quantity dispatched from this batch"
    )
    received_quantity = models.PositiveIntegerField(
        default=0,
        help_text="Quantity successfully received by dealer from this batch"
    )
    damaged_quantity = models.PositiveIntegerField(
        default=0,
        help_text="Quantity reported damaged/lost in transit from this batch"
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['production_batch__expiry_date']
        verbose_name = 'Stock Request Batch Allocation'
        verbose_name_plural = 'Stock Request Batch Allocations'

    def __str__(self):
        return f"{self.stock_request.request_number} -> Batch {self.production_batch.batch_number}: {self.allocated_quantity} units"


# =====================================================================
# AUTHORITATIVE IMMUTABLE INVENTORY TRANSACTION LEDGER
# =====================================================================

class InventoryTransactionLedger(models.Model):
    """
    Authoritative, immutable single source of truth for all finished goods and raw material stock movements.
    Every quantity modification must write a row to this ledger inside an atomic transaction.
    """
    TRANSACTION_TYPES = [
        ('PURCHASE_IN', 'Raw Material / Component Stock Received from Supplier'),
        ('PRODUCTION_CONSUMPTION', 'Raw Material Consumed During Production'),
        ('PRODUCTION_IN', 'Finished Goods Created by Production'),
        ('STOCK_TRANSFER_OUT', 'Company Stock Transferred/Dispatched to Dealer'),
        ('STOCK_TRANSFER_IN', 'Dealer Receives Stock Transfer'),
        ('SALE', 'Finished Stock Sold to Customer / Retailer'),
        ('RETURN', 'Stock Returned / Restocked'),
        ('DAMAGE', 'Damaged / Spoiled Stock Logged'),
        ('EXPIRY', 'Expired / Disposed Stock'),
        ('ADJUSTMENT', 'Authorized Stock Audit Correction'),
    ]

    MATERIAL_TYPES = [
        ('FINISHED_GOODS', 'Finished Pure Drinking Water Product'),
        ('RAW_MATERIAL', 'Raw Material / Component / Packaging'),
    ]

    LOCATION_TYPES = [
        ('COMPANY_WAREHOUSE', 'Central Plant / Company Warehouse'),
        ('DEALER_WAREHOUSE', 'Wholesale Dealer Warehouse'),
    ]

    transaction_id = models.UUIDField(
        default=uuid.uuid4,
        editable=False,
        unique=True,
        db_index=True
    )
    transaction_type = models.CharField(
        max_length=30,
        choices=TRANSACTION_TYPES,
        db_index=True
    )
    material_type = models.CharField(
        max_length=20,
        choices=MATERIAL_TYPES,
        default='FINISHED_GOODS'
    )
    location_type = models.CharField(
        max_length=25,
        choices=LOCATION_TYPES,
        default='COMPANY_WAREHOUSE'
    )
    dealer = models.ForeignKey(
        'accounts.FranchiseProfile',
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name='ledger_transactions'
    )
    product = models.ForeignKey(
        'products.Product',
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name='inventory_ledger_entries'
    )
    raw_material = models.ForeignKey(
        RawMaterial,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name='inventory_ledger_entries'
    )
    production_batch = models.ForeignKey(
        ProductionBatch,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name='ledger_transactions'
    )
    dealer_batch = models.ForeignKey(
        DealerStockBatch,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name='ledger_transactions'
    )
    quantity = models.DecimalField(
        max_digits=14,
        decimal_places=2,
        help_text="Signed quantity (+ for addition, - for deduction/consumption)"
    )
    balance_after = models.DecimalField(
        max_digits=14,
        decimal_places=2,
        default=0.00,
        help_text="Stock balance immediately after this transaction"
    )
    unit_cost_or_price = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        default=0.00,
        help_text="Unit cost or unit transfer/selling price in INR"
    )
    reference_type = models.CharField(
        max_length=50,
        blank=True,
        default='',
        help_text="e.g. PURCHASE_ORDER, PRODUCTION_BATCH, STOCK_REQUEST, ORDER, MANUAL_ADJUSTMENT"
    )
    reference_id = models.CharField(
        max_length=100,
        blank=True,
        default='',
        help_text="ID or Number of related entity"
    )
    actor = models.ForeignKey(
        User,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name='inventory_actions_performed'
    )
    notes = models.TextField(blank=True, default='')
    timestamp = models.DateTimeField(auto_now_add=True, db_index=True)

    class Meta:
        ordering = ['-timestamp']
        verbose_name = 'Inventory Transaction Ledger'
        verbose_name_plural = 'Inventory Transaction Ledgers'

    def __str__(self):
        item_name = self.product.name if self.product else (self.raw_material.name if self.raw_material else 'Item')
        return f"[{self.timestamp.strftime('%Y-%m-%d %H:%M')}] {self.transaction_type}: {self.quantity} {item_name} @ ₹{self.unit_cost_or_price}"


# =====================================================================
# 5-TIER EXPIRY ALERT LOG & DEDUPLICATION
# =====================================================================

class ExpiryAlertLog(models.Model):
    """
    Logs batch expiry warnings at 30, 15, 7, 3, and 0 days.
    Deduplicates using state-based hash (batch_type:id:alert_level) to prevent repetitive daily spam.
    """
    ALERT_LEVELS = [
        ('30_DAYS', '30 Days to Expiry'),
        ('15_DAYS', '15 Days to Expiry'),
        ('7_DAYS', '7 Days to Expiry'),
        ('3_DAYS', '3 Days to Expiry'),
        ('0_DAYS_EXPIRED', '0 Days / Batch Expired'),
    ]

    BATCH_TYPES = [
        ('COMPANY', 'Company Production Batch'),
        ('DEALER', 'Dealer Stock Batch'),
    ]

    batch_type = models.CharField(max_length=20, choices=BATCH_TYPES)
    dealer = models.ForeignKey(
        'accounts.FranchiseProfile',
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name='expiry_alert_logs'
    )
    production_batch = models.ForeignKey(
        ProductionBatch,
        null=True,
        blank=True,
        on_delete=models.CASCADE,
        related_name='expiry_alerts'
    )
    dealer_batch = models.ForeignKey(
        DealerStockBatch,
        null=True,
        blank=True,
        on_delete=models.CASCADE,
        related_name='expiry_alerts'
    )
    alert_level = models.CharField(max_length=20, choices=ALERT_LEVELS)
    alert_date = models.DateField(db_index=True)
    deduplication_hash = models.CharField(
        max_length=150,
        unique=True,
        db_index=True,
        help_text="Unique hash: batch_type:id:alert_level"
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']
        verbose_name = 'Expiry Alert Log'
        verbose_name_plural = 'Expiry Alert Logs'

    def __str__(self):
        return f"{self.deduplication_hash} on {self.alert_date}"

    @staticmethod
    def compute_hash(batch_type: str, batch_id: int, alert_level: str) -> str:
        """
        State-based deduplication hash: sha256(f"{batch_type}:{batch_id}:{alert_level}").
        Explicitly excludes report_date so running the expiry job on subsequent days
        never generates duplicate alerts for the same batch and tier.
        """
        clean_batch_type = str(batch_type).strip().upper()
        clean_batch_id = int(batch_id)
        clean_level = str(alert_level).strip().upper()
        return hashlib.sha256(f"{clean_batch_type}:{clean_batch_id}:{clean_level}".encode('utf-8')).hexdigest()


# =====================================================================
# FINANCIAL EXPENSES & DAILY BUSINESS SUMMARY
# =====================================================================

class Expense(models.Model):
    """
    Authoritative record of company operational expenses.
    """
    CATEGORY_CHOICES = [
        ('RAW_MATERIALS', 'Raw Materials & Components'),
        ('ELECTRICITY_WATER', 'Electricity & Water Treatment Utilities'),
        ('LABOUR_SALARY', 'Plant & Staff Salaries / Wages'),
        ('FUEL_TRANSPORT', 'Fuel, Logistics & Vehicle Maintenance'),
        ('PACKAGING_LABELS', 'Packaging, Cartons & Label Printing'),
        ('MAINTENANCE_REPAIRS', 'Machinery & RO Plant Maintenance'),
        ('MARKETING_PROMOTION', 'Marketing, Promotion & WhatsApp Outreach'),
        ('MISCELLANEOUS', 'Miscellaneous / General Overheads'),
    ]

    expense_number = models.CharField(max_length=50, unique=True, db_index=True)
    category = models.CharField(max_length=30, choices=CATEGORY_CHOICES)
    description = models.TextField()
    amount = models.DecimalField(max_digits=12, decimal_places=2)
    payment_method = models.CharField(max_length=50, default='UPI')
    receipt_image = models.ImageField(upload_to='expense_receipts/', null=True, blank=True)
    paid_date = models.DateField(db_index=True)
    recorded_by = models.ForeignKey(
        User,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name='recorded_expenses'
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-paid_date', '-created_at']
        verbose_name = 'Company Expense'
        verbose_name_plural = 'Company Expenses'

    def __str__(self):
        return f"{self.expense_number} - {self.get_category_display()}: ₹{self.amount} on {self.paid_date}"


class DailyBusinessReport(models.Model):
    """
    Authoritative aggregated daily business summary report.
    Calculates dual units & cases, gross revenue, snapshot COGS, expenses, and net profit.
    """
    report_date = models.DateField(unique=True, db_index=True)
    total_production_volume_units = models.PositiveIntegerField(default=0)
    total_production_volume_cases = models.DecimalField(max_digits=12, decimal_places=2, default=0.00)
    total_production_cost_inr = models.DecimalField(max_digits=14, decimal_places=2, default=0.00)
    total_dealer_dispatch_units = models.PositiveIntegerField(default=0)
    total_dealer_dispatch_cases = models.DecimalField(max_digits=12, decimal_places=2, default=0.00)
    total_dealer_sales_revenue_inr = models.DecimalField(max_digits=14, decimal_places=2, default=0.00)
    total_direct_company_revenue_inr = models.DecimalField(max_digits=14, decimal_places=2, default=0.00)
    total_gross_revenue_inr = models.DecimalField(max_digits=14, decimal_places=2, default=0.00)
    total_cogs_inr = models.DecimalField(max_digits=14, decimal_places=2, default=0.00)
    total_expenses_inr = models.DecimalField(max_digits=14, decimal_places=2, default=0.00)
    net_profit_inr = models.DecimalField(max_digits=14, decimal_places=2, default=0.00)
    new_leads_count = models.PositiveIntegerField(default=0)
    leads_converted_count = models.PositiveIntegerField(default=0)
    generated_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-report_date']
        verbose_name = 'Daily Business Report'
        verbose_name_plural = 'Daily Business Reports'

    def __str__(self):
        return f"Daily Report {self.report_date}: Rev=₹{self.total_gross_revenue_inr}, COGS=₹{self.total_cogs_inr}, Net=₹{self.net_profit_inr}"


# =====================================================================
# LEGACY COMPATIBILITY MODELS (PRESERVED)
# =====================================================================

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
    name = models.CharField(max_length=255)
    item_type = models.CharField(max_length=20, choices=TYPE_CHOICES, default='raw_material')
    sku = models.CharField(max_length=100, blank=True)
    unit = models.CharField(max_length=20, choices=UNIT_CHOICES, default='pcs')
    stock = models.PositiveIntegerField(default=0)
    min_stock = models.PositiveIntegerField(default=0)
    purchase_rate = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    batch = models.CharField(max_length=100, blank=True)
    supplier = models.CharField(max_length=255, blank=True)
    created_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True, related_name='created_inventory_items')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

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
    item = models.ForeignKey(InventoryItem, on_delete=models.CASCADE, related_name='stock_requests')
    request_type = models.CharField(max_length=20, choices=TYPE_CHOICES)
    quantity = models.PositiveIntegerField()
    reason = models.TextField(blank=True)
    rejection_reason = models.TextField(blank=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    requested_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True, related_name='inventory_requests_made')
    approved_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True, related_name='inventory_requests_approved')
    created_at = models.DateTimeField(auto_now_add=True)
    approved_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f'{self.request_type} - {self.item.name} ({self.quantity})'


class RawMaterialTransfer(models.Model):
    STATUS_CHOICES = [
        ('dispatched', 'Dispatched'),
        ('in_transit', 'In Transit'),
        ('received', 'Received'),
        ('cancelled', 'Cancelled'),
    ]
    franchise = models.ForeignKey('accounts.FranchiseProfile', on_delete=models.CASCADE, related_name='raw_material_transfers')
    item = models.ForeignKey(InventoryItem, on_delete=models.PROTECT, related_name='transfers', limit_choices_to={'item_type': 'raw_material'})
    quantity = models.PositiveIntegerField()
    dispatched_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True, related_name='dispatched_transfers')
    received_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True, related_name='received_transfers')
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='dispatched')
    dispatch_date = models.DateField(auto_now_add=True)
    received_date = models.DateField(null=True, blank=True)
    batch_ref = models.CharField(max_length=100, blank=True)
    notes = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']


class FranchiseRawMaterial(models.Model):
    UNIT_CHOICES = [
        ('pcs', 'Pcs'),
        ('bottles', 'Bottles'),
        ('jars', 'Jars'),
        ('kg', 'Kg'),
        ('litre', 'Litre'),
    ]
    franchise = models.ForeignKey('accounts.FranchiseProfile', on_delete=models.CASCADE, related_name='raw_material_stocks')
    item = models.ForeignKey(InventoryItem, on_delete=models.PROTECT, related_name='franchise_stocks', limit_choices_to={'item_type': 'raw_material'})
    current_stock = models.PositiveIntegerField(default=0)
    unit = models.CharField(max_length=20, choices=UNIT_CHOICES, default='pcs')
    min_alert_level = models.PositiveIntegerField(default=10)
    last_updated = models.DateTimeField(auto_now=True)

    class Meta:
        unique_together = ('franchise', 'item')
        ordering = ['franchise', 'item__name']


class LocalProductionLog(models.Model):
    franchise = models.ForeignKey('accounts.FranchiseProfile', on_delete=models.CASCADE, related_name='production_logs')
    product = models.ForeignKey('products.Product', on_delete=models.SET_NULL, null=True, blank=True, related_name='production_logs')
    product_name = models.CharField(max_length=200, blank=True, default='')
    quantity_produced = models.PositiveIntegerField()
    raw_materials_used = models.JSONField(default=dict, blank=True)
    production_date = models.DateField(auto_now_add=True)
    notes = models.TextField(blank=True)
    logged_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True, related_name='production_logs')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']


class FranchiseInventoryTransaction(models.Model):
    TRANSACTION_TYPE_CHOICES = [
        ('stock_in_transfer', 'Stock In - Raw Material Transfer'),
        ('stock_in_production', 'Stock In - Local Production'),
        ('stock_out_sale', 'Stock Out - Sale/Order'),
        ('stock_out_damage', 'Stock Out - Damage/Waste'),
        ('adjustment', 'Manual Adjustment'),
    ]
    franchise = models.ForeignKey('accounts.FranchiseProfile', on_delete=models.CASCADE, related_name='inventory_transactions')
    item = models.ForeignKey(InventoryItem, on_delete=models.PROTECT, related_name='franchise_transactions', null=True, blank=True)
    transaction_type = models.CharField(max_length=30, choices=TRANSACTION_TYPE_CHOICES)
    quantity = models.IntegerField()
    reference_id = models.PositiveIntegerField(null=True, blank=True)
    notes = models.TextField(blank=True)
    created_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True, related_name='inventory_transactions')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']
from django.db import models
from django.contrib.auth.models import User


class ProductCategory(models.Model):
    name = models.CharField(max_length=150)
    slug = models.SlugField(max_length=150, blank=True, default="")
    parent = models.ForeignKey(
        "self",
        on_delete=models.PROTECT,
        null=True,
        blank=True,
        related_name="children",
    )
    description = models.TextField(blank=True, default="")
    order = models.PositiveIntegerField(default=0)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["order", "name"]
        verbose_name_plural = "Product Categories"

    def __str__(self):
        if self.parent:
            return f"{self.parent.name} -> {self.name}"
        return self.name

    @property
    def full_path(self):
        if self.parent:
            return f"{self.parent.full_path} > {self.name}"
        return self.name

    def get_descendant_ids(self):
        descendants = [self.id]
        for child in self.children.all():
            descendants.extend(child.get_descendant_ids())
        return descendants


class Product(models.Model):

    CATEGORY_CHOICES = [
        ("Bottle", "Bottle"),
        ("Jar", "Jar"),
    ]

    STATUS_CHOICES = [
        ("Active", "Active"),
        ("Inactive", "Inactive"),
    ]

    PACKAGE_TYPE_CHOICES = [
        ("BOTTLE", "Bottle"),
        ("JAR", "Jar"),
    ]

    name = models.CharField(
        max_length=200,
    )

    sku = models.CharField(
        max_length=100,
        unique=True,
    )

    size = models.CharField(
        max_length=100,
    )

    volume_ml = models.PositiveIntegerField(
        default=0,
        help_text="Volume in milliliters (e.g. 200, 250, 500, 1000, 20000)"
    )

    package_type = models.CharField(
        max_length=20,
        choices=PACKAGE_TYPE_CHOICES,
        default="BOTTLE",
    )

    units_per_case = models.PositiveIntegerField(
        default=24,
        help_text="Number of units per standard carton or case (e.g. 24 for 200/250ml, 1 for 20L Jar)"
    )

    category = models.CharField(
        max_length=100,
        default="Bottle",
    )

    category_ref = models.ForeignKey(
        ProductCategory,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="products",
    )

    price = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        help_text="Customer unit retail / selling price in INR"
    )

    dealer_transfer_price = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        default=0.00,
        help_text="Wholesale transfer price charged to dealers per unit in INR"
    )

    mrp = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        default=0.00,
        help_text="Maximum Retail Price (MRP) printed on label in INR"
    )

    shelf_life_days = models.PositiveIntegerField(
        default=180,
        help_text="Standard shelf life in days from manufacture date (e.g. 180 days)"
    )

    gst = models.PositiveIntegerField(
        default=18,
    )

    stock = models.PositiveIntegerField(
        default=0,
    )

    status = models.CharField(
        max_length=20,
        choices=STATUS_CHOICES,
        default="Active",
    )

    image = models.ImageField(
        upload_to="products/",
        blank=True,
        null=True,
    )

    unit = models.CharField(
        max_length=30,
        default="Piece",
    )

    description = models.TextField(
        blank=True,
        default="",
    )

    created_at = models.DateTimeField(
        auto_now_add=True,
    )

    updated_at = models.DateTimeField(
        auto_now=True,
    )

    class Meta:
        ordering = [
            "name",
        ]
        indexes = [
            models.Index(fields=["sku"]),
            models.Index(fields=["category"]),
            models.Index(fields=["status"]),
        ]

    def save(self, *args, **kwargs):
        if self.category_ref and (not self.category or self.category in ["Bottle", "Jar", ""]):
            self.category = self.category_ref.name
        if not self.mrp:
            self.mrp = self.price
        super().save(*args, **kwargs)

    def __str__(self):
        return f"{self.name} ({self.sku})"


class ProductionRecipeBOM(models.Model):
    """
    Bill of Materials (BOM) recipe master for a finished drinking water product variant.
    Authoritative for production costing and P&L calculations.
    """
    product = models.OneToOneField(
        Product,
        on_delete=models.CASCADE,
        related_name="recipe_bom"
    )
    last_updated_by = models.ForeignKey(
        User,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="updated_boms"
    )
    notes = models.TextField(blank=True, default="")
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = "Production Recipe BOM"
        verbose_name_plural = "Production Recipe BOMs"

    def __str__(self):
        return f"BOM Recipe for {self.product.name} ({self.product.sku}) - Cost: ₹{self.total_production_cost_per_unit:.2f}/unit"

    @property
    def total_production_cost_per_unit(self):
        total = sum(item.calculated_cost_per_unit for item in self.items.all())
        return total


class ProductionRecipeBOMItem(models.Model):
    """
    Relational line item in a BOM recipe linking a specific Raw Material.
    """
    bom = models.ForeignKey(
        ProductionRecipeBOM,
        on_delete=models.CASCADE,
        related_name="items"
    )
    raw_material = models.ForeignKey(
        'inventory.RawMaterial',
        on_delete=models.PROTECT,
        related_name="bom_usages"
    )
    quantity_required_per_unit = models.DecimalField(
        max_digits=12,
        decimal_places=4,
        help_text="Quantity of this raw material required to produce ONE finished product unit"
    )
    unit_cost_snapshot = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        default=0.00,
        help_text="Cost per raw material unit at current recipe setting"
    )
    notes = models.CharField(max_length=200, blank=True, default="")

    class Meta:
        verbose_name = "BOM Recipe Item"
        verbose_name_plural = "BOM Recipe Items"

    def __str__(self):
        return f"{self.raw_material.name}: {self.quantity_required_per_unit} {self.raw_material.unit_of_measure} @ ₹{self.unit_cost_snapshot}"

    @property
    def calculated_cost_per_unit(self):
        return self.quantity_required_per_unit * self.unit_cost_snapshot


class ProductStockThreshold(models.Model):
    """
    Configurable low-stock thresholds for company plant and dealer warehouses.
    """
    product = models.OneToOneField(
        Product,
        on_delete=models.CASCADE,
        related_name="stock_threshold"
    )
    company_low_stock_threshold = models.PositiveIntegerField(
        default=100,
        help_text="Minimum company warehouse units before triggering low stock alert"
    )
    dealer_low_stock_threshold = models.PositiveIntegerField(
        default=20,
        help_text="Minimum dealer warehouse units before triggering low stock alert"
    )
    alert_enabled = models.BooleanField(default=True)

    class Meta:
        verbose_name = "Product Stock Threshold"
        verbose_name_plural = "Product Stock Thresholds"

    def __str__(self):
        return f"{self.product.name} Thresholds: Co={self.company_low_stock_threshold} / Dlr={self.dealer_low_stock_threshold}"
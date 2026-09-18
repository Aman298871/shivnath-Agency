from django.db import models


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
        super().save(*args, **kwargs)

    def __str__(self):
        return self.name
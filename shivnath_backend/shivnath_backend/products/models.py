from django.db import models


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
        max_length=30,
        choices=CATEGORY_CHOICES,
        default="Bottle",
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

    def __str__(self):
        return self.name
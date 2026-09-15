from django.db import models


class Supplier(models.Model):
    STATUS_CHOICES = (
        ("Active", "Active"),
        ("Inactive", "Inactive"),
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
        default=""
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

    def __str__(self):
        return self.name
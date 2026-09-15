from django.contrib import admin

from .models import Supplier


@admin.register(Supplier)
class SupplierAdmin(admin.ModelAdmin):

    list_display = (
        "id",
        "name",
        "contact",
        "phone",
        "category",
        "city",
        "status",
    )

    list_filter = (
        "status",
        "category",
        "city",
    )

    search_fields = (
        "name",
        "contact",
        "phone",
        "email",
        "gst",
        "city",
    )

    ordering = (
        "-id",
    )
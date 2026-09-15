from django.contrib import admin

from .models import (
    InventoryItem,
    StockRequest,
)


@admin.register(InventoryItem)
class InventoryItemAdmin(admin.ModelAdmin):

    list_display = [
        'id',
        'name',
        'item_type',
        'sku',
        'unit',
        'stock',
        'min_stock',
        'purchase_rate',
        'supplier',
        'is_low_stock',
        'created_at',
    ]

    list_filter = [
        'item_type',
        'unit',
    ]

    search_fields = [
        'name',
        'sku',
        'supplier',
        'batch',
    ]

    ordering = [
        '-created_at',
    ]

    readonly_fields = [
        'created_at',
        'updated_at',
    ]

    def is_low_stock(self, obj):
        return obj.stock <= obj.min_stock

    is_low_stock.boolean = True
    is_low_stock.short_description = 'Low Stock'


@admin.register(StockRequest)
class StockRequestAdmin(admin.ModelAdmin):

    list_display = [
        'id',
        'item',
        'request_type',
        'quantity',
        'status',
        'requested_by',
        'approved_by',
        'created_at',
        'approved_at',
    ]

    list_filter = [
        'request_type',
        'status',
    ]

    search_fields = [
        'item__name',
        'item__sku',
        'requested_by__username',
    ]

    ordering = [
        '-created_at',
    ]

    readonly_fields = [
        'created_at',
        'approved_at',
    ]
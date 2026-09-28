from django.contrib import admin

from .models import (
    InventoryItem,
    StockRequest,
    DealerStockRequest,
    DealerStockRequestAllocation,
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


class DealerStockRequestAllocationInline(admin.TabularInline):
    from .models import DealerStockRequestAllocation
    model = DealerStockRequestAllocation
    extra = 0
    fields = ['production_batch', 'allocated_quantity', 'allocated_at']
    readonly_fields = ['allocated_at']


@admin.register(DealerStockRequest)
class DealerStockRequestAdmin(admin.ModelAdmin):
    list_display = [
        'request_number',
        'dealer',
        'product',
        'requested_quantity',
        'approved_quantity',
        'dispatched_quantity',
        'received_quantity',
        'status',
        'created_at',
    ]
    list_filter = [
        'status',
        'product',
        'created_at',
    ]
    search_fields = [
        'request_number',
        'dealer__business_name',
        'dealer__owner_name',
        'dealer__phone',
        'product__name',
    ]
    ordering = ['-created_at']
    readonly_fields = ['created_at', 'received_at']
    inlines = [DealerStockRequestAllocationInline]


@admin.register(DealerStockRequestAllocation)
class DealerStockRequestAllocationAdmin(admin.ModelAdmin):
    list_display = [
        'id',
        'stock_request',
        'production_batch',
        'allocated_quantity',
        'allocated_at',
    ]
    list_filter = [
        'allocated_at',
    ]
    search_fields = [
        'stock_request__request_number',
        'production_batch__batch_number',
    ]
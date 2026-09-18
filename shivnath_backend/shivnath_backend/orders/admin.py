from django.contrib import admin
from .models import Order, OrderItem


class OrderItemInline(admin.TabularInline):
    model = OrderItem
    extra = 0
    fields = ('product', 'product_name', 'size', 'quantity', 'unit_price', 'total_price')
    readonly_fields = ('total_price',)


@admin.register(Order)
class OrderAdmin(admin.ModelAdmin):
    list_display = (
        'id',
        'order_code',
        'franchise_name',
        'serving_franchise',
        'registered_franchise',
        'zone',
        'items_count',
        'amount',
        'duration_choice',
        'status',
        'payment_status',
        'order_date',
    )
    list_filter = (
        'status',
        'payment_status',
        'duration_choice',
        'zone__district',
        'zone',
        'order_date',
    )
    search_fields = (
        'franchise_name',
        'created_by__email',
        'created_by__first_name',
        'created_by__last_name',
        'serving_franchise__business_name',
        'registered_franchise__business_name',
        'city',
    )
    readonly_fields = ('created_at', 'updated_at', 'order_code')
    inlines = [OrderItemInline]


@admin.register(OrderItem)
class OrderItemAdmin(admin.ModelAdmin):
    list_display = ('id', 'order', 'product_name', 'size', 'quantity', 'unit_price', 'total_price')
    list_filter = ('size',)
    search_fields = ('order__id', 'product_name')


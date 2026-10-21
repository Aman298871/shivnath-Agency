from django.contrib import admin
from .models import Order, OrderItem, Wallet, WalletTransaction, WalletRedemptionRule


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
        'order_source',
        'franchise_name',
        'serving_franchise',
        'registered_franchise',
        'items_count',
        'amount',
        'points_redeemed',
        'points_discount_amount',
        'wallet_amount_debited',
        'remaining_payable_amount',
        'status',
        'payment_status',
        'order_date',
    )
    list_filter = (
        'order_source',
        'status',
        'payment_status',
        'duration_choice',
        'zone__district',
        'zone',
        'order_date',
    )
    search_fields = (
        'id',
        'order_code',
        'order_source',
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


@admin.register(Wallet)
class WalletAdmin(admin.ModelAdmin):
    list_display = ('id', 'user', 'balance', 'reward_points', 'updated_at')
    search_fields = ('user__username', 'user__email', 'user__first_name', 'user__last_name')
    readonly_fields = ('created_at', 'updated_at')


@admin.register(WalletTransaction)
class WalletTransactionAdmin(admin.ModelAdmin):
    list_display = (
        'transaction_id',
        'wallet',
        'transaction_type',
        'amount',
        'points',
        'points_balance_after',
        'balance_after',
        'status',
        'order',
        'created_at',
    )
    list_filter = ('transaction_type', 'status', 'created_at')
    search_fields = ('transaction_id', 'wallet__user__username', 'razorpay_payment_id', 'description')
    readonly_fields = ('created_at',)


@admin.register(WalletRedemptionRule)
class WalletRedemptionRuleAdmin(admin.ModelAdmin):
    list_display = (
        'id',
        'is_active',
        'rupees_spent_per_point',
        'points_per_rupee_discount',
        'min_points_to_redeem',
        'updated_at',
    )
    list_filter = ('is_active',)
    readonly_fields = ('created_at', 'updated_at')

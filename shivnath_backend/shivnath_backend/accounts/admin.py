from django.contrib import admin
from django.utils import timezone

from .models import (
    UserProfile,
    FranchiseProfile,
    ServiceDistrict,
    ServiceZone,
    ServiceArea,
    FranchiseTerritoryAssignment,
    CustomerFranchiseRelationship,
    CustomerStockCycle,
    ServiceHoldHistory,
    CustomerBulkOrder,
    FranchiseNotification,
    StockAlertLog,
    CustomerNotification,
    AdminNotification,
    SupportContact,
    DealerDocument,
)


@admin.register(UserProfile)
class UserProfileAdmin(admin.ModelAdmin):

    list_display = (
        'user',
        'get_email',
        'phone',
        'role',
        'created_at',
    )

    list_filter = (
        'role',
    )

    search_fields = (
        'user__first_name',
        'user__email',
        'phone',
    )

    @admin.display(description='Email')
    def get_email(self, obj):
        return obj.user.email


class DealerDocumentInline(admin.TabularInline):
    model = DealerDocument
    extra = 0
    readonly_fields = ('uploaded_at',)

@admin.register(FranchiseProfile)
class FranchiseProfileAdmin(admin.ModelAdmin):
    inlines = [DealerDocumentInline]

    list_display = (
        'business_name',
        'get_owner',
        'get_email',
        'city',
        'status',
        'created_at',
    )

    list_filter = (
        'status',
        'city',
    )

    search_fields = (
        'business_name',
        'user__first_name',
        'user__email',
        'city',
        'gst_number',
    )

    actions = [
        'approve_franchises',
        'reject_franchises',
    ]

    @admin.display(description='Owner')
    def get_owner(self, obj):
        return obj.user.get_full_name()

    @admin.display(description='Email')
    def get_email(self, obj):
        return obj.user.email

    @admin.action(
        description='Approve selected franchises'
    )
    def approve_franchises(
        self,
        request,
        queryset
    ):
        queryset.update(
            status='approved',
            rejection_reason='',
            approved_at=timezone.now(),
        )

    @admin.action(
        description='Reject selected franchises'
    )
    def reject_franchises(
        self,
        request,
        queryset
    ):
        queryset.update(
            status='rejected',
            approved_at=None,
        )


@admin.register(ServiceDistrict)
class ServiceDistrictAdmin(admin.ModelAdmin):
    list_display = ('name', 'state', 'is_active', 'created_at')
    list_filter = ('state', 'is_active')
    search_fields = ('name', 'state')


@admin.register(ServiceZone)
class ServiceZoneAdmin(admin.ModelAdmin):
    list_display = ('name', 'code', 'district', 'is_active', 'created_at')
    list_filter = ('district', 'is_active')
    search_fields = ('name', 'code', 'district__name')


@admin.register(ServiceArea)
class ServiceAreaAdmin(admin.ModelAdmin):
    list_display = ('pincode', 'locality_name', 'zone', 'district', 'is_active', 'created_at')
    list_filter = ('district', 'zone', 'is_active')
    search_fields = ('pincode', 'locality_name', 'zone__name', 'district__name')


@admin.register(FranchiseTerritoryAssignment)
class FranchiseTerritoryAssignmentAdmin(admin.ModelAdmin):
    list_display = ('franchise', 'zone', 'is_primary', 'is_active', 'assigned_at')
    list_filter = ('is_primary', 'is_active', 'zone__district', 'zone')
    search_fields = ('franchise__business_name', 'zone__name', 'zone__district__name')


@admin.register(CustomerFranchiseRelationship)
class CustomerFranchiseRelationshipAdmin(admin.ModelAdmin):
    list_display = (
        'customer',
        'registered_franchise',
        'current_serving_franchise',
        'district',
        'zone',
        'pincode',
        'service_status',
        'updated_at',
    )
    list_filter = ('service_status', 'district', 'zone')
    search_fields = (
        'customer__email',
        'customer__first_name',
        'customer__last_name',
        'registered_franchise__business_name',
        'current_serving_franchise__business_name',
        'pincode',
        'locality',
    )
    readonly_fields = ('created_at', 'updated_at')


class ServiceHoldHistoryInline(admin.TabularInline):
    model = ServiceHoldHistory
    extra = 0
    readonly_fields = ('action', 'actor', 'actor_role', 'remaining_days', 'notes', 'created_at')
    can_delete = False


@admin.register(CustomerStockCycle)
class CustomerStockCycleAdmin(admin.ModelAdmin):
    list_display = (
        'id',
        'customer',
        'order',
        'product_name',
        'quantity',
        'serving_franchise',
        'duration_choice',
        'start_date',
        'expected_end_date',
        'get_days_remaining',
        'get_status',
    )
    list_filter = ('service_status', 'duration_choice', 'serving_franchise', 'district', 'zone')
    search_fields = (
        'customer__email',
        'customer__first_name',
        'serving_franchise__business_name',
        'registered_franchise__business_name',
        'order__id',
        'product_name',
    )
    readonly_fields = ('created_at', 'updated_at')
    inlines = [ServiceHoldHistoryInline]

    @admin.display(description='Days Left')
    def get_days_remaining(self, obj):
        return obj.days_remaining

    @admin.display(description='Status')
    def get_status(self, obj):
        return obj.computed_status


@admin.register(ServiceHoldHistory)
class ServiceHoldHistoryAdmin(admin.ModelAdmin):
    list_display = (
        'id',
        'customer',
        'stock_cycle',
        'action',
        'actor',
        'actor_role',
        'remaining_days',
        'created_at',
    )
    list_filter = ('action', 'actor_role', 'created_at')
    search_fields = ('customer__email', 'actor__email', 'notes')
    readonly_fields = ('created_at',)


@admin.register(CustomerBulkOrder)
class CustomerBulkOrderAdmin(admin.ModelAdmin):
    list_display = (
        'id',
        'customer',
        'product_name',
        'quantity',
        'duration_choice',
        'serving_franchise',
        'district',
        'zone_name',
        'required_date',
        'status',
        'created_at',
    )
    list_filter = ('status', 'duration_choice', 'district', 'serving_franchise')
    search_fields = (
        'customer__email',
        'product_name',
        'serving_franchise__business_name',
        'district',
        'zone_name',
    )
    readonly_fields = ('created_at', 'updated_at')


@admin.register(FranchiseNotification)
class FranchiseNotificationAdmin(admin.ModelAdmin):
    list_display = (
        'id',
        'franchise',
        'title',
        'notification_type',
        'is_read',
        'created_at',
    )
    list_filter = ('notification_type', 'is_read', 'franchise')
    search_fields = ('franchise__business_name', 'title', 'message')
    readonly_fields = ('created_at',)


@admin.register(StockAlertLog)
class StockAlertLogAdmin(admin.ModelAdmin):
    list_display = (
        'id',
        'stock_cycle',
        'alert_date',
        'recipient_type',
        'recipient_id',
        'days_remaining',
        'status',
        'created_at',
    )
    list_filter = ('recipient_type', 'status', 'alert_date')
    search_fields = ('stock_cycle__id', 'stock_cycle__customer__email', 'error_message')
    readonly_fields = ('created_at',)


@admin.register(CustomerNotification)
class CustomerNotificationAdmin(admin.ModelAdmin):
    list_display = (
        'id',
        'customer',
        'title',
        'notification_type',
        'is_read',
        'created_at',
    )
    list_filter = ('notification_type', 'is_read')
    search_fields = ('customer__email', 'title', 'message')
    readonly_fields = ('created_at',)


@admin.register(AdminNotification)
class AdminNotificationAdmin(admin.ModelAdmin):
    list_display = (
        'id',
        'title',
        'notification_type',
        'is_read',
        'created_at',
    )
    list_filter = ('notification_type', 'is_read')
    search_fields = ('title', 'message')
    readonly_fields = ('created_at',)


@admin.register(SupportContact)
class SupportContactAdmin(admin.ModelAdmin):
    list_display = (
        'role',
        'name',
        'phone',
        'email',
    )
    list_filter = ('role',)
    search_fields = ('name', 'phone', 'email')


@admin.register(DealerDocument)
class DealerDocumentAdmin(admin.ModelAdmin):
    list_display = (
        'dealer',
        'document_type',
        'verification_status',
        'uploaded_at',
    )
    list_filter = ('verification_status', 'document_type')
    search_fields = ('dealer__business_name', 'dealer__user__email')
    readonly_fields = ('uploaded_at',)


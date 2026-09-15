from django.contrib import admin
from django.utils import timezone

from .models import (
    UserProfile,
    FranchiseProfile,
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


@admin.register(FranchiseProfile)
class FranchiseProfileAdmin(admin.ModelAdmin):

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
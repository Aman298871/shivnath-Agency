from django.contrib import admin

from .models import (
    Lead,
    LeadActivity,
)


class LeadActivityInline(admin.TabularInline):

    model = LeadActivity

    extra = 0

    readonly_fields = [
        'created_at'
    ]


@admin.register(Lead)
class LeadAdmin(admin.ModelAdmin):

    list_display = [
        'id',
        'name',
        'phone',
        'city',
        'investment_budget',
        'score',
        'status',
        'assigned_executive',
        'next_followup',
        'created_at',
    ]

    list_filter = [
        'score',
        'status',
        'existing_business',
        'commercial_space',
        'city',
        'created_at',
    ]

    search_fields = [
        'name',
        'phone',
        'city',
        'district',
        'preferred_location',
        'assigned_executive',
    ]

    readonly_fields = [
        'created_at',
        'updated_at',
    ]

    inlines = [
        LeadActivityInline
    ]


@admin.register(LeadActivity)
class LeadActivityAdmin(admin.ModelAdmin):

    list_display = [
        'id',
        'lead',
        'activity_type',
        'title',
        'created_by',
        'created_at',
    ]

    list_filter = [
        'activity_type',
        'created_at',
    ]

    search_fields = [
        'lead__name',
        'lead__phone',
        'title',
        'description',
    ]

    readonly_fields = [
        'created_at'
    ]
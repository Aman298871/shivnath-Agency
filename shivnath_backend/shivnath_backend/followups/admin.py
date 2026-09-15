from django.contrib import admin

from .models import FollowUp


@admin.register(FollowUp)
class FollowUpAdmin(admin.ModelAdmin):

    list_display = (
        "id",
        "lead",
        "followup_datetime",
        "followup_type",
        "status",
        "created_by",
        "completed_at",
        "created_at",
    )

    list_filter = (
        "status",
        "followup_type",
        "followup_datetime",
        "created_at",
    )

    search_fields = (
        "lead__name",
        "lead__phone",
        "lead__city",
        "lead__assigned_executive",
        "note",
    )

    readonly_fields = (
        "created_at",
        "updated_at",
        "completed_at",
    )

    ordering = (
        "-followup_datetime",
    )

    autocomplete_fields = (
        "lead",
        "created_by",
    )

    fieldsets = (
        (
            "Lead Information",
            {
                "fields": (
                    "lead",
                ),
            },
        ),

        (
            "Follow-up Details",
            {
                "fields": (
                    "followup_datetime",
                    "followup_type",
                    "note",
                    "status",
                ),
            },
        ),

        (
            "System",
            {
                "fields": (
                    "created_by",
                    "completed_at",
                    "created_at",
                    "updated_at",
                ),
            },
        ),
    )
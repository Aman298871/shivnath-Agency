from rest_framework import serializers

from .models import FollowUp, FollowUpAuditLog


class FollowUpAuditLogSerializer(serializers.ModelSerializer):
    performed_by_name = serializers.SerializerMethodField()

    class Meta:
        model = FollowUpAuditLog
        fields = [
            "id",
            "followup_id",
            "lead_id",
            "action",
            "previous_status",
            "new_status",
            "previous_datetime",
            "new_datetime",
            "notes",
            "performed_by",
            "performed_by_name",
            "performed_at",
        ]

    def get_performed_by_name(self, obj):
        if obj.performed_by:
            return obj.performed_by.get_full_name() or obj.performed_by.username
        return "System"


class FollowUpSerializer(serializers.ModelSerializer):

    lead = serializers.SerializerMethodField()
    phone = serializers.SerializerMethodField()
    city = serializers.SerializerMethodField()
    executive = serializers.SerializerMethodField()
    date = serializers.SerializerMethodField()
    time = serializers.SerializerMethodField()
    original_date = serializers.SerializerMethodField()
    completed_by_name = serializers.SerializerMethodField()
    customer_or_franchise = serializers.SerializerMethodField()

    # ---- WRITE: actual model field, Flutter isi key se bhejta hai ----
    followup_type = serializers.CharField(
        required=False,
        default="Call",
    )

    # ---- READ: Flutter list screen isi key se padhta hai ----
    type = serializers.SerializerMethodField()

    class Meta:
        model = FollowUp

        fields = [
            "id",
            "lead_id",

            "lead",
            "phone",
            "city",
            "executive",
            "customer_or_franchise",

            "date",
            "time",
            "original_date",

            "followup_type",
            "type",

            "note",
            "outcome_notes",

            "status",

            "followup_datetime",
            "next_followup_date",
            "completed_at",
            "completed_by",
            "completed_by_name",

            "created_at",
            "updated_at",
        ]

        read_only_fields = [
            "id",
            "created_at",
            "updated_at",
            "completed_at",
            "completed_by",
        ]

    # -----------------------------
    # Lead Name
    # -----------------------------

    def get_lead(self, obj):
        return obj.lead.name

    # -----------------------------
    # Phone
    # -----------------------------

    def get_phone(self, obj):
        return obj.lead.phone

    # -----------------------------
    # City
    # -----------------------------

    def get_city(self, obj):
        return obj.lead.city

    # -----------------------------
    # Executive
    # -----------------------------

    def get_executive(self, obj):
        return obj.lead.assigned_executive

    # -----------------------------
    # Date
    # -----------------------------

    def get_date(self, obj):
        return obj.followup_datetime.strftime(
            "%Y-%m-%d"
        )

    # -----------------------------
    # Time
    # -----------------------------

    def get_time(self, obj):
        return obj.followup_datetime.strftime(
            "%H:%M"
        )

    # -----------------------------
    # Type (read-only alias for Flutter GET)
    # -----------------------------

    def get_type(self, obj):
        return obj.followup_type

    def get_completed_by_name(self, obj):
        if obj.completed_by:
            return obj.completed_by.get_full_name() or obj.completed_by.username
        return None

    def get_customer_or_franchise(self, obj):
        if obj.lead:
            return getattr(obj.lead, 'lead_type_display', '') or ('Customer' if getattr(obj.lead, 'lead_type', '') == 'CUSTOMER' else 'Franchise')
        return 'Franchise'

    def get_original_date(self, obj):
        dt = obj.original_followup_datetime or obj.followup_datetime
        return dt.strftime("%Y-%m-%d") if dt else None


    # -----------------------------
    # Validation
    # -----------------------------

    def validate_note(self, value):

        return value.strip()

    def validate(self, attrs):

        if attrs.get("followup_datetime") is None:
            raise serializers.ValidationError(
                {
                    "followup_datetime":
                        "Follow-up date & time is required."
                }
            )

        return attrs
from rest_framework import serializers

from .models import FollowUp


class FollowUpSerializer(serializers.ModelSerializer):

    lead = serializers.SerializerMethodField()

    phone = serializers.SerializerMethodField()

    city = serializers.SerializerMethodField()

    executive = serializers.SerializerMethodField()

    date = serializers.SerializerMethodField()

    time = serializers.SerializerMethodField()

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

            "date",
            "time",

            "followup_type",
            "type",

            "note",

            "status",

            "followup_datetime",
            "next_followup_date",

            "created_at",
            "updated_at",
        ]

        read_only_fields = [
            "id",
            "created_at",
            "updated_at",
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
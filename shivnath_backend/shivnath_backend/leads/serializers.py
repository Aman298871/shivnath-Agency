from rest_framework import serializers

from .models import (
    Lead,
    LeadActivity,
    MarketingSpend,
    WhatsAppMessageLog,
    LeadJourneyState,
    CRMActivityLog,
)
from chat.serializers import ChatSessionSerializer


class MarketingSpendSerializer(serializers.ModelSerializer):
    campaign_source_display = serializers.CharField(source='get_campaign_source_display', read_only=True)
    cpl = serializers.SerializerMethodField()

    class Meta:
        model = MarketingSpend
        fields = [
            'id',
            'campaign_name',
            'campaign_source',
            'campaign_source_display',
            'period_start',
            'period_end',
            'total_spend_inr',
            'notes',
            'cpl',
            'created_at',
        ]
        read_only_fields = ['id', 'created_at', 'cpl', 'campaign_source_display']

    def get_cpl(self, obj):
        lead_count = Lead.objects.filter(
            created_at__date__gte=obj.period_start,
            created_at__date__lte=obj.period_end,
        ).count()
        if lead_count > 0:
            return round(float(obj.total_spend_inr) / lead_count, 2)
        return float(obj.total_spend_inr)


class WhatsAppMessageLogSerializer(serializers.ModelSerializer):
    class Meta:
        model = WhatsAppMessageLog
        fields = '__all__'


class LeadJourneyStateSerializer(serializers.ModelSerializer):
    class Meta:
        model = LeadJourneyState
        fields = '__all__'


class CRMActivityLogSerializer(serializers.ModelSerializer):
    actor_name = serializers.CharField(source='actor.username', read_only=True)

    class Meta:
        model = CRMActivityLog
        fields = '__all__'


class LeadActivitySerializer(serializers.ModelSerializer):

    created_by_name = serializers.SerializerMethodField()
    activity_type_display = serializers.CharField(
        source='get_activity_type_display',
        read_only=True
    )

    class Meta:
        model = LeadActivity

        fields = [
            'id',
            'lead',
            'activity_type',
            'activity_type_display',
            'title',
            'description',
            'created_by',
            'created_by_name',
            'created_at',
        ]

        read_only_fields = [
            'id',
            'lead',
            'created_by',
            'created_by_name',
            'created_at',
            'activity_type_display',
        ]

    def get_created_by_name(self, obj):
        if not obj.created_by:
            return ''

        return (
            obj.created_by.get_full_name()
            or obj.created_by.username
        )


class LeadSerializer(serializers.ModelSerializer):

    score_display = serializers.CharField(
        source='get_score_display',
        read_only=True
    )

    status_display = serializers.CharField(
        source='get_status_display',
        read_only=True
    )

    lead_type_display = serializers.CharField(
        source='get_lead_type_display',
        read_only=True
    )

    existing_business_display = serializers.CharField(
        source='get_existing_business_display',
        read_only=True
    )

    commercial_space_display = serializers.CharField(
        source='get_commercial_space_display',
        read_only=True
    )

    created_by_name = serializers.SerializerMethodField()

    activities = LeadActivitySerializer(
        many=True,
        read_only=True
    )

    chat_sessions = ChatSessionSerializer(
        many=True,
        read_only=True
    )

    activity_logs = CRMActivityLogSerializer(
        many=True,
        read_only=True
    )

    class Meta:
        model = Lead

        fields = [
            'id',
            'lead_number',
            'lead_type',
            'lead_type_display',
            'name',
            'phone',
            'email',
            'city',
            'district',
            'territory',
            'locality',
            'assigned_franchise',

            'investment_budget',
            'existing_business',
            'existing_business_display',
            'commercial_space',
            'commercial_space_display',
            'previous_experience',
            'preferred_location',

            'score',
            'score_display',
            'score_category',
            'lead_score_number',

            'status',
            'status_display',

            'assigned_executive',
            'next_followup',

            'source',
            'notes',
            'interest_level',
            'site_visit_planned',
            'site_visit_completed',
            'site_visit_date',
            'site_visit_notes',

            'converted_user',

            'created_by',
            'created_by_name',

            'created_at',
            'updated_at',

            'activities',
            'activity_logs',
            'chat_sessions',
        ]

        read_only_fields = [
            'id',
            'lead_number',
            'created_by',
            'created_by_name',
            'created_at',
            'updated_at',
            'activities',
            'activity_logs',
            'chat_sessions',
            'converted_user',

            'score_display',
            'status_display',
            'existing_business_display',
            'commercial_space_display',
        ]

    def get_created_by_name(self, obj):
        if not obj.created_by:
            return ''

        return (
            obj.created_by.get_full_name()
            or obj.created_by.username
        )

    def validate_name(self, value):
        value = value.strip()

        if not value:
            raise serializers.ValidationError(
                'Full name is required.'
            )

        return value

    def validate_phone(self, value):
        value = value.strip()

        cleaned = (
            value
            .replace(' ', '')
            .replace('-', '')
        )

        if cleaned.startswith('+'):
            cleaned = cleaned[1:]

        if not cleaned.isdigit():
            raise serializers.ValidationError(
                'Enter a valid mobile number.'
            )

        if len(cleaned) < 10 or len(cleaned) > 15:
            raise serializers.ValidationError(
                'Mobile number must contain 10 to 15 digits.'
            )

        return value

    def validate_city(self, value):
        value = value.strip()

        if not value:
            raise serializers.ValidationError(
                'City is required.'
            )

        return value
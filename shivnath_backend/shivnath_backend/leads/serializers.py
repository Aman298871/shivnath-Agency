from rest_framework import serializers

from .models import (
    Lead,
    LeadActivity,
)


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

    class Meta:
        model = Lead

        fields = [
            'id',

            'name',
            'phone',
            'email',
            'city',
            'district',

            'investment_budget',
            'existing_business',
            'existing_business_display',
            'commercial_space',
            'commercial_space_display',
            'previous_experience',
            'preferred_location',

            'score',
            'score_display',

            'status',
            'status_display',

            'assigned_executive',
            'next_followup',

            'source',
            'notes',

            'created_by',
            'created_by_name',

            'created_at',
            'updated_at',

            'activities',
        ]

        read_only_fields = [
            'id',
            'created_by',
            'created_by_name',
            'created_at',
            'updated_at',
            'activities',

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
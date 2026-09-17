from django.contrib.auth import authenticate
from django.contrib.auth.models import User
from django.db import transaction

from rest_framework import serializers
from rest_framework_simplejwt.tokens import RefreshToken

from .models import (
    UserProfile,
    FranchiseProfile,
)


class CustomerRegisterSerializer(serializers.Serializer):

    name = serializers.CharField(
        max_length=150
    )

    phone = serializers.CharField(
        max_length=15
    )

    email = serializers.EmailField()

    password = serializers.CharField(
        write_only=True,
        min_length=6
    )

    confirm_password = serializers.CharField(
        write_only=True
    )

    city = serializers.CharField(
        max_length=100,
        required=False,
        allow_blank=True,
        default=''
    )

    district = serializers.CharField(
        max_length=100,
        required=False,
        allow_blank=True,
        default=''
    )

    address = serializers.CharField(
        required=False,
        allow_blank=True,
        default=''
    )

    def validate_email(self, value):

        value = value.strip().lower()

        if User.objects.filter(
            email__iexact=value
        ).exists():
            raise serializers.ValidationError(
                'An account with this email already exists.'
            )

        return value

    def validate(self, attrs):

        if attrs['password'] != attrs['confirm_password']:
            raise serializers.ValidationError({
                'confirm_password':
                    'Passwords do not match.'
            })

        return attrs

    @transaction.atomic
    def create(self, validated_data):

        validated_data.pop(
            'confirm_password'
        )

        name = validated_data.pop('name').strip()
        phone = validated_data.pop('phone').strip()
        email = validated_data.pop('email').lower()
        password = validated_data.pop('password')
        city = validated_data.pop('city', '').strip()
        district = validated_data.pop('district', '').strip()
        address = validated_data.pop('address', '').strip()

        user = User.objects.create_user(
            username=email,
            email=email,
            password=password,
            first_name=name,
            is_active=True,
        )

        profile, _ = UserProfile.objects.get_or_create(
            user=user
        )

        profile.name = name
        profile.phone = phone
        profile.city = city
        profile.district = district
        profile.address = address
        profile.role = 'customer'
        profile.status = 'active'
        profile.save()

        # Link any existing Lead to this registered account without duplicate lead creation
        try:
            from leads.models import Lead, LeadActivity
            import re
            norm_phone = re.sub(r'\D', '', phone)[-10:] if len(re.sub(r'\D', '', phone)) >= 10 else phone
            matching_leads = Lead.objects.filter(phone__icontains=norm_phone)
            for m_lead in matching_leads:
                if not m_lead.created_by:
                    m_lead.created_by = user
                    m_lead.save(update_fields=['created_by'])
                LeadActivity.objects.create(
                    lead=m_lead,
                    activity_type='note',
                    title='Customer Registered Account',
                    description=f'Lead linked to registered customer account {email} (User ID: {user.id}).',
                    created_by=user,
                )
        except Exception:
            pass

        # Create Admin Notification
        try:
            from .models import AdminNotification
            location_str = f" from {city}" if city else ""
            AdminNotification.objects.create(
                title='New Customer Registered',
                message=f'{name} ({phone}){location_str} has registered on the Pure Water platform.',
                notification_type='customer_registration',
                reference_id=user.id,
            )
        except Exception:
            pass

        return user


class FranchiseRegisterSerializer(serializers.Serializer):
    owner_name = serializers.CharField(max_length=150)

    business_name = serializers.CharField(max_length=200)

    phone = serializers.CharField(max_length=15)

    email = serializers.EmailField()

    password = serializers.CharField(
        write_only=True,
        min_length=6
    )

    confirm_password = serializers.CharField(
        write_only=True
    )

    city = serializers.CharField(max_length=100)

    address = serializers.CharField()

    territory = serializers.CharField(
        max_length=150,
        required=False,
        allow_blank=True
    )

    gst_number = serializers.CharField(
        max_length=30,
        required=False,
        allow_blank=True
    )

    pan_number = serializers.CharField(
        max_length=20,
        required=False,
        allow_blank=True
    )

    aadhaar_number = serializers.CharField(
        max_length=20,
        required=False,
        allow_blank=True
    )

    def validate_email(self, value):
        value = value.strip().lower()

        if User.objects.filter(
            email__iexact=value
        ).exists():
            raise serializers.ValidationError(
                'An account with this email already exists.'
            )

        return value

    def validate(self, attrs):
        if attrs['password'] != attrs['confirm_password']:
            raise serializers.ValidationError({
                'confirm_password':
                    'Passwords do not match.'
            })

        return attrs

    @transaction.atomic
    def create(self, validated_data):
        validated_data.pop('confirm_password')

        owner_name = validated_data.pop(
            'owner_name'
        ).strip()

        business_name = validated_data.pop(
            'business_name'
        ).strip()

        phone = validated_data.pop(
            'phone'
        ).strip()

        email = validated_data.pop(
            'email'
        ).strip().lower()

        password = validated_data.pop(
            'password'
        )

        city = validated_data.pop(
            'city'
        ).strip()

        address = validated_data.pop(
            'address'
        ).strip()

        territory = validated_data.pop(
            'territory',
            ''
        ).strip()

        gst_number = validated_data.pop(
            'gst_number',
            ''
        ).strip()

        pan_number = validated_data.pop(
            'pan_number',
            ''
        ).strip()

        aadhaar_number = validated_data.pop(
            'aadhaar_number',
            ''
        ).strip()

        user = User.objects.create_user(
            username=email,
            email=email,
            password=password,
            first_name=owner_name,
            is_active=True,
        )

        profile, _ = UserProfile.objects.get_or_create(
            user=user
        )

        profile.name = owner_name
        profile.phone = phone
        profile.city = city
        profile.address = address
        profile.role = 'franchise'
        profile.status = 'pending'
        profile.save()

        FranchiseProfile.objects.create(
            user=user,
            business_name=business_name,
            city=city,
            address=address,
            territory=territory,
            gst_number=gst_number,
            pan_number=pan_number,
            aadhaar_number=aadhaar_number,

            # Admin fills these later.
            security_deposit=0,
            commission=0,
            agreement_status='pending',

            status='pending',
        )

        # Create Admin Notification
        try:
            from .models import AdminNotification
            AdminNotification.objects.create(
                title='New Franchise Application',
                message=f'{owner_name} has applied for a new franchise partner account for "{business_name}" in {city}.',
                notification_type='franchise_registration',
                reference_id=user.id,
            )
        except Exception:
            pass

        return user

        return user

class LoginSerializer(serializers.Serializer):

    email = serializers.EmailField()

    password = serializers.CharField(
        write_only=True
    )

    role = serializers.ChoiceField(
        choices=UserProfile.ROLE_CHOICES
    )

    def validate(self, attrs):

        email = attrs['email'].strip().lower()
        password = attrs['password']
        selected_role = attrs['role']

        try:
            user_object = User.objects.get(
                email__iexact=email
            )

        except User.DoesNotExist:
            raise serializers.ValidationError({
                'email':
                    'No account found with this email.'
            })

        user = authenticate(
            username=user_object.username,
            password=password
        )

        if user is None:
            raise serializers.ValidationError({
                'password':
                    'Incorrect password.'
            })

        if not user.is_active:
            raise serializers.ValidationError({
                'detail':
                    'Your account is inactive.'
            })

        profile, _ = UserProfile.objects.get_or_create(
            user=user
        )

        if user.is_superuser:
            profile.role = 'admin'
            profile.save()

        if profile.role != selected_role:
            raise serializers.ValidationError({
                'role':
                    f'This account is registered as '
                    f'{profile.get_role_display()}.'
            })

        franchise_status = 'approved'
        rejection_reason = ''
        business_name = ''
        city = ''
        territory = ''

        if profile.role == 'franchise':
            try:
                franchise = user.franchise_profile
                franchise_status = franchise.status
                rejection_reason = franchise.rejection_reason
                business_name = franchise.business_name
                city = franchise.city
                territory = franchise.territory
            except FranchiseProfile.DoesNotExist:
                franchise_status = 'pending'

        refresh = RefreshToken.for_user(user)

        return {
            'access': str(
                refresh.access_token
            ),
            'refresh': str(refresh),

            'user': {
                'id': user.id,
                'name':
                    user.get_full_name()
                    or user.username,
                'email': user.email,
                'phone': profile.phone,
                'role': profile.role,
                'status': franchise_status,
                'rejection_reason': rejection_reason,
                'business_name': business_name,
                'city': city,
                'territory': territory,
            }
        }


class CurrentUserSerializer(
    serializers.ModelSerializer
):

    name = serializers.SerializerMethodField()

    phone = serializers.CharField(
        source='profile.phone',
        read_only=True
    )

    role = serializers.CharField(
        source='profile.role',
        read_only=True
    )

    status = serializers.SerializerMethodField()
    rejection_reason = serializers.SerializerMethodField()
    business_name = serializers.SerializerMethodField()
    city = serializers.SerializerMethodField()
    territory = serializers.SerializerMethodField()
    approved_at = serializers.SerializerMethodField()

    class Meta:
        model = User

        fields = [
            'id',
            'name',
            'email',
            'phone',
            'role',
            'status',
            'rejection_reason',
            'business_name',
            'city',
            'territory',
            'approved_at',
        ]

    def get_name(self, obj):
        return (
            obj.get_full_name()
            or obj.username
        )

    def get_status(self, obj):
        if hasattr(obj, 'franchise_profile'):
            return obj.franchise_profile.status
        return 'approved'

    def get_rejection_reason(self, obj):
        if hasattr(obj, 'franchise_profile'):
            return obj.franchise_profile.rejection_reason
        return ''

    def get_business_name(self, obj):
        if hasattr(obj, 'franchise_profile'):
            return obj.franchise_profile.business_name
        return ''

    def get_city(self, obj):
        if hasattr(obj, 'franchise_profile'):
            return obj.franchise_profile.city
        return ''

    def get_territory(self, obj):
        if hasattr(obj, 'franchise_profile'):
            return obj.franchise_profile.territory
        return ''

    def get_approved_at(self, obj):
        if hasattr(obj, 'franchise_profile') and obj.franchise_profile.approved_at:
            return obj.franchise_profile.approved_at.isoformat()
        return None
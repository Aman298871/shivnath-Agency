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
        required=True
    )

    pincode = serializers.CharField(
        max_length=10,
        required=False,
        allow_blank=True,
        default=''
    )

    locality = serializers.CharField(
        max_length=150,
        required=False,
        allow_blank=True,
        default=''
    )

    address = serializers.CharField(
        required=False,
        allow_blank=True,
        default=''
    )

    zone_id = serializers.IntegerField(
        required=True
    )

    franchise_id = serializers.IntegerField(
        required=False,
        allow_null=True
    )

    referral_code = serializers.CharField(
        required=False,
        allow_blank=True,
        default=''
    )

    def validate_phone(self, value):
        import re
        cleaned = re.sub(r'[\s\-\+]', '', value)
        if cleaned.startswith('91') and len(cleaned) == 12:
            cleaned = cleaned[2:]
        if not re.fullmatch(r'[6-9][0-9]{9}', cleaned):
            raise serializers.ValidationError(
                'Please enter a valid 10-digit Indian mobile number starting with 6, 7, 8 or 9.'
            )
        return cleaned

    def validate_email(self, value):
        value = value.strip().lower()
        if User.objects.filter(email__iexact=value).exists():
            raise serializers.ValidationError(
                'An account with this email already exists.'
            )
        return value

    def validate(self, attrs):
        if attrs['password'] != attrs['confirm_password']:
            raise serializers.ValidationError({
                'confirm_password': 'Passwords do not match.'
            })

        district_str = attrs.get('district', '').strip()
        if not district_str:
            raise serializers.ValidationError({'district': 'District is required.'})

        submitted_zone_id = attrs.get('zone_id')
        from .models import ServiceDistrict, ServiceZone, FranchiseProfile, FranchiseTerritoryAssignment

        # Validate zone_id against master territories for the district
        try:
            resolved_zone = ServiceZone.objects.select_related('district').get(
                id=submitted_zone_id,
                district__name__iexact=district_str,
                is_active=True
            )
        except ServiceZone.DoesNotExist:
            raise serializers.ValidationError({
                'zone_id': f'Invalid territory selected for district "{district_str}". Please select an active territory from the list.'
            })

        # Validate franchise_id if customer selected one
        franchise_id = attrs.get('franchise_id')
        chosen_franchise = None
        is_fallback_franchise = False

        if franchise_id:
            try:
                chosen_franchise = FranchiseProfile.objects.get(id=franchise_id, status='approved')
                is_assigned = FranchiseTerritoryAssignment.objects.filter(
                    zone=resolved_zone,
                    franchise=chosen_franchise,
                    is_active=True
                ).exists()
                is_fallback_franchise = not is_assigned
            except FranchiseProfile.DoesNotExist:
                raise serializers.ValidationError({'franchise_id': 'Selected franchise does not exist or is not active.'})

        attrs['_resolved_zone'] = resolved_zone
        attrs['_matched_district'] = resolved_zone.district
        attrs['_chosen_franchise'] = chosen_franchise
        attrs['_is_fallback_franchise'] = is_fallback_franchise
        return attrs

    @transaction.atomic
    def create(self, validated_data):
        from .models import (
            FranchiseProfile,
            FranchiseTerritoryAssignment,
            CustomerFranchiseRelationship,
            FranchiseNotification,
            AdminNotification,
        )

        validated_data.pop('confirm_password')
        resolved_zone = validated_data.pop('_resolved_zone')
        matched_district = validated_data.pop('_matched_district', None)
        chosen_franchise = validated_data.pop('_chosen_franchise', None)
        is_fallback = validated_data.pop('_is_fallback_franchise', False)
        zone_id = validated_data.pop('zone_id', None)
        franchise_id = validated_data.pop('franchise_id', None)
        referral_code = validated_data.pop('referral_code', '').strip()

        name = validated_data.pop('name').strip()
        phone = validated_data.pop('phone').strip()
        email = validated_data.pop('email').lower()
        password = validated_data.pop('password')
        city = validated_data.pop('city', '').strip() or (matched_district.name if matched_district else 'Raipur')
        district = validated_data.pop('district', '').strip() or (matched_district.name if matched_district else 'Raipur')
        pincode = validated_data.pop('pincode', '').strip()
        locality = validated_data.pop('locality', '').strip()
        address = validated_data.pop('address', '').strip()

        # =====================================================================
        # FRANCHISE ASSIGNMENT HIERARCHY
        # 1. Customer selected franchise
        # 2. Referral code franchise
        # 3. Admin-designated primary franchise for Zone
        # 4. Any approved franchise assigned to Zone
        # 5. Headquarters fallback
        # 6. Any active approved franchise
        # =====================================================================
        assigned_franchise = chosen_franchise

        if not assigned_franchise and referral_code:
            assigned_franchise = FranchiseProfile.objects.filter(
                Q(user__username__iexact=referral_code)
                | Q(user__profile__phone=referral_code)
                | Q(business_name__icontains=referral_code),
                status='approved'
            ).first()

        if not assigned_franchise:
            primary_assignment = FranchiseTerritoryAssignment.objects.filter(
                zone=resolved_zone,
                is_primary=True,
                is_active=True,
                franchise__status='approved'
            ).select_related('franchise').first()
            if primary_assignment:
                assigned_franchise = primary_assignment.franchise

        if not assigned_franchise:
            zone_assignment = FranchiseTerritoryAssignment.objects.filter(
                zone=resolved_zone,
                is_active=True,
                franchise__status='approved'
            ).select_related('franchise').first()
            if zone_assignment:
                assigned_franchise = zone_assignment.franchise

        if not assigned_franchise:
            assigned_franchise = FranchiseProfile.objects.filter(
                is_headquarters=True,
                status='approved'
            ).first()

        if not assigned_franchise:
            assigned_franchise = FranchiseProfile.objects.filter(
                status='approved'
            ).first()

        if not assigned_franchise:
            raise serializers.ValidationError({
                'territory': 'Service unavailable: No active franchise is currently configured in the system. Please contact administration.'
            })

        user = User.objects.create_user(
            username=email,
            email=email,
            password=password,
            first_name=name,
            is_active=True,
        )

        profile, _ = UserProfile.objects.get_or_create(user=user)
        profile.name = name
        profile.phone = phone
        profile.city = city
        profile.district = district
        profile.pincode = pincode
        profile.locality = locality
        profile.zone = resolved_zone
        profile.address = address
        profile.role = 'customer'
        profile.status = 'active'
        profile.save()

        matched_district = resolved_zone.district if resolved_zone else None

        # Create authoritative CustomerFranchiseRelationship
        rel = CustomerFranchiseRelationship.objects.create(
            customer=user,
            registered_franchise=assigned_franchise,
            current_serving_franchise=assigned_franchise,
            district=matched_district,
            zone=resolved_zone,
            service_area=None,
            pincode=pincode,
            locality=locality,
            service_status='active',
        )

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
                    description=f'Lead linked to registered customer account {email} (User ID: {user.id}). Registered Franchise: {assigned_franchise.business_name}.',
                    created_by=user,
                )
        except Exception:
            pass

        # Dual Notifications on Customer Registration
        try:
            from accounts.services import send_customer_registration_notifications
            send_customer_registration_notifications(user, rel)
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

    def validate_phone(self, value):
        import re
        cleaned = re.sub(r'[\s\-\+]', '', value)
        if cleaned.startswith('91') and len(cleaned) == 12:
            cleaned = cleaned[2:]
        if not re.fullmatch(r'[6-9][0-9]{9}', cleaned):
            raise serializers.ValidationError(
                'Please enter a valid 10-digit Indian mobile number starting with 6, 7, 8 or 9.'
            )
        from .models import UserProfile
        if UserProfile.objects.filter(phone=cleaned).exists():
            raise serializers.ValidationError(
                'This franchise account is already registered. Please login instead.'
            )
        return cleaned

    def validate_email(self, value):
        value = value.strip().lower()

        if User.objects.filter(
            email__iexact=value
        ).exists():
            raise serializers.ValidationError(
                'This franchise account is already registered. Please login instead.'
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

    city = serializers.SerializerMethodField()
    territory = serializers.SerializerMethodField()
    approved_at = serializers.SerializerMethodField()
    address = serializers.SerializerMethodField()

    district = serializers.SerializerMethodField()
    pincode = serializers.SerializerMethodField()
    locality = serializers.SerializerMethodField()
    zone_id = serializers.SerializerMethodField()
    zone_name = serializers.SerializerMethodField()
    registered_franchise = serializers.SerializerMethodField()
    current_serving_franchise = serializers.SerializerMethodField()
    service_status = serializers.SerializerMethodField()
    active_stock_cycle = serializers.SerializerMethodField()
    territory_info = serializers.SerializerMethodField()

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
            'address',
            'territory',
            'territory_info',
            'approved_at',
            'district',
            'pincode',
            'locality',
            'zone_id',
            'zone_name',
            'registered_franchise',
            'current_serving_franchise',
            'service_status',
            'active_stock_cycle',
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
        prof = getattr(obj, 'profile', None)
        return prof.city if prof else ''

    def get_address(self, obj):
        if hasattr(obj, 'franchise_profile'):
            return obj.franchise_profile.address
        prof = getattr(obj, 'profile', None)
        return prof.address if prof else ''

    def get_territory(self, obj):
        if hasattr(obj, 'franchise_profile'):
            fp = obj.franchise_profile
            from .models import FranchiseTerritoryAssignment
            assign = FranchiseTerritoryAssignment.objects.filter(franchise=fp, is_active=True).select_related('zone', 'zone__district').first()
            if assign:
                return {
                    'district': assign.zone.district.name,
                    'zone_id': assign.zone.id,
                    'zone_name': assign.zone.name,
                    'locality': fp.address,
                    'territory': assign.zone.name,
                }
            return {
                'district': fp.city,
                'zone_id': None,
                'zone_name': fp.territory,
                'locality': fp.address,
                'territory': fp.territory,
            }
        rel = getattr(obj, 'customer_relationship', None)
        prof = getattr(obj, 'profile', None)
        return {
            'district': rel.district.name if rel and rel.district else (prof.district if prof else ''),
            'zone_id': rel.zone.id if rel and rel.zone else None,
            'zone_name': rel.zone.name if rel and rel.zone else '',
            'locality': rel.locality if rel else (prof.locality if prof else ''),
            'pincode': rel.pincode if rel else (prof.pincode if prof else ''),
        }

    def get_territory_info(self, obj):
        if hasattr(obj, 'franchise_profile'):
            fp = obj.franchise_profile
            from .models import FranchiseTerritoryAssignment
            assign = FranchiseTerritoryAssignment.objects.filter(franchise=fp, is_active=True).select_related('zone', 'zone__district').first()
            if assign:
                areas = list(assign.zone.areas.filter(is_active=True).values_list('locality_name', flat=True)[:5])
                return {
                    'district': assign.zone.district.name,
                    'territory': assign.zone.name,
                    'zone_id': assign.zone.id,
                    'service_area': ", ".join(areas) if areas else (fp.city or ""),
                    'address': fp.address or "",
                    'is_assigned': True,
                }
            return {
                'district': fp.city or "",
                'territory': fp.territory or "",
                'zone_id': None,
                'service_area': fp.city or "",
                'address': fp.address or "",
                'is_assigned': bool(fp.city or fp.territory),
            }

        rel = getattr(obj, 'customer_relationship', None)
        prof = getattr(obj, 'profile', None)
        dist = rel.district.name if rel and rel.district else (prof.district if prof else '')
        zone_name = rel.zone.name if rel and rel.zone else (prof.territory if prof else '')
        zone_id = rel.zone.id if rel and rel.zone else (prof.zone.id if prof and prof.zone else None)
        locality = rel.locality if rel and rel.locality else (prof.locality if prof else '')
        address = prof.address if prof else ''
        return {
            'district': dist,
            'territory': zone_name,
            'zone_id': zone_id,
            'service_area': locality,
            'address': address,
            'is_assigned': bool(dist or zone_id or zone_name),
        }

    def get_approved_at(self, obj):
        if hasattr(obj, 'franchise_profile') and obj.franchise_profile.approved_at:
            return obj.franchise_profile.approved_at.isoformat()
        return None

    def get_district(self, obj):
        if hasattr(obj, 'franchise_profile'):
            fp = obj.franchise_profile
            from .models import FranchiseTerritoryAssignment
            assign = FranchiseTerritoryAssignment.objects.filter(franchise=fp, is_active=True).select_related('zone', 'zone__district').first()
            if assign:
                return assign.zone.district.name
            return fp.city
        rel = getattr(obj, 'customer_relationship', None)
        if rel and rel.district:
            return rel.district.name
        prof = getattr(obj, 'profile', None)
        return prof.district if prof else ''

    def get_pincode(self, obj):
        rel = getattr(obj, 'customer_relationship', None)
        if rel and rel.pincode:
            return rel.pincode
        prof = getattr(obj, 'profile', None)
        return prof.pincode if prof else ''

    def get_locality(self, obj):
        if hasattr(obj, 'franchise_profile'):
            return obj.franchise_profile.address
        rel = getattr(obj, 'customer_relationship', None)
        if rel and rel.locality:
            return rel.locality
        prof = getattr(obj, 'profile', None)
        return prof.locality if prof else ''

    def get_zone_id(self, obj):
        if hasattr(obj, 'franchise_profile'):
            fp = obj.franchise_profile
            from .models import FranchiseTerritoryAssignment
            assign = FranchiseTerritoryAssignment.objects.filter(franchise=fp, is_active=True).first()
            return assign.zone_id if assign else None
        rel = getattr(obj, 'customer_relationship', None)
        if rel and rel.zone:
            return rel.zone.id
        prof = getattr(obj, 'profile', None)
        return prof.zone.id if prof and prof.zone else None

    def get_zone_name(self, obj):
        if hasattr(obj, 'franchise_profile'):
            fp = obj.franchise_profile
            from .models import FranchiseTerritoryAssignment
            assign = FranchiseTerritoryAssignment.objects.filter(franchise=fp, is_active=True).select_related('zone').first()
            if assign:
                return assign.zone.name
            return fp.territory
        rel = getattr(obj, 'customer_relationship', None)
        if rel and rel.zone:
            return rel.zone.name
        prof = getattr(obj, 'profile', None)
        return prof.zone.name if prof and prof.zone else ''

    def get_registered_franchise(self, obj):
        rel = getattr(obj, 'customer_relationship', None)
        if rel and rel.registered_franchise:
            rf = rel.registered_franchise
            return {
                'id': rf.id,
                'business_name': rf.business_name,
                'city': rf.city,
                'phone': rf.user.profile.phone if hasattr(rf.user, 'profile') else '',
            }
        return None

    def get_current_serving_franchise(self, obj):
        rel = getattr(obj, 'customer_relationship', None)
        if rel and rel.current_serving_franchise:
            sf = rel.current_serving_franchise
            return {
                'id': sf.id,
                'business_name': sf.business_name,
                'city': sf.city,
                'phone': sf.user.profile.phone if hasattr(sf.user, 'profile') else '',
            }
        return None

    def get_service_status(self, obj):
        rel = getattr(obj, 'customer_relationship', None)
        return rel.service_status if rel else 'active'

    def get_active_stock_cycle(self, obj):
        from datetime import date
        from .models import CustomerStockCycle
        cycle = CustomerStockCycle.objects.filter(customer=obj, service_status__in=['active', 'hold']).first()
        if not cycle:
            return None

        today = date.today()
        if cycle.service_status == 'hold':
            remaining = cycle.remaining_days_at_hold if cycle.remaining_days_at_hold is not None else max((cycle.expected_end_date - today).days, 0)
        else:
            remaining = max((cycle.expected_end_date - today).days, 0)

        return {
            'id': cycle.id,
            'duration_choice': cycle.duration_choice,
            'duration_days': cycle.duration_days,
            'start_date': cycle.start_date.isoformat(),
            'expected_end_date': cycle.expected_end_date.isoformat(),
            'service_status': cycle.service_status,
            'remaining_days': remaining,
            'is_low_stock': (remaining <= 7 and cycle.service_status == 'active'),
            'serving_franchise_id': cycle.serving_franchise.id if cycle.serving_franchise else None,
            'serving_franchise_name': cycle.serving_franchise.business_name if cycle.serving_franchise else 'Shivnath Agency (Direct)',
        }


# =====================================================================
# TERRITORY & LIFECYCLE SERIALIZERS
# =====================================================================

from .models import (
    ServiceDistrict,
    ServiceZone,
    ServiceArea,
    CustomerBulkOrder,
    CustomerStockCycle,
    ServiceHoldHistory,
    FranchiseNotification,
)

class ServiceAreaSerializer(serializers.ModelSerializer):
    zone_name = serializers.CharField(source='zone.name', read_only=True)
    district_name = serializers.CharField(source='district.name', read_only=True)

    class Meta:
        model = ServiceArea
        fields = ['id', 'district', 'district_name', 'zone', 'zone_name', 'pincode', 'locality_name', 'is_active']


class ServiceZoneSerializer(serializers.ModelSerializer):
    district_name = serializers.CharField(source='district.name', read_only=True)
    areas = ServiceAreaSerializer(many=True, read_only=True)

    class Meta:
        model = ServiceZone
        fields = ['id', 'district', 'district_name', 'name', 'code', 'is_active', 'areas']


class ServiceDistrictSerializer(serializers.ModelSerializer):
    zones = ServiceZoneSerializer(many=True, read_only=True)

    class Meta:
        model = ServiceDistrict
        fields = ['id', 'name', 'state', 'is_active', 'zones']


class CustomerBulkOrderSerializer(serializers.ModelSerializer):
    customer_name = serializers.CharField(source='customer.get_full_name', read_only=True)
    customer_phone = serializers.CharField(source='customer.profile.phone', read_only=True)
    customer_email = serializers.CharField(source='customer.email', read_only=True)
    serving_franchise_name = serializers.CharField(source='serving_franchise.business_name', read_only=True)

    class Meta:
        model = CustomerBulkOrder
        fields = [
            'id',
            'customer',
            'customer_name',
            'customer_phone',
            'customer_email',
            'product',
            'product_name',
            'variant_size',
            'quantity',
            'duration_choice',
            'required_date',
            'delivery_address',
            'district',
            'zone_name',
            'serving_franchise',
            'serving_franchise_name',
            'status',
            'additional_notes',
            'created_at',
            'updated_at',
        ]
        read_only_fields = ['id', 'customer', 'created_at', 'updated_at']


class CustomerStockCycleSerializer(serializers.ModelSerializer):
    customer_name = serializers.CharField(source='customer.get_full_name', read_only=True)
    customer_phone = serializers.CharField(source='customer.profile.phone', read_only=True)
    serving_franchise_name = serializers.CharField(source='serving_franchise.business_name', read_only=True)
    remaining_days = serializers.SerializerMethodField()
    is_low_stock = serializers.SerializerMethodField()

    class Meta:
        model = CustomerStockCycle
        fields = [
            'id',
            'customer',
            'customer_name',
            'customer_phone',
            'order',
            'serving_franchise',
            'serving_franchise_name',
            'start_date',
            'duration_choice',
            'duration_days',
            'expected_end_date',
            'service_status',
            'remaining_days',
            'is_low_stock',
            'hold_reason',
            'hold_timestamp',
            'created_at',
            'updated_at',
        ]

    def get_remaining_days(self, obj):
        from datetime import date
        today = date.today()
        if obj.service_status == 'hold':
            return obj.remaining_days_at_hold if obj.remaining_days_at_hold is not None else max((obj.expected_end_date - today).days, 0)
        return max((obj.expected_end_date - today).days, 0)

    def get_is_low_stock(self, obj):
        rem = self.get_remaining_days(obj)
        return (rem <= 7 and obj.service_status == 'active')


class ServiceHoldHistorySerializer(serializers.ModelSerializer):
    actor_name = serializers.CharField(source='actor.get_full_name', read_only=True)

    class Meta:
        model = ServiceHoldHistory
        fields = [
            'id',
            'stock_cycle',
            'customer',
            'action',
            'actor',
            'actor_name',
            'actor_role',
            'remaining_days',
            'notes',
            'created_at',
        ]


class FranchiseNotificationSerializer(serializers.ModelSerializer):
    class Meta:
        model = FranchiseNotification
        fields = [
            'id',
            'franchise',
            'title',
            'message',
            'notification_type',
            'reference_id',
            'is_read',
            'created_at',
        ]
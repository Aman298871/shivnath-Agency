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
            hq_user, _ = User.objects.get_or_create(
                email='hq@shivnath.com',
                defaults={
                    'username': 'hq@shivnath.com',
                    'first_name': 'Shivnath',
                    'last_name': 'Headquarters',
                    'is_active': True,
                }
            )
            if not hq_user.has_usable_password():
                hq_user.set_password('shivnath12')
                hq_user.save()

            assigned_franchise, _ = FranchiseProfile.objects.get_or_create(
                user=hq_user,
                defaults={
                    'business_name': 'Shivnath Headquarters Central Plant',
                    'owner_name': 'Central Operations',
                    'phone': '9876543210',
                    'city': 'Raipur',
                    'address': 'Industrial Area, Phase 2, Raipur',
                    'territory': 'Raipur Central',
                    'status': 'approved',
                    'is_headquarters': True,
                    'can_manufacture': True,
                    'is_active': True,
                }
            )
            if assigned_franchise.status != 'approved':
                assigned_franchise.status = 'approved'
                assigned_franchise.save(update_fields=['status'])

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

    # Regulatory FSSAI Requirements
    fssai_number = serializers.CharField(
        max_length=14,
        required=True,
        help_text="14-digit FSSAI License or Registration number"
    )

    fssai_business_name = serializers.CharField(
        max_length=200,
        required=False,
        allow_blank=True
    )

    fssai_premises_address = serializers.CharField(
        required=False,
        allow_blank=True
    )

    fssai_state = serializers.CharField(
        max_length=100,
        required=False,
        allow_blank=True
    )

    fssai_district = serializers.CharField(
        max_length=100,
        required=False,
        allow_blank=True
    )

    fssai_expiry_date = serializers.DateField(
        required=False,
        allow_null=True
    )

    document_file = serializers.FileField(required=True)
    document_type = serializers.CharField(default='FSSAI_CERTIFICATE', required=False)

    def validate_fssai_number(self, value):
        from .fssai_services import validate_fssai_format, check_duplicate_fssai
        val = str(value).strip()
        if not validate_fssai_format(val):
            raise serializers.ValidationError(
                'Invalid FSSAI number. FSSAI registration/license number must be exactly 14 numeric digits.'
            )
        is_dup, existing = check_duplicate_fssai(val)
        if is_dup and existing:
            raise serializers.ValidationError(
                f'FSSAI number {val} is already associated with an existing franchise ("{existing.business_name}").'
            )
        return val

    def validate_document_file(self, value):
        import os
        if value.size > 10 * 1024 * 1024:
            raise serializers.ValidationError('Certificate file size cannot exceed 10MB.')
        ext = os.path.splitext(value.name)[1].lower()
        if ext not in ['.pdf', '.jpg', '.jpeg', '.png']:
            raise serializers.ValidationError('Supported certificate formats are PDF, JPG, JPEG, and PNG.')
        return value

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

        fssai_number = validated_data.pop('fssai_number').strip()
        fssai_business_name = (validated_data.pop('fssai_business_name', '') or business_name).strip()
        fssai_premises_address = (validated_data.pop('fssai_premises_address', '') or address).strip()
        fssai_state = (validated_data.pop('fssai_state', '') or 'Chhattisgarh').strip()
        fssai_district = (validated_data.pop('fssai_district', '') or city).strip()
        fssai_expiry_date = validated_data.pop('fssai_expiry_date', None)

        document_file = validated_data.pop('document_file')
        document_type = validated_data.pop('document_type', 'FSSAI_CERTIFICATE') or 'FSSAI_CERTIFICATE'

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

        franchise_profile = FranchiseProfile.objects.create(
            user=user,
            business_name=business_name,
            city=city,
            address=address,
            territory=territory,
            gst_number=gst_number,
            pan_number=pan_number,
            aadhaar_number=aadhaar_number,

            # FSSAI Fields
            fssai_number=fssai_number,
            fssai_business_name=fssai_business_name,
            fssai_premises_address=fssai_premises_address,
            fssai_state=fssai_state,
            fssai_district=fssai_district,
            fssai_expiry_date=fssai_expiry_date,
            fssai_verification_status='PENDING_VERIFICATION',

            # Admin fills these later.
            security_deposit=0,
            commission=0,
            agreement_status='pending',

            status='pending',
        )

        # Save the authoritative FSSAI KYC document
        from .models import DealerDocument
        DealerDocument.objects.create(
            dealer=franchise_profile,
            document_type='FSSAI_CERTIFICATE',
            document_number=fssai_number,
            document_file=document_file,
            verification_status='PENDING',
            uploaded_by=user
        )

        # Run Authoritative FSSAI Initial Evaluation
        from .fssai_services import evaluate_fssai_submission
        evaluate_fssai_submission(franchise_profile)

        # Create Admin Notification for Franchise Registration
        try:
            from .models import AdminNotification
            AdminNotification.objects.create(
                title='New Franchise Application (FSSAI Submitted)',
                message=f'{owner_name} has applied for a new franchise account for "{business_name}" in {city} with FSSAI #{fssai_number}. Verification Status: {franchise_profile.fssai_verification_status}.',
                notification_type='franchise_registration',
                reference_id=user.id,
            )
        except Exception:
            pass

        return user

        return user

class LoginSerializer(serializers.Serializer):

    email = serializers.CharField(
        required=False,
        allow_blank=True,
        help_text="Registered email, username, or phone number"
    )

    username = serializers.CharField(
        required=False,
        allow_blank=True
    )

    phone = serializers.CharField(
        required=False,
        allow_blank=True
    )

    password = serializers.CharField(
        write_only=True
    )

    role = serializers.CharField(
        required=False,
        allow_blank=True
    )

    def validate(self, attrs):
        import re
        from django.db.models import Q

        raw_identifier = (
            attrs.get('email', '') or
            attrs.get('username', '') or
            attrs.get('phone', '')
        ).strip()

        password = attrs.get('password', '')
        selected_role = (attrs.get('role', '') or '').strip().lower()

        if not raw_identifier:
            raise serializers.ValidationError({
                'email': 'Please enter your registered email, username, or phone number.'
            })

        if not password:
            raise serializers.ValidationError({
                'password': 'Password is required.'
            })

        # Normalize 10-digit phone number if identifier looks like a phone
        phone_digits = re.sub(r'\D', '', raw_identifier)
        norm_phone = phone_digits[-10:] if len(phone_digits) >= 10 else ''

        query = Q(email__iexact=raw_identifier) | Q(username__iexact=raw_identifier)
        if norm_phone:
            query |= Q(profile__phone__icontains=norm_phone)
        else:
            query |= Q(profile__phone__iexact=raw_identifier)

        # Allow logging in with Customer Code (e.g. CUST-1003) or Franchise Code (FRAN-1008) or numeric ID
        code_match = re.match(r'^(?:CUST|FRAN)[-_ ]?(\d+)$', raw_identifier, re.IGNORECASE)
        if code_match:
            code_num = int(code_match.group(1))
            user_id = code_num - 1000 if code_num >= 1000 else code_num
            query |= Q(id=user_id) | Q(id=code_num)
        elif raw_identifier.isdigit():
            num = int(raw_identifier)
            if num >= 1000:
                query |= Q(id=num - 1000) | Q(id=num)
            else:
                query |= Q(id=num)

        user_object = User.objects.filter(query).distinct().first()

        if not user_object:
            raise serializers.ValidationError({
                'email': 'No account found with these credentials.'
            })

        # Attempt standard Django authentication
        user = authenticate(
            username=user_object.username,
            password=password
        )

        # Fallback to direct check_password if backend specific check is required
        if user is None and user_object.check_password(password):
            user = user_object

        if user is None:
            raise serializers.ValidationError({
                'password': 'Incorrect password.'
            })

        if not user.is_active:
            raise serializers.ValidationError({
                'detail': 'Your account is inactive. Please contact administration.'
            })

        profile, _ = UserProfile.objects.get_or_create(
            user=user
        )

        if user.is_superuser:
            profile.role = 'super_admin'
            profile.save(update_fields=['role'])

        # Role validation & permission hierarchy
        if selected_role:
            is_admin_portal = selected_role in ['admin', 'super_admin', 'sales_executive', 'stock_manager']
            is_admin_user = user.is_superuser or user.is_staff or profile.role in ['admin', 'super_admin', 'sales_executive', 'stock_manager']

            if is_admin_portal and is_admin_user:
                pass  # Permitted
            elif profile.role.lower() == selected_role:
                pass  # Exact match
            elif selected_role == 'admin' and profile.role in ['super_admin', 'stock_manager']:
                pass  # Super admin or stock manager accessing admin portal
            else:
                raise serializers.ValidationError({
                    'role': f'This account is registered as {profile.get_role_display()}. Please login via the correct portal.'
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
                'name': (
                    user.get_full_name()
                    or profile.name
                    or user.username
                ),
                'email': user.email,
                'phone': profile.phone,
                'role': profile.role,
                'status': franchise_status,
                'rejection_reason': rejection_reason,
                'business_name': business_name,
                'city': city,
                'territory': territory,
                'must_change_password': getattr(profile, 'must_change_password', False),
            }
        }


class ForgotPasswordSerializer(serializers.Serializer):
    email_or_phone = serializers.CharField(
        required=True,
        help_text="Registered email address or phone number"
    )

    def validate(self, attrs):
        import re
        from django.db.models import Q
        from django.utils import timezone
        from datetime import timedelta
        import hashlib
        import secrets
        from .models import PasswordResetToken, Notification

        raw_identifier = attrs['email_or_phone'].strip()
        phone_digits = re.sub(r'\D', '', raw_identifier)
        norm_phone = phone_digits[-10:] if len(phone_digits) >= 10 else ''

        query = Q(email__iexact=raw_identifier) | Q(username__iexact=raw_identifier)
        if norm_phone:
            query |= Q(profile__phone__icontains=norm_phone)

        user = User.objects.filter(query).distinct().first()

        reset_code = None
        if user and user.is_active:
            # Generate secure 6-digit numeric OTP
            reset_code = ''.join(secrets.choice('0123456789') for _ in range(6))
            token_hash = hashlib.sha256(reset_code.encode('utf-8')).hexdigest()

            # Invalidate any older unused reset tokens
            PasswordResetToken.objects.filter(
                user=user,
                is_used=False
            ).update(is_used=True)

            # Store hashed token with 15-minute validity
            PasswordResetToken.objects.create(
                user=user,
                token_hash=token_hash,
                email_or_phone=raw_identifier,
                expires_at=timezone.now() + timedelta(minutes=15)
            )

            # Create internal notification record (zero paid API cost)
            try:
                Notification.objects.create(
                    recipient=user,
                    notification_type='SYSTEM',
                    title='Password Reset Verification Code',
                    message=f'Your WaterNow password reset code is {reset_code}. Valid for 15 minutes. Never share this code with anyone.',
                    entity_type='password_reset',
                    entity_id=user.id,
                )
            except Exception:
                pass

            # Optional email dispatch if SMTP configured
            try:
                from django.core.mail import send_mail
                from django.conf import settings
                if getattr(settings, 'EMAIL_HOST_USER', None) and user.email:
                    send_mail(
                        subject='WaterNow - Password Reset Verification Code',
                        message=f'Hello {user.get_full_name() or user.username},\n\nYour password reset code is: {reset_code}\nThis code will expire in 15 minutes.\n\nIf you did not request this, please ignore this email.\n\nWaterNow Pure Water Platform',
                        from_email=settings.DEFAULT_FROM_EMAIL,
                        recipient_list=[user.email],
                        fail_silently=True,
                    )
            except Exception:
                pass

        # Standard secure response to prevent account enumeration
        response_data = {
            'success': True,
            'message': 'If an account exists with these details, password reset instructions have been generated.',
            'email_or_phone': raw_identifier,
        }

        # For debug / local testing environments where email/SMS is not provisioned
        from django.conf import settings
        if settings.DEBUG and reset_code:
            response_data['dev_reset_code'] = reset_code

        return response_data


class ResetPasswordSerializer(serializers.Serializer):
    email_or_phone = serializers.CharField(
        required=True
    )
    token = serializers.CharField(
        required=True,
        help_text="6-digit reset OTP or verification token"
    )
    new_password = serializers.CharField(
        write_only=True,
        min_length=6
    )
    confirm_password = serializers.CharField(
        write_only=True
    )

    def validate(self, attrs):
        import re
        import hashlib
        from django.db.models import Q
        from django.utils import timezone
        from .models import PasswordResetToken

        raw_identifier = attrs['email_or_phone'].strip()
        token = attrs['token'].strip()
        new_password = attrs['new_password']
        confirm_password = attrs['confirm_password']

        if new_password != confirm_password:
            raise serializers.ValidationError({
                'confirm_password': 'Passwords do not match.'
            })

        phone_digits = re.sub(r'\D', '', raw_identifier)
        norm_phone = phone_digits[-10:] if len(phone_digits) >= 10 else ''

        query = Q(email__iexact=raw_identifier) | Q(username__iexact=raw_identifier)
        if norm_phone:
            query |= Q(profile__phone__icontains=norm_phone)

        user = User.objects.filter(query).distinct().first()

        if not user:
            raise serializers.ValidationError({
                'detail': 'Invalid account or verification code.'
            })

        token_hash = hashlib.sha256(token.encode('utf-8')).hexdigest()

        reset_token_record = PasswordResetToken.objects.filter(
            user=user,
            is_used=False,
            expires_at__gte=timezone.now()
        ).order_by('-created_at').first()

        if not reset_token_record:
            raise serializers.ValidationError({
                'token': 'Verification code has expired or is invalid. Please request a new one.'
            })

        if reset_token_record.verification_attempts >= 5:
            reset_token_record.is_used = True
            reset_token_record.save(update_fields=['is_used'])
            raise serializers.ValidationError({
                'token': 'Too many failed verification attempts. Please request a new code.'
            })

        if reset_token_record.token_hash != token_hash:
            reset_token_record.verification_attempts += 1
            reset_token_record.save(update_fields=['verification_attempts'])
            raise serializers.ValidationError({
                'token': 'Incorrect verification code. Please check and try again.'
            })

        # Update password securely using Django's set_password()
        user.set_password(new_password)
        user.save()

        # Invalidate reset token
        reset_token_record.is_used = True
        reset_token_record.used_at = timezone.now()
        reset_token_record.save(update_fields=['is_used', 'used_at'])

        return {
            'success': True,
            'message': 'Password has been reset successfully. You can now login with your new password.'
        }


class ChangePasswordSerializer(serializers.Serializer):
    current_password = serializers.CharField(
        write_only=True,
        required=True
    )
    new_password = serializers.CharField(
        write_only=True,
        required=True,
        min_length=6
    )
    confirm_password = serializers.CharField(
        write_only=True,
        required=True
    )

    def validate(self, attrs):
        if attrs['new_password'] != attrs['confirm_password']:
            raise serializers.ValidationError({
                'confirm_password': 'New password and confirm password do not match.'
            })
        if attrs['new_password'] == attrs['current_password']:
            raise serializers.ValidationError({
                'new_password': 'New password cannot be identical to the temporary password.'
            })
        return attrs


class AdminResetUserPasswordSerializer(serializers.Serializer):
    verification_reason = serializers.CharField(
        required=True,
        min_length=5,
        help_text="Mandatory identity verification reason (e.g. Verified customer identity via phone/official documentation)"
    )


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
    must_change_password = serializers.SerializerMethodField()

    is_gst_requested = serializers.SerializerMethodField()
    gstin = serializers.SerializerMethodField()
    gst_legal_name = serializers.SerializerMethodField()
    gst_billing_address = serializers.SerializerMethodField()
    gst_state_name = serializers.SerializerMethodField()
    gst_pincode = serializers.SerializerMethodField()

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
            'must_change_password',
            'is_gst_requested',
            'gstin',
            'gst_legal_name',
            'gst_billing_address',
            'gst_state_name',
            'gst_pincode',
        ]

    def get_is_gst_requested(self, obj):
        prof = getattr(obj, 'profile', None)
        return getattr(prof, 'is_gst_requested', False) if prof else False

    def get_gstin(self, obj):
        prof = getattr(obj, 'profile', None)
        return getattr(prof, 'gstin', '') if prof else ''

    def get_gst_legal_name(self, obj):
        prof = getattr(obj, 'profile', None)
        return getattr(prof, 'gst_legal_name', '') if prof else ''

    def get_gst_billing_address(self, obj):
        prof = getattr(obj, 'profile', None)
        return getattr(prof, 'gst_billing_address', '') if prof else ''

    def get_gst_state_name(self, obj):
        prof = getattr(obj, 'profile', None)
        return getattr(prof, 'gst_state_name', '') if prof else ''

    def get_gst_pincode(self, obj):
        prof = getattr(obj, 'profile', None)
        return getattr(prof, 'gst_pincode', '') if prof else ''

    def get_must_change_password(self, obj):
        return getattr(getattr(obj, 'profile', None), 'must_change_password', False)

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
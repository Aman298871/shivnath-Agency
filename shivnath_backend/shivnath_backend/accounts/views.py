from decimal import Decimal, InvalidOperation
from datetime import datetime
from django.shortcuts import get_object_or_404
from django.utils import timezone
from django.db.models import Q
from rest_framework_simplejwt.authentication import JWTAuthentication
from rest_framework import status
from rest_framework.permissions import (
    AllowAny,
    IsAuthenticated,
)
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import FranchiseProfile, UserProfile
from .permissions import IsAdminRole, IsApprovedFranchise

from .serializers import (
    CustomerRegisterSerializer,
    FranchiseRegisterSerializer,
    LoginSerializer,
    CurrentUserSerializer,
)
from django.contrib.auth.models import User
from django.db import transaction

class CustomerRegisterView(APIView):

    permission_classes = [AllowAny]
    authentication_classes = []

    def post(self, request):

        serializer = CustomerRegisterSerializer(
            data=request.data
        )

        if serializer.is_valid():

            user = serializer.save()

            # Link existing lead if matching phone / email
            try:
                from leads.models import Lead, LeadActivity
                phone_raw = str(request.data.get('phone', ''))
                cleaned_phone = phone_raw.replace(' ', '').replace('-', '').replace('+', '')
                if len(cleaned_phone) >= 10:
                    cleaned_phone = cleaned_phone[-10:]
                email_raw = str(request.data.get('email', '')).strip().lower()

                lead_query = Q()
                if cleaned_phone:
                    lead_query |= Q(phone__icontains=cleaned_phone)
                if email_raw:
                    lead_query |= Q(email__iexact=email_raw)

                if lead_query:
                    matching_leads = Lead.objects.filter(lead_query)
                    for lead in matching_leads:
                        lead.converted_user = user
                        lead.save(update_fields=['converted_user'])
                        LeadActivity.objects.create(
                            lead=lead,
                            activity_type='converted',
                            title='Customer Registered',
                            description=f'User account created for {user.get_full_name() or user.username} (User ID: {user.id}).'
                        )
            except Exception:
                pass

            return Response(
                {
                    'success': True,
                    'message':
                        'Customer account created successfully. You can now login.',
                    'user': {
                        'id': user.id,
                        'name':
                            user.get_full_name(),
                        'email': user.email,
                        'role': 'customer',
                    }
                },
                status=status.HTTP_201_CREATED
            )

        return Response(
            {
                'success': False,
                'errors': serializer.errors,
            },
            status=status.HTTP_400_BAD_REQUEST
        )

class PendingFranchiseListView(APIView):
    permission_classes = [IsAdminRole]

    def get(self, request):
        franchises = FranchiseProfile.objects.filter(
            status='pending'
        ).select_related('user', 'user__profile')

        data = []

        for franchise in franchises:
            data.append({
                'id': franchise.id,
                'user_id': franchise.user.id,
                'owner_name':
                    franchise.user.get_full_name()
                    or franchise.user.username,
                'business_name':
                    franchise.business_name,
                'email':
                    franchise.user.email,
                'phone':
                    franchise.user.profile.phone,
                'city':
                    franchise.city,
                'address':
                    franchise.address,
                'gst_number':
                    franchise.gst_number,
                'status':
                    franchise.status,
                'rejection_reason':
                    franchise.rejection_reason,
                'created_at':
                    franchise.created_at,
            })

        return Response(
            data,
            status=status.HTTP_200_OK
        )


class FranchiseListView(APIView):
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAdminRole]

    def get(self, request):
        franchises = FranchiseProfile.objects.all().select_related(
            'user',
            'user__profile'
        ).order_by('-created_at')

        data = []

        for franchise in franchises:
            data.append({
                'id': franchise.id,

                'user_id': franchise.user.id,

                'owner_name':
                    franchise.user.get_full_name()
                    or franchise.user.username,

                'business_name':
                    franchise.business_name,

                'email':
                    franchise.user.email,

                'phone':
                    franchise.user.profile.phone,

                'city':
                    franchise.city,

                'address':
                    franchise.address,

                'territory':
                    franchise.territory,

                'gst_number':
                    franchise.gst_number,

                'pan':
                    franchise.pan_number,

                'aadhaar':
                    franchise.aadhaar_number,

                'security_deposit':
                    float(
                        franchise.security_deposit
                    ),

                'commission':
                    str(franchise.commission),

                'renewal_date':
                    franchise.renewal_date,

                'agreement':
                    (
                        'Uploaded'
                        if franchise.agreement_status
                        == 'uploaded'
                        else 'Pending'
                    ),

                'status':
                    franchise.status,

                'rejection_reason':
                    franchise.rejection_reason,

                'approved_at':
                    franchise.approved_at,

                'created_at':
                    franchise.created_at,
            })

        return Response(
            data,
            status=status.HTTP_200_OK
        )


class ApproveFranchiseView(APIView):
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAdminRole]

    def post(self, request, pk):
        franchise = get_object_or_404(
            FranchiseProfile,
            pk=pk
        )

        if franchise.status == 'approved':
            return Response(
                {
                    'success': True,
                    'message':
                        'Franchise is already approved.'
                },
                status=status.HTTP_200_OK
            )

        franchise.status = 'approved'
        franchise.rejection_reason = ''
        franchise.approved_at = timezone.now()

        franchise.save(
            update_fields=[
                'status',
                'rejection_reason',
                'approved_at',
                'updated_at',
            ]
        )

        return Response(
            {
                'success': True,
                'message':
                    'Franchise approved successfully.',
                'franchise': {
                    'id': franchise.id,
                    'business_name':
                        franchise.business_name,
                    'status':
                        franchise.status,
                }
            },
            status=status.HTTP_200_OK
        )


class RejectFranchiseView(APIView):
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAdminRole]

    def post(self, request, pk):
        franchise = get_object_or_404(
            FranchiseProfile,
            pk=pk
        )

        reason = str(
            request.data.get(
                'reason',
                ''
            )
        ).strip()

        if not reason:
            return Response(
                {
                    'success': False,
                    'message':
                        'Rejection reason is required.'
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        franchise.status = 'rejected'
        franchise.rejection_reason = reason
        franchise.approved_at = None

        franchise.save(
            update_fields=[
                'status',
                'rejection_reason',
                'approved_at',
                'updated_at',
            ]
        )

        return Response(
            {
                'success': True,
                'message':
                    'Franchise rejected successfully.',
                'franchise': {
                    'id': franchise.id,
                    'business_name':
                        franchise.business_name,
                    'status':
                        franchise.status,
                    'rejection_reason':
                        franchise.rejection_reason,
                }
            },
            status=status.HTTP_200_OK
        )
class AdminCreateFranchiseView(APIView):
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAdminRole]

    @transaction.atomic
    def post(self, request):
        owner_name = str(
            request.data.get('owner_name', '')
        ).strip()

        business_name = str(
            request.data.get('business_name', '')
        ).strip()

        phone = str(
            request.data.get('phone', '')
        ).strip()

        email = str(
            request.data.get('email', '')
        ).strip().lower()

        city = str(
            request.data.get('city', '')
        ).strip()

        address = str(
            request.data.get('address', '')
        ).strip()

        territory = str(
            request.data.get('territory', '')
        ).strip()

        gst_number = str(
            request.data.get('gst_number', '')
        ).strip()

        pan_number = str(
            request.data.get('pan_number', '')
        ).strip()

        aadhaar_number = str(
            request.data.get('aadhaar_number', '')
        ).strip()

        password = str(
            request.data.get('password', '')
        ).strip()

        if not owner_name:
            return Response(
                {
                    'success': False,
                    'message': 'Owner name is required.'
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        if not business_name:
            return Response(
                {
                    'success': False,
                    'message': 'Business name is required.'
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        if not phone:
            return Response(
                {
                    'success': False,
                    'message': 'Phone number is required.'
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        if not email:
            return Response(
                {
                    'success': False,
                    'message': 'Email is required.'
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        if not city:
            return Response(
                {
                    'success': False,
                    'message': 'City is required.'
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        if not password:
            return Response(
                {
                    'success': False,
                    'message': 'Password is required.'
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        if len(password) < 6:
            return Response(
                {
                    'success': False,
                    'message':
                        'Password must be at least 6 characters.'
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        if User.objects.filter(
            email__iexact=email
        ).exists():
            return Response(
                {
                    'success': False,
                    'message':
                        'An account with this email already exists.'
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        security_deposit_raw = request.data.get(
            'security_deposit',
            0
        )

        commission_raw = request.data.get(
            'commission',
            0
        )

        try:
            security_deposit = Decimal(
                str(security_deposit_raw or 0)
            )

            commission = Decimal(
                str(commission_raw or 0)
            )

        except (InvalidOperation, ValueError):
            return Response(
                {
                    'success': False,
                    'message':
                        'Security deposit or commission is invalid.'
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        if security_deposit < 0:
            return Response(
                {
                    'success': False,
                    'message':
                        'Security deposit cannot be negative.'
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        if commission < 0 or commission > 100:
            return Response(
                {
                    'success': False,
                    'message':
                        'Commission must be between 0 and 100.'
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        renewal_date_raw = request.data.get(
            'renewal_date'
        )

        renewal_date = None

        if renewal_date_raw is not None:
            renewal_date_raw = str(
                renewal_date_raw
            ).strip()

            if renewal_date_raw:
                parsed_date = None

                for date_format in [
                    '%Y-%m-%d',
                    '%d/%m/%Y',
                ]:
                    try:
                        parsed_date = datetime.strptime(
                            renewal_date_raw,
                            date_format
                        ).date()
                        break

                    except ValueError:
                        continue

                if parsed_date is None:
                    return Response(
                        {
                            'success': False,
                            'message':
                                'Invalid renewal date. Use DD/MM/YYYY or YYYY-MM-DD.'
                        },
                        status=status.HTTP_400_BAD_REQUEST
                    )

                renewal_date = parsed_date

        agreement_status = str(
            request.data.get(
                'agreement_status',
                'pending'
            )
        ).lower()

        if agreement_status not in [
            'pending',
            'uploaded',
        ]:
            return Response(
                {
                    'success': False,
                    'message':
                        'Invalid agreement status.'
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        franchise_status = str(
            request.data.get(
                'status',
                'approved'
            )
        ).lower()

        allowed_statuses = [
            'pending',
            'approved',
            'rejected',
            'inactive',
            'suspended',
        ]

        if franchise_status not in allowed_statuses:
            return Response(
                {
                    'success': False,
                    'message':
                        'Invalid franchise status.'
                },
                status=status.HTTP_400_BAD_REQUEST
            )

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

        profile.phone = phone
        profile.role = 'franchise'
        profile.save()

        franchise = FranchiseProfile.objects.create(
            user=user,
            business_name=business_name,
            city=city,
            address=address,
            territory=territory,
            gst_number=gst_number,
            pan_number=pan_number,
            aadhaar_number=aadhaar_number,
            security_deposit=security_deposit,
            commission=commission,
            renewal_date=renewal_date,
            agreement_status=agreement_status,
            status=franchise_status,
            approved_at=(
                timezone.now()
                if franchise_status == 'approved'
                else None
            ),
        )

        return Response(
            {
                'success': True,
                'message':
                    'Franchise created successfully.',
                'franchise': {
                    'id': franchise.id,
                    'owner_name': owner_name,
                    'business_name':
                        franchise.business_name,
                    'phone': profile.phone,
                    'email': user.email,
                    'city': franchise.city,
                    'address': franchise.address,
                    'territory':
                        franchise.territory,
                    'gst_number':
                        franchise.gst_number,
                    'pan_number':
                        franchise.pan_number,
                    'aadhaar_number':
                        franchise.aadhaar_number,
                    'security_deposit':
                        str(
                            franchise.security_deposit
                        ),
                    'commission':
                        str(franchise.commission),
                    'renewal_date':
                        (
                            franchise.renewal_date.isoformat()
                            if franchise.renewal_date
                            else None
                        ),
                    'agreement_status':
                        franchise.agreement_status,
                    'status':
                        franchise.status,
                }
            },
            status=status.HTTP_201_CREATED
        )
                
class UpdateFranchiseView(APIView):
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAdminRole]

    def put(self, request, pk):
        franchise = get_object_or_404(
            FranchiseProfile,
            pk=pk
        )

        user = franchise.user
        profile = user.profile

        # ---------------------------------
        # BASIC DETAILS
        # ---------------------------------

        owner_name = str(
            request.data.get(
                'owner_name',
                user.get_full_name()
            )
        ).strip()

        phone = str(
            request.data.get(
                'phone',
                profile.phone
            )
        ).strip()

        email = str(
            request.data.get(
                'email',
                user.email
            )
        ).strip().lower()

        city = str(
            request.data.get(
                'city',
                franchise.city
            )
        ).strip()

        territory = str(
            request.data.get(
                'territory',
                franchise.territory
            )
        ).strip()

        gst_number = str(
            request.data.get(
                'gst_number',
                franchise.gst_number
            )
        ).strip()

        pan_number = str(
            request.data.get(
                'pan_number',
                franchise.pan_number
            )
        ).strip()

        aadhaar_number = str(
            request.data.get(
                'aadhaar_number',
                franchise.aadhaar_number
            )
        ).strip()

        # ---------------------------------
        # REQUIRED VALIDATION
        # ---------------------------------

        if not owner_name:
            return Response(
                {
                    'success': False,
                    'message':
                        'Owner name is required.'
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        if not phone:
            return Response(
                {
                    'success': False,
                    'message':
                        'Phone number is required.'
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        if not city:
            return Response(
                {
                    'success': False,
                    'message':
                        'City is required.'
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        # ---------------------------------
        # SECURITY DEPOSIT + COMMISSION
        # ---------------------------------

        security_deposit_raw = request.data.get(
            'security_deposit',
            franchise.security_deposit
        )

        commission_raw = request.data.get(
            'commission',
            franchise.commission
        )

        try:
            security_deposit = Decimal(
                str(security_deposit_raw or 0)
            )

            commission = Decimal(
                str(commission_raw or 0)
            )

        except (InvalidOperation, ValueError):
            return Response(
                {
                    'success': False,
                    'message':
                        'Security deposit or commission is invalid.'
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        if security_deposit < 0:
            return Response(
                {
                    'success': False,
                    'message':
                        'Security deposit cannot be negative.'
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        if commission < 0 or commission > 100:
            return Response(
                {
                    'success': False,
                    'message':
                        'Commission must be between 0 and 100.'
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        # ---------------------------------
        # RENEWAL DATE
        # Supports:
        # 25/08/2027
        # 2027-08-25
        # ---------------------------------

        renewal_date_raw = request.data.get(
            'renewal_date'
        )

        renewal_date = franchise.renewal_date

        if renewal_date_raw is not None:
            renewal_date_raw = str(
                renewal_date_raw
            ).strip()

            if renewal_date_raw == '':
                renewal_date = None

            else:
                parsed_date = None

                for date_format in [
                    '%Y-%m-%d',
                    '%d/%m/%Y',
                ]:
                    try:
                        parsed_date = datetime.strptime(
                            renewal_date_raw,
                            date_format
                        ).date()

                        break

                    except ValueError:
                        continue

                if parsed_date is None:
                    return Response(
                        {
                            'success': False,
                            'message':
                                'Invalid renewal date. Use DD/MM/YYYY or YYYY-MM-DD.'
                        },
                        status=status.HTTP_400_BAD_REQUEST
                    )

                renewal_date = parsed_date

        # ---------------------------------
        # AGREEMENT STATUS
        # ---------------------------------

        agreement_status = str(
            request.data.get(
                'agreement_status',
                franchise.agreement_status
            )
        ).lower()

        if agreement_status not in [
            'pending',
            'uploaded'
        ]:
            return Response(
                {
                    'success': False,
                    'message':
                        'Invalid agreement status.'
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        # ---------------------------------
        # FRANCHISE STATUS
        # ---------------------------------

        franchise_status = str(
            request.data.get(
                'status',
                franchise.status
            )
        ).lower()

        allowed_statuses = [
            'pending',
            'approved',
            'rejected',
            'inactive',
            'suspended',
        ]

        if franchise_status not in allowed_statuses:
            return Response(
                {
                    'success': False,
                    'message':
                        'Invalid franchise status.'
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        # ---------------------------------
        # UPDATE USER
        # ---------------------------------

        user.first_name = owner_name
        user.email = email

        user.save(
            update_fields=[
                'first_name',
                'email',
            ]
        )

        # ---------------------------------
        # UPDATE USER PROFILE
        # ---------------------------------

        profile.phone = phone
        profile.save()

        # ---------------------------------
        # UPDATE FRANCHISE
        # ---------------------------------

        franchise.city = city
        franchise.territory = territory
        franchise.gst_number = gst_number
        franchise.pan_number = pan_number
        franchise.aadhaar_number = aadhaar_number

        franchise.security_deposit = security_deposit
        franchise.commission = commission
        franchise.renewal_date = renewal_date
        franchise.agreement_status = agreement_status
        franchise.status = franchise_status

        # ---------------------------------
        # APPROVAL STATUS
        # ---------------------------------

        if franchise_status == 'approved':
            if franchise.approved_at is None:
                franchise.approved_at = timezone.now()

            franchise.rejection_reason = ''

        elif franchise_status != 'approved':
            franchise.approved_at = None

        # ---------------------------------
        # SAVE
        # ---------------------------------

        franchise.save()

        return Response(
            {
                'success': True,
                'message':
                    'Franchise updated successfully.',
                'franchise': {
                    'id': franchise.id,
                    'owner_name': owner_name,
                    'phone': profile.phone,
                    'email': user.email,
                    'city': franchise.city,
                    'territory':
                        franchise.territory,
                    'gst_number':
                        franchise.gst_number,
                    'pan_number':
                        franchise.pan_number,
                    'aadhaar_number':
                        franchise.aadhaar_number,
                    'security_deposit':
                        str(
                            franchise.security_deposit
                        ),
                    'commission':
                        str(
                            franchise.commission
                        ),
                    'renewal_date':
                        (
                            franchise.renewal_date.isoformat()
                            if franchise.renewal_date
                            else None
                        ),
                    'agreement_status':
                        franchise.agreement_status,
                    'status':
                        franchise.status,
                }
            },
            status=status.HTTP_200_OK
        )
        
class DeleteFranchiseView(APIView):
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAdminRole]

    def delete(self, request, pk):
        franchise = get_object_or_404(
            FranchiseProfile,
            pk=pk
        )

        user = franchise.user

        user.delete()

        return Response({
            'success': True,
            'message':
                'Franchise deleted successfully.'
        })                
class FranchiseRegisterView(APIView):

    permission_classes = [AllowAny]
    authentication_classes = []

    def post(self, request):

        serializer = FranchiseRegisterSerializer(
            data=request.data
        )

        if serializer.is_valid():

            user = serializer.save()
            refresh = RefreshToken.for_user(user)

            phone = ''
            if hasattr(user, 'profile'):
                phone = user.profile.phone

            business_name = ''
            city = ''
            territory = ''
            if hasattr(user, 'franchise_profile'):
                business_name = user.franchise_profile.business_name
                city = user.franchise_profile.city
                territory = user.franchise_profile.territory

            return Response(
                {
                    'success': True,
                    'message':
                        'Franchise application submitted successfully. Please wait for admin approval.',
                    'access': str(refresh.access_token),
                    'refresh': str(refresh),
                    'user': {
                        'id': user.id,
                        'name':
                            user.get_full_name(),
                        'email': user.email,
                        'phone': phone,
                        'role': 'franchise',
                        'status': 'pending',
                        'rejection_reason': '',
                        'business_name': business_name,
                        'city': city,
                        'territory': territory,
                    }
                },
                status=status.HTTP_201_CREATED
            )

        return Response(
            {
                'success': False,
                'errors': serializer.errors,
            },
            status=status.HTTP_400_BAD_REQUEST
        )


class LoginView(APIView):

    permission_classes = [AllowAny]
    authentication_classes = []

    def post(self, request):

        serializer = LoginSerializer(
            data=request.data
        )

        if serializer.is_valid():

            return Response(
                serializer.validated_data,
                status=status.HTTP_200_OK
            )

        return Response(
            serializer.errors,
            status=status.HTTP_400_BAD_REQUEST
        )


class CurrentUserView(APIView):

    permission_classes = [
        IsAuthenticated
    ]

    def get(self, request):

        serializer = CurrentUserSerializer(
            request.user
        )

        return Response(
            serializer.data,
            status=status.HTTP_200_OK
        )


class AdminUserListView(APIView):
    """
    Admin endpoint to view registered users (Customers, Franchises)
    safely without exposing credentials or internal admin accounts in the normal user directory.
    """
    permission_classes = [IsAdminRole]

    def get(self, request):
        role_filter = request.query_params.get('role', '').strip().lower()
        search = request.query_params.get('search', '').strip().lower()

        users = User.objects.select_related('profile', 'franchise_profile').all().order_by('-date_joined')

        if role_filter == 'customer':
            users = users.filter(profile__role='customer')
        elif role_filter == 'franchise':
            users = users.filter(profile__role='franchise')
        elif role_filter == 'admin':
            users = users.filter(Q(profile__role='admin') | Q(is_superuser=True))
        elif role_filter == 'staff':
            users = users.filter(profile__role='staff')
        else:
            # By default, in user directory, show only actual customers and franchises
            users = users.exclude(profile__role__in=['admin', 'staff']).exclude(is_superuser=True)

        if search:
            from django.db.models import Q
            users = users.filter(
                Q(username__icontains=search) |
                Q(email__icontains=search) |
                Q(first_name__icontains=search) |
                Q(last_name__icontains=search) |
                Q(profile__phone__icontains=search) |
                Q(franchise_profile__business_name__icontains=search)
            )

        results = []
        from orders.models import Order
        from datetime import date
        today = date.today()

        for u in users.distinct():
            prof = getattr(u, 'profile', None)
            fp = getattr(u, 'franchise_profile', None)
            rel = getattr(u, 'customer_relationship', None)
            role = prof.role if prof else ('admin' if u.is_superuser else 'customer')

            order_count = Order.objects.filter(created_by=u).count()

            # Active stock cycle info
            stock_info = None
            if role == 'customer':
                from .models import CustomerStockCycle
                cycle = CustomerStockCycle.objects.filter(customer=u, service_status__in=['active', 'hold']).first()
                if cycle:
                    rem = cycle.remaining_days_at_hold if cycle.service_status == 'hold' and cycle.remaining_days_at_hold is not None else max((cycle.expected_end_date - today).days, 0)
                    stock_info = {
                        'id': cycle.id,
                        'duration_choice': cycle.duration_choice,
                        'duration_days': cycle.duration_days,
                        'start_date': cycle.start_date.isoformat(),
                        'expected_end_date': cycle.expected_end_date.isoformat(),
                        'service_status': cycle.service_status,
                        'remaining_days': rem,
                        'is_low_stock': (rem <= 7 and cycle.service_status == 'active'),
                        'serving_franchise_id': cycle.serving_franchise.id,
                        'serving_franchise_name': cycle.serving_franchise.business_name,
                    }

            item = {
                'id': u.id,
                'customer_code': f'CUST-{1000 + u.id}' if role == 'customer' else f'FRAN-{1000 + u.id}',
                'name': (prof.name if prof and prof.name else (u.get_full_name() or u.username)),
                'username': u.username,
                'email': u.email,
                'phone': prof.phone if prof else '',
                'city': (prof.city if prof and prof.city else (fp.city if fp else '')),
                'district': (rel.district.name if rel and rel.district else (prof.district if prof else '')),
                'pincode': (rel.pincode if rel and rel.pincode else (prof.pincode if prof else '')),
                'zone_name': (rel.zone.name if rel and rel.zone else (prof.zone.name if prof and prof.zone else '')),
                'locality': (rel.locality if rel and rel.locality else (prof.locality if prof else '')),
                'address': (prof.address if prof and prof.address else (fp.address if fp else '')),
                'role': role,
                'status': prof.status if prof else ('active' if u.is_active else 'inactive'),
                'service_status': rel.service_status if rel else 'active',
                'is_active': u.is_active,
                'order_count': order_count,
                'registered_franchise': {
                    'id': rel.registered_franchise.id,
                    'business_name': rel.registered_franchise.business_name,
                } if rel and rel.registered_franchise else None,
                'current_serving_franchise': {
                    'id': rel.current_serving_franchise.id,
                    'business_name': rel.current_serving_franchise.business_name,
                } if rel and rel.current_serving_franchise else None,
                'active_stock_cycle': stock_info,
                'date_joined': u.date_joined.strftime('%Y-%m-%d %H:%M'),
            }

            if fp:
                item['franchise_details'] = {
                    'business_name': fp.business_name,
                    'status': fp.status,
                    'territory': fp.territory or 'Pending',
                    'is_headquarters': fp.is_headquarters,
                    'gst_number': fp.gst_number or '',
                    'security_deposit': str(fp.security_deposit),
                    'commission_rate': str(fp.commission),
                }

            results.append(item)

        return Response({
            'success': True,
            'count': len(results),
            'users': results,
        }, status=status.HTTP_200_OK)


class AdminNotificationListView(APIView):
    permission_classes = [IsAdminRole]

    def get(self, request):
        from .models import AdminNotification
        notifications = AdminNotification.objects.all()[:50]
        unread_count = AdminNotification.objects.filter(is_read=False).count()

        results = [
            {
                'id': n.id,
                'title': n.title,
                'message': n.message,
                'notification_type': n.notification_type,
                'reference_id': n.reference_id,
                'is_read': n.is_read,
                'created_at': n.created_at.strftime('%Y-%m-%d %H:%M'),
            }
            for n in notifications
        ]

        return Response({
            'success': True,
            'unread_count': unread_count,
            'count': len(results),
            'notifications': results,
        }, status=status.HTTP_200_OK)

    def post(self, request):
        from .models import AdminNotification
        notification_id = request.data.get('id')
        if notification_id:
            AdminNotification.objects.filter(id=notification_id).update(is_read=True)
        else:
            AdminNotification.objects.filter(is_read=False).update(is_read=True)
        return Response({'success': True, 'message': 'Notifications marked as read.'})


# =====================================================================
# TERRITORY RESOLUTION & MASTER VIEWS
# =====================================================================

class ZoneResolutionView(APIView):
    """
    Public endpoint: Customer inputs District + PIN (and optional locality).
    Database derives the authoritative ServiceZone.
    Handles unambiguous, ambiguous (multiple zones for PIN), and unknown PINs.
    """
    permission_classes = [AllowAny]
    authentication_classes = []

    def post(self, request):
        district_str = str(request.data.get('district', '')).strip()
        pincode_str = str(request.data.get('pincode', '')).strip()
        locality_str = str(request.data.get('locality', '')).strip()

        if not pincode_str:
            return Response({
                'success': False,
                'status': 'error',
                'message': 'PIN code is required to resolve service zone.'
            }, status=status.HTTP_400_BAD_REQUEST)

        from .models import ServiceArea, ServiceDistrict, ServiceZone

        # Query matching active areas
        areas_query = ServiceArea.objects.filter(pincode=pincode_str, is_active=True).select_related('district', 'zone')
        if district_str:
            district_match = areas_query.filter(district__name__iexact=district_str)
            if district_match.exists():
                areas_query = district_match

        if not areas_query.exists():
            # Unknown PIN code -> suggest recognized areas
            available = ServiceArea.objects.filter(is_active=True).select_related('district', 'zone')[:8]
            return Response({
                'success': True,
                'status': 'unknown',
                'pincode': pincode_str,
                'district': district_str,
                'message': f'PIN code {pincode_str} was not found in our currently active service areas. Please select your locality or contact support.',
                'available_areas': [
                    {
                        'area_id': a.id,
                        'locality': a.locality_name,
                        'pincode': a.pincode,
                        'district': a.district.name,
                        'zone_id': a.zone.id,
                        'zone_name': a.zone.name,
                    }
                    for a in available
                ]
            }, status=status.HTTP_200_OK)

        # Check unique zones
        unique_zones = list({a.zone for a in areas_query})

        if len(unique_zones) == 1:
            z = unique_zones[0]
            matched_area = areas_query.first()
            return Response({
                'success': True,
                'status': 'resolved',
                'zone_id': z.id,
                'zone_name': z.name,
                'zone_code': z.code,
                'district': matched_area.district.name,
                'pincode': pincode_str,
                'locality': matched_area.locality_name,
                'message': f'📍 Your service zone appears to be {z.name}.'
            }, status=status.HTTP_200_OK)

        # Multiple zones for this PIN -> check locality if provided
        if locality_str:
            for a in areas_query:
                if a.locality_name.lower() in locality_str.lower() or locality_str.lower() in a.locality_name.lower():
                    return Response({
                        'success': True,
                        'status': 'resolved',
                        'zone_id': a.zone.id,
                        'zone_name': a.zone.name,
                        'zone_code': a.zone.code,
                        'district': a.district.name,
                        'pincode': pincode_str,
                        'locality': a.locality_name,
                        'message': f'📍 Your service zone appears to be {a.zone.name}.'
                    }, status=status.HTTP_200_OK)

        # Ambiguous -> ask customer to choose locality
        options = [
            {
                'area_id': a.id,
                'locality': a.locality_name,
                'zone_id': a.zone.id,
                'zone_name': a.zone.name,
                'district': a.district.name,
            }
            for a in areas_query
        ]
        return Response({
            'success': True,
            'status': 'ambiguous',
            'pincode': pincode_str,
            'district': district_str or areas_query.first().district.name,
            'message': f'PIN code {pincode_str} covers multiple service zones. Please select your specific locality or delivery area.',
            'options': options,
        }, status=status.HTTP_200_OK)


class TerritoryMasterView(APIView):
    """
    Returns hierarchical master territory data: Districts, Zones, and Service Areas.
    """
    permission_classes = [AllowAny]
    authentication_classes = []

    def get(self, request):
        from .models import ServiceDistrict
        from .serializers import ServiceDistrictSerializer
        districts = ServiceDistrict.objects.filter(is_active=True).prefetch_related('zones__areas')
        serializer = ServiceDistrictSerializer(districts, many=True)
        return Response({
            'success': True,
            'districts': serializer.data,
        }, status=status.HTTP_200_OK)


class EligibleFranchisesView(APIView):
    """
    Returns active franchises serving a specific District and Zone.
    Derived server-side from customer's profile if authenticated, or query params.
    Uses multi-tier resolver: Exact Zone -> Same-District Fallback -> Service Unavailable.
    """
    permission_classes = [AllowAny]

    def get(self, request):
        from .models import ServiceZone, ServiceDistrict
        from .services import resolve_serviceable_franchises

        zone_id = request.query_params.get('zone_id')
        district_name = request.query_params.get('district', '').strip()

        target_zone = None
        target_district = None

        # If user is authenticated customer, auto-derive zone and district from customer relationship
        if request.user and request.user.is_authenticated:
            rel = getattr(request.user, 'customer_relationship', None)
            if rel:
                if not zone_id and rel.zone:
                    target_zone = rel.zone
                if not district_name and rel.district:
                    target_district = rel.district

        if zone_id and not target_zone:
            try:
                target_zone = ServiceZone.objects.select_related('district').get(id=zone_id, is_active=True)
            except ServiceZone.DoesNotExist:
                pass

        if district_name and not target_district:
            target_district = ServiceDistrict.objects.filter(name__iexact=district_name, is_active=True).first()

        result = resolve_serviceable_franchises(zone=target_zone, district=target_district, allow_fallback=True)
        return Response(result, status=status.HTTP_200_OK)



# =====================================================================
# SERVICE HOLD / RESUME LIFECYCLE VIEW
# =====================================================================

class CustomerServiceStatusView(APIView):
    """
    Safe multi-cycle ACTIVE <-> HOLD lifecycle management.
    Customer can hold/resume their own service.
    Serving franchise can hold/resume customers currently served by it.
    Admin can hold/resume any customer.
    """
    permission_classes = [IsAuthenticated]

    def post(self, request):
        action = str(request.data.get('action', '')).strip().lower()
        reason = str(request.data.get('reason', '')).strip()
        target_customer_id = request.data.get('customer_id')

        if action not in ['hold', 'resume']:
            return Response({
                'success': False,
                'message': 'Action must be either "hold" or "resume".'
            }, status=status.HTTP_400_BAD_REQUEST)

        from .models import (
            CustomerFranchiseRelationship,
            CustomerStockCycle,
            ServiceHoldHistory,
            FranchiseNotification,
            AdminNotification,
        )
        from datetime import date, timedelta

        actor = request.user
        actor_role = getattr(actor, 'profile', None).role if hasattr(actor, 'profile') else 'customer'

        # Determine target customer
        if target_customer_id and (actor_role in ['admin', 'staff'] or actor.is_superuser):
            customer_user = get_object_or_404(User, id=target_customer_id)
        elif target_customer_id and actor_role == 'franchise':
            customer_user = get_object_or_404(User, id=target_customer_id)
            fp = getattr(actor, 'franchise_profile', None)
            rel = getattr(customer_user, 'customer_relationship', None)
            # Permission check: must be serving or registered franchise
            is_served = CustomerStockCycle.objects.filter(customer=customer_user, serving_franchise=fp).exists()
            is_registered = (rel and rel.registered_franchise == fp)
            if not (is_served or is_registered):
                return Response({
                    'success': False,
                    'message': 'Permission denied. You can only modify service status for customers served by your franchise.'
                }, status=status.HTTP_403_FORBIDDEN)
        else:
            customer_user = actor

        rel, _ = CustomerFranchiseRelationship.objects.get_or_create(
            customer=customer_user,
            defaults={'service_status': 'active'}
        )

        today = date.today()

        if action == 'hold':
            cycle = CustomerStockCycle.objects.filter(customer=customer_user, service_status='active').order_by('-created_at').first()
            if not cycle:
                # If no cycle currently active, still set relationship status
                rel.service_status = 'hold'
                rel.save(update_fields=['service_status'])
                return Response({
                    'success': True,
                    'message': 'Customer service has been placed on hold.',
                    'service_status': 'hold',
                    'remaining_days': 0,
                })

            if cycle.expected_end_date < today:
                return Response({
                    'success': False,
                    'message': 'Cannot pause an expired stock cycle.'
                }, status=status.HTTP_400_BAD_REQUEST)

            remaining_days = max((cycle.expected_end_date - today).days, 0)
            cycle.remaining_days_at_hold = remaining_days
            cycle.service_status = 'hold'
            cycle.hold_timestamp = timezone.now()
            cycle.hold_by = actor
            cycle.hold_reason = reason
            cycle.save(update_fields=['remaining_days_at_hold', 'service_status', 'hold_timestamp', 'hold_by', 'hold_reason'])

            rel.service_status = 'hold'
            rel.save(update_fields=['service_status'])

            ServiceHoldHistory.objects.create(
                stock_cycle=cycle,
                customer=customer_user,
                action='hold',
                actor=actor,
                actor_role=actor_role,
                remaining_days=remaining_days,
                notes=reason,
            )

            # Notifications
            try:
                if cycle.serving_franchise:
                    FranchiseNotification.objects.create(
                        franchise=cycle.serving_franchise,
                        title='Customer Service Paused (On Hold)',
                        message=f'Customer {customer_user.get_full_name() or customer_user.username} has paused their water supply service ({remaining_days} days preserved). Reason: {reason or "Customer request"}.',
                        notification_type='service_status',
                        reference_id=cycle.id,
                    )
                AdminNotification.objects.create(
                    title='Customer Service Paused',
                    message=f'Customer {customer_user.get_full_name() or customer_user.username} paused service ({remaining_days} days remaining). Reason: {reason or "N/A"}.',
                    notification_type='service_status',
                    reference_id=cycle.id,
                )
            except Exception:
                pass

            return Response({
                'success': True,
                'message': f'Service placed on hold. {remaining_days} days preserved.',
                'service_status': 'hold',
                'remaining_days': remaining_days,
            }, status=status.HTTP_200_OK)

        elif action == 'resume':
            cycle = CustomerStockCycle.objects.filter(customer=customer_user, service_status='hold').order_by('-created_at').first()
            if not cycle:
                rel.service_status = 'active'
                rel.save(update_fields=['service_status'])
                return Response({
                    'success': True,
                    'message': 'Service resumed.',
                    'service_status': 'active',
                })

            rem = cycle.remaining_days_at_hold if cycle.remaining_days_at_hold is not None else 0
            if rem <= 0:
                return Response({
                    'success': False,
                    'message': 'Cannot resume a completed or expired stock cycle. Please place a new water order.'
                }, status=status.HTTP_400_BAD_REQUEST)

            new_expected_end_date = today + timedelta(days=rem)
            cycle.expected_end_date = new_expected_end_date
            cycle.service_status = 'active'
            cycle.remaining_days_at_hold = None
            cycle.save(update_fields=['expected_end_date', 'service_status', 'remaining_days_at_hold', 'updated_at'])

            rel.service_status = 'active'
            rel.save(update_fields=['service_status'])

            ServiceHoldHistory.objects.create(
                stock_cycle=cycle,
                customer=customer_user,
                action='resume',
                actor=actor,
                actor_role=actor_role,
                remaining_days=rem,
                notes=reason,
            )

            # Notifications
            try:
                if cycle.serving_franchise:
                    FranchiseNotification.objects.create(
                        franchise=cycle.serving_franchise,
                        title='Customer Service Resumed',
                        message=f'Customer {customer_user.get_full_name() or customer_user.username} has resumed service. Expected cycle active until {new_expected_end_date}.',
                        notification_type='service_status',
                        reference_id=cycle.id,
                    )
                AdminNotification.objects.create(
                    title='Customer Service Resumed',
                    message=f'Customer {customer_user.get_full_name() or customer_user.username} resumed service until {new_expected_end_date}.',
                    notification_type='service_status',
                    reference_id=cycle.id,
                )
            except Exception:
                pass

            return Response({
                'success': True,
                'message': f'Service successfully resumed until {new_expected_end_date.strftime("%d %b %Y")}.',
                'service_status': 'active',
                'expected_end_date': new_expected_end_date.isoformat(),
                'remaining_days': rem,
            }, status=status.HTTP_200_OK)


# =====================================================================
# FRANCHISE CUSTOMER VIEW & DATA ISOLATION
# =====================================================================

class FranchiseCustomerListView(APIView):
    """
    Franchise-only endpoint with strict data isolation:
    A franchise can ONLY access customers registered under it or served by it.
    """
    permission_classes = [IsApprovedFranchise]

    def get(self, request):
        franchise = getattr(request.user, 'franchise_profile', None)
        if not franchise:
            return Response({'success': False, 'message': 'Franchise profile not found.'}, status=status.HTTP_404_NOT_FOUND)

        from .models import CustomerFranchiseRelationship, CustomerStockCycle
        from orders.models import Order
        from datetime import date
        today = date.today()

        # Strict isolation: registered with this franchise OR served by this franchise
        relationships = CustomerFranchiseRelationship.objects.filter(
            Q(registered_franchise=franchise) | Q(current_serving_franchise=franchise)
        ).select_related('customer', 'customer__profile', 'district', 'zone', 'registered_franchise')

        search = request.query_params.get('search', '').strip().lower()
        if search:
            relationships = relationships.filter(
                Q(customer__first_name__icontains=search)
                | Q(customer__email__icontains=search)
                | Q(customer__profile__phone__icontains=search)
                | Q(locality__icontains=search)
                | Q(pincode__icontains=search)
            )

        customer_list = []
        for rel in relationships:
            cust = rel.customer
            prof = getattr(cust, 'profile', None)

            # Only orders fulfilled by THIS franchise
            fulfilled_orders = Order.objects.filter(
                created_by=cust,
                serving_franchise=franchise
            ).order_by('-created_at')

            latest_order = fulfilled_orders.first()

            # Active stock cycle fulfilled by THIS franchise
            cycle = CustomerStockCycle.objects.filter(
                customer=cust,
                serving_franchise=franchise,
                service_status__in=['active', 'hold']
            ).order_by('-created_at').first()

            cycle_data = None
            if cycle:
                rem = cycle.remaining_days_at_hold if cycle.service_status == 'hold' and cycle.remaining_days_at_hold is not None else max((cycle.expected_end_date - today).days, 0)
                cycle_data = {
                    'duration_choice': cycle.duration_choice,
                    'duration_days': cycle.duration_days,
                    'start_date': cycle.start_date.isoformat(),
                    'expected_end_date': cycle.expected_end_date.isoformat(),
                    'service_status': cycle.service_status,
                    'remaining_days': rem,
                    'is_low_stock': (rem <= 7 and cycle.service_status == 'active'),
                }

            customer_list.append({
                'id': cust.id,
                'customer_code': f'CUST-{1000 + cust.id}',
                'name': cust.get_full_name() or (prof.name if prof else cust.username),
                'phone': prof.phone if prof else '',
                'email': cust.email,
                'city': prof.city if prof else '',
                'district': rel.district.name if rel.district else (prof.district if prof else ''),
                'pincode': rel.pincode or (prof.pincode if prof else ''),
                'zone_name': rel.zone.name if rel.zone else (prof.zone.name if prof and prof.zone else ''),
                'locality': rel.locality or (prof.locality if prof else ''),
                'registered_date': cust.date_joined.strftime('%Y-%m-%d %H:%M'),
                'customer_status': prof.status if prof else 'active',
                'service_status': rel.service_status,
                'is_registered_franchise': (rel.registered_franchise == franchise),
                'active_stock_cycle': cycle_data,
                'orders_count': fulfilled_orders.count(),
                'latest_order': {
                    'order_id': latest_order.order_code,
                    'date': latest_order.order_date.isoformat(),
                    'amount': str(latest_order.amount),
                    'status': latest_order.status,
                } if latest_order else None,
            })

        return Response({
            'success': True,
            'count': len(customer_list),
            'customers': customer_list,
        }, status=status.HTTP_200_OK)


# =====================================================================
# FRANCHISE NOTIFICATIONS VIEW
# =====================================================================

class FranchiseNotificationListView(APIView):
    """
    Franchise notification inbox.
    """
    permission_classes = [IsApprovedFranchise]

    def get(self, request):
        franchise = getattr(request.user, 'franchise_profile', None)
        if not franchise:
            return Response({'success': False, 'message': 'Franchise not found.'}, status=status.HTTP_404_NOT_FOUND)

        from .models import FranchiseNotification
        notifs = FranchiseNotification.objects.filter(franchise=franchise)[:50]
        unread = FranchiseNotification.objects.filter(franchise=franchise, is_read=False).count()

        data = [
            {
                'id': n.id,
                'title': n.title,
                'message': n.message,
                'notification_type': n.notification_type,
                'reference_id': n.reference_id,
                'is_read': n.is_read,
                'created_at': n.created_at.strftime('%Y-%m-%d %H:%M'),
            }
            for n in notifs
        ]

        return Response({
            'success': True,
            'unread_count': unread,
            'notifications': data,
        }, status=status.HTTP_200_OK)

    def post(self, request):
        franchise = getattr(request.user, 'franchise_profile', None)
        from .models import FranchiseNotification
        notif_id = request.data.get('id')
        if notif_id:
            FranchiseNotification.objects.filter(franchise=franchise, id=notif_id).update(is_read=True)
        else:
            FranchiseNotification.objects.filter(franchise=franchise, is_read=False).update(is_read=True)
        return Response({'success': True, 'message': 'Franchise notifications marked as read.'})


# =====================================================================
# DYNAMIC CONTEXTUAL SUPPORT CONTACT VIEW
# =====================================================================

class SupportContactView(APIView):
    """
    Dynamic support contact resolution from backend configuration:
    - Customer -> Assigned or Serving Franchise contact.
    - Franchise -> Admin Central Support.
    - Public / Anonymous -> Central Shivnath Helpline.
    """
    permission_classes = [AllowAny]

    def get(self, request):
        user = request.user if request.user and request.user.is_authenticated else None
        role = getattr(getattr(user, 'profile', None), 'role', 'public') if user else 'public'

        from .models import FranchiseProfile

        central_phone = "9806247194"
        central_email = "support@shivnath.com"

        if role == 'franchise':
            return Response({
                'success': True,
                'target': 'admin',
                'name': 'Shivnath Agency Admin Desk',
                'phone': central_phone,
                'email': central_email,
                'message_template': f"Namaste Admin Support,\nI am reaching out regarding franchise account {user.get_full_name() or user.username}."
            })
        elif role == 'customer':
            rel = getattr(user, 'customer_relationship', None)
            target_f = (rel.current_serving_franchise if rel and rel.current_serving_franchise else (rel.registered_franchise if rel else None))
            if target_f:
                f_phone = target_f.user.profile.phone if hasattr(target_f.user, 'profile') and target_f.user.profile.phone else central_phone
                return Response({
                    'success': True,
                    'target': 'franchise',
                    'franchise_id': target_f.id,
                    'name': target_f.business_name,
                    'owner_name': target_f.user.get_full_name() or target_f.user.username,
                    'phone': f_phone,
                    'email': target_f.user.email,
                    'message_template': f"Namaste {target_f.business_name},\nI am customer {user.get_full_name() or user.username} (Phone: {user.profile.phone if hasattr(user, 'profile') else ''}). I need assistance with my drinking water supply."
                })

        return Response({
            'success': True,
            'target': 'central',
            'name': 'Shivnath Agency Central Helpline',
            'phone': central_phone,
            'email': central_email,
            'message_template': "Namaste Shivnath Support,\nI would like to inquire about your pure drinking water products and delivery service."
        })


# =====================================================================
# STOCK MANAGEMENT VIEWS (CUSTOMER, FRANCHISE, ADMIN)
# =====================================================================

class CustomerStockListView(APIView):
    """
    Customer-facing stock management API:
    Returns customer's active and historical stock cycles.
    Includes low-stock alerts, days remaining countdown, and serving franchise contact info.
    """
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]

    def get(self, request):
        user = request.user
        from .models import CustomerStockCycle
        from django.utils import timezone
        today = timezone.now().date()

        cycles = CustomerStockCycle.objects.filter(
            customer=user
        ).select_related(
            'order', 'product', 'serving_franchise', 'serving_franchise__user',
            'serving_franchise__user__profile', 'registered_franchise', 'district',
            'zone', 'service_area'
        ).order_by('-created_at')

        active_stocks = []
        history_stocks = []

        for cycle in cycles:
            sf = cycle.serving_franchise
            rf = cycle.registered_franchise
            order = cycle.order

            sf_phone = sf.user.profile.phone if sf and hasattr(sf.user, 'profile') else ''
            sf_data = {
                'id': sf.id if sf else None,
                'business_name': sf.business_name if sf else 'Shivnath Agency',
                'owner_name': sf.user.get_full_name() if sf else 'Manager',
                'phone': sf_phone,
                'city': sf.city if sf else '',
                'address': sf.address if sf else '',
            } if sf else None

            rf_data = {
                'id': rf.id if rf else None,
                'business_name': rf.business_name if rf else 'Shivnath Agency',
                'city': rf.city if rf else '',
            } if rf else None

            days_rem = cycle.days_remaining
            comp_status = cycle.computed_status
            is_low = cycle.is_low_stock

            item_data = {
                'id': cycle.id,
                'order_id': order.id if order else None,
                'order_code': order.order_code if order else f"ORD-{cycle.id}",
                'order_date': order.order_date.isoformat() if order else cycle.start_date.isoformat(),
                'product_name': cycle.product_name or (order.items.first().product_name if order and order.items.exists() else 'Pure Mineral Water'),
                'variant_size': cycle.variant_size or (order.items.first().size if order and order.items.exists() else 'Standard'),
                'quantity': cycle.quantity,
                'duration_choice': cycle.duration_choice,
                'duration_days': cycle.duration_days,
                'start_date': cycle.start_date.isoformat(),
                'expected_end_date': cycle.expected_end_date.isoformat(),
                'days_remaining': days_rem,
                'service_status': cycle.service_status,
                'computed_status': comp_status,
                'is_low_stock': is_low,
                'low_stock_warning': is_low,
                'low_stock_message': f"Your stock will finish in {days_rem} day{'s' if days_rem != 1 else ''}." if is_low else None,
                'serving_franchise': sf_data,
                'registered_franchise': rf_data,
                'district': cycle.district.name if cycle.district else '',
                'zone': cycle.zone.name if cycle.zone else '',
                'service_area': cycle.service_area.locality_name if cycle.service_area else '',
                'pincode': cycle.pincode,
                'created_at': cycle.created_at.strftime('%Y-%m-%d %H:%M'),
            }

            if comp_status == 'Active' or comp_status == 'On Hold':
                active_stocks.append(item_data)
            else:
                history_stocks.append(item_data)

        return Response({
            'success': True,
            'active_count': len(active_stocks),
            'history_count': len(history_stocks),
            'active_stocks': active_stocks,
            'history_stocks': history_stocks,
        }, status=status.HTTP_200_OK)


class FranchiseCustomerStockListView(APIView):
    """
    Franchise-facing customer stock management:
    Shows all stock cycles where the authenticated franchise is the serving franchise.
    Supports filtering by low-stock (<= 7 days), on-hold, expired, and search.
    Provides customer phone and direct follow-up details.
    """
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsApprovedFranchise]

    def get(self, request):
        franchise = getattr(request.user, 'franchise_profile', None)
        if not franchise:
            return Response({'success': False, 'message': 'Franchise profile not found.'}, status=status.HTTP_404_NOT_FOUND)

        from .models import CustomerStockCycle
        from django.utils import timezone
        today = timezone.now().date()

        # Strict isolation: Serving franchise ownership
        query = CustomerStockCycle.objects.filter(
            serving_franchise=franchise
        ).select_related(
            'customer', 'customer__profile', 'order', 'product',
            'registered_franchise', 'district', 'zone', 'service_area'
        ).order_by('-created_at')

        filter_type = request.query_params.get('filter', 'all').strip().lower()
        search = request.query_params.get('search', '').strip().lower()

        if search:
            query = query.filter(
                Q(customer__first_name__icontains=search)
                | Q(customer__email__icontains=search)
                | Q(customer__profile__phone__icontains=search)
                | Q(product_name__icontains=search)
                | Q(pincode__icontains=search)
            )

        stocks_data = []
        low_stock_count = 0
        on_hold_count = 0

        for cycle in query:
            days_rem = cycle.days_remaining
            comp_status = cycle.computed_status
            is_low = cycle.is_low_stock

            if is_low:
                low_stock_count += 1
            if cycle.service_status == 'hold':
                on_hold_count += 1

            if filter_type == 'low_stock' and not is_low:
                continue
            if filter_type == 'on_hold' and cycle.service_status != 'hold':
                continue
            if filter_type == 'expired' and comp_status != 'Expired':
                continue
            if filter_type == 'active' and comp_status != 'Active':
                continue

            cust = cycle.customer
            prof = getattr(cust, 'profile', None)
            order = cycle.order

            stocks_data.append({
                'id': cycle.id,
                'customer_id': cust.id,
                'customer_name': cust.get_full_name() or (prof.name if prof else cust.username),
                'customer_phone': prof.phone if prof else '',
                'customer_email': cust.email,
                'customer_address': prof.address if prof else '',
                'order_id': order.id if order else None,
                'order_code': order.order_code if order else f"ORD-{cycle.id}",
                'order_date': order.order_date.isoformat() if order else cycle.start_date.isoformat(),
                'product_name': cycle.product_name or 'Pure Mineral Water',
                'variant_size': cycle.variant_size or 'Standard',
                'quantity': cycle.quantity,
                'duration_choice': cycle.duration_choice,
                'duration_days': cycle.duration_days,
                'start_date': cycle.start_date.isoformat(),
                'expected_end_date': cycle.expected_end_date.isoformat(),
                'days_remaining': days_rem,
                'service_status': cycle.service_status,
                'computed_status': comp_status,
                'is_low_stock': is_low,
                'district': cycle.district.name if cycle.district else '',
                'zone': cycle.zone.name if cycle.zone else '',
                'service_area': cycle.service_area.locality_name if cycle.service_area else '',
                'pincode': cycle.pincode,
                'registered_franchise_name': cycle.registered_franchise.business_name if cycle.registered_franchise else 'Shivnath Agency',
                'serving_franchise_name': franchise.business_name,
                'created_at': cycle.created_at.strftime('%Y-%m-%d %H:%M'),
            })

        return Response({
            'success': True,
            'count': len(stocks_data),
            'low_stock_count': low_stock_count,
            'on_hold_count': on_hold_count,
            'stocks': stocks_data,
        }, status=status.HTTP_200_OK)


class AdminStockManagementListView(APIView):
    """
    Central administrative stock management API:
    View all active, low-stock, held, expired stock cycles across all territories.
    Audit hold/resume history.
    """
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAdminRole]

    def get(self, request):
        from .models import CustomerStockCycle, ServiceHoldHistory
        from django.utils import timezone
        today = timezone.now().date()

        filter_type = request.query_params.get('filter', 'all').strip().lower()
        search = request.query_params.get('search', '').strip().lower()

        query = CustomerStockCycle.objects.all().select_related(
            'customer', 'customer__profile', 'order', 'product',
            'serving_franchise', 'registered_franchise', 'district',
            'zone', 'service_area'
        ).order_by('-created_at')

        if search:
            query = query.filter(
                Q(customer__first_name__icontains=search)
                | Q(customer__email__icontains=search)
                | Q(customer__profile__phone__icontains=search)
                | Q(serving_franchise__business_name__icontains=search)
                | Q(zone__name__icontains=search)
                | Q(product_name__icontains=search)
            )

        stocks_data = []
        metrics = {
            'total_all': CustomerStockCycle.objects.count(),
            'total_active': 0,
            'total_low_stock': 0,
            'total_on_hold': 0,
            'total_expired': 0,
        }

        # Calculate metrics accurately
        for c in CustomerStockCycle.objects.all():
            if c.service_status == 'hold':
                metrics['total_on_hold'] += 1
            elif c.computed_status == 'Expired':
                metrics['total_expired'] += 1
            elif c.computed_status == 'Active':
                metrics['total_active'] += 1
                if c.is_low_stock:
                    metrics['total_low_stock'] += 1

        for cycle in query:
            days_rem = cycle.days_remaining
            comp_status = cycle.computed_status
            is_low = cycle.is_low_stock

            if filter_type == 'low_stock' and not is_low:
                continue
            if filter_type == 'expiring_7_days' and not is_low:
                continue
            if filter_type == 'held' and cycle.service_status != 'hold':
                continue
            if filter_type == 'expired' and comp_status != 'Expired':
                continue
            if filter_type == 'active' and comp_status != 'Active':
                continue

            cust = cycle.customer
            prof = getattr(cust, 'profile', None)
            order = cycle.order
            sf = cycle.serving_franchise
            rf = cycle.registered_franchise

            # Hold logs
            hold_logs = [
                {
                    'action': h.action,
                    'actor_name': h.actor.get_full_name() or h.actor.username if h.actor else 'System',
                    'actor_role': h.actor_role,
                    'remaining_days': h.remaining_days,
                    'notes': h.notes,
                    'timestamp': h.created_at.strftime('%Y-%m-%d %H:%M'),
                }
                for h in cycle.hold_logs.all()[:5]
            ]

            stocks_data.append({
                'id': cycle.id,
                'customer_id': cust.id,
                'customer_name': cust.get_full_name() or (prof.name if prof else cust.username),
                'customer_phone': prof.phone if prof else '',
                'customer_email': cust.email,
                'order_id': order.id if order else None,
                'order_code': order.order_code if order else f"ORD-{cycle.id}",
                'order_date': order.order_date.isoformat() if order else cycle.start_date.isoformat(),
                'product_name': cycle.product_name or 'Pure Mineral Water',
                'variant_size': cycle.variant_size or 'Standard',
                'quantity': cycle.quantity,
                'duration_choice': cycle.duration_choice,
                'duration_days': cycle.duration_days,
                'start_date': cycle.start_date.isoformat(),
                'expected_end_date': cycle.expected_end_date.isoformat(),
                'days_remaining': days_rem,
                'service_status': cycle.service_status,
                'computed_status': comp_status,
                'is_low_stock': is_low,
                'serving_franchise_id': sf.id if sf else None,
                'serving_franchise_name': sf.business_name if sf else 'Shivnath Agency',
                'registered_franchise_id': rf.id if rf else None,
                'registered_franchise_name': rf.business_name if rf else 'Shivnath Agency',
                'district': cycle.district.name if cycle.district else '',
                'zone': cycle.zone.name if cycle.zone else '',
                'service_area': cycle.service_area.locality_name if cycle.service_area else '',
                'pincode': cycle.pincode,
                'hold_history': hold_logs,
                'created_at': cycle.created_at.strftime('%Y-%m-%d %H:%M'),
            })

        return Response({
            'success': True,
            'count': len(stocks_data),
            'metrics': metrics,
            'stocks': stocks_data,
        }, status=status.HTTP_200_OK)


class CustomerNotificationListView(APIView):
    """
    Customer in-app notification inbox.
    """
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]

    def get(self, request):
        from .models import CustomerNotification
        notifs = CustomerNotification.objects.filter(customer=request.user)[:50]
        unread = CustomerNotification.objects.filter(customer=request.user, is_read=False).count()

        data = [
            {
                'id': n.id,
                'title': n.title,
                'message': n.message,
                'notification_type': n.notification_type,
                'reference_id': n.reference_id,
                'is_read': n.is_read,
                'created_at': n.created_at.strftime('%Y-%m-%d %H:%M'),
            }
            for n in notifs
        ]

        return Response({
            'success': True,
            'unread_count': unread,
            'notifications': data,
        }, status=status.HTTP_200_OK)

    def post(self, request):
        from .models import CustomerNotification
        notif_id = request.data.get('id')
        if notif_id:
            CustomerNotification.objects.filter(customer=request.user, id=notif_id).update(is_read=True)
        else:
            CustomerNotification.objects.filter(customer=request.user, is_read=False).update(is_read=True)
        return Response({'success': True, 'message': 'Notifications marked as read.'})


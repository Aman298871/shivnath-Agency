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
from .permissions import IsAdminRole

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
        for u in users.distinct():
            prof = getattr(u, 'profile', None)
            fp = getattr(u, 'franchise_profile', None)
            role = prof.role if prof else ('admin' if u.is_superuser else 'customer')

            order_count = Order.objects.filter(created_by=u).count()

            item = {
                'id': u.id,
                'customer_code': f'CUST-{1000 + u.id}' if role == 'customer' else f'FRAN-{1000 + u.id}',
                'name': (prof.name if prof and prof.name else (u.get_full_name() or u.username)),
                'username': u.username,
                'email': u.email,
                'phone': prof.phone if prof else '',
                'city': (prof.city if prof and prof.city else (fp.city if fp else '')),
                'district': prof.district if prof else '',
                'address': (prof.address if prof and prof.address else (fp.address if fp else '')),
                'role': role,
                'status': prof.status if prof else ('active' if u.is_active else 'inactive'),
                'is_active': u.is_active,
                'order_count': order_count,
                'date_joined': u.date_joined.strftime('%Y-%m-%d %H:%M'),
            }

            if fp:
                item['franchise_details'] = {
                    'business_name': fp.business_name,
                    'status': fp.status,
                    'territory': fp.territory or 'Pending',
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
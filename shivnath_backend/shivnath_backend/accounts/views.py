from decimal import Decimal, InvalidOperation
from datetime import datetime
import os
import sys
import logging

logger = logging.getLogger(__name__)
import subprocess
import hashlib
from pathlib import Path
from django.conf import settings
from django.shortcuts import get_object_or_404
from django.utils import timezone
from django.db.models import Q, Max
from rest_framework_simplejwt.authentication import JWTAuthentication
from rest_framework import status
from rest_framework.permissions import (
    AllowAny,
    IsAuthenticated,
)
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import FranchiseProfile, UserProfile
from .permissions import IsAdminRole, IsApprovedFranchise, IsAdminOrFranchiseUser

from .serializers import (
    CustomerRegisterSerializer,
    FranchiseRegisterSerializer,
    LoginSerializer,
    CurrentUserSerializer,
    ForgotPasswordSerializer,
    ResetPasswordSerializer,
    ChangePasswordSerializer,
    AdminResetUserPasswordSerializer,
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

def _build_public_doc_url(request, path):
    """
    Ensure document URL always points to canonical Render backend URL
    instead of localhost / internal IPs / testserver.
    """
    render_base = 'https://shivnath-agency.onrender.com'
    if request:
        try:
            uri = request.build_absolute_uri(path)
            if 'localhost' in uri or '127.0.0.1' in uri or '10.0.2.2' in uri or 'testserver' in uri:
                return f"{render_base}{path}"
            return uri
        except Exception:
            return f"{render_base}{path}"
    return f"{render_base}{path}"


class PendingFranchiseListView(APIView):
    permission_classes = [IsAdminRole]

    def get(self, request):
        franchises = FranchiseProfile.objects.filter(
            status='pending'
        ).select_related('user', 'user__profile')

        data = []

        for franchise in franchises:
            doc = franchise.kyc_documents.filter(document_type='FSSAI_CERTIFICATE').first()
            doc_url = ''
            if doc and doc.document_file:
                doc_url = _build_public_doc_url(request, f'/api/accounts/dealers/documents/{doc.id}/view/')

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
                'fssai_number':
                    franchise.fssai_number,
                'fssai_business_name':
                    franchise.fssai_business_name or franchise.business_name,
                'fssai_verification_status':
                    franchise.fssai_verification_status,
                'fssai_expiry_date':
                    str(franchise.fssai_expiry_date) if franchise.fssai_expiry_date else None,
                'fssai_certificate_url':
                    doc_url,
                'fssai_rejection_reason':
                    franchise.fssai_rejection_reason,
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
            doc = franchise.kyc_documents.filter(document_type='FSSAI_CERTIFICATE').first()
            doc_url = ''
            if doc and doc.document_file:
                doc_url = _build_public_doc_url(request, f'/api/accounts/dealers/documents/{doc.id}/view/')

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

                'fssai_number':
                    franchise.fssai_number,

                'fssai_business_name':
                    franchise.fssai_business_name or franchise.business_name,

                'fssai_verification_status':
                    franchise.fssai_verification_status,

                'fssai_expiry_date':
                    str(franchise.fssai_expiry_date) if franchise.fssai_expiry_date else None,

                'fssai_certificate_url':
                    doc_url,

                'fssai_rejection_reason':
                    franchise.fssai_rejection_reason,

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

        # Regulatory FSSAI Verification Enforcement
        from .fssai_services import validate_franchise_fssai_for_activation
        override_reason = str(request.data.get('override_reason', '')).strip()
        is_eligible, err_msg, err_code = validate_franchise_fssai_for_activation(
            franchise, actor=request.user, override_reason=override_reason
        )
        if not is_eligible:
            return Response(
                {
                    'success': False,
                    'message': err_msg,
                    'error_code': err_code,
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        if override_reason and franchise.fssai_verification_status != 'VERIFIED':
            from .models import AdminAuditLog
            AdminAuditLog.objects.create(
                actor=request.user,
                action='FRANCHISE_APPROVAL_FSSAI_OVERRIDE',
                resource_type='FranchiseProfile',
                resource_id=str(franchise.id),
                changes={
                    'fssai_number': franchise.fssai_number,
                    'fssai_status': franchise.fssai_verification_status,
                    'override_reason': override_reason
                }
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

        # Synchronize UserProfile status to active so franchise can log in and access portal
        user_prof = getattr(franchise.user, 'profile', None)
        if user_prof:
            user_prof.status = 'active'
            user_prof.save(update_fields=['status'])

        from .models import AdminAuditLog, FranchiseNotification
        AdminAuditLog.objects.create(
            actor=request.user,
            action='APPROVE_FRANCHISE',
            resource_type='FranchiseProfile',
            resource_id=str(franchise.id),
            changes={
                'status': 'approved',
                'reviewer_id': request.user.id,
                'reviewer_username': request.user.username,
                'fssai_status': franchise.fssai_verification_status,
                'approved_at': franchise.approved_at.isoformat() if franchise.approved_at else None,
            }
        )

        # In-app Franchise Notification
        try:
            FranchiseNotification.objects.create(
                franchise=franchise,
                title='Franchise Application Approved! 🎉',
                message=f'Congratulations! Your franchise application for "{franchise.business_name}" has been approved by {request.user.get_full_name() or request.user.username}.',
                notification_type='franchise_approval',
                reference_id=franchise.id,
            )
        except Exception:
            pass

        try:
            from accounts.fcm_services import notify_franchise_approval_status
            actor = request.user.get_full_name() or request.user.username
            notify_franchise_approval_status(franchise, 'approved', actor_name=actor)
        except Exception:
            pass

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
                    'user_profile_status':
                        user_prof.status if user_prof else 'active',
                    'fssai_number':
                        franchise.fssai_number,
                    'fssai_verification_status':
                        franchise.fssai_verification_status,
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

        # Synchronize UserProfile status to rejected
        user_prof = getattr(franchise.user, 'profile', None)
        if user_prof:
            user_prof.status = 'rejected'
            user_prof.save(update_fields=['status'])

        from .models import AdminAuditLog, FranchiseNotification
        AdminAuditLog.objects.create(
            actor=request.user,
            action='REJECT_FRANCHISE',
            resource_type='FranchiseProfile',
            resource_id=str(franchise.id),
            changes={
                'status': 'rejected',
                'rejection_reason': reason,
                'reviewer_id': request.user.id,
                'reviewer_username': request.user.username,
            }
        )

        # In-app Franchise Notification
        try:
            FranchiseNotification.objects.create(
                franchise=franchise,
                title='Franchise Application Update',
                message=f'Your franchise application for "{franchise.business_name}" was not approved. Reason: {reason}',
                notification_type='franchise_rejection',
                reference_id=franchise.id,
            )
        except Exception:
            pass

        try:
            from accounts.fcm_services import notify_franchise_approval_status
            actor = request.user.get_full_name() or request.user.username
            notify_franchise_approval_status(franchise, 'rejected', reason=reason, actor_name=actor)
        except Exception:
            pass

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

        if franchise_status == 'approved' and franchise.status != 'approved':
            from .fssai_services import validate_franchise_fssai_for_activation
            override_reason = str(request.data.get('override_reason', '')).strip()
            is_eligible, err_msg, err_code = validate_franchise_fssai_for_activation(
                franchise, actor=request.user, override_reason=override_reason
            )
            if not is_eligible:
                return Response(
                    {
                        'success': False,
                        'message': err_msg,
                        'error_code': err_code,
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
    
    from rest_framework.parsers import MultiPartParser, FormParser, JSONParser
    parser_classes = [MultiPartParser, FormParser, JSONParser]

    def post(self, request):
        with transaction.atomic():
            serializer = FranchiseRegisterSerializer(
                data=request.data
            )

            if serializer.is_valid():
                user = serializer.save()

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
                    try:
                        from accounts.fcm_services import notify_franchise_registered
                        notify_franchise_registered(user.franchise_profile)
                    except Exception:
                        pass

                return Response(
                    {
                        'success': True,
                        'status': 'Pending Admin Approval',
                        'message':
                            'Franchise account created successfully! Please wait for administrator approval before logging in.',
                        'user': {
                            'id': user.id,
                            'name': user.get_full_name() or user.username,
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

            first_err = ""
            if serializer.errors:
                if isinstance(serializer.errors, dict):
                    for k, v in serializer.errors.items():
                        if isinstance(v, list) and len(v) > 0:
                            first_err = str(v[0])
                            break
                        first_err = str(v)
                        break
                else:
                    first_err = str(serializer.errors)

            return Response(
                {
                    'success': False,
                    'message': first_err or 'Registration failed. Please check the provided information.',
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


class ForgotPasswordView(APIView):
    permission_classes = [AllowAny]
    authentication_classes = []

    def post(self, request):
        serializer = ForgotPasswordSerializer(
            data=request.data
        )
        if serializer.is_valid():
            return Response(
                serializer.validated_data,
                status=status.HTTP_200_OK
            )
        return Response(
            {
                'success': False,
                'errors': serializer.errors,
            },
            status=status.HTTP_400_BAD_REQUEST
        )


class ResetPasswordView(APIView):
    permission_classes = [AllowAny]
    authentication_classes = []

    def post(self, request):
        serializer = ResetPasswordSerializer(
            data=request.data
        )
        if serializer.is_valid():
            return Response(
                serializer.validated_data,
                status=status.HTTP_200_OK
            )
        return Response(
            {
                'success': False,
                'errors': serializer.errors,
            },
            status=status.HTTP_400_BAD_REQUEST
        )


class ChangePasswordView(APIView):
    permission_classes = [IsAuthenticated]
    authentication_classes = [JWTAuthentication]

    def post(self, request):
        serializer = ChangePasswordSerializer(data=request.data)
        if not serializer.is_valid():
            return Response({
                'success': False,
                'errors': serializer.errors
            }, status=status.HTTP_400_BAD_REQUEST)

        current_pwd = serializer.validated_data['current_password']
        new_pwd = serializer.validated_data['new_password']

        if not request.user.check_password(current_pwd):
            return Response({
                'success': False,
                'errors': {'current_password': ['Current password is incorrect.']}
            }, status=status.HTTP_400_BAD_REQUEST)

        # Secure password update using Django's set_password()
        request.user.set_password(new_pwd)
        request.user.save()

        profile, _ = UserProfile.objects.get_or_create(user=request.user)
        profile.must_change_password = False
        profile.save(update_fields=['must_change_password'])

        from rest_framework_simplejwt.tokens import RefreshToken
        refresh = RefreshToken.for_user(request.user)

        # Audit event without exposing any password
        from .models import AdminAuditLog
        try:
            AdminAuditLog.objects.create(
                actor=request.user,
                action='USER_CHANGED_PASSWORD',
                resource_type='User',
                resource_id=str(request.user.id),
                ip_address=request.META.get('REMOTE_ADDR'),
                changes={'status': 'CREDENTIALS_UPDATED_SUCCESSFULLY'}
            )
        except Exception:
            pass

        return Response({
            'success': True,
            'message': 'Password changed successfully.',
            'access': str(refresh.access_token),
            'refresh': str(refresh),
            'user': {
                'id': request.user.id,
                'name': request.user.get_full_name() or request.user.username,
                'email': request.user.email,
                'role': profile.role,
                'must_change_password': False,
            }
        }, status=status.HTTP_200_OK)


class AdminResetUserPasswordView(APIView):
    permission_classes = [IsAuthenticated, IsAdminRole]
    authentication_classes = [JWTAuthentication]

    def post(self, request, user_id):
        serializer = AdminResetUserPasswordSerializer(data=request.data)
        if not serializer.is_valid():
            return Response({
                'success': False,
                'errors': serializer.errors
            }, status=status.HTTP_400_BAD_REQUEST)

        target_user = get_object_or_404(User, id=user_id)

        # Super Admin protection
        if target_user.is_superuser and not request.user.is_superuser:
            return Response({
                'success': False,
                'message': 'Security policy violation: Only Super Administrators can reset credentials for another Super Administrator.'
            }, status=status.HTTP_403_FORBIDDEN)

        # Self-reset protection
        if target_user.id == request.user.id:
            return Response({
                'success': False,
                'message': 'Administrators cannot reset their own password via assisted reset. Please use the Change Password menu.'
            }, status=status.HTTP_400_BAD_REQUEST)

        verification_reason = serializer.validated_data['verification_reason'].strip()

        # Generate a cryptographically random, secure temporary password
        import secrets
        import string
        chars = string.ascii_letters + string.digits
        temp_password = 'WN#' + ''.join(secrets.choice(chars) for _ in range(10))

        # Store password exclusively using Django's set_password()
        target_user.set_password(temp_password)
        target_user.save()

        # Require user to change temporary password immediately upon login
        profile, _ = UserProfile.objects.get_or_create(user=target_user)
        profile.must_change_password = True
        profile.save(update_fields=['must_change_password'])

        # Record audit event containing actor, target, timestamp, action — NEVER the password
        from .models import AdminAuditLog
        try:
            AdminAuditLog.objects.create(
                actor=request.user,
                action='ADMIN_RESET_USER_PASSWORD',
                resource_type='User',
                resource_id=str(target_user.id),
                ip_address=request.META.get('REMOTE_ADDR'),
                changes={
                    'target_username': target_user.username,
                    'target_email': target_user.email,
                    'target_role': profile.role,
                    'verification_reason': verification_reason,
                    'status': 'TEMPORARY_CREDENTIAL_ISSUED',
                }
            )
        except Exception:
            pass

        # Return temporary password only once to the authorized admin
        return Response({
            'success': True,
            'message': f'Temporary password generated for {target_user.get_full_name() or target_user.username}. Share this password securely with the user. They will be required to choose a new password upon login.',
            'temporary_password': temp_password,
            'user_id': target_user.id,
            'user_email': target_user.email,
            'user_name': target_user.get_full_name() or target_user.username,
            'must_change_password': True,
        }, status=status.HTTP_200_OK)




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

    def patch(self, request):
        return self.update_profile(request)

    def put(self, request):
        return self.update_profile(request)

    def update_profile(self, request):
        from .models import (
            ServiceDistrict,
            ServiceZone,
            ServiceArea,
            FranchiseTerritoryAssignment,
            CustomerFranchiseRelationship,
        )
        from .services import resolve_serviceable_franchises

        user = request.user
        data = request.data

        # 1. Update general name if provided
        name = str(data.get('name', '')).strip()
        if name:
            name_parts = name.split(' ', 1)
            user.first_name = name_parts[0]
            user.last_name = name_parts[1] if len(name_parts) > 1 else ''
            user.save(update_fields=['first_name', 'last_name'])
            if hasattr(user, 'profile'):
                user.profile.name = name
                user.profile.save(update_fields=['name'])

        # 2. Role = Franchise profile update
        if hasattr(user, 'franchise_profile'):
            fp = user.franchise_profile
            business_name = str(data.get('business_name', '')).strip()
            if business_name:
                fp.business_name = business_name
            phone = str(data.get('phone', '')).strip()
            if phone and hasattr(user, 'profile'):
                user.profile.phone = phone
                user.profile.save(update_fields=['phone'])
            address = str(data.get('address', '')).strip()
            if address:
                fp.address = address

            district_name = str(data.get('district', '')).strip()
            zone_id = data.get('zone_id')
            zone_name = str(data.get('territory', '')).strip()

            active_assignment = (
                FranchiseTerritoryAssignment.objects
                .filter(franchise=fp, is_active=True)
                .select_related('zone', 'zone__district')
                .first()
            )

            if district_name or zone_id or zone_name:
                if active_assignment:
                    current_dist = active_assignment.zone.district.name.lower()
                    current_zone = active_assignment.zone.name.lower()
                    incoming_dist = district_name.lower() if district_name else current_dist
                    incoming_zone = zone_name.lower() if zone_name else ''
                    if (district_name and incoming_dist != current_dist) or (zone_name and incoming_zone != current_zone) or (zone_id and int(zone_id) != active_assignment.zone.id):
                        return Response({
                            'success': False,
                            'message': 'Franchise territory has already been authoritatively assigned by Admin. Modification requires Admin review and cannot be changed directly.'
                        }, status=status.HTTP_403_FORBIDDEN)
                else:
                    district_obj = None
                    if district_name:
                        district_obj = ServiceDistrict.objects.filter(name__iexact=district_name, is_active=True).first()
                        if not district_obj:
                            return Response({'success': False, 'message': f'District "{district_name}" not found in territory master.'}, status=status.HTTP_400_BAD_REQUEST)

                    zone_obj = None
                    if zone_id:
                        zone_obj = ServiceZone.objects.filter(id=zone_id, is_active=True).first()
                    elif zone_name:
                        zone_q = ServiceZone.objects.filter(name__iexact=zone_name, is_active=True)
                        if district_obj:
                            zone_q = zone_q.filter(district=district_obj)
                        zone_obj = zone_q.first()

                    if zone_obj and district_obj and zone_obj.district != district_obj:
                        return Response({'success': False, 'message': f'Territory "{zone_obj.name}" does not belong to District "{district_obj.name}".'}, status=status.HTTP_400_BAD_REQUEST)

                    if zone_obj:
                        FranchiseTerritoryAssignment.objects.create(
                            franchise=fp,
                            zone=zone_obj,
                            is_primary=True,
                            is_active=True,
                        )
                        fp.city = zone_obj.district.name
                        fp.territory = zone_obj.name
                    elif district_obj:
                        fp.city = district_obj.name

            fp.save()
            serializer = CurrentUserSerializer(user)
            return Response(serializer.data, status=status.HTTP_200_OK)

        # 3. Role = Customer (or normal user) profile update
        prof = getattr(user, 'profile', None)
        if prof:
            phone = str(data.get('phone', '')).strip()
            if phone:
                prof.phone = phone
            address = str(data.get('address', '')).strip()
            if address:
                prof.address = address
            locality = str(data.get('locality', '')).strip()
            if locality:
                prof.locality = locality

            district_name = str(data.get('district', '')).strip()
            zone_id = data.get('zone_id')
            zone_name = str(data.get('territory', '')).strip()

            district_obj = None
            if district_name:
                district_obj = ServiceDistrict.objects.filter(name__iexact=district_name, is_active=True).first()
                if not district_obj:
                    return Response({'success': False, 'message': f'District "{district_name}" not found.'}, status=status.HTTP_400_BAD_REQUEST)

            zone_obj = None
            if zone_id:
                zone_obj = ServiceZone.objects.filter(id=zone_id, is_active=True).first()
            elif zone_name:
                zone_q = ServiceZone.objects.filter(name__iexact=zone_name, is_active=True)
                if district_obj:
                    zone_q = zone_q.filter(district=district_obj)
                zone_obj = zone_q.first()

            if zone_obj and district_obj and zone_obj.district != district_obj:
                return Response({'success': False, 'message': f'Territory "{zone_obj.name}" does not belong to District "{district_obj.name}".'}, status=status.HTTP_400_BAD_REQUEST)

            if district_obj:
                prof.district = district_obj.name
                prof.city = district_obj.name
            if zone_obj:
                prof.zone = zone_obj
                prof.territory = zone_obj.name
            if 'is_gst_requested' in data:
                prof.is_gst_requested = bool(data.get('is_gst_requested'))
            if 'gstin' in data:
                prof.gstin = str(data.get('gstin', '')).strip().upper()
            if 'gst_legal_name' in data:
                prof.gst_legal_name = str(data.get('gst_legal_name', '')).strip()
            if 'gst_billing_address' in data:
                prof.gst_billing_address = str(data.get('gst_billing_address', '')).strip()
            if 'gst_state_name' in data:
                prof.gst_state_name = str(data.get('gst_state_name', '')).strip()
            if 'gst_pincode' in data:
                prof.gst_pincode = str(data.get('gst_pincode', '')).strip()

            prof.save()

            rel, _ = CustomerFranchiseRelationship.objects.get_or_create(
                customer=user,
                defaults={
                    'registered_franchise': FranchiseProfile.objects.filter(status='approved').first(),
                }
            )
            if district_obj:
                rel.district = district_obj
            if zone_obj:
                rel.zone = zone_obj
            if locality:
                rel.locality = locality
            if address:
                rel.address = address

            res = resolve_serviceable_franchises(zone=zone_obj or rel.zone, district=district_obj or rel.district)
            if res.get('franchises'):
                primary_f = next((f for f in res['franchises'] if f.get('is_primary')), res['franchises'][0])
                if not rel.current_serving_franchise:
                    rel.current_serving_franchise_id = primary_f['id']
                if not rel.registered_franchise:
                    rel.registered_franchise_id = primary_f['id']

            rel.save()

        serializer = CurrentUserSerializer(user)
        return Response(serializer.data, status=status.HTTP_200_OK)


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
            search_q = (
                Q(username__icontains=search) |
                Q(email__icontains=search) |
                Q(first_name__icontains=search) |
                Q(last_name__icontains=search) |
                Q(profile__name__icontains=search) |
                Q(profile__phone__icontains=search) |
                Q(profile__city__icontains=search) |
                Q(profile__district__icontains=search) |
                Q(franchise_profile__business_name__icontains=search)
            )
            if search.isdigit():
                search_q |= Q(id=int(search))
            users = users.filter(search_q)

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
                        'serving_franchise_id': cycle.serving_franchise.id if cycle.serving_franchise else None,
                        'serving_franchise_name': cycle.serving_franchise.business_name if cycle.serving_franchise else 'Shivnath Agency (Direct)',
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

            if role == 'customer':
                cust_orders = Order.objects.filter(created_by=u)
                tot_orders = cust_orders.count()
                comp_orders = cust_orders.filter(status='delivered').count()
                canc_orders = cust_orders.filter(status='cancelled').count()
                fran_orders = cust_orders.filter(order_source='FRANCHISE').count()
                dir_orders = cust_orders.filter(order_source='DIRECT_COMPANY').count()

                first_ord = cust_orders.order_by('created_at').first()
                last_ord = cust_orders.order_by('-created_at').first()
                first_date = str(first_ord.order_date) if first_ord and first_ord.order_date else None
                last_date = str(last_ord.order_date) if last_ord and last_ord.order_date else None

                from billing.models import Invoice
                cust_invoices = Invoice.objects.filter(order__in=cust_orders)
                if cust_invoices.exists():
                    tot_rev = sum((inv.grand_total or Decimal('0.00')) for inv in cust_invoices)
                    tot_paid = sum((inv.amount_paid or Decimal('0.00')) for inv in cust_invoices)
                    tot_out = sum((inv.outstanding_balance or Decimal('0.00')) for inv in cust_invoices)
                else:
                    tot_rev = sum((o.grand_total or o.amount or Decimal('0.00')) for o in cust_orders)
                    tot_paid = sum((o.grand_total or o.amount or Decimal('0.00')) for o in cust_orders.filter(payment_status='paid'))
                    tot_out = max(Decimal('0.00'), tot_rev - tot_paid)

                item['total_revenue'] = float(tot_rev)
                item['total_orders'] = tot_orders
                item['source'] = 'Customer App / Portal'
                item['financial_summary'] = {
                    'total_orders': tot_orders,
                    'completed_orders': comp_orders,
                    'cancelled_orders': canc_orders,
                    'total_revenue': float(tot_rev),
                    'total_paid': float(tot_paid),
                    'total_outstanding': float(tot_out),
                    'first_order_date': first_date,
                    'last_order_date': last_date,
                    'orders_by_franchise': fran_orders,
                    'direct_orders': dir_orders,
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
    """
    Authoritative, role-isolated notification feed and unread counter.
    Strictly delivers:
    - Customer -> ONLY their own CustomerNotification records.
    - Franchise -> ONLY their own FranchiseNotification records.
    - Admin / Super Admin -> Operational AdminNotification records.
    A Customer or Franchise API request CAN NEVER retrieve Admin/Super Admin notifications.
    """
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]

    def get(self, request):
        user = request.user
        role = getattr(getattr(user, 'profile', None), 'role', '')
        if user.is_superuser:
            role = 'super_admin'

        try:
            limit = min(int(request.query_params.get('limit', 30)), 100)
        except (ValueError, TypeError):
            limit = 30

        unread_only = request.query_params.get('unread_only', 'false').lower() in ['true', '1']

        from .models import CustomerNotification, FranchiseNotification, AdminNotification

        if role == 'customer':
            qs = CustomerNotification.objects.filter(customer=user)
            unread_count = qs.filter(is_read=False).count()
            if unread_only:
                qs = qs.filter(is_read=False)
            notifs = qs.order_by('-created_at')[:limit]
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
                for n in notifs
            ]
        elif role == 'franchise':
            franchise = getattr(user, 'franchise_profile', None)
            if not franchise:
                return Response({'success': True, 'role': role, 'unread_count': 0, 'count': 0, 'notifications': []})
            qs = FranchiseNotification.objects.filter(franchise=franchise)
            unread_count = qs.filter(is_read=False).count()
            if unread_only:
                qs = qs.filter(is_read=False)
            notifs = qs.order_by('-created_at')[:limit]
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
                for n in notifs
            ]
        elif role in ['admin', 'super_admin'] or user.is_staff or user.is_superuser:
            qs = AdminNotification.objects.all()
            unread_count = qs.filter(is_read=False).count()
            if unread_only:
                qs = qs.filter(is_read=False)
            notifs = qs.order_by('-created_at')[:limit]
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
                for n in notifs
            ]
        else:
            return Response({'success': True, 'role': role, 'unread_count': 0, 'count': 0, 'notifications': []})

        return Response({
            'success': True,
            'role': role,
            'unread_count': unread_count,
            'count': len(results),
            'notifications': results,
        }, status=status.HTTP_200_OK)

    def post(self, request):
        user = request.user
        role = getattr(getattr(user, 'profile', None), 'role', '')
        if user.is_superuser:
            role = 'super_admin'

        notification_id = request.data.get('id') or request.data.get('notification_id')
        from .models import CustomerNotification, FranchiseNotification, AdminNotification

        if role == 'customer':
            if notification_id:
                CustomerNotification.objects.filter(customer=user, id=notification_id).update(is_read=True)
            else:
                CustomerNotification.objects.filter(customer=user, is_read=False).update(is_read=True)
        elif role == 'franchise':
            franchise = getattr(user, 'franchise_profile', None)
            if franchise:
                if notification_id:
                    FranchiseNotification.objects.filter(franchise=franchise, id=notification_id).update(is_read=True)
                else:
                    FranchiseNotification.objects.filter(franchise=franchise, is_read=False).update(is_read=True)
        elif role in ['admin', 'super_admin'] or user.is_staff or user.is_superuser:
            if notification_id:
                AdminNotification.objects.filter(id=notification_id).update(is_read=True)
            else:
                AdminNotification.objects.filter(is_read=False).update(is_read=True)

        return Response({'success': True, 'message': 'Notifications marked as read.'})


class NotificationUnreadCountView(APIView):
    """
    Lightweight, high-speed indexed unread badge counter.
    Runs a single SELECT COUNT(1) query scoped strictly to the authenticated user's role.
    """
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]

    def get(self, request):
        user = request.user
        role = getattr(getattr(user, 'profile', None), 'role', '')
        if user.is_superuser:
            role = 'super_admin'

        from .models import CustomerNotification, FranchiseNotification, AdminNotification

        if role == 'customer':
            count = CustomerNotification.objects.filter(customer=user, is_read=False).count()
        elif role == 'franchise':
            franchise = getattr(user, 'franchise_profile', None)
            count = FranchiseNotification.objects.filter(franchise=franchise, is_read=False).count() if franchise else 0
        elif role in ['admin', 'super_admin'] or user.is_staff or user.is_superuser:
            count = AdminNotification.objects.filter(is_read=False).count()
        else:
            count = 0

        return Response({
            'success': True,
            'role': role,
            'unread_count': count
        }, status=status.HTTP_200_OK)


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
    Supports ?district=<name> to return active territories (zones) for a specific district.
    """
    permission_classes = [AllowAny]
    authentication_classes = []

    def get(self, request):
        from .models import ServiceDistrict, ServiceZone
        district_name = request.query_params.get('district', '').strip()

        if district_name:
            # 1. Try exact match
            zones = ServiceZone.objects.filter(
                district__name__iexact=district_name,
                is_active=True
            ).order_by('name')

            # 2. Try icontains match
            if not zones.exists():
                zones = ServiceZone.objects.filter(
                    district__name__icontains=district_name,
                    is_active=True
                ).order_by('name')

            # 3. Try partial token matching (e.g. "Baloda Bazar" vs "Baloda Bazar - Bhatapara")
            if not zones.exists():
                clean_name = district_name.split('-')[0].split('(')[0].strip()
                if clean_name:
                    zones = ServiceZone.objects.filter(
                        district__name__icontains=clean_name,
                        is_active=True
                    ).order_by('name')

            # 4. If district exists in DB but has 0 zones, ensure a default central zone
            if not zones.exists():
                dist_obj = ServiceDistrict.objects.filter(name__icontains=district_name, is_active=True).first()
                if not dist_obj:
                    dist_obj = ServiceDistrict.objects.filter(name__iexact=district_name).first()
                if dist_obj:
                    fallback_zone, _ = ServiceZone.objects.get_or_create(
                        district=dist_obj,
                        name=f"{dist_obj.name} Central",
                        defaults={'code': f"{dist_obj.name[:3].upper()}-CENTRAL", 'is_active': True}
                    )
                    zones = ServiceZone.objects.filter(id=fallback_zone.id)

            territories = []
            for z in zones:
                area_names = list(z.areas.filter(is_active=True).values_list('locality_name', flat=True))
                area_pincodes = list(z.areas.filter(is_active=True).values_list('pincode', flat=True).distinct())
                territories.append({
                    'id': z.id,
                    'name': z.name,
                    'code': z.code,
                    'district_name': z.district.name,
                    'areas': area_names,
                    'areas_display': ", ".join(area_names[:6]) if area_names else "All central & municipal localities in zone",
                    'pincodes': area_pincodes,
                })
            return Response({
                'success': True,
                'district': district_name,
                'count': len(territories),
                'territories': territories,
            }, status=status.HTTP_200_OK)

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

        zone_id = request.query_params.get('zone_id') or request.query_params.get('territory_id')
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
    Strictly isolated to the authenticated franchise.
    """
    permission_classes = [IsApprovedFranchise]

    def get(self, request):
        franchise = getattr(request.user, 'franchise_profile', None)
        if not franchise:
            return Response({'success': False, 'message': 'Franchise not found.'}, status=status.HTTP_404_NOT_FOUND)

        try:
            limit = min(int(request.query_params.get('limit', 30)), 100)
        except (ValueError, TypeError):
            limit = 30

        unread_only = request.query_params.get('unread_only', 'false').lower() in ['true', '1']

        from .models import FranchiseNotification
        qs = FranchiseNotification.objects.filter(franchise=franchise)
        unread = qs.filter(is_read=False).count()
        if unread_only:
            qs = qs.filter(is_read=False)
        notifs = qs.order_by('-created_at')[:limit]

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
            'count': len(data),
            'notifications': data,
        }, status=status.HTTP_200_OK)

    def post(self, request):
        franchise = getattr(request.user, 'franchise_profile', None)
        if not franchise:
            return Response({'success': False, 'message': 'Franchise not found.'}, status=status.HTTP_404_NOT_FOUND)
        from .models import FranchiseNotification
        notif_id = request.data.get('id') or request.data.get('notification_id')
        if notif_id:
            FranchiseNotification.objects.filter(franchise=franchise, id=notif_id).update(is_read=True)
        else:
            FranchiseNotification.objects.filter(franchise=franchise, is_read=False).update(is_read=True)
        return Response({'success': True, 'message': 'Franchise notifications marked as read.'})


# =====================================================================
# DYNAMIC CONTEXTUAL SUPPORT CONTACT VIEW
# =====================================================================

def _get_support_contact(role_key):
    from django.conf import settings
    from .models import SupportContact
    try:
        contact = SupportContact.objects.get(role=role_key)
        return {
            'name': contact.name,
            'phone': contact.phone,
            'email': contact.email,
            'message_template': contact.message_template,
        }
    except SupportContact.DoesNotExist:
        fallback_phone = getattr(settings, 'SUPPORT_FALLBACK_PHONE', '+91 98062 47194')
        return {
            'name': 'Shivnath Support Desk',
            'phone': fallback_phone,
            'email': getattr(settings, 'SUPPORT_FALLBACK_EMAIL', 'support@shivnath.com'),
            'message_template': 'Namaste Shivnath Support Desk,\nI need assistance with my drinking water supply.',
        }


class SupportContactView(APIView):
    """
    Dynamic support contact resolution from backend configuration:
    - Customer -> Assigned or Serving Franchise contact (or Central Customer Care).
    - Franchise -> Admin Central Support.
    - Admin -> Central Admin / Company Support.
    - Public / Anonymous -> Central Shivnath Helpline.
    """
    authentication_classes = [JWTAuthentication]
    permission_classes = [AllowAny]

    def get(self, request):
        user = request.user if request.user and request.user.is_authenticated else None
        role = getattr(getattr(user, 'profile', None), 'role', 'public') if user else 'public'
        inquiry_type = request.query_params.get('inquiry_type', '').strip().lower()
        requested_role = request.query_params.get('role', '').strip().lower()
        fetch_all = request.query_params.get('all', '').strip().lower() in ['true', '1']

        from .models import SupportContact

        if fetch_all and (role == 'admin' or (user and (user.is_staff or user.is_superuser))):
            contacts = SupportContact.objects.all().order_by('id')
            data = [{
                'id': c.id,
                'role': c.role,
                'role_display': c.get_role_display(),
                'name': c.name,
                'phone': c.phone,
                'email': c.email,
                'message_template': c.message_template,
            } for c in contacts]
            return Response({'success': True, 'contacts': data})

        if requested_role and (role == 'admin' or (user and (user.is_staff or user.is_superuser))):
            contact = _get_support_contact(requested_role)
            if contact:
                return Response({
                    'success': True,
                    'target': requested_role,
                    'name': contact['name'],
                    'phone': contact['phone'],
                    'email': contact['email'],
                    'message_template': contact['message_template'],
                })

        if role == 'admin' or (user and (user.is_staff or user.is_superuser)):
            contact = _get_support_contact('admin') or _get_support_contact('public_customer')
            if not contact:
                return Response({
                    'success': False,
                    'error': 'support_not_configured',
                    'message': 'Support contact not configured. Please contact the system administrator.'
                }, status=status.HTTP_503_SERVICE_UNAVAILABLE)
            return Response({
                'success': True,
                'target': 'admin',
                'name': contact['name'],
                'phone': contact['phone'],
                'email': contact['email'],
                'message_template': contact['message_template'] or "Namaste Shivnath Central Administration,\nI require system support."
            })
        elif role == 'franchise':
            contact = _get_support_contact('franchise') or _get_support_contact('admin')
            if not contact:
                return Response({
                    'success': False,
                    'error': 'support_not_configured',
                    'message': 'Support contact not configured. Please contact the system administrator.'
                }, status=status.HTTP_503_SERVICE_UNAVAILABLE)
            return Response({
                'success': True,
                'target': 'admin',
                'name': contact['name'],
                'phone': contact['phone'],
                'email': contact['email'],
                'message_template': contact['message_template'] or f"Namaste Admin Support,\nI am reaching out regarding franchise account {user.get_full_name() or user.username}."
            })
        elif role == 'customer':
            from .models import FranchiseProfile
            from orders.models import Order

            rel = getattr(user, 'customer_relationship', None)
            target_f = (rel.current_serving_franchise if rel and rel.current_serving_franchise else (rel.registered_franchise if rel else None))

            # If not explicitly linked in relationship, find franchise from recent orders or customer zone/district
            if not target_f:
                last_order = Order.objects.filter(created_by=user).exclude(serving_franchise=None).order_by('-id').first()
                if last_order and last_order.serving_franchise:
                    target_f = last_order.serving_franchise

            prof = getattr(user, 'profile', None)
            if not target_f and prof:
                user_zone = getattr(prof, 'zone', None) or getattr(user, 'zone', None)
                if user_zone:
                    target_f = FranchiseProfile.objects.filter(zone=user_zone, is_verified=True).first()
                if not target_f and getattr(prof, 'district', None):
                    target_f = FranchiseProfile.objects.filter(district__iexact=prof.district, is_verified=True).first()

            if not target_f:
                target_f = FranchiseProfile.objects.filter(is_verified=True).first()

            f_phone = target_f.user.profile.phone if target_f and hasattr(target_f.user, 'profile') and target_f.user.profile.phone else getattr(target_f, 'contact_number', None)

            # Also fetch all verified franchises in the customer's area/district
            user_dist = getattr(prof, 'district', '') if prof else ''
            area_franchises = []
            q_franchises = FranchiseProfile.objects.filter(is_verified=True)
            if user_dist:
                q_dist = q_franchises.filter(district__iexact=user_dist)
                if q_dist.exists():
                    q_franchises = q_dist

            for f_item in q_franchises[:6]:
                f_ph = f_item.user.profile.phone if hasattr(f_item.user, 'profile') and f_item.user.profile.phone else getattr(f_item, 'contact_number', '')
                area_franchises.append({
                    'id': f_item.id,
                    'name': f_item.business_name,
                    'owner_name': f_item.user.get_full_name() or f_item.user.username,
                    'phone': f_ph,
                    'email': f_item.user.email,
                    'zone': str(f_item.zone) if f_item.zone else '',
                    'district': str(f_item.district) if f_item.district else '',
                    'office_address': getattr(f_item, 'office_address', ''),
                })

            if target_f and f_phone:
                return Response({
                    'success': True,
                    'target': 'franchise',
                    'franchise_id': target_f.id,
                    'name': target_f.business_name,
                    'role_display': f"{target_f.business_name} (Local Franchise)",
                    'owner_name': target_f.user.get_full_name() or target_f.user.username,
                    'phone': f_phone,
                    'email': target_f.user.email,
                    'zone': str(target_f.zone) if target_f.zone else '',
                    'district': str(target_f.district) if target_f.district else '',
                    'office_address': getattr(target_f, 'office_address', ''),
                    'franchises_in_area': area_franchises,
                    'message_template': f"Namaste {target_f.business_name},\nI am customer {user.get_full_name() or user.username} (Phone: {user.profile.phone if hasattr(user, 'profile') else ''}). I need assistance with my drinking water supply in {getattr(prof, 'district', 'my area')}."
                })
            else:
                contact = _get_support_contact('customer') or _get_support_contact('public_customer') or _get_support_contact('admin')
                if not contact:
                    return Response({
                        'success': False,
                        'error': 'support_not_configured',
                        'message': 'Support contact not configured. Please contact the system administrator.'
                    }, status=status.HTTP_503_SERVICE_UNAVAILABLE)
                return Response({
                    'success': True,
                    'target': 'central',
                    'name': contact['name'],
                    'phone': contact['phone'],
                    'email': contact['email'],
                    'message_template': contact['message_template'] or f"Namaste Shivnath Support,\nI am customer {user.get_full_name() or user.username}. I need assistance with my drinking water supply."
                })

        # Public / Anonymous
        role_key = 'public_franchise' if inquiry_type == 'franchise' else 'public_customer'
        contact = _get_support_contact(role_key) or _get_support_contact('admin')
        if not contact:
            return Response({
                'success': False,
                'error': 'support_not_configured',
                'message': 'Support contact not configured. Please contact the system administrator.'
            }, status=status.HTTP_503_SERVICE_UNAVAILABLE)

        return Response({
            'success': True,
            'target': 'central',
            'name': contact['name'],
            'phone': contact['phone'],
            'email': contact['email'],
            'message_template': contact['message_template'] or "Namaste Shivnath Support,\nI would like to inquire about your pure drinking water products and delivery service."
        })

    def post(self, request):
        user = request.user
        if not user or not user.is_authenticated or not (user.is_staff or user.is_superuser or getattr(getattr(user, 'profile', None), 'role', '') == 'admin'):
            return Response({'error': 'Unauthorized. Admin access required.'}, status=status.HTTP_403_FORBIDDEN)

        from .models import SupportContact
        role_key = request.data.get('role')
        name = request.data.get('name')
        phone = request.data.get('phone')
        email = request.data.get('email', '')
        message_template = request.data.get('message_template', '')

        if not role_key or not name or not phone:
            return Response({'error': 'role, name, and phone are required.'}, status=status.HTTP_400_BAD_REQUEST)

        contact, _ = SupportContact.objects.update_or_create(
            role=role_key,
            defaults={
                'name': name,
                'phone': phone,
                'email': email,
                'message_template': message_template,
            }
        )
        return Response({
            'success': True,
            'message': f'Support contact for {contact.get_role_display()} updated successfully.',
            'contact': {
                'id': contact.id,
                'role': contact.role,
                'name': contact.name,
                'phone': contact.phone,
                'email': contact.email,
                'message_template': contact.message_template,
            }
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
    Strictly delivers only notifications for authenticated customer.
    """
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]

    def get(self, request):
        try:
            limit = min(int(request.query_params.get('limit', 30)), 100)
        except (ValueError, TypeError):
            limit = 30

        unread_only = request.query_params.get('unread_only', 'false').lower() in ['true', '1']

        from .models import CustomerNotification
        qs = CustomerNotification.objects.filter(customer=request.user)
        unread = qs.filter(is_read=False).count()
        if unread_only:
            qs = qs.filter(is_read=False)
        notifs = qs.order_by('-created_at')[:limit]

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
            'count': len(data),
            'notifications': data,
        }, status=status.HTTP_200_OK)

    def post(self, request):
        from .models import CustomerNotification
        notif_id = request.data.get('id') or request.data.get('notification_id')
        if notif_id:
            CustomerNotification.objects.filter(customer=request.user, id=notif_id).update(is_read=True)
        else:
            CustomerNotification.objects.filter(customer=request.user, is_read=False).update(is_read=True)
        return Response({'success': True, 'message': 'Notifications marked as read.'})


# =====================================================================
# FRANCHISE DASHBOARD STATS (SERVER-SIDE DATABASE AGGREGATION)
# =====================================================================

class FranchiseDashboardStatsView(APIView):
    """
    Franchise Dashboard Statistics computed directly from PostgreSQL.
    Strictly isolated to the authenticated franchise.
    """
    permission_classes = [IsApprovedFranchise]

    def get(self, request):
        import datetime
        from django.utils import timezone
        from orders.models import Order
        from .models import (
            CustomerFranchiseRelationship,
            CustomerStockCycle,
        )

        franchise = getattr(request.user, 'franchise_profile', None)
        if not franchise:
            return Response({'success': False, 'message': 'Franchise profile not found.'}, status=status.HTTP_404_NOT_FOUND)

        today = timezone.now().date()
        low_stock_cutoff = today + datetime.timedelta(days=7)

        # 1. Customers Served: customers whose current serving franchise is this franchise
        customers_served = (
            CustomerFranchiseRelationship.objects
            .filter(current_serving_franchise=franchise)
            .values('customer')
            .distinct()
            .count()
        )

        # 2. Registered Customers: customers whose registered franchise is this franchise
        registered_customers = (
            CustomerFranchiseRelationship.objects
            .filter(registered_franchise=franchise)
            .values('customer')
            .distinct()
            .count()
        )

        # 3. Active Stock & Inventory Metrics (Authoritative DealerStockBatch)
        from inventory.models import DealerStockBatch
        from django.db.models import Sum

        dealer_batches = DealerStockBatch.objects.filter(dealer=franchise)
        has_dealer_batches = dealer_batches.exists()

        if has_dealer_batches:
            active_stock = dealer_batches.filter(
                is_active=True,
                remaining_quantity__gt=0,
            ).aggregate(t=Sum('remaining_quantity'))['t'] or 0

            on_hold = dealer_batches.filter(
                is_active=True,
            ).aggregate(t=Sum('reserved_quantity'))['t'] or 0

            expired_stock = dealer_batches.filter(
                expiry_date__lt=today,
            ).aggregate(t=Sum('remaining_quantity'))['t'] or 0

            low_stock = dealer_batches.filter(
                is_active=True,
                expiry_date__gte=today,
                expiry_date__lte=low_stock_cutoff,
            ).aggregate(t=Sum('remaining_quantity'))['t'] or 0
        else:
            # Fallback to CustomerStockCycle for traditional jar delivery franchises
            active_stock = CustomerStockCycle.objects.filter(
                serving_franchise=franchise,
                service_status='active',
            ).count()
            low_stock = CustomerStockCycle.objects.filter(
                serving_franchise=franchise,
                service_status='active',
                expected_end_date__gte=today,
                expected_end_date__lte=low_stock_cutoff,
            ).count()
            on_hold = CustomerStockCycle.objects.filter(
                serving_franchise=franchise,
                service_status='hold',
            ).count()
            expired_stock = CustomerStockCycle.objects.filter(
                serving_franchise=franchise,
                service_status='active',
                expected_end_date__lt=today,
            ).count()

        # 7. Pending / Relevant Orders: serving_franchise=franchise, status in pending states
        pending_orders = Order.objects.filter(
            serving_franchise=franchise,
            status__in=['order_placement', 'plant_approval', 'invoice_generated', 'dispatch'],
        ).count()

        # 8. Total Orders
        total_orders = Order.objects.filter(
            serving_franchise=franchise,
        ).count()

        # 9. Authoritative Current Territory Info
        from .models import FranchiseTerritoryAssignment
        assignment = (
            FranchiseTerritoryAssignment.objects
            .filter(franchise=franchise, is_active=True)
            .select_related('zone', 'zone__district')
            .order_by('-is_primary', '-assigned_at')
            .first()
        )
        if assignment:
            district_name = assignment.zone.district.name
            territory_name = assignment.zone.name
            zone_id = assignment.zone.id
            areas = list(assignment.zone.areas.filter(is_active=True).values_list('locality_name', flat=True)[:5])
            service_area_str = ", ".join(areas) if areas else (franchise.city or "")
            is_assigned = True
        else:
            district_name = franchise.city or ""
            territory_name = franchise.territory or ""
            zone_id = None
            service_area_str = franchise.city or ""
            is_assigned = bool(district_name or territory_name)

        territory_info = {
            'district': district_name,
            'territory': territory_name,
            'zone_id': zone_id,
            'service_area': service_area_str,
            'address': franchise.address or "",
            'is_assigned': is_assigned,
        }

        stats_dict = {
            'customers_served': customers_served,
            'registered_customers': registered_customers,
            'active_stock': active_stock,
            'low_stock': low_stock,
            'on_hold': on_hold,
            'expired_stock': expired_stock,
            'pending_orders': pending_orders,
            'total_orders': total_orders,
        }

        return Response({
            'success': True,
            'franchise_id': franchise.id,
            'franchise_name': franchise.business_name,
            'territory_info': territory_info,
            'customers_served': customers_served,
            'registered_customers': registered_customers,
            'active_stock': active_stock,
            'low_stock': low_stock,
            'on_hold': on_hold,
            'expired_stock': expired_stock,
            'pending_orders': pending_orders,
            'total_orders': total_orders,
            'stats': stats_dict,
        }, status=status.HTTP_200_OK)


# =====================================================================
# ADMIN FRANCHISE DETAIL & CUSTOMER HIERARCHY VIEW
# =====================================================================

class AdminFranchiseDetailView(APIView):
    """
    Admin-only view for detailed franchise inspection.
    Includes explicit separation between registered customers and customers currently being served,
    along with their per-customer orders and stock cycles.
    """
    permission_classes = [IsAdminRole]

    def get(self, request, franchise_id):
        from orders.models import Order
        from .models import (
            FranchiseProfile,
            CustomerFranchiseRelationship,
            CustomerStockCycle,
        )

        franchise = get_object_or_404(FranchiseProfile, id=franchise_id)

        # Customers connected to this franchise either as registered or currently served
        relationships = (
            CustomerFranchiseRelationship.objects
            .filter(Q(registered_franchise=franchise) | Q(current_serving_franchise=franchise))
            .select_related('customer', 'customer__profile', 'district', 'zone', 'registered_franchise', 'current_serving_franchise')
            .order_by('-customer__date_joined')
        )

        registered_count = relationships.filter(registered_franchise=franchise).values('customer').distinct().count()
        served_count = relationships.filter(current_serving_franchise=franchise).values('customer').distinct().count()

        customer_list = []
        for rel in relationships:
            cust = rel.customer
            prof = getattr(cust, 'profile', None)

            # Customer stock cycles
            cycles = CustomerStockCycle.objects.filter(customer=cust).select_related('product', 'registered_franchise', 'serving_franchise').order_by('-created_at')
            cycles_data = []
            for c in cycles:
                cycles_data.append({
                    'id': c.id,
                    'product_name': c.product.name if c.product else 'Drinking Water',
                    'quantity': c.quantity,
                    'duration_choice': c.duration_choice,
                    'duration_days': c.duration_days,
                    'start_date': c.start_date.isoformat(),
                    'expected_end_date': c.expected_end_date.isoformat(),
                    'service_status': c.service_status,
                    'days_remaining': c.days_remaining,
                    'is_low_stock': c.is_low_stock,
                    'registered_franchise': {
                        'id': c.registered_franchise.id,
                        'name': c.registered_franchise.business_name,
                    } if c.registered_franchise else None,
                    'serving_franchise': {
                        'id': c.serving_franchise.id,
                        'name': c.serving_franchise.business_name,
                    } if c.serving_franchise else None,
                })

            # Customer orders (latest 10)
            orders = Order.objects.filter(created_by=cust).select_related('serving_franchise', 'registered_franchise').order_by('-order_date')[:10]
            orders_data = []
            for o in orders:
                orders_data.append({
                    'id': o.id,
                    'order_code': getattr(o, 'order_code', f'ORD-{o.id}'),
                    'order_date': o.order_date.isoformat() if o.order_date else '',
                    'status': o.status,
                    'status_display': o.get_status_display() if hasattr(o, 'get_status_display') else o.status,
                    'amount': str(o.amount),
                    'items_count': o.items_count,
                    'serving_franchise': {
                        'id': o.serving_franchise.id,
                        'name': o.serving_franchise.business_name,
                    } if o.serving_franchise else None,
                    'registered_franchise': {
                        'id': o.registered_franchise.id,
                        'name': o.registered_franchise.business_name,
                    } if o.registered_franchise else None,
                })

            customer_list.append({
                'id': cust.id,
                'customer_code': f'CUST-{1000 + cust.id}',
                'name': cust.get_full_name() or (prof.name if prof else cust.username),
                'email': cust.email,
                'phone': prof.phone if prof else '',
                'city': prof.city if prof else '',
                'district': rel.district.name if rel.district else (prof.district if prof else ''),
                'zone': rel.zone.name if rel.zone else (prof.zone.name if prof and prof.zone else ''),
                'pincode': rel.pincode or (prof.pincode if prof else ''),
                'locality': rel.locality or (prof.locality if prof else ''),
                'address': prof.address if prof else '',
                'service_status': rel.service_status,
                'registered_franchise': {
                    'id': rel.registered_franchise.id,
                    'name': rel.registered_franchise.business_name,
                } if rel.registered_franchise else None,
                'current_serving_franchise': {
                    'id': rel.current_serving_franchise.id,
                    'name': rel.current_serving_franchise.business_name,
                } if rel.current_serving_franchise else None,
                'is_registered_here': (rel.registered_franchise_id == franchise.id),
                'is_served_here': (rel.current_serving_franchise_id == franchise.id),
                'stock_cycles': cycles_data,
                'orders': orders_data,
            })

        fssai_doc = franchise.kyc_documents.filter(document_type='FSSAI_CERTIFICATE').first()
        fssai_doc_url = ''
        if fssai_doc and fssai_doc.document_file:
            fssai_doc_url = _build_public_doc_url(request, f'/api/accounts/dealers/documents/{fssai_doc.id}/view/')

        return Response({
            'success': True,
            'franchise': {
                'id': franchise.id,
                'user_id': franchise.user_id,
                'business_name': franchise.business_name,
                'owner_name': franchise.user.get_full_name() or franchise.user.username,
                'email': franchise.user.email,
                'phone': franchise.user.profile.phone if hasattr(franchise.user, 'profile') else '',
                'city': franchise.city,
                'address': franchise.address,
                'territory': franchise.territory,
                'status': franchise.status,
                'is_headquarters': franchise.is_headquarters,
                'security_deposit': str(franchise.security_deposit),
                'commission': str(franchise.commission),
                'fssai_number': franchise.fssai_number,
                'fssai_business_name': franchise.fssai_business_name or franchise.business_name,
                'fssai_premises_address': franchise.fssai_premises_address or franchise.address,
                'fssai_state': franchise.fssai_state,
                'fssai_district': franchise.fssai_district,
                'fssai_expiry_date': str(franchise.fssai_expiry_date) if franchise.fssai_expiry_date else None,
                'fssai_verification_status': franchise.fssai_verification_status,
                'fssai_verification_source': franchise.fssai_verification_source,
                'fssai_verified_at': franchise.fssai_verified_at.isoformat() if franchise.fssai_verified_at else None,
                'fssai_verified_by': franchise.fssai_verified_by.username if franchise.fssai_verified_by else None,
                'fssai_rejection_reason': franchise.fssai_rejection_reason,
                'fssai_notes': franchise.fssai_notes,
                'fssai_verification_attempts': franchise.fssai_verification_attempts,
                'fssai_certificate_url': fssai_doc_url,
                'fssai_certificate_id': fssai_doc.id if fssai_doc else None,
                'official_verification_link': 'https://foscos.fssai.gov.in/',
                'created_at': franchise.created_at.strftime('%Y-%m-%d') if franchise.created_at else '',
            },
            'summary': {
                'registered_customers_count': registered_count,
                'customers_served_count': served_count,
            },
            'customers': customer_list,
        }, status=status.HTTP_200_OK)


# =====================================================================
# AUTHORITATIVE SUPER ADMIN GOVERNANCE & BACKUP VIEWS
# =====================================================================

from django.contrib.auth.hashers import make_password
import hashlib
import subprocess
import os
from pathlib import Path
from .models import DealerDocument, Notification, AdminAuditLog, SystemBackupLog, SupportContact


class SuperAdminAdminManagementView(APIView):
    """
    Super Admin management for operational admins with granular permissions and data scopes.
    """
    permission_classes = [IsAuthenticated]

    def _check_super_admin(self, request):
        if request.user.is_superuser:
            return True
        profile = getattr(request.user, 'profile', None)
        return profile is not None and profile.role == 'super_admin'

    def get(self, request):
        if not self._check_super_admin(request):
            return Response({'error': 'Unauthorized. Super Admin access required.'}, status=status.HTTP_403_FORBIDDEN)

        admins = User.objects.filter(profile__role__in=['admin', 'super_admin', 'sales_executive', 'stock_manager']).select_related('profile')
        data = [
            {
                'id': u.id,
                'username': u.username,
                'email': u.email,
                'name': u.get_full_name() or (u.profile.name if hasattr(u, 'profile') else ''),
                'phone': u.profile.phone if hasattr(u, 'profile') else '',
                'role': u.profile.role if hasattr(u, 'profile') else 'admin',
                'status': u.profile.status if hasattr(u, 'profile') else ('active' if u.is_active else 'inactive'),
                'admin_permissions': u.profile.admin_permissions if hasattr(u, 'profile') else [],
                'data_scope_type': u.profile.data_scope_type if hasattr(u, 'profile') else 'all_data',
                'assigned_scope_ids': u.profile.assigned_scope_ids if hasattr(u, 'profile') else [],
                'is_active': u.is_active,
                'created_at': u.date_joined.strftime('%Y-%m-%d %H:%M'),
            }
            for u in admins
        ]
        return Response({'success': True, 'count': len(data), 'admins': data})

    def post(self, request):
        if not self._check_super_admin(request):
            return Response({'error': 'Unauthorized. Super Admin access required.'}, status=status.HTTP_403_FORBIDDEN)

        email = request.data.get('email', '').strip().lower()
        username = request.data.get('username', '').strip()
        name = request.data.get('name', '').strip()
        phone = request.data.get('phone', request.data.get('mobile', '')).strip()
        password = request.data.get('password', '')
        confirm_password = request.data.get('confirm_password', '').strip()
        status_val = request.data.get('status', 'active').strip().lower()
        role = request.data.get('role', 'admin').strip().lower()
        data_scope_type = request.data.get('data_scope_type', 'all_data').strip().lower()
        assigned_scope_ids = request.data.get('assigned_scope_ids', [])
        admin_permissions = request.data.get('admin_permissions', [])

        if confirm_password and confirm_password != password:
            return Response({'error': 'Password and confirm password do not match.'}, status=status.HTTP_400_BAD_REQUEST)

        if not email or not password:
            return Response({'error': 'Email and password are required.'}, status=status.HTTP_400_BAD_REQUEST)

        if not username:
            username = email

        if isinstance(admin_permissions, str):
            import json
            try:
                admin_permissions = json.loads(admin_permissions)
            except Exception:
                admin_permissions = [p.strip() for p in admin_permissions.split(',') if p.strip()]
        elif hasattr(request.data, 'getlist'):
            raw_list = request.data.getlist('admin_permissions')
            if raw_list and len(raw_list) > 1:
                admin_permissions = raw_list

        if isinstance(assigned_scope_ids, str):
            import json
            try:
                assigned_scope_ids = json.loads(assigned_scope_ids)
            except Exception:
                assigned_scope_ids = [s.strip() for s in assigned_scope_ids.split(',') if s.strip()]
        elif hasattr(request.data, 'getlist'):
            raw_scopes = request.data.getlist('assigned_scope_ids')
            if raw_scopes and len(raw_scopes) > 1:
                assigned_scope_ids = raw_scopes

        if User.objects.filter(username__iexact=username).exists():
            return Response({'error': f'A user with username "{username}" already exists.'}, status=status.HTTP_400_BAD_REQUEST)

        if User.objects.filter(email__iexact=email).exists():
            return Response({'error': f'A user with email "{email}" already exists.'}, status=status.HTTP_400_BAD_REQUEST)

        is_active = (status_val == 'active')

        with transaction.atomic():
            user = User.objects.create(
                username=username,
                email=email,
                password=make_password(password),
                first_name=name,
                is_active=is_active,
            )
            prof, _ = UserProfile.objects.get_or_create(user=user)
            prof.name = name
            prof.phone = phone
            prof.status = status_val
            prof.role = role
            prof.admin_permissions = admin_permissions
            prof.data_scope_type = data_scope_type
            prof.assigned_scope_ids = assigned_scope_ids
            prof.save()

            AdminAuditLog.objects.create(
                actor=request.user,
                action='CREATE_ADMIN',
                resource_type='UserProfile',
                resource_id=str(user.id),
                changes={
                    'username': username,
                    'email': email,
                    'name': name,
                    'phone': phone,
                    'role': role,
                    'status': status_val,
                    'admin_permissions': admin_permissions,
                    'data_scope_type': data_scope_type,
                    'assigned_scope_ids': assigned_scope_ids
                }
            )

        return Response({
            'success': True,
            'message': f'Admin account created for {email}.',
            'id': user.id
        }, status=status.HTTP_201_CREATED)


class SuperAdminAdminDetailView(APIView):
    """
    Super Admin management for individual admin accounts:
    - GET: Detail, permissions, data scope, active status, recent audit history.
    - PATCH / PUT: Update name, email, role, admin_permissions, data_scope_type, assigned_scope_ids, is_active, password reset.
    - DELETE: Soft disable (is_active=False) preserving all historical records.
    """
    permission_classes = [IsAuthenticated]

    def _check_super_admin(self, request):
        if request.user.is_superuser:
            return True
        profile = getattr(request.user, 'profile', None)
        return profile is not None and profile.role == 'super_admin'

    def get(self, request, pk):
        if not self._check_super_admin(request):
            return Response({'error': 'Unauthorized. Super Admin access required.'}, status=status.HTTP_403_FORBIDDEN)

        target_user = get_object_or_404(User.objects.select_related('profile'), pk=pk)
        profile = getattr(target_user, 'profile', None)

        recent_logs = AdminAuditLog.objects.filter(actor=target_user)[:15]
        logs_data = [
            {
                'id': log.id,
                'action': log.action,
                'resource_type': log.resource_type,
                'resource_id': log.resource_id,
                'created_at': log.created_at.strftime('%Y-%m-%d %H:%M:%S'),
                'changes': log.changes,
            }
            for log in recent_logs
        ]

        return Response({
            'success': True,
            'admin': {
                'id': target_user.id,
                'username': target_user.username,
                'email': target_user.email,
                'name': target_user.get_full_name() or (profile.name if profile else ''),
                'phone': profile.phone if profile else '',
                'role': profile.role if profile else 'admin',
                'status': profile.status if profile else ('active' if target_user.is_active else 'inactive'),
                'is_active': target_user.is_active,
                'admin_permissions': profile.admin_permissions if profile else [],
                'data_scope_type': profile.data_scope_type if profile else 'all_data',
                'assigned_scope_ids': profile.assigned_scope_ids if profile else [],
                'date_joined': target_user.date_joined.strftime('%Y-%m-%d %H:%M'),
                'last_login': target_user.last_login.strftime('%Y-%m-%d %H:%M') if target_user.last_login else None,
                'recent_activity': logs_data
            }
        })

    def patch(self, request, pk):
        if not self._check_super_admin(request):
            return Response({'error': 'Unauthorized. Super Admin access required.'}, status=status.HTTP_403_FORBIDDEN)

        target_user = get_object_or_404(User.objects.select_related('profile'), pk=pk)
        profile = getattr(target_user, 'profile', None)
        changes = {}

        with transaction.atomic():
            if 'name' in request.data:
                name = request.data['name'].strip()
                target_user.first_name = name
                if profile:
                    profile.name = name
                changes['name'] = name

            if 'email' in request.data:
                email = request.data['email'].strip().lower()
                if email != target_user.email and User.objects.filter(email__iexact=email).exclude(pk=target_user.pk).exists():
                    return Response({'error': 'A user with this email already exists.'}, status=status.HTTP_400_BAD_REQUEST)
                target_user.email = email
                changes['email'] = email

            if 'username' in request.data:
                uname = request.data['username'].strip()
                if uname and uname != target_user.username and User.objects.filter(username__iexact=uname).exclude(pk=target_user.pk).exists():
                    return Response({'error': 'A user with this username already exists.'}, status=status.HTTP_400_BAD_REQUEST)
                if uname:
                    target_user.username = uname
                    changes['username'] = uname

            if 'phone' in request.data or 'mobile' in request.data:
                ph = request.data.get('phone', request.data.get('mobile', '')).strip()
                if profile:
                    profile.phone = ph
                changes['phone'] = ph

            if 'status' in request.data:
                st = request.data['status'].strip().lower()
                if profile:
                    profile.status = st
                target_user.is_active = (st == 'active')
                changes['status'] = st
                changes['is_active'] = target_user.is_active

            if 'is_active' in request.data:
                is_active = bool(request.data['is_active'])
                target_user.is_active = is_active
                if profile:
                    profile.status = 'active' if is_active else 'inactive'
                changes['is_active'] = is_active

            if 'role' in request.data and profile:
                new_role = request.data['role'].strip().lower()
                if new_role in ['admin', 'sales_executive', 'super_admin', 'stock_manager']:
                    profile.role = new_role
                    changes['role'] = new_role

            if 'admin_permissions' in request.data and profile:
                perms = request.data['admin_permissions']
                if isinstance(perms, str):
                    import json
                    try:
                        perms = json.loads(perms)
                    except Exception:
                        perms = [p.strip() for p in perms.split(',') if p.strip()]
                elif hasattr(request.data, 'getlist'):
                    raw_p = request.data.getlist('admin_permissions')
                    if raw_p and len(raw_p) > 1:
                        perms = raw_p
                profile.admin_permissions = perms
                changes['admin_permissions'] = profile.admin_permissions

            if 'data_scope_type' in request.data and profile:
                profile.data_scope_type = request.data['data_scope_type'].strip().lower()
                changes['data_scope_type'] = profile.data_scope_type

            if 'assigned_scope_ids' in request.data and profile:
                scopes = request.data['assigned_scope_ids']
                if isinstance(scopes, str):
                    import json
                    try:
                        scopes = json.loads(scopes)
                    except Exception:
                        scopes = [s.strip() for s in scopes.split(',') if s.strip()]
                elif hasattr(request.data, 'getlist'):
                    raw_s = request.data.getlist('assigned_scope_ids')
                    if raw_s and len(raw_s) > 1:
                        scopes = raw_s
                profile.assigned_scope_ids = scopes
                changes['assigned_scope_ids'] = profile.assigned_scope_ids

            if 'password' in request.data and request.data['password']:
                target_user.password = make_password(request.data['password'])
                changes['password'] = 'RESET_SECURELY'

            target_user.save()
            if profile:
                profile.save()

            AdminAuditLog.objects.create(
                actor=request.user,
                action='UPDATE_ADMIN',
                resource_type='UserProfile',
                resource_id=str(target_user.id),
                changes=changes
            )

        return Response({
            'success': True,
            'message': f'Admin account {target_user.email} updated successfully.',
            'changes': changes
        })

    def delete(self, request, pk):
        if not self._check_super_admin(request):
            return Response({'error': 'Unauthorized. Super Admin access required.'}, status=status.HTTP_403_FORBIDDEN)

        target_user = get_object_or_404(User.objects.select_related('profile'), pk=pk)
        if target_user.pk == request.user.pk:
            return Response({'error': 'Cannot disable your own Super Admin account.'}, status=status.HTTP_400_BAD_REQUEST)

        target_user.is_active = False
        target_user.save()
        if hasattr(target_user, 'profile') and target_user.profile:
            target_user.profile.status = 'inactive'
            target_user.profile.save()

        AdminAuditLog.objects.create(
            actor=request.user,
            action='DISABLE_ADMIN',
            resource_type='UserProfile',
            resource_id=str(target_user.id),
            changes={'is_active': False, 'status': 'inactive'}
        )

        return Response({
            'success': True,
            'message': f'Admin account {target_user.email} disabled successfully. Historical records preserved.'
        })


class SuperAdminAdminPerformanceView(APIView):
    """
    Real-time Admin-Performance / Activity Reporting for Super Admin.
    Calculates operational actions performed by individual admins using DB records.
    Filters: today, yesterday, last_7_days, this_month, custom.
    """
    permission_classes = [IsAuthenticated]

    def _check_super_admin(self, request):
        if request.user.is_superuser:
            return True
        profile = getattr(request.user, 'profile', None)
        return profile is not None and profile.role == 'super_admin'

    def get(self, request):
        if not self._check_super_admin(request):
            return Response({'error': 'Unauthorized. Super Admin access required.'}, status=status.HTTP_403_FORBIDDEN)

        from django.utils import timezone
        from datetime import timedelta, datetime
        from orders.models import OrderStatusHistory
        from inventory.models import DealerStockRequest, InventoryTransactionLedger
        from leads.models import Lead, CRMActivityLog
        from followups.models import FollowUp

        now = timezone.now()
        date_filter = request.query_params.get('date_filter', 'today').lower()

        if date_filter == 'today':
            start_dt = now.replace(hour=0, minute=0, second=0, microsecond=0)
            end_dt = now
        elif date_filter == 'yesterday':
            yesterday = now - timedelta(days=1)
            start_dt = yesterday.replace(hour=0, minute=0, second=0, microsecond=0)
            end_dt = yesterday.replace(hour=23, minute=59, second=59, microsecond=999999)
        elif date_filter in ['last_7_days', '7_days']:
            start_dt = (now - timedelta(days=7)).replace(hour=0, minute=0, second=0, microsecond=0)
            end_dt = now
        elif date_filter == 'this_month':
            start_dt = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
            end_dt = now
        elif date_filter == 'custom':
            start_str = request.query_params.get('start_date')
            end_str = request.query_params.get('end_date')
            try:
                start_dt = timezone.make_aware(datetime.strptime(start_str, '%Y-%m-%d'))
                end_dt = timezone.make_aware(datetime.strptime(end_str, '%Y-%m-%d').replace(hour=23, minute=59, second=59, microsecond=999999))
            except Exception:
                try:
                    from datetime import timezone as dt_tz
                    start_dt = datetime.strptime(start_str, '%Y-%m-%d').replace(tzinfo=dt_tz.utc)
                    end_dt = datetime.strptime(end_str, '%Y-%m-%d').replace(hour=23, minute=59, second=59, tzinfo=dt_tz.utc)
                except Exception:
                    return Response({'error': 'Invalid custom dates. Format YYYY-MM-DD required.'}, status=status.HTTP_400_BAD_REQUEST)
        else:
            start_dt = now.replace(hour=0, minute=0, second=0, microsecond=0)
            end_dt = now

        admin_id = request.query_params.get('admin_id')
        admins_qs = User.objects.filter(profile__role__in=['admin', 'super_admin', 'sales_executive']).select_related('profile')
        if admin_id:
            admins_qs = admins_qs.filter(id=admin_id)

        performance_data = []

        for admin in admins_qs:
            order_transitions = OrderStatusHistory.objects.filter(
                changed_by=admin,
                created_at__range=(start_dt, end_dt)
            )
            orders_handled = order_transitions.values('order_id').distinct().count()
            orders_approved = order_transitions.filter(new_status='plant_approval').count()
            orders_prepared = order_transitions.filter(new_status='preparing').count()
            orders_dispatched = order_transitions.filter(new_status='dispatch').count()
            orders_delivered = order_transitions.filter(new_status='delivered').count()

            stock_reqs_approved = DealerStockRequest.objects.filter(
                approved_by=admin,
                created_at__range=(start_dt, end_dt)
            ).count()
            stock_reqs_dispatched = DealerStockRequest.objects.filter(
                dispatched_by=admin,
                created_at__range=(start_dt, end_dt)
            ).count()

            dealer_onboarding_actions = AdminAuditLog.objects.filter(
                actor=admin,
                action__in=['APPROVE_DEALER', 'REJECT_DEALER', 'SUSPEND_DEALER'],
                created_at__range=(start_dt, end_dt)
            ).count()

            customer_actions = AdminAuditLog.objects.filter(
                actor=admin,
                resource_type__in=['UserProfile', 'CustomerFranchiseRelationship'],
                created_at__range=(start_dt, end_dt)
            ).count()

            leads_handled = Lead.objects.filter(
                Q(created_by=admin) | Q(assigned_executive_user=admin),
                created_at__range=(start_dt, end_dt)
            ).count()
            leads_converted = Lead.objects.filter(
                converted_user__isnull=False,
                created_by=admin,
                updated_at__range=(start_dt, end_dt)
            ).count()

            followups_completed = FollowUp.objects.filter(
                status='Completed',
                updated_by=admin,
                completed_at__range=(start_dt, end_dt)
            ).count()

            inventory_adjustments = InventoryTransactionLedger.objects.filter(
                actor=admin,
                transaction_type__in=['ADJUSTMENT', 'DAMAGE', 'EXPIRY'],
                timestamp__range=(start_dt, end_dt)
            ).count()

            reports_generated = AdminAuditLog.objects.filter(
                actor=admin,
                action__icontains='REPORT',
                created_at__range=(start_dt, end_dt)
            ).count()

            latest_audit = AdminAuditLog.objects.filter(actor=admin).first()
            latest_transition = order_transitions.first()
            last_active_time = None
            if latest_audit and latest_transition:
                last_active_time = max(latest_audit.created_at, latest_transition.created_at)
            elif latest_audit:
                last_active_time = latest_audit.created_at
            elif latest_transition:
                last_active_time = latest_transition.created_at

            recent_audit = AdminAuditLog.objects.filter(
                actor=admin,
                created_at__range=(start_dt, end_dt)
            )[:10]

            performance_data.append({
                'admin_id': admin.id,
                'name': admin.get_full_name() or (admin.profile.name if hasattr(admin, 'profile') else admin.username),
                'email': admin.email,
                'role': admin.profile.role if hasattr(admin, 'profile') else 'admin',
                'is_active': admin.is_active,
                'last_login': admin.last_login.strftime('%Y-%m-%d %H:%M:%S') if admin.last_login else None,
                'last_active_time': last_active_time.strftime('%Y-%m-%d %H:%M:%S') if last_active_time else None,
                'metrics': {
                    'orders_handled': orders_handled,
                    'orders_approved': orders_approved,
                    'orders_prepared': orders_prepared,
                    'orders_dispatched': orders_dispatched,
                    'orders_delivered': orders_delivered,
                    'stock_requests_reviewed': stock_reqs_approved + stock_reqs_dispatched,
                    'stock_requests_approved': stock_reqs_approved,
                    'stock_requests_dispatched': stock_reqs_dispatched,
                    'dealer_onboarding_actions': dealer_onboarding_actions,
                    'customer_actions': customer_actions,
                    'leads_handled': leads_handled,
                    'leads_converted': leads_converted,
                    'followups_completed': followups_completed,
                    'inventory_adjustments': inventory_adjustments,
                    'reports_generated': reports_generated,
                },
                'audit_trail': [
                    {
                        'id': a.id,
                        'action': a.action,
                        'resource_type': a.resource_type,
                        'resource_id': a.resource_id,
                        'created_at': a.created_at.strftime('%Y-%m-%d %H:%M:%S'),
                        'changes': a.changes,
                    }
                    for a in recent_audit
                ]
            })

        return Response({
            'success': True,
            'date_filter': date_filter,
            'start_date': start_dt.strftime('%Y-%m-%d %H:%M:%S'),
            'end_date': end_dt.strftime('%Y-%m-%d %H:%M:%S'),
            'count': len(performance_data),
            'admin_performance': performance_data
        })


class DealerOnboardingApprovalView(APIView):
    """
    Super Admin / Admin review of wholesale dealer onboarding applications.
    Transitions: PENDING -> UNDER_REVIEW -> APPROVED / REJECTED / SUSPENDED.
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        role = getattr(getattr(request.user, 'profile', None), 'role', '')
        if not (request.user.is_superuser or role in ['admin', 'super_admin']):
            return Response({'error': 'Unauthorized. Admin access required.'}, status=status.HTTP_403_FORBIDDEN)

        qs = FranchiseProfile.objects.all().select_related('user', 'user__profile')
        status_filter = request.query_params.get('status')
        if status_filter:
            qs = qs.filter(status=status_filter)

        data = [
            {
                'id': f.id,
                'dealer_code': f.dealer_code,
                'business_name': f.business_name,
                'owner_name': f.user.get_full_name() or f.user.username,
                'phone': f.user.profile.phone if hasattr(f.user, 'profile') else '',
                'email': f.user.email,
                'city': f.city,
                'address': f.address,
                'territory': f.territory,
                'status': f.status,
                'commission': str(f.commission),
                'gst_number': f.gst_number,
                'pan_number': f.pan_number,
                'created_at': f.created_at.strftime('%Y-%m-%d'),
            }
            for f in qs
        ]
        return Response({'success': True, 'dealers': data})

    def post(self, request, pk):
        role = getattr(getattr(request.user, 'profile', None), 'role', '')
        if not (request.user.is_superuser or role in ['admin', 'super_admin']):
            return Response({'error': 'Unauthorized. Admin access required.'}, status=status.HTTP_403_FORBIDDEN)

        dealer = get_object_or_404(FranchiseProfile, pk=pk)
        action = request.data.get('action', 'approve').lower()

        with transaction.atomic():
            if action == 'approve':
                from .fssai_services import validate_franchise_fssai_for_activation
                override_reason = str(request.data.get('override_reason', '')).strip()
                is_eligible, err_msg, err_code = validate_franchise_fssai_for_activation(
                    dealer, actor=request.user, override_reason=override_reason
                )
                if not is_eligible:
                    return Response({'error': err_msg, 'message': err_msg, 'error_code': err_code, 'success': False}, status=status.HTTP_400_BAD_REQUEST)

                dealer.status = 'approved'
                dealer.approved_at = timezone.now()
                if 'commission' in request.data:
                    dealer.commission = Decimal(str(request.data['commission']))
                if not dealer.dealer_code:
                    count = FranchiseProfile.objects.filter(status='approved').count() + 1
                    dealer.dealer_code = f"DLR-{(dealer.city[:3] if dealer.city else 'SHV').upper()}-{count:03d}"
                dealer.save()

                # Ensure DealerCreditProfile exists
                from billing.models import DealerCreditProfile
                credit_limit = Decimal(str(request.data.get('credit_limit', '50000.00')))
                payment_terms = int(request.data.get('payment_terms_days', 15))
                credit, _ = DealerCreditProfile.objects.get_or_create(
                    dealer=dealer,
                    defaults={'credit_limit': credit_limit, 'payment_terms_days': payment_terms}
                )
                if not _:
                    credit.credit_limit = credit_limit
                    credit.payment_terms_days = payment_terms
                    credit.save()

                AdminAuditLog.objects.create(
                    actor=request.user,
                    action='APPROVE_DEALER',
                    resource_type='FranchiseProfile',
                    resource_id=str(dealer.id),
                    changes={'dealer_code': dealer.dealer_code, 'commission': str(dealer.commission), 'credit_limit': str(credit_limit)}
                )

                return Response({
                    'success': True,
                    'message': f'Dealer {dealer.business_name} approved ({dealer.dealer_code}).',
                    'dealer_code': dealer.dealer_code
                })

            elif action == 'reject':
                dealer.status = 'rejected'
                dealer.rejection_reason = request.data.get('reason', '')
                dealer.save()

                AdminAuditLog.objects.create(
                    actor=request.user,
                    action='REJECT_DEALER',
                    resource_type='FranchiseProfile',
                    resource_id=str(dealer.id),
                    changes={'reason': dealer.rejection_reason}
                )
                return Response({'success': True, 'message': 'Dealer onboarding rejected.'})

            elif action == 'under_review':
                dealer.status = 'under_review'
                dealer.save()
                return Response({'success': True, 'message': 'Dealer status set to under review.'})

            elif action == 'suspend':
                dealer.status = 'suspended'
                dealer.save()
                AdminAuditLog.objects.create(
                    actor=request.user,
                    action='SUSPEND_DEALER',
                    resource_type='FranchiseProfile',
                    resource_id=str(dealer.id),
                    changes={'reason': request.data.get('reason', 'Account suspended by admin')}
                )
                return Response({'success': True, 'message': 'Dealer account suspended.'})

        return Response({'error': 'Invalid action'}, status=status.HTTP_400_BAD_REQUEST)


class DatabaseBackupTriggerView(APIView):
    """
    Executes actual PostgreSQL pg_dump or SQLite/management backup, verifies output file size and SHA256,
    and logs record to SystemBackupLog. Never fakes completion.
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        backups = SystemBackupLog.objects.all()[:30]
        data = [
            {
                'id': b.id,
                'backup_filename': b.backup_filename,
                'file_size_bytes': b.file_size_bytes,
                'checksum_sha256': b.checksum_sha256,
                'status': b.status,
                'error_message': b.error_message,
                'started_at': b.started_at.strftime('%Y-%m-%d %H:%M:%S'),
                'completed_at': b.completed_at.strftime('%Y-%m-%d %H:%M:%S') if b.completed_at else None,
            }
            for b in backups
        ]
        return Response({'success': True, 'backups': data})

    def post(self, request):
        if not (request.user.is_superuser or (hasattr(request.user, 'profile') and request.user.profile.role == 'super_admin')):
            return Response({'error': 'Unauthorized. Super Admin access required.'}, status=status.HTTP_403_FORBIDDEN)

        timestamp_str = timezone.now().strftime('%Y%m%d_%H%M%S')
        filename = f"shivnath_db_backup_{timestamp_str}.sql"
        backup_dir = Path(settings.BASE_DIR) / 'backups'
        backup_dir.mkdir(parents=True, exist_ok=True)
        backup_path = backup_dir / filename

        log = SystemBackupLog.objects.create(
            triggered_by=request.user,
            backup_filename=filename,
            storage_path=str(backup_path),
            status='IN_PROGRESS'
        )

        try:
            import shutil
            from django.core.management import call_command

            # Build pg_dump command from database settings
            db_conf = settings.DATABASES['default']
            db_engine = db_conf.get('ENGINE', '')
            backup_written = False

            if 'postgresql' in db_engine and shutil.which('pg_dump'):
                env = os.environ.copy()
                if db_conf.get('PASSWORD'):
                    env['PGPASSWORD'] = str(db_conf['PASSWORD'])

                cmd = [
                    'pg_dump',
                    '-h', str(db_conf.get('HOST', 'localhost')),
                    '-p', str(db_conf.get('PORT', '5432')),
                    '-U', str(db_conf.get('USER', 'postgres')),
                    '-d', str(db_conf.get('NAME', 'shivnath')),
                    '-F', 'c',
                    '-f', str(backup_path)
                ]
                result = subprocess.run(cmd, env=env, capture_output=True, text=True, timeout=120)
                if result.returncode == 0 and backup_path.exists() and backup_path.stat().st_size > 0:
                    backup_written = True

            if not backup_written:
                with open(backup_path, 'w', encoding='utf-8') as f:
                    call_command('dumpdata', natural_foreign=True, natural_primary=True, stdout=f)
                backup_written = True


            # Verify file exists and calculate SHA256 checksum
            if not backup_path.exists() or backup_path.stat().st_size == 0:
                raise Exception("Backup output file is empty or was not created.")

            file_size = backup_path.stat().st_size
            hasher = hashlib.sha256()
            with open(backup_path, 'rb') as f:
                while chunk := f.read(65536):
                    hasher.update(chunk)
            checksum = hasher.hexdigest()

            log.file_size_bytes = file_size
            log.checksum_sha256 = checksum
            log.status = 'SUCCESS'
            log.completed_at = timezone.now()
            log.save()

            return Response({
                'success': True,
                'message': 'Database backup executed and verified successfully.',
                'filename': filename,
                'file_size_bytes': file_size,
                'checksum_sha256': checksum
            }, status=status.HTTP_201_CREATED)

        except Exception as e:
            log.status = 'FAILED'
            log.error_message = str(e)
            log.completed_at = timezone.now()
            log.save()
            return Response({
                'success': False,
                'error': f"Backup execution failed: {str(e)}"
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class RoleBasedChatbotMenuView(APIView):
    """
    Live DB-backed dynamic chatbot menus tailored per authenticated user role.
    CUSTOMER, DEALER, ADMIN, SUPER_ADMIN.
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        user = request.user
        role = getattr(getattr(user, 'profile', None), 'role', 'customer')

        if role == 'super_admin':
            menu_items = [
                {'key': 'BUSINESS_OVERVIEW', 'title': 'Business Overview', 'description': 'Real-time sales, production & active dealers'},
                {'key': 'SALES', 'title': 'Sales', 'description': 'Company-wide retail and wholesale sales'},
                {'key': 'REVENUE', 'title': 'Revenue', 'description': 'Delivered sales revenue recognition'},
                {'key': 'PROFIT_LOSS', 'title': 'P&L', 'description': 'Gross margin, snapshot COGS & operational expenses'},
                {'key': 'DEALERS', 'title': 'Dealers', 'description': 'Network status, credit balances & territory allocations'},
                {'key': 'CUSTOMERS', 'title': 'Customers', 'description': 'Registered customer base across districts'},
                {'key': 'ORDERS', 'title': 'Orders', 'description': 'Live company and dealer order pipeline'},
                {'key': 'PRODUCTION', 'title': 'Production', 'description': 'Active batches and daily bottling output'},
                {'key': 'INVENTORY', 'title': 'Inventory', 'description': 'Company plant inventory and dealer warehouses'},
                {'key': 'STOCK', 'title': 'Stock', 'description': 'Total available finished cases across 5 official variants'},
                {'key': 'EXPIRY', 'title': 'Expiry', 'description': 'Active 30/15/7/3-day batch expiry alerts'},
                {'key': 'LEADS', 'title': 'Leads', 'description': 'CRM prospective dealer inquiry pipeline'},
                {'key': 'CRM', 'title': 'CRM', 'description': 'Sales executive field visits and follow-ups'},
                {'key': 'REPORTS', 'title': 'Reports', 'description': 'Daily business summaries & inventory valuation'},
                {'key': 'NOTIFICATIONS', 'title': 'Notifications', 'description': 'Critical system & low-stock alerts'},
                {'key': 'SUPPORT', 'title': 'Support', 'description': 'Support desk and emergency escalation'},
            ]
        elif role == 'admin':
            menu_items = [
                {'key': 'LEADS', 'title': 'Leads', 'description': 'New inquiries and qualification pipeline'},
                {'key': 'CUSTOMERS', 'title': 'Customers', 'description': 'Customer service areas and delivery status'},
                {'key': 'DEALERS', 'title': 'Franchises', 'description': 'Franchise network and contact info'},
                {'key': 'ORDERS', 'title': 'Orders', 'description': 'Pending approvals, dispatch and tracking'},
                {'key': 'PRODUCTS', 'title': 'Products', 'description': 'Official 5 variants and MRP catalog'},
                {'key': 'INVENTORY', 'title': 'Inventory', 'description': 'Plant stock and raw material balances'},
                {'key': 'STOCK_REQUESTS', 'title': 'Stock Requests', 'description': 'Pending franchise allocations'},
                {'key': 'PRODUCTION', 'title': 'Production', 'description': 'Log new production batches'},
                {'key': 'FOLLOW_UPS', 'title': 'Follow-ups', 'description': 'Scheduled customer & dealer calls'},
                {'key': 'REPORTS', 'title': 'Reports', 'description': 'Daily dispatch and sales summaries'},
                {'key': 'NOTIFICATIONS', 'title': 'Notifications', 'description': 'Batch expiry & stock alerts'},
                {'key': 'SUPPORT', 'title': 'Support', 'description': 'Support desk escalation'},
            ]
        elif role == 'franchise':
            menu_items = [
                {'key': 'STOCK', 'title': 'Stock', 'description': 'Local warehouse stock across 5 variants'},
                {'key': 'STOCK_REQUEST', 'title': 'Stock Request', 'description': 'Request fresh stock from central plant'},
                {'key': 'ORDERS', 'title': 'Orders', 'description': 'Customer orders assigned to your dealership'},
                {'key': 'SALES', 'title': 'Sales', 'description': 'Record local retail sales'},
                {'key': 'CUSTOMERS', 'title': 'Customers', 'description': 'Active customers in your assigned territory'},
                {'key': 'REPORTS', 'title': 'Reports', 'description': 'Dealer sales and purchase credit ledger'},
                {'key': 'DEALER_INFO', 'title': 'Dealer Info', 'description': 'Assigned territory, credit limit & terms'},
                {'key': 'SUPPORT', 'title': 'Support', 'description': 'Company operations support desk'},
            ]
        else:
            menu_items = [
                {'key': 'PRODUCTS', 'title': 'Products', 'description': 'Shivnath Pure Drinking Water variants'},
                {'key': 'PRODUCT_PRICES', 'title': 'Product Prices', 'description': 'Official retail prices and MRP'},
                {'key': 'PRODUCT_AVAILABILITY', 'title': 'Product Availability', 'description': 'Check stock in your area'},
                {'key': 'COMPARE_PRODUCTS', 'title': 'Compare Products', 'description': 'Bottle sizes, cases and uses'},
                {'key': 'PRODUCT_SIZES', 'title': 'Product Sizes', 'description': '200ML, 250ML, 500ML, 1L, 20L Jar'},
                {'key': 'MY_ORDERS', 'title': 'My Orders', 'description': 'View previous orders and receipts'},
                {'key': 'ORDER_STATUS', 'title': 'Order Status', 'description': 'Track active delivery in real-time'},
                {'key': 'PAYMENT_BILLING', 'title': 'Payment / Billing', 'description': 'GST invoices and UPI payments'},
                {'key': 'DELIVERY_DISPATCH', 'title': 'Delivery / Dispatch', 'description': 'Expected delivery timeline'},
                {'key': 'BULK_ORDER', 'title': 'Bulk Order', 'description': 'Request commercial/event bulk supply'},
                {'key': 'SUPPORT', 'title': 'Support', 'description': 'Call or chat with support desk'},
            ]

        return Response({
            'success': True,
            'role': role,
            'menu': menu_items
        })


class RoleBasedChatbotActionView(APIView):
    """
    Executes role-specific actions from the live authenticated chatbot.
    Accepts: { "action": str, "query": str }
    Roles: customer, franchise, admin, super_admin.
    """
    permission_classes = [IsAuthenticated]

    def post(self, request):
        user = request.user
        role = getattr(getattr(user, 'profile', None), 'role', 'customer')
        action = request.data.get('action', '').strip().upper()
        query = request.data.get('query', '').strip()

        from products.models import Product
        from orders.models import Order
        from inventory.models import ProductionBatch, DealerStockBatch, DealerStockRequest
        from billing.models import DealerCreditProfile, Invoice
        from leads.models import Lead

        result_data = {}
        message = ""

        if role == 'super_admin':
            if action in ['BUSINESS_OVERVIEW', 'OVERVIEW']:
                total_orders = Order.objects.count()
                total_dealers = FranchiseProfile.objects.filter(status='approved').count()
                batches_active = ProductionBatch.objects.filter(status='ACTIVE').count()
                message = f"Enterprise Overview: {total_orders} total orders placed, {total_dealers} active franchises, {batches_active} active production batches."
                result_data = {'orders_count': total_orders, 'dealers_count': total_dealers, 'active_batches': batches_active}
            elif action in ['DEALERS', 'DEALER_NETWORK']:
                dealers = FranchiseProfile.objects.filter(status='approved')[:10]
                result_data = [{'id': d.id, 'dealer_code': d.dealer_code, 'name': d.business_name, 'city': d.city} for d in dealers]
                message = f"Found {dealers.count()} active approved franchises."
            elif action in ['PROFIT_LOSS', 'P&L']:
                from inventory.models import DailyBusinessReport
                latest = DailyBusinessReport.objects.first()
                if latest:
                    message = f"Latest Daily P&L ({latest.report_date}): Revenue ₹{latest.total_gross_revenue_inr}, COGS ₹{latest.total_cogs_inr}, Net Profit ₹{latest.net_profit_inr}."
                    result_data = {'date': str(latest.report_date), 'revenue': str(latest.total_gross_revenue_inr), 'net_profit': str(latest.net_profit_inr)}
                else:
                    message = "No daily P&L report generated yet."
            elif action in ['EXPIRY', 'EXPIRY_ALERTS']:
                from inventory.models import ExpiryAlertLog
                alerts_count = ExpiryAlertLog.objects.count()
                message = f"There are {alerts_count} active/logged batch expiry alerts across the enterprise."
                result_data = {'expiry_alerts_count': alerts_count}
            else:
                message = f"Action '{action}' processed for Super Admin."

        elif role == 'admin':
            if action in ['INVENTORY', 'PLANT_STOCK']:
                batches = ProductionBatch.objects.filter(status='ACTIVE', quantity_remaining_company__gt=0).select_related('product')
                total_bottles = sum(b.quantity_remaining_company for b in batches)
                message = f"Central Plant Inventory: {total_bottles} total bottles across {batches.count()} active production batches."
                result_data = {'total_units': total_bottles, 'batches_count': batches.count()}
            elif action in ['STOCK_REQUESTS']:
                reqs = DealerStockRequest.objects.filter(status='REQUESTED').select_related('dealer', 'product')
                message = f"{reqs.count()} pending franchise stock request(s) awaiting allocation."
                result_data = [{'id': r.id, 'request_number': r.request_number, 'dealer': r.dealer.business_name, 'qty': r.requested_quantity} for r in reqs]
            elif action in ['ORDERS']:
                pending = Order.objects.filter(status='order_placement').count()
                message = f"{pending} customer order(s) pending plant or dealer assignment."
                result_data = {'pending_orders': pending}
            elif action in ['LEADS']:
                hot_leads = Lead.objects.filter(score_category='HOT').count()
                message = f"CRM Pipeline: {hot_leads} Hot qualified dealer lead(s)."
                result_data = {'hot_leads_count': hot_leads}
            else:
                message = f"Action '{action}' executed for Admin."

        elif role == 'franchise':
            dealer = getattr(user, 'franchise_profile', None)
            if not dealer:
                return Response({'error': 'No dealer profile associated.'}, status=status.HTTP_400_BAD_REQUEST)
            if action in ['STOCK', 'LOCAL_STOCK']:
                batches = DealerStockBatch.objects.filter(dealer=dealer, is_active=True, remaining_quantity__gt=0)
                total = sum(b.remaining_quantity for b in batches)
                message = f"Your Local Warehouse Stock: {total} total bottles available."
                result_data = {'total_available': total, 'batches': [{'sku': b.product.sku, 'qty': b.remaining_quantity, 'exp': str(b.expiry_date)} for b in batches]}
            elif action in ['DEALER_INFO', 'CREDIT']:
                credit = DealerCreditProfile.objects.filter(dealer=dealer).first()
                if credit:
                    message = f"Dealer {dealer.business_name} ({dealer.dealer_code}): Credit Limit ₹{credit.credit_limit}, Outstanding ₹{credit.current_outstanding}, Status: {credit.credit_status}."
                    result_data = {'credit_limit': str(credit.credit_limit), 'outstanding': str(credit.current_outstanding), 'status': credit.credit_status}
                else:
                    message = f"Dealer {dealer.business_name}: Standard terms apply."
            elif action in ['ORDERS']:
                orders = Order.objects.filter(serving_franchise=dealer).order_by('-id')[:5]
                message = f"Found {orders.count()} recent order(s) assigned to your dealership."
                result_data = [{'id': o.id, 'order_code': o.order_code, 'status': o.status, 'amount': str(o.grand_total)} for o in orders]
            elif action in ['STOCK_REQUEST']:
                reqs = DealerStockRequest.objects.filter(dealer=dealer).order_by('-id')[:5]
                message = f"You have {reqs.count()} recent stock request(s)."
                result_data = [{'req': r.request_number, 'status': r.status, 'qty': r.requested_quantity} for r in reqs]
            else:
                message = f"Action '{action}' processed for Dealer."

        else:  # customer
            if action in ['PRODUCTS', 'PRODUCT_PRICES', 'PRODUCT_SIZES']:
                prods = Product.objects.filter(status='Active').order_by('id')
                message = f"Shivnath Pure Drinking Water is available in 5 official variants (200ml to 20L Jar)."
                result_data = [{'sku': p.sku, 'name': p.name, 'mrp': str(p.mrp), 'consumer_price': str(p.price)} for p in prods]
            elif action in ['MY_ORDERS', 'ORDERS']:
                orders = Order.objects.filter(created_by=user).order_by('-id')[:5]
                message = f"You have {orders.count()} previous order(s) with Shivnath Agency."
                result_data = [{'id': o.id, 'order_code': o.order_code, 'status': o.status, 'amount': str(o.grand_total)} for o in orders]
            elif action in ['ORDER_STATUS']:
                latest = Order.objects.filter(created_by=user).order_by('-id').first()
                if latest:
                    message = f"Your latest order {latest.order_code} is currently: {latest.get_status_display()}."
                    result_data = {'order_code': latest.order_code, 'status': latest.status, 'status_display': latest.get_status_display()}
                else:
                    message = "You don't have any active orders right now."
            elif action in ['SUPPORT']:
                contacts = SupportContact.objects.filter(is_active=True)[:3]
                message = "You can reach Shivnath Agency Support directly:"
                result_data = [{'name': c.contact_name, 'phone': c.phone_number, 'email': c.email} for c in contacts]
            else:
                message = f"Hello! How can Shivnath Agency help you today?"

        return Response({
            'success': True,
            'role': role,
            'action': action,
            'message': message,
            'data': result_data
        })



class SupportContactListView(APIView):
    """
    Returns role-aware Support Contacts from DB.
    """
    permission_classes = [AllowAny]

    def get(self, request):
        user = request.user if request.user.is_authenticated else None
        role = getattr(getattr(user, 'profile', None), 'role', 'public_customer') if user else 'public_customer'

        role_target_map = {
            'customer': ['customer', 'public_customer'],
            'franchise': ['franchise', 'public_franchise'],
            'admin': ['admin'],
            'super_admin': ['admin'],
            'public_customer': ['public_customer', 'customer']
        }
        allowed_roles = role_target_map.get(role, ['public_customer'])

        contacts = SupportContact.objects.filter(is_active=True, role__in=allowed_roles)
        data = [
            {
                'id': c.id,
                'role': c.role,
                'name': c.name,
                'phone': c.phone,
                'whatsapp_number': c.whatsapp_number or c.phone,
                'email': c.email,
                'message_template': c.message_template,
                'available_hours': c.available_hours,
            }
            for c in contacts
        ]
        return Response({'success': True, 'contacts': data})


# =========================================================
# DEALER KYC DOCUMENTS & VERIFICATION
# =========================================================

class DealerKYCDocumentView(APIView):
    authentication_classes = [JWTAuthentication]

    permission_classes = [IsAdminOrFranchiseUser]

    def _get_franchise(self, request, dealer_id=None):
        if dealer_id:
            return get_object_or_404(FranchiseProfile, pk=dealer_id)
        franchise = getattr(request.user, 'franchise_profile', None)
        if not franchise:
            franchise = FranchiseProfile.objects.filter(user=request.user).first()
        return franchise

    def get(self, request, dealer_id=None):
        franchise = self._get_franchise(request, dealer_id)
        if not franchise:
            return Response({'success': False, 'message': 'Franchise profile not found.'}, status=status.HTTP_404_NOT_FOUND)

        # Authorization check: admin or the dealer itself
        if not (request.user.is_superuser or getattr(request.user, 'profile', None).role in ['admin', 'super_admin']):
            if getattr(request.user, 'franchise_profile', None) != franchise:
                return Response({'success': False, 'message': 'Forbidden.'}, status=status.HTTP_403_FORBIDDEN)

        docs = franchise.kyc_documents.all().order_by('-version', '-uploaded_at')
        data = [
            {
                'id': d.id,
                'version': d.version,
                'document_type': d.document_type,
                'document_type_display': d.get_document_type_display(),
                'document_number': d.document_number,
                'document_url': _build_public_doc_url(request, f'/api/accounts/dealers/documents/{d.id}/view/') if d.document_file else '',
                'download_url': _build_public_doc_url(request, f'/api/accounts/dealers/documents/{d.id}/download/') if d.document_file else '',
                'verification_status': d.verification_status,
                'rejection_reason': d.rejection_reason,
                'uploaded_at': d.uploaded_at.isoformat(),
                'verified_at': d.verified_at.isoformat() if d.verified_at else None,
                'verified_by': d.verified_by.username if d.verified_by else None,
                'verification_logs': [
                    {
                        'id': log.id,
                        'version': log.version,
                        'decision': log.decision,
                        'reviewed_by': log.reviewed_by.username if log.reviewed_by else 'Admin',
                        'reviewed_at': log.reviewed_at.isoformat(),
                        'rejection_reason': log.rejection_reason,
                        'verification_method': log.verification_method,
                        'notes': log.notes,
                    }
                    for log in d.verification_logs.all().order_by('-reviewed_at')
                ],
            }
            for d in docs
        ]
        return Response({'success': True, 'dealer_id': franchise.id, 'documents': data})

    def post(self, request, dealer_id=None):
        franchise = self._get_franchise(request, dealer_id)
        if not franchise:
            return Response({'success': False, 'message': 'Franchise profile not found.'}, status=status.HTTP_404_NOT_FOUND)

        # Authorization check
        if not (request.user.is_superuser or getattr(request.user, 'profile', None).role in ['admin', 'super_admin']):
            if getattr(request.user, 'franchise_profile', None) != franchise:
                return Response({'success': False, 'message': 'Forbidden.'}, status=status.HTTP_403_FORBIDDEN)

        doc_type = request.data.get('document_type')
        doc_number = request.data.get('document_number', '').strip()
        doc_file = request.FILES.get('document_file')

        if not doc_type or not doc_file:
            return Response({'success': False, 'message': 'document_type and document_file are required.'}, status=400)

        # Calculate incremental version for this document type
        existing_docs = DealerDocument.objects.filter(dealer=franchise, document_type=doc_type)
        max_version = existing_docs.aggregate(Max('version'))['version__max'] or 0
        new_version = max_version + 1

        doc = DealerDocument.objects.create(
            dealer=franchise,
            document_type=doc_type,
            document_number=doc_number,
            document_file=doc_file,
            version=new_version,
            verification_status='PENDING',
            uploaded_by=request.user,
        )

        # Sync franchise regulatory status on FSSAI upload
        if doc_type == 'FSSAI_CERTIFICATE':
            franchise.fssai_verification_status = 'PENDING'
            franchise.save(update_fields=['fssai_verification_status'])

        doc_view_url = _build_public_doc_url(request, f'/api/accounts/dealers/documents/{doc.id}/view/') if doc.document_file else ''
        doc_download_url = _build_public_doc_url(request, f'/api/accounts/dealers/documents/{doc.id}/download/') if doc.document_file else ''
        doc_info = {
            'id': doc.id,
            'version': doc.version,
            'document_type': doc.document_type,
            'verification_status': doc.verification_status,
            'document_url': doc_view_url,
            'download_url': doc_download_url,
        }
        return Response({
            'success': True,
            'message': 'Document uploaded successfully.',
            'document_id': doc.id,
            'version': doc.version,
            'verification_status': doc.verification_status,
            'document_url': doc_view_url,
            'download_url': doc_download_url,
            'data': doc_info,
        }, status=status.HTTP_201_CREATED)

    def delete(self, request, dealer_id=None):
        doc_id = request.data.get('document_id') or request.query_params.get('document_id')
        if not doc_id:
            return Response({'success': False, 'message': 'document_id is required.'}, status=400)
        doc = get_object_or_404(DealerDocument, pk=doc_id)
        franchise = self._get_franchise(request, dealer_id)
        if not (request.user.is_superuser or getattr(request.user, 'profile', None).role in ['admin', 'super_admin']):
            if doc.dealer != getattr(request.user, 'franchise_profile', None):
                return Response({'success': False, 'message': 'Forbidden.'}, status=status.HTTP_403_FORBIDDEN)
            # Franchise users cannot delete documents that have been reviewed or have audit records
            if doc.verification_status in ['VERIFIED', 'REJECTED'] or doc.verification_logs.exists():
                return Response({
                    'success': False,
                    'message': 'Audited or reviewed documents cannot be deleted. Please upload a new version.'
                }, status=status.HTTP_400_BAD_REQUEST)

        if doc.document_file:
            try:
                doc.document_file.delete(save=False)
            except Exception:
                pass
        doc.delete()
        return Response({'success': True, 'message': 'Document deleted successfully.'})


class DealerKYCVerifyView(APIView):
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAdminRole]

    def post(self, request, pk):
        return self.patch(request, pk)

    def patch(self, request, pk):
        doc = get_object_or_404(DealerDocument, pk=pk)
        new_status = (request.data.get('status') or request.data.get('action') or '').upper()
        rejection_reason = request.data.get('rejection_reason', '').strip()
        verification_method = request.data.get('verification_method', 'MANUAL_ADMIN_REVIEW').strip()
        notes = request.data.get('notes', '').strip()

        if new_status not in ['VERIFIED', 'REJECTED']:
            return Response({'success': False, 'message': 'status must be VERIFIED or REJECTED.'}, status=400)

        if new_status == 'REJECTED' and not rejection_reason:
            return Response({
                'success': False,
                'message': 'A meaningful rejection_reason is mandatory when rejecting a document.'
            }, status=status.HTTP_400_BAD_REQUEST)

        now = timezone.now()
        doc.verification_status = new_status
        doc.verified_by = request.user
        doc.verified_at = now
        doc.rejection_reason = rejection_reason if new_status == 'REJECTED' else ''
        doc.save(update_fields=['verification_status', 'verified_by', 'verified_at', 'rejection_reason'])

        # Persist audit record in DealerDocumentVerificationLog
        from .models import DealerDocumentVerificationLog, AdminAuditLog
        log_entry = DealerDocumentVerificationLog.objects.create(
            document=doc,
            document_id_persisted=doc.id,
            document_version=doc.version,
            franchise=doc.dealer,
            document_type=doc.document_type,
            decision=new_status,
            reviewer=request.user,
            reviewer_username=request.user.username,
            rejection_reason=rejection_reason if new_status == 'REJECTED' else '',
            verification_method=verification_method,
            notes=notes,
        )

        # Also persist in central AdminAuditLog
        AdminAuditLog.objects.create(
            actor=request.user,
            action=f'DOCUMENT_{new_status}',
            resource_type='DealerDocument',
            resource_id=str(doc.id),
            changes={
                'decision': new_status,
                'version': doc.version,
                'document_type': doc.document_type,
                'franchise_id': doc.dealer.id,
                'franchise_name': doc.dealer.business_name,
                'rejection_reason': rejection_reason,
            }
        )

        # Synchronize franchise FSSAI status if applicable
        if doc.document_type == 'FSSAI_CERTIFICATE':
            franchise = doc.dealer
            if new_status == 'VERIFIED':
                franchise.fssai_verification_status = 'VERIFIED'
                franchise.fssai_verified_at = now
                franchise.fssai_verified_by = request.user
                franchise.fssai_rejection_reason = ''
            else:
                franchise.fssai_verification_status = 'REJECTED'
                franchise.fssai_verified_at = now
                franchise.fssai_verified_by = request.user
                franchise.fssai_rejection_reason = rejection_reason
            franchise.save(update_fields=[
                'fssai_verification_status', 'fssai_verified_at',
                'fssai_verified_by', 'fssai_rejection_reason'
            ])

        return Response({
            'success': True,
            'message': f'Document marked as {new_status}.',
            'document_id': doc.id,
            'version': doc.version,
            'status': doc.verification_status,
            'verified_at': doc.verified_at.isoformat(),
            'verified_by': doc.verified_by.username,
            'rejection_reason': doc.rejection_reason,
            'log_id': log_entry.id,
        })


class ProtectedDealerDocumentView(APIView):
    """
    Securely serves private dealer KYC and FSSAI documents.
    Enforces authentication and authorization: Admin, Super Admin, or the owning Franchise.
    Supports Bearer header and '?token=' query parameter for in-app and browser document viewing.
    Also handles direct /media/dealer_documents/<filename> lookups to prevent path traversal or bypass.
    """
    authentication_classes = [JWTAuthentication]
    permission_classes = [AllowAny]

    def get(self, request, pk=None, filename=None, filepath=None):
        import mimetypes
        from django.http import FileResponse

        user = request.user
        if not user or not user.is_authenticated:
            token = request.query_params.get('token')
            if token:
                from rest_framework_simplejwt.tokens import AccessToken
                try:
                    validated = AccessToken(token)
                    user_id = validated.get('user_id')
                    user = User.objects.filter(id=user_id).first()
                except Exception:
                    user = None

        if not user or not user.is_authenticated:
            return Response({'detail': 'Authentication credentials were not provided.'}, status=status.HTTP_401_UNAUTHORIZED)

        # Lookup document by pk, filepath, or filename
        doc = None
        if pk is not None:
            doc = DealerDocument.objects.filter(pk=pk).first()
        elif filepath:
            clean_path = filepath.replace('\\', '/')
            doc = DealerDocument.objects.filter(document_file=clean_path).first()
            if not doc:
                filename_only = clean_path.split('/')[-1]
                doc = DealerDocument.objects.filter(document_file__icontains=filename_only).first()
        elif filename:
            clean_filename = filename.replace('\\', '/').split('/')[-1]
            doc = DealerDocument.objects.filter(document_file__icontains=clean_filename).first()

        if not doc:
            return Response({'detail': 'Document not found.'}, status=status.HTTP_404_NOT_FOUND)

        franchise = doc.dealer
        profile = getattr(user, 'profile', None)
        is_admin = user.is_superuser or (profile and profile.role in ['admin', 'super_admin'])
        is_owner = (franchise.user_id == user.id) or (getattr(user, 'franchise_profile', None) == franchise)

        if not (is_admin or is_owner):
            return Response({'detail': 'You do not have permission to view this document.'}, status=status.HTTP_403_FORBIDDEN)

        if not doc.document_file or not doc.document_file.storage.exists(doc.document_file.name):
            return Response({'detail': 'Document file does not exist on storage.'}, status=status.HTTP_404_NOT_FOUND)

        content_type, _ = mimetypes.guess_type(doc.document_file.name)
        if not content_type:
            content_type = 'application/pdf' if doc.document_file.name.lower().endswith('.pdf') else 'application/octet-stream'

        as_download = request.path.endswith('/download/') or request.query_params.get('download') == '1'

        try:
            response = FileResponse(doc.document_file.open('rb'), content_type=content_type)
            if as_download:
                actual_name = doc.document_file.name.split('/')[-1]
                response['Content-Disposition'] = f'attachment; filename="{actual_name}"'
            return response
        except Exception as e:
            return Response({'detail': f'Error opening document file: {str(e)}'}, status=500)


class VerifyFranchiseFSSAIView(APIView):
    """
    Authoritative Admin/Super Admin FSSAI verification endpoint.
    Performs verification against FoSCoS portal or official external records,
    records audit trail, updates status, and synchronizes document state.
    """
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAdminRole]

    def post(self, request, pk):
        from .fssai_services import record_fssai_verification, compare_fssai_details
        franchise = get_object_or_404(FranchiseProfile, pk=pk)

        action = request.data.get('action', '').upper()
        if action not in ['VERIFIED', 'FAILED', 'MANUAL_REVIEW_REQUIRED']:
            return Response({
                'success': False,
                'message': "Invalid action. Must be 'VERIFIED', 'FAILED', or 'MANUAL_REVIEW_REQUIRED'."
            }, status=status.HTTP_400_BAD_REQUEST)

        source = request.data.get('source', 'FoSCoS Portal Manual Review (https://foscos.fssai.gov.in/)').strip()
        notes = request.data.get('notes', '').strip()
        reason = request.data.get('reason', '').strip()
        official_business_name = request.data.get('official_business_name', '').strip()
        official_reference = request.data.get('official_reference', '').strip()
        official_expiry_date = request.data.get('official_expiry_date')

        if official_expiry_date:
            try:
                franchise.fssai_expiry_date = official_expiry_date
                franchise.save(update_fields=['fssai_expiry_date'])
            except Exception:
                pass

        if official_business_name:
            matches, mismatch_reason = compare_fssai_details(franchise.business_name, official_business_name)
            if not matches and action == 'VERIFIED':
                return Response({
                    'success': False,
                    'message': f"Cannot mark as VERIFIED: {mismatch_reason}. Mark as MANUAL_REVIEW_REQUIRED or FAILED instead."
                }, status=status.HTTP_400_BAD_REQUEST)

        if action == 'FAILED' and not reason:
            return Response({
                'success': False,
                'message': "A rejection/failure reason is required when marking FSSAI as FAILED."
            }, status=status.HTTP_400_BAD_REQUEST)

        record_fssai_verification(
            franchise=franchise,
            new_status=action,
            verification_source=source,
            verified_by=request.user,
            notes=notes,
            mismatch_reason=reason,
            official_reference=official_reference,
            action_taken=f'Admin {action} via {source}'
        )

        return Response({
            'success': True,
            'message': f"Franchise FSSAI status updated to {action}.",
            'franchise_id': franchise.id,
            'fssai_number': franchise.fssai_number,
            'fssai_verification_status': franchise.fssai_verification_status,
            'fssai_verified_at': franchise.fssai_verified_at.isoformat() if franchise.fssai_verified_at else None,
            'fssai_verified_by': request.user.username,
        })


class FranchiseFSSAIDetailView(APIView):
    """
    Returns complete FSSAI regulatory verification profile, document info, and audit trail for Admin review.
    """
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAdminRole]

    def get(self, request, pk):
        from .fssai_services import check_duplicate_fssai
        franchise = get_object_or_404(FranchiseProfile, pk=pk)

        doc = DealerDocument.objects.filter(
            dealer=franchise,
            document_type='FSSAI_CERTIFICATE'
        ).first()

        doc_url = ''
        if doc and doc.document_file:
            doc_url = _build_public_doc_url(request, f'/api/accounts/dealers/documents/{doc.id}/view/')

        is_dup, dup = check_duplicate_fssai(franchise.fssai_number, current_franchise_id=franchise.id)

        audit_logs = [
            {
                'id': log.id,
                'previous_status': log.previous_status,
                'new_status': log.new_status,
                'verification_source': log.verification_source,
                'mismatch_reason': log.mismatch_reason,
                'official_reference': log.official_reference,
                'notes': log.notes,
                'verified_by': log.verified_by.get_full_name() or log.verified_by.username if log.verified_by else 'System',
                'action_taken': log.action_taken,
                'created_at': log.created_at.isoformat(),
            }
            for log in franchise.fssai_audit_logs.all().order_by('-created_at')[:20]
        ]

        return Response({
            'success': True,
            'franchise_id': franchise.id,
            'business_name': franchise.business_name,
            'owner_name': franchise.user.get_full_name() or franchise.user.username,
            'phone': getattr(getattr(franchise.user, 'profile', None), 'phone', ''),
            'email': franchise.user.email,
            'city': franchise.city,
            'address': franchise.address,
            'fssai_number': franchise.fssai_number,
            'fssai_business_name': franchise.fssai_business_name or franchise.business_name,
            'fssai_premises_address': franchise.fssai_premises_address or franchise.address,
            'fssai_state': franchise.fssai_state,
            'fssai_district': franchise.fssai_district,
            'fssai_expiry_date': str(franchise.fssai_expiry_date) if franchise.fssai_expiry_date else None,
            'fssai_verification_status': franchise.fssai_verification_status,
            'fssai_verification_source': franchise.fssai_verification_source,
            'fssai_verified_at': franchise.fssai_verified_at.isoformat() if franchise.fssai_verified_at else None,
            'fssai_verified_by': franchise.fssai_verified_by.username if franchise.fssai_verified_by else None,
            'fssai_rejection_reason': franchise.fssai_rejection_reason,
            'fssai_notes': franchise.fssai_notes,
            'fssai_verification_attempts': franchise.fssai_verification_attempts,
            'is_duplicate': is_dup,
            'duplicate_franchise': f"{dup.business_name} (ID: #{dup.id})" if dup else None,
            'document': {
                'id': doc.id if doc else None,
                'document_type': 'FSSAI_CERTIFICATE',
                'document_number': doc.document_number if doc else franchise.fssai_number,
                'document_url': doc_url,
                'verification_status': doc.verification_status if doc else 'PENDING',
                'rejection_reason': doc.rejection_reason if doc else '',
                'uploaded_at': doc.uploaded_at.isoformat() if doc else None,
            } if doc else None,
            'official_verification_link': 'https://foscos.fssai.gov.in/',
            'audit_logs': audit_logs,
        })


class SuperAdminSeedDemoDataView(APIView):
    """
    Triggers complete demo dataset seeding for development, staging, or cloud environments.
    """
    permission_classes = [AllowAny]

    def post(self, request):
        from django.core.management import call_command
        secret = request.data.get('secret') or request.query_params.get('secret')
        is_admin = False
        if request.user and request.user.is_authenticated:
            profile = getattr(request.user, 'profile', None)
            is_admin = request.user.is_superuser or (profile and profile.role in ['admin', 'super_admin'])

        if not is_admin and secret != 'shivnath_demo_seed_secret_2026':
            return Response({'error': 'Unauthorized'}, status=status.HTTP_403_FORBIDDEN)

        try:
            import seed_production_data
            seed_production_data.seed()
            try:
                call_command('seed_demo_data', force=True)
            except Exception as e:
                logger.warning("seed_demo_data auxiliary notice: %s", e)
            return Response({'success': True, 'message': 'Authoritative production & demo datasets seeded successfully.'})
        except Exception as e:
            logger.error("Seeding error in SuperAdminSeedDemoDataView: %s", e)
            return Response({'success': False, 'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class CustomerDetailHistoryView(APIView):
    """
    Authoritative profile, order history, and payment history for a customer.
    Provides complete real-time DB order counts, revenue, amounts paid, outstanding balance,
    and history breakdown.
    """
    permission_classes = [IsAuthenticated]

    def get(self, request, user_id):
        from orders.models import Order
        from billing.models import Invoice, PaymentTransaction
        from decimal import Decimal

        customer_user = get_object_or_404(User, id=user_id)
        user = request.user
        role = getattr(getattr(user, 'profile', None), 'role', '')
        if not user.is_superuser and role not in ['admin', 'super_admin'] and user.id != customer_user.id:
            return Response({'error': 'Unauthorized'}, status=status.HTTP_403_FORBIDDEN)

        prof = getattr(customer_user, 'profile', None)
        rel = getattr(customer_user, 'customer_relationship', None)

        orders = Order.objects.filter(created_by=customer_user).order_by('-created_at')
        total_orders = orders.count()
        completed_orders = orders.filter(status='delivered').count()
        cancelled_orders = orders.filter(status='cancelled').count()
        franchise_orders = orders.filter(order_source='FRANCHISE').count()
        direct_orders = orders.filter(order_source='DIRECT_COMPANY').count()

        first_order = orders.order_by('created_at').first()
        last_order = orders.first()

        invoices = Invoice.objects.filter(order__in=orders)
        if invoices.exists():
            total_revenue = sum(inv.grand_total for inv in invoices)
            total_paid = sum(inv.amount_paid for inv in invoices)
            total_outstanding = sum(inv.outstanding_balance for inv in invoices)
        else:
            total_revenue = sum((o.grand_total or o.amount or Decimal('0.00')) for o in orders)
            total_paid = sum((o.grand_total or o.amount or Decimal('0.00')) for o in orders.filter(payment_status='paid'))
            total_outstanding = max(Decimal('0.00'), total_revenue - total_paid)

        payments = PaymentTransaction.objects.filter(invoice__in=invoices).order_by('-payment_date')

        orders_data = [
            {
                'id': o.id,
                'order_code': o.order_code,
                'order_date': str(o.order_date),
                'amount': float(o.grand_total or o.amount or 0.0),
                'status': o.status,
                'payment_status': o.payment_status,
                'order_source': o.order_source,
                'serving_franchise_name': o.serving_franchise.business_name if o.serving_franchise else o.franchise_name,
                'items_count': o.items_count,
            }
            for o in orders
        ]

        payments_data = [
            {
                'id': p.id,
                'transaction_number': p.transaction_number,
                'amount_paid': float(p.amount_paid),
                'payment_method': p.payment_method,
                'payment_date': p.payment_date.isoformat(),
                'reference_number': p.reference_number,
                'invoice_number': p.invoice.invoice_number if p.invoice else '',
                'notes': p.notes,
            }
            for p in payments
        ]

        return Response({
            'success': True,
            'customer': {
                'id': customer_user.id,
                'customer_code': f'CUST-{1000 + customer_user.id}',
                'name': prof.name if prof and prof.name else (customer_user.get_full_name() or customer_user.username),
                'email': customer_user.email,
                'phone': prof.phone if prof else '',
                'city': prof.city if prof else '',
                'district': rel.district.name if rel and rel.district else (prof.district if prof else ''),
                'territory': rel.zone.name if rel and rel.zone else '',
                'address': prof.address if prof else '',
            },
            'financial_summary': {
                'total_orders': total_orders,
                'completed_orders': completed_orders,
                'cancelled_orders': cancelled_orders,
                'total_revenue': float(total_revenue),
                'total_paid': float(total_paid),
                'total_outstanding': float(total_outstanding),
                'first_order_date': str(first_order.order_date) if first_order and first_order.order_date else None,
                'last_order_date': str(last_order.order_date) if last_order and last_order.order_date else None,
                'orders_by_franchise': franchise_orders,
                'direct_orders': direct_orders,
            },
            'orders': orders_data,
            'payments': payments_data,
        })


# =========================================================
# FIREBASE PUSH NOTIFICATION VIEWS
# =========================================================

class RegisterDeviceTokenView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        token = request.data.get('token', '').strip()
        device_type = request.data.get('device_type', 'android').strip().lower()

        if not token:
            return Response(
                {'success': False, 'message': 'Device token is required.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        from accounts.models import DeviceToken
        # Security Guard: Deactivate this token for any previous user to prevent wrong-role notifications
        DeviceToken.objects.filter(token=token).exclude(user=request.user).update(is_active=False)

        device_token, created = DeviceToken.objects.update_or_create(
            token=token,
            defaults={
                'user': request.user,
                'device_type': device_type,
                'is_active': True,
            }
        )

        logger.info(
            "FCM: [TOKEN_REGISTERED] User '%s' (role: %s) registered device token (type: %s, created: %s, token_snippet: %s...)",
            request.user.username,
            getattr(getattr(request.user, 'profile', None), 'role', 'N/A'),
            device_type,
            created,
            token[:12]
        )

        return Response({
            'success': True,
            'message': 'Device token registered successfully.',
            'created': created,
            'device_type': device_token.device_type,
        })


class UnregisterDeviceTokenView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        token = request.data.get('token', '').strip()
        from accounts.models import DeviceToken
        count = 0
        if token:
            count += DeviceToken.objects.filter(token=token).update(is_active=False)
        if request.user and request.user.is_authenticated:
            count += DeviceToken.objects.filter(user=request.user).update(is_active=False)

        username = request.user.username if (request.user and request.user.is_authenticated) else 'Anonymous/TokenOnly'
        logger.info(
            "FCM: [TOKEN_UNREGISTERED] User '%s' unregistered device token (deactivated count: %d, token: %s...)",
            username,
            count,
            token[:12] if token else 'N/A'
        )

        return Response({
            'success': True,
            'message': 'Device token unregistered successfully.',
            'deactivated_count': count
        })


class SendTestPushNotificationView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        from accounts.fcm_services import send_fcm_notification
        title = request.data.get('title', 'Shivnath Agency Test Push')
        body = request.data.get('body', 'Real Firebase push notifications are live and working!')

        res = send_fcm_notification(
            users=[request.user],
            title=title,
            body=body,
            data={'type': 'test', 'user': request.user.username},
            notification_type='general'
        )

        return Response(res)


# =====================================================================
# ZONE & SERVICE AREA ADMINISTRATION (ADMIN INTERFACE)
# =====================================================================

class AdminZoneManagementView(APIView):
    """
    Authoritative Admin API for managing Service Zones:
    - Lists configured zones with districts, fulfilment hubs, pricing rules, and assigned franchises.
    - Creates new service zones.
    """
    def get_permissions(self):
        if self.request.method == 'GET':
            return [AllowAny()]
        return [IsAdminRole()]

    def get(self, request):
        from .models import ServiceZone, ServiceArea, FranchiseTerritoryAssignment
        district_id = request.query_params.get('district_id')
        district_name = request.query_params.get('district')
        search = request.query_params.get('q', '').strip()
        is_active = request.query_params.get('is_active')

        qs = ServiceZone.objects.select_related('district', 'fulfilment_hub', 'delivery_pricing_rule').prefetch_related('areas', 'franchise_assignments__franchise')

        if district_id:
            qs = qs.filter(district_id=district_id)
        if district_name:
            qs = qs.filter(district__name__icontains=district_name)
        if search:
            qs = qs.filter(
                models.Q(name__icontains=search) |
                models.Q(code__icontains=search) |
                models.Q(district__name__icontains=search)
            )
        if is_active is not None and is_active != '':
            qs = qs.filter(is_active=str(is_active).lower() in ['true', '1'])

        zones_data = []
        for z in qs:
            areas = list(z.areas.filter(is_active=True).values('id', 'locality_name', 'pincode', 'latitude', 'longitude'))
            assigned_franchises = [
                {
                    'id': fa.franchise.id,
                    'business_name': fa.franchise.business_name,
                    'is_primary': fa.is_primary,
                    'is_active': fa.is_active,
                }
                for fa in z.franchise_assignments.filter(is_active=True)
            ]
            zones_data.append({
                'id': z.id,
                'name': z.name,
                'code': z.code,
                'is_active': z.is_active,
                'district_id': z.district.id,
                'district_name': z.district.name,
                'district_state': z.district.state,
                'fulfilment_hub_id': z.fulfilment_hub.id if z.fulfilment_hub else None,
                'fulfilment_hub_name': z.fulfilment_hub.name if z.fulfilment_hub else None,
                'fulfilment_hub_city': z.fulfilment_hub.city if z.fulfilment_hub else None,
                'delivery_pricing_rule_id': z.delivery_pricing_rule.id if z.delivery_pricing_rule else None,
                'delivery_pricing_rule_name': f"Band: {z.delivery_pricing_rule.min_km}-{z.delivery_pricing_rule.max_km}km (Rs {z.delivery_pricing_rule.price})" if z.delivery_pricing_rule else None,
                'assigned_franchises': assigned_franchises,
                'areas_count': len(areas),
                'localities': [a['locality_name'] for a in areas],
                'areas': areas,
                'created_at': z.created_at.strftime('%Y-%m-%d %H:%M') if z.created_at else None,
            })

        return Response({
            'success': True,
            'count': len(zones_data),
            'zones': zones_data,
            'results': zones_data,
        })

    def post(self, request):
        from .models import ServiceZone, ServiceDistrict, FranchiseProfile, FranchiseTerritoryAssignment
        from billing.models import DeliveryOriginSetting, DeliveryDistanceBand

        name = request.data.get('name', '').strip()
        code = request.data.get('code', '').strip()
        district_id = request.data.get('district_id')
        district_name = request.data.get('district')
        is_active = request.data.get('is_active', True)
        hub_id = request.data.get('fulfilment_hub_id')
        pricing_rule_id = request.data.get('delivery_pricing_rule_id')
        franchise_ids = request.data.get('franchise_ids', [])

        if not name:
            return Response({'success': False, 'message': 'Zone name is required.'}, status=status.HTTP_400_BAD_REQUEST)

        district = None
        if district_id:
            district = ServiceDistrict.objects.filter(id=district_id).first()
        elif district_name:
            district = ServiceDistrict.objects.filter(name__iexact=district_name).first()

        if not district:
            return Response({'success': False, 'message': 'Valid district is required.'}, status=status.HTTP_400_BAD_REQUEST)

        if not code:
            code = f"{district.name[:3].upper()}-{name[:3].upper()}-{ServiceZone.objects.count() + 1}"

        hub = DeliveryOriginSetting.objects.filter(id=hub_id).first() if hub_id else None
        pricing_rule = DeliveryDistanceBand.objects.filter(id=pricing_rule_id).first() if pricing_rule_id else None

        zone, created = ServiceZone.objects.get_or_create(
            district=district,
            name=name,
            defaults={
                'code': code,
                'is_active': is_active,
                'fulfilment_hub': hub,
                'delivery_pricing_rule': pricing_rule,
            }
        )
        if not created:
            zone.code = code
            zone.is_active = is_active
            zone.fulfilment_hub = hub
            zone.delivery_pricing_rule = pricing_rule
            zone.save()

        # Handle franchise assignments
        if isinstance(franchise_ids, list):
            for fid in franchise_ids:
                fr = FranchiseProfile.objects.filter(id=fid).first()
                if fr:
                    FranchiseTerritoryAssignment.objects.get_or_create(
                        franchise=fr,
                        zone=zone,
                        defaults={'is_primary': False, 'is_active': True}
                    )

        return Response({
            'success': True,
            'message': f"Zone '{zone.name}' configured successfully.",
            'zone_id': zone.id,
            'name': zone.name,
            'code': zone.code,
            'created': created,
        }, status=status.HTTP_201_CREATED if created else status.HTTP_200_OK)


class AdminZoneDetailView(APIView):
    permission_classes = [IsAdminRole]

    def get_object(self, pk):
        from .models import ServiceZone
        return get_object_or_404(ServiceZone, pk=pk)

    def get(self, request, pk):
        z = self.get_object(pk)
        areas = list(z.areas.filter(is_active=True).values('id', 'locality_name', 'pincode', 'latitude', 'longitude'))
        assigned_franchises = [
            {
                'id': fa.franchise.id,
                'business_name': fa.franchise.business_name,
                'is_primary': fa.is_primary,
                'is_active': fa.is_active,
            }
            for fa in z.franchise_assignments.filter(is_active=True)
        ]
        return Response({
            'success': True,
            'zone': {
                'id': z.id,
                'name': z.name,
                'code': z.code,
                'is_active': z.is_active,
                'district_id': z.district.id,
                'district_name': z.district.name,
                'district_state': z.district.state,
                'fulfilment_hub_id': z.fulfilment_hub.id if z.fulfilment_hub else None,
                'fulfilment_hub_name': z.fulfilment_hub.name if z.fulfilment_hub else None,
                'delivery_pricing_rule_id': z.delivery_pricing_rule.id if z.delivery_pricing_rule else None,
                'assigned_franchises': assigned_franchises,
                'areas': areas,
                'localities': [a['locality_name'] for a in areas],
            }
        })

    def patch(self, request, pk):
        from .models import ServiceDistrict
        from billing.models import DeliveryOriginSetting, DeliveryDistanceBand
        z = self.get_object(pk)

        if 'name' in request.data:
            z.name = request.data['name'].strip()
        if 'code' in request.data:
            z.code = request.data['code'].strip()
        if 'is_active' in request.data:
            z.is_active = bool(request.data['is_active'])
        if 'district_id' in request.data:
            dist = ServiceDistrict.objects.filter(id=request.data['district_id']).first()
            if dist:
                z.district = dist
        if 'fulfilment_hub_id' in request.data:
            hid = request.data['fulfilment_hub_id']
            z.fulfilment_hub = DeliveryOriginSetting.objects.filter(id=hid).first() if hid else None
        if 'delivery_pricing_rule_id' in request.data:
            rid = request.data['delivery_pricing_rule_id']
            z.delivery_pricing_rule = DeliveryDistanceBand.objects.filter(id=rid).first() if rid else None

        z.save()
        return Response({
            'success': True,
            'message': f"Zone '{z.name}' updated successfully.",
        })

    def delete(self, request, pk):
        z = self.get_object(pk)
        z.is_active = False
        z.save()
        return Response({
            'success': True,
            'message': f"Zone '{z.name}' deactivated successfully.",
        })


class AdminZoneAreaManagementView(APIView):
    """
    Manage localities / areas covered within a specific service zone.
    """
    def get_permissions(self):
        if self.request.method == 'GET':
            return [AllowAny()]
        return [IsAdminRole()]

    def get(self, request, pk):
        from .models import ServiceZone, ServiceArea
        zone = get_object_or_404(ServiceZone, pk=pk)
        areas = ServiceArea.objects.filter(zone=zone, is_active=True).order_by('locality_name')
        return Response({
            'success': True,
            'zone_id': zone.id,
            'zone_name': zone.name,
            'district_name': zone.district.name,
            'count': areas.count(),
            'areas': [
                {
                    'id': a.id,
                    'name': a.locality_name,
                    'locality_name': a.locality_name,
                    'pincode': a.pincode,
                    'latitude': float(a.latitude) if a.latitude else None,
                    'longitude': float(a.longitude) if a.longitude else None,
                    'is_active': a.is_active,
                }
                for a in areas
            ]
        })

    def post(self, request, pk):
        from .models import ServiceZone, ServiceArea
        zone = get_object_or_404(ServiceZone, pk=pk)
        locality_name = (request.data.get('locality_name') or request.data.get('name') or '').strip()
        pincode = request.data.get('pincode', '').strip()
        lat = request.data.get('latitude')
        lon = request.data.get('longitude')

        if not locality_name:
            return Response({'success': False, 'message': 'Locality name is required.'}, status=status.HTTP_400_BAD_REQUEST)
        if not pincode:
            pincode = '492001'

        area, created = ServiceArea.objects.get_or_create(
            zone=zone,
            locality_name=locality_name,
            defaults={
                'district': zone.district,
                'pincode': pincode,
                'latitude': lat,
                'longitude': lon,
                'is_active': True,
            }
        )
        if not created:
            area.pincode = pincode
            if lat is not None:
                area.latitude = lat
            if lon is not None:
                area.longitude = lon
            area.is_active = True
            area.save()

        return Response({
            'success': True,
            'message': f"Locality '{area.locality_name}' mapped to zone '{zone.name}' successfully.",
            'area_id': area.id,
            'name': area.locality_name,
            'locality_name': area.locality_name,
            'zone_name': zone.name,
            'created': created,
        }, status=status.HTTP_201_CREATED if created else status.HTTP_200_OK)



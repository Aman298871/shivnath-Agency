import os
import logging
from django.http import HttpResponse, FileResponse, Http404

logger = logging.getLogger(__name__)
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.parsers import MultiPartParser, FormParser, JSONParser
from rest_framework_simplejwt.authentication import JWTAuthentication
from django.shortcuts import get_object_or_404
from django.db.models import Count, Max, Q
from django.utils import timezone

from .services import AIService
from .models import ChatSession, ChatMessage, ChatbotOption, Quotation
from .serializers import ChatbotOptionSerializer, QuotationSerializer
from accounts.permissions import IsAdminRole


# =========================================================
# PUBLIC CHATBOT OPTIONS HIERARCHY
# =========================================================

class ChatbotOptionListView(APIView):
    """
    Public endpoint providing dynamic chatbot option hierarchies.
    """
    permission_classes = [AllowAny]

    def get(self, request):
        inquiry_type = request.query_params.get("inquiry_type", "").strip().lower()
        parent_id = request.query_params.get("parent_id", "").strip()
        tree_mode = request.query_params.get("tree", "").strip().lower() in ["true", "1"]

        queryset = ChatbotOption.objects.filter(is_active=True).order_by("order", "title")

        if inquiry_type == "customer":
            # STRICT CUSTOMER TREE: Never show quotation or franchise options
            queryset = queryset.filter(Q(inquiry_type="customer") | Q(inquiry_type="both")).exclude(
                Q(title__icontains="quotation") | Q(title__icontains="franchise")
            )
        elif inquiry_type == "franchise":
            # STRICT FRANCHISE TREE: Franchise options only
            queryset = queryset.filter(Q(inquiry_type="franchise") | Q(inquiry_type="both"))

        context = {'request': request, 'inquiry_type': inquiry_type}
        if parent_id and parent_id.isdigit():
            # Return sub-options of selected parent
            queryset = queryset.filter(parent_id=int(parent_id))
            serializer = ChatbotOptionSerializer(queryset, many=True, context=context)
        elif tree_mode:
            # Return root tree nodes with nested children
            root_options = queryset.filter(parent__isnull=True)
            serializer = ChatbotOptionSerializer(root_options, many=True, context=context)
        else:
            # Return root options (level 1)
            root_options = queryset.filter(parent__isnull=True)
            serializer = ChatbotOptionSerializer(root_options, many=True, context=context)

        return Response({
            "success": True,
            "count": queryset.count(),
            "options": serializer.data,
        }, status=status.HTTP_200_OK)


# =========================================================
# ADMIN CHATBOT MANAGEMENT (CRUD)
# =========================================================

class AdminChatbotOptionListView(APIView):
    permission_classes = [IsAdminRole]

    def get(self, request):
        inquiry_type = request.query_params.get("inquiry_type", "").strip().lower()
        queryset = ChatbotOption.objects.select_related("parent", "product", "quotation").all().order_by("order", "title")

        if inquiry_type in ["customer", "franchise"]:
            queryset = queryset.filter(Q(inquiry_type=inquiry_type) | Q(inquiry_type="both"))

        serializer = ChatbotOptionSerializer(queryset, many=True)
        return Response({
            "success": True,
            "count": queryset.count(),
            "options": serializer.data,
        }, status=status.HTTP_200_OK)

    def post(self, request):
        serializer = ChatbotOptionSerializer(data=request.data)
        if not serializer.is_valid():
            return Response({"success": False, "errors": serializer.errors}, status=status.HTTP_400_BAD_REQUEST)

        option = serializer.save()
        return Response({
            "success": True,
            "message": "Chatbot option created successfully.",
            "option": ChatbotOptionSerializer(option).data,
        }, status=status.HTTP_201_CREATED)


class AdminChatbotOptionDetailView(APIView):
    permission_classes = [IsAdminRole]

    def get(self, request, pk):
        option = get_object_or_404(ChatbotOption.objects.select_related("parent", "product", "quotation"), pk=pk)
        return Response({
            "success": True,
            "option": ChatbotOptionSerializer(option).data,
        }, status=status.HTTP_200_OK)

    def patch(self, request, pk):
        option = get_object_or_404(ChatbotOption, pk=pk)
        serializer = ChatbotOptionSerializer(option, data=request.data, partial=True)
        if not serializer.is_valid():
            return Response({"success": False, "errors": serializer.errors}, status=status.HTTP_400_BAD_REQUEST)

        updated = serializer.save()
        return Response({
            "success": True,
            "message": "Chatbot option updated successfully.",
            "option": ChatbotOptionSerializer(updated).data,
        }, status=status.HTTP_200_OK)

    def delete(self, request, pk):
        option = get_object_or_404(ChatbotOption, pk=pk)
        title = option.title
        option.delete()
        return Response({
            "success": True,
            "message": f"Chatbot option '{title}' deleted successfully.",
        }, status=status.HTTP_200_OK)


# =========================================================
# QUOTATION MANAGEMENT (FRANCHISE ONLY & ADMIN ACCESS)
# =========================================================

def get_user_role(user):
    if not user or not user.is_authenticated:
        return 'anonymous'
    if user.is_superuser or user.is_staff:
        return 'admin'
    prof = getattr(user, 'profile', None) or getattr(user, 'userprofile', None)
    if prof and prof.role in ['admin', 'super_admin', 'superadmin']:
        return 'admin'
    if hasattr(user, 'franchise_profile'):
        return 'franchise'
    if prof and prof.role == 'franchise':
        return 'franchise'
    return 'customer'


class QuotationListCreateView(APIView):
    parser_classes = [MultiPartParser, FormParser, JSONParser]
    permission_classes = [IsAuthenticated]

    def get(self, request):
        role = get_user_role(request.user)
        if role == 'customer':
            return Response({
                "success": False,
                "message": "Access Denied: Quotations are exclusively accessible to Franchises and Administrators.",
            }, status=status.HTTP_403_FORBIDDEN)

        status_param = request.query_params.get("status", "").strip().lower()
        quotation_type = request.query_params.get("type", "").strip().lower()
        franchise_id_param = request.query_params.get("franchise_id", "").strip()

        queryset = Quotation.objects.select_related("product", "franchise").all().order_by("-updated_at")

        if role == 'franchise':
            f_profile = getattr(request.user, 'franchise_profile', None)
            if not f_profile:
                return Response({
                    "success": False,
                    "message": "Franchise profile not found for authenticated user.",
                }, status=status.HTTP_403_FORBIDDEN)
            # Franchise can strictly view ONLY their own quotations and never drafts
            queryset = queryset.filter(franchise=f_profile).exclude(status='draft')
        elif role == 'admin':
            if franchise_id_param and franchise_id_param.isdigit():
                queryset = queryset.filter(franchise_id=int(franchise_id_param))

        # Check for expired quotations dynamically
        now_date = timezone.now().date()
        for q in queryset.filter(status='published', valid_until__isnull=False, valid_until__lt=now_date):
            q.status = 'expired'
            q.status_history.append({
                "action": "expired",
                "timestamp": timezone.now().isoformat(),
                "reason": f"Validity expired on {q.valid_until}"
            })
            q.save(update_fields=['status', 'status_history'])

        if status_param:
            if status_param in ['new', 'pending']:
                queryset = queryset.filter(status='published')
            else:
                queryset = queryset.filter(status=status_param)

        if quotation_type:
            queryset = queryset.filter(quotation_type=quotation_type)

        serializer = QuotationSerializer(queryset, many=True, context={'request': request})
        return Response({
            "success": True,
            "count": queryset.count(),
            "quotations": serializer.data,
        }, status=status.HTTP_200_OK)

    def post(self, request):
        role = get_user_role(request.user)
        if role != 'admin':
            return Response({
                "success": False,
                "message": "Permission Denied: Only Administrators can create and issue quotations.",
            }, status=status.HTTP_403_FORBIDDEN)

        data = request.data.copy()
        # Enforce Franchise assignment validation
        franchise_id = data.get('franchise') or data.get('franchise_id')
        if franchise_id:
            from accounts.models import FranchiseProfile
            f_obj = FranchiseProfile.objects.filter(id=franchise_id).first()
            if not f_obj:
                return Response({
                    "success": False,
                    "message": f"Target franchise with ID '{franchise_id}' not found.",
                }, status=status.HTTP_400_BAD_REQUEST)
            data['franchise'] = f_obj.id

        # Target audience is strictly Franchise
        data['target_audience'] = 'franchise'
        if data.get('status') == 'published':
            data['published_at'] = timezone.now()

        serializer = QuotationSerializer(data=data, context={'request': request})
        if not serializer.is_valid():
            return Response({"success": False, "errors": serializer.errors}, status=status.HTTP_400_BAD_REQUEST)

        quotation = serializer.save()
        quotation.status_history.append({
            "action": "created",
            "status": quotation.status,
            "timestamp": timezone.now().isoformat(),
            "user": request.user.username,
        })
        quotation.save(update_fields=['status_history'])

        # Notify franchise via system event and FCM push
        if quotation.franchise and quotation.status == 'published':
            from accounts.models import publish_system_event
            publish_system_event(
                event_type='quotation.received',
                payload={
                    'quotation_id': quotation.id,
                    'quotation_number': quotation.quotation_number,
                    'title': quotation.title,
                    'final_amount': float(quotation.final_amount),
                    'franchise_id': quotation.franchise.id,
                },
                target_scope='franchise',
                franchise_id=quotation.franchise.id
            )
            try:
                from accounts.fcm_services import notify_quotation_created
                notify_quotation_created(quotation)
            except Exception as fcm_err:
                logger.warning("FCM quotation notification warning: %s", fcm_err)

        return Response({
            "success": True,
            "message": "Franchise quotation created successfully.",
            "quotation": QuotationSerializer(quotation, context={'request': request}).data,
        }, status=status.HTTP_201_CREATED)


class QuotationDetailView(APIView):
    parser_classes = [MultiPartParser, FormParser, JSONParser]
    permission_classes = [IsAuthenticated]

    def get(self, request, pk):
        role = get_user_role(request.user)
        if role == 'customer':
            return Response({
                "success": False,
                "message": "Access Denied: Quotations are exclusively accessible to Franchises and Administrators.",
            }, status=status.HTTP_403_FORBIDDEN)

        quotation = get_object_or_404(Quotation.objects.select_related("product", "franchise"), pk=pk)

        if role == 'franchise':
            f_profile = getattr(request.user, 'franchise_profile', None)
            if not f_profile or quotation.franchise != f_profile:
                return Response({
                    "success": False,
                    "message": "Access Denied: You cannot view quotations assigned to another franchise.",
                }, status=status.HTTP_403_FORBIDDEN)
            if quotation.status == 'draft':
                return Response({
                    "success": False,
                    "message": "This quotation is currently in draft and has not been published.",
                }, status=status.HTTP_403_FORBIDDEN)
            # Mark read
            if not quotation.is_read_by_franchise:
                quotation.is_read_by_franchise = True
                quotation.save(update_fields=['is_read_by_franchise'])

        return Response({
            "success": True,
            "quotation": QuotationSerializer(quotation, context={'request': request}).data,
        }, status=status.HTTP_200_OK)

    def patch(self, request, pk):
        role = get_user_role(request.user)
        if role == 'customer':
            return Response({
                "success": False,
                "message": "Access Denied: Customers cannot modify quotations.",
            }, status=status.HTTP_403_FORBIDDEN)

        quotation = get_object_or_404(Quotation.objects.select_related("franchise"), pk=pk)

        # Allow assigned franchise to accept/reject via PATCH
        action = str(request.data.get('action', '')).strip().lower()
        if role == 'franchise':
            if action in ['accept', 'reject']:
                return FranchiseQuotationActionView().post(request, pk)
            return Response({
                "success": False,
                "message": "Permission Denied: Only Administrators can modify quotation terms and pricing.",
            }, status=status.HTTP_403_FORBIDDEN)

        if role != 'admin':
            return Response({
                "success": False,
                "message": "Permission Denied: Only Administrators can modify quotation terms and pricing.",
            }, status=status.HTTP_403_FORBIDDEN)
        old_status = quotation.status
        serializer = QuotationSerializer(quotation, data=request.data, partial=True, context={'request': request})
        if not serializer.is_valid():
            return Response({"success": False, "errors": serializer.errors}, status=status.HTTP_400_BAD_REQUEST)

        updated = serializer.save()
        if old_status != updated.status:
            updated.status_history.append({
                "action": f"status_changed_to_{updated.status}",
                "timestamp": timezone.now().isoformat(),
                "user": request.user.username,
            })
            updated.save(update_fields=['status_history'])

            if updated.status == 'published' and updated.franchise:
                try:
                    from accounts.fcm_services import notify_quotation_created
                    notify_quotation_created(updated)
                except Exception as fcm_err:
                    logger.warning("FCM quotation publish notification warning: %s", fcm_err)

        return Response({
            "success": True,
            "message": "Quotation updated successfully.",
            "quotation": QuotationSerializer(updated, context={'request': request}).data,
        }, status=status.HTTP_200_OK)

    def delete(self, request, pk):
        role = get_user_role(request.user)
        if role != 'admin':
            return Response({
                "success": False,
                "message": "Permission Denied: Only Administrators can delete quotations.",
            }, status=status.HTTP_403_FORBIDDEN)

        quotation = get_object_or_404(Quotation, pk=pk)
        title = quotation.title
        if quotation.pdf_file:
            try:
                quotation.pdf_file.delete(save=False)
            except Exception:
                pass
        quotation.delete()
        return Response({
            "success": True,
            "message": f"Quotation '{title}' deleted successfully.",
        }, status=status.HTTP_200_OK)


class FranchiseQuotationActionView(APIView):
    """
    Franchise-side Quotation Actions: Accept or Reject with mandatory reason.
    Exclusively available to the designated Franchise or Admin.
    """
    permission_classes = [IsAuthenticated]

    def post(self, request, pk):
        role = get_user_role(request.user)
        if role == 'customer':
            return Response({
                "success": False,
                "message": "Access Denied: Customers cannot perform actions on franchise quotations.",
            }, status=status.HTTP_403_FORBIDDEN)

        quotation = get_object_or_404(Quotation.objects.select_related("franchise"), pk=pk)

        if role == 'franchise':
            f_profile = getattr(request.user, 'franchise_profile', None)
            if not f_profile or quotation.franchise != f_profile:
                return Response({
                    "success": False,
                    "message": "Access Denied: You do not have authorization to act on this quotation.",
                }, status=status.HTTP_403_FORBIDDEN)

        action = str(request.data.get('action', '')).strip().lower()

        if action == 'accept':
            if quotation.status == 'accepted':
                return Response({
                    "success": False,
                    "message": "This quotation has already been accepted.",
                }, status=status.HTTP_400_BAD_REQUEST)
            if quotation.status in ['rejected', 'withdrawn', 'expired', 'draft']:
                return Response({
                    "success": False,
                    "message": f"Cannot accept quotation in '{quotation.status}' state.",
                }, status=status.HTTP_400_BAD_REQUEST)

            # Check validity expiry
            if quotation.valid_until and quotation.valid_until < timezone.now().date():
                quotation.status = 'expired'
                quotation.status_history.append({
                    "action": "expired",
                    "timestamp": timezone.now().isoformat(),
                    "reason": f"Validity expired on {quotation.valid_until}"
                })
                quotation.save(update_fields=['status', 'status_history'])
                return Response({
                    "success": False,
                    "message": f"This quotation expired on {quotation.valid_until} and can no longer be accepted.",
                }, status=status.HTTP_400_BAD_REQUEST)

            quotation.status = 'accepted'
            quotation.accepted_at = timezone.now()
            quotation.accepted_by = request.user
            quotation.status_history.append({
                "action": "accepted",
                "timestamp": timezone.now().isoformat(),
                "user": request.user.username,
                "franchise": quotation.franchise.business_name if quotation.franchise else None,
            })
            quotation.save()

            # Broadcast SSE notification to Admin
            from accounts.models import publish_system_event
            publish_system_event(
                event_type='quotation.accepted',
                payload={
                    'quotation_id': quotation.id,
                    'quotation_number': quotation.quotation_number,
                    'title': quotation.title,
                    'franchise_id': quotation.franchise_id,
                    'final_amount': float(quotation.final_amount),
                    'accepted_by': request.user.username,
                },
                target_scope='admin'
            )

            try:
                from accounts.fcm_services import notify_quotation_status_update
                notify_quotation_status_update(quotation, action='accepted', actor_name=request.user.username)
            except Exception as fcm_err:
                logger.warning("FCM quotation accepted notification warning: %s", fcm_err)

            return Response({
                "success": True,
                "message": f"Quotation '{quotation.quotation_number}' accepted successfully.",
                "quotation": QuotationSerializer(quotation, context={'request': request}).data,
            }, status=status.HTTP_200_OK)

        elif action == 'reject':
            reason = str(request.data.get('reason', '')).strip()
            if not reason or len(reason) < 3:
                return Response({
                    "success": False,
                    "message": "A mandatory rejection reason is required (minimum 3 characters).",
                }, status=status.HTTP_400_BAD_REQUEST)

            if quotation.status in ['accepted', 'withdrawn', 'expired', 'draft']:
                return Response({
                    "success": False,
                    "message": f"Cannot reject quotation in '{quotation.status}' state.",
                }, status=status.HTTP_400_BAD_REQUEST)

            quotation.status = 'rejected'
            quotation.rejection_reason = reason
            quotation.status_history.append({
                "action": "rejected",
                "reason": reason,
                "timestamp": timezone.now().isoformat(),
                "user": request.user.username,
                "franchise": quotation.franchise.business_name if quotation.franchise else None,
            })
            quotation.save()

            # Broadcast SSE notification to Admin
            from accounts.models import publish_system_event
            publish_system_event(
                event_type='quotation.rejected',
                payload={
                    'quotation_id': quotation.id,
                    'quotation_number': quotation.quotation_number,
                    'title': quotation.title,
                    'franchise_id': quotation.franchise_id,
                    'rejection_reason': reason,
                    'rejected_by': request.user.username,
                },
                target_scope='admin'
            )

            try:
                from accounts.fcm_services import notify_quotation_status_update
                notify_quotation_status_update(quotation, action='rejected', actor_name=request.user.username, reason=reason)
            except Exception as fcm_err:
                logger.warning("FCM quotation rejected notification warning: %s", fcm_err)

            return Response({
                "success": True,
                "message": f"Quotation '{quotation.quotation_number}' rejected.",
                "quotation": QuotationSerializer(quotation, context={'request': request}).data,
            }, status=status.HTTP_200_OK)

        else:
            return Response({
                "success": False,
                "message": "Invalid action. Supported actions are 'accept' and 'reject'.",
            }, status=status.HTTP_400_BAD_REQUEST)


class QuotationPDFDownloadView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, pk=None):
        role = get_user_role(request.user)
        if role == 'customer':
            return Response({
                "success": False,
                "message": "Access Denied: Customers cannot access franchise quotation documents.",
            }, status=status.HTTP_403_FORBIDDEN)

        if pk:
            quotation = get_object_or_404(Quotation.objects.select_related("product", "franchise"), pk=pk)
        else:
            q_type = request.query_params.get("type", "").strip().lower()
            queryset = Quotation.objects.select_related("product", "franchise").filter(is_active=True)
            if q_type:
                queryset = queryset.filter(quotation_type=q_type)
            if role == 'franchise':
                f_profile = getattr(request.user, 'franchise_profile', None)
                queryset = queryset.filter(franchise=f_profile)
            quotation = queryset.first()

        if not quotation:
            return Response({"success": False, "has_pdf": False, "message": "Quotation not found."}, status=status.HTTP_404_NOT_FOUND)

        if role == 'franchise':
            f_profile = getattr(request.user, 'franchise_profile', None)
            if not f_profile or quotation.franchise != f_profile:
                return Response({
                    "success": False,
                    "message": "Access Denied: You cannot download quotations assigned to another franchise.",
                }, status=status.HTTP_403_FORBIDDEN)

        # Check if actual PDF file is uploaded in database
        if not quotation.pdf_file or not hasattr(quotation.pdf_file, 'path') or not os.path.exists(quotation.pdf_file.path):
            return Response({
                "success": False,
                "has_pdf": False,
                "quotation": QuotationSerializer(quotation, context={'request': request}).data,
                "message": f"No official PDF document is currently attached to quotation '{quotation.quotation_number or quotation.title}'."
            }, status=status.HTTP_404_NOT_FOUND)

        # Serve the real uploaded PDF file from database
        try:
            file_handle = open(quotation.pdf_file.path, 'rb')
            response = FileResponse(file_handle, content_type='application/pdf')
            filename = os.path.basename(quotation.pdf_file.name)
            response['Content-Disposition'] = f'inline; filename="{filename}"'
            response['Access-Control-Expose-Headers'] = 'Content-Disposition'
            return response
        except Exception as e:
            return Response({
                "success": False,
                "has_pdf": False,
                "message": f"Error opening attached PDF file: {str(e)}"
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)



# =========================================================
# CHAT PROCESSING
# =========================================================

class ChatView(APIView):
    authentication_classes = [JWTAuthentication]
    permission_classes = [AllowAny]

    def post(self, request):
        message = str(request.data.get('message', '')).strip()
        app_type = str(request.data.get('app_type', 'customer')).strip().lower()
        chatbot_mode = str(request.data.get('chatbot_mode', app_type)).strip().lower()
        inquiry_type = str(request.data.get('inquiry_type', app_type)).strip().lower()
        lead_capture_completed = request.data.get('lead_capture_completed') is True
        history = request.data.get('history', [])
        session_id = str(request.data.get('session_id', '')).strip()
        cust_name = str(request.data.get('customer_name', '')).strip()
        cust_phone = str(request.data.get('customer_phone', '')).strip()
        cust_email = str(request.data.get('customer_email', '')).strip()
        option_id = request.data.get('option_id')

        if not message and not option_id:
            return Response(
                {'success': False, 'error': 'Message or option cannot be empty.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        user = request.user if (request.user and request.user.is_authenticated) else None

        import re
        if not cust_phone and message:
            phone_match = re.search(r'(?:(?:\+?91)|0)?([6-9]\d{9})\b', message)
            if phone_match:
                cust_phone = phone_match.group(1)

        if not cust_email and message:
            email_match = re.search(r'[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+', message)
            if email_match:
                cust_email = email_match.group(0).lower()

        if (not cust_name or cust_name == 'Guest Customer') and message:
            name_match = re.search(r'(?:my name is|i am|name is|name:)\s+([A-Za-z\s]{2,30})', message, re.IGNORECASE)
            if name_match:
                cust_name = name_match.group(1).strip()

        try:
            # 1. If user selected a specific configured ChatbotOption directly
            configured_opt = None
            if option_id and str(option_id).isdigit():
                configured_opt = ChatbotOption.objects.filter(id=int(option_id), is_active=True).first()

            if configured_opt:
                reply = configured_opt.answer_text
                if not reply and configured_opt.product:
                    p = configured_opt.product
                    reply = (
                        f"Product: {p.name}\n"
                        f"Size: {p.size}\n"
                        f"Price: Rs.{p.price} per {p.unit}\n"
                        f"Availability: {'In Stock (' + str(p.stock) + ' units)' if p.stock > 0 else 'Currently Out of Stock'}\n"
                        f"Description: {p.description or 'Pure packaged drinking water'}"
                    )
                elif not reply and configured_opt.quotation:
                    q = configured_opt.quotation
                    reply = (
                        f"Quotation: {q.title}\n"
                        f"Tier: {q.quantity_tier}\n"
                        f"Rate: Rs.{q.total_price or q.unit_price}\n"
                        f"Terms: {q.applicable_terms}\n"
                        f"Validity: {q.validity}"
                    )
                if not reply:
                    reply = f"You selected '{configured_opt.title}'. How can I assist you further?"
            else:
                # 2. Process Natural Language or keyword query
                reply = AIService.generate_response(
                    message=message,
                    app_type=app_type,
                    user=user,
                    history=history
                )

            # Persist session and messages in PostgreSQL
            session = None
            if user:
                session, _ = ChatSession.objects.get_or_create(
                    user=user,
                    app_type=app_type,
                    defaults={
                        'session_id': session_id,
                        'customer_name': user.get_full_name() or user.username,
                        'customer_email': user.email,
                        'customer_phone': getattr(getattr(user, 'profile', None), 'phone', ''),
                        'inquiry_type': inquiry_type,
                        'chatbot_mode': chatbot_mode,
                        'lead_capture_completed': True,
                    }
                )
            elif session_id:
                session, _ = ChatSession.objects.get_or_create(
                    session_id=session_id,
                    app_type=app_type,
                    defaults={
                        'customer_name': cust_name or 'Guest Customer',
                        'customer_phone': cust_phone,
                        'customer_email': cust_email,
                        'inquiry_type': inquiry_type,
                        'chatbot_mode': chatbot_mode,
                        'lead_capture_completed': lead_capture_completed,
                    }
                )
            else:
                session = ChatSession.objects.create(
                    app_type=app_type,
                    customer_name=cust_name or 'Guest Customer',
                    customer_phone=cust_phone,
                    customer_email=cust_email,
                    inquiry_type=inquiry_type,
                    chatbot_mode=chatbot_mode,
                    lead_capture_completed=lead_capture_completed,
                )

            if session:
                updated = False
                if cust_name and (session.customer_name in ['Guest Customer', ''] or not session.customer_name):
                    session.customer_name = cust_name
                    updated = True
                if cust_phone and not session.customer_phone:
                    session.customer_phone = cust_phone
                    updated = True
                if cust_email and not session.customer_email:
                    session.customer_email = cust_email
                    updated = True
                if chatbot_mode and session.chatbot_mode != chatbot_mode:
                    session.chatbot_mode = chatbot_mode
                    updated = True
                if inquiry_type and session.inquiry_type != inquiry_type:
                    session.inquiry_type = inquiry_type
                    updated = True
                if lead_capture_completed and not session.lead_capture_completed:
                    session.lead_capture_completed = True
                    updated = True
                if updated:
                    session.save()

                ChatMessage.objects.create(session=session, role='user', content=message or (configured_opt.title if configured_opt else ''))
                ChatMessage.objects.create(session=session, role='assistant', content=reply)

                # Public Chatbot CRM Lead integration: create or update Lead and link session
                clean_p = re.sub(r'\D', '', cust_phone) if cust_phone else ''
                if clean_p.startswith('91') and len(clean_p) == 12:
                    clean_p = clean_p[2:]
                valid_phone = bool(len(clean_p) == 10 and clean_p[0] in '6789')
                valid_email = bool(cust_email and '@' in cust_email and '.' in cust_email)

                # Also scan message for phone or email if not provided directly
                if not valid_phone and message:
                    pm = re.search(r'\b[6-9]\d{9}\b', message)
                    if pm:
                        clean_p = pm.group(0)
                        valid_phone = True
                if not valid_email and message:
                    em = re.search(r'[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+', message)
                    if em:
                        cust_email = em.group(0).lower()
                        valid_email = True

                # Every public inquiry creates or updates a Lead
                is_public_inquiry = bool(app_type in ['customer', 'public', 'guest'] or not user)
                if valid_phone or valid_email or is_public_inquiry:
                    try:
                        from leads.models import Lead, CRMActivityLog, LeadActivity
                        lead = getattr(session, 'lead', None)

                        if not lead and valid_phone:
                            lead = Lead.objects.filter(phone=clean_p).first()
                        if not lead and valid_email:
                            lead = Lead.objects.filter(email__iexact=cust_email).first()

                        if not lead:
                            # Generate unique contact identifier if visitor hasn't provided phone yet
                            fallback_phone = clean_p if valid_phone else f"98{abs(hash(session.session_id or str(session.id or timezone.now()))) % 100000000:08d}"
                            lead_name = cust_name if (cust_name and cust_name not in ['Guest Customer', '']) else 'Public Prospect'
                            lead = Lead.objects.create(
                                name=lead_name,
                                phone=fallback_phone,
                                email=cust_email if valid_email else '',
                                city='Raipur',
                                status='NEW',
                                source='PUBLIC_CHATBOT',
                                notes=f"Public Chatbot Inquiry: {message or (configured_opt.title if configured_opt else '')}",
                            )
                            lead.calculate_lead_score()
                            lead.save()

                            CRMActivityLog.objects.create(
                                lead=lead,
                                activity_type='STATUS_CHANGED',
                                description=f"Inbound public chatbot lead created. Source: PUBLIC_CHATBOT. Qualified as {lead.score_category} (Score: {lead.lead_score_number})"
                            )
                            LeadActivity.objects.create(
                                lead=lead,
                                activity_type='note',
                                title='Public Chatbot Inquiry',
                                description=f"Initial message: {message}",
                            )

                            # Dispatch FCM push notification to Admin & Super Admin
                            try:
                                from accounts.fcm_services import notify_lead_created
                                notify_lead_created(lead, is_update=False)
                            except Exception as fcm_err:
                                logger.warning("FCM: Chatbot lead creation notification warning: %s", fcm_err)
                        else:
                            updated_lead = False
                            if cust_name and lead.name in ['Guest Customer', 'Public Prospect', 'Prospect', 'Public Customer', '']:
                                lead.name = cust_name
                                updated_lead = True
                            if valid_phone and (lead.phone != clean_p):
                                lead.phone = clean_p
                                updated_lead = True
                            if valid_email and not lead.email:
                                lead.email = cust_email
                                updated_lead = True
                            if not lead.source:
                                lead.source = 'PUBLIC_CHATBOT'
                                updated_lead = True
                            if message:
                                lead.notes = f"{lead.notes}\n[{timezone.now().strftime('%d %b %H:%M')}] {message}"
                                updated_lead = True
                            if updated_lead:
                                lead.save()

                            CRMActivityLog.objects.create(
                                lead=lead,
                                activity_type='NOTE_ADDED',
                                description=f"Public Chatbot interaction: {message}"
                            )

                            if updated_lead:
                                try:
                                    from accounts.fcm_services import notify_lead_created
                                    notify_lead_created(lead, is_update=True)
                                except Exception as fcm_err:
                                    logger.warning("FCM: Chatbot lead update notification warning: %s", fcm_err)

                        if session and session.lead != lead:
                            session.lead = lead
                            session.save(update_fields=['lead'])
                    except Exception as lead_err:
                        logger.warning("CRM: Lead capture warning in chatbot: %s", lead_err)

            return Response({
                'success': True,
                'reply': reply,
                'app_type': app_type,
                'chatbot_mode': session.chatbot_mode if session else chatbot_mode,
                'inquiry_type': session.inquiry_type if session else inquiry_type,
                'lead_capture_completed': session.lead_capture_completed if session else lead_capture_completed,
                'session_id': session.id if session else None,
                'is_lead_trigger': configured_opt.is_lead_trigger if configured_opt else False,
                'lead_inquiry_type': configured_opt.lead_inquiry_type if configured_opt else '',
            }, status=status.HTTP_200_OK)

        except Exception as e:
            if app_type == 'admin':
                return Response({
                    'success': True,
                    'reply': f"Admin Analytics Assistant: Error processing data query: {str(e)}",
                    'app_type': app_type,
                    'chatbot_mode': 'admin',
                }, status=status.HTTP_200_OK)
            return Response({
                'success': True,
                'reply': 'Thank you for your inquiry. For direct assistance, our customer support team is available at +91 98062 47194.',
                'app_type': app_type,
            }, status=status.HTTP_200_OK)


class AdminChatConversationsView(APIView):
    permission_classes = [IsAdminRole]

    def get(self, request):
        sessions = ChatSession.objects.annotate(
            msg_count=Count('messages'),
            last_activity=Max('messages__timestamp')
        ).order_by('-updated_at')

        app_type_filter = request.query_params.get('app_type', '').strip()
        if app_type_filter:
            sessions = sessions.filter(app_type=app_type_filter)

        results = []
        for s in sessions:
            last_msg = s.messages.order_by('-timestamp').first()
            user_name = s.user.get_full_name() or s.user.username if s.user else (s.customer_name or 'Guest Customer')
            user_email = s.user.email if s.user else s.customer_email
            user_phone = getattr(getattr(s.user, 'profile', None), 'phone', '') if s.user else s.customer_phone

            results.append({
                'id': s.id,
                'session_id': s.session_id,
                'app_type': s.app_type,
                'customer_name': user_name,
                'customer_email': user_email,
                'customer_phone': user_phone,
                'status': s.status,
                'message_count': s.msg_count,
                'last_message': last_msg.content[:120] if last_msg else '',
                'last_message_role': last_msg.role if last_msg else '',
                'created_at': s.created_at.strftime('%Y-%m-%d %H:%M'),
                'updated_at': s.updated_at.strftime('%Y-%m-%d %H:%M'),
            })

        return Response({
            'success': True,
            'count': len(results),
            'conversations': results,
        }, status=status.HTTP_200_OK)


class AdminChatConversationDetailView(APIView):
    permission_classes = [IsAdminRole]

    def get(self, request, session_id):
        session = get_object_or_404(ChatSession, id=session_id)
        messages = session.messages.order_by('timestamp')

        user_name = session.user.get_full_name() or session.user.username if session.user else (session.customer_name or 'Guest Customer')
        user_email = session.user.email if session.user else session.customer_email
        user_phone = getattr(getattr(session.user, 'profile', None), 'phone', '') if session.user else session.customer_phone

        return Response({
            'success': True,
            'session': {
                'id': session.id,
                'session_id': session.session_id,
                'app_type': session.app_type,
                'customer_name': user_name,
                'customer_email': user_email,
                'customer_phone': user_phone,
                'status': session.status,
                'created_at': session.created_at.strftime('%Y-%m-%d %H:%M'),
                'updated_at': session.updated_at.strftime('%Y-%m-%d %H:%M'),
                'messages': [
                    {
                        'id': m.id,
                        'role': m.role,
                        'content': m.content,
                        'timestamp': m.timestamp.strftime('%Y-%m-%d %H:%M:%S'),
                    }
                    for m in messages
                ]
            }
        }, status=status.HTTP_200_OK)


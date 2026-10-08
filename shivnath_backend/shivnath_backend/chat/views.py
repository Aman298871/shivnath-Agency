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
# QUOTATION MANAGEMENT (CRUD + PUBLIC VIEW)
# =========================================================

class QuotationListCreateView(APIView):
    parser_classes = [MultiPartParser, FormParser, JSONParser]

    def get_permissions(self):
        if self.request.method == "GET":
            return [AllowAny()]
        return [IsAdminRole()]

    def get(self, request):
        target = request.query_params.get("target", "").strip().lower()
        quotation_type = request.query_params.get("type", "").strip().lower()

        queryset = Quotation.objects.select_related("product").all().order_by("-updated_at")

        # Allow public users to only see active quotations
        if not (request.user and request.user.is_authenticated and (request.user.is_staff or request.user.is_superuser or getattr(getattr(request.user, 'profile', None), 'role', '') == 'admin')):
            queryset = queryset.filter(is_active=True)

        if target in ["customer", "franchise"]:
            queryset = queryset.filter(Q(target_audience=target) | Q(target_audience="both"))

        if quotation_type:
            queryset = queryset.filter(quotation_type=quotation_type)

        serializer = QuotationSerializer(queryset, many=True, context={'request': request})
        return Response({
            "success": True,
            "count": queryset.count(),
            "quotations": serializer.data,
        }, status=status.HTTP_200_OK)

    def post(self, request):
        serializer = QuotationSerializer(data=request.data, context={'request': request})
        if not serializer.is_valid():
            return Response({"success": False, "errors": serializer.errors}, status=status.HTTP_400_BAD_REQUEST)

        quotation = serializer.save()
        return Response({
            "success": True,
            "message": "Quotation template created successfully.",
            "quotation": QuotationSerializer(quotation, context={'request': request}).data,
        }, status=status.HTTP_201_CREATED)


class QuotationDetailView(APIView):
    parser_classes = [MultiPartParser, FormParser, JSONParser]

    def get_permissions(self):
        if self.request.method == "GET":
            return [AllowAny()]
        return [IsAdminRole()]

    def get(self, request, pk):
        quotation = get_object_or_404(Quotation.objects.select_related("product"), pk=pk)
        return Response({
            "success": True,
            "quotation": QuotationSerializer(quotation, context={'request': request}).data,
        }, status=status.HTTP_200_OK)

    def patch(self, request, pk):
        quotation = get_object_or_404(Quotation, pk=pk)
        serializer = QuotationSerializer(quotation, data=request.data, partial=True, context={'request': request})
        if not serializer.is_valid():
            return Response({"success": False, "errors": serializer.errors}, status=status.HTTP_400_BAD_REQUEST)

        updated = serializer.save()
        return Response({
            "success": True,
            "message": "Quotation updated successfully.",
            "quotation": QuotationSerializer(updated, context={'request': request}).data,
        }, status=status.HTTP_200_OK)

    def delete(self, request, pk):
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


class QuotationPDFDownloadView(APIView):
    permission_classes = [AllowAny]

    def get(self, request, pk=None):
        if pk:
            quotation = get_object_or_404(Quotation.objects.select_related("product"), pk=pk)
        else:
            q_type = request.query_params.get("type", "").strip().lower()
            target = request.query_params.get("target", "").strip().lower()
            queryset = Quotation.objects.select_related("product").filter(is_active=True)
            if q_type:
                queryset = queryset.filter(quotation_type=q_type)
            if target:
                queryset = queryset.filter(Q(target_audience=target) | Q(target_audience="both"))
            quotation = queryset.first()

        if not quotation:
            return Response({"success": False, "has_pdf": False, "message": "Quotation not found."}, status=status.HTTP_404_NOT_FOUND)

        # Check if actual PDF file is uploaded in database
        if not quotation.pdf_file or not hasattr(quotation.pdf_file, 'path') or not os.path.exists(quotation.pdf_file.path):
            return Response({
                "success": False,
                "has_pdf": False,
                "quotation": QuotationSerializer(quotation, context={'request': request}).data,
                "message": f"No official PDF document is currently attached to quotation '{quotation.title}'."
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


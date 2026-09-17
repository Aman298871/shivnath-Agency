from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from rest_framework.permissions import AllowAny, IsAuthenticated
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

        if inquiry_type in ["customer", "franchise"]:
            queryset = queryset.filter(Q(inquiry_type=inquiry_type) | Q(inquiry_type="both"))

        if parent_id and parent_id.isdigit():
            # Return sub-options of selected parent
            queryset = queryset.filter(parent_id=int(parent_id))
            serializer = ChatbotOptionSerializer(queryset, many=True)
        elif tree_mode:
            # Return root tree nodes with nested children
            root_options = queryset.filter(parent__isnull=True)
            serializer = ChatbotOptionSerializer(root_options, many=True)
        else:
            # Return root options (level 1)
            root_options = queryset.filter(parent__isnull=True)
            serializer = ChatbotOptionSerializer(root_options, many=True)

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

        serializer = QuotationSerializer(queryset, many=True)
        return Response({
            "success": True,
            "count": queryset.count(),
            "quotations": serializer.data,
        }, status=status.HTTP_200_OK)

    def post(self, request):
        serializer = QuotationSerializer(data=request.data)
        if not serializer.is_valid():
            return Response({"success": False, "errors": serializer.errors}, status=status.HTTP_400_BAD_REQUEST)

        quotation = serializer.save()
        return Response({
            "success": True,
            "message": "Quotation template created successfully.",
            "quotation": QuotationSerializer(quotation).data,
        }, status=status.HTTP_201_CREATED)


class QuotationDetailView(APIView):
    def get_permissions(self):
        if self.request.method == "GET":
            return [AllowAny()]
        return [IsAdminRole()]

    def get(self, request, pk):
        quotation = get_object_or_404(Quotation.objects.select_related("product"), pk=pk)
        return Response({
            "success": True,
            "quotation": QuotationSerializer(quotation).data,
        }, status=status.HTTP_200_OK)

    def patch(self, request, pk):
        quotation = get_object_or_404(Quotation, pk=pk)
        serializer = QuotationSerializer(quotation, data=request.data, partial=True)
        if not serializer.is_valid():
            return Response({"success": False, "errors": serializer.errors}, status=status.HTTP_400_BAD_REQUEST)

        updated = serializer.save()
        return Response({
            "success": True,
            "message": "Quotation updated successfully.",
            "quotation": QuotationSerializer(updated).data,
        }, status=status.HTTP_200_OK)

    def delete(self, request, pk):
        quotation = get_object_or_404(Quotation, pk=pk)
        title = quotation.title
        quotation.delete()
        return Response({
            "success": True,
            "message": f"Quotation '{title}' deleted successfully.",
        }, status=status.HTTP_200_OK)


# =========================================================
# CHAT PROCESSING
# =========================================================

class ChatView(APIView):
    authentication_classes = [JWTAuthentication]
    permission_classes = [AllowAny]

    def post(self, request):
        message = str(request.data.get('message', '')).strip()
        app_type = str(request.data.get('app_type', 'customer')).strip().lower()
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
                        'inquiry_type': app_type,
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
                        'inquiry_type': app_type,
                    }
                )
            else:
                session = ChatSession.objects.create(
                    app_type=app_type,
                    customer_name=cust_name or 'Guest Customer',
                    customer_phone=cust_phone,
                    customer_email=cust_email,
                    inquiry_type=app_type,
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
                if updated:
                    session.save()

                ChatMessage.objects.create(session=session, role='user', content=message or (configured_opt.title if configured_opt else ''))
                ChatMessage.objects.create(session=session, role='assistant', content=reply)

            return Response({
                'success': True,
                'reply': reply,
                'app_type': app_type,
                'session_id': session.id if session else None,
                'is_lead_trigger': configured_opt.is_lead_trigger if configured_opt else False,
                'lead_inquiry_type': configured_opt.lead_inquiry_type if configured_opt else '',
            }, status=status.HTTP_200_OK)

        except Exception as e:
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


from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework_simplejwt.authentication import JWTAuthentication
from django.shortcuts import get_object_or_404
from django.db.models import Count, Max

from .services import AIService
from .models import ChatSession, ChatMessage
from accounts.permissions import IsAdminRole


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

        if not message:
            return Response(
                {'success': False, 'error': 'Message cannot be empty.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        user = request.user if (request.user and request.user.is_authenticated) else None

        try:
            reply = AIService.generate_response(
                message=message,
                app_type=app_type,
                user=user,
                history=history
            )

            # Persist session and messages for both logged-in and guest customers
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
                    }
                )
            else:
                session = ChatSession.objects.create(
                    app_type=app_type,
                    customer_name=cust_name or 'Guest Customer',
                    customer_phone=cust_phone,
                    customer_email=cust_email,
                )

            # Update contact info on session if newly provided
            if session:
                updated = False
                if cust_name and not session.customer_name:
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

                ChatMessage.objects.create(session=session, role='user', content=message)
                ChatMessage.objects.create(session=session, role='assistant', content=reply)

            return Response({
                'success': True,
                'reply': reply,
                'app_type': app_type,
                'session_id': session.id if session else None,
            }, status=status.HTTP_200_OK)

        except Exception as e:
            return Response({
                'success': True,
                'reply': 'I am currently processing your request. Please ask your question again or contact our support team at +91 98062 47194.',
                'app_type': app_type,
            }, status=status.HTTP_200_OK)


class AdminChatConversationsView(APIView):
    """
    Admin-only endpoint to list all customer and franchise chatbot conversations.
    """
    authentication_classes = [JWTAuthentication]
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
                'last_message': last_msg.content[:100] if last_msg else '',
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
    """
    Admin-only endpoint to view the complete chronological conversation history of a specific session.
    """
    authentication_classes = [JWTAuthentication]
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

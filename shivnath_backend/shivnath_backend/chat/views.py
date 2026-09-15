from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from rest_framework.permissions import AllowAny
from rest_framework_simplejwt.authentication import JWTAuthentication

from .services import AIService
from .models import ChatSession, ChatMessage


class ChatView(APIView):
    authentication_classes = [JWTAuthentication]
    permission_classes = [AllowAny]

    def post(self, request):
        message = str(request.data.get('message', '')).strip()
        app_type = str(request.data.get('app_type', 'customer')).strip().lower()
        history = request.data.get('history', [])

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

            # Persist session and messages if needed
            if user:
                session, _ = ChatSession.objects.get_or_create(
                    user=user,
                    app_type=app_type
                )
                ChatMessage.objects.create(session=session, role='user', content=message)
                ChatMessage.objects.create(session=session, role='assistant', content=reply)

            return Response({
                'success': True,
                'reply': reply,
                'app_type': app_type,
            }, status=status.HTTP_200_OK)

        except Exception as e:
            return Response({
                'success': True,
                'reply': 'I am currently processing your request. Please ask your question again or contact our support team at +91 98062 47194.',
                'app_type': app_type,
            }, status=status.HTTP_200_OK)

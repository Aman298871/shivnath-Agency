from django.urls import path
from .views import ChatView, AdminChatConversationsView, AdminChatConversationDetailView

urlpatterns = [
    path('', ChatView.as_view(), name='chat-api'),
    path('admin/conversations/', AdminChatConversationsView.as_view(), name='admin-chat-conversations'),
    path('admin/conversations/<int:session_id>/', AdminChatConversationDetailView.as_view(), name='admin-chat-conversation-detail'),
]

from django.urls import path
from .views import (
    ChatView,
    ChatbotOptionListView,
    AdminChatbotOptionListView,
    AdminChatbotOptionDetailView,
    QuotationListCreateView,
    QuotationDetailView,
    AdminChatConversationsView,
    AdminChatConversationDetailView,
)

urlpatterns = [
    path('', ChatView.as_view(), name='chat-api'),
    path('options/', ChatbotOptionListView.as_view(), name='chatbot-options'),
    path('admin/options/', AdminChatbotOptionListView.as_view(), name='admin-chatbot-options'),
    path('admin/options/<int:pk>/', AdminChatbotOptionDetailView.as_view(), name='admin-chatbot-option-detail'),
    path('quotations/', QuotationListCreateView.as_view(), name='quotations-list-create'),
    path('quotations/<int:pk>/', QuotationDetailView.as_view(), name='quotation-detail'),
    path('admin/conversations/', AdminChatConversationsView.as_view(), name='admin-chat-conversations'),
    path('admin/conversations/<int:session_id>/', AdminChatConversationDetailView.as_view(), name='admin-chat-conversation-detail'),
]

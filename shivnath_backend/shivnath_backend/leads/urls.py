from django.urls import path

from .views import (
    LeadListCreateView,
    LeadDetailView,
    LeadActivityListCreateView,
    LeadStatsView,
    PublicLeadCaptureView,
    PublicChatbotInquiryView,
    WhatsAppWebhookView,
    MarketingSpendListCreateView,
    LeadScoreRecalculateView,
)


urlpatterns = [
    # Public Lead Capture
    path('public/', PublicLeadCaptureView.as_view(), name='public-lead-capture'),
    path('public-capture/', PublicLeadCaptureView.as_view(), name='public-lead-capture-alt'),
    path('public/ingest/', PublicLeadCaptureView.as_view(), name='public-lead-ingest'),
    path('public/chatbot/', PublicChatbotInquiryView.as_view(), name='public-chatbot-inquiry'),

    # WhatsApp Webhook & Messages
    path('whatsapp/webhook/', WhatsAppWebhookView.as_view(), name='whatsapp-webhook'),

    # Marketing Spend & CAC Analytics
    path('marketing-spend/', MarketingSpendListCreateView.as_view(), name='marketing-spend-list-create'),

    # Admin Lead List + Create
    path('', LeadListCreateView.as_view(), name='lead-list-create'),

    # Stats
    path('stats/', LeadStatsView.as_view(), name='lead-stats'),

    # Single Lead
    path('<int:pk>/', LeadDetailView.as_view(), name='lead-detail'),
    path('<int:pk>/score/', LeadScoreRecalculateView.as_view(), name='lead-recalculate-score'),

    # Activities
    path('<int:lead_id>/activities/', LeadActivityListCreateView.as_view(), name='lead-activities'),
]
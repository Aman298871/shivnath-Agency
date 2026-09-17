from django.urls import path

from .views import (
    LeadListCreateView,
    LeadDetailView,
    LeadActivityListCreateView,
    LeadStatsView,
    PublicLeadCaptureView,
)


urlpatterns = [
    # Public Lead Capture
    path('public/', PublicLeadCaptureView.as_view(), name='public-lead-capture'),

    # Admin Lead List + Create
    path('', LeadListCreateView.as_view(), name='lead-list-create'),

    # Stats
    path('stats/', LeadStatsView.as_view(), name='lead-stats'),

    # Single Lead
    path('<int:pk>/', LeadDetailView.as_view(), name='lead-detail'),

    # Activities
    path('<int:lead_id>/activities/', LeadActivityListCreateView.as_view(), name='lead-activities'),
]
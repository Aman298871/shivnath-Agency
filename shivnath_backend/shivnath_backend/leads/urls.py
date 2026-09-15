from django.urls import path

from .views import (
    LeadListCreateView,
    LeadDetailView,
    LeadActivityListCreateView,
    LeadStatsView,
)


urlpatterns = [

    # -----------------------------------------
    # LEAD LIST + CREATE
    # -----------------------------------------

    path(
        '',
        LeadListCreateView.as_view(),
        name='lead-list-create'
    ),

    # -----------------------------------------
    # STATS
    # -----------------------------------------

    path(
        'stats/',
        LeadStatsView.as_view(),
        name='lead-stats'
    ),

    # -----------------------------------------
    # SINGLE LEAD
    # -----------------------------------------

    path(
        '<int:pk>/',
        LeadDetailView.as_view(),
        name='lead-detail'
    ),

    # -----------------------------------------
    # ACTIVITIES
    # -----------------------------------------

    path(
        '<int:lead_id>/activities/',
        LeadActivityListCreateView.as_view(),
        name='lead-activities'
    ),
]
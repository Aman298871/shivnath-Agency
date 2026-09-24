from django.urls import path

from .views import (
    FollowUpListCreateView,
    FollowUpDetailView,
    CompleteFollowUpView,
    CompletedFollowUpListView,
    FollowUpAuditLogListView,
    FollowUpStatsView,
)

urlpatterns = [

    # =====================================
    # LIST + CREATE
    # =====================================

    path(
        "",
        FollowUpListCreateView.as_view(),
        name="followup-list-create",
    ),

    # =====================================
    # COMPLETED FOLLOW-UPS
    # =====================================

    path(
        "completed/",
        CompletedFollowUpListView.as_view(),
        name="followup-completed-list",
    ),

    # =====================================
    # STATS
    # =====================================

    path(
        "stats/",
        FollowUpStatsView.as_view(),
        name="followup-stats",
    ),

    # =====================================
    # UPDATE + DELETE
    # =====================================

    path(
        "<int:pk>/",
        FollowUpDetailView.as_view(),
        name="followup-detail",
    ),

    # =====================================
    # COMPLETE
    # =====================================

    path(
        "<int:pk>/complete/",
        CompleteFollowUpView.as_view(),
        name="followup-complete",
    ),

    # =====================================
    # AUDIT LOGS
    # =====================================

    path(
        "<int:pk>/audit-logs/",
        FollowUpAuditLogListView.as_view(),
        name="followup-audit-logs",
    ),
]
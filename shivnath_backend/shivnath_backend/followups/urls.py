from django.urls import path

from .views import (
    FollowUpListCreateView,
    FollowUpDetailView,
    CompleteFollowUpView,
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
    # STATS
    # =====================================

    path(
        "stats/",
        FollowUpStatsView.as_view(),
        name="followup-stats",
    ),
]
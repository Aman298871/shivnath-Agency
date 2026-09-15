from django.urls import path

from .views import (
    SupplierListCreateView,
    SupplierDetailView,
    SupplierStatsView,
)

urlpatterns = [

    path(
        "",
        SupplierListCreateView.as_view(),
    ),

    path(
        "stats/",
        SupplierStatsView.as_view(),
    ),

    path(
        "<int:pk>/",
        SupplierDetailView.as_view(),
    ),

]
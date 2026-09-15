from django.urls import path

from .views import (
    ProductListCreateView,
    ProductDetailView,
    ProductStatsView,
)

urlpatterns = [

    # ==========================
    # Products
    # ==========================

    path(
        "",
        ProductListCreateView.as_view(),
        name="product-list-create",
    ),

    path(
        "stats/",
        ProductStatsView.as_view(),
        name="product-stats",
    ),

    path(
        "<int:pk>/",
        ProductDetailView.as_view(),
        name="product-detail",
    ),

]
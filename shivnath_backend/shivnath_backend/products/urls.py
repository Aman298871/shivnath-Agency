from django.urls import path

from .views import (
    ProductListCreateView,
    ProductDetailView,
    ProductStatsView,
    CategoryListCreateView,
    CategoryDetailView,
)

urlpatterns = [
    # Categories
    path("categories/", CategoryListCreateView.as_view(), name="category-list-create"),
    path("categories/<int:pk>/", CategoryDetailView.as_view(), name="category-detail"),

    # Products
    path("", ProductListCreateView.as_view(), name="product-list-create"),
    path("stats/", ProductStatsView.as_view(), name="product-stats"),
    path("<int:pk>/", ProductDetailView.as_view(), name="product-detail"),
]
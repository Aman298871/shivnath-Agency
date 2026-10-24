from django.urls import path

from .views import (
    ProductListCreateView,
    ProductDetailView,
    ProductStatsView,
    CategoryListCreateView,
    CategoryDetailView,
    ProductBOMDetailView,
    ProductBOMItemManageView,
    ProductPricingUpdateView,
    ProductStockThresholdView,
    MinimumOrderPackagingRuleListCreateView,
    MinimumOrderPackagingRuleDetailView,
    PackagingRuleCheckView,
)

urlpatterns = [
    # Categories
    path("categories/", CategoryListCreateView.as_view(), name="category-list-create"),
    path("categories/<int:pk>/", CategoryDetailView.as_view(), name="category-detail"),

    # Packaging Rules (Admin configuration & Cart validation)
    path("packaging-rules/", MinimumOrderPackagingRuleListCreateView.as_view(), name="packaging-rule-list-create"),
    path("packaging-rules/<int:pk>/", MinimumOrderPackagingRuleDetailView.as_view(), name="packaging-rule-detail"),
    path("packaging-rules/check/", PackagingRuleCheckView.as_view(), name="packaging-rule-check"),

    # Products
    path("", ProductListCreateView.as_view(), name="product-list-create"),
    path("stats/", ProductStatsView.as_view(), name="product-stats"),
    path("<int:pk>/", ProductDetailView.as_view(), name="product-detail"),
    path("<int:pk>/bom/", ProductBOMDetailView.as_view(), name="product-bom-detail"),
    path("<int:pk>/bom-items/", ProductBOMItemManageView.as_view(), name="product-bom-item-add"),
    path("<int:pk>/bom-items/<int:item_id>/", ProductBOMItemManageView.as_view(), name="product-bom-item-delete"),
    path("<int:pk>/pricing/", ProductPricingUpdateView.as_view(), name="product-pricing-update"),
    path("<int:pk>/threshold/", ProductStockThresholdView.as_view(), name="product-threshold"),
]
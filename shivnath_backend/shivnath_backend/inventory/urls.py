from django.urls import path

from .views import (
    InventoryItemListCreateView,
    InventoryItemDetailView,
    StockRequestListCreateView,
    StockRequestApproveView,
    StockRequestRejectView,
    InventoryStatsView,
)

urlpatterns = [
    path('items/', InventoryItemListCreateView.as_view()),
    path('items/<int:pk>/', InventoryItemDetailView.as_view()),
    path('stats/', InventoryStatsView.as_view()),

    path('requests/', StockRequestListCreateView.as_view()),
    path('requests/<int:pk>/approve/', StockRequestApproveView.as_view()),
    path('requests/<int:pk>/reject/', StockRequestRejectView.as_view()),
]
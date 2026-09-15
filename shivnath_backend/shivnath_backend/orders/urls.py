from django.urls import path

from .views import (
    OrderListCreateView,
    OrderDetailView,
    OrderStatusUpdateView,
    OrderStatsView,
)

urlpatterns = [
    path('', OrderListCreateView.as_view()),
    path('<int:pk>/', OrderDetailView.as_view()),
    path('<int:pk>/status/', OrderStatusUpdateView.as_view()),
    path('stats/', OrderStatsView.as_view()),
]
from django.urls import path

from .views import (
    OrderListCreateView,
    OrderDetailView,
    OrderStatusUpdateView,
    OrderStatsView,
    CustomerBulkOrderView,
    RazorpayCreateOrderAPIView,
    RazorpayVerifyPaymentAPIView,
    RazorpayWebhookAPIView,
    OrderLifecycleRepairView,
)

urlpatterns = [
    path('', OrderListCreateView.as_view()),
    path('bulk/', CustomerBulkOrderView.as_view(), name='bulk-orders'),
    path('razorpay/create-order/', RazorpayCreateOrderAPIView.as_view(), name='razorpay-create-order'),
    path('razorpay/verify-payment/', RazorpayVerifyPaymentAPIView.as_view(), name='razorpay-verify-payment'),
    path('razorpay/webhook/', RazorpayWebhookAPIView.as_view(), name='razorpay-webhook'),
    path('repair-lifecycle/', OrderLifecycleRepairView.as_view(), name='repair-order-lifecycle'),
    path('<int:pk>/', OrderDetailView.as_view()),
    path('<int:pk>/status/', OrderStatusUpdateView.as_view()),
    path('stats/', OrderStatsView.as_view()),
]
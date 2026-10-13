from django.urls import path

from .views import (
    OrderListCreateView,
    OrderDetailView,
    OrderStatusUpdateView,
    OrderStatsView,
    CustomerBulkOrderView,
    RazorpayCreateOrderAPIView,
    RazorpayVerifyPaymentAPIView,
    RazorpayCancelPaymentAPIView,
    RazorpayWebhookAPIView,
    RazorpayReconcilePaymentAPIView,
    RazorpayStatusAPIView,
    OrderLifecycleRepairView,
)

urlpatterns = [
    path('', OrderListCreateView.as_view()),
    path('bulk/', CustomerBulkOrderView.as_view(), name='bulk-orders'),
    path('razorpay/status/', RazorpayStatusAPIView.as_view(), name='razorpay-status'),
    path('razorpay/create-order/', RazorpayCreateOrderAPIView.as_view(), name='razorpay-create-order'),
    path('razorpay/verify-payment/', RazorpayVerifyPaymentAPIView.as_view(), name='razorpay-verify-payment'),
    path('razorpay/cancel-payment/', RazorpayCancelPaymentAPIView.as_view(), name='razorpay-cancel-payment'),
    path('razorpay/webhook/', RazorpayWebhookAPIView.as_view(), name='razorpay-webhook'),
    path('razorpay/reconcile/', RazorpayReconcilePaymentAPIView.as_view(), name='razorpay-reconcile'),
    path('repair-lifecycle/', OrderLifecycleRepairView.as_view(), name='repair-order-lifecycle'),
    path('<int:pk>/', OrderDetailView.as_view()),
    path('<int:pk>/status/', OrderStatusUpdateView.as_view()),
    path('stats/', OrderStatsView.as_view()),
]
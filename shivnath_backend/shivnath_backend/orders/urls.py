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
from .wallet_views import (
    WalletDetailAPIView,
    WalletRechargeInitiateAPIView,
    WalletRechargeVerifyAPIView,
    WalletPayOrderAPIView,
    WalletTransactionListAPIView,
    WalletRedemptionProductsAPIView,
    WalletRedeemPointsAPIView,
    WalletSettingsAPIView,
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
    # Prepaid My Water Wallet endpoints
    path('wallet/', WalletDetailAPIView.as_view(), name='wallet-detail'),
    path('wallet/recharge/', WalletRechargeInitiateAPIView.as_view(), name='wallet-recharge-initiate'),
    path('wallet/verify-recharge/', WalletRechargeVerifyAPIView.as_view(), name='wallet-recharge-verify'),
    path('wallet/pay-order/', WalletPayOrderAPIView.as_view(), name='wallet-pay-order'),
    path('wallet/transactions/', WalletTransactionListAPIView.as_view(), name='wallet-transactions'),
    path('wallet/redemption-products/', WalletRedemptionProductsAPIView.as_view(), name='wallet-redemption-products'),
    path('wallet/redeem/', WalletRedeemPointsAPIView.as_view(), name='wallet-redeem-points'),
    path('wallet/settings/', WalletSettingsAPIView.as_view(), name='wallet-settings'),
]
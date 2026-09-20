from django.urls import path

from .views import (
    InventoryItemListCreateView,
    InventoryItemDetailView,
    StockRequestListCreateView,
    StockRequestApproveView,
    StockRequestRejectView,
    InventoryStatsView,
    FranchiseRawMaterialListView,
    FranchiseProductionLogView,
    FranchiseInventoryTransactionListView,
    # ERP Views
    RawMaterialListCreateAPIView,
    ProductionBatchListCreateAPIView,
    DealerStockBatchListAPIView,
    DealerStockRequestListCreateAPIView,
    DealerStockRequestDispatchAPIView,
    DealerStockRequestReceiveAPIView,
    InventoryLedgerListAPIView,
    ExpenseListCreateAPIView,
    DailyBusinessReportAPIView,
    ExpiryAlertListAPIView,
    StockAdjustmentAPIView,
)

urlpatterns = [
    # Legacy items
    path('items/', InventoryItemListCreateView.as_view()),
    path('items/<int:pk>/', InventoryItemDetailView.as_view()),
    path('stats/', InventoryStatsView.as_view()),

    path('requests/', StockRequestListCreateView.as_view()),
    path('requests/<int:pk>/approve/', StockRequestApproveView.as_view()),
    path('requests/<int:pk>/reject/', StockRequestRejectView.as_view()),

    # Legacy Franchise inventory endpoints
    path('franchise/raw-materials/', FranchiseRawMaterialListView.as_view()),
    path('franchise/production-logs/', FranchiseProductionLogView.as_view()),
    path('franchise/transactions/', FranchiseInventoryTransactionListView.as_view()),

    # Authoritative Enterprise ERP endpoints
    path('raw-materials/', RawMaterialListCreateAPIView.as_view(), name='erp_raw_materials'),
    path('production-batches/', ProductionBatchListCreateAPIView.as_view(), name='erp_production_batches'),
    path('dealer-batches/', DealerStockBatchListAPIView.as_view(), name='erp_dealer_batches'),
    path('dealer-stock-requests/', DealerStockRequestListCreateAPIView.as_view(), name='erp_dealer_stock_requests'),
    path('dealer-stock-requests/<int:pk>/dispatch/', DealerStockRequestDispatchAPIView.as_view(), name='erp_dealer_stock_request_dispatch'),
    path('dealer-stock-requests/<int:pk>/receive/', DealerStockRequestReceiveAPIView.as_view(), name='erp_dealer_stock_request_receive'),
    path('ledger/', InventoryLedgerListAPIView.as_view(), name='erp_inventory_ledger'),
    path('expenses/', ExpenseListCreateAPIView.as_view(), name='erp_expenses'),
    path('daily-reports/', DailyBusinessReportAPIView.as_view(), name='erp_daily_reports'),
    path('expiry-alerts/', ExpiryAlertListAPIView.as_view(), name='erp_expiry_alerts'),
    path('stock/adjust/', StockAdjustmentAPIView.as_view(), name='erp_stock_adjust'),
]
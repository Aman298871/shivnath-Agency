from django.urls import path
from billing.views import (
    InvoiceListAPIView,
    InvoiceDetailAPIView,
    RecordPaymentAPIView,
    DealerCreditProfileAPIView,
    DealerAgingReportAPIView,
    CompanyBillingProfileAPIView,
)

urlpatterns = [
    path('invoices/', InvoiceListAPIView.as_view(), name='billing_invoices_list'),
    path('invoices/<int:pk>/', InvoiceDetailAPIView.as_view(), name='billing_invoice_detail'),
    path('invoices/<int:invoice_id>/payments/', RecordPaymentAPIView.as_view(), name='billing_record_payment'),
    path('dealers/<int:dealer_id>/credit-profile/', DealerCreditProfileAPIView.as_view(), name='billing_dealer_credit'),
    path('dealers/<int:dealer_id>/aging/', DealerAgingReportAPIView.as_view(), name='billing_dealer_aging'),
    path('company-profile/', CompanyBillingProfileAPIView.as_view(), name='billing_company_profile'),
]

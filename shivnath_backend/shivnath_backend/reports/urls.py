from django.urls import path
from .csv_export_views import ExportReportCSVView

urlpatterns = [
    path('export/', ExportReportCSVView.as_view(), name='export_report_csv'),
    path('export/<str:report_type>/', ExportReportCSVView.as_view(), name='export_report_type_csv'),
]

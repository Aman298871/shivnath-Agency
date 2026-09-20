from rest_framework import generics, status, views, permissions
from rest_framework.response import Response
from django.shortcuts import get_object_or_404

from billing.models import CompanyBillingProfile, DealerCreditProfile, Invoice, PaymentTransaction
from billing.serializers import (
    CompanyBillingProfileSerializer,
    DealerCreditProfileSerializer,
    InvoiceSerializer,
    PaymentTransactionSerializer,
)
from billing.services import record_payment_transaction, get_dealer_aging_report


class InvoiceListAPIView(generics.ListAPIView):
    serializer_class = InvoiceSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        qs = Invoice.objects.all()

        # Role / Data Scoping
        if hasattr(user, 'profile') and user.profile.role == 'franchise':
            # Dealers see their purchase invoices and customer invoices they fulfilled
            dealer = getattr(user, 'franchise_profile', None)
            if dealer:
                qs = qs.filter(
                    models.Q(stock_request__dealer=dealer) |
                    models.Q(order__serving_franchise=dealer)
                )
            else:
                qs = qs.none()
        elif hasattr(user, 'profile') and user.profile.role == 'customer':
            qs = qs.filter(order__created_by=user)

        invoice_type = self.request.query_params.get('invoice_type')
        if invoice_type:
            qs = qs.filter(invoice_type=invoice_type)

        status_param = self.request.query_params.get('status')
        if status_param:
            qs = qs.filter(status=status_param)

        return qs


class InvoiceDetailAPIView(generics.RetrieveAPIView):
    queryset = Invoice.objects.all()
    serializer_class = InvoiceSerializer
    permission_classes = [permissions.IsAuthenticated]


class RecordPaymentAPIView(views.APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, invoice_id):
        amount = request.data.get('amount')
        payment_method = request.data.get('payment_method', 'UPI')
        reference_number = request.data.get('reference_number', '')
        notes = request.data.get('notes', '')

        if not amount:
            return Response({'error': 'Amount is required.'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            txn = record_payment_transaction(
                invoice_id=invoice_id,
                amount_paid=amount,
                payment_method=payment_method,
                reference_number=reference_number,
                actor=request.user,
                notes=notes
            )
            return Response(PaymentTransactionSerializer(txn).data, status=status.HTTP_201_CREATED)
        except Exception as e:
            return Response({'error': str(e)}, status=status.HTTP_400_BAD_REQUEST)


class DealerCreditProfileAPIView(views.APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, dealer_id):
        profile, _ = DealerCreditProfile.objects.get_or_create(dealer_id=dealer_id)
        return Response(DealerCreditProfileSerializer(profile).data)

    def put(self, request, dealer_id):
        profile, _ = DealerCreditProfile.objects.get_or_create(dealer_id=dealer_id)
        serializer = DealerCreditProfileSerializer(profile, data=request.data, partial=True)
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class DealerAgingReportAPIView(views.APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, dealer_id):
        aging = get_dealer_aging_report(dealer_id)
        return Response(aging)


class CompanyBillingProfileAPIView(views.APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        profile = CompanyBillingProfile.objects.first()
        if not profile:
            profile = CompanyBillingProfile.objects.create()
        return Response(CompanyBillingProfileSerializer(profile).data)

    def put(self, request):
        if not hasattr(request.user, 'profile') or request.user.profile.role not in ['super_admin', 'admin']:
            return Response({'error': 'Unauthorized'}, status=status.HTTP_403_FORBIDDEN)

        profile = CompanyBillingProfile.objects.first()
        if not profile:
            profile = CompanyBillingProfile.objects.create()
        serializer = CompanyBillingProfileSerializer(profile, data=request.data, partial=True)
        if serializer.is_valid():
            serializer.save(is_configured=True)
            return Response(serializer.data)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

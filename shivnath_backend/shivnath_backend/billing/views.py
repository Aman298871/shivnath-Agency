from django.db import models
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
from billing.services import (
    record_payment_transaction,
    submit_payment_for_verification,
    verify_payment_transaction,
    reject_payment_transaction,
    get_dealer_aging_report,
)


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
                    models.Q(order__serving_franchise=dealer) |
                    models.Q(billed_to_name=dealer.business_name)
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
            return Response({'success': False, 'message': 'Amount is required.', 'error': 'Amount is required.'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            txn = record_payment_transaction(
                invoice_id=invoice_id,
                amount_paid=amount,
                payment_method=payment_method,
                reference_number=reference_number,
                actor=request.user,
                notes=notes
            )
            is_pending = (txn.payment_status == 'PENDING')
            msg = 'Payment submitted. Awaiting Admin verification and approval.' if is_pending else 'Payment recorded and verified successfully.'
            return Response({
                'success': True,
                'message': msg,
                'is_pending_verification': is_pending,
                'data': PaymentTransactionSerializer(txn).data
            }, status=status.HTTP_201_CREATED)
        except Exception as e:
            return Response({'success': False, 'message': str(e), 'error': str(e)}, status=status.HTTP_400_BAD_REQUEST)


class VerifyPaymentAPIView(views.APIView):
    """
    Admin verifies funds receipt into company bank/cash account.
    Marks transaction SUCCESS, invoice PAID/PARTIAL, and deducts dealer credit profile.
    """
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, invoice_id):
        is_admin = (
            request.user.is_staff or 
            request.user.is_superuser or 
            (hasattr(request.user, 'profile') and request.user.profile.role in ['super_admin', 'admin'])
        )
        if not is_admin:
            return Response({
                'success': False,
                'message': 'Unauthorized. Only administrators can verify and approve payments.'
            }, status=status.HTTP_403_FORBIDDEN)

        try:
            txn = verify_payment_transaction(
                invoice_id=invoice_id,
                actor=request.user,
                notes=request.data.get('notes', '')
            )
            return Response({
                'success': True,
                'message': f'Payment of ₹{txn.amount_paid} verified and approved successfully. Dealer ledger updated.',
                'data': PaymentTransactionSerializer(txn).data
            })
        except Exception as e:
            return Response({'success': False, 'message': str(e), 'error': str(e)}, status=status.HTTP_400_BAD_REQUEST)


class RejectPaymentAPIView(views.APIView):
    """
    Admin rejects unverified or fraudulent payment references.
    Reverts invoice back to UNPAID or PARTIALLY_PAID and notifies dealer.
    """
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, invoice_id):
        is_admin = (
            request.user.is_staff or 
            request.user.is_superuser or 
            (hasattr(request.user, 'profile') and request.user.profile.role in ['super_admin', 'admin'])
        )
        if not is_admin:
            return Response({
                'success': False,
                'message': 'Unauthorized. Only administrators can reject payments.'
            }, status=status.HTTP_403_FORBIDDEN)

        reason = request.data.get('reason', request.data.get('notes', 'Payment could not be verified in bank statement.'))
        try:
            txn = reject_payment_transaction(
                invoice_id=invoice_id,
                actor=request.user,
                rejection_reason=reason
            )
            return Response({
                'success': True,
                'message': 'Payment rejected. Dealer has been notified.',
                'data': PaymentTransactionSerializer(txn).data
            })
        except Exception as e:
            return Response({'success': False, 'message': str(e), 'error': str(e)}, status=status.HTTP_400_BAD_REQUEST)


def _resolve_dealer(user, dealer_id):
    from accounts.models import FranchiseProfile
    # 1. If logged-in user is a franchise, ALWAYS return their own franchise profile
    if hasattr(user, 'franchise_profile') and user.franchise_profile:
        return user.franchise_profile
    if hasattr(user, 'profile') and user.profile.role == 'franchise':
        dealer = FranchiseProfile.objects.filter(user=user).first()
        if dealer:
            return dealer

    # 2. Otherwise (e.g. Admin inspecting a specific dealer):
    dealer = None
    if dealer_id and int(dealer_id) > 0:
        dealer = FranchiseProfile.objects.filter(id=dealer_id).first()
        if not dealer:
            dealer = FranchiseProfile.objects.filter(user_id=dealer_id).first()
    if not dealer:
        dealer = FranchiseProfile.objects.filter(status='approved').first() or FranchiseProfile.objects.first()
    return dealer


class DealerCreditProfileAPIView(views.APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, dealer_id):
        dealer = _resolve_dealer(request.user, dealer_id)
        if not dealer:
            return Response({'error': 'Dealer not found.'}, status=status.HTTP_404_NOT_FOUND)
        profile, _ = DealerCreditProfile.objects.get_or_create(dealer=dealer)
        return Response(DealerCreditProfileSerializer(profile).data)

    def put(self, request, dealer_id):
        dealer = _resolve_dealer(request.user, dealer_id)
        if not dealer:
            return Response({'error': 'Dealer not found.'}, status=status.HTTP_404_NOT_FOUND)
        profile, _ = DealerCreditProfile.objects.get_or_create(dealer=dealer)
        serializer = DealerCreditProfileSerializer(profile, data=request.data, partial=True)
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class DealerAgingReportAPIView(views.APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, dealer_id):
        dealer = _resolve_dealer(request.user, dealer_id)
        d_id = dealer.id if dealer else dealer_id
        aging = get_dealer_aging_report(d_id)
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


class RecordOrderPaymentAPIView(views.APIView):
    """
    Authoritative endpoint for recording payment on an Order by either Franchise or Admin.
    Automatically generates invoice if not present, links payment to Order, Invoice, and Customer,
    records authoritative PaymentTransaction, and creates audit notification.
    """
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, order_id):
        from orders.models import Order
        order = get_object_or_404(Order, id=order_id)
        user = request.user
        role = getattr(getattr(user, 'profile', None), 'role', '')
        if not user.is_superuser and role not in ['admin', 'super_admin']:
            fp = getattr(user, 'franchise_profile', None)
            if role == 'franchise':
                if not fp or (order.serving_franchise != fp and order.registered_franchise != fp):
                    return Response({'error': 'Unauthorized to view payments for this order.'}, status=status.HTTP_403_FORBIDDEN)
            elif role == 'customer':
                if order.created_by != user:
                    return Response({'error': 'Unauthorized to view payments for this order.'}, status=status.HTTP_403_FORBIDDEN)

        if not hasattr(order, 'invoice') or not order.invoice:
            return Response({
                'success': True,
                'order_id': order.id,
                'order_code': order.order_code,
                'payments': [],
                'total_amount': float(order.grand_total or order.amount or 0.0),
                'amount_paid': 0.0,
                'outstanding_balance': float(order.grand_total or order.amount or 0.0),
                'payment_status': order.payment_status,
            })

        payments = PaymentTransaction.objects.filter(invoice=order.invoice).order_by('-payment_date')
        return Response({
            'success': True,
            'order_id': order.id,
            'order_code': order.order_code,
            'invoice_number': order.invoice.invoice_number,
            'total_amount': float(order.invoice.grand_total),
            'amount_paid': float(order.invoice.amount_paid),
            'outstanding_balance': float(order.invoice.outstanding_balance),
            'payment_status': order.invoice.status,
            'payments': PaymentTransactionSerializer(payments, many=True).data,
        })

    def post(self, request, order_id):
        from orders.models import Order
        from decimal import Decimal
        from billing.services import generate_invoice_for_order

        order = get_object_or_404(Order, id=order_id)
        user = request.user
        role = getattr(getattr(user, 'profile', None), 'role', '')

        # Permission check: Admin, Super Admin, or the serving Franchise
        if not user.is_superuser and role not in ['admin', 'super_admin']:
            fp = getattr(user, 'franchise_profile', None)
            if role == 'franchise':
                if not fp or (order.serving_franchise != fp and order.registered_franchise != fp):
                    return Response({'error': 'Unauthorized to collect payment for this order.'}, status=status.HTTP_403_FORBIDDEN)
            else:
                return Response({'error': 'Unauthorized to record payments.'}, status=status.HTTP_403_FORBIDDEN)

        invoice = generate_invoice_for_order(order)
        outstanding = invoice.outstanding_balance

        if outstanding <= Decimal('0.00'):
            return Response({'error': 'Order invoice is already fully paid.'}, status=status.HTTP_400_BAD_REQUEST)

        payment_type = str(request.data.get('payment_type', '')).upper().strip()
        amount_raw = request.data.get('amount')
        if payment_type == 'FULL' or not amount_raw:
            amount = outstanding
        else:
            try:
                amount = Decimal(str(amount_raw))
            except Exception:
                return Response({'error': 'Invalid payment amount.'}, status=status.HTTP_400_BAD_REQUEST)

        if amount <= Decimal('0.00'):
            return Response({'error': 'Payment amount must be greater than zero.'}, status=status.HTTP_400_BAD_REQUEST)

        if amount > outstanding:
            amount = outstanding

        payment_method = request.data.get('payment_method', 'CASH')
        reference_number = request.data.get('reference_number', '') or request.data.get('transaction_reference', '')
        notes = request.data.get('notes', '')

        try:
            txn = record_payment_transaction(
                invoice_id=invoice.id,
                amount_paid=amount,
                payment_method=payment_method,
                reference_number=reference_number,
                actor=user,
                notes=notes
            )

            # Create notification for Admin & Super Admin & Customer Push
            try:
                from accounts.models import AdminNotification
                from accounts.fcm_services import notify_payment_received
                collector_name = user.get_full_name() or user.username
                if role == 'franchise' and hasattr(user, 'franchise_profile'):
                    collector_name = f"Franchise {user.franchise_profile.business_name}"
                AdminNotification.objects.create(
                    title=f"Payment Collected: Order #{order.order_code}",
                    message=f"₹{amount} collected for Order #{order.order_code} by {collector_name} via {payment_method}. Remaining balance: ₹{invoice.outstanding_balance}.",
                    notification_type='general',
                    reference_id=order.id
                )
                notify_payment_received(order, amount, collector_name=collector_name)
            except Exception:
                pass

            invoice.refresh_from_db()
            order.refresh_from_db()

            return Response({
                'success': True,
                'message': f"Payment of ₹{amount} successfully recorded.",
                'transaction': PaymentTransactionSerializer(txn).data,
                'invoice': InvoiceSerializer(invoice).data,
                'order_payment_status': order.payment_status,
                'outstanding_balance': float(invoice.outstanding_balance),
            }, status=status.HTTP_201_CREATED)
        except Exception as e:
            return Response({'error': str(e)}, status=status.HTTP_400_BAD_REQUEST)


from accounts.fcm_services import logger
from django.db import models
from django.utils import timezone
import datetime
from decimal import Decimal
from django.http import HttpResponse
from rest_framework import generics, status, views, permissions
from rest_framework.response import Response
from django.shortcuts import get_object_or_404
from accounts.permissions import IsAdminRole, DenyStockManager

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
    _process_payment_verification,
    get_dealer_aging_report,
    get_dealer_account_statement,
    get_dealer_stock_payment_reconciliation,
)


class InvoiceListAPIView(generics.ListAPIView):
    serializer_class = InvoiceSerializer
    permission_classes = [permissions.IsAuthenticated, DenyStockManager]

    def get_queryset(self):
        user = self.request.user
        if hasattr(user, 'profile') and user.profile.role == 'stock_manager':
            from rest_framework.exceptions import PermissionDenied
            raise PermissionDenied("Stock managers are forbidden from accessing financial invoices and billing.")

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
    permission_classes = [permissions.IsAuthenticated, DenyStockManager]

    def get_object(self):
        user = self.request.user
        if hasattr(user, 'profile') and user.profile.role == 'stock_manager':
            from rest_framework.exceptions import PermissionDenied
            raise PermissionDenied("Stock managers are forbidden from accessing financial invoices and billing.")
        return super().get_object()


class RecordPaymentAPIView(views.APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, invoice_id):
        user = request.user
        if hasattr(user, 'profile') and user.profile.role == 'stock_manager':
            return Response({'success': False, 'message': 'Stock managers cannot record invoice payments.'}, status=status.HTTP_403_FORBIDDEN)

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
            is_pending = (txn.payment_status in ['PENDING', 'PENDING_VERIFICATION'])
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
    is_admin = (
        user.is_staff or 
        user.is_superuser or 
        (hasattr(user, 'profile') and user.profile.role in ['super_admin', 'admin'])
    )
    if is_admin and dealer_id and int(dealer_id) > 0:
        dealer = FranchiseProfile.objects.filter(id=dealer_id).first()
        if not dealer:
            dealer = FranchiseProfile.objects.filter(user_id=dealer_id).first()
        if dealer:
            return dealer

    # If logged-in user is a franchise, ALWAYS return their own franchise profile
    if hasattr(user, 'franchise_profile') and user.franchise_profile:
        return user.franchise_profile
    if hasattr(user, 'profile') and user.profile.role == 'franchise':
        dealer = FranchiseProfile.objects.filter(user=user).first()
        if dealer:
            return dealer

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
        user = request.user
        is_admin = (
            user.is_staff or 
            user.is_superuser or 
            (hasattr(user, 'profile') and user.profile.role in ['super_admin', 'admin'])
        )
        is_dealer = hasattr(user, 'profile') and user.profile.role == 'franchise'
        if not (is_admin or is_dealer):
            return Response({'error': 'Unauthorized to view dealer credit profile.'}, status=status.HTTP_403_FORBIDDEN)

        dealer = _resolve_dealer(request.user, dealer_id)
        if not dealer:
            return Response({'error': 'Dealer not found.'}, status=status.HTTP_404_NOT_FOUND)
        profile, _ = DealerCreditProfile.objects.get_or_create(dealer=dealer)
        return Response(DealerCreditProfileSerializer(profile).data)

    def put(self, request, dealer_id):
        is_admin = (
            request.user.is_staff or 
            request.user.is_superuser or 
            (hasattr(request.user, 'profile') and request.user.profile.role in ['super_admin', 'admin'])
        )
        if not is_admin:
            return Response({
                'success': False,
                'message': 'Unauthorized. Only administrators can update franchise credit limit and terms.'
            }, status=status.HTTP_403_FORBIDDEN)

        dealer = _resolve_dealer(request.user, dealer_id)
        if not dealer:
            return Response({'error': 'Dealer not found.'}, status=status.HTTP_404_NOT_FOUND)
        profile, _ = DealerCreditProfile.objects.get_or_create(dealer=dealer)
        serializer = DealerCreditProfileSerializer(profile, data=request.data, partial=True)
        if serializer.is_valid():
            serializer.save()
            data = serializer.data
            return Response({
                'success': True,
                'message': 'Credit profile updated successfully.',
                'data': data,
                **data
            })
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class DealerAgingReportAPIView(views.APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, dealer_id):
        user = request.user
        is_admin = (
            user.is_staff or 
            user.is_superuser or 
            (hasattr(user, 'profile') and user.profile.role in ['super_admin', 'admin'])
        )
        is_dealer = hasattr(user, 'profile') and user.profile.role == 'franchise'
        if not (is_admin or is_dealer):
            return Response({'error': 'Unauthorized to view dealer aging reports.'}, status=status.HTTP_403_FORBIDDEN)

        dealer = _resolve_dealer(request.user, dealer_id)
        d_id = dealer.id if dealer else dealer_id
        aging = get_dealer_aging_report(d_id)
        return Response(aging)


class DealerAccountStatementAPIView(views.APIView):
    """
    Franchise Account Statement:
    Returns chronological ledger of wholesale purchase invoices (debits) and
    payment instalments (credits) with running balance and payment status.
    """
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, dealer_id):
        user = request.user
        is_admin = (
            user.is_staff or 
            user.is_superuser or 
            (hasattr(user, 'profile') and user.profile.role in ['super_admin', 'admin'])
        )
        is_dealer = hasattr(user, 'profile') and user.profile.role == 'franchise'
        if not (is_admin or is_dealer):
            return Response({'error': 'Unauthorized to view dealer account statements.'}, status=status.HTTP_403_FORBIDDEN)

        dealer = _resolve_dealer(request.user, dealer_id)
        if not dealer:
            return Response({'error': 'Dealer not found.'}, status=status.HTTP_404_NOT_FOUND)

        start_date = request.query_params.get('start_date')
        end_date = request.query_params.get('end_date')

        try:
            statement = get_dealer_account_statement(dealer.id, start_date=start_date, end_date=end_date)
            return Response({'success': True, 'data': statement, **statement})
        except Exception as e:
            return Response({'success': False, 'error': str(e)}, status=status.HTTP_400_BAD_REQUEST)


class DealerStockPaymentReconciliationAPIView(views.APIView):
    """
    Stock-versus-Payment Reconciliation:
    Audits physical and batch stock in dealer warehouse against wholesale purchase
    invoicing and approved payment transactions to detect discrepancies.
    """
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, dealer_id):
        user = request.user
        is_admin = (
            user.is_staff or 
            user.is_superuser or 
            (hasattr(user, 'profile') and user.profile.role in ['super_admin', 'admin'])
        )
        is_dealer = hasattr(user, 'profile') and user.profile.role == 'franchise'
        if not (is_admin or is_dealer):
            return Response({'error': 'Unauthorized to view dealer stock-payment reconciliation.'}, status=status.HTTP_403_FORBIDDEN)

        dealer = _resolve_dealer(request.user, dealer_id)
        if not dealer:
            return Response({'error': 'Dealer not found.'}, status=status.HTTP_404_NOT_FOUND)

        try:
            reconciliation = get_dealer_stock_payment_reconciliation(dealer.id)
            return Response({'success': True, 'data': reconciliation, **reconciliation})
        except Exception as e:
            return Response({'success': False, 'error': str(e)}, status=status.HTTP_400_BAD_REQUEST)


class CompanyBillingProfileAPIView(views.APIView):
    permission_classes = [IsAdminRole]

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
    Authoritative endpoint for recording customer payment on an Order by either Franchise or Admin.
    Directly settles the customer sale invoice, updates Order payment_status immediately,
    and logs an authoritative PaymentTransaction.
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

        is_paid = (getattr(order, 'payment_status', '').lower() == 'paid')
        total_amt = float(order.grand_total or order.amount or 0.0)

        from billing.models import Invoice, PaymentTransaction
        from billing.services import generate_invoice_for_order
        invoice = Invoice.objects.filter(order=order).first()
        if not invoice:
            invoice = generate_invoice_for_order(order)

        if not invoice:
            return Response({
                'success': True,
                'order_id': order.id,
                'order_code': order.order_code,
                'payments': [],
                'total_amount': total_amt,
                'amount_paid': total_amt if is_paid else 0.0,
                'outstanding_balance': 0.0 if is_paid else total_amt,
                'payment_status': 'PAID' if is_paid else order.payment_status,
                'payment_collected': is_paid,
                'is_pending_verification': False,
            })

        if is_paid and invoice.status != 'PAID':
            try:
                invoice.amount_paid = Decimal(str(invoice.grand_total))
                invoice.status = 'PAID'
                invoice.save(update_fields=['amount_paid', 'status'])
            except Exception:
                pass

        payments = PaymentTransaction.objects.filter(invoice=invoice).order_by('-payment_date')
        inv_paid = invoice.status == 'PAID' or is_paid
        has_pending = payments.filter(payment_status__in=['PENDING', 'PENDING_VERIFICATION']).exists()
        
        # Order payment is collected if fully paid
        payment_status_display = 'PAID' if inv_paid else ('PARTIALLY_PAID' if invoice.status == 'PARTIALLY_PAID' or order.payment_status == 'partial' else 'PENDING')

        return Response({
            'success': True,
            'order_id': order.id,
            'order_code': order.order_code,
            'invoice_number': invoice.invoice_number,
            'total_amount': float(invoice.grand_total),
            'amount_paid': float(invoice.grand_total) if inv_paid else float(invoice.amount_paid),
            'outstanding_balance': 0.0 if inv_paid else float(invoice.outstanding_balance),
            'payment_status': payment_status_display,
            'payment_collected': inv_paid,
            'is_pending_verification': (invoice.status == 'PAYMENT_PENDING_VERIFICATION' or getattr(order, 'payment_status', '').lower() == 'pending_verification') and not inv_paid,
            'payments': PaymentTransactionSerializer(payments, many=True).data,
        })

    def post(self, request, order_id):
        from orders.models import Order
        from billing.services import generate_invoice_for_order

        order = get_object_or_404(Order, id=order_id)
        user = request.user
        role = getattr(getattr(user, 'profile', None), 'role', '')

        # Permission check: Admin, Super Admin, or the fulfilling/registered Franchise
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
                return Response({'error': 'Invalid payment amount.', 'message': 'Invalid payment amount.'}, status=status.HTTP_400_BAD_REQUEST)

        if amount <= Decimal('0.00'):
            return Response({'error': 'Payment amount must be greater than zero.', 'message': 'Payment amount must be greater than zero.'}, status=status.HTTP_400_BAD_REQUEST)

        if amount > outstanding:
            msg = f'Payment amount (₹{amount}) exceeds remaining balance (₹{outstanding}).'
            return Response({
                'error': msg,
                'message': msg
            }, status=status.HTTP_400_BAD_REQUEST)

        payment_method = request.data.get('payment_method', 'CASH')
        reference_number = request.data.get('reference_number', '') or request.data.get('transaction_reference', '')
        notes = request.data.get('notes', '')

        # Duplicate submission protection (prevent double-click within 30s)
        cutoff = timezone.now() - datetime.timedelta(seconds=30)
        clean_method = 'CASH' if 'CASH' in str(payment_method).upper() else ('UPI' if 'UPI' in str(payment_method).upper() else 'OTHER')
        dup = PaymentTransaction.objects.filter(
            invoice=invoice,
            amount_paid=amount,
            received_by=user,
            payment_status='SUCCESS',
            payment_date__gte=cutoff
        ).first()
        if dup:
            msg = 'Duplicate payment submission detected. This payment was already recorded.'
            return Response({
                'error': msg,
                'message': msg,
                'transaction': PaymentTransactionSerializer(dup).data
            }, status=status.HTTP_409_CONFLICT)

        try:
            # Settle immediately for customer order collection by Franchise/Admin
            txn = record_payment_transaction(
                invoice_id=invoice.id,
                amount_paid=amount,
                payment_method=payment_method,
                reference_number=reference_number,
                actor=user,
                notes=notes,
                is_direct_collection=True
            )

            # Notifications
            try:
                from accounts.models import AdminNotification
                from accounts.fcm_services import notify_payment_received
                collector_name = user.get_full_name() or user.username
                if role == 'franchise' and hasattr(user, 'franchise_profile'):
                    collector_name = f"Franchise {user.franchise_profile.business_name}"

                invoice.refresh_from_db()
                notif_title = f"Payment Collected: Order #{order.order_code}"
                notif_msg = f"₹{amount} collected for Order #{order.order_code} by {collector_name} via {payment_method}. Remaining balance: ₹{invoice.outstanding_balance}."
                
                AdminNotification.objects.create(
                    title=notif_title,
                    message=notif_msg,
                    notification_type='general',
                    reference_id=invoice.id
                )
                notify_payment_received(
                    order=order,
                    amount=amount,
                    actor_name=collector_name,
                    collector_name=collector_name,
                    is_pending=False,
                    invoice=invoice
                )
            except Exception as e:
                logger.warning("FCM: Payment notification dispatch warning: %s", e)

            invoice.refresh_from_db()
            order.refresh_from_db()

            msg = f"Payment of ₹{amount} successfully recorded."
            res_data = {
                'payment_collected': order.payment_status == 'paid',
                'order_payment_status': order.payment_status,
                'is_pending_verification': False,
                'amount_paid': float(invoice.amount_paid),
                'outstanding_balance': float(invoice.outstanding_balance),
                'total_amount': float(invoice.grand_total),
                'transaction': PaymentTransactionSerializer(txn).data,
                'invoice': InvoiceSerializer(invoice).data,
            }

            return Response({
                'success': True,
                'message': msg,
                'data': res_data,
                **res_data
            }, status=status.HTTP_201_CREATED)
        except Exception as e:
            return Response({'error': str(e), 'message': str(e)}, status=status.HTTP_400_BAD_REQUEST)


class FranchiseCollectionsSummaryAPIView(views.APIView):
    """
    Authoritative Admin endpoint for aggregated franchise collections:
    - Total collected (overall & within date range)
    - Breakdown by payment mode (Cash, UPI, Cheque, etc.)
    - Breakdown by date
    - Breakdown by franchise
    - Total outstanding customer balances
    - Discrepancies and exceptions
    - Recent transaction log for inspection
    """
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        is_admin = (
            request.user.is_staff or 
            request.user.is_superuser or 
            (hasattr(request.user, 'profile') and request.user.profile.role in ['super_admin', 'admin'])
        )
        if not is_admin:
            return Response({'error': 'Unauthorized'}, status=status.HTTP_403_FORBIDDEN)

        from django.db.models import Sum, Count, Q
        from orders.models import Order
        from accounts.models import FranchiseProfile

        qs = PaymentTransaction.objects.filter(
            invoice__order__isnull=False,
            payment_status='SUCCESS'
        ).select_related('invoice', 'invoice__order', 'received_by')

        # Optional date filters
        start_date_str = request.query_params.get('start_date')
        end_date_str = request.query_params.get('end_date')
        if start_date_str:
            try:
                qs = qs.filter(payment_date__date__gte=start_date_str)
            except Exception:
                pass
        if end_date_str:
            try:
                qs = qs.filter(payment_date__date__lte=end_date_str)
            except Exception:
                pass

        franchise_id = request.query_params.get('franchise_id')
        if franchise_id:
            qs = qs.filter(
                Q(invoice__order__serving_franchise_id=franchise_id) |
                Q(invoice__order__registered_franchise_id=franchise_id)
            )

        total_collected = qs.aggregate(total=Sum('amount_paid'))['total'] or Decimal('0.00')
        cash_collected = qs.filter(payment_method='CASH').aggregate(total=Sum('amount_paid'))['total'] or Decimal('0.00')
        upi_collected = qs.filter(payment_method='UPI').aggregate(total=Sum('amount_paid'))['total'] or Decimal('0.00')
        other_collected = qs.exclude(payment_method__in=['CASH', 'UPI']).aggregate(total=Sum('amount_paid'))['total'] or Decimal('0.00')

        # Customer orders outstanding
        unpaid_orders = Order.objects.filter(
            payment_status__in=['pending', 'partial']
        ).exclude(
            status='cancelled'
        ).exclude(
            order_source='WATER_WALLET_REDEMPTION'
        )
        if franchise_id:
            unpaid_orders = unpaid_orders.filter(serving_franchise_id=franchise_id)
        
        total_outstanding = Decimal('0.00')
        for o in unpaid_orders:
            # If order has no remaining payable amount, skip
            if getattr(o, 'remaining_payable_amount', None) is not None and o.remaining_payable_amount <= Decimal('0.00') and ((getattr(o, 'points_discount_amount', 0) or 0) > 0 or (getattr(o, 'wallet_amount_debited', 0) or 0) > 0):
                continue
            inv = Invoice.objects.filter(order=o).first()
            if inv:
                total_outstanding += inv.outstanding_balance
            else:
                rem = getattr(o, 'remaining_payable_amount', None)
                if rem is not None and (getattr(o, 'points_discount_amount', 0) > 0 or getattr(o, 'wallet_amount_debited', 0) > 0):
                    total_outstanding += rem
                else:
                    total_outstanding += (o.grand_total or o.amount or Decimal('0.00'))

        # Exceptions / discrepancies:
        # Delivered orders unpaid for more than 3 days
        three_days_ago = timezone.now() - datetime.timedelta(days=3)
        overdue_delivered_count = unpaid_orders.filter(status='delivered', updated_at__lte=three_days_ago).count()

        # Collections by Franchise
        franchises = FranchiseProfile.objects.all()
        franchise_breakdown = []
        for f in franchises:
            f_qs = qs.filter(
                Q(invoice__order__serving_franchise=f) | Q(invoice__order__registered_franchise=f)
            )
            f_total = f_qs.aggregate(total=Sum('amount_paid'))['total'] or Decimal('0.00')
            if f_total > Decimal('0.00'):
                f_cash = f_qs.filter(payment_method='CASH').aggregate(total=Sum('amount_paid'))['total'] or Decimal('0.00')
                f_upi = f_qs.filter(payment_method='UPI').aggregate(total=Sum('amount_paid'))['total'] or Decimal('0.00')
                franchise_breakdown.append({
                    'franchise_id': f.id,
                    'franchise_name': f.business_name,
                    'total_collected': float(f_total),
                    'cash_collected': float(f_cash),
                    'upi_collected': float(f_upi),
                    'transaction_count': f_qs.count()
                })

        # Recent 25 collections
        recent = []
        for txn in qs.order_by('-payment_date')[:25]:
            order = txn.invoice.order if txn.invoice else None
            f_name = 'Franchise'
            if order and order.serving_franchise:
                f_name = order.serving_franchise.business_name
            elif txn.received_by and hasattr(txn.received_by, 'franchise_profile'):
                f_name = txn.received_by.franchise_profile.business_name

            recent.append({
                'id': txn.id,
                'transaction_number': txn.transaction_number,
                'order_id': order.id if order else None,
                'order_code': order.order_code if order else '',
                'invoice_number': txn.invoice.invoice_number if txn.invoice else '',
                'customer_name': txn.invoice.billed_to_name if txn.invoice else (order.customer_name if order else ''),
                'franchise_name': f_name,
                'amount_paid': float(txn.amount_paid),
                'payment_method': txn.payment_method,
                'reference_number': txn.reference_number,
                'notes': txn.notes,
                'payment_status': txn.payment_status,
                'payment_date': txn.payment_date.strftime('%Y-%m-%d %H:%M:%S') if txn.payment_date else '',
                'received_by_name': txn.received_by.get_full_name() or txn.received_by.username if txn.received_by else '',
            })

        summary_payload = {
            'summary': {
                'total_collected_in_period': float(total_collected),
                'total_collected': float(total_collected),
                'total_cash_collected': float(cash_collected),
                'total_upi_collected': float(upi_collected),
                'total_other_collected': float(other_collected),
                'total_customer_outstanding': float(total_outstanding),
                'total_outstanding': float(total_outstanding),
                'total_transactions_in_period': qs.count(),
                'total_transaction_count': qs.count(),
                'overdue_delivered_unpaid_count': overdue_delivered_count,
            },
            'by_mode': {
                'cash': float(cash_collected),
                'upi': float(upi_collected),
                'other': float(other_collected),
            },
            'franchise_breakdown': franchise_breakdown,
            'recent_collections': recent,
            'recent_transactions': recent,
        }

        return Response({
            'success': True,
            'data': summary_payload,
            **summary_payload
        })


class PendingPaymentsAPIView(views.APIView):
    """
    Returns all real database PaymentTransactions awaiting admin verification.
    Direct authoritative query from PaymentTransaction model.
    """
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        is_admin = (
            request.user.is_staff or 
            request.user.is_superuser or 
            (hasattr(request.user, 'profile') and request.user.profile.role in ['super_admin', 'admin'])
        )
        if not is_admin:
            return Response({'error': 'Unauthorized'}, status=status.HTTP_403_FORBIDDEN)

        pending_txns = PaymentTransaction.objects.filter(
            payment_status='PENDING_VERIFICATION'
        ).select_related('invoice', 'invoice__order', 'received_by').order_by('-payment_date')

        data = []
        for txn in pending_txns:
            inv = txn.invoice
            order = inv.order if inv else None
            franchise_name = 'Franchise'
            if inv:
                if inv.stock_request and inv.stock_request.dealer:
                    franchise_name = inv.stock_request.dealer.business_name
                elif order and order.serving_franchise:
                    franchise_name = order.serving_franchise.business_name
                elif txn.received_by and hasattr(txn.received_by, 'franchise_profile'):
                    franchise_name = txn.received_by.franchise_profile.business_name
                elif inv.billed_to_name:
                    franchise_name = inv.billed_to_name

            data.append({
                'id': txn.id,
                'transaction_number': txn.transaction_number,
                'invoice_id': inv.id if inv else None,
                'invoice_number': inv.invoice_number if inv else 'N/A',
                'order_id': order.id if order else None,
                'order_code': order.order_code if order else '',
                'franchise_name': franchise_name,
                'customer_name': inv.billed_to_name if inv else 'N/A',
                'amount': float(txn.amount_paid),
                'amount_paid': float(txn.amount_paid),
                'payment_method': txn.payment_method,
                'reference_number': txn.reference_number,
                'notes': txn.notes,
                'payment_status': txn.payment_status,
                'submitted_at': txn.payment_date.strftime('%Y-%m-%d %H:%M') if txn.payment_date else '',
                'submitted_by': txn.received_by.get_full_name() or txn.received_by.username if txn.received_by else 'Franchise',
            })

        return Response({
            'success': True,
            'count': len(data),
            'payments': data,
            'data': data,
        })


class VerifyPaymentByTxnAPIView(views.APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, txn_id):
        is_admin = (
            request.user.is_staff or 
            request.user.is_superuser or 
            (hasattr(request.user, 'profile') and request.user.profile.role in ['super_admin', 'admin'])
        )
        if not is_admin:
            return Response({'error': 'Unauthorized'}, status=status.HTTP_403_FORBIDDEN)

        try:
            txn = _process_payment_verification(txn_id, 'approve', request.user, notes=request.data.get('notes', ''))
            return Response({
                'success': True,
                'message': f'Payment of ₹{txn.amount_paid} approved and verified successfully. Ledger and credit updated.',
                'data': PaymentTransactionSerializer(txn).data
            })
        except Exception as e:
            return Response({'success': False, 'message': str(e), 'error': str(e)}, status=status.HTTP_400_BAD_REQUEST)


class RejectPaymentByTxnAPIView(views.APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, txn_id):
        is_admin = (
            request.user.is_staff or 
            request.user.is_superuser or 
            (hasattr(request.user, 'profile') and request.user.profile.role in ['super_admin', 'admin'])
        )
        if not is_admin:
            return Response({'error': 'Unauthorized'}, status=status.HTTP_403_FORBIDDEN)

        reason = request.data.get('reason', request.data.get('notes', 'Payment could not be verified in bank statement.'))
        try:
            txn = _process_payment_verification(txn_id, 'reject', request.user, notes=reason)
            return Response({
                'success': True,
                'message': 'Payment rejected. Franchise has been notified.',
                'data': PaymentTransactionSerializer(txn).data
            })
        except Exception as e:
            return Response({'success': False, 'message': str(e), 'error': str(e)}, status=status.HTTP_400_BAD_REQUEST)


# =========================================================
# THERMAL RECEIPT & VECTOR PDF DOWNLOAD ENDPOINTS
# =========================================================

def _check_invoice_access(user, invoice):
    """
    Strict ownership and authorization check for invoices.
    Admins/staff have full access.
    Customers can only access invoices for orders they created.
    Franchises can only access invoices for orders they served or stock requests they made.
    """
    if user.is_staff or user.is_superuser:
        return True
    user_role = getattr(getattr(user, 'profile', None), 'role', 'customer')
    if user_role in ['admin', 'super_admin']:
        return True

    if user_role == 'customer':
        if invoice.order and invoice.order.created_by_id == user.id:
            return True
        return False

    if user_role == 'franchise':
        fp = getattr(user, 'franchise_profile', None)
        if not fp:
            return False
        if invoice.order and invoice.order.serving_franchise_id == fp.id:
            return True
        if invoice.stock_request and invoice.stock_request.dealer_id == fp.id:
            return True
        return False

    return False


class InvoiceThermalPrintView(views.APIView):
    """
    Print-ready thermal invoice preview (58mm or 80mm).
    Returns self-contained HTML with @media print CSS for thermal POS printers.
    """
    permission_classes = [permissions.AllowAny]

    def get(self, request, pk):
        from billing.invoice_pdf_services import generate_thermal_invoice_html
        invoice = get_object_or_404(Invoice, pk=pk)

        user = request.user
        if not user or not user.is_authenticated:
            token = request.query_params.get('token')
            if token:
                try:
                    from rest_framework_simplejwt.tokens import AccessToken
                    from django.contrib.auth import get_user_model
                    validated_token = AccessToken(token)
                    user_id = validated_token['user_id']
                    user = get_user_model().objects.get(id=user_id)
                except Exception:
                    user = None

        if not user or not user.is_authenticated:
            return Response({'error': 'Authentication credentials were not provided.'}, status=status.HTTP_401_UNAUTHORIZED)

        if not _check_invoice_access(user, invoice):
            return Response({'error': 'You do not have permission to view this invoice.'}, status=status.HTTP_403_FORBIDDEN)

        try:
            width_param = int(request.query_params.get('width', 80))
            if width_param not in [58, 80]:
                width_param = 80
        except (ValueError, TypeError):
            width_param = 80

        html_content = generate_thermal_invoice_html(invoice, paper_width_mm=width_param)
        return HttpResponse(html_content, content_type='text/html; charset=utf-8')


class InvoicePDFDownloadView(views.APIView):
    """
    Vector PDF generation and download for invoices.
    Uses pure-python standard-library PDF generator (zero external C/pypi dependency).
    """
    permission_classes = [permissions.AllowAny]

    def get(self, request, pk):
        from billing.invoice_pdf_services import generate_pure_pdf_document
        invoice = get_object_or_404(Invoice, pk=pk)

        user = request.user
        if not user or not user.is_authenticated:
            token = request.query_params.get('token')
            if token:
                try:
                    from rest_framework_simplejwt.tokens import AccessToken
                    from django.contrib.auth import get_user_model
                    validated_token = AccessToken(token)
                    user_id = validated_token['user_id']
                    user = get_user_model().objects.get(id=user_id)
                except Exception:
                    user = None

        if not user or not user.is_authenticated:
            return Response({'error': 'Authentication credentials were not provided.'}, status=status.HTTP_401_UNAUTHORIZED)

        if not _check_invoice_access(user, invoice):
            return Response({'error': 'You do not have permission to download this invoice.'}, status=status.HTTP_403_FORBIDDEN)

        pdf_bytes = generate_pure_pdf_document(invoice)
        safe_filename = invoice.invoice_number.replace('/', '_').replace('\\', '_')
        response = HttpResponse(pdf_bytes, content_type='application/pdf')
        disposition = request.query_params.get('disposition', 'attachment')
        if disposition not in ['inline', 'attachment']:
            disposition = 'attachment'
        response['Content-Disposition'] = f'{disposition}; filename="Invoice_{safe_filename}.pdf"'
        return response


class OrderInvoicePDFDownloadView(views.APIView):
    """
    Direct invoice download for an Order by order ID.
    Ensures invoice exists (generates if missing) and returns vector PDF.
    Enforces strict access control: Customer can only download their own order's invoice.
    """
    permission_classes = [permissions.AllowAny]

    def get(self, request, order_id):
        from orders.models import Order
        from billing.models import Invoice
        from billing.services import generate_invoice_for_order
        from billing.invoice_pdf_services import generate_pure_pdf_document

        order = get_object_or_404(Order, pk=order_id)

        user = request.user
        if not user or not user.is_authenticated:
            token = request.query_params.get('token')
            if token:
                try:
                    from rest_framework_simplejwt.tokens import AccessToken
                    from django.contrib.auth import get_user_model
                    validated_token = AccessToken(token)
                    user_id = validated_token['user_id']
                    user = get_user_model().objects.get(id=user_id)
                except Exception:
                    user = None

        if not user or not user.is_authenticated:
            return Response({'error': 'Authentication credentials were not provided.'}, status=status.HTTP_401_UNAUTHORIZED)

        invoice = Invoice.objects.filter(order=order).first()
        if not invoice:
            try:
                invoice = generate_invoice_for_order(order)
            except Exception as e:
                return Response({'error': f'Failed to generate invoice: {e}'}, status=status.HTTP_400_BAD_REQUEST)

        if not _check_invoice_access(user, invoice):
            return Response({'error': 'You do not have permission to download this invoice.'}, status=status.HTTP_403_FORBIDDEN)

        pdf_bytes = generate_pure_pdf_document(invoice)
        safe_filename = invoice.invoice_number.replace('/', '_').replace('\\', '_')
        response = HttpResponse(pdf_bytes, content_type='application/pdf')
        disposition = request.query_params.get('disposition', 'attachment')
        if disposition not in ['inline', 'attachment']:
            disposition = 'attachment'
        response['Content-Disposition'] = f'{disposition}; filename="Invoice_{safe_filename}.pdf"'
        return response



# =========================================================
# DISTANCE-BASED DELIVERY CALCULATION & ADMIN SETTINGS
# =========================================================

class DeliveryCalculateAPIView(views.APIView):
    """
    Authoritative distance-based delivery fee calculation endpoint.
    Client supplies destination coordinates or address to preview delivery charges.
    Backend recalculates distance via Haversine and looks up active distance bands.
    """
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        from billing.delivery_services import get_authoritative_delivery_charge
        lat = request.data.get('latitude') or request.data.get('lat')
        lng = request.data.get('longitude') or request.data.get('lng')
        address = request.data.get('address', '')
        channel = request.data.get('channel', 'CUSTOMER')

        result = get_authoritative_delivery_charge(
            dest_latitude=lat,
            dest_longitude=lng,
            dest_address=address,
            channel=channel,
        )
        is_success = bool(result.get('is_supported', True) and not result.get('is_blocked', False))
        return Response({
            'success': is_success,
            'data': result,
            **result,
        })


class DeliveryOriginSettingsAPIView(views.APIView):
    """
    Admin configuration for the authoritative dispatch origin (latitude, longitude, address).
    """
    def get_permissions(self):
        if self.request.method in ['POST', 'PATCH', 'PUT']:
            from accounts.permissions import IsAdminRole
            return [IsAdminRole()]
        return [permissions.IsAuthenticated()]

    def get(self, request):
        from billing.models import DeliveryOriginSetting
        from billing.serializers import DeliveryOriginSettingSerializer
        origin = DeliveryOriginSetting.get_active_origin()
        return Response({
            'success': True,
            'origin': DeliveryOriginSettingSerializer(origin).data,
        })

    def _update_origin(self, request):
        from billing.models import DeliveryOriginSetting
        from billing.serializers import DeliveryOriginSettingSerializer
        origin = DeliveryOriginSetting.get_active_origin()

        data = dict(request.data)
        if 'depot_name' in data and 'name' not in data:
            data['name'] = data['depot_name']
        if 'lat' in data and 'latitude' not in data:
            data['latitude'] = data['lat']
        if 'lng' in data and 'longitude' not in data:
            data['longitude'] = data['lng']

        if 'latitude' in data:
            try:
                lat_f = float(data['latitude'])
                if not (-90.0 <= lat_f <= 90.0):
                    return Response({'success': False, 'message': 'Latitude must be between -90 and 90 degrees.'}, status=status.HTTP_400_BAD_REQUEST)
            except (ValueError, TypeError):
                return Response({'success': False, 'message': 'Invalid latitude numeric value.'}, status=status.HTTP_400_BAD_REQUEST)

        if 'longitude' in data:
            try:
                lng_f = float(data['longitude'])
                if not (-180.0 <= lng_f <= 180.0):
                    return Response({'success': False, 'message': 'Longitude must be between -180 and 180 degrees.'}, status=status.HTTP_400_BAD_REQUEST)
            except (ValueError, TypeError):
                return Response({'success': False, 'message': 'Invalid longitude numeric value.'}, status=status.HTTP_400_BAD_REQUEST)

        serializer = DeliveryOriginSettingSerializer(origin, data=data, partial=True)
        if not serializer.is_valid():
            return Response({'success': False, 'errors': serializer.errors}, status=status.HTTP_400_BAD_REQUEST)
        serializer.save()
        return Response({
            'success': True,
            'message': 'Delivery origin updated successfully.',
            'origin': serializer.data,
        })

    def patch(self, request):
        return self._update_origin(request)

    def post(self, request):
        return self._update_origin(request)

    def put(self, request):
        return self._update_origin(request)


class DeliveryDistanceBandListCreateView(views.APIView):
    """
    List active delivery distance bands (public/authenticated) or create a new band (Admin).
    Enforces strict slab validation, non-negative fees, and overlap detection.
    """
    def get_permissions(self):
        if self.request.method == 'POST':
            from accounts.permissions import IsAdminRole
            return [IsAdminRole()]
        return [permissions.AllowAny()]

    def get(self, request):
        from billing.models import DeliveryDistanceBand
        from billing.serializers import DeliveryDistanceBandSerializer
        from billing.delivery_services import seed_default_distance_bands_if_empty
        from django.db import models
        seed_default_distance_bands_if_empty()

        qs = DeliveryDistanceBand.objects.all().order_by('order', 'min_distance_km')
        channel = request.query_params.get('channel')
        if channel:
            qs = qs.filter(models.Q(applies_to=channel) | models.Q(applies_to='ALL'))
        is_active = request.query_params.get('is_active')
        if is_active is not None and is_active != '':
            qs = qs.filter(is_active=str(is_active).lower() in ['true', '1'])

        serializer = DeliveryDistanceBandSerializer(qs, many=True)
        return Response({
            'success': True,
            'count': qs.count(),
            'bands': serializer.data,
        })

    def post(self, request):
        from billing.models import DeliveryDistanceBand
        from billing.serializers import DeliveryDistanceBandSerializer
        from decimal import Decimal

        data = dict(request.data)
        if 'label' in data and 'name' not in data:
            data['name'] = data['label']

        try:
            min_k = Decimal(str(data.get('min_distance_km', '0')))
            if min_k < 0:
                return Response({'success': False, 'message': 'Minimum distance cannot be negative.'}, status=status.HTTP_400_BAD_REQUEST)
        except Exception:
            return Response({'success': False, 'message': 'Invalid minimum distance.'}, status=status.HTTP_400_BAD_REQUEST)

        max_k_val = data.get('max_distance_km')
        max_k = None
        if max_k_val is not None and str(max_k_val).strip() != '':
            try:
                max_k = Decimal(str(max_k_val))
                if max_k <= min_k:
                    return Response({'success': False, 'message': f'Maximum distance ({max_k} km) must be strictly greater than minimum distance ({min_k} km).'}, status=status.HTTP_400_BAD_REQUEST)
            except Exception:
                return Response({'success': False, 'message': 'Invalid maximum distance.'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            charge = Decimal(str(data.get('delivery_charge', '0')))
            if charge < 0:
                return Response({'success': False, 'message': 'Delivery charge cannot be negative.'}, status=status.HTTP_400_BAD_REQUEST)
        except Exception:
            return Response({'success': False, 'message': 'Invalid delivery charge.'}, status=status.HTTP_400_BAD_REQUEST)

        applies_to_val = data.get('applies_to', 'ALL')
        existing_bands = DeliveryDistanceBand.objects.filter(is_active=True)
        if applies_to_val != 'ALL':
            from django.db import models
            existing_bands = existing_bands.filter(models.Q(applies_to=applies_to_val) | models.Q(applies_to='ALL'))

        for ex in existing_bands:
            ex_min = ex.min_distance_km
            ex_max = ex.max_distance_km
            overlap = False
            if max_k is not None and ex_max is not None:
                if not (max_k <= ex_min or min_k >= ex_max):
                    overlap = True
            elif max_k is None and ex_max is None:
                overlap = True
            elif max_k is None and ex_max is not None:
                if min_k < ex_max:
                    overlap = True
            elif max_k is not None and ex_max is None:
                if max_k > ex_min:
                    overlap = True

            if overlap:
                upper_str = f"{ex_max} km" if ex_max is not None else "Above"
                return Response({
                    'success': False,
                    'message': f"Overlapping distance band detected with '{ex.name}' ({ex_min} to {upper_str}). Please adjust band boundaries to prevent overlap."
                }, status=status.HTTP_400_BAD_REQUEST)

        serializer = DeliveryDistanceBandSerializer(data=data)
        if not serializer.is_valid():
            return Response({'success': False, 'errors': serializer.errors}, status=status.HTTP_400_BAD_REQUEST)
        band = serializer.save()
        return Response({
            'success': True,
            'message': f"Distance band '{band.name}' created successfully.",
            'band': serializer.data,
        }, status=status.HTTP_201_CREATED)


class DeliveryDistanceBandDetailView(views.APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get_object(self, pk):
        from billing.models import DeliveryDistanceBand
        return get_object_or_404(DeliveryDistanceBand, pk=pk)

    def get(self, request, pk):
        from billing.serializers import DeliveryDistanceBandSerializer
        band = self.get_object(pk)
        return Response({'success': True, 'band': DeliveryDistanceBandSerializer(band).data})

    def patch(self, request, pk):
        from accounts.permissions import IsAdminRole
        if not IsAdminRole().has_permission(request, self):
            return Response({'error': 'Unauthorized'}, status=status.HTTP_403_FORBIDDEN)
        from billing.serializers import DeliveryDistanceBandSerializer
        band = self.get_object(pk)
        serializer = DeliveryDistanceBandSerializer(band, data=request.data, partial=True)
        if not serializer.is_valid():
            return Response({'success': False, 'errors': serializer.errors}, status=status.HTTP_400_BAD_REQUEST)
        serializer.save()
        return Response({
            'success': True,
            'message': f"Distance band '{band.name}' updated successfully.",
            'band': serializer.data,
        })

    def delete(self, request, pk):
        from accounts.permissions import IsAdminRole
        if not IsAdminRole().has_permission(request, self):
            return Response({'error': 'Unauthorized'}, status=status.HTTP_403_FORBIDDEN)
        band = self.get_object(pk)
        name = band.name
        band.delete()
        return Response({
            'success': True,
            'message': f"Distance band '{name}' deleted successfully.",
        })



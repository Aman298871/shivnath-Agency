"""
Authoritative REST API Views for WATERNow Prepaid 'My Water Wallet'.
"""

from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.exceptions import ValidationError

from .models import Order
from .wallet_services import (
    get_or_create_wallet,
    initiate_wallet_recharge,
    verify_wallet_recharge,
    debit_wallet_for_order,
)


class WalletDetailAPIView(APIView):
    """
    Returns the authenticated customer's current Water Wallet balance and summary.
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        wallet = get_or_create_wallet(request.user)
        recent_txns = wallet.transactions.order_by('-created_at')[:5]

        data = {
            'success': True,
            'balance': float(wallet.balance),
            'currency': 'INR',
            'user': request.user.username,
            'customer_name': request.user.get_full_name() or request.user.username,
            'updated_at': wallet.updated_at.isoformat() if wallet.updated_at else None,
            'recent_transactions': [
                {
                    'transaction_id': t.transaction_id,
                    'type': t.transaction_type,
                    'type_display': t.get_transaction_type_display(),
                    'amount': float(t.amount),
                    'status': t.status,
                    'description': t.description,
                    'created_at': t.created_at.strftime('%d %b %Y, %I:%M %p') if t.created_at else '',
                }
                for t in recent_txns
            ]
        }
        return Response(data)


class WalletRechargeInitiateAPIView(APIView):
    """
    Creates a Razorpay order to recharge the customer's wallet.
    """
    permission_classes = [IsAuthenticated]

    def post(self, request):
        amount = request.data.get('amount')
        if not amount:
            return Response({'success': False, 'message': 'Amount is required.'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            result = initiate_wallet_recharge(request.user, amount)
            return Response(result, status=status.HTTP_201_CREATED)
        except ValidationError as e:
            msg = e.detail[0] if isinstance(e.detail, list) else str(e.detail)
            return Response({'success': False, 'message': msg}, status=status.HTTP_400_BAD_REQUEST)
        except Exception as e:
            return Response({'success': False, 'message': f"Failed to initiate recharge: {str(e)}"}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class WalletRechargeVerifyAPIView(APIView):
    """
    Verifies Razorpay payment signature and credits wallet balance.
    """
    permission_classes = [IsAuthenticated]

    def post(self, request):
        razorpay_order_id = request.data.get('razorpay_order_id')
        razorpay_payment_id = request.data.get('razorpay_payment_id')
        razorpay_signature = request.data.get('razorpay_signature')

        if not razorpay_order_id or not razorpay_payment_id:
            return Response(
                {'success': False, 'message': 'Missing razorpay_order_id or razorpay_payment_id.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            result = verify_wallet_recharge(
                user=request.user,
                razorpay_order_id=razorpay_order_id,
                razorpay_payment_id=razorpay_payment_id,
                razorpay_signature=razorpay_signature,
            )
            return Response(result, status=status.HTTP_200_OK)
        except ValidationError as e:
            msg = e.detail[0] if isinstance(e.detail, list) else str(e.detail)
            return Response({'success': False, 'message': msg}, status=status.HTTP_400_BAD_REQUEST)
        except Exception as e:
            return Response({'success': False, 'message': f"Verification error: {str(e)}"}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class WalletPayOrderAPIView(APIView):
    """
    Debits the customer's wallet to pay for an existing order.
    """
    permission_classes = [IsAuthenticated]

    def post(self, request):
        order_id = request.data.get('order_id')
        if not order_id:
            return Response({'success': False, 'message': 'order_id is required.'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            clean_id = str(order_id).replace('ORD-', '').replace('#', '').strip()
            order = Order.objects.get(id=int(clean_id))
        except (Order.DoesNotExist, ValueError):
            return Response({'success': False, 'message': 'Order not found.'}, status=status.HTTP_404_NOT_FOUND)

        # Ensure order belongs to user or user is admin
        if order.created_by != request.user and not (request.user.is_staff or request.user.is_superuser):
            return Response({'success': False, 'message': 'Permission denied.'}, status=status.HTTP_403_FORBIDDEN)

        if order.payment_status == 'paid':
            return Response({'success': False, 'message': 'Order is already marked as paid.'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            result = debit_wallet_for_order(order=order, user=request.user)
            return Response(result, status=status.HTTP_200_OK)
        except ValidationError as e:
            msg = e.detail[0] if isinstance(e.detail, list) else str(e.detail)
            return Response({'success': False, 'message': msg}, status=status.HTTP_400_BAD_REQUEST)
        except Exception as e:
            return Response({'success': False, 'message': f"Wallet payment error: {str(e)}"}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class WalletTransactionListAPIView(APIView):
    """
    Returns full ledger history for the authenticated user's wallet.
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        wallet = get_or_create_wallet(request.user)
        txns = wallet.transactions.order_by('-created_at')

        results = [
            {
                'transaction_id': t.transaction_id,
                'type': t.transaction_type,
                'type_display': t.get_transaction_type_display(),
                'amount': float(t.amount),
                'balance_after': float(t.balance_after) if t.balance_after is not None else None,
                'status': t.status,
                'order_code': t.order.order_code if t.order else None,
                'description': t.description,
                'gateway_ref': t.razorpay_payment_id or '',
                'created_at': t.created_at.strftime('%d %b %Y, %I:%M %p') if t.created_at else '',
                'completed_at': t.completed_at.strftime('%d %b %Y, %I:%M %p') if t.completed_at else None,
            }
            for t in txns
        ]

        return Response({
            'success': True,
            'balance': float(wallet.balance),
            'count': len(results),
            'transactions': results,
        })

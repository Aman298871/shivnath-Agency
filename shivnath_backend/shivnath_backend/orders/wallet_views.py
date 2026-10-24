"""
Authoritative REST API Views for WATERNow Prepaid 'My Water Wallet' and Points Redemption.
"""

from decimal import Decimal
from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.exceptions import ValidationError
from django.core.exceptions import ValidationError as DjangoValidationError

from .models import Order, WalletRedemptionRule
from .serializers import OrderSerializer
from .wallet_services import (
    get_or_create_wallet,
    initiate_wallet_recharge,
    verify_wallet_recharge,
    debit_wallet_for_order,
    sync_customer_earned_points,
    get_redemption_eligible_products,
    redeem_points_for_order,
)


class WalletDetailAPIView(APIView):
    """
    Returns the authenticated customer's current Water Wallet balance, reward points,
    conversion rules, and summary.
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        wallet = get_or_create_wallet(request.user)

        rule = WalletRedemptionRule.get_active_rule()
        conversion_ratio = float(rule.points_per_rupee_discount)
        point_val = float(Decimal('1.00') / rule.points_per_rupee_discount) if conversion_ratio > 0 else 0.5
        redeemable_val = round(wallet.reward_points * point_val, 2)

        recent_txns = wallet.transactions.order_by('-created_at')[:8]

        data = {
            'success': True,
            'balance': float(wallet.balance),
            'reward_points': wallet.reward_points,
            'points_value_in_inr': redeemable_val,
            'currency': 'INR',
            'user': request.user.username,
            'customer_name': request.user.get_full_name() or request.user.username,
            'updated_at': wallet.updated_at.isoformat() if wallet.updated_at else None,
            'conversion_rule': {
                'points_per_rupee_spent': float(rule.rupees_spent_per_point),
                'rupees_spent_per_point': float(rule.rupees_spent_per_point),
                'points_per_rupee_discount': conversion_ratio,
                'redemption_conversion_ratio': conversion_ratio,
                'min_points_to_redeem': rule.min_points_to_redeem,
                'point_value_in_inr': point_val,
                'rule_description': (
                    f"Earn 1 point per Rs. {rule.rupees_spent_per_point:.0f} spent. "
                    f"Redeem at {conversion_ratio:.1f} pts = Rs. 1.00 (min {rule.min_points_to_redeem} pts)."
                ),
            },
            'recent_transactions': [
                {
                    'transaction_id': t.transaction_id,
                    'type': t.transaction_type,
                    'type_display': t.get_transaction_type_display(),
                    'amount': float(t.amount),
                    'points': t.points,
                    'points_balance_after': t.points_balance_after,
                    'balance_after': float(t.balance_after) if t.balance_after is not None else None,
                    'status': t.status,
                    'description': t.description,
                    'created_at': t.created_at.strftime('%d %b %Y, %I:%M %p') if t.created_at else '',
                }
                for t in recent_txns
            ]
        }
        return Response(data)


class WalletRedemptionProductsAPIView(APIView):
    """
    Returns the catalog of eligible products for Water Wallet points redemption,
    including unit prices, points required, current stock availability, and conversion rules.
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        wallet = get_or_create_wallet(request.user)
        result = get_redemption_eligible_products(request.user)
        return Response(result, status=status.HTTP_200_OK)


class WalletRedeemPointsAPIView(APIView):
    """
    Executes a product purchase using Water Wallet reward points (and optional wallet cash balance).
    The resulting order is assigned order_source='WATER_WALLET_REDEMPTION' and routed DIRECTLY
    to Central Admin. It is strictly never assigned to or visible to any Franchise.
    """
    permission_classes = [IsAuthenticated]

    def post(self, request):
        product_id = request.data.get('product_id')
        quantity = request.data.get('quantity', None)
        points_to_redeem = request.data.get('points_to_redeem', None)
        delivery_address = request.data.get('delivery_address', None)
        delivery_latitude = request.data.get('delivery_latitude') or request.data.get('latitude')
        delivery_longitude = request.data.get('delivery_longitude') or request.data.get('longitude')
        notes = request.data.get('notes', '')
        idempotency_key = request.data.get('idempotency_key') or request.headers.get('X-Idempotency-Key')

        if not product_id:
            return Response(
                {'success': False, 'message': 'product_id is required.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        if quantity is not None:
            try:
                quantity = int(quantity)
                if quantity < 1:
                    return Response(
                        {'success': False, 'message': 'Quantity must be at least 1.'},
                        status=status.HTTP_400_BAD_REQUEST
                    )
            except (ValueError, TypeError):
                return Response(
                    {'success': False, 'message': 'Invalid quantity value.'},
                    status=status.HTTP_400_BAD_REQUEST
                )

        if points_to_redeem is not None:
            try:
                points_to_redeem = int(points_to_redeem)
                if points_to_redeem < 0:
                    return Response(
                        {'success': False, 'message': 'points_to_redeem cannot be negative.'},
                        status=status.HTTP_400_BAD_REQUEST
                    )
            except (ValueError, TypeError):
                return Response(
                    {'success': False, 'message': 'Invalid points_to_redeem value.'},
                    status=status.HTTP_400_BAD_REQUEST
                )

        try:
            result = redeem_points_for_order(
                user=request.user,
                product_id=product_id,
                quantity=quantity,
                points_to_redeem=points_to_redeem,
                delivery_latitude=delivery_latitude,
                delivery_longitude=delivery_longitude,
                delivery_address=delivery_address,
                notes=notes,
                idempotency_key=idempotency_key,
            )
            # Re-serialize order with full serializer
            order_obj = result.get('order')
            if order_obj:
                serialized_order = OrderSerializer(order_obj).data
                result['order'] = serialized_order
                result['data'] = {'order': serialized_order}
            else:
                result['data'] = dict(result)

            return Response(result, status=status.HTTP_201_CREATED)

        except (ValidationError, DjangoValidationError) as e:
            msg = e.detail if hasattr(e, 'detail') else (e.messages if hasattr(e, 'messages') else str(e))
            if isinstance(msg, list):
                msg = msg[0]
            elif isinstance(msg, dict):
                msg = next(iter(msg.values()))
                if isinstance(msg, list):
                    msg = msg[0]
            return Response(
                {
                    'success': False,
                    'message': str(msg),
                    'error_code': 'PACKAGING_RULE_VIOLATION' if 'Minimum order' in str(msg) or 'carton' in str(msg) else 'VALIDATION_ERROR'
                },
                status=status.HTTP_400_BAD_REQUEST
            )
        except Exception as e:
            err_msg = str(e)
            if any(term in err_msg for term in ['Minimum', 'Insufficient', 'unavailable', 'not exist', 'required', 'Quantity', 'points']):
                return Response({'success': False, 'message': err_msg}, status=status.HTTP_400_BAD_REQUEST)
            return Response(
                {'success': False, 'message': f"Redemption failed: {err_msg}"},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


class WalletSettingsAPIView(APIView):
    """
    Exposes configurable Water Wallet redemption rules.
    Admins can view and update the rule; authenticated customers can view.
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        rule = WalletRedemptionRule.get_active_rule()
        conversion_ratio = float(rule.points_per_rupee_discount)
        data = {
            'success': True,
            'id': rule.id,
            'is_active': rule.is_active,
            'rupees_spent_per_point': float(rule.rupees_spent_per_point),
            'points_per_rupee_discount': conversion_ratio,
            'point_value_in_inr': float(Decimal('1.00') / rule.points_per_rupee_discount) if conversion_ratio > 0 else 0.5,
            'min_points_to_redeem': rule.min_points_to_redeem,
            'updated_at': rule.updated_at.isoformat() if rule.updated_at else None,
        }
        return Response(data)

    def post(self, request):
        user = request.user
        role = getattr(getattr(user, 'profile', None), 'role', '')
        if not (user.is_superuser or user.is_staff or role in ['admin', 'super_admin']):
            return Response(
                {'success': False, 'message': 'Only Central Admins can update redemption settings.'},
                status=status.HTTP_403_FORBIDDEN
            )

        rule = WalletRedemptionRule.get_active_rule()

        if 'rupees_spent_per_point' in request.data:
            try:
                rule.rupees_spent_per_point = Decimal(str(request.data['rupees_spent_per_point']))
            except (ValueError, TypeError):
                pass
        elif 'points_per_rupee_spent' in request.data:
            try:
                rule.rupees_spent_per_point = Decimal(str(request.data['points_per_rupee_spent']))
            except (ValueError, TypeError):
                pass

        if 'points_per_rupee_discount' in request.data:
            try:
                val = Decimal(str(request.data['points_per_rupee_discount']))
                if val > Decimal('0'):
                    rule.points_per_rupee_discount = val
            except Exception:
                pass
        elif 'redemption_conversion_ratio' in request.data:
            try:
                val = Decimal(str(request.data['redemption_conversion_ratio']))
                if val > Decimal('0'):
                    rule.points_per_rupee_discount = val
            except Exception:
                pass

        if 'min_points_to_redeem' in request.data:
            try:
                rule.min_points_to_redeem = max(0, int(request.data['min_points_to_redeem']))
            except (ValueError, TypeError):
                pass

        if 'is_active' in request.data:
            rule.is_active = bool(request.data['is_active'])

        rule.save()
        return Response({'success': True, 'message': 'Redemption rules updated successfully.'})


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
                'points': t.points,
                'points_balance_after': t.points_balance_after,
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
            'reward_points': wallet.reward_points,
            'count': len(results),
            'transactions': results,
        })


class AdminWalletReconciliationAPIView(APIView):
    """
    Controlled Admin reconciliation procedure for customer Water Wallets.
    GET: Previews ledger calculations, discrepancies, and un-backfilled orders without altering records.
    POST: Explicitly applies authorized corrections with immutable AdminAuditLog entry.
    """
    permission_classes = [IsAuthenticated]

    def _check_admin(self, request):
        user = request.user
        role = getattr(getattr(user, 'profile', None), 'role', '')
        return user.is_superuser or user.is_staff or role == 'admin'

    def get(self, request):
        if not self._check_admin(request):
            return Response({'success': False, 'message': 'Admin authorization required.'}, status=status.HTTP_403_FORBIDDEN)

        user_id = request.query_params.get('user_id')
        wallets = Wallet.objects.select_related('user').all()
        if user_id:
            wallets = wallets.filter(user_id=user_id)

        discrepancies = []
        for w in wallets:
            matches_pts, computed_pts = w.reconcile_points(auto_fix=False)
            matches_bal, computed_bal = w.reconcile_balance(auto_fix=False)
            if not matches_pts or not matches_bal:
                discrepancies.append({
                    'wallet_id': w.id,
                    'user_id': w.user_id,
                    'username': w.user.username,
                    'current_points': w.reward_points,
                    'ledger_points': computed_pts,
                    'points_discrepancy': computed_pts - w.reward_points,
                    'current_balance': float(w.balance),
                    'ledger_balance': float(computed_bal),
                    'balance_discrepancy': float(computed_bal - w.balance),
                })

        return Response({
            'success': True,
            'total_wallets_audited': wallets.count(),
            'discrepancy_count': len(discrepancies),
            'discrepancies': discrepancies,
            'mode': 'PREVIEW_ONLY',
        }, status=status.HTTP_200_OK)

    def post(self, request):
        if not self._check_admin(request):
            return Response({'success': False, 'message': 'Admin authorization required.'}, status=status.HTTP_403_FORBIDDEN)

        user_id = request.data.get('user_id')
        apply_backfill = request.data.get('backfill_points', False)
        reason = request.data.get('reason', '').strip()

        if not reason:
            return Response({'success': False, 'message': 'Explicit audit reason is required for wallet corrections.'}, status=status.HTTP_400_BAD_REQUEST)

        wallets = Wallet.objects.select_related('user').all()
        if user_id:
            wallets = wallets.filter(user_id=user_id)

        from accounts.models import AdminAuditLog
        fixed = []
        with transaction.atomic():
            for w in wallets:
                if apply_backfill:
                    sync_customer_earned_points(w.user, w)

                matches_pts, comp_pts = w.reconcile_points(auto_fix=True)
                matches_bal, comp_bal = w.reconcile_balance(auto_fix=True)

                if not matches_pts or not matches_bal or apply_backfill:
                    fixed.append({
                        'wallet_id': w.id,
                        'user_id': w.user_id,
                        'username': w.user.username,
                        'new_points': w.reward_points,
                        'new_balance': float(w.balance),
                    })

            AdminAuditLog.objects.create(
                actor=request.user,
                action='WALLET_LEDGER_RECONCILIATION',
                resource_type='WaterWallet',
                resource_id=str(user_id or 'ALL'),
                changes={
                    'reason': reason,
                    'wallets_corrected': len(fixed),
                    'corrections': fixed,
                }
            )

        return Response({
            'success': True,
            'message': f"Reconciliation executed successfully. Corrected {len(fixed)} wallet(s).",
            'audit_logged': True,
            'corrected_count': len(fixed),
            'corrected_wallets': fixed,
        }, status=status.HTTP_200_OK)


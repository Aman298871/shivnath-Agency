from django.shortcuts import get_object_or_404
from django.db.models import Q, F, Sum, DecimalField, ExpressionWrapper
from django.utils import timezone

from rest_framework import status
from rest_framework.response import Response
from rest_framework.views import APIView

from accounts.permissions import IsAdminRole

from .models import InventoryItem, StockRequest
from .serializers import InventoryItemSerializer, StockRequestSerializer


# =========================================================
# INVENTORY ITEM LIST + CREATE
# =========================================================

class InventoryItemListCreateView(APIView):

    permission_classes = [IsAdminRole]

    def get(self, request):

        items = InventoryItem.objects.all()

        search = request.query_params.get(
            'search', ''
        ).strip()

        if search:
            items = items.filter(
                Q(name__icontains=search)
                | Q(sku__icontains=search)
                | Q(supplier__icontains=search)
            )

        item_type = request.query_params.get(
            'type', ''
        ).strip()

        if item_type:
            items = items.filter(
                item_type=item_type
            )

        serializer = InventoryItemSerializer(
            items, many=True
        )

        return Response(
            {
                'success': True,
                'count': items.count(),
                'items': serializer.data,
            },
            status=status.HTTP_200_OK,
        )

    def post(self, request):

        serializer = InventoryItemSerializer(
            data=request.data
        )

        if not serializer.is_valid():
            return Response(
                {
                    'success': False,
                    'errors': serializer.errors,
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        item = serializer.save(
            created_by=request.user
        )

        return Response(
            {
                'success': True,
                'message': 'Inventory item added successfully.',
                'item': InventoryItemSerializer(item).data,
            },
            status=status.HTTP_201_CREATED,
        )


# =========================================================
# INVENTORY ITEM DETAIL + UPDATE + DELETE
# =========================================================

class InventoryItemDetailView(APIView):

    permission_classes = [IsAdminRole]

    def get(self, request, pk):
        item = get_object_or_404(InventoryItem, pk=pk)

        return Response(
            {
                'success': True,
                'item': InventoryItemSerializer(item).data,
            }
        )

    def put(self, request, pk):
        return self._update(request, pk, partial=False)

    def patch(self, request, pk):
        return self._update(request, pk, partial=True)

    def _update(self, request, pk, partial):

        item = get_object_or_404(InventoryItem, pk=pk)

        serializer = InventoryItemSerializer(
            item,
            data=request.data,
            partial=partial,
        )

        if not serializer.is_valid():
            return Response(
                {
                    'success': False,
                    'errors': serializer.errors,
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        updated_item = serializer.save()

        return Response(
            {
                'success': True,
                'message': 'Inventory item updated successfully.',
                'item': InventoryItemSerializer(updated_item).data,
            }
        )

    def delete(self, request, pk):
        item = get_object_or_404(InventoryItem, pk=pk)
        name = item.name
        item.delete()

        return Response(
            {
                'success': True,
                'message': f'{name} deleted successfully.',
            }
        )


# =========================================================
# STOCK REQUEST LIST + CREATE
# =========================================================

class StockRequestListCreateView(APIView):

    permission_classes = [IsAdminRole]

    def get(self, request):

        requests_qs = (
            StockRequest.objects
            .select_related('item', 'requested_by')
            .all()
        )

        req_status = request.query_params.get(
            'status', ''
        ).strip()

        if req_status:
            requests_qs = requests_qs.filter(
                status=req_status
            )

        serializer = StockRequestSerializer(
            requests_qs, many=True
        )

        return Response(
            {
                'success': True,
                'count': requests_qs.count(),
                'requests': serializer.data,
            }
        )

    def post(self, request):

        serializer = StockRequestSerializer(
            data=request.data
        )

        if not serializer.is_valid():
            return Response(
                {
                    'success': False,
                    'errors': serializer.errors,
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        item = serializer.validated_data['item']
        request_type = serializer.validated_data['request_type']
        quantity = serializer.validated_data['quantity']

        if request_type == 'stock_out' and quantity > item.stock:
            return Response(
                {
                    'success': False,
                    'message': 'Stock out quantity is greater than available stock.',
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        stock_request = serializer.save(
            requested_by=request.user
        )

        # If created by admin/staff or auto_approve requested, apply stock immediately
        auto_apply = request.data.get('auto_approve', True)
        if auto_apply or request.user.is_superuser or getattr(getattr(request.user, 'profile', None), 'role', '') == 'admin':
            if request_type == 'stock_in':
                item.stock = F('stock') + quantity
            else:
                item.stock = F('stock') - quantity

            item.save()
            item.refresh_from_db()

            stock_request.status = 'approved'
            stock_request.approved_by = request.user
            stock_request.approved_at = timezone.now()
            stock_request.save()

            # Sync matching Product if exists
            try:
                from products.models import Product
                if item.sku:
                    Product.objects.filter(sku__iexact=item.sku).update(stock=item.stock)
                else:
                    Product.objects.filter(name__iexact=item.name).update(stock=item.stock)
            except Exception:
                pass

        return Response(
            {
                'success': True,
                'message': 'Stock entry recorded and inventory updated successfully.',
                'request': StockRequestSerializer(stock_request).data,
                'item': InventoryItemSerializer(item).data,
            },
            status=status.HTTP_201_CREATED,
        )


# =========================================================
# STOCK REQUEST APPROVE
# =========================================================

class StockRequestApproveView(APIView):

    permission_classes = [IsAdminRole]

    def patch(self, request, pk):

        stock_request = get_object_or_404(StockRequest, pk=pk)

        if stock_request.status != 'pending':
            return Response(
                {
                    'success': False,
                    'message': 'This request has already been processed.',
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        item = stock_request.item

        if (
            stock_request.request_type == 'stock_out'
            and stock_request.quantity > item.stock
        ):
            return Response(
                {
                    'success': False,
                    'message': 'Available stock is insufficient for this request.',
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        if stock_request.request_type == 'stock_in':
            item.stock = F('stock') + stock_request.quantity
        else:
            item.stock = F('stock') - stock_request.quantity

        item.save()
        item.refresh_from_db()

        stock_request.status = 'approved'
        stock_request.approved_by = request.user
        stock_request.approved_at = timezone.now()
        stock_request.save()

        # Sync matching Product if exists
        try:
            from products.models import Product
            if item.sku:
                Product.objects.filter(sku__iexact=item.sku).update(stock=item.stock)
            else:
                Product.objects.filter(name__iexact=item.name).update(stock=item.stock)
        except Exception:
            pass

        return Response(
            {
                'success': True,
                'message': 'Stock request approved successfully.',
                'request': StockRequestSerializer(stock_request).data,
                'item': InventoryItemSerializer(item).data,
            }
        )


# =========================================================
# STOCK REQUEST REJECT
# =========================================================

class StockRequestRejectView(APIView):

    permission_classes = [IsAdminRole]

    def patch(self, request, pk):

        stock_request = get_object_or_404(StockRequest, pk=pk)

        if stock_request.status != 'pending':
            return Response(
                {
                    'success': False,
                    'message': 'This request has already been processed.',
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        reason = request.data.get(
            'rejection_reason', ''
        ).strip()

        if not reason:
            return Response(
                {
                    'success': False,
                    'message': 'Rejection reason is required.',
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        stock_request.status = 'rejected'
        stock_request.rejection_reason = reason
        stock_request.approved_by = request.user
        stock_request.approved_at = timezone.now()
        stock_request.save()

        return Response(
            {
                'success': True,
                'message': 'Stock request rejected.',
                'request': StockRequestSerializer(stock_request).data,
            }
        )


# =========================================================
# INVENTORY STATS
# =========================================================

class InventoryStatsView(APIView):

    permission_classes = [IsAdminRole]

    def get(self, request):

        items = InventoryItem.objects.all()

        total_items = items.count()

        low_stock = items.filter(
            stock__lte=F('min_stock')
        ).count()

        pending_approvals = StockRequest.objects.filter(
            status='pending'
        ).count()

        value_expr = ExpressionWrapper(
            F('stock') * F('purchase_rate'),
            output_field=DecimalField(
                max_digits=14, decimal_places=2
            ),
        )

        stock_value = items.aggregate(
            total=Sum(value_expr)
        )['total'] or 0

        return Response(
            {
                'success': True,
                'stats': {
                    'total_items': total_items,
                    'low_stock': low_stock,
                    'pending_approvals': pending_approvals,
                    'stock_value': float(stock_value),
                },
            }
        )


# =========================================================
# FRANCHISE INVENTORY VIEWS
# =========================================================

class FranchiseRawMaterialListView(APIView):
    """
    GET  /api/inventory/franchise/raw-materials/
    List raw material stocks for the authenticated franchise.
    """
    from accounts.permissions import IsApprovedFranchise

    def get_permissions(self):
        from accounts.permissions import IsApprovedFranchise
        return [IsApprovedFranchise()]

    def get(self, request):
        fp = getattr(request.user, 'franchise_profile', None)
        if not fp:
            return Response({'success': False, 'message': 'No franchise profile found.'}, status=403)

        from .models import FranchiseRawMaterial
        stocks = FranchiseRawMaterial.objects.filter(franchise=fp).select_related('item')
        data = [
            {
                'id': s.id,
                'item': s.item.id,
                'item_name': s.item.name,
                'current_stock': s.current_stock,
                'unit': s.unit,
                'min_alert_level': s.min_alert_level,
                'last_updated': s.last_updated.isoformat(),
            }
            for s in stocks
        ]
        return Response({'success': True, 'data': data})


class FranchiseProductionLogView(APIView):
    """
    GET  /api/inventory/franchise/production-logs/
    POST /api/inventory/franchise/production-logs/
    """

    def get_permissions(self):
        from accounts.permissions import IsApprovedFranchise
        return [IsApprovedFranchise()]

    def get(self, request):
        fp = getattr(request.user, 'franchise_profile', None)
        if not fp:
            return Response({'success': False, 'message': 'No franchise profile found.'}, status=403)

        from .models import LocalProductionLog
        logs = LocalProductionLog.objects.filter(franchise=fp).order_by('-created_at')[:50]
        data = [
            {
                'id': l.id,
                'product_name': l.product_name,
                'quantity_produced': l.quantity_produced,
                'production_date': l.production_date.isoformat(),
                'notes': l.notes,
            }
            for l in logs
        ]
        return Response({'success': True, 'data': data})

    def post(self, request):
        fp = getattr(request.user, 'franchise_profile', None)
        if not fp:
            return Response({'success': False, 'message': 'No franchise profile found.'}, status=403)

        from .models import LocalProductionLog
        product_name = request.data.get('product_name', '').strip()
        quantity_produced = request.data.get('quantity_produced', 0)
        notes = request.data.get('notes', '').strip()

        if not product_name:
            return Response({'success': False, 'message': 'Product name is required.'}, status=400)
        try:
            quantity_produced = int(quantity_produced)
            if quantity_produced <= 0:
                raise ValueError()
        except (ValueError, TypeError):
            return Response({'success': False, 'message': 'Quantity must be a positive integer.'}, status=400)

        log = LocalProductionLog.objects.create(
            franchise=fp,
            product_name=product_name,
            quantity_produced=quantity_produced,
            notes=notes,
            logged_by=request.user,
        )

        # Create a transaction record
        from .models import FranchiseInventoryTransaction
        FranchiseInventoryTransaction.objects.create(
            franchise=fp,
            transaction_type='stock_in_production',
            quantity=quantity_produced,
            reference_id=log.id,
            notes=f'Production batch: {product_name}',
            created_by=request.user,
        )

        return Response({
            'success': True,
            'message': 'Production batch logged.',
            'id': log.id,
        }, status=201)


class FranchiseInventoryTransactionListView(APIView):
    """
    GET /api/inventory/franchise/transactions/
    """

    def get_permissions(self):
        from accounts.permissions import IsApprovedFranchise
        return [IsApprovedFranchise()]

    def get(self, request):
        fp = getattr(request.user, 'franchise_profile', None)
        if not fp:
            return Response({'success': False, 'message': 'No franchise profile found.'}, status=403)

        from .models import FranchiseInventoryTransaction
        txns = FranchiseInventoryTransaction.objects.filter(franchise=fp).select_related('item').order_by('-created_at')[:100]
        data = [
            {
                'id': t.id,
                'item_name': t.item.name if t.item else '',
                'transaction_type': t.transaction_type,
                'quantity': t.quantity,
                'notes': t.notes,
                'created_at': t.created_at.isoformat(),
            }
            for t in txns
        ]
        return Response({'success': True, 'data': data})
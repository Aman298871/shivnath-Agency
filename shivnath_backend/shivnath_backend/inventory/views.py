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

        return Response(
            {
                'success': True,
                'message': 'Stock request submitted for approval.',
                'request': StockRequestSerializer(stock_request).data,
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
from django.shortcuts import get_object_or_404
from django.db.models import Q, F, Sum, DecimalField, ExpressionWrapper
from django.utils import timezone

from rest_framework import status
from rest_framework.response import Response
from rest_framework.views import APIView

from accounts.permissions import IsAdminRole, IsProductMasterAdmin

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

        # If requested by a franchise user, deliver directly to FranchiseRawMaterial
        if stock_request.request_type == 'stock_out':
            req_user = stock_request.requested_by
            if req_user and hasattr(req_user, 'franchise_profile'):
                fp = req_user.franchise_profile
                from .models import FranchiseRawMaterial, FranchiseInventoryTransaction
                frm, _ = FranchiseRawMaterial.objects.get_or_create(
                    franchise=fp,
                    item=item,
                    defaults={'unit': item.unit, 'current_stock': 0}
                )
                frm.current_stock += stock_request.quantity
                frm.save()
                FranchiseInventoryTransaction.objects.create(
                    franchise=fp,
                    item=item,
                    transaction_type='stock_in_transfer',
                    quantity=stock_request.quantity,
                    reference_id=stock_request.id,
                    notes=f"Approved raw material transfer from central inventory: {item.name}",
                    created_by=request.user,
                )

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

        raw_material_id = request.data.get('raw_material_id')
        try:
            raw_material_qty = int(request.data.get('raw_material_qty') or 0)
        except (ValueError, TypeError):
            raw_material_qty = 0

        raw_materials_used = {}
        from .models import FranchiseRawMaterial, FranchiseInventoryTransaction

        log = LocalProductionLog.objects.create(
            franchise=fp,
            product_name=product_name,
            quantity_produced=quantity_produced,
            raw_materials_used=raw_materials_used,
            notes=notes,
            logged_by=request.user,
        )

        if raw_material_id and raw_material_qty > 0:
            frm = FranchiseRawMaterial.objects.filter(franchise=fp, id=raw_material_id).first()
            if frm:
                raw_materials_used[str(frm.item_id)] = raw_material_qty
                log.raw_materials_used = raw_materials_used
                log.save(update_fields=['raw_materials_used'])
                if frm.current_stock >= raw_material_qty:
                    frm.current_stock -= raw_material_qty
                else:
                    frm.current_stock = 0
                frm.save()
                FranchiseInventoryTransaction.objects.create(
                    franchise=fp,
                    item=frm.item,
                    transaction_type='stock_out_damage',
                    quantity=-raw_material_qty,
                    reference_id=log.id,
                    notes=f"Consumed in production of {product_name} x{quantity_produced}",
                    created_by=request.user,
                )

        # Sync matching Product stock if exists
        try:
            from products.models import Product
            Product.objects.filter(name__iexact=product_name).update(stock=F('stock') + quantity_produced)
        except Exception:
            pass

        # Create production transaction record
        FranchiseInventoryTransaction.objects.create(
            franchise=fp,
            transaction_type='stock_in_production',
            quantity=quantity_produced,
            reference_id=log.id,
            notes=f'Production batch: {product_name} x{quantity_produced}',
            created_by=request.user,
        )

        return Response({
            'success': True,
            'message': 'Production batch logged and inventory updated.',
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


# =====================================================================
# AUTHORITATIVE ENTERPRISE ERP VIEWS
# =====================================================================

from rest_framework import generics, permissions, views
from .models import (
    RawMaterial,
    ProductionBatch,
    DealerStockBatch,
    DealerStockRequest,
    DealerStockRequestAllocation,
    InventoryTransactionLedger,
    Expense,
    DailyBusinessReport,
    ExpiryAlertLog,
)
from .serializers import (
    RawMaterialSerializer,
    ProductionBatchSerializer,
    DealerStockBatchSerializer,
    DealerStockRequestSerializer,
    DealerStockRequestAllocationSerializer,
    InventoryTransactionLedgerSerializer,
    ExpenseSerializer,
    DailyBusinessReportSerializer,
)
from .services import (
    create_production_batch_atomic,
    record_batch_collection_atomic,
    allocate_and_dispatch_stock_request_atomic,
    receive_stock_request_atomic,
)


class RawMaterialListCreateAPIView(generics.ListCreateAPIView):
    queryset = RawMaterial.objects.all()
    serializer_class = RawMaterialSerializer

    def get_permissions(self):
        if self.request.method in ['GET', 'HEAD', 'OPTIONS']:
            return [permissions.IsAuthenticated()]
        return [IsProductMasterAdmin()]

    def get_queryset(self):
        qs = super().get_queryset()
        category = self.request.query_params.get('category')
        if category:
            qs = qs.filter(category=category)
        return qs


class ProductionBatchListCreateAPIView(views.APIView):
    def get_permissions(self):
        if self.request.method in ['GET', 'HEAD', 'OPTIONS']:
            return [permissions.IsAuthenticated()]
        return [IsProductMasterAdmin()]

    def get(self, request):
        batches = ProductionBatch.objects.select_related('product', 'linked_order').all()
        product_id = request.query_params.get('product_id')
        if product_id:
            batches = batches.filter(product_id=product_id)
        order_id = request.query_params.get('order_id')
        if order_id:
            batches = batches.filter(linked_order_id=order_id)
        serializer = ProductionBatchSerializer(batches, many=True)
        return Response(serializer.data)

    def post(self, request):
        product_id = request.data.get('product') or request.data.get('product_id')
        qty = request.data.get('quantity_produced_units') or request.data.get('quantity')
        mfg_date = request.data.get('manufacture_date')
        exp_date = request.data.get('expiry_date')
        batch_number = request.data.get('batch_number')
        shelf_life_days = request.data.get('shelf_life_days')
        client_name = request.data.get('client_name')
        linked_order = request.data.get('linked_order') or request.data.get('order_id')
        label_requirement = request.data.get('label_requirement')
        printing_requirement = request.data.get('printing_requirement')
        branding_requirement = request.data.get('branding_requirement')

        if not product_id or not qty:
            return Response({'error': 'Product and quantity_produced_units are required.'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            batch = create_production_batch_atomic(
                product_id=product_id,
                quantity_produced_units=int(qty),
                manufacture_date=mfg_date,
                expiry_date=exp_date,
                batch_number=batch_number,
                shelf_life_days=int(shelf_life_days) if shelf_life_days is not None else None,
                client_name=client_name,
                linked_order=linked_order,
                label_requirement=label_requirement,
                printing_requirement=printing_requirement,
                branding_requirement=branding_requirement,
                actor=request.user
            )
            return Response(ProductionBatchSerializer(batch).data, status=status.HTTP_201_CREATED)
        except Exception as e:
            return Response({'error': str(e)}, status=status.HTTP_400_BAD_REQUEST)


class ProductionBatchCollectionAPIView(views.APIView):
    """
    Handles customer / dealer collection or dispatch from a central company ProductionBatch.
    Example: Customer Digital Marketing Wala ordered 5,000, batch manufactured 5,000,
    customer collects 2,000 units. The remaining 3,000 units STAY as pending company stock.
    """
    def get_permissions(self):
        return [IsProductMasterAdmin()]

    def post(self, request, pk):
        qty = request.data.get('quantity_collected') or request.data.get('quantity')
        if not qty:
            return Response({'error': 'quantity_collected is required.'}, status=status.HTTP_400_BAD_REQUEST)

        client_name = request.data.get('client_name')
        notes = request.data.get('notes')

        try:
            res = record_batch_collection_atomic(
                batch_id=pk,
                quantity_collected=int(qty),
                client_name=client_name,
                notes=notes,
                actor=request.user
            )
            return Response({
                'success': True,
                'message': (
                    f"Successfully collected {res['quantity_collected']} units. "
                    f"Remaining company pending stock: {res['quantity_remaining_company']} units."
                ),
                'batch': ProductionBatchSerializer(res['batch']).data,
                'summary': {
                    'produced': res['quantity_produced'],
                    'collected': res['quantity_dispatched'],
                    'pending_company_stock': res['quantity_remaining_company'],
                    'order_status': res['order_status'],
                }
            }, status=status.HTTP_200_OK)
        except Exception as e:
            return Response({'error': str(e)}, status=status.HTTP_400_BAD_REQUEST)


class DealerStockBatchListAPIView(generics.ListAPIView):
    serializer_class = DealerStockBatchSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        qs = DealerStockBatch.objects.select_related('product', 'dealer').all()

        if hasattr(user, 'profile') and user.profile.role == 'franchise':
            dealer = getattr(user, 'franchise_profile', None)
            if dealer:
                qs = qs.filter(dealer=dealer)
            else:
                qs = qs.none()
        else:
            dealer_id = self.request.query_params.get('dealer_id')
            if dealer_id:
                qs = qs.filter(dealer_id=dealer_id)

        product_id = self.request.query_params.get('product_id')
        if product_id:
            qs = qs.filter(product_id=product_id)

        return qs


class DealerStockRequestListCreateAPIView(views.APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        user = request.user
        qs = DealerStockRequest.objects.select_related('product', 'dealer').prefetch_related('allocations__production_batch').all()

        if hasattr(user, 'profile') and user.profile.role == 'franchise':
            dealer = getattr(user, 'franchise_profile', None)
            if dealer:
                qs = qs.filter(dealer=dealer)
            else:
                qs = qs.none()
        else:
            dealer_id = request.query_params.get('dealer_id')
            if dealer_id:
                qs = qs.filter(dealer_id=dealer_id)

        status_param = request.query_params.get('status')
        if status_param:
            qs = qs.filter(status=status_param)

        serializer = DealerStockRequestSerializer(qs, many=True)
        return Response(serializer.data)

    def post(self, request):
        user = request.user
        dealer = getattr(user, 'franchise_profile', None)
        if not dealer and 'dealer_id' in request.data:
            from accounts.models import FranchiseProfile
            dealer = get_object_or_404(FranchiseProfile, id=request.data['dealer_id'])

        if not dealer:
            return Response({'error': 'No dealer profile associated.'}, status=status.HTTP_400_BAD_REQUEST)

        product_id = request.data.get('product') or request.data.get('product_id')
        qty = request.data.get('requested_quantity')
        notes = request.data.get('dealer_notes', '')

        if not product_id or not qty:
            return Response({'error': 'Product and requested_quantity are required.'}, status=status.HTTP_400_BAD_REQUEST)

        from products.models import Product
        product = get_object_or_404(Product, id=product_id)

        count = DealerStockRequest.objects.count() + 1
        req_number = f"SR-{timezone.now().strftime('%Y%m')}-{count:04d}"

        stock_req = DealerStockRequest.objects.create(
            request_number=req_number,
            dealer=dealer,
            product=product,
            requested_quantity=int(qty),
            dealer_notes=notes,
            status='REQUESTED'
        )
        return Response(DealerStockRequestSerializer(stock_req).data, status=status.HTTP_201_CREATED)


class DealerStockRequestDispatchAPIView(views.APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, pk):
        stock_req = get_object_or_404(DealerStockRequest, pk=pk)
        allocations_data = request.data.get('allocations', [])

        if not allocations_data:
            return Response({'error': 'allocations list is required [{"batch_id": int, "quantity": int}].'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            req_obj, invoice = allocate_and_dispatch_stock_request_atomic(
                stock_request=stock_req,
                allocations_list=allocations_data,
                actor=request.user
            )
            return Response({
                'stock_request': DealerStockRequestSerializer(req_obj).data,
                'invoice_id': invoice.id,
                'invoice_number': invoice.invoice_number,
                'grand_total': invoice.grand_total
            }, status=status.HTTP_200_OK)
        except Exception as e:
            return Response({'error': str(e)}, status=status.HTTP_400_BAD_REQUEST)


class DealerStockRequestReceiveAPIView(views.APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, pk):
        stock_req = get_object_or_404(DealerStockRequest, pk=pk)
        receipt_items = request.data.get('receipt_items', [])

        if not receipt_items:
            # Fallback: if no detailed items passed, mark all allocations as received
            receipt_items = [
                {
                    'allocation_id': alloc.id,
                    'received_quantity': alloc.dispatched_quantity,
                    'damaged_quantity': 0
                }
                for alloc in stock_req.allocations.all()
            ]

        try:
            req_obj = receive_stock_request_atomic(
                stock_request=stock_req,
                receipt_items=receipt_items,
                actor=request.user
            )
            return Response(DealerStockRequestSerializer(req_obj).data, status=status.HTTP_200_OK)
        except Exception as e:
            return Response({'error': str(e)}, status=status.HTTP_400_BAD_REQUEST)


class InventoryLedgerListAPIView(generics.ListAPIView):
    serializer_class = InventoryTransactionLedgerSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        qs = InventoryTransactionLedger.objects.select_related('product', 'raw_material', 'dealer', 'actor').all()

        if hasattr(user, 'profile') and user.profile.role == 'franchise':
            dealer = getattr(user, 'franchise_profile', None)
            if dealer:
                qs = qs.filter(dealer=dealer)
            else:
                qs = qs.none()
        else:
            dealer_id = self.request.query_params.get('dealer_id')
            if dealer_id:
                qs = qs.filter(dealer_id=dealer_id)

        tx_type = self.request.query_params.get('transaction_type')
        if tx_type:
            qs = qs.filter(transaction_type=tx_type)

        material_type = self.request.query_params.get('material_type')
        if material_type:
            qs = qs.filter(material_type=material_type)

        return qs[:200]


class ExpenseListCreateAPIView(generics.ListCreateAPIView):
    queryset = Expense.objects.all()
    serializer_class = ExpenseSerializer
    permission_classes = [permissions.IsAuthenticated]

    def perform_create(self, serializer):
        count = Expense.objects.count() + 1
        exp_number = f"EXP-{timezone.now().strftime('%Y%m')}-{count:04d}"
        serializer.save(expense_number=exp_number, recorded_by=self.request.user)


class DailyBusinessReportAPIView(views.APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        date_str = request.query_params.get('date')
        start_date = request.query_params.get('start_date')
        end_date = request.query_params.get('end_date')

        qs = DailyBusinessReport.objects.all()

        if date_str:
            qs = qs.filter(report_date=date_str)
        else:
            if start_date:
                qs = qs.filter(report_date__gte=start_date)
            if end_date:
                qs = qs.filter(report_date__lte=end_date)

        reports = qs.order_by('-report_date')[:60]
        return Response(DailyBusinessReportSerializer(reports, many=True).data)


class ExpiryAlertListAPIView(generics.ListAPIView):
    queryset = ExpiryAlertLog.objects.all()
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        user = request.user
        qs = ExpiryAlertLog.objects.select_related('production_batch__product', 'dealer_batch__product', 'dealer').all()
        if hasattr(user, 'profile') and user.profile.role == 'franchise':
            dealer = getattr(user, 'franchise_profile', None)
            if dealer:
                qs = qs.filter(dealer=dealer)
            else:
                qs = qs.none()

        data = [
            {
                'id': a.id,
                'batch_type': a.batch_type,
                'dealer_name': a.dealer.business_name if a.dealer else 'Company Central Plant',
                'batch_number': a.production_batch.batch_number if a.production_batch else (a.dealer_batch.batch_number if a.dealer_batch else ''),
                'product_name': a.production_batch.product.name if a.production_batch else (a.dealer_batch.product.name if a.dealer_batch else ''),
                'alert_level': a.alert_level,
                'alert_date': a.alert_date.isoformat(),
                'deduplication_hash': a.deduplication_hash
            }
            for a in qs[:100]
        ]
        return Response({'success': True, 'count': len(data), 'alerts': data})


class StockAdjustmentAPIView(views.APIView):
    """
    Authorized manual stock audit correction. Creates an ADJUSTMENT ledger transaction.
    """
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        user = request.user
        role = getattr(getattr(user, 'profile', None), 'role', '')
        if not (user.is_superuser or role in ['admin', 'super_admin', 'franchise']):
            return Response({'error': 'Unauthorized to record stock adjustments.'}, status=status.HTTP_403_FORBIDDEN)

        entity_type = request.data.get('entity_type')
        entity_id = request.data.get('entity_id')
        adjusted_quantity = request.data.get('adjusted_quantity')
        reason = request.data.get('reason', 'Manual Stock Correction')

        if not entity_type or not entity_id or adjusted_quantity is None:
            return Response({'error': 'entity_type, entity_id, and adjusted_quantity are required.'}, status=status.HTTP_400_BAD_REQUEST)

        from .services import adjust_stock_atomic
        try:
            ledger_entry = adjust_stock_atomic(
                entity_type=entity_type,
                entity_id=entity_id,
                adjusted_quantity=adjusted_quantity,
                reason=reason,
                actor=user
            )
            return Response({
                'success': True,
                'message': 'Stock adjustment successfully logged.',
                'transaction_id': str(ledger_entry.transaction_id),
                'transaction_type': ledger_entry.transaction_type,
                'quantity': str(ledger_entry.quantity),
                'balance_after': str(ledger_entry.balance_after)
            }, status=status.HTTP_201_CREATED)
        except Exception as e:
            return Response({'error': str(e)}, status=status.HTTP_400_BAD_REQUEST)


class PendingStockExpiryAlertView(APIView):
    """
    Returns real DB-backed pending/uncollected stock approaching expiry.
    Audience: SUPER_ADMIN (unrestricted) and ADMIN (scoped by apply_data_scope).
    Calculates current pending quantity dynamically from actual database records.
    """
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        user = request.user
        role = getattr(getattr(user, 'profile', None), 'role', '')
        if not user.is_superuser and role not in ['super_admin', 'admin']:
            return Response({'success': False, 'message': 'Forbidden: Admin access required.'}, status=status.HTTP_403_FORBIDDEN)

        from .services import get_pending_stock_expiry_alerts
        alerts = get_pending_stock_expiry_alerts(user=user)
        return Response({
            'success': True,
            'count': len(alerts),
            'alerts': alerts,
        }, status=status.HTTP_200_OK)


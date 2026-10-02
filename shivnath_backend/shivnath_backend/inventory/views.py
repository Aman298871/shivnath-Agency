from django.shortcuts import get_object_or_404
from django.db import transaction
from django.db.models import Q, F, Sum, DecimalField, ExpressionWrapper
from django.utils import timezone
import logging

logger = logging.getLogger(__name__)

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
    get_dealer_stock_request_fulfillment_details,
    fulfill_dealer_stock_request_atomic,
    fulfill_all_pending_dealer_stock_requests,
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
                shelf_life_days=int(shelf_life_days) if shelf_life_days not in (None, '') and str(shelf_life_days).strip().isdigit() else None,
                client_name=client_name,
                linked_order=linked_order,
                label_requirement=label_requirement,
                printing_requirement=printing_requirement,
                branding_requirement=branding_requirement,
                actor=request.user
            )
            batch.refresh_from_db()
            data = ProductionBatchSerializer(batch).data
            return Response({'success': True, 'message': 'Production batch created successfully.', 'data': data, **data}, status=status.HTTP_201_CREATED)
        except Exception as e:
            return Response({'success': False, 'message': str(e), 'error': str(e)}, status=status.HTTP_400_BAD_REQUEST)


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
        payment_status = request.data.get('payment_status')
        payment_method = request.data.get('payment_method', 'CASH')
        reference_number = request.data.get('reference_number', '')
        amount_due = request.data.get('amount_due')
        amount_paid = request.data.get('amount_paid')
        delivery_status = request.data.get('delivery_status') or request.data.get('order_status')

        try:
            res = record_batch_collection_atomic(
                batch_id=pk,
                quantity_collected=int(qty),
                client_name=client_name,
                notes=notes,
                actor=request.user,
                payment_status=payment_status,
                payment_method=payment_method,
                reference_number=reference_number,
                amount_due=amount_due,
                amount_paid=amount_paid,
                delivery_status=delivery_status,
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
                    'billing': res.get('billing'),
                },
                'billing': res.get('billing'),
            }, status=status.HTTP_200_OK)
        except Exception as e:
            msg = str(e)
            if hasattr(e, 'messages') and e.messages:
                msg = e.messages[0]
            elif hasattr(e, 'message') and e.message:
                msg = e.message
            if msg.startswith("['") and msg.endswith("']"):
                msg = msg[2:-2]
            return Response({'error': msg, 'message': msg}, status=status.HTTP_400_BAD_REQUEST)


class DealerStockBatchListAPIView(generics.ListAPIView):
    serializer_class = DealerStockBatchSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        qs = DealerStockBatch.objects.select_related('product', 'dealer').all()

        dealer = getattr(user, 'franchise_profile', None)
        if dealer:
            qs = qs.filter(dealer=dealer)
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

        dealer = getattr(user, 'franchise_profile', None)
        if dealer:
            qs = qs.filter(dealer=dealer)
        else:
            dealer_id = request.query_params.get('dealer_id')
            if dealer_id:
                qs = qs.filter(dealer_id=dealer_id)

        status_param = request.query_params.get('status')
        if status_param:
            qs = qs.filter(status=status_param)

        qs = qs.order_by('-created_at')

        serializer = DealerStockRequestSerializer(qs, many=True)
        return Response(serializer.data)

    def post(self, request):
        user = request.user
        dealer = getattr(user, 'franchise_profile', None)
        if not dealer and 'dealer_id' in request.data:
            from accounts.models import FranchiseProfile
            dealer = get_object_or_404(FranchiseProfile, id=request.data['dealer_id'])

        if not dealer:
            return Response({'success': False, 'error': 'No dealer profile associated.', 'message': 'No dealer profile associated.'}, status=status.HTTP_400_BAD_REQUEST)

        notes = request.data.get('dealer_notes') or request.data.get('notes', '')
        raw_items = request.data.get('items')

        from products.models import Product

        # Helper for robust active product resolution for the 5 official SKUs
        def _resolve_stock_product(p_id, p_sku):
            canonical_skus = {
                'SHV-200': ['SHV-200', 'SKU-BOT-200', 'BOT-200', '200ML', 'SHV-200ML', '200'],
                'SHV-250': ['SHV-250', 'SKU-BOT-250', 'BOT-250', '250ML', 'SHV-250ML', '250'],
                'SHV-500': ['SHV-500', 'SKU-BOT-500', 'BOT-500', '500ML', 'SHV-500ML', '500'],
                'SHV-1L': ['SHV-1L', 'SKU-BOT-1000', 'BOT-1000', '1000ML', 'SHV-1000', 'SHV-1000ML', '1L', '1 LITRE', '1000'],
                'SHV-20L': ['SHV-20L', 'SKU-JAR-20L', 'JAR-20L', '20000ML', 'DEV-JAR-20L', 'STOCK-JAR-20L', '20L', '20 LITRE', '20000'],
            }

            # 1. Determine canonical SKU if p_sku is provided
            target_canonical = None
            if p_sku:
                sku_clean = str(p_sku).strip().upper()
                for canon, aliases in canonical_skus.items():
                    if sku_clean == canon or sku_clean in aliases:
                        target_canonical = canon
                        break

            # 2. If target_canonical is found, find the ACTIVE product with this exact SKU first!
            if target_canonical:
                active_prod = Product.objects.filter(sku__iexact=target_canonical, status='Active').first()
                if active_prod:
                    return active_prod

            # 3. If p_id is provided, verify it is Active and matches canonical family
            if p_id:
                try:
                    prod_by_id = Product.objects.filter(id=p_id, status='Active').first()
                    if prod_by_id:
                        if not target_canonical or prod_by_id.sku.upper() in canonical_skus.get(target_canonical, []):
                            return prod_by_id
                except (ValueError, TypeError):
                    pass

            # 4. Search by exact SKU (case-insensitive) active
            if p_sku:
                sku_clean = str(p_sku).strip()
                prod = Product.objects.filter(sku__iexact=sku_clean, status='Active').first()
                if prod:
                    return prod

            # 5. Search by aliases active
            if target_canonical:
                for alias in canonical_skus[target_canonical]:
                    prod = Product.objects.filter(sku__iexact=alias, status='Active').first()
                    if prod:
                        return prod

            # 6. Fallback volume lookup active
            if target_canonical == 'SHV-200' or (p_sku and '200' in str(p_sku).lower() and '2000' not in str(p_sku).lower()):
                return Product.objects.filter(volume_ml=200, status='Active').first()
            elif target_canonical == 'SHV-250' or (p_sku and '250' in str(p_sku).lower()):
                return Product.objects.filter(volume_ml=250, status='Active').first()
            elif target_canonical == 'SHV-500' or (p_sku and '500' in str(p_sku).lower()):
                return Product.objects.filter(volume_ml=500, status='Active').first()
            elif target_canonical == 'SHV-1L' or (p_sku and ('1000' in str(p_sku).lower() or '1l' in str(p_sku).lower())):
                return Product.objects.filter(volume_ml=1000, status='Active').first()
            elif target_canonical == 'SHV-20L' or (p_sku and ('20000' in str(p_sku).lower() or '20l' in str(p_sku).lower())):
                return Product.objects.filter(volume_ml=20000, status='Active').first()

            return None

        def _generate_stock_request_number():
            prefix = f"SR-{timezone.now().strftime('%Y%m')}"
            base_count = DealerStockRequest.objects.count() + 1
            req_number = f"{prefix}-{base_count:04d}"
            attempt = base_count
            while DealerStockRequest.objects.filter(request_number=req_number).exists():
                attempt += 1
                req_number = f"{prefix}-{attempt:04d}"
            return req_number

        try:
            # Handle batch items from Flutter franchise inventory screen
            if isinstance(raw_items, list) and len(raw_items) > 0:
                validated_items = []
                validation_errors = []

                for item in raw_items:
                    p_id = item.get('product_id') or item.get('product') or item.get('id')
                    product_sku = item.get('product_sku') or item.get('sku') or ''

                    qty_units = item.get('quantity_units')
                    qty_cases = item.get('quantity_cases')
                    qty_generic = item.get('requested_quantity') or item.get('quantity')

                    if qty_units is not None:
                        qty = qty_units
                    elif qty_cases is not None:
                        qty = qty_cases
                    else:
                        qty = qty_generic

                    try:
                        qty_int = int(qty) if qty is not None else 0
                    except (ValueError, TypeError):
                        qty_int = 0

                    if qty_int <= 0:
                        continue  # User left item at 0 quantity

                    product = _resolve_stock_product(p_id, product_sku)

                    if product is None:
                        validation_errors.append(
                            f"Item (sku={product_sku or p_id}): product not found in catalog."
                        )
                        continue

                    if product.status != 'Active':
                        validation_errors.append(
                            f"Item ({product.sku}): product is inactive or archived."
                        )
                        continue

                    validated_items.append((product, qty_int))

                if not validated_items:
                    err_msg = '; '.join(validation_errors) if validation_errors else 'Please enter a quantity greater than 0 for at least one active product.'
                    return Response(
                        {
                            'success': False,
                            'message': err_msg,
                            'errors': validation_errors,
                        },
                        status=status.HTTP_400_BAD_REQUEST
                    )

                created_requests = []
                with transaction.atomic():
                    for product, qty_int in validated_items:
                        req_number = _generate_stock_request_number()

                        stock_req = DealerStockRequest.objects.create(
                            request_number=req_number,
                            dealer=dealer,
                            product=product,
                            requested_quantity=qty_int,
                            dealer_notes=notes,
                            status='REQUESTED'
                        )
                        created_requests.append(stock_req)

                # Authoritative notification to Admin and Super Admin
                try:
                    from accounts.models import AdminNotification
                    summary_items = ", ".join([f"{sr.requested_quantity}x {sr.product.sku}" for sr in created_requests[:3]])
                    if len(created_requests) > 3:
                        summary_items += f" (+{len(created_requests) - 3} more)"
                    AdminNotification.objects.create(
                        title=f"New Stock Request: {dealer.business_name}",
                        message=f"Franchise {dealer.business_name} requested Central Plant stock: {summary_items}. Request #{created_requests[0].request_number}.",
                        notification_type='stock_alert',
                        reference_id=created_requests[0].id,
                    )
                    from accounts.fcm_services import notify_stock_request_created
                    for cr in created_requests:
                        notify_stock_request_created(cr)
                except Exception:
                    pass

                serialized_list = DealerStockRequestSerializer(created_requests, many=True).data
                return Response({
                    'success': True,
                    'message': f'{len(created_requests)} stock request(s) submitted successfully.',
                    'requests': serialized_list,
                    'data': serialized_list,
                }, status=status.HTTP_201_CREATED)

            # Handle single product request
            product_id = request.data.get('product') or request.data.get('product_id')
            qty = request.data.get('requested_quantity') or request.data.get('quantity')
            product_sku = request.data.get('sku') or request.data.get('product_sku')

            if not product_id and not product_sku:
                return Response({'success': False, 'error': 'Product identifier is required.', 'message': 'Product identifier is required.'}, status=status.HTTP_400_BAD_REQUEST)

            if not qty:
                return Response({'success': False, 'error': 'Requested quantity is required.', 'message': 'Requested quantity is required.'}, status=status.HTTP_400_BAD_REQUEST)

            try:
                qty_int = int(qty)
                if qty_int <= 0:
                    raise ValueError()
            except (ValueError, TypeError):
                return Response({'success': False, 'error': 'Requested quantity must be greater than 0.', 'message': 'Requested quantity must be greater than 0.'}, status=status.HTTP_400_BAD_REQUEST)

            product = _resolve_stock_product(product_id, product_sku)
            if not product:
                return Response({'success': False, 'error': f'Product not found (id={product_id}, sku={product_sku}).', 'message': f'Product not found (id={product_id}, sku={product_sku}).'}, status=status.HTTP_400_BAD_REQUEST)

            if product.status != 'Active':
                return Response({'success': False, 'error': f'Product {product.sku} is inactive.', 'message': f'Product {product.sku} is inactive.'}, status=status.HTTP_400_BAD_REQUEST)

            req_number = _generate_stock_request_number()

            stock_req = DealerStockRequest.objects.create(
                request_number=req_number,
                dealer=dealer,
                product=product,
                requested_quantity=qty_int,
                dealer_notes=notes,
                status='REQUESTED'
            )

            # Authoritative notification to Admin and Super Admin
            try:
                from accounts.models import AdminNotification
                AdminNotification.objects.create(
                    title=f"New Stock Request: {dealer.business_name}",
                    message=f"Franchise {dealer.business_name} requested {qty_int}x {product.sku} ({product.name}). Request #{req_number}.",
                    notification_type='stock_alert',
                    reference_id=stock_req.id,
                )
                from accounts.fcm_services import notify_stock_request_created
                notify_stock_request_created(stock_req)
            except Exception:
                pass

            data = DealerStockRequestSerializer(stock_req).data
            return Response({
                'success': True,
                'message': 'Stock request submitted successfully.',
                'data': data,
                **data,
            }, status=status.HTTP_201_CREATED)

        except Exception as e:
            logger.exception("Error creating dealer stock request: %s", str(e))
            return Response(
                {
                    'success': False,
                    'error': str(e),
                    'message': f'Failed to create stock request: {str(e)}'
                },
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


class DealerStockRequestDispatchAPIView(views.APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, pk):
        stock_req = get_object_or_404(DealerStockRequest, pk=pk)
        allocations_data = request.data.get('allocations', [])

        if not allocations_data:
            # Auto-FEFO allocation fallback
            needed_quantity = max(0, stock_req.requested_quantity - stock_req.dispatched_quantity)
            custom_qty = request.data.get('quantity')
            if custom_qty:
                needed_quantity = min(needed_quantity, int(custom_qty))
            elif request.data.get('items'):
                items_list = request.data.get('items', [])
                if isinstance(items_list, list) and items_list:
                    item_spec = items_list[0]
                    if 'cases_to_dispatch' in item_spec:
                        upc = getattr(stock_req.product, 'units_per_case', 24) or 24
                        needed_quantity = min(needed_quantity, int(item_spec['cases_to_dispatch']) * upc)
                    elif 'quantity' in item_spec:
                        needed_quantity = min(needed_quantity, int(item_spec['quantity']))

            if needed_quantity <= 0:
                return Response({'error': 'No quantity to dispatch or request is already fulfilled.'}, status=status.HTTP_400_BAD_REQUEST)

            from django.utils import timezone
            today = timezone.now().date()
            batches = ProductionBatch.objects.filter(
                product=stock_req.product,
                status='ACTIVE',
                quantity_remaining_company__gt=0,
                expiry_date__gt=today
            ).order_by('expiry_date', 'manufacture_date')

            allocations_data = []
            accumulated = 0
            for b in batches:
                avail = b.available_quantity
                if avail <= 0:
                    continue
                take = min(avail, needed_quantity - accumulated)
                allocations_data.append({'batch_id': b.id, 'quantity': take})
                accumulated += take
                if accumulated >= needed_quantity:
                    break

            if accumulated < needed_quantity:
                total_avail = sum(b.available_quantity for b in batches)
                return Response({
                    'error': f'Insufficient central plant stock for {stock_req.product.name}. Available: {total_avail} units, Required: {needed_quantity} units. Please produce a new batch first.',
                    'message': f'Insufficient central plant stock for {stock_req.product.name}. Available: {total_avail} units, Required: {needed_quantity} units.'
                }, status=status.HTTP_400_BAD_REQUEST)

        try:
            req_obj, invoice = allocate_and_dispatch_stock_request_atomic(
                stock_request=stock_req,
                allocations_list=allocations_data,
                actor=request.user
            )
            try:
                from accounts.fcm_services import notify_stock_request_status
                notify_stock_request_status(req_obj, 'DISPATCHED', actor_name=request.user.get_full_name() or request.user.username)
            except Exception:
                pass
            return Response({
                'success': True,
                'message': f'Dispatched successfully! Wholesale invoice #{invoice.invoice_number} generated.',
                'stock_request': DealerStockRequestSerializer(req_obj).data,
                'invoice_id': invoice.id,
                'invoice_number': invoice.invoice_number,
                'grand_total': invoice.grand_total
            }, status=status.HTTP_200_OK)
        except Exception as e:
            return Response({'error': str(e), 'message': str(e)}, status=status.HTTP_400_BAD_REQUEST)



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
            try:
                from accounts.fcm_services import notify_stock_request_status
                notify_stock_request_status(req_obj, 'RECEIVED', actor_name=request.user.get_full_name() or request.user.username)
            except Exception:
                pass
            return Response(DealerStockRequestSerializer(req_obj).data, status=status.HTTP_200_OK)
        except Exception as e:
            return Response({'error': str(e)}, status=status.HTTP_400_BAD_REQUEST)


class DealerStockRequestFulfillmentTrackerAPIView(views.APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, pk):
        stock_req = get_object_or_404(DealerStockRequest, pk=pk)
        user = request.user
        is_franchise = hasattr(user, 'profile') and user.profile.role == 'franchise'
        if is_franchise:
            dealer = getattr(user, 'franchise_profile', None)
            if not dealer or stock_req.dealer_id != dealer.id:
                return Response(
                    {'success': False, 'message': 'Permission denied: cannot view stock requests belonging to another franchise.'},
                    status=status.HTTP_403_FORBIDDEN
                )

        include_costs = not is_franchise
        try:
            details = get_dealer_stock_request_fulfillment_details(stock_req, include_costs=include_costs)
            return Response({'success': True, 'fulfillment': details}, status=status.HTTP_200_OK)
        except Exception as e:
            logger.exception("Error calculating fulfillment tracker details: %s", str(e))
            return Response({'success': False, 'error': str(e), 'message': f'Fulfillment calculation error: {str(e)}'}, status=status.HTTP_400_BAD_REQUEST)


class DealerStockRequestFulfillSingleAPIView(views.APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, pk):
        user = request.user
        if hasattr(user, 'profile') and user.profile.role == 'franchise':
            return Response({'success': False, 'message': 'Only plant admins can fulfill stock requests.'}, status=status.HTTP_403_FORBIDDEN)

        stock_req = get_object_or_404(DealerStockRequest, pk=pk)
        auto_receive = request.data.get('auto_receive', True)
        try:
            fulfilled = fulfill_dealer_stock_request_atomic(stock_req, actor=user, auto_receive=auto_receive)
            try:
                from accounts.fcm_services import notify_stock_request_status
                notify_stock_request_status(fulfilled, fulfilled.status, actor_name=user.get_full_name() or user.username)
            except Exception:
                pass
            return Response({
                'success': True,
                'message': f"Request {fulfilled.request_number} fulfilled and completed successfully.",
                'request_number': fulfilled.request_number,
                'status': fulfilled.status,
                'dispatched_quantity': fulfilled.dispatched_quantity,
                'received_quantity': fulfilled.received_quantity,
            }, status=status.HTTP_200_OK)
        except Exception as e:
            logger.exception("Error fulfilling dealer stock request %s: %s", pk, str(e))
            return Response({'success': False, 'error': str(e), 'message': str(e)}, status=status.HTTP_400_BAD_REQUEST)


class DealerStockRequestFulfillAllAPIView(views.APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        user = request.user
        if hasattr(user, 'profile') and user.profile.role == 'franchise':
            return Response({'success': False, 'message': 'Only plant admins can fulfill stock requests.'}, status=status.HTTP_403_FORBIDDEN)

        auto_receive = request.data.get('auto_receive', True)
        try:
            results = fulfill_all_pending_dealer_stock_requests(actor=user, auto_receive=auto_receive)
            success_count = sum(1 for r in results if r.get('success'))
            return Response({
                'success': True,
                'message': f"Completed fulfillment of {success_count} dealer stock request(s).",
                'count': len(results),
                'success_count': success_count,
                'results': results,
            }, status=status.HTTP_200_OK)
        except Exception as e:
            logger.exception("Error executing fulfill-all dealer stock requests: %s", str(e))
            return Response({'success': False, 'error': str(e), 'message': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class InventoryLedgerListAPIView(generics.ListAPIView):
    serializer_class = InventoryTransactionLedgerSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        qs = InventoryTransactionLedger.objects.select_related('product', 'raw_material', 'dealer', 'actor').all()

        dealer = getattr(user, 'franchise_profile', None)
        if dealer:
            qs = qs.filter(dealer=dealer)
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
        from datetime import date, timedelta
        from decimal import Decimal
        from django.utils import timezone
        from orders.models import Order, OrderItem
        from leads.models import Lead
        from billing.models import Invoice

        today = timezone.now().date()
        date_str = request.query_params.get('date')
        start_date_str = request.query_params.get('start_date')
        end_date_str = request.query_params.get('end_date')
        period = (request.query_params.get('period') or '').strip().lower()

        start_date = None
        end_date = None

        if period in ['all', 'all_time', 'lifetime']:
            start_date = date(2020, 1, 1)
            end_date = today + timedelta(days=365)
        elif period == 'today':
            start_date = today
            end_date = today
        elif period == 'yesterday':
            start_date = today - timedelta(days=1)
            end_date = today - timedelta(days=1)
        elif period in ['this_week', 'this week', 'week']:
            start_date = today - timedelta(days=today.weekday())
            end_date = today
        elif period in ['this_month', 'this month', 'month']:
            start_date = today.replace(day=1)
            end_date = today
        elif period in ['last_month', 'last month']:
            first_this_month = today.replace(day=1)
            last_day_last_month = first_this_month - timedelta(days=1)
            start_date = last_day_last_month.replace(day=1)
            end_date = last_day_last_month
        elif period in ['last_3_months', 'last 3 months']:
            start_date = (today.replace(day=1) - timedelta(days=60)).replace(day=1)
            end_date = today
        elif period in ['this_year', 'this year']:
            start_date = today.replace(month=1, day=1)
            end_date = today
        elif start_date_str and end_date_str:
            try:
                start_date = date.fromisoformat(start_date_str)
                end_date = date.fromisoformat(end_date_str)
            except Exception:
                pass
        elif date_str:
            try:
                start_date = date.fromisoformat(date_str)
                end_date = start_date
            except Exception:
                pass

        if not start_date:
            start_date = today.replace(day=1)
        if not end_date:
            end_date = today

        # 1. Dynamically calculate and sync today's DailyBusinessReport
        try:
            from inventory.services import sync_daily_business_report
            sync_daily_business_report(today)
        except Exception:
            pass

        # 2. Query data across the requested date range
        orders_qs = Order.objects.filter(
            created_at__date__gte=start_date,
            created_at__date__lte=end_date
        ).select_related('created_by', 'serving_franchise').prefetch_related('items').order_by('-created_at')

        stock_requests_qs = DealerStockRequest.objects.filter(
            created_at__date__gte=start_date,
            created_at__date__lte=end_date
        ).select_related('dealer', 'product').order_by('-created_at')

        leads_qs = Lead.objects.filter(
            created_at__date__gte=start_date,
            created_at__date__lte=end_date
        ).order_by('-created_at')

        total_orders_count = orders_qs.count()
        total_order_amount = orders_qs.exclude(status__in=['Cancelled', 'CANCELLED', 'cancelled']).aggregate(t=Sum('amount'))['t'] or Decimal('0.00')
        customer_orders = [
            {
                'id': o.id,
                'order_code': o.order_code,
                'customer': o.franchise_name or (o.created_by.get_full_name() if o.created_by else 'Customer'),
                'items_count': o.items_count,
                'quantity': sum(it.quantity for it in o.items.all()) or o.items_count,
                'amount': float(o.amount),
                'status': o.status,
                'status_display': o.get_status_display(),
                'order_source': o.order_source,
                'serving_franchise': o.serving_franchise.business_name if o.serving_franchise else 'Direct Company',
                'created_at': o.created_at.strftime('%d %b %Y %H:%M') if o.created_at else '',
            }
            for o in orders_qs[:100]
        ]

        franchise_activity = [
            {
                'id': req.id,
                'request_number': req.request_number,
                'franchise_name': req.dealer.business_name if req.dealer else 'Franchise',
                'product_name': req.product.name if req.product else '',
                'requested_quantity': req.requested_quantity,
                'approved_quantity': req.approved_quantity,
                'dispatched_quantity': req.dispatched_quantity,
                'received_quantity': req.received_quantity,
                'pending_quantity': max(0, req.requested_quantity - (req.received_quantity or 0)),
                'outstanding': float(getattr(req.dealer, 'current_balance', 0.0)) if req.dealer else 0.0,
                'status': req.status,
                'created_at': req.created_at.strftime('%d %b %Y %H:%M') if req.created_at else '',
            }
            for req in stock_requests_qs[:100]
        ]

        lead_activity = [
            {
                'id': l.id,
                'name': l.name,
                'phone': l.phone,
                'source': l.source,
                'status': l.status,
                'score_category': l.score_category,
                'city': l.city,
                'territory': l.territory,
                'created_at': l.created_at.strftime('%d %b %Y %H:%M') if l.created_at else '',
            }
            for l in leads_qs[:100]
        ]

        reports_qs = DailyBusinessReport.objects.filter(
            report_date__gte=start_date,
            report_date__lte=end_date
        ).order_by('-report_date')

        reports_data = list(DailyBusinessReportSerializer(reports_qs, many=True).data)

        # 3. REVENUE RECOGNITION = DELIVERED ONLY (Authoritative Business Rule)
        from billing.models import PaymentTransaction
        from inventory.models import ProductionBatch, DealerStockBatch, Expense, DealerStockRequestAllocation, InventoryTransactionLedger
        from django.db.models import Q

        # Operational status counts in date range
        orders_placed_count = orders_qs.filter(status='order_placement').count()
        orders_approved_count = orders_qs.filter(status='plant_approval').count()
        orders_preparing_count = orders_qs.filter(status__in=['preparing', 'invoice_generated']).count()
        orders_dispatched_count = orders_qs.filter(status='dispatch').count()
        orders_delivered_count = orders_qs.filter(status__in=['delivered', 'DELIVERED', 'Delivered']).count()
        orders_cancelled_count = orders_qs.filter(status__in=['cancelled', 'CANCELLED', 'Cancelled']).count()

        # Orders delivered in this period (regardless of placement date)
        delivered_orders_in_range = Order.objects.filter(
            status__in=['delivered', 'DELIVERED', 'Delivered']
        ).filter(
            Q(delivered_at__date__gte=start_date, delivered_at__date__lte=end_date) |
            Q(delivered_at__isnull=True, updated_at__date__gte=start_date, updated_at__date__lte=end_date)
        ).prefetch_related('items__product')

        # Direct Company delivered revenue & COGS
        direct_delivered = delivered_orders_in_range.filter(order_source='DIRECT_COMPANY')
        direct_rev = direct_delivered.aggregate(t=Sum('grand_total'))['t'] or direct_delivered.aggregate(t=Sum('amount'))['t'] or Decimal('0.00')

        cogs_direct = OrderItem.objects.filter(order__in=direct_delivered).aggregate(
            c=Sum('snapshot_total_cogs')
        )['c'] or Decimal('0.00')
        if cogs_direct == 0 and direct_delivered.exists():
            cogs_direct = OrderItem.objects.filter(order__in=direct_delivered).aggregate(
                c=Sum(F('snapshot_unit_production_cost') * F('quantity'))
            )['c'] or Decimal('0.00')

        # Wholesale Dealer Invoices issued in date range
        dealer_invoices = Invoice.objects.filter(
            invoice_type='DEALER_PURCHASE_INVOICE',
            issued_at__date__gte=start_date,
            issued_at__date__lte=end_date
        ).exclude(status__in=['CANCELLED', 'Cancelled'])
        dealer_rev = dealer_invoices.aggregate(t=Sum('grand_total'))['t'] or Decimal('0.00')

        # Dealer wholesale dispatch COGS in date range
        dealer_allocations = DealerStockRequestAllocation.objects.filter(
            created_at__date__gte=start_date,
            created_at__date__lte=end_date
        ).select_related('production_batch')
        cogs_dealer = sum(
            (Decimal(str(a.dispatched_quantity or a.allocated_quantity)) * a.production_batch.unit_production_cost)
            for a in dealer_allocations if a.production_batch
        )

        # Inventory dispatches to dealers in range
        dispatches = InventoryTransactionLedger.objects.filter(
            transaction_type='STOCK_TRANSFER_OUT',
            timestamp__date__gte=start_date,
            timestamp__date__lte=end_date
        )
        dispatch_units = abs(dispatches.aggregate(q=Sum('quantity'))['q'] or 0)
        if not cogs_dealer and dispatch_units > 0:
            cogs_dealer = Decimal(dispatch_units) * Decimal('6.50')

        # Total authoritative financial figures
        agg_gross = dealer_rev + direct_rev
        agg_cogs = Decimal(str(cogs_dealer)) + Decimal(str(cogs_direct))

        # Operating expenses in date range
        expenses_in_range = Expense.objects.filter(
            paid_date__gte=start_date,
            paid_date__lte=end_date
        )
        total_exp = expenses_in_range.aggregate(a=Sum('amount'))['a'] or Decimal('0.00')

        gross_profit = agg_gross - agg_cogs
        agg_net = gross_profit - total_exp

        # Payments in date range
        payments_qs = PaymentTransaction.objects.filter(
            payment_date__date__gte=start_date,
            payment_date__date__lte=end_date
        )
        total_collected = payments_qs.filter(payment_status='SUCCESS').aggregate(s=Sum('amount_paid'))['s'] or Decimal('0.00')
        cash_collected = payments_qs.filter(payment_status='SUCCESS', payment_method='CASH').aggregate(s=Sum('amount_paid'))['s'] or Decimal('0.00')
        online_collected = total_collected - cash_collected
        pending_verif_amt = payments_qs.filter(payment_status='PENDING_VERIFICATION').aggregate(s=Sum('amount_paid'))['s'] or Decimal('0.00')
        pending_verif_cnt = payments_qs.filter(payment_status='PENDING_VERIFICATION').count()
        confirmed_cnt = payments_qs.filter(payment_status='SUCCESS').count()
        rejected_cnt = payments_qs.filter(payment_status='REJECTED').count()

        invoices_qs = Invoice.objects.filter(
            issued_at__date__gte=start_date,
            issued_at__date__lte=end_date
        )
        total_outstanding = invoices_qs.aggregate(s=Sum(F('grand_total') - F('amount_paid')))['s'] or Decimal('0.00')

        # Production in date range
        prod_batches = ProductionBatch.objects.filter(
            created_at__date__gte=start_date,
            created_at__date__lte=end_date
        )
        prod_units = prod_batches.aggregate(u=Sum('quantity_produced_units'))['u'] or 0
        prod_cost = prod_batches.aggregate(c=Sum(F('quantity_produced_units') * F('unit_production_cost')))['c'] or Decimal('0.00')

        central_stock = ProductionBatch.objects.filter(status='ACTIVE').aggregate(s=Sum('quantity_remaining_company'))['s'] or 0
        franchise_stock = DealerStockBatch.objects.filter(is_active=True).aggregate(s=Sum('remaining_quantity'))['s'] or 0

        # Monthly chart data derived from delivered orders & dealer invoices
        monthly_map = {}
        for o in Order.objects.filter(status__in=['delivered', 'DELIVERED', 'Delivered'], delivered_at__year=today.year):
            m_key = o.delivered_at.strftime('%b')
            monthly_map[m_key] = monthly_map.get(m_key, 0.0) + float(o.grand_total or o.amount)
        for inv in Invoice.objects.filter(invoice_type='DEALER_PURCHASE_INVOICE', issued_at__year=today.year).exclude(status__in=['CANCELLED', 'Cancelled']):
            m_key = inv.issued_at.strftime('%b')
            monthly_map[m_key] = monthly_map.get(m_key, 0.0) + float(inv.grand_total)

        monthly_sales_list = [{'month': m, 'amount': int(val)} for m, val in monthly_map.items()]

        # 4. Product-wise Profitability Breakdown (Authoritative from Delivered Sales)
        prod_map = {}
        for it in OrderItem.objects.filter(order__in=delivered_orders_in_range).select_related('product'):
            p_name = it.product_name or (it.product.name if it.product else 'Product')
            p_sku = it.product.sku if it.product else p_name
            if p_sku not in prod_map:
                prod_map[p_sku] = {
                    'sku': p_sku,
                    'name': p_name,
                    'quantity': 0,
                    'revenue': 0.0,
                    'cogs': 0.0,
                    'gross_profit': 0.0,
                    'margin_pct': 0.0,
                }
            it_rev = float(it.total_price or (it.unit_price * it.quantity))
            it_cogs = float(it.snapshot_total_cogs or (it.snapshot_unit_production_cost * it.quantity))
            prod_map[p_sku]['quantity'] += it.quantity
            prod_map[p_sku]['revenue'] += it_rev
            prod_map[p_sku]['cogs'] += it_cogs

        for sku_k, p_val in prod_map.items():
            p_val['gross_profit'] = p_val['revenue'] - p_val['cogs']
            if p_val['revenue'] > 0:
                p_val['margin_pct'] = round((p_val['gross_profit'] / p_val['revenue']) * 100, 1)

        product_wise_list = list(prod_map.values())

        # Franchise-wise Breakdown
        fran_map = {}
        for o in delivered_orders_in_range:
            f_name = o.serving_franchise.business_name if o.serving_franchise else (o.franchise_name or 'Direct Company')
            if f_name not in fran_map:
                fran_map[f_name] = {'name': f_name, 'orders_count': 0, 'revenue': 0.0}
            fran_map[f_name]['orders_count'] += 1
            fran_map[f_name]['revenue'] += float(o.grand_total or o.amount)
        franchise_wise_list = list(fran_map.values())

        from leads.models import LeadFollowup
        followups_count = LeadFollowup.objects.filter(scheduled_date__gte=start_date, scheduled_date__lte=end_date).count()

        summary_data = {
            'gross_revenue': float(agg_gross),
            'total_revenue': float(agg_gross),
            'gross_profit': float(gross_profit),
            'collected_amount': float(total_collected),
            'pending_amount': float(total_outstanding),
            'direct_company_revenue': float(direct_rev),
            'franchise_revenue': float(dealer_rev),
            'cogs': float(agg_cogs),
            'expenses': float(total_exp),
            'net_profit': float(agg_net),
            'production_volume_units': int(prod_units),
            'dealer_dispatch_units': int(dispatch_units),
            'central_stock_units': int(central_stock),
            'franchise_stock_units': int(franchise_stock),
            'total_orders': total_orders_count,
            'orders_placed': orders_placed_count,
            'orders_approved': orders_approved_count,
            'orders_preparing': orders_preparing_count,
            'orders_dispatched': orders_dispatched_count,
            'orders_delivered': orders_delivered_count,
            'orders_cancelled': orders_cancelled_count,
            'delivered_orders': orders_delivered_count,
            'cancelled_orders': orders_cancelled_count,
            'quantity_sold': sum(p['quantity'] for p in product_wise_list),
            'customer_orders_count': total_orders_count,
            'franchise_requests_count': stock_requests_qs.count(),
            'new_leads_count': leads_qs.count(),
            'converted_leads_count': leads_qs.filter(status__in=['CONVERTED', 'FRANCHISE_CONFIRMED', 'converted', 'franchise_confirmed']).count(),
            'followups_count': followups_count,
        }

        # ─────────────────────────────────────────────────────────────────────
        # SYNTHETIC REPORT INJECTION
        # If no stored DailyBusinessReport rows exist for this period but the
        # live-computed summary has meaningful data, build a synthetic row so
        # the Flutter UI is never blank when real transactions exist.
        # ─────────────────────────────────────────────────────────────────────
        if not reports_data and (
            agg_gross > 0
            or total_orders_count > 0
            or stock_requests_qs.count() > 0
            or leads_qs.count() > 0
            or prod_units > 0
        ):
            label = f"{start_date} to {end_date}" if start_date != end_date else str(start_date)
            synthetic_entry = {
                'id': None,
                'report_date': str(start_date),
                'report_period_label': label,
                # Revenue & P&L
                'gross_revenue': float(agg_gross),
                'total_revenue': float(agg_gross),
                'direct_company_revenue': float(direct_rev),
                'franchise_revenue': float(dealer_rev),
                'cogs': float(agg_cogs),
                'gross_profit': float(gross_profit),
                'total_operating_expenses': float(total_exp),
                'net_profit_or_loss': float(agg_net),
                # Collections
                'total_collected': float(total_collected),
                'cash_collected': float(cash_collected),
                'online_collected': float(online_collected),
                'pending_verification_amount': float(pending_verif_amt),
                'outstanding_receivables': float(total_outstanding),
                # Operations
                'total_units_produced': int(prod_units),
                'total_units_dispatched': int(dispatch_units),
                'central_stock_units': int(central_stock),
                'franchise_stock_units': int(franchise_stock),
                # Orders
                'total_orders': total_orders_count,
                'orders_placed': orders_placed_count,
                'orders_approved': orders_approved_count,
                'orders_preparing': orders_preparing_count,
                'orders_dispatched': orders_dispatched_count,
                'orders_delivered': orders_delivered_count,
                'orders_cancelled': orders_cancelled_count,
                # CRM
                'franchise_requests_count': stock_requests_qs.count(),
                'new_leads_count': leads_qs.count(),
                'converted_leads_count': leads_qs.filter(
                    status__in=['CONVERTED', 'FRANCHISE_CONFIRMED', 'converted', 'franchise_confirmed']
                ).count(),
                # Products
                'quantity_sold': summary_data['quantity_sold'],
                'product_wise': product_wise_list,
                # Meta
                'is_synthetic': True,
                'is_finalized': False,
            }
            reports_data = [synthetic_entry]

        return Response({
            'success': True,
            'period': period or 'custom',
            'start_date': str(start_date),
            'end_date': str(end_date),
            'summary': summary_data,
            'sales_report': {
                'total_orders': total_orders_count,
                'delivered_orders': orders_delivered_count,
                'cancelled_orders': orders_cancelled_count,
                'quantity_sold': summary_data['quantity_sold'],
                'revenue': float(agg_gross),
                'product_wise': product_wise_list,
                'franchise_wise': franchise_wise_list,
            },
            'payment_report': {
                'total_collected': float(total_collected),
                'cash_collected': float(cash_collected),
                'online_collected': float(online_collected),
                'pending_verification_amount': float(pending_verif_amt),
                'pending_verification_count': pending_verif_cnt,
                'confirmed_count': confirmed_cnt,
                'rejected_count': rejected_cnt,
                'outstanding': float(total_outstanding),
            },
            'inventory_report': {
                'central_stock': int(central_stock),
                'franchise_stock': int(franchise_stock),
                'produced_quantity': int(prod_units),
                'dispatched_quantity': int(dispatch_units),
                'sold_quantity': summary_data['quantity_sold'],
            },
            'production_report': {
                'batches_count': prod_batches.count(),
                'quantity_produced': int(prod_units),
                'production_cost': float(prod_cost),
            },
            'product_wise': product_wise_list,
            'monthly_sales': monthly_sales_list,
            'customer_activity': customer_orders,
            'franchise_activity': franchise_activity,
            'lead_activity': lead_activity,
            'reports': reports_data,
            'data': reports_data,
        })


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
        has_unacknowledged = any(a.get('can_popup', False) for a in alerts)
        return Response({
            'success': True,
            'count': len(alerts),
            'has_unacknowledged_popup': has_unacknowledged,
            'alerts': alerts,
        }, status=status.HTTP_200_OK)


class PendingStockExpiryAlertActionView(APIView):
    """
    Handles user actions on stock alerts:
    - ACKNOWLEDGE / MARK_REVIEWED: Persists state in PostgreSQL so popup never annoys the user again.
    - SNOOZE: Postpones alert popup for X days.
    - RESOLVE / STOCK_CLEARED: Strictly verifies in PostgreSQL that stock was legitimately cleared.
    """
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        user = request.user
        role = getattr(getattr(user, 'profile', None), 'role', '')
        if not user.is_superuser and role not in ['super_admin', 'admin']:
            return Response({'success': False, 'message': 'Forbidden: Admin access required.'}, status=status.HTTP_403_FORBIDDEN)

        alert_id = request.data.get('alert_id') or request.data.get('id')
        alert_key = request.data.get('alert_key')
        action = str(request.data.get('action', '')).strip().upper()

        from .models import StockAlertRecord
        rec = None
        if alert_id:
            rec = StockAlertRecord.objects.filter(id=alert_id).first()
        if not rec and alert_key:
            rec = StockAlertRecord.objects.filter(alert_key=alert_key).first()

        if not rec:
            return Response({'success': False, 'message': 'Alert record not found.'}, status=status.HTTP_404_NOT_FOUND)

        from django.utils import timezone
        from datetime import timedelta

        if action in ['ACKNOWLEDGE', 'MARK_REVIEWED', 'REVIEWED']:
            rec.status = 'ACKNOWLEDGED'
            rec.acknowledged_by = request.user
            rec.acknowledged_at = timezone.now()
            rec.save(update_fields=['status', 'acknowledged_by', 'acknowledged_at', 'updated_at'])
            return Response({
                'success': True,
                'message': f'Alert for batch {rec.batch_number} marked as reviewed / acknowledged.',
                'status': rec.status,
                'alert': {'id': rec.id, 'status': rec.status, 'batch_number': rec.batch_number},
            })

        elif action in ['SNOOZE', 'REMIND_LATER']:
            days = int(request.data.get('days', 3))
            rec.status = 'SNOOZED'
            rec.snoozed_until = timezone.now() + timedelta(days=days)
            rec.save(update_fields=['status', 'snoozed_until', 'updated_at'])
            return Response({
                'success': True,
                'message': f'Alert snoozed for {days} days.',
                'status': rec.status,
                'alert': {'id': rec.id, 'status': rec.status, 'batch_number': rec.batch_number},
            })

        elif action in ['RESOLVE', 'CHECK_RESOLVED', 'STOCK_CLEARED']:
            # Strictly verify physical stock in PostgreSQL: Never allow false zeroing of pending stock
            pending = 0
            if rec.source_type == 'DEALER_STOCK_REQUEST' and rec.source_id:
                from .models import DealerStockRequestAllocation
                alloc = DealerStockRequestAllocation.objects.filter(id=rec.source_id).first()
                if alloc:
                    pending = max(0, alloc.allocated_quantity - alloc.received_quantity - alloc.damaged_quantity)
            elif rec.source_type == 'CUSTOMER_ORDER' and rec.source_id:
                from orders.models import OrderItemBatchReservation
                res = OrderItemBatchReservation.objects.filter(id=rec.source_id).first()
                if res:
                    pending = max(0, res.reserved_quantity - res.consumed_quantity - res.released_quantity)

            if pending > 0:
                return Response({
                    'success': False,
                    'error': 'STOCK_STILL_PENDING',
                    'pending_quantity': pending,
                    'message': f"Cannot mark stock cleared: {pending:,} units are still pending in the database. Please record customer collection, transfer, or stock adjustment first."
                }, status=status.HTTP_400_BAD_REQUEST)

            rec.status = 'RESOLVED'
            rec.resolved_at = timezone.now()
            rec.pending_quantity = 0
            rec.resolution_notes = request.data.get('notes', 'Stock verified physically cleared via inventory records.')
            rec.save(update_fields=['status', 'resolved_at', 'pending_quantity', 'resolution_notes', 'updated_at'])
            return Response({
                'success': True,
                'message': f'Stock for batch {rec.batch_number} verified as completely cleared and resolved.',
                'status': rec.status,
            })

        return Response({'success': False, 'message': f'Unsupported action: {action}'}, status=status.HTTP_400_BAD_REQUEST)




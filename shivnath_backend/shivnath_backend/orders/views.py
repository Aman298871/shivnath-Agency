from django.shortcuts import get_object_or_404
from django.db.models import Q, Sum, F
from django.db import transaction

from rest_framework import status
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.permissions import AllowAny, IsAuthenticated
from accounts.permissions import IsAdminRole, IsApprovedFranchise, IsAdminOrApprovedFranchise

from .models import Order, OrderItem
from .serializers import OrderSerializer
from products.models import Product


# =========================================================
# ORDER LIST + CREATE
# =========================================================

class OrderListCreateView(APIView):
    permission_classes = [AllowAny]

    def get(self, request):
        user = request.user if (request.user and request.user.is_authenticated) else None

        if not user:
            phone = request.query_params.get('phone', '').strip()
            if phone:
                orders = Order.objects.filter(
                    Q(created_by__profile__phone=phone)
                    | Q(created_by__username=phone)
                    | Q(franchise_name__icontains=phone)
                ).prefetch_related('items')
            else:
                orders = Order.objects.prefetch_related('items').all()
        else:
            profile = getattr(user, 'profile', None)
            role = profile.role if profile else 'customer'
            if user.is_superuser or role == 'admin' or user.is_staff:
                orders = Order.objects.select_related('created_by').prefetch_related('items').all()
            elif role == 'franchise':
                business_name = getattr(getattr(user, 'franchise_profile', None), 'business_name', '')
                orders = Order.objects.filter(
                    Q(created_by=user)
                    | (Q(franchise_name__iexact=business_name) if business_name else Q())
                    | Q(franchise_name__icontains=user.email)
                ).prefetch_related('items').distinct()
            else:
                orders = Order.objects.filter(
                    Q(created_by=user)
                    | Q(created_by__isnull=True)
                ).prefetch_related('items')

        search = request.query_params.get('search', '').strip()
        if search:
            orders = orders.filter(
                Q(franchise_name__icontains=search)
                | Q(city__icontains=search)
                | Q(id__icontains=search)
            )

        order_status = request.query_params.get('status', '').strip()
        if order_status:
            orders = orders.filter(status=order_status)

        serializer = OrderSerializer(orders, many=True)

        return Response(
            {
                'success': True,
                'count': orders.count(),
                'orders': serializer.data,
            },
            status=status.HTTP_200_OK,
        )

    def post(self, request):
        creator = request.user if (request.user and request.user.is_authenticated) else None

        raw_items = request.data.get('order_items') or request.data.get('items_list') or []
        if not raw_items and isinstance(request.data.get('items'), list):
            raw_items = request.data.get('items')

        items_count = request.data.get('items_count') or request.data.get('items', 0)
        product_id = request.data.get('product_id')

        # If frontend sent items list or single product id, validate inventory atomically
        with transaction.atomic():
            validated_order_items = []
            
            if isinstance(raw_items, list) and len(raw_items) > 0:
                for it in raw_items:
                    p_id = it.get('product_id') or it.get('product') or it.get('id')
                    qty = int(it.get('quantity', 1))
                    if p_id:
                        try:
                            prod = Product.objects.select_for_update().get(id=p_id)
                            if prod.stock < qty:
                                return Response(
                                    {
                                        'success': False,
                                        'message': f"Only {prod.stock} units are currently available for {prod.name}.",
                                        'available_stock': prod.stock,
                                        'product_id': prod.id,
                                    },
                                    status=status.HTTP_400_BAD_REQUEST,
                                )
                            validated_order_items.append((prod, qty, it.get('price') or prod.price))
                        except Product.DoesNotExist:
                            pass
            elif product_id:
                try:
                    qty = int(items_count or 1)
                    prod = Product.objects.select_for_update().get(id=product_id)
                    if prod.stock < qty:
                        return Response(
                            {
                                'success': False,
                                'message': f"Only {prod.stock} units are currently available for {prod.name}.",
                                'available_stock': prod.stock,
                                'product_id': prod.id,
                            },
                            status=status.HTTP_400_BAD_REQUEST,
                        )
                    validated_order_items.append((prod, qty, prod.price))
                except Product.DoesNotExist:
                    pass

            # Prepare data for OrderSerializer
            order_data = request.data.copy()
            if not order_data.get('franchise_name'):
                order_data['franchise_name'] = (
                    order_data.get('franchise')
                    or order_data.get('customer_name')
                    or (creator.get_full_name() if creator else None)
                    or (creator.username if creator else 'Customer Order')
                )

            if not order_data.get('city'):
                user_city = getattr(getattr(creator, 'profile', None), 'city', '') if creator else ''
                order_data['city'] = user_city or order_data.get('delivery_city') or 'Raipur'

            calc_amount = sum(float(p) * q for _, q, p in validated_order_items)
            calc_count = sum(q for _, q, _ in validated_order_items)

            if not order_data.get('amount') and calc_amount > 0:
                order_data['amount'] = calc_amount

            if not order_data.get('items_count') and calc_count > 0:
                order_data['items_count'] = calc_count
            elif 'items' in order_data and not isinstance(order_data['items'], int) and not order_data.get('items_count'):
                order_data['items_count'] = calc_count if calc_count > 0 else 1

            if 'payment' in order_data and not order_data.get('payment_status'):
                order_data['payment_status'] = 'pending' if str(order_data.get('payment')).lower() == 'pending' else 'paid'

            serializer = OrderSerializer(data=order_data)
            if not serializer.is_valid():
                return Response(
                    {
                        'success': False,
                        'errors': serializer.errors,
                    },
                    status=status.HTTP_400_BAD_REQUEST,
                )

            order = serializer.save(created_by=creator)

            # Deduct stock and create OrderItems
            for prod, qty, price in validated_order_items:
                prod.stock -= qty
                prod.save(update_fields=['stock'])
                OrderItem.objects.create(
                    order=order,
                    product=prod,
                    product_name=prod.name,
                    size=prod.size,
                    quantity=qty,
                    unit_price=price,
                    total_price=float(price) * qty,
                )

            # Create notification
            try:
                from accounts.models import AdminNotification
                AdminNotification.objects.create(
                    title='New Order Placed',
                    message=f'Order #{order.order_code} for ₹{order.amount} placed by {order.franchise_name} ({order.city}).',
                    notification_type='order_placed',
                    reference_id=order.id,
                )
            except Exception:
                pass

            return Response(
                {
                    'success': True,
                    'message': 'Order created successfully.',
                    'order': OrderSerializer(order).data,
                },
                status=status.HTTP_201_CREATED,
            )


# =========================================================
# ORDER DETAIL + UPDATE + DELETE
# =========================================================

class OrderDetailView(APIView):
    permission_classes = [AllowAny]

    def get(self, request, pk):
        order = get_object_or_404(Order.objects.prefetch_related('items'), pk=pk)
        return Response(
            {
                'success': True,
                'order': OrderSerializer(order).data,
            }
        )

    def put(self, request, pk):
        return self._update(request, pk, partial=False)

    def patch(self, request, pk):
        return self._update(request, pk, partial=True)

    def _update(self, request, pk, partial):
        order = get_object_or_404(Order, pk=pk)

        old_status = order.status
        serializer = OrderSerializer(
            order,
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

        with transaction.atomic():
            updated_order = serializer.save()
            new_status = updated_order.status

            # If cancelled now and wasn't cancelled before, restore stock
            if new_status == 'cancelled' and old_status != 'cancelled':
                for item in updated_order.items.all():
                    if item.product:
                        Product.objects.filter(id=item.product.id).update(
                            stock=F('stock') + item.quantity
                        )
            # If was cancelled before and now un-cancelled/re-opened, re-deduct stock
            elif old_status == 'cancelled' and new_status != 'cancelled':
                for item in updated_order.items.all():
                    if item.product:
                        Product.objects.filter(id=item.product.id).update(
                            stock=F('stock') - item.quantity
                        )

        return Response(
            {
                'success': True,
                'message': 'Order updated successfully.',
                'order': OrderSerializer(updated_order).data,
            }
        )

    def delete(self, request, pk):
        order = get_object_or_404(Order, pk=pk)
        order_code = order.order_code

        with transaction.atomic():
            # If not delivered or cancelled, restore stock
            if order.status not in ['delivered', 'cancelled']:
                for item in order.items.all():
                    if item.product:
                        Product.objects.filter(id=item.product.id).update(
                            stock=F('stock') + item.quantity
                        )
            order.delete()

        return Response(
            {
                'success': True,
                'message': f'{order_code} deleted successfully.',
            }
        )


# =========================================================
# ORDER STATUS UPDATE (dedicated endpoint, used by dialog)
# =========================================================

class OrderStatusUpdateView(APIView):
    permission_classes = [IsAdminRole]

    def patch(self, request, pk):
        order = get_object_or_404(Order, pk=pk)
        new_status = request.data.get('status', '').strip().lower()

        valid_statuses = dict(Order.STATUS_CHOICES).keys()
        if new_status not in valid_statuses:
            return Response(
                {
                    'success': False,
                    'message': 'Invalid order status.',
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        old_status = order.status
        with transaction.atomic():
            order.status = new_status
            order.save(update_fields=['status', 'updated_at'])

            # Restore stock if cancelled
            if new_status == 'cancelled' and old_status != 'cancelled':
                for item in order.items.all():
                    if item.product:
                        Product.objects.filter(id=item.product.id).update(
                            stock=F('stock') + item.quantity
                        )
            # Re-deduct stock if reactivated from cancelled
            elif old_status == 'cancelled' and new_status != 'cancelled':
                for item in order.items.all():
                    if item.product:
                        Product.objects.filter(id=item.product.id).update(
                            stock=F('stock') - item.quantity
                        )

        return Response(
            {
                'success': True,
                'message': f'{order.order_code} status changed successfully.',
                'order': OrderSerializer(order).data,
            }
        )


# =========================================================
# ORDER STATS
# =========================================================

class OrderStatsView(APIView):
    permission_classes = [IsAdminRole]

    def get(self, request):
        orders = Order.objects.all()
        total_orders = orders.count()
        approval_pending = orders.filter(status='plant_approval').count()
        in_dispatch = orders.filter(status='dispatch').count()
        order_value = orders.aggregate(total=Sum('amount'))['total'] or 0

        return Response(
            {
                'success': True,
                'stats': {
                    'total_orders': total_orders,
                    'approval_pending': approval_pending,
                    'in_dispatch': in_dispatch,
                    'order_value': float(order_value),
                },
            }
        )
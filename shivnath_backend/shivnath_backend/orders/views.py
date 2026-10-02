from django.shortcuts import get_object_or_404
from django.db.models import Q, Sum, F
from django.db import transaction

from rest_framework import status
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.permissions import AllowAny, IsAuthenticated
from accounts.permissions import IsAdminRole, IsApprovedFranchise, IsAdminOrApprovedFranchise

from .models import Order, OrderItem, OrderStatusHistory
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
            if user.is_superuser or role in ['admin', 'super_admin'] or user.is_staff or role == 'sales_executive':
                from accounts.services import apply_data_scope
                orders = Order.objects.select_related('created_by', 'serving_franchise').prefetch_related('items').all()
                orders = apply_data_scope(user, orders, 'Order')
            elif role == 'franchise':
                fp = getattr(user, 'franchise_profile', None)
                if not fp:
                    from accounts.models import FranchiseProfile
                    fp = FranchiseProfile.objects.filter(user=user).first()
                if fp:
                    orders = Order.objects.filter(
                        Q(serving_franchise=fp)
                        | Q(registered_franchise=fp)
                        | Q(created_by=user)
                    ).prefetch_related('items').distinct()
                else:
                    orders = Order.objects.none()
            else:
                phone = getattr(getattr(user, 'profile', None), 'phone', '')
                cond = Q(created_by=user)
                if phone:
                    cond |= Q(created_by__profile__phone=phone) | Q(created_by__username=phone)
                orders = Order.objects.filter(cond).prefetch_related('items').distinct()

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

        orders = orders.order_by('-created_at')

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

            serving_franchise = None
            registered_franchise = None
            zone = None

            creator_fp = getattr(creator, 'franchise_profile', None) if creator else None
            if not creator_fp and creator:
                from accounts.models import FranchiseProfile
                creator_fp = FranchiseProfile.objects.filter(user=creator).first()

            if creator_fp:
                serving_franchise = creator_fp
                registered_franchise = creator_fp
                order_source = 'FRANCHISE'
                if not zone and getattr(creator_fp, 'zone', None):
                    zone = getattr(creator_fp, 'zone', None)

            if creator:
                rel = getattr(creator, 'customer_relationship', None)
                if rel:
                    registered_franchise = rel.registered_franchise
                    zone = rel.zone

            serving_franchise_id = request.data.get('serving_franchise_id') or request.data.get('serving_franchise')
            order_source_raw = str(request.data.get('order_source', '')).strip().upper()

            if creator_fp:
                # Creator is the franchise itself; ensure FRANCHISE order source and serving franchise
                order_source = 'FRANCHISE'
                serving_franchise = creator_fp
                registered_franchise = creator_fp
            elif order_source_raw == 'DIRECT_COMPANY':
                order_source = 'DIRECT_COMPANY'
                serving_franchise = None
            elif serving_franchise_id:
                from accounts.models import FranchiseProfile
                from accounts.services import resolve_serviceable_franchises
                try:
                    sf = FranchiseProfile.objects.get(id=serving_franchise_id, status='approved')
                    if zone:
                        serv_res = resolve_serviceable_franchises(zone=zone, district=rel.district if rel else None, allow_fallback=True)
                        allowed_ids = {f['id'] for f in serv_res.get('franchises', [])}
                        if allowed_ids and sf.id not in allowed_ids:
                            return Response({
                                'success': False,
                                'message': f'Franchise "{sf.business_name}" is not serviceable for your delivery area ({zone.name}).'
                            }, status=status.HTTP_400_BAD_REQUEST)
                    serving_franchise = sf
                    order_source = 'FRANCHISE'
                except FranchiseProfile.DoesNotExist:
                    return Response({
                        'success': False,
                        'message': 'Selected serving franchise does not exist or is not approved.'
                    }, status=status.HTTP_400_BAD_REQUEST)
            elif zone:
                from accounts.services import resolve_serviceable_franchises
                # Exact zone matching only; no random or fallback franchise assigned
                serv_res = resolve_serviceable_franchises(zone=zone, district=None, allow_fallback=False)
                available = serv_res.get('franchises', [])
                if available:
                    from accounts.models import FranchiseProfile
                    primary_f = next((f for f in available if f.get('is_primary')), available[0])
                    serving_franchise = FranchiseProfile.objects.filter(id=primary_f['id'], status='approved').first()
                    order_source = 'FRANCHISE'
                else:
                    # Case 2: Territory selected + NO eligible franchise available -> automatically route DIRECT_COMPANY
                    order_source = 'DIRECT_COMPANY'
                    serving_franchise = None
            else:
                # Case 3: Customer has NOT selected a territory/location -> automatically route DIRECT_COMPANY
                order_source = 'DIRECT_COMPANY'
                serving_franchise = None

            # Fallback Check: If customer-placed order routed to dealer has insufficient non-expired stock, fallback to DIRECT_COMPANY
            if order_source == 'FRANCHISE' and serving_franchise and not creator_fp:
                from inventory.models import DealerStockBatch
                from datetime import date
                today_chk = date.today()
                has_insufficient_dealer_stock = False
                for prod, req_qty, _ in validated_order_items:
                    dealer_batches = DealerStockBatch.objects.filter(
                        dealer=serving_franchise,
                        product=prod,
                        is_active=True,
                        expiry_date__gt=today_chk
                    )
                    if dealer_batches.exists():
                        avail = sum(b.available_quantity for b in dealer_batches)
                        if avail < req_qty:
                            has_insufficient_dealer_stock = True
                            break
                if has_insufficient_dealer_stock:
                    order_source = 'DIRECT_COMPANY'
                    serving_franchise = None

            # Set authoritative franchise_name display
            resolved_franchise_name = 'Shivnath Agency (Direct)'
            if serving_franchise:
                resolved_franchise_name = serving_franchise.business_name
            elif registered_franchise:
                resolved_franchise_name = registered_franchise.business_name
            elif order_source != 'DIRECT_COMPANY' and order_data.get('franchise'):
                fn = str(order_data.get('franchise', '')).strip()
                cust_n = (creator.get_full_name() if creator else '').strip()
                cust_u = (creator.username if creator else '').strip()
                if fn and fn.lower() != cust_n.lower() and fn.lower() != cust_u.lower():
                    resolved_franchise_name = fn

            order_data['franchise_name'] = resolved_franchise_name

            if not order_data.get('city'):
                user_city = getattr(getattr(creator, 'profile', None), 'city', '') if creator else ''
                order_data['city'] = user_city or order_data.get('delivery_city') or 'Raipur'

            # Capture territory snapshot
            territory_snapshot = ''
            if zone:
                territory_snapshot = zone.name
            elif creator:
                territory_snapshot = getattr(getattr(creator, 'profile', None), 'territory', '') or ''

            delivery_address_val = request.data.get('delivery_address', '') or request.data.get('address', '')

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

            # Dynamic Stock Duration Calculation with Exact Calendar Months & Custom Days
            from datetime import date
            from accounts.services import calculate_stock_end_date, send_order_placed_notifications
            today = date.today()
            duration_choice = str(request.data.get('duration_choice', '1 Month')).strip() or '1 Month'
            custom_days = request.data.get('custom_days') or request.data.get('duration_days')
            expected_end_date = calculate_stock_end_date(today, duration_choice, custom_days=custom_days)
            duration_days = (expected_end_date - today).days

            serializer = OrderSerializer(data=order_data)
            if not serializer.is_valid():
                return Response(
                    {
                        'success': False,
                        'errors': serializer.errors,
                    },
                    status=status.HTTP_400_BAD_REQUEST,
                )

            order = serializer.save(
                created_by=creator,
                serving_franchise=serving_franchise,
                registered_franchise=registered_franchise,
                franchise_name=resolved_franchise_name,
                zone=zone,
                duration_choice=duration_choice,
                duration_days=duration_days,
                expected_end_date=expected_end_date,
                order_source=order_source,
                territory=territory_snapshot,
                delivery_address=delivery_address_val,
            )

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

            # Perform soft FEFO batch reservation if batches exist
            try:
                from inventory.services import reserve_order_stock_fefo_atomic
                reserve_order_stock_fefo_atomic(order)
            except Exception:
                pass

            # Start/Renew Active Stock Cycle with permanent serving franchise association and snapshots
            stock_cycle = None
            if creator:
                from accounts.models import CustomerStockCycle
                # Mark previous active cycles as completed (preserves complete history)
                CustomerStockCycle.objects.filter(customer=creator, service_status='active').update(service_status='completed')

                first_item = order.items.first()
                p_obj = first_item.product if first_item else None
                p_name = first_item.product_name if first_item else (order_data.get('product_name') or 'Water Stock')
                v_size = first_item.size if first_item else ''
                qty = first_item.quantity if first_item else order.items_count

                rel = getattr(creator, 'customer_relationship', None)
                stock_cycle = CustomerStockCycle.objects.create(
                    customer=creator,
                    order=order,
                    product=p_obj,
                    product_name=p_name,
                    variant_size=v_size,
                    quantity=qty,
                    serving_franchise=serving_franchise,
                    registered_franchise=registered_franchise,
                    district=rel.district if rel else None,
                    zone=rel.zone if rel else None,
                    service_area=rel.service_area if rel else None,
                    pincode=rel.pincode if rel else '',
                    start_date=today,
                    duration_choice=duration_choice,
                    duration_days=duration_days,
                    expected_end_date=expected_end_date,
                    service_status='active',
                )
                if rel and serving_franchise:
                    rel.current_serving_franchise = serving_franchise
                    rel.service_status = 'active'
                    rel.save(update_fields=['current_serving_franchise', 'service_status'])
                elif rel:
                    rel.service_status = 'active'
                    rel.save(update_fields=['service_status'])

            # Authoritative GST Invoice generation
            try:
                from billing.services import generate_invoice_for_order
                generate_invoice_for_order(order)
            except Exception:
                pass

            # Targeted Notifications to Actual Serving Franchise and Admin
            try:
                send_order_placed_notifications(order, stock_cycle)
                from accounts.fcm_services import notify_order_created
                notify_order_created(order)
            except Exception:
                pass

            return Response(
                {
                    'success': True,
                    'message': 'Order created successfully.',
                    'id': order.id,
                    'order_id': order.id,
                    'order': OrderSerializer(order).data,
                },
                status=status.HTTP_201_CREATED,
            )


# =========================================================
# CUSTOMER BULK ORDERS VIEW
# =========================================================

class CustomerBulkOrderView(APIView):
    """
    Secure Customer Bulk Orders.
    Server derives District + Zone strictly from customer's profile.
    Server validates that serving_franchise is licensed/assigned to that zone.
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        user = request.user
        role = getattr(getattr(user, 'profile', None), 'role', 'customer')
        from accounts.models import CustomerBulkOrder
        from accounts.serializers import CustomerBulkOrderSerializer

        if role == 'customer':
            orders = CustomerBulkOrder.objects.filter(customer=user).select_related('serving_franchise', 'product')
        elif role == 'franchise':
            fp = getattr(user, 'franchise_profile', None)
            orders = CustomerBulkOrder.objects.filter(serving_franchise=fp).select_related('customer', 'customer__profile', 'product')
        else:
            orders = CustomerBulkOrder.objects.all().select_related('customer', 'customer__profile', 'serving_franchise', 'product')

        serializer = CustomerBulkOrderSerializer(orders, many=True)
        return Response({
            'success': True,
            'count': orders.count(),
            'bulk_orders': serializer.data
        }, status=status.HTTP_200_OK)

    def post(self, request):
        user = request.user
        from accounts.models import CustomerFranchiseRelationship, FranchiseProfile, FranchiseTerritoryAssignment, CustomerBulkOrder, FranchiseNotification, AdminNotification
        from accounts.serializers import CustomerBulkOrderSerializer
        from products.models import Product

        rel = getattr(user, 'customer_relationship', None)
        if not rel or not rel.zone:
            return Response({
                'success': False,
                'message': 'Please complete your service area registration before placing bulk orders.'
            }, status=status.HTTP_400_BAD_REQUEST)

        # Server-authoritative: Derive District and Zone strictly from customer profile!
        derived_district = rel.district.name if rel.district else (user.profile.district or 'Raipur')
        derived_zone_name = rel.zone.name

        serving_franchise_id = request.data.get('serving_franchise_id')
        serving_franchise = None
        if serving_franchise_id:
            from accounts.services import resolve_serviceable_franchises
            try:
                sf = FranchiseProfile.objects.get(id=serving_franchise_id, status='approved')
                # Server validation: must serve customer's territory (exact or configured fallback)
                serv_res = resolve_serviceable_franchises(zone=rel.zone, district=rel.district, allow_fallback=True)
                allowed_ids = {f['id'] for f in serv_res.get('franchises', [])}
                if sf.id not in allowed_ids:
                    return Response({
                        'success': False,
                        'message': f'Franchise "{sf.business_name}" does not serve your zone ({derived_zone_name}).'
                    }, status=status.HTTP_400_BAD_REQUEST)
                serving_franchise = sf
            except FranchiseProfile.DoesNotExist:
                return Response({
                    'success': False,
                    'message': 'Selected serving franchise not found.'
                }, status=status.HTTP_400_BAD_REQUEST)
        else:
            serving_franchise = rel.registered_franchise

        product_id = request.data.get('product_id')
        product = Product.objects.filter(id=product_id).first() if product_id else None
        product_name = str(request.data.get('product_name') or (product.name if product else 'Packaged Drinking Water')).strip()
        variant_size = str(request.data.get('variant_size') or (product.size if product else '')).strip()
        
        try:
            quantity = int(request.data.get('quantity', 1))
        except (ValueError, TypeError):
            quantity = 1

        duration_choice = str(request.data.get('duration_choice', 'One-time supply')).strip()
        required_date_str = request.data.get('required_date')
        from datetime import date
        try:
            required_date = date.fromisoformat(required_date_str) if required_date_str else date.today()
        except (ValueError, TypeError):
            required_date = date.today()

        delivery_address = str(request.data.get('delivery_address') or user.profile.address or 'Standard Delivery Address').strip()
        notes = str(request.data.get('additional_notes') or request.data.get('notes') or '').strip()

        bulk_order = CustomerBulkOrder.objects.create(
            customer=user,
            product=product,
            product_name=product_name,
            variant_size=variant_size,
            quantity=quantity,
            duration_choice=duration_choice,
            required_date=required_date,
            delivery_address=delivery_address,
            district=derived_district,
            zone_name=derived_zone_name,
            serving_franchise=serving_franchise,
            additional_notes=notes,
            status='pending',
        )

        # Dual Notifications
        try:
            cust_name = user.get_full_name() or user.username
            FranchiseNotification.objects.create(
                franchise=serving_franchise,
                title=f'New Bulk Order Request #{bulk_order.id}',
                message=f'Customer {cust_name} has requested a bulk order: {quantity}x {product_name} ({variant_size}) for {required_date}. Delivery: {delivery_address}, {derived_zone_name}.',
                notification_type='bulk_order',
                reference_id=bulk_order.id,
            )
            AdminNotification.objects.create(
                title='New Bulk Order Request',
                message=f'Customer {cust_name} requested bulk order #{bulk_order.id} ({quantity}x {product_name}) with {serving_franchise.business_name} in {derived_zone_name}.',
                notification_type='bulk_order',
                reference_id=bulk_order.id,
            )
        except Exception:
            pass

        return Response({
            'success': True,
            'message': 'Bulk order request submitted successfully.',
            'bulk_order': CustomerBulkOrderSerializer(bulk_order).data,
        }, status=status.HTTP_201_CREATED)



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
        data = request.data.copy() if hasattr(request.data, 'copy') else dict(request.data)

        user = request.user if request.user and request.user.is_authenticated else None
        role = getattr(getattr(user, 'profile', None), 'role', '')
        is_admin = user and (user.is_superuser or user.is_staff or role in ['admin', 'super_admin'])

        # Security rule: Non-admins cannot unilaterally mark payment_status as paid or confirmed
        if not is_admin and 'payment_status' in data:
            requested_payment_status = str(data.get('payment_status', '')).lower()
            if requested_payment_status in ['paid', 'completed', 'confirmed']:
                data['payment_status'] = 'pending_verification'

        old_status = order.status
        serializer = OrderSerializer(
            order,
            data=data,
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

            # If status changed, notify customer & admin
            if new_status != old_status:
                try:
                    from accounts.fcm_services import notify_order_status_update
                    actor_name = request.user.get_full_name() or request.user.username
                    notify_order_status_update(updated_order, new_status, actor_name=actor_name)
                except Exception:
                    pass

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
    permission_classes = [IsAdminOrApprovedFranchise]

    def put(self, request, pk):
        return self.patch(request, pk)

    def patch(self, request, pk):
        order = get_object_or_404(Order, pk=pk)
        user = request.user
        profile = getattr(user, 'profile', None)
        role = profile.role if profile else 'admin'

        # Franchise must only update orders assigned to them
        if role == 'franchise' and not user.is_superuser:
            fp = getattr(user, 'franchise_profile', None)
            if not fp or order.serving_franchise_id != fp.id:
                return Response({
                    'success': False,
                    'message': 'You are not authorized to update this order.'
                }, status=status.HTTP_403_FORBIDDEN)

        new_status = request.data.get('status', '').strip().lower()
        notes = request.data.get('notes', '').strip()

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
            from inventory.services import dispatch_order_atomic, deliver_order_atomic, cancel_order_atomic

            if new_status == 'dispatch':
                dispatch_order_atomic(order, user)
            elif new_status == 'delivered':
                deliver_order_atomic(order, user)
            elif new_status == 'cancelled':
                cancel_order_atomic(order, user)
            else:
                order.status = new_status
                order.save(update_fields=['status', 'updated_at'])

            if new_status in ['invoice_generated', 'plant_approval']:
                try:
                    from billing.services import generate_invoice_for_order
                    generate_invoice_for_order(order)
                except Exception:
                    pass

            # Log status change
            if old_status != new_status:
                OrderStatusHistory.objects.create(
                    order=order,
                    old_status=old_status,
                    new_status=new_status,
                    changed_by=user,
                    notes=notes,
                )

                # Notify customer & admin about status update (franchise updates)
                try:
                    from accounts.models import AdminNotification
                    from accounts.fcm_services import notify_order_status_update
                    changed_by_name = user.get_full_name() or user.username
                    AdminNotification.objects.create(
                        title=f'Order {order.order_code} Status Updated',
                        message=f'{order.order_code} status changed from {old_status} to {new_status} by {changed_by_name}.',
                        notification_type='order_update',
                        reference_id=order.id,
                    )
                    notify_order_status_update(order, new_status, actor_name=changed_by_name)
                except Exception:
                    pass

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
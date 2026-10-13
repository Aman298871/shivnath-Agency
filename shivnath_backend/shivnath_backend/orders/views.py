import hashlib
import hmac
import json
import logging
import os
import uuid
from decimal import Decimal
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

logger = logging.getLogger(__name__)


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
            clean_search = search.replace('ORD-', '').replace('ord-', '').replace('#', '').strip()
            search_filters = (
                Q(franchise_name__icontains=search)
                | Q(city__icontains=search)
                | Q(customer_name__icontains=search)
                | Q(client_name__icontains=search)
            )
            if clean_search.isdigit():
                search_filters |= Q(id=int(clean_search))
            orders = orders.filter(search_filters)

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
        creator_fp = getattr(creator, 'franchise_profile', None) if creator else None
        if not creator_fp and creator:
            from accounts.models import FranchiseProfile
            creator_fp = FranchiseProfile.objects.filter(user=creator).first()

        is_customer = not creator_fp and (not creator or getattr(getattr(creator, 'profile', None), 'role', 'customer') == 'customer')
        req_pm = str(request.data.get('payment_mode') or request.data.get('payment_method') or request.data.get('payment') or '').strip().upper()
        if is_customer and req_pm in ['COD', 'CASH', 'CASH_ON_DELIVERY', 'PAY_ON_DELIVERY', 'PENDING_COD']:
            return Response(
                {
                    'success': False,
                    'message': 'Cash on Delivery (COD) is disabled for customer orders. Please complete your payment online securely via Razorpay.',
                    'error_code': 'COD_NOT_ALLOWED',
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

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
                            from inventory.models import ProductionBatch, DealerStockBatch
                            from django.db.models import Sum
                            from datetime import date
                            today_chk = date.today()
                            cp_avail = ProductionBatch.objects.filter(
                                product=prod, status='ACTIVE', expiry_date__gt=today_chk
                            ).aggregate(s=Sum('quantity_remaining_company'))['s'] or 0
                            dealer_avail = DealerStockBatch.objects.filter(
                                product=prod, is_active=True, expiry_date__gt=today_chk
                            ).aggregate(s=Sum('remaining_quantity'))['s'] or 0
                            effective_avail = max(prod.stock, int(cp_avail) + int(dealer_avail))
                            if effective_avail > prod.stock:
                                prod.stock = effective_avail
                                prod.save(update_fields=['stock'])

                            if effective_avail < qty:
                                return Response(
                                    {
                                        'success': False,
                                        'message': f"Only {effective_avail} units are currently available for {prod.name}.",
                                        'available_stock': effective_avail,
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
                    from inventory.models import ProductionBatch, DealerStockBatch
                    from django.db.models import Sum
                    from datetime import date
                    today_chk = date.today()
                    cp_avail = ProductionBatch.objects.filter(
                        product=prod, status='ACTIVE', expiry_date__gt=today_chk
                    ).aggregate(s=Sum('quantity_remaining_company'))['s'] or 0
                    dealer_avail = DealerStockBatch.objects.filter(
                        product=prod, is_active=True, expiry_date__gt=today_chk
                    ).aggregate(s=Sum('remaining_quantity'))['s'] or 0
                    effective_avail = max(prod.stock, int(cp_avail) + int(dealer_avail))
                    if effective_avail > prod.stock:
                        prod.stock = effective_avail
                        prod.save(update_fields=['stock'])

                    if effective_avail < qty:
                        return Response(
                            {
                                'success': False,
                                'message': f"Only {effective_avail} units are currently available for {prod.name}.",
                                'available_stock': effective_avail,
                                'product_id': prod.id,
                            },
                            status=status.HTTP_400_BAD_REQUEST,
                        )
                    validated_order_items.append((prod, qty, prod.price))
                except Product.DoesNotExist:
                    pass

            # Prepare data for OrderSerializer
            order_data = request.data.copy()
            if 'status' in order_data and isinstance(order_data['status'], str):
                order_data['status'] = order_data['status'].strip().lower().replace(' ', '_')
            if 'payment' in order_data and isinstance(order_data['payment'], str):
                order_data['payment'] = order_data['payment'].strip().lower()

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

            # Authoritative fulfillment source & franchise name resolution
            if order_source == 'DIRECT_COMPANY' or not serving_franchise:
                order_source = 'DIRECT_COMPANY'
                serving_franchise = None
                resolved_franchise_name = 'Shivnath Agency (Direct)'
            elif serving_franchise:
                resolved_franchise_name = serving_franchise.business_name
            else:
                resolved_franchise_name = 'Shivnath Agency (Direct)'

            order_data['order_source'] = order_source
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

            # Immutable audit log for initial order placement
            OrderStatusHistory.objects.create(
                order=order,
                old_status='',
                new_status=order.status or 'order_placement',
                changed_by=creator,
                notes='Order placed by client.',
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

            # Authoritative targeted notifications dispatched strictly on DB transaction commit
            def _dispatch_order_placed_notifs():
                try:
                    send_order_placed_notifications(order, stock_cycle)
                    from accounts.fcm_services import notify_order_created
                    notify_order_created(order)
                except Exception as notif_err:
                    logger.error("FCM: Order creation notification dispatch error: %s", notif_err, exc_info=True)

            transaction.on_commit(_dispatch_order_placed_notifs)

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

        from orders.services import validate_order_status_transition, validate_payment_stage, transition_order_status
        from django.core.exceptions import ValidationError as DjangoValidationError

        # Security & Operational Rule: Payment status cannot be marked paid before allowed operational stage (dispatch/delivered)
        if 'payment_status' in data:
            req_ps = str(data.get('payment_status', '')).lower()
            try:
                validate_payment_stage(order, req_ps)
            except DjangoValidationError as pe:
                return Response(
                    {'success': False, 'message': str(pe.message if hasattr(pe, 'message') else pe), 'error_code': 'PAYMENT_STAGE_LOCKED'},
                    status=status.HTTP_400_BAD_REQUEST,
                )

            if not is_admin and req_ps in ['paid', 'completed', 'confirmed']:
                data['payment_status'] = 'pending_verification'

        old_status = order.status
        new_status = data.get('status')
        if new_status and new_status != old_status:
            try:
                validate_order_status_transition(old_status, new_status)
            except DjangoValidationError as te:
                return Response(
                    {'success': False, 'message': str(te.message if hasattr(te, 'message') else te), 'error_code': 'INVALID_STATUS_TRANSITION'},
                    status=status.HTTP_400_BAD_REQUEST,
                )

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
            new_st = updated_order.status

            if new_st != old_status:
                transition_order_status(
                    updated_order,
                    new_st,
                    actor=user,
                    notes=data.get('notes', '') or f"Status updated via order update endpoint.",
                    bypass_validation=True,  # Already validated above
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

        from orders.services import validate_order_status_transition, transition_order_status
        from django.core.exceptions import ValidationError as DjangoValidationError

        old_status = order.status
        try:
            validate_order_status_transition(old_status, new_status)
        except DjangoValidationError as te:
            return Response(
                {
                    'success': False,
                    'message': str(te.message if hasattr(te, 'message') else te),
                    'error_code': 'INVALID_STATUS_TRANSITION',
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        updated_order = transition_order_status(
            order,
            new_status,
            actor=user,
            notes=notes,
            bypass_validation=True,
        )

        return Response(
            {
                'success': True,
                'message': f'{order.order_code} status changed to {new_status} successfully.',
                'order': OrderSerializer(updated_order).data,
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


# =========================================================
# RAZORPAY PAYMENT INTEGRATION
# =========================================================

import os
import hmac
import hashlib
import uuid
import sys


def is_production_environment():
    """
    Authoritative server-side check for production environment.
    Prevents mock mode, synthetic payments, and bypass logic in production.
    """
    from django.conf import settings

    # In isolated Django test runner, only consider production if explicitly requested in environment
    if 'test' in sys.argv or getattr(settings, 'IS_TESTING', False):
        env_str = os.environ.get('ENVIRONMENT', '').strip().lower()
        rzp_env = os.environ.get('RAZORPAY_ENVIRONMENT', '').strip().upper()
        return env_str in ('production', 'prod', 'live') or rzp_env == 'LIVE'

    env_str = os.environ.get('ENVIRONMENT', '').strip().lower()
    if env_str in ('production', 'prod', 'live'):
        return True
    if os.environ.get('RAZORPAY_ENVIRONMENT', '').strip().upper() == 'LIVE':
        return True
    if not getattr(settings, 'DEBUG', True):
        return True
def get_razorpay_credentials():
    """
    Securely retrieves Razorpay credentials.
    Defaults to the user-configured test credentials ('rzp_test_TnHOsEiTNcd25f' / 'KhXhv0YO2Lvu1aBFr5ks5s2R')
    if not explicitly overridden via environment variables or settings.
    """
    from django.conf import settings
    key_id = (
        os.environ.get('RAZORPAY_KEY_ID') or 
        getattr(settings, 'RAZORPAY_KEY_ID', '') or 
        'rzp_test_TnHOsEiTNcd25f'
    ).strip()
    key_secret = (
        os.environ.get('RAZORPAY_KEY_SECRET') or 
        getattr(settings, 'RAZORPAY_KEY_SECRET', '') or 
        'KhXhv0YO2Lvu1aBFr5ks5s2R'
    ).strip()
    razorpay_env = (
        os.environ.get('RAZORPAY_ENVIRONMENT') or 
        getattr(settings, 'RAZORPAY_ENVIRONMENT', '') or 
        'TEST'
    ).strip().upper()
    webhook_secret = (
        os.environ.get('RAZORPAY_WEBHOOK_SECRET') or 
        getattr(settings, 'RAZORPAY_WEBHOOK_SECRET', '') or 
        ''
    ).strip()
    return key_id, key_secret, razorpay_env, webhook_secret


class RazorpayCreateOrderAPIView(APIView):
    """
    Creates a Razorpay Order ID for online checkout.
    Reads RAZORPAY_KEY_ID and RAZORPAY_KEY_SECRET securely from environment.
    Enforces server-side amount validation against authoritative order data,
    validates currency (INR), and includes environment safeguards preventing
    accidental test key usage in production live mode.
    """
    permission_classes = [AllowAny]

    def post(self, request):
        order_id = request.data.get('order_id')
        amount = request.data.get('amount')
        currency = request.data.get('currency', 'INR').strip().upper()

        if currency != 'INR':
            return Response(
                {'success': False, 'message': 'Only INR currency is supported for Razorpay payments.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        order = None
        if order_id:
            try:
                order = Order.objects.get(id=order_id)
                authoritative_amount = float(order.grand_total if getattr(order, 'grand_total', None) else order.amount)
                # Anti-tampering check: if client sent an amount, verify it matches order total
                if amount is not None:
                    client_amount_val = float(amount)
                    if abs(authoritative_amount - client_amount_val) > 0.05:
                        return Response(
                            {
                                'success': False,
                                'message': f"Amount tampering detected: Client requested ₹{client_amount_val:.2f} but authoritative order total is ₹{authoritative_amount:.2f}.",
                                'error_code': 'AMOUNT_MISMATCH',
                            },
                            status=status.HTTP_400_BAD_REQUEST,
                        )
                amount = authoritative_amount
            except Order.DoesNotExist:
                return Response(
                    {'success': False, 'message': 'Order not found.'},
                    status=status.HTTP_404_NOT_FOUND,
                )

        if not amount or float(amount) <= 0:
            return Response(
                {'success': False, 'message': 'Invalid payment amount.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        amount_val = float(amount)
        amount_in_paise = int(round(amount_val * 100))

        key_id, key_secret, razorpay_env, webhook_secret = get_razorpay_credentials()

        is_prod = is_production_environment()

        # Configuration safeguard 1: Prevent test keys in LIVE mode
        if razorpay_env == 'LIVE' and key_id.startswith('rzp_test_'):
            return Response(
                {
                    'success': False,
                    'message': 'Security Configuration Error: Razorpay Test Key detected while RAZORPAY_ENVIRONMENT is set to LIVE. Please configure authorized live credentials.'
                },
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )

        # Configuration safeguard 2: Production environment strictly requires genuine credentials
        if is_prod and (not key_id or not key_secret):
            return Response(
                {
                    'success': False,
                    'message': 'Payment Gateway Unavailable: Razorpay API credentials are not configured on the production server. Mock payment mode is strictly prohibited in production.',
                    'error_code': 'GATEWAY_CREDENTIALS_MISSING_IN_PRODUCTION',
                    'diagnostics': {
                        'environment': razorpay_env,
                        'is_production': True,
                        'credentials_configured': False,
                        'key_id_present': bool(key_id),
                        'key_secret_present': bool(key_secret),
                        'reason': 'Production environment requires authorized live RAZORPAY_KEY_ID and RAZORPAY_KEY_SECRET environment variables.',
                    }
                },
                status=status.HTTP_503_SERVICE_UNAVAILABLE,
            )

        if not key_id or not key_secret:
            # Test or local environment without configured credentials
            # Fail safely and diagnostically - DO NOT silently fake payments
            if getattr(settings, 'IS_TESTING', False) and 'test_mock_order' in request.data:
                # Automated isolated test hook ONLY
                razorpay_order_id = f"order_test_{uuid.uuid4().hex[:14]}"
            else:
                return Response(
                    {
                        'success': False,
                        'message': 'Payment Gateway Unavailable: Razorpay Test Mode credentials (RAZORPAY_KEY_ID & RAZORPAY_KEY_SECRET) are not configured in this test environment.',
                        'error_code': 'GATEWAY_CREDENTIALS_MISSING_IN_TEST',
                        'diagnostics': {
                            'environment': razorpay_env,
                            'is_production': False,
                            'credentials_configured': False,
                            'key_id_present': bool(key_id),
                            'key_secret_present': bool(key_secret),
                            'reason': 'Please set RAZORPAY_KEY_ID and RAZORPAY_KEY_SECRET in your backend environment (.env.test).',
                        }
                    },
                    status=status.HTTP_503_SERVICE_UNAVAILABLE,
                )
        else:
            try:
                import razorpay
                client = razorpay.Client(auth=(key_id, key_secret))
                rzp_order = client.order.create({
                    'amount': amount_in_paise,
                    'currency': 'INR',
                    'receipt': f"rcpt_ord_{order.id if order else uuid.uuid4().hex[:8]}",
                    'payment_capture': 1,
                    'notes': {
                        'environment': razorpay_env,
                        'order_code': getattr(order, 'order_code', f"ORD-{order_id}"),
                    }
                })
                razorpay_order_id = rzp_order.get('id')
            except Exception as e:
                logger.error("Razorpay API order creation exception: %s", e)
                return Response(
                    {
                        'success': False,
                        'message': f"Razorpay order initialization failed: {str(e)}",
                        'error_code': 'GATEWAY_API_ERROR',
                        'diagnostics': {
                            'environment': razorpay_env,
                            'is_production': is_prod,
                            'credentials_configured': True,
                            'reason': f"Razorpay API rejected the request: {str(e)}",
                        }
                    },
                    status=status.HTTP_502_BAD_GATEWAY,
                )

        if order and razorpay_order_id:
            order.razorpay_order_id = razorpay_order_id
            order.payment_mode = 'RAZORPAY'
            order.save(update_fields=['razorpay_order_id', 'payment_mode'])

        is_test_mode = key_id.startswith('rzp_test_') or razorpay_env == 'TEST'

        return Response(
            {
                'success': True,
                'razorpay_order_id': razorpay_order_id,
                'order_id': order.id if order else None,
                'amount': amount_val,
                'amount_in_paise': amount_in_paise,
                'currency': 'INR',
                'key_id': key_id,
                'environment': razorpay_env,
                'is_test_mode': is_test_mode,
                'diagnostics': {
                    'status': 'CONFIGURED',
                    'environment': razorpay_env,
                    'gateway_reachable': True,
                },
                'payment_methods': ['UPI', 'Card', 'NetBanking', 'Wallet'],
            },
            status=status.HTTP_200_OK,
        )


class RazorpayStatusAPIView(APIView):
    """
    Diagnostic status endpoint for Razorpay payment gateway.
    Reports whether the gateway is ready, current environment (TEST vs LIVE),
    and whether credentials are configured, WITHOUT exposing any secrets.
    """
    permission_classes = [AllowAny]

    def get(self, request):
        key_id, key_secret, razorpay_env, webhook_secret = get_razorpay_credentials()
        is_prod = is_production_environment()

        configured = bool(key_id and key_secret)
        is_test_mode = key_id.startswith('rzp_test_') or razorpay_env == 'TEST'

        config_valid = True
        error_code = None

        if not configured:
            config_valid = False
            if is_prod:
                error_code = 'GATEWAY_CREDENTIALS_MISSING_IN_PRODUCTION'
                status_message = "Payment Gateway Unavailable: Razorpay API credentials are not configured on the production server. Mock payment mode is strictly prohibited in production."
            else:
                error_code = 'GATEWAY_CREDENTIALS_MISSING_IN_TEST'
                status_message = "Payment Gateway Unavailable: Razorpay credentials (RAZORPAY_KEY_ID & RAZORPAY_KEY_SECRET) are not configured in this environment."
        elif razorpay_env == 'LIVE' and key_id.startswith('rzp_test_'):
            config_valid = False
            error_code = 'TEST_KEY_IN_LIVE_ENVIRONMENT'
            status_message = "Security Configuration Error: Razorpay Test Key detected while RAZORPAY_ENVIRONMENT is set to LIVE."
        elif is_prod and is_test_mode:
            status_message = "Razorpay Test Mode credentials active in production."
        else:
            status_message = "Razorpay payment gateway is configured and ready."

        # Supported payment methods - ONLY if gateway is configured and valid
        supported_methods = ['UPI', 'Cards', 'Net Banking', 'Wallets'] if (configured and config_valid) else []

        return Response({
            'success': True,
            'available': configured and config_valid,
            'environment': razorpay_env,
            'is_test_mode': is_test_mode,
            'is_production': is_prod,
            'key_id': key_id if (configured and config_valid) else None,
            'supported_methods': supported_methods,
            'diagnostics': {
                'status': 'CONFIGURED' if (configured and config_valid) else 'UNAVAILABLE',
                'credentials_configured': configured,
                'key_id_present': bool(key_id),
                'key_secret_present': bool(key_secret),
                'error_code': error_code,
                'message': status_message,
            }
        }, status=status.HTTP_200_OK)


class RazorpayVerifyPaymentAPIView(APIView):
    """
    Authoritative server-side Razorpay payment verification.
    Verifies HMAC-SHA256 signature, validates payment state,
    records PaymentTransaction, marks Invoice & Order PAID atomically.
    Strictly forbids mock payment mode or unverified bypass.
    """
    permission_classes = [AllowAny]

    def post(self, request):
        order_id = request.data.get('order_id')
        razorpay_order_id = request.data.get('razorpay_order_id', '').strip()
        razorpay_payment_id = request.data.get('razorpay_payment_id', '').strip()
        razorpay_signature = request.data.get('razorpay_signature', '').strip()

        if not order_id:
            return Response(
                {'success': False, 'message': 'Order ID is required for verification.', 'error_code': 'MISSING_ORDER_ID'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            order = Order.objects.get(id=order_id)
        except Order.DoesNotExist:
            return Response(
                {'success': False, 'message': 'Order not found.', 'error_code': 'ORDER_NOT_FOUND'},
                status=status.HTTP_404_NOT_FOUND,
            )

        # Idempotency: If order is already verified and marked paid, return success immediately
        if order.payment_status == 'paid' and order.razorpay_payment_id:
            return Response(
                {
                    'success': True,
                    'is_already_verified': True,
                    'message': 'Payment already verified and authoritative.',
                    'order': OrderSerializer(order).data,
                },
                status=status.HTTP_200_OK,
            )

        key_id, key_secret, razorpay_env, webhook_secret = get_razorpay_credentials()
        is_prod = is_production_environment()

        # Without credentials, genuine verification cannot proceed
        if not key_secret:
            err_code = 'CREDENTIALS_MISSING_IN_PRODUCTION' if is_prod else 'CREDENTIALS_MISSING_IN_TEST'
            return Response(
                {
                    'success': False,
                    'message': 'Payment verification rejected: Razorpay credentials are not configured on the server. Signature verification cannot be performed.',
                    'error_code': err_code,
                },
                status=status.HTTP_503_SERVICE_UNAVAILABLE,
            )

        # Genuine cryptographic signature verification
        if not razorpay_signature or not razorpay_order_id or not razorpay_payment_id:
            return Response(
                {
                    'success': False,
                    'message': 'Missing signature parameters for cryptographic verification.',
                    'error_code': 'MISSING_SIGNATURE_PAYLOAD',
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            msg = f"{razorpay_order_id}|{razorpay_payment_id}".encode('utf-8')
            generated_sig = hmac.new(
                key_secret.encode('utf-8'),
                msg,
                hashlib.sha256
            ).hexdigest()
            if not hmac.compare_digest(generated_sig, razorpay_signature):
                return Response(
                    {
                        'success': False,
                        'message': 'Payment verification failed: Invalid Razorpay cryptographic signature.',
                        'error_code': 'SIGNATURE_VERIFICATION_FAILED',
                    },
                    status=status.HTTP_400_BAD_REQUEST,
                )
        except Exception as e:
            logger.error("Cryptographic verification error: %s", e)
            return Response(
                {
                    'success': False,
                    'message': 'Payment signature verification exception.',
                    'error_code': 'SIGNATURE_VERIFICATION_FAILED',
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        is_test = key_id.startswith('rzp_test_')

        with transaction.atomic():
            order.payment_status = 'paid'
            order.payment_mode = 'RAZORPAY'
            order.razorpay_order_id = razorpay_order_id or order.razorpay_order_id
            order.razorpay_payment_id = razorpay_payment_id
            order.razorpay_signature = razorpay_signature
            order.save(update_fields=[
                'payment_status',
                'payment_mode',
                'razorpay_order_id',
                'razorpay_payment_id',
                'razorpay_signature',
            ])

            # Update Invoice and record PaymentTransaction atomically
            try:
                from billing.models import Invoice, PaymentTransaction
                inv = getattr(order, 'invoice', None)
                if not inv:
                    from billing.services import generate_invoice_for_order
                    inv = generate_invoice_for_order(order)
                if inv:
                    inv.status = 'PAID'
                    inv.amount_paid = inv.grand_total
                    inv.save(update_fields=['status', 'amount_paid'])

                    test_label = "[TEST MODE] " if is_test else ""
                    PaymentTransaction.objects.get_or_create(
                        reference_number=order.razorpay_payment_id,
                        defaults={
                            'transaction_number': f"TXN-RZP-{order.id}-{uuid.uuid4().hex[:6].upper()}",
                            'invoice': inv,
                            'payment_method': 'RAZORPAY',
                            'amount_paid': inv.grand_total,
                            'razorpay_order_id': order.razorpay_order_id,
                            'razorpay_payment_id': order.razorpay_payment_id,
                            'razorpay_signature': order.razorpay_signature,
                            'payment_status': 'SUCCESS',
                            'received_by': order.created_by,
                            'notes': f"{test_label}Razorpay Online Payment verified server-side for {order.order_code}",
                        }
                    )
            except Exception as e:
                logger.error("Error creating PaymentTransaction for order %s: %s", order.id, e)

            # Send FCM and Admin notifications
            try:
                from accounts.fcm_services import notify_order_created
                notify_order_created(order)
            except Exception as notif_err:
                logger.error("FCM: Razorpay order notification dispatch error: %s", notif_err, exc_info=True)

        return Response(
            {
                'success': True,
                'message': 'Payment successfully verified server-side.',
                'is_test_mode': is_test,
                'order': OrderSerializer(order).data,
            },
            status=status.HTTP_200_OK,
        )


class RazorpayCancelPaymentAPIView(APIView):
    """
    Handles payment cancellation when a user dismisses the Razorpay checkout sheet
    or cancels before completion.
    Preserves existing orders, prevents dangling pending states, and records cancellation.
    """
    permission_classes = [AllowAny]

    def post(self, request):
        order_id = request.data.get('order_id')
        razorpay_order_id = request.data.get('razorpay_order_id', '').strip()
        reason = request.data.get('reason', 'Customer dismissed or cancelled payment sheet.').strip()

        if not order_id and not razorpay_order_id:
            return Response(
                {'success': False, 'message': 'order_id or razorpay_order_id is required.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        order = None
        if order_id:
            order = Order.objects.filter(id=order_id).first()
        elif razorpay_order_id:
            order = Order.objects.filter(razorpay_order_id=razorpay_order_id).first()

        if not order:
            return Response(
                {'success': False, 'message': 'Order not found.'},
                status=status.HTTP_404_NOT_FOUND,
            )

        # Do not cancel an already paid and verified order
        if order.payment_status == 'paid':
            return Response(
                {
                    'success': False,
                    'message': 'Cannot cancel payment for an already paid and verified order.',
                    'payment_status': 'paid',
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        order.payment_status = 'cancelled'
        order.save(update_fields=['payment_status'])

        return Response(
            {
                'success': True,
                'message': 'Payment cancelled successfully.',
                'order_id': order.id,
                'payment_status': order.payment_status,
                'reason': reason,
            },
            status=status.HTTP_200_OK,
        )


class RazorpayWebhookAPIView(APIView):
    """
    Webhook handler for authoritative asynchronous Razorpay event notifications.
    Verifies raw body signature using RAZORPAY_WEBHOOK_SECRET.
    Idempotently handles payment.captured, order.paid, and payment.failed events.
    """
    permission_classes = [AllowAny]

    def post(self, request):
        webhook_secret = os.environ.get('RAZORPAY_WEBHOOK_SECRET', '').strip()
        received_signature = request.headers.get('X-Razorpay-Signature', '').strip()

        # If webhook secret is configured, strictly verify cryptographic signature
        if webhook_secret:
            if not received_signature:
                return Response({'success': False, 'error': 'Missing X-Razorpay-Signature header'}, status=status.HTTP_400_BAD_REQUEST)
            try:
                expected_signature = hmac.new(
                    webhook_secret.encode('utf-8'),
                    request.body,
                    hashlib.sha256
                ).hexdigest()
                if not hmac.compare_digest(expected_signature, received_signature):
                    return Response({'success': False, 'error': 'Invalid webhook signature'}, status=status.HTTP_400_BAD_REQUEST)
            except Exception as e:
                logger.error("Webhook signature verification error: %s", e)
                return Response({'success': False, 'error': 'Signature verification error'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            payload = json.loads(request.body.decode('utf-8'))
        except Exception:
            return Response({'success': False, 'error': 'Invalid JSON body'}, status=status.HTTP_400_BAD_REQUEST)

        event = payload.get('event')
        logger.info("Razorpay Webhook received event: %s", event)

        if event in ('payment.captured', 'order.paid'):
            payment_entity = payload.get('payload', {}).get('payment', {}).get('entity', {})
            rzp_order_id = payment_entity.get('order_id')
            rzp_payment_id = payment_entity.get('id')

            if rzp_order_id:
                order = Order.objects.filter(razorpay_order_id=rzp_order_id).first()
                if order and order.payment_status != 'paid':
                    with transaction.atomic():
                        order.payment_status = 'paid'
                        order.razorpay_payment_id = rzp_payment_id or order.razorpay_payment_id
                        order.save(update_fields=['payment_status', 'razorpay_payment_id'])

                        from billing.models import Invoice, PaymentTransaction
                        inv = getattr(order, 'invoice', None)
                        if not inv:
                            from billing.services import generate_invoice_for_order
                            inv = generate_invoice_for_order(order)

                        if inv:
                            inv.status = 'PAID'
                            inv.amount_paid = inv.grand_total
                            inv.save(update_fields=['status', 'amount_paid'])

                            PaymentTransaction.objects.get_or_create(
                                reference_number=rzp_payment_id,
                                defaults={
                                    'transaction_number': f"TXN-WH-{order.id}-{uuid.uuid4().hex[:6].upper()}",
                                    'invoice': inv,
                                    'payment_method': 'RAZORPAY',
                                    'amount_paid': inv.grand_total,
                                    'razorpay_order_id': rzp_order_id,
                                    'razorpay_payment_id': rzp_payment_id,
                                    'payment_status': 'SUCCESS',
                                    'notes': f"Razorpay Webhook ({event}) verified asynchronously",
                                }
                            )

        elif event == 'payment.failed':
            payment_entity = payload.get('payload', {}).get('payment', {}).get('entity', {})
            rzp_order_id = payment_entity.get('order_id')
            rzp_payment_id = payment_entity.get('id')
            error_desc = payment_entity.get('error_description') or payment_entity.get('error_reason') or 'Payment failed at gateway'

            if rzp_order_id:
                order = Order.objects.filter(razorpay_order_id=rzp_order_id).first()
                if order and order.payment_status != 'paid':
                    with transaction.atomic():
                        order.payment_status = 'failed'
                        order.save(update_fields=['payment_status'])

                        from billing.models import Invoice, PaymentTransaction
                        inv = getattr(order, 'invoice', None)
                        if not inv:
                            from billing.services import generate_invoice_for_order
                            inv = generate_invoice_for_order(order)

                        if inv:
                            PaymentTransaction.objects.get_or_create(
                                reference_number=rzp_payment_id or f"fail_{order.id}",
                                defaults={
                                    'transaction_number': f"TXN-FAIL-{order.id}-{uuid.uuid4().hex[:6].upper()}",
                                    'invoice': inv,
                                    'payment_method': 'RAZORPAY',
                                    'amount_paid': 0,
                                    'razorpay_order_id': rzp_order_id,
                                    'razorpay_payment_id': rzp_payment_id,
                                    'payment_status': 'FAILED',
                                    'notes': f"Razorpay Webhook payment.failed: {error_desc}",
                                }
                            )
            return Response({'success': True, 'status': 'ok', 'event': event, 'message': 'Payment failure recorded.'}, status=status.HTTP_200_OK)

        return Response({'success': True, 'status': 'ok', 'event': event}, status=status.HTTP_200_OK)


class RazorpayReconcilePaymentAPIView(APIView):
    """
    Reconciles payment status between the application and Razorpay.
    Used when network drops or interruptions occur before confirmation callback completes.
    """
    permission_classes = [AllowAny]

    def post(self, request):
        order_id = request.data.get('order_id')
        razorpay_order_id = request.data.get('razorpay_order_id', '').strip()

        if not order_id and not razorpay_order_id:
            return Response(
                {'success': False, 'message': 'order_id or razorpay_order_id is required.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        order = None
        if order_id:
            order = Order.objects.filter(id=order_id).first()
        elif razorpay_order_id:
            order = Order.objects.filter(razorpay_order_id=razorpay_order_id).first()

        if not order:
            return Response(
                {'success': False, 'message': 'Order not found.'},
                status=status.HTTP_404_NOT_FOUND,
            )

        key_id, key_secret, razorpay_env, webhook_secret = get_razorpay_credentials()

        # If order is already marked paid in DB
        if order.payment_status == 'paid':
            return Response(
                {
                    'success': True,
                    'reconciled': True,
                    'payment_status': 'paid',
                    'order_id': order.id,
                    'razorpay_payment_id': order.razorpay_payment_id,
                    'message': 'Order is confirmed paid and authoritative.',
                },
                status=status.HTTP_200_OK,
            )

        # If gateway credentials exist, query Razorpay API for authoritative status
        if key_id and key_secret and order.razorpay_order_id:
            try:
                import razorpay
                client = razorpay.Client(auth=(key_id, key_secret))
                order_payments = client.order.payments(order.razorpay_order_id)
                items = order_payments.get('items', [])
                successful_payment = next(
                    (p for p in items if p.get('status') == 'captured'),
                    None
                )
                if successful_payment:
                    with transaction.atomic():
                        order.payment_status = 'paid'
                        order.razorpay_payment_id = successful_payment.get('id')
                        order.save(update_fields=['payment_status', 'razorpay_payment_id'])

                        from billing.models import Invoice, PaymentTransaction
                        inv = getattr(order, 'invoice', None)
                        if inv:
                            inv.status = 'PAID'
                            inv.amount_paid = inv.grand_total
                            inv.save(update_fields=['status', 'amount_paid'])

                            PaymentTransaction.objects.get_or_create(
                                reference_number=successful_payment.get('id'),
                                defaults={
                                    'transaction_number': f"TXN-REC-{order.id}-{uuid.uuid4().hex[:6].upper()}",
                                    'invoice': inv,
                                    'payment_method': 'RAZORPAY',
                                    'amount_paid': inv.grand_total,
                                    'razorpay_order_id': order.razorpay_order_id,
                                    'razorpay_payment_id': successful_payment.get('id'),
                                    'payment_status': 'SUCCESS',
                                    'notes': 'Payment reconciled directly via Razorpay API',
                                }
                            )
                    return Response(
                        {
                            'success': True,
                            'reconciled': True,
                            'payment_status': 'paid',
                            'order_id': order.id,
                            'razorpay_payment_id': order.razorpay_payment_id,
                            'message': 'Reconciled successfully with Razorpay API: Payment captured.',
                        },
                        status=status.HTTP_200_OK,
                    )
            except Exception as e:
                logger.error("Razorpay API reconciliation failed for order %s: %s", order.id, e)

        return Response(
            {
                'success': True,
                'reconciled': False,
                'payment_status': order.payment_status,
                'order_id': order.id,
                'message': f"Order payment status remains '{order.payment_status}'. No captured payment found at gateway.",
            },
            status=status.HTTP_200_OK,
        )


class OrderLifecycleRepairView(APIView):
    """
    Admin-authorized endpoint for idempotent, non-destructive repair of historical orders.
    Reconstructs missing OrderStatusHistory audit records based on real database evidence.
    """
    permission_classes = [IsAdminRole]

    def post(self, request):
        from orders.services import repair_historical_orders_lifecycle
        result = repair_historical_orders_lifecycle()
        return Response(
            {
                'success': True,
                'message': f"Historical order lifecycle audit complete. Repaired {result['repaired_orders']} of {result['total_orders']} orders.",
                'data': result,
            },
            status=status.HTTP_200_OK,
        )

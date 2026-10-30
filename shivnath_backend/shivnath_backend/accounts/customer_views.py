import logging
import math
from decimal import Decimal
from datetime import date

from django.contrib.auth.models import User
from django.db.models import (
    Count, Sum, Max, Min, Q, F, Value, DecimalField, OuterRef, Subquery
)
from django.db.models.functions import Coalesce
from django.shortcuts import get_object_or_404
from django.utils import timezone
from rest_framework import status
from rest_framework.response import Response
from rest_framework.views import APIView

from accounts.models import (
    UserProfile,
    FranchiseProfile,
    CustomerFranchiseRelationship,
    CustomerStockCycle,
    ServiceZone,
    ServiceDistrict,
)
from accounts.permissions import IsAdminRole
from orders.models import Order, OrderItem, Wallet
from billing.models import Invoice, PaymentTransaction
from leads.models import Lead
from followups.models import FollowUp
from inventory.models import DealerStockRequest

logger = logging.getLogger(__name__)


def get_franchise_phone(fp):
    if not fp:
        return ''
    user = getattr(fp, 'user', None)
    if user:
        prof = getattr(user, 'profile', None)
        if prof and prof.phone:
            return prof.phone
    return getattr(fp, 'phone', '') or ''



# =============================================================================
# 1. ADMIN CUSTOMER LIST VIEW (SERVER-SIDE CRM DIRECTORY)
# =============================================================================

class AdminCustomerListView(APIView):
    """
    Authoritative Admin CRM list view for all registered customers.
    Provides:
    - Server-side aggregation: total_orders, delivered_orders, pending_orders,
      cancelled_orders, total_spent, last_order_date, wallet_balance.
    - Full zone, district, assigned (registered) franchise, serving franchise attribution.
    - Search by customer name, phone, email, username, customer code, city, district.
    - Filtering by status (active/inactive/hold), zone, franchise attribution, date range.
    - Server-side pagination with count, total_pages, page, page_size.
    - Global summary metrics (total customers, active customers, total orders, total revenue).
    """
    permission_classes = [IsAdminRole]

    def get(self, request):
        try:
            # 1. Base Customer Queryset (Exclude internal admins, franchises, staff, stock managers)
            base_customers = User.objects.filter(
                Q(profile__role='customer') | Q(profile__isnull=True)
            ).exclude(
                is_superuser=True
            ).exclude(
                profile__role__in=['admin', 'super_admin', 'franchise', 'staff', 'stock_manager', 'sales_executive']
            ).exclude(
                franchise_profile__isnull=False
            ).select_related(
                'profile',
                'profile__zone',
                'customer_relationship',
                'customer_relationship__zone',
                'customer_relationship__district',
                'customer_relationship__registered_franchise',
                'customer_relationship__current_serving_franchise',
                'water_wallet',
            )

            # 2. Search Filter
            search = request.query_params.get('search', '').strip()
            if search:
                clean_id = search.upper().replace('CUST-', '').replace('CUST', '').replace('#', '').strip()
                search_q = (
                    Q(first_name__icontains=search) |
                    Q(last_name__icontains=search) |
                    Q(username__icontains=search) |
                    Q(email__icontains=search) |
                    Q(profile__name__icontains=search) |
                    Q(profile__phone__icontains=search) |
                    Q(profile__city__icontains=search) |
                    Q(profile__district__icontains=search) |
                    Q(profile__address__icontains=search) |
                    Q(customer_relationship__registered_franchise__business_name__icontains=search) |
                    Q(customer_relationship__current_serving_franchise__business_name__icontains=search)
                )
                if clean_id.isdigit():
                    user_id = int(clean_id)
                    # Support searching both actual DB id or 1000 + DB id
                    search_q |= Q(id=user_id)
                    if user_id > 1000:
                        search_q |= Q(id=user_id - 1000)
                base_customers = base_customers.filter(search_q)

            # 3. Status Filter (active / inactive / hold)
            status_param = request.query_params.get('status', '').strip().lower()
            if status_param and status_param != 'all':
                if status_param == 'active':
                    base_customers = base_customers.filter(
                        is_active=True
                    ).exclude(profile__status__in=['inactive', 'suspended'])
                elif status_param == 'inactive':
                    base_customers = base_customers.filter(
                        Q(is_active=False) | Q(profile__status__in=['inactive', 'suspended'])
                    )
                elif status_param == 'hold':
                    base_customers = base_customers.filter(
                        customer_relationship__service_status='hold'
                    )

            # 4. Zone Filter
            zone_param = request.query_params.get('zone', '').strip()
            if zone_param and zone_param != 'all':
                if zone_param.isdigit():
                    base_customers = base_customers.filter(
                        Q(customer_relationship__zone_id=int(zone_param)) |
                        Q(profile__zone_id=int(zone_param))
                    )
                else:
                    base_customers = base_customers.filter(
                        Q(customer_relationship__zone__name__icontains=zone_param) |
                        Q(profile__zone__name__icontains=zone_param)
                    )

            # 5. Franchise Attribution Filter
            franchise_param = request.query_params.get('franchise', '').strip()
            if franchise_param and franchise_param != 'all':
                if franchise_param.isdigit():
                    f_id = int(franchise_param)
                    base_customers = base_customers.filter(
                        Q(customer_relationship__registered_franchise_id=f_id) |
                        Q(customer_relationship__current_serving_franchise_id=f_id)
                    )
                else:
                    base_customers = base_customers.filter(
                        Q(customer_relationship__registered_franchise__business_name__icontains=franchise_param) |
                        Q(customer_relationship__current_serving_franchise__business_name__icontains=franchise_param)
                    )

            # 6. Registration Date Range Filter
            date_from = request.query_params.get('date_from', '').strip()
            date_to = request.query_params.get('date_to', '').strip()
            if date_from:
                base_customers = base_customers.filter(date_joined__date__gte=date_from)
            if date_to:
                base_customers = base_customers.filter(date_joined__date__lte=date_to)

            # 7. Server-Side Aggregations via ORM Annotation (No N+1 queries)
            annotated_customers = base_customers.annotate(
                total_orders_count=Count('created_orders', distinct=True),
                delivered_orders_count=Count(
                    'created_orders',
                    filter=Q(created_orders__status='delivered'),
                    distinct=True
                ),
                pending_orders_count=Count(
                    'created_orders',
                    filter=~Q(created_orders__status__in=['delivered', 'cancelled']),
                    distinct=True
                ),
                cancelled_orders_count=Count(
                    'created_orders',
                    filter=Q(created_orders__status='cancelled'),
                    distinct=True
                ),
                total_spent=Coalesce(
                    Sum('created_orders__grand_total', filter=~Q(created_orders__status='cancelled')),
                    Sum('created_orders__amount', filter=~Q(created_orders__status='cancelled')),
                    Value(Decimal('0.00')),
                    output_field=DecimalField()
                ),
                last_order_dt=Max('created_orders__created_at'),
                first_order_dt=Min('created_orders__created_at'),
            ).order_by('-date_joined')

            total_count = annotated_customers.count()

            # Global summary calculation across the filtered queryset
            total_active = annotated_customers.filter(
                is_active=True
            ).exclude(profile__status__in=['inactive', 'suspended']).count()

            # Summary totals
            total_orders_all = annotated_customers.aggregate(
                total_orders=Sum('total_orders_count'),
                total_revenue=Sum('total_spent')
            )
            summary = {
                'total_customers': total_count,
                'active_customers': total_active,
                'total_orders': total_orders_all.get('total_orders') or 0,
                'total_revenue': float(total_orders_all.get('total_revenue') or 0.0),
            }

            # 8. Pagination
            page = int(request.query_params.get('page', 1))
            page_size = int(request.query_params.get('page_size', 20))
            page = max(page, 1)
            page_size = min(max(page_size, 1), 100)

            total_pages = math.ceil(total_count / page_size) if total_count > 0 else 1
            offset = (page - 1) * page_size
            paginated_customers = annotated_customers[offset:offset + page_size]

            # 9. Format Results
            results = []
            for u in paginated_customers:
                prof = getattr(u, 'profile', None)
                rel = getattr(u, 'customer_relationship', None)
                wallet = getattr(u, 'water_wallet', None)

                # Determine customer display status
                is_active = u.is_active and (not prof or prof.status != 'inactive')
                status_label = 'Active' if is_active else 'Inactive'
                if rel and rel.service_status == 'hold':
                    status_label = 'On Hold'

                # Zone Attribution
                zone_name = 'Not assigned'
                zone_id = None
                zone_code = ''
                if rel and rel.zone:
                    zone_name = rel.zone.name
                    zone_id = rel.zone.id
                    zone_code = getattr(rel.zone, 'code', '') or ''
                elif prof and prof.zone:
                    zone_name = prof.zone.name
                    zone_id = prof.zone.id
                    zone_code = getattr(prof.zone, 'code', '') or ''

                # Franchise Attribution
                registered_franchise = None
                if rel and rel.registered_franchise:
                    rf = rel.registered_franchise
                    registered_franchise = {
                        'id': rf.id,
                        'name': rf.business_name,
                        'city': rf.city,
                        'phone': get_franchise_phone(rf),
                    }

                current_serving_franchise = None
                if rel and rel.current_serving_franchise:
                    sf = rel.current_serving_franchise
                    current_serving_franchise = {
                        'id': sf.id,
                        'name': sf.business_name,
                        'city': sf.city,
                        'phone': get_franchise_phone(sf),
                    }

                # Customer name
                display_name = ''
                if prof and prof.name:
                    display_name = prof.name
                elif u.get_full_name():
                    display_name = u.get_full_name()
                else:
                    display_name = u.username

                results.append({
                    'id': u.id,
                    'customer_code': f'CUST-{1000 + u.id}',
                    'name': display_name,
                    'username': u.username,
                    'email': u.email,
                    'phone': prof.phone if prof else '',
                    'status': status_label,
                    'is_active': is_active,
                    'date_joined': u.date_joined.isoformat() if u.date_joined else '',
                    'date_joined_formatted': u.date_joined.strftime('%d %b %Y, %I:%M %p') if u.date_joined else '',
                    'city': prof.city if prof else '',
                    'district': rel.district.name if rel and rel.district else (prof.district if prof else ''),
                    'locality': rel.locality if rel and rel.locality else (prof.locality if prof else ''),
                    'pincode': rel.pincode if rel and rel.pincode else (prof.pincode if prof else ''),
                    'address': prof.address if prof else '',
                    'zone': {
                        'id': zone_id,
                        'name': zone_name,
                        'code': zone_code,
                    },
                    'registered_franchise': registered_franchise,
                    'current_serving_franchise': current_serving_franchise,
                    'service_status': rel.service_status if rel else 'active',
                    'wallet_balance': float(wallet.balance) if wallet else 0.0,
                    'gstin': prof.gstin if prof else '',
                    'metrics': {
                        'total_orders': u.total_orders_count,
                        'delivered_orders': u.delivered_orders_count,
                        'pending_orders': u.pending_orders_count,
                        'cancelled_orders': u.cancelled_orders_count,
                        'total_spent': float(u.total_spent),
                        'last_order_date': u.last_order_dt.isoformat() if u.last_order_dt else None,
                        'first_order_date': u.first_order_dt.isoformat() if u.first_order_dt else None,
                    }
                })

            return Response({
                'success': True,
                'count': total_count,
                'page': page,
                'page_size': page_size,
                'total_pages': total_pages,
                'summary': summary,
                'results': results,
            }, status=status.HTTP_200_OK)

        except Exception as e:
            logger.error("Error in AdminCustomerListView: %s", e, exc_info=True)
            return Response({
                'success': False,
                'message': f"Failed to retrieve customer directory: {str(e)}"
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


# =============================================================================
# 2. ADMIN CUSTOMER DETAIL VIEW (PROFILE, STATS & PAGINATED ORDER HISTORY)
# =============================================================================

class AdminCustomerDetailView(APIView):
    """
    Authoritative Admin CRM detail view for a specific customer.
    Returns:
    - Complete Customer Profile: contact info, addresses, zone, GST profile, wallet.
    - Franchise Attribution: distinguishes registered origin dealer from serving dealer.
    - Financial & Order Statistics: delivered, pending, cancelled, lifetime spend,
      paid and outstanding amounts.
    - Paginated Order History: complete order objects with items, pricing snapshots,
      payment details, and fulfillment attribution.
    """
    permission_classes = [IsAdminRole]

    def get(self, request, user_id):
        try:
            customer_user = get_object_or_404(User, id=user_id)
            prof = getattr(customer_user, 'profile', None)
            rel = getattr(customer_user, 'customer_relationship', None)
            wallet = getattr(customer_user, 'water_wallet', None)

            # Security: Ensure this is a customer, not an internal staff or franchise
            role = prof.role if prof else 'customer'
            if role in ['admin', 'super_admin', 'staff', 'stock_manager'] or customer_user.is_superuser:
                return Response({
                    'success': False,
                    'message': 'Requested user is an internal administrative account, not a customer profile.'
                }, status=status.HTTP_400_BAD_REQUEST)

            # 1. Customer Orders Queryset
            orders_qs = Order.objects.filter(
                created_by=customer_user
            ).select_related(
                'serving_franchise',
                'registered_franchise',
                'zone'
            ).prefetch_related(
                'items',
                'items__product'
            ).order_by('-created_at')

            total_orders = orders_qs.count()
            delivered_orders = orders_qs.filter(status='delivered').count()
            cancelled_orders = orders_qs.filter(status='cancelled').count()
            pending_orders = orders_qs.filter(~Q(status__in=['delivered', 'cancelled'])).count()
            direct_orders = orders_qs.filter(order_source='DIRECT_COMPANY').count()
            franchise_orders = orders_qs.filter(order_source='FRANCHISE').count()

            first_order = orders_qs.order_by('created_at').first()
            last_order = orders_qs.first()

            # Monetary Calculations from Invoices or Orders
            invoices = Invoice.objects.filter(order__created_by=customer_user)
            if invoices.exists():
                total_revenue = sum(inv.grand_total for inv in invoices)
                total_paid = sum(inv.amount_paid for inv in invoices)
                total_outstanding = sum(inv.outstanding_balance for inv in invoices)
            else:
                valid_orders = orders_qs.filter(~Q(status='cancelled'))
                total_revenue = sum((o.grand_total or o.amount or Decimal('0.00')) for o in valid_orders)
                total_paid = sum((o.grand_total or o.amount or Decimal('0.00')) for o in valid_orders.filter(payment_status='paid'))
                total_outstanding = max(Decimal('0.00'), total_revenue - total_paid)

            # 2. Paginated Order History
            order_page = int(request.query_params.get('order_page', request.query_params.get('page', 1)))
            order_page_size = int(request.query_params.get('order_page_size', request.query_params.get('page_size', 10)))
            order_page = max(order_page, 1)
            order_page_size = min(max(order_page_size, 1), 50)

            total_order_pages = math.ceil(total_orders / order_page_size) if total_orders > 0 else 1
            order_offset = (order_page - 1) * order_page_size
            page_orders = orders_qs[order_offset:order_offset + order_page_size]

            orders_list = []
            for o in page_orders:
                items_data = []
                for it in o.items.all():
                    items_data.append({
                        'id': it.id,
                        'product_id': it.product.id if it.product else None,
                        'product_name': it.product_name or (it.product.name if it.product else (o.franchise_name or 'Packaged Water')),
                        'size': it.size,
                        'quantity': it.quantity,
                        'unit_price': float(it.unit_price or 0.0),
                        'total_price': float(it.total_price or 0.0),
                    })

                # Associated franchise attribution
                serving_franchise_data = None
                if o.serving_franchise:
                    serving_franchise_data = {
                        'id': o.serving_franchise.id,
                        'name': o.serving_franchise.business_name,
                        'city': o.serving_franchise.city,
                        'phone': get_franchise_phone(o.serving_franchise),
                    }
                elif o.snapshot_serving_dealer_name:
                    serving_franchise_data = {
                        'id': o.snapshot_serving_dealer_id,
                        'name': o.snapshot_serving_dealer_name,
                        'city': o.city,
                        'phone': '',
                    }

                registered_franchise_data = None
                if o.registered_franchise:
                    registered_franchise_data = {
                        'id': o.registered_franchise.id,
                        'name': o.registered_franchise.business_name,
                        'city': o.registered_franchise.city,
                        'phone': get_franchise_phone(o.registered_franchise),
                    }

                orders_list.append({
                    'id': o.id,
                    'order_code': getattr(o, 'order_code', None) or f'ORD-{o.id}',
                    'created_at': o.created_at.isoformat() if hasattr(o, 'created_at') and o.created_at else (
                        timezone.datetime.combine(o.order_date, timezone.datetime.min.time()).isoformat() if o.order_date else ''
                    ),
                    'order_date': str(o.order_date),
                    'status': o.status,
                    'status_display': dict(Order.STATUS_CHOICES).get(o.status, o.status.replace('_', ' ').title()),
                    'order_source': o.order_source,
                    'order_source_display': dict(Order.ORDER_SOURCE_CHOICES).get(o.order_source, o.order_source),
                    'payment_status': o.payment_status,
                    'payment_mode': o.payment_mode,
                    'amount': float(o.amount or 0.0),
                    'delivery_charge': float(getattr(o, 'delivery_charge', 0.0) or 0.0),
                    'tax_amount': float(o.tax_amount or 0.0),
                    'grand_total': float(o.grand_total or o.amount or 0.0),
                    'items_count': o.items_count,
                    'items_summary': getattr(o, 'items_summary', '') or f"{o.items_count} items",
                    'delivery_address': getattr(o, 'delivery_address', '') or (prof.address if prof else ''),
                    'city': o.city,
                    'serving_franchise': serving_franchise_data,
                    'registered_franchise': registered_franchise_data,
                    'items': items_data,
                })

            # 3. Active Stock Cycles
            stock_cycles = []
            cycles = CustomerStockCycle.objects.filter(customer=customer_user).select_related(
                'product', 'registered_franchise', 'serving_franchise'
            ).order_by('-created_at')
            today = date.today()
            for c in cycles:
                stock_cycles.append({
                    'id': c.id,
                    'product_name': c.product.name if c.product else 'Drinking Water',
                    'quantity': c.quantity,
                    'duration_choice': c.duration_choice,
                    'duration_days': c.duration_days,
                    'start_date': c.start_date.isoformat(),
                    'expected_end_date': c.expected_end_date.isoformat(),
                    'service_status': c.service_status,
                    'days_remaining': c.days_remaining,
                    'is_low_stock': c.is_low_stock,
                    'registered_franchise': {
                        'id': c.registered_franchise.id,
                        'name': c.registered_franchise.business_name,
                    } if c.registered_franchise else None,
                    'serving_franchise': {
                        'id': c.serving_franchise.id,
                        'name': c.serving_franchise.business_name,
                    } if c.serving_franchise else None,
                })

            # Customer Name
            name = ''
            if prof and prof.name:
                name = prof.name
            elif customer_user.get_full_name():
                name = customer_user.get_full_name()
            else:
                name = customer_user.username

            # Zone Information
            zone_info = {
                'id': None,
                'name': 'Not assigned',
                'code': '',
                'description': '',
            }
            if rel and rel.zone:
                zone_info = {
                    'id': rel.zone.id,
                    'name': rel.zone.name,
                    'code': getattr(rel.zone, 'code', '') or '',
                    'description': getattr(rel.zone, 'description', '') or '',
                }
            elif prof and prof.zone:
                zone_info = {
                    'id': prof.zone.id,
                    'name': prof.zone.name,
                    'code': getattr(prof.zone, 'code', '') or '',
                    'description': getattr(prof.zone, 'description', '') or '',
                }

            # Franchise Attribution
            reg_franchise_info = None
            if rel and rel.registered_franchise:
                rf = rel.registered_franchise
                reg_franchise_info = {
                    'id': rf.id,
                    'name': rf.business_name,
                    'city': rf.city,
                    'phone': get_franchise_phone(rf),
                    'territory': rf.territory,
                }

            serving_franchise_info = None
            if rel and rel.current_serving_franchise:
                sf = rel.current_serving_franchise
                serving_franchise_info = {
                    'id': sf.id,
                    'name': sf.business_name,
                    'city': sf.city,
                    'phone': get_franchise_phone(sf),
                    'territory': sf.territory,
                }

            return Response({
                'success': True,
                'customer': {
                    'id': customer_user.id,
                    'customer_code': f'CUST-{1000 + customer_user.id}',
                    'name': name,
                    'username': customer_user.username,
                    'email': customer_user.email,
                    'phone': prof.phone if prof else '',
                    'status': prof.status if prof else ('active' if customer_user.is_active else 'inactive'),
                    'is_active': customer_user.is_active,
                    'date_joined': customer_user.date_joined.isoformat() if customer_user.date_joined else '',
                    'date_joined_formatted': customer_user.date_joined.strftime('%d %b %Y, %I:%M %p') if customer_user.date_joined else '',
                    'city': prof.city if prof else '',
                    'district': rel.district.name if rel and rel.district else (prof.district if prof else ''),
                    'locality': rel.locality if rel and rel.locality else (prof.locality if prof else ''),
                    'pincode': rel.pincode if rel and rel.pincode else (prof.pincode if prof else ''),
                    'territory': prof.territory if prof else '',
                    'address': prof.address if prof else '',
                    'zone': zone_info,
                    'gst_profile': {
                        'gstin': prof.gstin if prof else '',
                        'legal_name': prof.gst_legal_name if prof else '',
                        'billing_address': prof.gst_billing_address if prof else '',
                        'state_name': prof.gst_state_name if prof else 'Chhattisgarh',
                        'pincode': prof.gst_pincode if prof else '',
                    },
                    'attribution': {
                        'registered_franchise': reg_franchise_info,
                        'current_serving_franchise': serving_franchise_info,
                        'service_status': rel.service_status if rel else 'active',
                    },
                    'wallet': {
                        'balance': float(wallet.balance) if wallet else 0.0,
                        'reward_points': getattr(wallet, 'reward_points', 0) if wallet else 0,
                    },
                    'stock_cycles': stock_cycles,
                },
                'statistics': {
                    'total_orders': total_orders,
                    'delivered_orders': delivered_orders,
                    'pending_orders': pending_orders,
                    'cancelled_orders': cancelled_orders,
                    'direct_orders': direct_orders,
                    'franchise_orders': franchise_orders,
                    'total_order_value': float(total_revenue),
                    'total_paid': float(total_paid),
                    'total_outstanding': float(total_outstanding),
                    'first_order_date': str(first_order.order_date) if first_order and first_order.order_date else None,
                    'last_order_date': str(last_order.order_date) if last_order and last_order.order_date else None,
                },
                'order_history': {
                    'count': total_orders,
                    'page': order_page,
                    'page_size': order_page_size,
                    'total_pages': total_order_pages,
                    'orders': orders_list,
                }
            }, status=status.HTTP_200_OK)

        except Exception as e:
            logger.error("Error in AdminCustomerDetailView: %s", e, exc_info=True)
            return Response({
                'success': False,
                'message': f"Failed to retrieve customer details: {str(e)}"
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


# =============================================================================
# 3. AUTHORITATIVE ADMIN DASHBOARD STATS VIEW
# =============================================================================

class AdminDashboardStatsView(APIView):
    """
    Authoritative database metrics aggregator for the Admin Dashboard.
    Provides true DB counts across leads, orders, customers, franchises,
    and stock requests—completely decoupled from list page sizes or pagination limits.
    """
    permission_classes = [IsAdminRole]

    def get(self, request):
        try:
            today = timezone.now().date()

            # 1. Authoritative Leads Metrics
            total_leads = Lead.objects.count()
            hot_leads = Lead.objects.filter(
                Q(score_category='HOT') | Q(score__iexact='hot')
            ).count()
            warm_leads = Lead.objects.filter(
                Q(score_category='WARM') | Q(score__iexact='warm')
            ).count()
            cold_leads = Lead.objects.filter(
                Q(score_category='COLD') | Q(score__iexact='cold')
            ).count()
            confirmed_dealers = Lead.objects.filter(
                status__iexact='franchise_confirmed'
            ).count()

            pipeline_items = Lead.objects.values('status').annotate(count=Count('id')).order_by()
            pipeline = {item['status']: item['count'] for item in pipeline_items}

            # 2. Authoritative Follow-ups
            followups_today = FollowUp.objects.filter(
                followup_datetime__date=today,
                status__iexact='pending'
            ).count()

            # 3. Authoritative Orders Metrics (Total across all statuses)
            orders_qs = Order.objects.all()
            total_orders = orders_qs.count()
            delivered_orders = orders_qs.filter(status='delivered').count()
            cancelled_orders = orders_qs.filter(status='cancelled').count()
            pending_orders = orders_qs.filter(
                status__in=[
                    'order_placement',
                    'plant_approval',
                    'invoice_generated',
                    'preparing',
                    'dispatch',
                    'payment_collection'
                ]
            ).count()
            new_orders = orders_qs.filter(
                status__in=['order_placement', 'created', 'new']
            ).count()
            preparing_orders = orders_qs.filter(
                status__in=['preparing', 'in_process']
            ).count()
            dispatch_orders = orders_qs.filter(
                status='dispatch'
            ).count()

            val_agg = orders_qs.filter(~Q(status='cancelled')).aggregate(
                total=Coalesce(Sum('grand_total'), Sum('amount'), Value(Decimal('0.00')), output_field=DecimalField())
            )
            total_order_value = float(val_agg.get('total') or 0.0)

            # 4. Authoritative Customers Metrics
            customers_qs = User.objects.filter(
                Q(profile__role='customer') | Q(profile__isnull=True)
            ).exclude(
                is_superuser=True
            ).exclude(
                profile__role__in=['admin', 'super_admin', 'franchise', 'staff', 'stock_manager', 'sales_executive']
            ).exclude(
                franchise_profile__isnull=False
            )
            total_customers = customers_qs.count()
            active_customers = customers_qs.filter(
                is_active=True
            ).exclude(profile__status__in=['inactive', 'suspended']).count()

            # 5. Authoritative Franchises Metrics
            total_franchises = FranchiseProfile.objects.filter(status='approved').count()
            pending_franchises = FranchiseProfile.objects.filter(status='pending').count()
            all_franchises_count = FranchiseProfile.objects.count()

            # 6. Authoritative Franchise Stock Requests
            total_stock_requests = DealerStockRequest.objects.count()
            pending_stock_requests = DealerStockRequest.objects.filter(
                status__in=['REQUESTED', 'PENDING', 'SUBMITTED']
            ).count()

            return Response({
                'success': True,
                'stats': {
                    # Leads
                    'total_leads': total_leads,
                    'hot_leads': hot_leads,
                    'warm_leads': warm_leads,
                    'cold_leads': cold_leads,
                    'confirmed_dealers': confirmed_dealers,
                    'followups_today': followups_today,
                    'pipeline': pipeline,

                    # Orders
                    'total_orders': total_orders,
                    'pending_orders': pending_orders,
                    'delivered_orders': delivered_orders,
                    'cancelled_orders': cancelled_orders,
                    'new_orders': new_orders,
                    'preparing_orders': preparing_orders,
                    'dispatch_orders': dispatch_orders,
                    'total_order_value': total_order_value,

                    # Customers
                    'total_customers': total_customers,
                    'active_customers': active_customers,

                    # Franchises
                    'total_franchises': total_franchises,
                    'pending_franchises': pending_franchises,
                    'all_franchises': all_franchises_count,

                    # Stock Requests
                    'franchise_stock_requests': total_stock_requests,
                    'pending_stock_requests': pending_stock_requests,
                }
            }, status=status.HTTP_200_OK)

        except Exception as e:
            logger.error("Error in AdminDashboardStatsView: %s", e, exc_info=True)
            return Response({
                'success': False,
                'message': f"Failed to calculate dashboard statistics: {str(e)}"
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

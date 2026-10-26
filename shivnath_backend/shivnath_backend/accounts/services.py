import calendar
from datetime import date, timedelta
from django.utils import timezone
from .models import (
    CustomerStockCycle,
    FranchiseNotification,
    AdminNotification,
    CustomerNotification,
    StockAlertLog,
)


def add_calendar_months(sourcedate, months):
    """
    Safely adds exact calendar months to a given date,
    handling variable month lengths (28, 29, 30, 31) and leap years accurately.
    Example: 18 Sep + 1 month = 18 Oct; 31 Jan + 1 month = 28 Feb (or 29 Feb).
    """
    month = sourcedate.month - 1 + months
    year = sourcedate.year + month // 12
    month = month % 12 + 1
    day = min(sourcedate.day, calendar.monthrange(year, month)[1])
    return sourcedate.replace(year=year, month=month, day=day)


def calculate_stock_end_date(start_date, duration_choice, custom_days=None):
    """
    Authoritative duration calculator:
    - 1 Month -> 1 calendar month
    - 2 Months -> 2 calendar months
    - 3 Months -> 3 calendar months
    - Custom -> exact configured number of days
    """
    choice = str(duration_choice or '').strip().lower()
    if '3' in choice and 'month' in choice:
        return add_calendar_months(start_date, 3)
    elif '2' in choice and 'month' in choice:
        return add_calendar_months(start_date, 2)
    elif '1' in choice and 'month' in choice:
        return add_calendar_months(start_date, 1)
    elif custom_days and int(custom_days) > 0:
        return start_date + timedelta(days=int(custom_days))
    elif 'custom' in choice and custom_days:
        return start_date + timedelta(days=int(custom_days))
    else:
        # Default to 1 calendar month
        return add_calendar_months(start_date, 1)


def trigger_daily_low_stock_alerts(target_date=None):
    """
    Daily background / scheduled job:
    1. Finds all active stock cycles.
    2. Ignores HOLD cycles.
    3. Calculates actual remaining days from expected_end_date.
    4. If days_remaining <= 0 -> Transitions to 'expired' state (no 7-day alert).
    5. If 1 <= days_remaining <= 7:
       Sends de-duplicated low-stock notifications to exactly 3 targets:
       a) Customer (CustomerNotification)
       b) Serving Franchise (FranchiseNotification)
       c) Admin (AdminNotification)
       Tracks each recipient in StockAlertLog with DB-level uniqueness constraint.
       Supports partial retry safely without duplicate dispatches.
    6. If days_remaining > 7 -> Does not send alerts.
    """
    today = target_date or timezone.now().date()

    active_cycles = CustomerStockCycle.objects.filter(
        service_status='active'
    ).select_related('customer', 'customer__profile', 'serving_franchise', 'zone')

    dispatched_summary = []

    for cycle in active_cycles:
        days_remaining = (cycle.expected_end_date - today).days

        # Rule 5: days_remaining <= 0 -> Expired
        if days_remaining <= 0:
            cycle.service_status = 'expired'
            cycle.save(update_fields=['service_status', 'updated_at'])
            continue

        # Rule 4 & 5: Only trigger when 1 <= days_remaining <= 7
        if 1 <= days_remaining <= 7:
            cust = cycle.customer
            cust_name = cust.get_full_name() or cust.username
            cust_phone = getattr(getattr(cust, 'profile', None), 'phone', '')
            serving_f = cycle.serving_franchise
            zone_name = cycle.zone.name if cycle.zone else 'General Zone'
            p_name = cycle.product_name or 'Water Stock'
            any_dispatched = False

            # 1. Target 1: Customer
            if not StockAlertLog.objects.filter(
                stock_cycle=cycle,
                alert_date=today,
                recipient_type='customer',
                recipient_id=cust.id,
                status='sent'
            ).exists():
                try:
                    CustomerNotification.objects.create(
                        customer=cust,
                        title="⚠️ Low Stock Alert",
                        message=(
                            f"Your stock is going to finish in {days_remaining} day{'s' if days_remaining != 1 else ''}. "
                            f"Please refill your stock by placing a new order or contact your serving franchise for assistance."
                        ),
                        notification_type='low_stock',
                        stock_cycle=cycle,
                        reference_id=cycle.id,
                    )
                    StockAlertLog.objects.create(
                        stock_cycle=cycle,
                        alert_date=today,
                        recipient_type='customer',
                        recipient_id=cust.id,
                        days_remaining=days_remaining,
                        status='sent'
                    )
                    any_dispatched = True
                except Exception as e:
                    StockAlertLog.objects.create(
                        stock_cycle=cycle,
                        alert_date=today,
                        recipient_type='customer',
                        recipient_id=cust.id,
                        days_remaining=days_remaining,
                        status='failed',
                        error_message=str(e)
                    )

            # 2. Target 2: Actual Serving Franchise
            if serving_f and not StockAlertLog.objects.filter(
                stock_cycle=cycle,
                alert_date=today,
                recipient_type='franchise',
                recipient_id=serving_f.id,
                status='sent'
            ).exists():
                try:
                    FranchiseNotification.objects.create(
                        franchise=serving_f,
                        title=f"Low Stock Alert: {cust_name} ({days_remaining}d left)",
                        message=(
                            f"Customer {cust_name}'s stock is going to finish in {days_remaining} day{'s' if days_remaining != 1 else ''}. "
                            f"Please contact the customer for refill/order follow-up."
                        ),
                        notification_type='stock_alert',
                        reference_id=cycle.id,
                    )
                    StockAlertLog.objects.create(
                        stock_cycle=cycle,
                        alert_date=today,
                        recipient_type='franchise',
                        recipient_id=serving_f.id,
                        days_remaining=days_remaining,
                        status='sent'
                    )
                    any_dispatched = True
                except Exception as e:
                    StockAlertLog.objects.create(
                        stock_cycle=cycle,
                        alert_date=today,
                        recipient_type='franchise',
                        recipient_id=serving_f.id,
                        days_remaining=days_remaining,
                        status='failed',
                        error_message=str(e)
                    )

            # 3. Target 3: Admin
            if not StockAlertLog.objects.filter(
                stock_cycle=cycle,
                alert_date=today,
                recipient_type='admin',
                recipient_id=0,
                status='sent'
            ).exists():
                try:
                    AdminNotification.objects.create(
                        title=f"Low Stock Alert: {cust_name}",
                        message=(
                            f"Customer {cust_name} ({cust_phone}) has stock ending in {days_remaining} day{'s' if days_remaining != 1 else ''} "
                            f"through {serving_f.business_name if serving_f else 'Serving Franchise'} in Zone {zone_name}."
                        ),
                        notification_type='stock_alert',
                        reference_id=cycle.id,
                    )
                    StockAlertLog.objects.create(
                        stock_cycle=cycle,
                        alert_date=today,
                        recipient_type='admin',
                        recipient_id=0,
                        days_remaining=days_remaining,
                        status='sent'
                    )
                    any_dispatched = True
                except Exception as e:
                    StockAlertLog.objects.create(
                        stock_cycle=cycle,
                        alert_date=today,
                        recipient_type='admin',
                        recipient_id=0,
                        days_remaining=days_remaining,
                        status='failed',
                        error_message=str(e)
                    )

            if any_dispatched:
                dispatched_summary.append({
                    'cycle_id': cycle.id,
                    'customer': cust_name,
                    'days_remaining': days_remaining,
                    'serving_franchise': serving_f.business_name if serving_f else 'N/A'
                })

    return dispatched_summary


# Backward compatibility alias
check_and_dispatch_stock_alerts = trigger_daily_low_stock_alerts



def send_customer_registration_notifications(customer_user, rel):
    """
    Sends registration notifications to:
    1. Assigned/Registered Franchise
    2. Admin
    """
    cust_name = customer_user.get_full_name() or customer_user.username
    from accounts.models import UserProfile
    phone = getattr(getattr(customer_user, 'profile', None), 'phone', '') or (UserProfile.objects.filter(user=customer_user).values_list('phone', flat=True).first() or '')
    email = customer_user.email
    district_name = rel.district.name if rel.district else 'N/A'
    zone_name = rel.zone.name if rel.zone else 'N/A'
    pin = rel.pincode or 'N/A'
    registered_f = rel.registered_franchise

    # 1. Franchise Notification
    if registered_f:
        FranchiseNotification.objects.create(
            franchise=registered_f,
            title="New Customer Registered",
            message=(
                f"New customer registered in your franchise/service area.\n"
                f"Name: {cust_name}\n"
                f"Mobile: {phone}\n"
                f"Email: {email}\n"
                f"District: {district_name}\n"
                f"Zone: {zone_name}\n"
                f"Service Area/PIN: {pin}\n"
                f"Registered/Assigned Franchise: {registered_f.business_name}"
            ),
            notification_type='new_customer',
            reference_id=customer_user.id,
        )

    # 2. Admin Notification
    AdminNotification.objects.create(
        title="New Customer Registered",
        message=(
            f"New customer registered.\n"
            f"Name: {cust_name}\n"
            f"Mobile: {phone}\n"
            f"Email: {email}\n"
            f"District: {district_name}\n"
            f"Zone: {zone_name}\n"
            f"Service Area/PIN: {pin}\n"
            f"Registered/Assigned Franchise: {registered_f.business_name if registered_f else 'N/A'}"
        ),
        notification_type='customer_registration',
        reference_id=customer_user.id,
    )

    try:
        from accounts.fcm_services import notify_customer_registered
        notify_customer_registered(customer_user, rel)
    except Exception as e:
        logger.warning("FCM: Customer registration push notification error: %s", e)



def send_order_placed_notifications(order, stock_cycle=None):
    """
    Sends order notifications to:
    1. Actual Serving Franchise (Only if Franchise-fulfilled)
    2. Admin & Super Admin
    """
    cust = order.created_by
    cust_name = cust.get_full_name() if cust else (order.client_name or 'Customer')
    is_direct = getattr(order, 'order_source', '') in ['DIRECT_COMPANY', 'WATER_WALLET', 'WATER_WALLET_REDEMPTION'] or not order.serving_franchise
    serving_f = None if is_direct else order.serving_franchise
    amount = order.amount or order.grand_total or 0.0
    items_count = order.items_count or (order.items.count() if hasattr(order, 'items') else 1)

    if is_direct:
        admin_title = f"New Customer Order: #{order.order_code}"
        admin_body = f"Order #{order.order_code} from {cust_name} • ₹{amount} • {items_count} items (Direct Company Order)"
    else:
        admin_title = f"New Customer Order: #{order.order_code}"
        admin_body = f"Order #{order.order_code} from {cust_name} • ₹{amount} • {items_count} items (Fulfilled by {serving_f.business_name})"

    # 1. Serving Franchise Notification (ONLY if Franchise order)
    if serving_f and not is_direct:
        FranchiseNotification.objects.get_or_create(
            franchise=serving_f,
            notification_type='order_placed',
            reference_id=order.id,
            defaults={
                'title': f"New Order Assigned: #{order.order_code}",
                'message': f"Client {cust_name} placed order #{order.order_code} (₹{amount}, {items_count} items) assigned to your territory."
            }
        )

    # 2. Admin Notification
    AdminNotification.objects.get_or_create(
        title=admin_title,
        notification_type='order_placed',
        reference_id=order.id,
        defaults={'message': admin_body}
    )



def resolve_serviceable_franchises(zone=None, district=None, allow_fallback=True):
    """
    Deterministically resolves eligible serving franchises for a customer's territory:
    1. Exact Zone Match: Searches for active, approved franchises assigned to `zone`.
    2. Same-District Fallback: If 0 exact franchises and allow_fallback=True,
       searches for active, approved franchises assigned to other zones in the same `district`.
       Returns clear coverage info (e.g., 'Serves West Raipur (Raipur District)').
    3. Unavailable: If 0 franchises found, returns match_level='none' with central support contact info.
    """
    from .models import FranchiseTerritoryAssignment, ServiceDistrict, ServiceZone, FranchiseProfile, SupportContact
    from django.conf import settings

    # Helper for support contact
    def _get_support_info():
        try:
            sc = SupportContact.objects.get(role='public_customer')
            return {'phone': sc.phone, 'email': sc.email, 'name': sc.name}
        except SupportContact.DoesNotExist:
            fallback = getattr(settings, 'SUPPORT_FALLBACK_PHONE', None)
            return {'phone': fallback or '', 'email': 'support@shivnath.com', 'name': 'Shivnath Central Support'}

    if not zone and not district:
        return {
            'success': False,
            'match_level': 'none',
            'is_fallback': False,
            'fallback_message': 'No territory or zone specified.',
            'support_contact': _get_support_info(),
            'franchises': [],
            'count': 0,
        }

    # 1. Exact Zone Match
    if zone:
        exact_assignments = FranchiseTerritoryAssignment.objects.filter(
            zone=zone,
            is_active=True,
            franchise__status='approved'
        ).select_related('franchise', 'franchise__user', 'franchise__user__profile', 'zone', 'zone__district')

        if exact_assignments.exists():
            franchises = []
            for assign in exact_assignments:
                f = assign.franchise
                franchises.append({
                    'id': f.id,
                    'business_name': f.business_name,
                    'owner_name': f.user.get_full_name() or f.user.username,
                    'city': f.city,
                    'address': f.address,
                    'phone': f.user.profile.phone if hasattr(f.user, 'profile') else '',
                    'is_primary': assign.is_primary,
                    'is_headquarters': f.is_headquarters,
                    'is_fallback': False,
                    'serving_zone_id': assign.zone.id,
                    'serving_zone_name': assign.zone.name,
                    'serving_district_name': assign.zone.district.name,
                    'service_coverage': f"Serves {assign.zone.name} ({assign.zone.district.name})",
                })
            return {
                'success': True,
                'match_level': 'exact',
                'is_fallback': False,
                'fallback_message': None,
                'support_contact': None,
                'franchises': franchises,
                'exact_matches': franchises,
                'available_franchises': [],
                'count': len(franchises),
            }

    # 2. Configured Fallback within the same District or System-wide
    if allow_fallback:
        target_district = district
        if not target_district and zone and zone.district:
            target_district = zone.district
        elif isinstance(district, str):
            target_district = ServiceDistrict.objects.filter(name__iexact=district, is_active=True).first()

        fallback_franchises = []
        seen_franchise_ids = set()

        if target_district:
            fallback_query = FranchiseTerritoryAssignment.objects.filter(
                zone__district=target_district,
                is_active=True,
                franchise__status='approved'
            )
            if zone:
                fallback_query = fallback_query.exclude(zone=zone)

            fallback_assignments = fallback_query.select_related(
                'franchise', 'franchise__user', 'franchise__user__profile', 'zone', 'zone__district'
            ).order_by('-is_primary', 'franchise__business_name')

            for assign in fallback_assignments:
                f = assign.franchise
                if f.id in seen_franchise_ids:
                    continue
                seen_franchise_ids.add(f.id)
                fallback_franchises.append({
                    'id': f.id,
                    'business_name': f.business_name,
                    'owner_name': f.user.get_full_name() or f.user.username,
                    'city': f.city,
                    'address': f.address,
                    'phone': f.user.profile.phone if hasattr(f.user, 'profile') else '',
                    'is_primary': assign.is_primary,
                    'is_headquarters': f.is_headquarters,
                    'is_fallback': True,
                    'serving_zone_id': assign.zone.id,
                    'serving_zone_name': assign.zone.name,
                    'serving_district_name': assign.zone.district.name,
                    'service_coverage': f"Serves {assign.zone.name} (Alternate Territory)",
                })

        if fallback_franchises:
            zone_label = f" ({zone.name})" if zone else ""
            dist_label = f" ({target_district.name})" if target_district else ""
            return {
                'success': True,
                'match_level': 'fallback',
                'is_fallback': True,
                'fallback_message': f'No primary franchise is currently available in your exact zone{zone_label}. Showing authorized alternate franchises in your district{dist_label}.',
                'support_contact': _get_support_info(),
                'franchises': fallback_franchises,
                'exact_matches': [],
                'available_franchises': fallback_franchises,
                'count': len(fallback_franchises),
            }

    # 3. No Serviceable Franchise Available
    return {
        'success': True,
        'match_level': 'none',
        'is_fallback': False,
        'fallback_message': 'No franchises are currently available in the system. Please contact support.',
        'support_contact': _get_support_info(),
        'franchises': [],
        'exact_matches': [],
        'available_franchises': [],
        'count': 0,
    }


def apply_data_scope(user, queryset, model_type):
    """
    Enforces server-side Admin Data Scopes on querysets:
    - ALL_DATA: Unrestricted global access (Super Admin or all_data scope).
    - TERRITORY_SCOPED: Restricted to assigned zones, districts, or territories.
    - DEALER_SCOPED: Restricted to specific authorized wholesale dealer IDs.
    - PLANT_SCOPED: Restricted to Central Manufacturing Plant (Direct Company operations).
    - SALES_EXECUTIVE: Permitted CRM and field sales boundary.
    """
    from django.db.models import Q
    if not user or not user.is_authenticated:
        return queryset

    if user.is_superuser:
        return queryset

    profile = getattr(user, 'profile', None)
    if not profile:
        return queryset

    role = profile.role
    scope_type = profile.data_scope_type or 'all_data'
    scope_ids = profile.assigned_scope_ids or []

    if role in ['super_admin', 'admin'] and (not scope_type or scope_type in ['all_data', 'all'] or not scope_ids):
        return queryset

    if model_type == 'Order':
        if scope_type == 'territory_scoped':
            if not scope_ids:
                return queryset
            return queryset.filter(
                Q(snapshot_territory__in=scope_ids) |
                Q(territory__in=scope_ids) |
                Q(zone__code__in=scope_ids) |
                Q(zone__id__in=[i for i in scope_ids if str(i).isdigit()]) |
                Q(zone__district__name__in=scope_ids) |
                Q(city__in=scope_ids)
            )
        elif scope_type == 'dealer_scoped':
            if not scope_ids:
                return queryset
            return queryset.filter(
                Q(serving_franchise_id__in=[i for i in scope_ids if str(i).isdigit()]) |
                Q(snapshot_serving_dealer_id__in=[i for i in scope_ids if str(i).isdigit()])
            )
        elif scope_type == 'plant_scoped':
            return queryset.filter(order_source='DIRECT_COMPANY')
        elif role == 'sales_executive':
            if scope_ids:
                return queryset.filter(
                    Q(snapshot_territory__in=scope_ids) |
                    Q(city__in=scope_ids) |
                    Q(created_by=user)
                )
            return queryset.filter(created_by=user)

    elif model_type == 'Lead':
        if role == 'sales_executive':
            return queryset.filter(
                Q(assigned_executive_user=user) |
                Q(assigned_executive__iexact=user.username) |
                Q(assigned_executive__iexact=user.get_full_name()) |
                Q(created_by=user)
            )
        if scope_type == 'territory_scoped':
            if not scope_ids:
                return queryset.none()
            return queryset.filter(
                Q(district__in=scope_ids) |
                Q(territory__in=scope_ids) |
                Q(city__in=scope_ids)
            )
        elif scope_type == 'dealer_scoped':
            return queryset.none()
        elif scope_type == 'plant_scoped':
            return queryset

    elif model_type == 'ProductionBatch':
        if scope_type in ['dealer_scoped', 'territory_scoped']:
            return queryset.none()
        elif scope_type in ['plant_scoped', 'all_data']:
            return queryset

    elif model_type == 'DealerStockRequest':
        if scope_type == 'dealer_scoped':
            if not scope_ids:
                return queryset.none()
            return queryset.filter(dealer_id__in=[i for i in scope_ids if str(i).isdigit()])
        elif scope_type == 'territory_scoped':
            if not scope_ids:
                return queryset.none()
            return queryset.filter(
                Q(dealer__territory__in=scope_ids) |
                Q(dealer__city__in=scope_ids)
            )
        elif scope_type in ['plant_scoped', 'all_data']:
            return queryset

    return queryset


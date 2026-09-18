from datetime import date, timedelta
from .models import CustomerStockCycle, FranchiseNotification, AdminNotification


def check_and_dispatch_stock_alerts():
    """
    Checks all active customer stock cycles and triggers targeted 7-day low-stock alerts:
    - To the actual Serving Franchise for that order/cycle
    - To Admin
    - Flags cycle.low_stock_alert_sent = True
    """
    today = date.today()
    threshold_date = today + timedelta(days=7)
    cycles = CustomerStockCycle.objects.filter(
        service_status='active',
        expected_end_date__lte=threshold_date,
        low_stock_alert_sent=False
    ).select_related('customer', 'customer__profile', 'serving_franchise')

    dispatched = []
    for cycle in cycles:
        rem = max((cycle.expected_end_date - today).days, 0)
        cust = cycle.customer
        cust_name = cust.get_full_name() or cust.username

        # 1. Franchise Notification
        if cycle.serving_franchise:
            FranchiseNotification.objects.create(
                franchise=cycle.serving_franchise,
                title=f"Low Stock Alert: {cust_name} ({rem} days left)",
                message=(
                    f"Customer {cust_name} ({cust.profile.phone if hasattr(cust, 'profile') else ''}) "
                    f"has only {rem} days remaining on their {cycle.duration_choice} water stock cycle "
                    f"(Ends: {cycle.expected_end_date.strftime('%d %b %Y')}). Please arrange refill or delivery."
                ),
                notification_type='stock_alert',
                reference_id=cycle.id,
            )

        # 2. Admin Notification
        AdminNotification.objects.create(
            title=f"Low Stock Alert: {cust_name}",
            message=(
                f"Customer {cust_name} served by {cycle.serving_franchise.business_name if cycle.serving_franchise else 'Shivnath Agency'} "
                f"has {rem} days remaining on their stock cycle."
            ),
            notification_type='stock_alert',
            reference_id=cycle.id,
        )

        cycle.low_stock_alert_sent = True
        cycle.save(update_fields=['low_stock_alert_sent'])

        dispatched.append({
            'cycle_id': cycle.id,
            'customer': cust_name,
            'remaining_days': rem,
            'serving_franchise': cycle.serving_franchise.business_name if cycle.serving_franchise else 'N/A'
        })

    return dispatched


def resolve_serviceable_franchises(zone=None, district=None, allow_fallback=True):
    """
    Deterministically resolves eligible serving franchises for a customer's territory:
    1. Exact Zone Match: Searches for active, approved franchises assigned to `zone`.
    2. Same-District Fallback: If 0 exact franchises and allow_fallback=True,
       searches for active, approved franchises assigned to other zones in the same `district`.
       Returns clear coverage info (e.g., 'Serves West Raipur (Raipur District)').
    3. Unavailable: If 0 franchises found, returns match_level='none' with central support contact info.
    """
    from .models import FranchiseTerritoryAssignment, ServiceDistrict, ServiceZone

    if not zone and not district:
        return {
            'success': False,
            'match_level': 'none',
            'is_fallback': False,
            'fallback_message': 'No territory or zone specified.',
            'support_contact': {
                'phone': '+91 98765 43210',
                'email': 'support@shivnathagency.com',
                'name': 'Shivnath Central Support',
            },
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
                'count': len(franchises),
            }

    # 2. Configured Fallback within the same District
    if allow_fallback:
        target_district = district
        if not target_district and zone and zone.district:
            target_district = zone.district
        elif isinstance(district, str):
            target_district = ServiceDistrict.objects.filter(name__iexact=district, is_active=True).first()

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

            seen_franchise_ids = set()
            fallback_franchises = []
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
                    'service_coverage': f"Serves {assign.zone.name} ({assign.zone.district.name})",
                })

            if fallback_franchises:
                return {
                    'success': True,
                    'match_level': 'district_fallback',
                    'is_fallback': True,
                    'fallback_message': 'No franchise is currently available in your selected area. We found franchises serving nearby/alternate service areas.',
                    'support_contact': {
                        'phone': '+91 98765 43210',
                        'email': 'support@shivnathagency.com',
                        'name': 'Shivnath Central Support',
                    },
                    'franchises': fallback_franchises,
                    'count': len(fallback_franchises),
                }

    # 3. No Serviceable Franchise Available Anywhere in Area
    return {
        'success': True,
        'match_level': 'none',
        'is_fallback': False,
        'fallback_message': 'Service currently unavailable in your area.',
        'support_contact': {
            'phone': '+91 98765 43210',
            'email': 'support@shivnathagency.com',
            'name': 'Shivnath Central Support',
            'address': 'Shivnath Central Fulfillment Plant, Raipur, Chhattisgarh',
        },
        'franchises': [],
        'count': 0,
    }


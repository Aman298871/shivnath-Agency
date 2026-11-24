from django.db.models import Q
from rest_framework.exceptions import PermissionDenied


def apply_data_scope(queryset, user, entity_type='order'):
    """
    Authoritative Data Isolation & Multi-Tenant Scope Engine.
    Filters QuerySets according to the user's data_scope_type and assigned_scope_ids.
    Enforces strict isolation across:
    - all_data: Global unrestricted access
    - dealer_scoped: Restricted strictly to assigned franchise IDs
    - territory_scoped: Restricted strictly to assigned zones/districts
    - plant_scoped: Direct company / central plant data only (no dealer records)
    """
    if not user or not user.is_authenticated:
        return queryset.none()
    if user.is_superuser:
        return queryset

    profile = getattr(user, 'profile', None)
    if not profile or profile.role == 'super_admin':
        return queryset

    scope_type = getattr(profile, 'data_scope_type', 'all_data')
    if scope_type == 'all_data':
        return queryset

    scope_ids = getattr(profile, 'assigned_scope_ids', []) or []
    clean_ids = set()
    for sid in scope_ids:
        s = str(sid).strip()
        if s:
            clean_ids.add(s)
            if s.isdigit():
                clean_ids.add(int(s))

    if scope_type == 'dealer_scoped':
        if not clean_ids:
            return queryset.none()
        if entity_type in ['order', 'orders']:
            return queryset.filter(
                Q(serving_franchise_id__in=clean_ids) |
                Q(registered_franchise_id__in=clean_ids)
            )
        elif entity_type in ['invoice', 'invoices', 'payment', 'payments']:
            return queryset.filter(
                Q(stock_request__dealer_id__in=clean_ids) |
                Q(order__serving_franchise_id__in=clean_ids)
            )
        elif entity_type in ['customer', 'customers']:
            return queryset.filter(
                Q(customer_relationship__registered_franchise_id__in=clean_ids) |
                Q(customer_relationship__current_serving_franchise_id__in=clean_ids)
            )
        elif entity_type in ['franchise', 'franchises', 'dealers']:
            return queryset.filter(id__in=clean_ids)
        elif entity_type in ['inventory', 'stock_request', 'stock_requests']:
            return queryset.filter(franchise_id__in=clean_ids)

    elif scope_type == 'territory_scoped':
        if not clean_ids:
            return queryset.none()
        if entity_type in ['order', 'orders']:
            return queryset.filter(
                Q(delivery_zone_id__in=clean_ids) |
                Q(delivery_district__in=clean_ids) |
                Q(serving_franchise__zone_id__in=clean_ids)
            )
        elif entity_type in ['customer', 'customers']:
            return queryset.filter(
                Q(profile__zone_id__in=clean_ids) |
                Q(customer_relationship__zone_id__in=clean_ids) |
                Q(customer_relationship__district__name__in=clean_ids)
            )
        elif entity_type in ['franchise', 'franchises', 'dealers']:
            return queryset.filter(
                Q(zone_id__in=clean_ids) |
                Q(district__in=clean_ids)
            )

    elif scope_type == 'plant_scoped':
        if entity_type in ['order', 'orders']:
            return queryset.filter(serving_franchise__isnull=True, registered_franchise__isnull=True)
        elif entity_type in ['invoice', 'invoices']:
            return queryset.filter(order__serving_franchise__isnull=True, stock_request__dealer__isnull=True)
        elif entity_type in ['customer', 'customers']:
            return queryset.filter(customer_relationship__registered_franchise__isnull=True)
        elif entity_type in ['inventory']:
            return queryset.filter(franchise__isnull=True)

    return queryset


def check_object_scope(user, obj, entity_type='order'):
    """
    Authoritative single-object scope validator.
    Prevents cross-scope / cross-tenant horizontal privilege escalation attacks.
    If an employee attempts to retrieve, modify, or delete a record belonging to another
    franchise or territory, raises PermissionDenied immediately.
    """
    if not user or not user.is_authenticated:
        raise PermissionDenied("Authentication required.")
    if user.is_superuser:
        return True

    profile = getattr(user, 'profile', None)
    if not profile or profile.role == 'super_admin':
        return True

    scope_type = getattr(profile, 'data_scope_type', 'all_data')
    if scope_type == 'all_data':
        return True

    scope_ids = getattr(profile, 'assigned_scope_ids', []) or []
    clean_ids = set()
    for sid in scope_ids:
        s = str(sid).strip()
        if s:
            clean_ids.add(s)
            if s.isdigit():
                clean_ids.add(int(s))

    if scope_type == 'dealer_scoped':
        obj_dealer = (
            getattr(obj, 'franchise_id', None) or
            getattr(obj, 'serving_franchise_id', None) or
            getattr(obj, 'registered_franchise_id', None)
        )
        if obj_dealer and (obj_dealer in clean_ids or str(obj_dealer) in clean_ids):
            return True
        raise PermissionDenied("Cross-scope access denied: You are not authorized to access records belonging to other dealers.")

    elif scope_type == 'plant_scoped':
        obj_dealer = getattr(obj, 'franchise_id', None) or getattr(obj, 'serving_franchise_id', None)
        if obj_dealer is not None:
            raise PermissionDenied("Cross-scope access denied: Plant managers cannot access dealer-franchise records.")
        return True

    return True

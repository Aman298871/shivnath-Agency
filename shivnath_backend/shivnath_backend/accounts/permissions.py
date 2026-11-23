from rest_framework.permissions import BasePermission
from rest_framework.exceptions import PermissionDenied


def resolve_module_and_action(request, view):
    """
    Intelligently determines the target security module and action for an incoming request.
    Respects explicit view declarations ('permission_module', 'permission_action')
    and falls back to automated URL path and HTTP method routing.
    """
    module = getattr(view, 'permission_module', None)
    if not module:
        path = request.path.lower()
        if '/api/orders/' in path or '/orders/' in path:
            module = 'orders'
        elif '/api/billing/delivery/' in path or '/delivery/' in path or '/packaging-rules/' in path:
            module = 'moq'
        elif '/api/billing/' in path or '/billing/' in path:
            module = 'billing'
        elif '/api/products/' in path or '/products/' in path:
            module = 'products'
        elif '/api/inventory/' in path or '/inventory/' in path or '/api/suppliers/' in path:
            module = 'inventory'
        elif '/api/leads/' in path or '/leads/' in path:
            module = 'leads'
        elif '/api/followups/' in path or '/followups/' in path:
            module = 'followups'
        elif '/admin/customers/' in path or '/customers/' in path:
            module = 'customers'
        elif '/franchises/' in path or '/dealers/' in path:
            module = 'dealers'
        elif '/super-admin/admins/' in path or '/employees/' in path:
            module = 'employees'
        elif '/audit-logs/' in path or '/activity/' in path:
            module = 'activity'
        elif '/reports/' in path:
            module = 'reports'

    action = getattr(view, 'permission_action', None)
    if not action:
        path = request.path.lower()
        if 'verify' in path or 'approve' in path:
            action = 'approve'
        elif 'reject' in path:
            action = 'approve'
        elif 'export' in path or 'download' in path:
            action = 'export'
        elif '/status/' in path:
            action = 'edit'
        else:
            method_map = {
                'GET': 'view',
                'POST': 'create',
                'PUT': 'edit',
                'PATCH': 'edit',
                'DELETE': 'delete'
            }
            action = method_map.get(request.method, 'view')

    return module, action


def check_granular_permission(user, module, action='view'):
    """
    Authoritative Permission Gate for all operational administrators.
    - Superusers and super_admin automatically inherit full wildcard access.
    - Inactive accounts or suspended profile status are strictly denied.
    - Checks wildcard permissions ('*', 'all', module, f'{module}:*').
    - Checks action-level permissions (e.g. f'{module}:{action}').
    - Supports module aliases (dealers <-> franchises, moq <-> pricing).
    """
    if not user or not user.is_authenticated:
        return False

    if not user.is_active:
        return False

    profile = getattr(user, 'profile', None)
    if not profile or profile.status != 'active':
        return False

    if user.is_superuser or profile.role == 'super_admin':
        return True

    # If role is customer or franchise, administrative permissions are denied
    if profile.role in ['customer', 'franchise']:
        return False

    if not module:
        return True

    mod = module.lower().strip()
    act = action.lower().strip() if action else 'view'

    # Module alias mapping
    aliases = {mod}
    if mod in ['dealers', 'franchises']:
        aliases.update(['dealers', 'franchises'])
    elif mod in ['moq', 'pricing']:
        aliases.update(['moq', 'pricing', 'delivery'])
    elif mod in ['employees', 'admin_management']:
        aliases.update(['employees', 'admin_management'])
    elif mod in ['activity', 'audit', 'logs']:
        aliases.update(['activity', 'audit', 'logs'])

    # Role-based baselines
    if profile.role == 'sales_executive' and any(m in ['leads', 'customers', 'followups'] for m in aliases) and act in ['view', 'create', 'edit']:
        return True
    if profile.role == 'stock_manager' and any(m in ['inventory', 'products'] for m in aliases) and act in ['view', 'edit', 'adjust']:
        return True

    user_perms = {p.lower().strip() for p in (profile.admin_permissions or [])}

    # Universal wildcards
    if '*' in user_perms or 'all' in user_perms:
        return True

    # Action-level wildcards (e.g., *:view, *:read, *:edit)
    if f"*:{act}" in user_perms or '*:*' in user_perms:
        return True
    if act in ['view', 'read'] and ('*:view' in user_perms or '*:read' in user_perms):
        return True

    # Check for any alias module
    for m in aliases:
        if m in user_perms or f"{m}:*" in user_perms or f"{m}:{act}" in user_perms:
            return True

    return False


class IsAdminRole(BasePermission):
    """
    Strict, granular administrative permission class.
    - Allows Super Admins full access.
    - Strictly blocks inactive or suspended user accounts.
    - For operational Admins (role == 'admin'), resolves target module and action
      and enforces profile.admin_permissions before granting access.
    """
    message = "Administrative access required."

    def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            return False

        if not request.user.is_active:
            self.message = "Your account is deactivated. Access denied."
            return False

        profile = getattr(request.user, 'profile', None)
        if not profile or profile.status != 'active':
            self.message = "Your account profile status is suspended or inactive. Access denied."
            return False

        if request.user.is_superuser or profile.role == 'super_admin':
            return True

        if profile.role != 'admin':
            self.message = "Administrative privileges required."
            return False

        module, action = resolve_module_and_action(request, view)
        if not check_granular_permission(request.user, module, action):
            self.message = f"Permission Denied: Missing '{module}:{action}' privilege."
            return False

        return True


class IsStockManagerOrAdmin(BasePermission):
    """
    Permits access to Super Admin, Admin, and Stock Manager roles.
    Requires active user account and active profile status.
    """
    message = "Stock management or Administrator privileges are required for this action."

    def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            return False
        if request.user.is_superuser:
            return True
        if not request.user.is_active:
            return False
        profile = getattr(request.user, 'profile', None)
        if not profile or profile.status != 'active':
            return False
        return profile.role in ['admin', 'super_admin', 'stock_manager']


class DenyStockManager(BasePermission):
    """
    Explicitly denies access to stock_manager role for financial, billing, customer, and administrative endpoints.
    """
    message = "Stock managers are strictly forbidden from financial, billing, customer, and administrative functions."

    def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            return False
        profile = getattr(request.user, 'profile', None)
        if profile and profile.role == 'stock_manager':
            return False
        return True


class IsSuperAdminRole(BasePermission):
    """
    Strictly restricted to super_admin role or Django superuser.
    """
    message = "Super Admin privileges are required for this action."

    def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            return False
        if request.user.is_superuser:
            return True
        profile = getattr(request.user, 'profile', None)
        return profile is not None and profile.role == 'super_admin'


class IsApprovedFranchise(BasePermission):
    """
    Allows access only to authenticated franchise/dealer users whose account has been approved by admin.
    """
    message = "Your dealer account is pending admin approval."

    def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            return False

        if request.user.is_superuser:
            return True

        profile = getattr(request.user, 'profile', None)
        if not profile:
            return False

        if profile.role in ['admin', 'super_admin']:
            return True

        if profile.role != 'franchise':
            return False

        franchise_profile = getattr(request.user, 'franchise_profile', None)
        if not franchise_profile:
            self.message = "Dealer profile not found."
            return False

        if franchise_profile.status != 'approved':
            if franchise_profile.status == 'rejected':
                self.message = "Your dealer account has been rejected by the administrator."
            else:
                self.message = "Your dealer account is pending admin approval."
            return False

        return True


class IsAdminOrApprovedFranchise(BasePermission):
    def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            return False

        if not request.user.is_active:
            return False

        if request.user.is_superuser:
            return True

        profile = getattr(request.user, 'profile', None)
        if not profile or profile.status != 'active':
            return False

        if profile.role in ['admin', 'super_admin']:
            return True

        if profile.role == 'franchise':
            franchise_profile = getattr(request.user, 'franchise_profile', None)
            return franchise_profile is not None and franchise_profile.status == 'approved'

        return False


class IsCrmStaffOrFranchise(BasePermission):
    """
    Grants access to Super Admin, Admin, Sales Executive, and Approved Franchise for CRM operations.
    Querysets must be appropriately scoped by role.
    """
    def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            return False

        if request.user.is_superuser:
            return True

        profile = getattr(request.user, 'profile', None)
        if not profile:
            return False

        if profile.role in ['admin', 'super_admin', 'sales_executive']:
            return True

        if profile.role == 'franchise':
            franchise_profile = getattr(request.user, 'franchise_profile', None)
            return franchise_profile is not None and franchise_profile.status == 'approved'

        return False


class IsAdminOrFranchiseUser(BasePermission):
    """
    Allows Super Admins, Admins, and any Franchise user (including pending onboarding) to view/upload KYC.
    """
    def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            return False
        if request.user.is_superuser:
            return True
        profile = getattr(request.user, 'profile', None)
        if not profile:
            return False
        return profile.role in ['admin', 'super_admin', 'franchise']



class IsAdminOrSalesExecutiveRole(BasePermission):
    """
    Allows access to Super Admins, Admins, and Sales Executives with server-side query scoping.
    """
    def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            return False
        if request.user.is_superuser:
            return True
        profile = getattr(request.user, 'profile', None)
        return profile is not None and profile.role in ['admin', 'super_admin', 'sales_executive']


class IsProductMasterAdmin(BasePermission):
    """
    Strict permission to guard Company Product Master data.
    Wholesale Dealers (Franchise role), Sales Executives, and Customers
    are strictly forbidden from creating, updating, or deleting:
    - Products
    - Categories
    - BOM Recipes & BOM items
    - Company-wide Pricing & MRP
    - Raw Materials
    - Production Batches

    Only Super Admin and authorized Admins are permitted.
    Attempts by Franchise/Wholesale Dealer will be rejected with HTTP 403 Forbidden.
    """
    message = "Permission Denied: Wholesale Dealers (Franchise) cannot create, update, or delete Product Master data. Products and master catalog are managed exclusively by Company Administration."

    def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            return False

        if request.user.is_superuser:
            return True

        profile = getattr(request.user, 'profile', None)
        if not profile:
            return False

        if profile.role == 'franchise':
            self.message = "Permission Denied: Wholesale Dealers (Franchise) cannot create, update, or delete Product Master data. Products and master catalog are managed exclusively by Company Administration."
            return False

        return profile.role in ['admin', 'super_admin']


class HasGranularPermission(BasePermission):
    """
    Action-level and module-level permission enforcement for operational staff and admin employees.
    - Super admins and Django superusers always have full access.
    - Active account check: user.is_active must be True and profile.status must be 'active'.
    - Operational admins/staff are verified against profile.admin_permissions.
    - Supports module wildcard (e.g. 'orders' satisfies all 'orders:*' actions).
    - Supports action-specific checks (e.g. 'orders:view', 'orders:create', 'orders:edit', 'orders:delete', 'orders:approve', 'orders:export').
    """
    message = "Permission Denied: You do not have the required administrative permission for this action."

    def __init__(self, module=None, action=None):
        self.module = module
        self.action = action

    def __call__(self):
        return self

    def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            return False

        if not request.user.is_active:
            self.message = "Your account is deactivated. Access denied."
            return False

        profile = getattr(request.user, 'profile', None)
        if not profile or profile.status != 'active':
            self.message = "Your account profile status is suspended/inactive. Access denied."
            return False

        if request.user.is_superuser or profile.role == 'super_admin':
            return True

        # Non-admin / non-staff roles cannot use admin endpoints
        if profile.role in ['customer', 'franchise']:
            self.message = "Administrative access required."
            return False

        module = getattr(view, 'permission_module', None) or self.module
        action = getattr(view, 'permission_action', None) or self.action

        if not module or not action:
            resolved_mod, resolved_act = resolve_module_and_action(request, view)
            module = module or resolved_mod
            action = action or resolved_act

        if not check_granular_permission(request.user, module, action):
            self.message = f"Permission Denied: Missing '{module}:{action}' privilege."
            return False

        return True


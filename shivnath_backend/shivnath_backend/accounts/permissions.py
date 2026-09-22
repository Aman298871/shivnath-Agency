from rest_framework.permissions import BasePermission


class IsAdminRole(BasePermission):

    def has_permission(
        self,
        request,
        view
    ):
        if (
            not request.user
            or not request.user.is_authenticated
        ):
            return False

        if request.user.is_superuser:
            return True

        profile = getattr(
            request.user,
            'profile',
            None
        )

        return (
            profile is not None
            and profile.role in ['admin', 'super_admin']
        )


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

        if request.user.is_superuser:
            return True

        profile = getattr(request.user, 'profile', None)
        if not profile:
            return False

        if profile.role in ['admin', 'super_admin']:
            return True

        if profile.role == 'franchise':
            franchise_profile = getattr(request.user, 'franchise_profile', None)
            return franchise_profile is not None and franchise_profile.status == 'approved'

        return False


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

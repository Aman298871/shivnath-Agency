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
            and profile.role == 'admin'
        )


class IsApprovedFranchise(BasePermission):
    """
    Allows access only to authenticated franchise users whose account has been approved by admin.
    """
    message = "Your franchise account is pending admin approval."

    def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            return False

        if request.user.is_superuser:
            return True

        profile = getattr(request.user, 'profile', None)
        if not profile:
            return False

        if profile.role == 'admin':
            return True

        if profile.role != 'franchise':
            return False

        franchise_profile = getattr(request.user, 'franchise_profile', None)
        if not franchise_profile:
            self.message = "Franchise profile not found."
            return False

        if franchise_profile.status != 'approved':
            if franchise_profile.status == 'rejected':
                self.message = "Your franchise account has been rejected by the administrator."
            else:
                self.message = "Your franchise account is pending admin approval."
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

        if profile.role == 'admin':
            return True

        if profile.role == 'franchise':
            franchise_profile = getattr(request.user, 'franchise_profile', None)
            return franchise_profile is not None and franchise_profile.status == 'approved'

        return False
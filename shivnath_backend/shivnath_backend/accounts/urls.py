from django.urls import path

from .views import (
    CustomerRegisterView,
    FranchiseRegisterView,
    LoginView,
    CurrentUserView,
    PendingFranchiseListView,
    FranchiseListView,
    ApproveFranchiseView,
    RejectFranchiseView,
    UpdateFranchiseView,
    DeleteFranchiseView,
    AdminCreateFranchiseView,
    AdminUserListView,
    AdminNotificationListView,
    ZoneResolutionView,
    TerritoryMasterView,
    EligibleFranchisesView,
    CustomerServiceStatusView,
    FranchiseCustomerListView,
    FranchiseNotificationListView,
    SupportContactView,
)


urlpatterns = [
    # Registration
    path(
        'register/customer/',
        CustomerRegisterView.as_view(),
        name='customer-register'
    ),

    path(
        'register/franchise/',
        FranchiseRegisterView.as_view(),
        name='franchise-register'
    ),

    # Dynamic Territory & Zone Resolution
    path(
        'resolve-zone/',
        ZoneResolutionView.as_view(),
        name='resolve-zone'
    ),
    path(
        'territory-master/',
        TerritoryMasterView.as_view(),
        name='territory-master'
    ),
    path(
        'eligible-franchises/',
        EligibleFranchisesView.as_view(),
        name='eligible-franchises'
    ),

    # Service Lifecycle (Hold / Resume)
    path(
        'service-status/',
        CustomerServiceStatusView.as_view(),
        name='customer-service-status'
    ),

    # Franchise Customer Portal & Isolation
    path(
        'franchise-customers/',
        FranchiseCustomerListView.as_view(),
        name='franchise-customers'
    ),
    path(
        'franchise-notifications/',
        FranchiseNotificationListView.as_view(),
        name='franchise-notifications'
    ),

    # Contextual Support Contacts
    path(
        'support-contact/',
        SupportContactView.as_view(),
        name='support-contact'
    ),

    # Authentication
    path(
        'login/',
        LoginView.as_view(),
        name='login'
    ),

    path(
        'me/',
        CurrentUserView.as_view(),
        name='current-user'
    ),

    # Admin Franchise Management
    path(
        'franchises/',
        FranchiseListView.as_view(),
        name='franchise-list'
    ),

    path(
        'franchises/pending/',
        PendingFranchiseListView.as_view(),
        name='pending-franchises'
    ),

    path(
        'franchises/<int:pk>/approve/',
        ApproveFranchiseView.as_view(),
        name='approve-franchise'
    ),
    path(
        'franchises/create/',
        AdminCreateFranchiseView.as_view(),
        name='admin-create-franchise',
    ),
    path(
        'franchises/<int:pk>/reject/',
        RejectFranchiseView.as_view(),
        name='reject-franchise'
    ),
    path(
        'franchises/<int:pk>/update/',
        UpdateFranchiseView.as_view(),
        name='update-franchise'
    ),
    path(
        'franchises/<int:pk>/delete/',
        DeleteFranchiseView.as_view(),
        name='delete-franchise'
    ),

    # Admin Directory & Notifications
    path(
        'users/',
        AdminUserListView.as_view(),
        name='admin-users'
    ),
    path(
        'notifications/',
        AdminNotificationListView.as_view(),
        name='admin-notifications'
    ),
]
"""
URL configuration for config project.

The `urlpatterns` list routes URLs to views. For more information please see:
    https://docs.djangoproject.com/en/6.1/topics/http/urls/
Examples:
Function views
    1. Add an import:  from my_app import views
    2. Add a URL to urlpatterns:  path('', views.home, name='home')
Class-based views
    1. Add an import:  from other_app.views import Home
    2. Add a URL to urlpatterns:  path('', Home.as_view(), name='home')
Including another URLconf
    1. Import the include() function: from django.urls import include, path
    2. Add a URL to urlpatterns:  path('blog/', include('blog.urls'))
"""
from django.contrib import admin
from django.urls import path, include

from rest_framework_simplejwt.views import (
    TokenRefreshView,
)


from django.http import JsonResponse
from django.db import connection
from pathlib import Path

def root_health_view(request):
    db_engine = settings.DATABASES['default'].get('ENGINE', 'unknown')
    raw_name = str(settings.DATABASES['default'].get('NAME', 'unknown'))
    safe_db_name = Path(raw_name).name if ('/' in raw_name or '\\' in raw_name) else raw_name

    db_connected = False
    try:
        connection.ensure_connection()
        db_connected = True
    except Exception:
        db_connected = False

    return JsonResponse({
        'status': 'online',
        'service': 'Shivnath Agency Pure Water Platform API',
        'admin_panel': '/admin/',
        'version': '1.0.0',
        'database': {
            'engine': db_engine,
            'name': safe_db_name,
            'connected': db_connected,
            'is_postgresql': 'postgresql' in db_engine,
            'is_sqlite': 'sqlite' in db_engine,
        }
    })

from django.conf import settings
from django.conf.urls.static import static

from accounts.privacy_and_deletion_views import (
    privacy_policy_html_view,
    public_account_deletion_html_view,
)

urlpatterns = [

    # Root Health Check & Safe Database Diagnostics
    path('', root_health_view, name='root_health'),
    path('api/health/', root_health_view, name='api_health'),
    path('api/system/db-status/', root_health_view, name='api_db_status'),

    # Public Legal & Google Play Compliance Pages
    path('privacy-policy/', privacy_policy_html_view, name='privacy_policy_html'),
    path('legal/privacy-policy/', privacy_policy_html_view, name='legal_privacy_policy_html'),
    path('account-deletion/', public_account_deletion_html_view, name='public_account_deletion_html'),
    path('legal/delete-account/', public_account_deletion_html_view, name='legal_delete_account_html'),

    # Jazzmin / Django Admin
    path(
        'admin/',
        admin.site.urls
    ),

    # Authentication & Accounts
    path(
        'api/auth/',
        include('accounts.urls')
    ),
    path(
        'api/accounts/',
        include('accounts.urls')
    ),
    path(
        'api/notifications/',
        include('accounts.urls')
    ),

    # JWT refresh
    path(
        'api/auth/refresh/',
        TokenRefreshView.as_view(),
        name='token_refresh'
    ),
    path(
        'api/leads/',
        include(
            'leads.urls'
        )
    ),
    path(
    "api/followups/",
    include("followups.urls"),
),
    path(
        "api/inventory/",
        include("inventory.urls"),
    ),
    path(
        "api/products/",
        include("products.urls"),
    ),
    path(
            "api/suppliers/",
            include("suppliers.urls"),
        ),
    path(
        "api/orders/",
        include("orders.urls"),
    ),
    path(
        "api/billing/",
        include("billing.urls"),
    ),
    path(
        "api/chat/",
        include("chat.urls"),
    ),
]

if settings.MEDIA_ROOT:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)


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

def root_health_view(request):
    return JsonResponse({
        'status': 'online',
        'service': 'Shivnath Agency Pure Water Platform API',
        'admin_panel': '/admin/',
        'version': '1.0.0'
    })

from django.conf import settings
from django.conf.urls.static import static

urlpatterns = [

    # Root Health Check
    path('', root_health_view, name='root_health'),

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
        "api/chat/",
        include("chat.urls"),
    ),
]

if settings.MEDIA_ROOT:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)


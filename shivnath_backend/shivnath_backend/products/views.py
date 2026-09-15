from django.db.models import Q

from django.shortcuts import get_object_or_404

from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status

from rest_framework.permissions import AllowAny

from accounts.permissions import IsAdminRole

from .models import Product
from .serializers import ProductSerializer


# =====================================================
# PRODUCT LIST + CREATE
# =====================================================

class ProductListCreateView(APIView):

    def get_permissions(self):
        if self.request.method == 'GET':
            return [AllowAny()]
        return [IsAdminRole()]

    def get(self, request):

        queryset = Product.objects.all()

        # Check if user is admin
        is_admin = False
        if request.user and request.user.is_authenticated:
            if request.user.is_superuser:
                is_admin = True
            else:
                profile = getattr(request.user, 'profile', None)
                if profile and profile.role == 'admin':
                    is_admin = True

        search = request.query_params.get(
            "search",
            ""
        ).strip()

        category = request.query_params.get(
            "category",
            ""
        ).strip()

        product_status = request.query_params.get(
            "status",
            ""
        ).strip()

        if search:

            queryset = queryset.filter(
                Q(name__icontains=search)
                |
                Q(sku__icontains=search)
            )

        if category:

            queryset = queryset.filter(
                category=category
            )

        if product_status:

            queryset = queryset.filter(
                status=product_status
            )

        serializer = ProductSerializer(
            queryset,
            many=True,
        )

        return Response({

            "success": True,

            "count": queryset.count(),

            "products": serializer.data,

        })

    def post(self, request):

        serializer = ProductSerializer(
            data=request.data,
        )

        if not serializer.is_valid():

            return Response({

                "success": False,

                "errors": serializer.errors,

            }, status=400)

        product = serializer.save()

        return Response({

            "success": True,

            "message": "Product created successfully.",

            "product": ProductSerializer(product).data,

        }, status=201)


# =====================================================
# PRODUCT DETAIL
# =====================================================

class ProductDetailView(APIView):

    def get_permissions(self):
        if self.request.method == 'GET':
            return [AllowAny()]
        return [IsAdminRole()]

    def get(self, request, pk):

        product = get_object_or_404(
            Product,
            pk=pk,
        )

        return Response({

            "success": True,

            "product": ProductSerializer(
                product
            ).data

        })

    def patch(self, request, pk):

        product = get_object_or_404(
            Product,
            pk=pk,
        )

        serializer = ProductSerializer(

            product,

            data=request.data,

            partial=True,

        )

        if not serializer.is_valid():

            return Response({

                "success": False,

                "errors": serializer.errors,

            }, status=400)

        serializer.save()

        return Response({

            "success": True,

            "message": "Product updated successfully.",

            "product": serializer.data,

        })

    def delete(self, request, pk):

        product = get_object_or_404(
            Product,
            pk=pk,
        )

        product.delete()

        return Response({

            "success": True,

            "message": "Product deleted successfully.",

        })


# =====================================================
# PRODUCT STATS
# =====================================================

class ProductStatsView(APIView):

    permission_classes = [
        IsAdminRole
    ]

    def get(self, request):

        total = Product.objects.count()

        active = Product.objects.filter(
            status="Active"
        ).count()

        bottle = Product.objects.filter(
            category="Bottle"
        ).count()

        jar = Product.objects.filter(
            category="Jar"
        ).count()

        low_stock = Product.objects.filter(
            stock__lte=100
        ).count()

        return Response({

            "success": True,

            "stats": {

                "total_products": total,

                "active_products": active,

                "bottle_products": bottle,

                "jar_products": jar,

                "low_stock": low_stock,

            }

        })
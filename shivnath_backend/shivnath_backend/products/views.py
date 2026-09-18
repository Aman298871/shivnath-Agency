from django.db.models import Q
from django.shortcuts import get_object_or_404
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from rest_framework.permissions import AllowAny
from accounts.permissions import IsAdminRole

from .models import Product, ProductCategory
from .serializers import ProductSerializer, ProductCategorySerializer


# =====================================================
# CATEGORY LIST + CREATE
# =====================================================

class CategoryListCreateView(APIView):
    def get_permissions(self):
        if self.request.method == "GET":
            return [AllowAny()]
        return [IsAdminRole()]

    def get(self, request):
        tree_only = request.query_params.get("tree", "").lower() in ["true", "1"]
        active_only = request.query_params.get("active_only", "").lower() in ["true", "1"]
        include_inactive = request.query_params.get("include_inactive", "").lower() in ["true", "1"]

        queryset = ProductCategory.objects.all().order_by("order", "name")
        if active_only or not include_inactive:
            queryset = queryset.filter(is_active=True)

        if tree_only:
            # Return top-level categories which nest their children
            root_categories = queryset.filter(parent__isnull=True)
            serializer = ProductCategorySerializer(root_categories, many=True, context={"request": request})
        else:
            serializer = ProductCategorySerializer(queryset, many=True, context={"request": request})

        return Response({
            "success": True,
            "count": queryset.count(),
            "categories": serializer.data,
        })

    def post(self, request):
        serializer = ProductCategorySerializer(data=request.data, context={"request": request})
        if not serializer.is_valid():
            return Response({"success": False, "errors": serializer.errors}, status=400)
        category = serializer.save()
        return Response({
            "success": True,
            "message": "Category created successfully.",
            "category": ProductCategorySerializer(category, context={"request": request}).data,
        }, status=201)


class CategoryDetailView(APIView):
    def get_permissions(self):
        if self.request.method == "GET":
            return [AllowAny()]
        return [IsAdminRole()]

    def get(self, request, pk):
        category = get_object_or_404(ProductCategory, pk=pk)
        return Response({
            "success": True,
            "category": ProductCategorySerializer(category, context={"request": request}).data,
        })

    def patch(self, request, pk):
        category = get_object_or_404(ProductCategory, pk=pk)
        serializer = ProductCategorySerializer(category, data=request.data, partial=True, context={"request": request})
        if not serializer.is_valid():
            return Response({"success": False, "errors": serializer.errors}, status=400)
        updated = serializer.save()
        return Response({
            "success": True,
            "message": "Category updated successfully.",
            "category": ProductCategorySerializer(updated, context={"request": request}).data,
        })

    def delete(self, request, pk):
        category = get_object_or_404(ProductCategory, pk=pk)
        has_children = category.children.filter(is_active=True).exists()
        has_products = category.products.exists()

        if has_children or has_products:
            return Response({
                "success": False,
                "error": "cannot_delete_with_dependencies",
                "message": (
                    "This category has active children or assigned products. "
                    "Archive it, reassign products, or delete children first."
                ),
                "children_count": category.children.count(),
                "product_count": category.products.count(),
            }, status=status.HTTP_400_BAD_REQUEST)

        # Archive (soft-delete) instead of hard-delete
        category.is_active = False
        category.save(update_fields=["is_active", "updated_at"])
        return Response({
            "success": True,
            "message": "Category archived successfully.",
        })


# =====================================================
# PRODUCT LIST + CREATE
# =====================================================

class ProductListCreateView(APIView):
    def get_permissions(self):
        if self.request.method == 'GET':
            return [AllowAny()]
        return [IsAdminRole()]

    def get(self, request):
        queryset = Product.objects.select_related("category_ref").all()

        search = request.query_params.get("search", "").strip()
        category = request.query_params.get("category", "").strip()
        category_id = request.query_params.get("category_id", "").strip()
        product_status = request.query_params.get("status", "").strip()

        if search:
            queryset = queryset.filter(
                Q(name__icontains=search)
                | Q(sku__icontains=search)
                | Q(size__icontains=search)
                | Q(description__icontains=search)
            )

        if category_id and category_id.isdigit():
            cat_id = int(category_id)
            try:
                cat = ProductCategory.objects.get(pk=cat_id)
                all_cat_ids = cat.get_descendant_ids()
            except ProductCategory.DoesNotExist:
                all_cat_ids = [cat_id]
            queryset = queryset.filter(category_ref_id__in=all_cat_ids)
        elif category and category.lower() != "all":
            queryset = queryset.filter(
                Q(category__iexact=category)
                | Q(category_ref__name__iexact=category)
                | Q(category_ref__parent__name__iexact=category)
            )

        if product_status:
            queryset = queryset.filter(status=product_status)

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
        product = get_object_or_404(Product.objects.select_related("category_ref"), pk=pk)
        return Response({
            "success": True,
            "product": ProductSerializer(product).data,
        })

    def patch(self, request, pk):
        product = get_object_or_404(Product, pk=pk)
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
        product = get_object_or_404(Product, pk=pk)
        product.delete()
        return Response({
            "success": True,
            "message": "Product deleted successfully.",
        })


# =====================================================
# PRODUCT STATS
# =====================================================

class ProductStatsView(APIView):
    permission_classes = [IsAdminRole]

    def get(self, request):
        total = Product.objects.count()
        active = Product.objects.filter(status="Active").count()
        bottle = Product.objects.filter(Q(category__icontains="Bottle") | Q(category_ref__name__icontains="Bottle")).count()
        jar = Product.objects.filter(Q(category__icontains="Jar") | Q(category_ref__name__icontains="Jar")).count()
        low_stock = Product.objects.filter(stock__lte=100).count()
        categories_count = ProductCategory.objects.count()

        return Response({
            "success": True,
            "stats": {
                "total_products": total,
                "active_products": active,
                "bottle_products": bottle,
                "jar_products": jar,
                "low_stock": low_stock,
                "total_categories": categories_count,
            }
        })
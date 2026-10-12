from django.db.models import Q
from django.shortcuts import get_object_or_404
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from rest_framework.permissions import AllowAny
from accounts.permissions import IsAdminRole, IsSuperAdminRole, IsProductMasterAdmin

from .models import Product, ProductCategory, ProductionRecipeBOM, ProductionRecipeBOMItem, ProductStockThreshold
from .serializers import (
    ProductSerializer,
    ProductCategorySerializer,
    ProductionRecipeBOMSerializer,
    ProductionRecipeBOMItemSerializer,
    ProductStockThresholdSerializer,
)
from inventory.models import RawMaterial


# =====================================================
# CATEGORY LIST + CREATE
# =====================================================

class CategoryListCreateView(APIView):
    def get_permissions(self):
        if self.request.method == "GET":
            return [AllowAny()]
        return [IsProductMasterAdmin()]

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
        return [IsProductMasterAdmin()]

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
        return [IsProductMasterAdmin()]

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
            c_low = category.lower()
            if "bottle" in c_low:
                queryset = queryset.filter(
                    Q(category__icontains="bottle")
                    | Q(package_type="BOTTLE")
                    | Q(category_ref__name__icontains="bottle")
                    | Q(category_ref__parent__name__icontains="bottle")
                )
            elif "jar" in c_low:
                queryset = queryset.filter(
                    Q(category__icontains="jar")
                    | Q(package_type="JAR")
                    | Q(category_ref__name__icontains="jar")
                    | Q(category_ref__parent__name__icontains="jar")
                )
            else:
                queryset = queryset.filter(
                    Q(category__iexact=category)
                    | Q(category__icontains=category)
                    | Q(category_ref__name__iexact=category)
                    | Q(category_ref__parent__name__iexact=category)
                )

        include_inactive = request.query_params.get("include_inactive", "").strip().lower() in ["true", "1"]
        active_only = request.query_params.get("active_only", "").strip().lower() in ["true", "1"]

        user = getattr(request, 'user', None)
        is_admin_user = bool(
            user and user.is_authenticated and (
                user.is_superuser or
                user.is_staff or
                getattr(getattr(user, 'profile', None), 'role', '') in ['admin', 'super_admin']
            )
        )

        if product_status:
            if not is_admin_user and product_status.lower() != 'active':
                queryset = queryset.filter(status="Active")
            else:
                queryset = queryset.filter(status=product_status)
        elif not is_admin_user or (not include_inactive or active_only):
            queryset = queryset.filter(status="Active")

        queryset = queryset.order_by("volume_ml", "name")

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
        return [IsProductMasterAdmin()]

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


# =====================================================
# BOM RECIPE MASTER EDITOR (SUPER ADMIN / ADMIN)
# =====================================================

class ProductBOMDetailView(APIView):
    def get_permissions(self):
        if self.request.method == "GET":
            return [IsAdminRole()]
        return [IsSuperAdminRole()]

    def get(self, request, pk):
        product = get_object_or_404(Product, pk=pk)
        bom, _ = ProductionRecipeBOM.objects.get_or_create(product=product)
        serializer = ProductionRecipeBOMSerializer(bom)
        bom_data = dict(serializer.data)
        bom_data["pricing"] = {
            "dealer_wholesale_price": float(product.dealer_transfer_price),
            "retail_mrp": float(product.mrp),
            "minimum_order_quantity_cases": getattr(product, "units_per_case", 10),
            "units_per_case": getattr(product, "units_per_case", 24),
            "customer_price": float(product.price),
        }
        threshold = getattr(product, "stock_threshold", None)
        bom_data["minimum_stock_threshold"] = threshold.company_low_stock_threshold if threshold else 500
        is_bom_configured = bom.items.exists()
        bom_data["is_configured"] = is_bom_configured
        return Response({
            "success": True,
            "is_configured": is_bom_configured,
            "bom": bom_data,
            "data": bom_data,
            "raw_materials_available": [
                {
                    "id": rm.id,
                    "name": rm.name,
                    "sku": rm.sku,
                    "category": rm.category,
                    "unit_of_measure": rm.unit_of_measure,
                    "unit_cost": float(rm.unit_cost),
                    "current_stock": float(rm.current_stock),
                }
                for rm in RawMaterial.objects.filter(is_active=True).order_by("name")
            ],
        })


class ProductBOMItemManageView(APIView):
    permission_classes = [IsSuperAdminRole]

    def post(self, request, pk):
        """Add or update a line item in product's recipe BOM."""
        product = get_object_or_404(Product, pk=pk)
        bom, _ = ProductionRecipeBOM.objects.get_or_create(product=product)

        raw_material_id = request.data.get("raw_material_id") or request.data.get("raw_material")
        quantity_required = (
            request.data.get("quantity_required_per_unit")
            if request.data.get("quantity_required_per_unit") is not None
            else (
                request.data.get("quantity_required")
                if request.data.get("quantity_required") is not None
                else request.data.get("quantity")
            )
        )
        unit_cost = (
            request.data.get("unit_cost_snapshot")
            if request.data.get("unit_cost_snapshot") is not None
            else (
                request.data.get("cost_basis")
                if request.data.get("cost_basis") is not None
                else request.data.get("unit_cost")
            )
        )
        notes = request.data.get("notes", "")

        if not raw_material_id or quantity_required is None:
            return Response({
                "success": False,
                "error": "missing_required_fields",
                "message": "raw_material_id and quantity_required_per_unit are required.",
            }, status=status.HTTP_400_BAD_REQUEST)

        raw_material = get_object_or_404(RawMaterial, pk=raw_material_id)

        try:
            qty = float(quantity_required)
            if qty <= 0:
                raise ValueError()
        except (ValueError, TypeError):
            return Response({"success": False, "message": "quantity_required_per_unit must be a positive number."}, status=400)

        cost = float(unit_cost) if unit_cost is not None else float(raw_material.unit_cost)

        item, created = ProductionRecipeBOMItem.objects.update_or_create(
            bom=bom,
            raw_material=raw_material,
            defaults={
                "quantity_required_per_unit": qty,
                "unit_cost_snapshot": cost,
                "notes": notes,
            }
        )

        bom.last_updated_by = request.user
        bom.save(update_fields=["last_updated_by", "updated_at"])

        return Response({
            "success": True,
            "message": "BOM item saved successfully.",
            "item": ProductionRecipeBOMItemSerializer(item).data,
            "total_production_cost_per_unit": float(bom.total_production_cost_per_unit),
        }, status=status.HTTP_201_CREATED if created else status.HTTP_200_OK)

    def delete(self, request, pk, item_id):
        """Remove a raw material item from the product's recipe BOM."""
        product = get_object_or_404(Product, pk=pk)
        bom = get_object_or_404(ProductionRecipeBOM, product=product)
        item = get_object_or_404(ProductionRecipeBOMItem, bom=bom, pk=item_id)
        item.delete()

        bom.last_updated_by = request.user
        bom.save(update_fields=["last_updated_by", "updated_at"])

        return Response({
            "success": True,
            "message": "BOM item removed successfully.",
            "total_production_cost_per_unit": float(bom.total_production_cost_per_unit),
        })


# =====================================================
# MASTER PRICING CONFIGURATION (SUPER ADMIN)
# =====================================================

class ProductPricingUpdateView(APIView):
    permission_classes = [IsSuperAdminRole]

    def patch(self, request, pk):
        product = get_object_or_404(Product, pk=pk)

        retail_price = request.data.get("price") or request.data.get("customer_price")
        dealer_transfer_price = (
            request.data.get("dealer_transfer_price")
            if request.data.get("dealer_transfer_price") is not None
            else (
                request.data.get("dealer_wholesale_price")
                if request.data.get("dealer_wholesale_price") is not None
                else request.data.get("wholesale_price")
            )
        )
        mrp = (
            request.data.get("mrp")
            if request.data.get("mrp") is not None
            else request.data.get("retail_mrp")
        )
        gst = request.data.get("gst")
        units_per_case = (
            request.data.get("units_per_case")
            if request.data.get("units_per_case") is not None
            else request.data.get("minimum_order_quantity_cases")
        )

        update_fields = ["updated_at"]

        if retail_price is not None:
            try:
                p = float(retail_price)
                if p < 0:
                    raise ValueError()
                product.price = p
                update_fields.append("price")
            except (ValueError, TypeError):
                return Response({"success": False, "message": "Invalid price value."}, status=400)

        if dealer_transfer_price is not None:
            try:
                dtp = float(dealer_transfer_price)
                if dtp < 0:
                    raise ValueError()
                product.dealer_transfer_price = dtp
                update_fields.append("dealer_transfer_price")
            except (ValueError, TypeError):
                return Response({"success": False, "message": "Invalid dealer_transfer_price value."}, status=400)

        if mrp is not None:
            try:
                m = float(mrp)
                if m < 0:
                    raise ValueError()
                product.mrp = m
                update_fields.append("mrp")
            except (ValueError, TypeError):
                return Response({"success": False, "message": "Invalid mrp value."}, status=400)

        if gst is not None:
            try:
                g = int(gst)
                if g < 0 or g > 100:
                    raise ValueError()
                product.gst = g
                update_fields.append("gst")
            except (ValueError, TypeError):
                return Response({"success": False, "message": "GST must be between 0 and 100."}, status=400)

        if units_per_case is not None:
            try:
                u = int(units_per_case)
                if u > 0:
                    product.units_per_case = u
                    update_fields.append("units_per_case")
            except (ValueError, TypeError):
                pass

        product.save(update_fields=update_fields)

        return Response({
            "success": True,
            "message": "Product pricing updated successfully.",
            "product": ProductSerializer(product).data,
        })


# =====================================================
# PRODUCT STOCK THRESHOLDS
# =====================================================

class ProductStockThresholdView(APIView):
    permission_classes = [IsAdminRole]

    def get(self, request, pk):
        product = get_object_or_404(Product, pk=pk)
        threshold, _ = ProductStockThreshold.objects.get_or_create(product=product)
        return Response({
            "success": True,
            "threshold": ProductStockThresholdSerializer(threshold).data,
        })

    def patch(self, request, pk):
        product = get_object_or_404(Product, pk=pk)
        threshold, _ = ProductStockThreshold.objects.get_or_create(product=product)
        serializer = ProductStockThresholdSerializer(threshold, data=request.data, partial=True)
        if not serializer.is_valid():
            return Response({"success": False, "errors": serializer.errors}, status=400)
        serializer.save()
        return Response({
            "success": True,
            "message": "Stock threshold updated successfully.",
            "threshold": serializer.data,
        })
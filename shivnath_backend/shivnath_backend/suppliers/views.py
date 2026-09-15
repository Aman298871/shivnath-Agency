from django.db.models import Q
from django.shortcuts import get_object_or_404

from rest_framework.views import APIView
from rest_framework.response import Response

from accounts.permissions import IsAdminRole

from .models import Supplier
from .serializers import SupplierSerializer


# =====================================================
# SUPPLIER LIST + CREATE
# =====================================================

class SupplierListCreateView(APIView):

    permission_classes = [
        IsAdminRole
    ]

    def get(self, request):

        queryset = Supplier.objects.all()

        search = request.query_params.get(
            "search",
            ""
        ).strip()

        status_filter = request.query_params.get(
            "status",
            ""
        ).strip()

        category = request.query_params.get(
            "category",
            ""
        ).strip()

        if search:

            queryset = queryset.filter(

                Q(name__icontains=search)

                |

                Q(contact__icontains=search)

                |

                Q(phone__icontains=search)

                |

                Q(email__icontains=search)

                |

                Q(city__icontains=search)

                |

                Q(gst__icontains=search)

            )

        if status_filter:

            queryset = queryset.filter(
                status=status_filter
            )

        if category:

            queryset = queryset.filter(
                category=category
            )

        serializer = SupplierSerializer(
            queryset,
            many=True,
        )

        return Response({

            "success": True,

            "count": queryset.count(),

            "suppliers": serializer.data,

        })

    def post(self, request):

        serializer = SupplierSerializer(
            data=request.data,
        )

        if not serializer.is_valid():

            return Response({

                "success": False,

                "errors": serializer.errors,

            }, status=400)

        supplier = serializer.save()

        return Response({

            "success": True,

            "message": "Supplier created successfully.",

            "supplier": SupplierSerializer(
                supplier
            ).data,

        }, status=201)


# =====================================================
# SUPPLIER DETAIL
# =====================================================

class SupplierDetailView(APIView):

    permission_classes = [
        IsAdminRole
    ]

    def get(self, request, pk):

        supplier = get_object_or_404(
            Supplier,
            pk=pk,
        )

        return Response({

            "success": True,

            "supplier": SupplierSerializer(
                supplier
            ).data

        })

    def patch(self, request, pk):

        supplier = get_object_or_404(
            Supplier,
            pk=pk,
        )

        serializer = SupplierSerializer(

            supplier,

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

            "message": "Supplier updated successfully.",

            "supplier": serializer.data,

        })

    def delete(self, request, pk):

        supplier = get_object_or_404(
            Supplier,
            pk=pk,
        )

        supplier.delete()

        return Response({

            "success": True,

            "message": "Supplier deleted successfully.",

        })


# =====================================================
# SUPPLIER STATS
# =====================================================

class SupplierStatsView(APIView):

    permission_classes = [
        IsAdminRole
    ]

    def get(self, request):

        total = Supplier.objects.count()

        active = Supplier.objects.filter(
            status="Active"
        ).count()

        inactive = Supplier.objects.filter(
            status="Inactive"
        ).count()

        return Response({

            "success": True,

            "stats": {

                "total_suppliers": total,

                "active_suppliers": active,

                "inactive_suppliers": inactive,

            }

        })
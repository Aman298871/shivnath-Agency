from django.shortcuts import get_object_or_404
from django.db.models import Q, Sum

from rest_framework import status
from rest_framework.response import Response
from rest_framework.views import APIView

from rest_framework.permissions import AllowAny, IsAuthenticated
from accounts.permissions import IsAdminRole, IsApprovedFranchise, IsAdminOrApprovedFranchise

from .models import Order
from .serializers import OrderSerializer


# =========================================================
# ORDER LIST + CREATE
# =========================================================

class OrderListCreateView(APIView):
    permission_classes = [AllowAny]

    def get(self, request):

        user = request.user if (request.user and request.user.is_authenticated) else None

        if not user:
            phone = request.query_params.get('phone', '').strip()
            if phone:
                orders = Order.objects.filter(
                    Q(created_by__profile__phone=phone)
                    | Q(created_by__username=phone)
                    | Q(franchise_name__icontains=phone)
                )
            else:
                orders = Order.objects.all()
        else:
            profile = getattr(user, 'profile', None)
            role = profile.role if profile else 'customer'
            if user.is_superuser or role == 'admin' or user.is_staff:
                orders = Order.objects.select_related('created_by').all()
            elif role == 'franchise':
                business_name = getattr(getattr(user, 'franchise_profile', None), 'business_name', '')
                orders = Order.objects.filter(
                    Q(created_by=user)
                    | (Q(franchise_name__iexact=business_name) if business_name else Q())
                    | Q(franchise_name__icontains=user.email)
                ).distinct()
            else:
                orders = Order.objects.filter(
                    Q(created_by=user)
                    | Q(created_by__isnull=True)
                )

        search = request.query_params.get(
            'search', ''
        ).strip()

        if search:
            orders = orders.filter(
                Q(franchise_name__icontains=search)
                | Q(city__icontains=search)
                | Q(id__icontains=search)
            )

        order_status = request.query_params.get(
            'status', ''
        ).strip()

        if order_status:
            orders = orders.filter(status=order_status)

        serializer = OrderSerializer(orders, many=True)

        return Response(
            {
                'success': True,
                'count': orders.count(),
                'orders': serializer.data,
            },
            status=status.HTTP_200_OK,
        )

    def post(self, request):
        creator = request.user if (request.user and request.user.is_authenticated) else None

        serializer = OrderSerializer(data=request.data)

        if not serializer.is_valid():
            return Response(
                {
                    'success': False,
                    'errors': serializer.errors,
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        order = serializer.save(
            created_by=creator
        )

        return Response(
            {
                'success': True,
                'message': 'Order created successfully.',
                'order': OrderSerializer(order).data,
            },
            status=status.HTTP_201_CREATED,
        )


# =========================================================
# ORDER DETAIL + UPDATE + DELETE
# =========================================================

class OrderDetailView(APIView):

    permission_classes = [IsAdminRole]

    def get(self, request, pk):
        order = get_object_or_404(Order, pk=pk)

        return Response(
            {
                'success': True,
                'order': OrderSerializer(order).data,
            }
        )

    def put(self, request, pk):
        return self._update(request, pk, partial=False)

    def patch(self, request, pk):
        return self._update(request, pk, partial=True)

    def _update(self, request, pk, partial):

        order = get_object_or_404(Order, pk=pk)

        serializer = OrderSerializer(
            order,
            data=request.data,
            partial=partial,
        )

        if not serializer.is_valid():
            return Response(
                {
                    'success': False,
                    'errors': serializer.errors,
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        updated_order = serializer.save()

        return Response(
            {
                'success': True,
                'message': 'Order updated successfully.',
                'order': OrderSerializer(updated_order).data,
            }
        )

    def delete(self, request, pk):
        order = get_object_or_404(Order, pk=pk)
        order_code = order.order_code
        order.delete()

        return Response(
            {
                'success': True,
                'message': f'{order_code} deleted successfully.',
            }
        )


# =========================================================
# ORDER STATUS UPDATE (dedicated endpoint, used by dialog)
# =========================================================

class OrderStatusUpdateView(APIView):

    permission_classes = [IsAdminRole]

    def patch(self, request, pk):

        order = get_object_or_404(Order, pk=pk)

        new_status = request.data.get('status', '').strip()

        valid_statuses = dict(Order.STATUS_CHOICES).keys()

        if new_status not in valid_statuses:
            return Response(
                {
                    'success': False,
                    'message': 'Invalid order status.',
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        order.status = new_status
        order.save()

        return Response(
            {
                'success': True,
                'message': f'{order.order_code} status changed successfully.',
                'order': OrderSerializer(order).data,
            }
        )


# =========================================================
# ORDER STATS
# =========================================================

class OrderStatsView(APIView):

    permission_classes = [IsAdminRole]

    def get(self, request):

        orders = Order.objects.all()

        total_orders = orders.count()

        approval_pending = orders.filter(
            status='plant_approval'
        ).count()

        in_dispatch = orders.filter(
            status='dispatch'
        ).count()

        order_value = orders.aggregate(
            total=Sum('amount')
        )['total'] or 0

        return Response(
            {
                'success': True,
                'stats': {
                    'total_orders': total_orders,
                    'approval_pending': approval_pending,
                    'in_dispatch': in_dispatch,
                    'order_value': float(order_value),
                },
            }
        )
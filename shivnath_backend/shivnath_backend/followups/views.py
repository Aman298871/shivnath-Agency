from django.shortcuts import get_object_or_404
from django.utils import timezone
from django.db.models import Count

from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status

from accounts.permissions import IsAdminRole

from leads.models import Lead

from .models import FollowUp
from .serializers import FollowUpSerializer


# ==========================================
# LIST + CREATE
# ==========================================

class FollowUpListCreateView(APIView):

    permission_classes = [
        IsAdminRole
    ]

    def get(self, request):

        queryset = (
            FollowUp.objects
            .select_related("lead")
            .select_related("created_by")
            .all()
        )

        serializer = FollowUpSerializer(
            queryset,
            many=True,
        )

        return Response({
            "success": True,
            "count": queryset.count(),
            "followups": serializer.data,
        })

    def post(self, request):

        lead_id = request.data.get("lead_id")

        if not lead_id:
            return Response(
                {
                    "success": False,
                    "message": "lead_id is required."
                },
                status=400,
            )

        lead = get_object_or_404(
            Lead,
            pk=lead_id,
        )

        serializer = FollowUpSerializer(
            data=request.data,
        )

        if not serializer.is_valid():

            return Response(
                {
                    "success": False,
                    "errors": serializer.errors,
                },
                status=400,
            )

        followup = serializer.save(
            lead=lead,
            created_by=request.user,
        )

        return Response(
            {
                "success": True,
                "message": "Follow-up created successfully.",
                "followup": FollowUpSerializer(followup).data,
            },
            status=201,
        )


# ==========================================
# DETAIL
# ==========================================

class FollowUpDetailView(APIView):

    permission_classes = [
        IsAdminRole
    ]

    def patch(self, request, pk):

        followup = get_object_or_404(
            FollowUp,
            pk=pk,
        )

        serializer = FollowUpSerializer(
            followup,
            data=request.data,
            partial=True,
        )

        if not serializer.is_valid():

            return Response(
                {
                    "success": False,
                    "errors": serializer.errors,
                },
                status=400,
            )

        serializer.save()

        return Response({
            "success": True,
            "message": "Follow-up updated successfully.",
            "followup": serializer.data,
        })

    def delete(self, request, pk):

        followup = get_object_or_404(
            FollowUp,
            pk=pk,
        )

        followup.delete()

        return Response({
            "success": True,
            "message": "Follow-up deleted successfully."
        })


# ==========================================
# COMPLETE
# ==========================================

class CompleteFollowUpView(APIView):

    permission_classes = [
        IsAdminRole
    ]

    def patch(self, request, pk):

        followup = get_object_or_404(
            FollowUp,
            pk=pk,
        )

        followup.status = "Completed"

        followup.completed_at = timezone.now()

        followup.save()

        return Response({
            "success": True,
            "message": "Follow-up completed.",
            "followup": FollowUpSerializer(followup).data,
        })


# ==========================================
# STATS
# ==========================================

class FollowUpStatsView(APIView):

    permission_classes = [
        IsAdminRole
    ]

    def get(self, request):

        today = timezone.localdate()

        today_count = FollowUp.objects.filter(
            followup_datetime__date=today,
            status="Pending",
        ).count()

        overdue = FollowUp.objects.filter(
            followup_datetime__date__lt=today,
            status="Pending",
        ).count()

        upcoming = FollowUp.objects.filter(
            followup_datetime__date__gt=today,
            status="Pending",
        ).count()

        completed = FollowUp.objects.filter(
            status="Completed",
        ).count()

        return Response({
            "success": True,
            "stats": {
                "today": today_count,
                "overdue": overdue,
                "upcoming": upcoming,
                "completed": completed,
            }
        })
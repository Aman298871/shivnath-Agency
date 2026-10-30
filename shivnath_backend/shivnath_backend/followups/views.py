from django.shortcuts import get_object_or_404
from django.utils import timezone
from django.db.models import Count, Q

from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status

from accounts.permissions import IsAdminRole, IsCrmStaffOrFranchise

from leads.models import Lead

from .models import FollowUp
from .serializers import FollowUpSerializer


def get_scoped_followup_queryset(user):
    if not user or not user.is_authenticated:
        return FollowUp.objects.none()
    if user.is_superuser:
        return FollowUp.objects.all()
    profile = getattr(user, 'profile', None)
    role = profile.role if profile else 'admin'
    if role in ['admin', 'super_admin']:
        return FollowUp.objects.all()
    if role == 'franchise':
        fp = getattr(user, 'franchise_profile', None)
        if fp:
            return FollowUp.objects.filter(lead__assigned_franchise=fp)
        return FollowUp.objects.none()
    if role == 'sales_executive':
        p_name = profile.name if profile else ''
        return FollowUp.objects.filter(
            Q(lead__assigned_executive_user=user)
            | Q(created_by=user)
            | Q(lead__created_by=user)
            | Q(lead__assigned_executive=user.username)
            | (Q(lead__assigned_executive=p_name) if p_name else Q())
        )
    return FollowUp.objects.none()


def check_followup_access(user, followup):
    if not user or not user.is_authenticated:
        return False
    if user.is_superuser:
        return True
    profile = getattr(user, 'profile', None)
    role = profile.role if profile else 'admin'
    if role in ['admin', 'super_admin']:
        return True
    if role == 'franchise':
        fp = getattr(user, 'franchise_profile', None)
        return bool(fp and (followup.lead.assigned_franchise_id == fp.id or followup.lead.assigned_franchise_id is None))
    if role == 'sales_executive':
        p_name = profile.name if profile else ''
        return bool(
            followup.lead.assigned_executive_user_id == user.id
            or followup.created_by_id == user.id
            or followup.lead.created_by_id == user.id
            or followup.lead.assigned_executive == user.username
            or (p_name and followup.lead.assigned_executive == p_name)
        )
    return False


# ==========================================
# LIST + CREATE
# ==========================================

class FollowUpListCreateView(APIView):

    permission_classes = [
        IsCrmStaffOrFranchise
    ]

    def get(self, request):

        queryset = (
            get_scoped_followup_queryset(request.user)
            .select_related("lead")
            .select_related("created_by")
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
        IsCrmStaffOrFranchise
    ]

    def patch(self, request, pk):
        from django.db.models import Q
        from leads.models import LeadActivity
        from .models import FollowUpAuditLog

        followup = get_object_or_404(
            FollowUp,
            pk=pk,
        )

        if not check_followup_access(request.user, followup):
            return Response(
                {"success": False, "message": "You are not authorized to update this follow-up."},
                status=status.HTTP_403_FORBIDDEN
            )

        old_datetime = followup.followup_datetime
        old_status = followup.status

        serializer = FollowUpSerializer(
            followup,
            data=request.data,
            partial=True,
        )

        if not serializer.is_valid():
            return Response(
                {
                    "success": False,
                    "message": "Validation failed for follow-up update.",
                    "errors": serializer.errors,
                },
                status=400,
            )

        updated_followup = serializer.save(updated_by=request.user)

        # Audit log and lead sync on reschedule / datetime change
        if old_datetime != updated_followup.followup_datetime:
            if not updated_followup.original_followup_datetime:
                updated_followup.original_followup_datetime = old_datetime
                updated_followup.save(update_fields=['original_followup_datetime'])

            FollowUpAuditLog.objects.create(
                followup=updated_followup,
                lead=updated_followup.lead,
                action='RESCHEDULED',
                previous_status=old_status,
                new_status=updated_followup.status,
                previous_datetime=old_datetime,
                new_datetime=updated_followup.followup_datetime,
                notes=request.data.get('note', '') or 'Follow-up rescheduled.',
                performed_by=request.user,
            )

            # Sync lead.next_followup
            lead = updated_followup.lead
            lead.next_followup = updated_followup.followup_datetime
            lead.save(update_fields=['next_followup'])

            LeadActivity.objects.create(
                lead=lead,
                activity_type='followup',
                title='Follow-up Rescheduled',
                description=f"Rescheduled to {updated_followup.followup_datetime.strftime('%d %b %Y, %I:%M %p')}.",
                created_by=request.user,
            )

        return Response({
            "success": True,
            "message": "Follow-up updated successfully.",
            "followup": FollowUpSerializer(updated_followup).data,
        })

    def delete(self, request, pk):
        profile = getattr(request.user, 'profile', None)
        role = profile.role if profile else 'admin'
        if not request.user.is_superuser and role not in ['admin', 'super_admin']:
            return Response(
                {"success": False, "message": "Only Administrators can delete follow-ups."},
                status=status.HTTP_403_FORBIDDEN
            )

        from .models import FollowUpAuditLog
        followup = get_object_or_404(
            FollowUp,
            pk=pk,
        )

        FollowUpAuditLog.objects.create(
            followup=followup,
            lead=followup.lead,
            action='CANCELLED',
            previous_status=followup.status,
            new_status='Cancelled',
            previous_datetime=followup.followup_datetime,
            notes='Follow-up deleted/cancelled.',
            performed_by=request.user,
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
        IsCrmStaffOrFranchise
    ]

    def patch(self, request, pk):
        return self.post(request, pk)

    def post(self, request, pk):
        from leads.models import LeadActivity
        from .models import FollowUpAuditLog

        followup = get_object_or_404(
            FollowUp,
            pk=pk,
        )

        if not check_followup_access(request.user, followup):
            return Response(
                {"success": False, "message": "You are not authorized to update this follow-up."},
                status=status.HTTP_403_FORBIDDEN
            )

        old_status = followup.status
        notes = request.data.get("outcome_notes") or request.data.get("notes") or request.data.get("outcome") or ""

        followup.status = "Completed"
        followup.completed_at = timezone.now()
        followup.completed_by = request.user
        followup.outcome_notes = notes
        followup.save(update_fields=['status', 'completed_at', 'completed_by', 'outcome_notes'])

        # Authoritative completion log / audit trail
        FollowUpAuditLog.objects.create(
            followup=followup,
            lead=followup.lead,
            action='COMPLETED',
            previous_status=old_status,
            new_status='Completed',
            previous_datetime=followup.followup_datetime,
            new_datetime=followup.completed_at,
            notes=notes or 'Marked completed.',
            performed_by=request.user,
        )

        # Log CRM activity on Lead
        lead = followup.lead
        LeadActivity.objects.create(
            lead=lead,
            activity_type='followup',
            title='Follow-up Completed',
            description=f"Follow-up completed by {request.user.get_full_name() or request.user.username}. Outcome: {notes or 'No notes'}",
            created_by=request.user,
        )

        # Check and update lead next_followup
        next_pending = FollowUp.objects.filter(
            lead=lead,
            status="Pending",
            followup_datetime__gt=timezone.now()
        ).order_by("followup_datetime").first()
        lead.next_followup = next_pending.followup_datetime if next_pending else None
        lead.save(update_fields=['next_followup'])

        return Response({
            "success": True,
            "message": "Follow-up completed successfully.",
            "followup": FollowUpSerializer(followup).data,
        })


# ==========================================
# COMPLETED FOLLOW-UPS LIST
# ==========================================

class CompletedFollowUpListView(APIView):
    """
    Dedicated view for completed follow-ups with rich period filtering:
    today, yesterday, this_week, this_month, custom date ranges, and keyword search.
    """
    permission_classes = [
        IsCrmStaffOrFranchise
    ]

    def get(self, request):
        from datetime import date, timedelta
        from django.db.models import Q

        today = timezone.localdate()
        qs = (
            get_scoped_followup_queryset(request.user)
            .filter(status="Completed")
            .select_related("lead", "created_by", "completed_by")
            .order_by("-completed_at")
        )

        period = (request.query_params.get("period") or "").strip().lower()
        start_date_str = request.query_params.get("start_date")
        end_date_str = request.query_params.get("end_date")

        if period == "today":
            qs = qs.filter(completed_at__date=today)
        elif period == "yesterday":
            qs = qs.filter(completed_at__date=today - timedelta(days=1))
        elif period in ["this_week", "this week", "week"]:
            week_start = today - timedelta(days=today.weekday())
            qs = qs.filter(completed_at__date__gte=week_start, completed_at__date__lte=today)
        elif period in ["this_month", "this month", "month"]:
            qs = qs.filter(completed_at__date__year=today.year, completed_at__date__month=today.month)
        elif start_date_str and end_date_str:
            try:
                s_date = date.fromisoformat(start_date_str)
                e_date = date.fromisoformat(end_date_str)
                qs = qs.filter(completed_at__date__gte=s_date, completed_at__date__lte=e_date)
            except Exception:
                pass

        search = request.query_params.get("search", "").strip()
        if search:
            qs = qs.filter(
                Q(lead__name__icontains=search)
                | Q(lead__phone__icontains=search)
                | Q(lead__city__icontains=search)
                | Q(outcome_notes__icontains=search)
                | Q(note__icontains=search)
            )

        serializer = FollowUpSerializer(qs, many=True)
        return Response({
            "success": True,
            "count": qs.count(),
            "followups": serializer.data,
        })


# ==========================================
# AUDIT LOG
# ==========================================

class FollowUpAuditLogListView(APIView):
    permission_classes = [
        IsCrmStaffOrFranchise
    ]

    def get(self, request, pk):
        followup = get_object_or_404(FollowUp, pk=pk)
        if not check_followup_access(request.user, followup):
            return Response(
                {"success": False, "message": "You are not authorized to view audit logs for this follow-up."},
                status=status.HTTP_403_FORBIDDEN
            )
        from .models import FollowUpAuditLog
        logs = FollowUpAuditLog.objects.filter(followup=followup).select_related("performed_by").order_by("-performed_at")
        serializer = FollowUpAuditLogSerializer(logs, many=True)
        return Response({
            "success": True,
            "count": logs.count(),
            "audit_logs": serializer.data,
        })



# ==========================================
# STATS
# ==========================================

class FollowUpStatsView(APIView):

    permission_classes = [
        IsCrmStaffOrFranchise
    ]

    def get(self, request):

        today = timezone.localdate()
        scoped_qs = get_scoped_followup_queryset(request.user)

        today_count = scoped_qs.filter(
            followup_datetime__date=today,
            status="Pending",
        ).count()

        overdue = scoped_qs.filter(
            followup_datetime__date__lt=today,
            status="Pending",
        ).count()

        upcoming = scoped_qs.filter(
            followup_datetime__date__gt=today,
            status="Pending",
        ).count()

        completed = scoped_qs.filter(
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
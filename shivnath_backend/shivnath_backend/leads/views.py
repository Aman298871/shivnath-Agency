from django.db.models import Q, Count
from django.shortcuts import get_object_or_404

from rest_framework import status
from rest_framework.response import Response
from rest_framework.views import APIView

from accounts.permissions import IsAdminRole

from .models import (
    Lead,
    LeadActivity,
)

from .serializers import (
    LeadSerializer,
    LeadActivitySerializer,
)

from followups.models import FollowUp


# =========================================================
# HELPER: SYNC LEAD.next_followup -> FollowUp TABLE
# =========================================================

def _sync_followup(lead, user):
    """
    Lead ke next_followup field ke basis pe
    FollowUp table me pending entry create/update karta hai.
    """

    if lead.next_followup:

        FollowUp.objects.update_or_create(
            lead=lead,
            status='Pending',
            defaults={
                'followup_datetime': lead.next_followup,
                'created_by': user,
            }
        )

    else:

        # agar next_followup hata diya gaya, toh pending followup bhi hata do
        FollowUp.objects.filter(
            lead=lead,
            status='Pending',
        ).delete()


# =========================================================
# LEAD LIST + CREATE
# =========================================================

class LeadListCreateView(APIView):

    permission_classes = [
        IsAdminRole
    ]

    def get(self, request):

        leads = (
            Lead.objects
            .select_related(
                'created_by'
            )
            .prefetch_related(
                'activities',
                'activities__created_by'
            )
            .all()
        )

        # ---------------------------------------------
        # SEARCH
        # ---------------------------------------------

        search = request.query_params.get(
            'search',
            ''
        ).strip()

        if search:
            leads = leads.filter(
                Q(name__icontains=search)
                |
                Q(phone__icontains=search)
                |
                Q(city__icontains=search)
                |
                Q(district__icontains=search)
                |
                Q(
                    preferred_location__icontains=search
                )
                |
                Q(
                    assigned_executive__icontains=search
                )
            )

        # ---------------------------------------------
        # STATUS
        # ---------------------------------------------

        lead_status = request.query_params.get(
            'status',
            ''
        ).strip()

        if lead_status:
            leads = leads.filter(
                status=lead_status
            )

        # ---------------------------------------------
        # SCORE
        # ---------------------------------------------

        score = request.query_params.get(
            'score',
            ''
        ).strip()

        if score:
            leads = leads.filter(
                score=score
            )

        # ---------------------------------------------
        # CITY
        # ---------------------------------------------

        city = request.query_params.get(
            'city',
            ''
        ).strip()

        if city:
            leads = leads.filter(
                city__iexact=city
            )

        # ---------------------------------------------
        # DISTRICT
        # ---------------------------------------------

        district = request.query_params.get(
            'district',
            ''
        ).strip()

        if district:
            leads = leads.filter(
                district__iexact=district
            )

        serializer = LeadSerializer(
            leads,
            many=True
        )

        return Response(
            {
                'success': True,
                'count': leads.count(),
                'leads': serializer.data,
            },
            status=status.HTTP_200_OK
        )

    def post(self, request):

        serializer = LeadSerializer(
            data=request.data
        )

        if not serializer.is_valid():

            return Response(
                {
                    'success': False,
                    'errors': serializer.errors,
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        lead = serializer.save(
            created_by=request.user
        )

        # ---------------------------------------------
        # SYNC FOLLOWUP TABLE (agar next_followup diya gaya ho)
        # ---------------------------------------------

        _sync_followup(
            lead,
            request.user
        )

        LeadActivity.objects.create(
            lead=lead,
            activity_type='note',
            title='Lead Created',
            description='New lead added to CRM.',
            created_by=request.user
        )

        return Response(
            {
                'success': True,
                'message':
                    'Lead created successfully.',
                'lead':
                    LeadSerializer(
                        lead
                    ).data,
            },
            status=status.HTTP_201_CREATED
        )


# =========================================================
# LEAD DETAIL + UPDATE + DELETE
# =========================================================

class LeadDetailView(APIView):

    permission_classes = [
        IsAdminRole
    ]

    def get(self, request, pk):

        lead = get_object_or_404(
            Lead.objects
            .select_related(
                'created_by'
            )
            .prefetch_related(
                'activities',
                'activities__created_by'
            ),
            pk=pk
        )

        return Response(
            {
                'success': True,
                'lead':
                    LeadSerializer(
                        lead
                    ).data,
            },
            status=status.HTTP_200_OK
        )

    def put(self, request, pk):

        return self._update_lead(
            request=request,
            pk=pk,
            partial=False
        )

    def patch(self, request, pk):

        return self._update_lead(
            request=request,
            pk=pk,
            partial=True
        )

    def _update_lead(
        self,
        request,
        pk,
        partial
    ):

        lead = get_object_or_404(
            Lead,
            pk=pk
        )

        old_status = lead.status
        old_score = lead.score
        old_followup = lead.next_followup

        serializer = LeadSerializer(
            lead,
            data=request.data,
            partial=partial
        )

        if not serializer.is_valid():

            return Response(
                {
                    'success': False,
                    'errors': serializer.errors,
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        updated_lead = serializer.save()

        # -----------------------------------------
        # STATUS CHANGE ACTIVITY
        # -----------------------------------------

        if old_status != updated_lead.status:

            old_label = dict(
                Lead.STATUS_CHOICES
            ).get(
                old_status,
                old_status
            )

            new_label = dict(
                Lead.STATUS_CHOICES
            ).get(
                updated_lead.status,
                updated_lead.status
            )

            LeadActivity.objects.create(
                lead=updated_lead,
                activity_type='status_change',
                title='Lead Status Changed',
                description=(
                    f'{old_label} → {new_label}'
                ),
                created_by=request.user
            )

        # -----------------------------------------
        # SCORE CHANGE ACTIVITY
        # -----------------------------------------

        if old_score != updated_lead.score:

            old_label = dict(
                Lead.SCORE_CHOICES
            ).get(
                old_score,
                old_score
            )

            new_label = dict(
                Lead.SCORE_CHOICES
            ).get(
                updated_lead.score,
                updated_lead.score
            )

            LeadActivity.objects.create(
                lead=updated_lead,
                activity_type='note',
                title='Lead Score Changed',
                description=(
                    f'{old_label} → {new_label}'
                ),
                created_by=request.user
            )

        # -----------------------------------------
        # FOLLOW-UP CHANGE ACTIVITY + SYNC
        # -----------------------------------------

        if old_followup != updated_lead.next_followup:

            # ---- FollowUp table sync ----
            _sync_followup(
                updated_lead,
                request.user
            )

            if updated_lead.next_followup:

                description = (
                    'Next follow-up scheduled for '
                    f'{updated_lead.next_followup}.'
                )

            else:

                description = (
                    'Next follow-up removed.'
                )

            LeadActivity.objects.create(
                lead=updated_lead,
                activity_type='note',
                title='Follow-up Updated',
                description=description,
                created_by=request.user
            )

        return Response(
            {
                'success': True,
                'message':
                    'Lead updated successfully.',
                'lead':
                    LeadSerializer(
                        updated_lead
                    ).data,
            },
            status=status.HTTP_200_OK
        )

    def delete(self, request, pk):

        lead = get_object_or_404(
            Lead,
            pk=pk
        )

        lead_name = lead.name

        lead.delete()

        return Response(
            {
                'success': True,
                'message':
                    f'{lead_name} deleted successfully.'
            },
            status=status.HTTP_200_OK
        )


# =========================================================
# LEAD ACTIVITY LIST + CREATE
# =========================================================

class LeadActivityListCreateView(APIView):

    permission_classes = [
        IsAdminRole
    ]

    def get(self, request, lead_id):

        lead = get_object_or_404(
            Lead,
            pk=lead_id
        )

        activities = (
            LeadActivity.objects
            .filter(
                lead=lead
            )
            .select_related(
                'created_by'
            )
            .order_by(
                '-created_at'
            )
        )

        serializer = LeadActivitySerializer(
            activities,
            many=True
        )

        return Response(
            {
                'success': True,
                'lead_id': lead.id,
                'lead_name': lead.name,
                'activities':
                    serializer.data,
            },
            status=status.HTTP_200_OK
        )

    def post(self, request, lead_id):

        lead = get_object_or_404(
            Lead,
            pk=lead_id
        )

        serializer = LeadActivitySerializer(
            data=request.data
        )

        if not serializer.is_valid():

            return Response(
                {
                    'success': False,
                    'errors': serializer.errors,
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        activity = serializer.save(
            lead=lead,
            created_by=request.user
        )

        return Response(
            {
                'success': True,
                'message':
                    'Lead activity added successfully.',
                'activity':
                    LeadActivitySerializer(
                        activity
                    ).data,
            },
            status=status.HTTP_201_CREATED
        )


# =========================================================
# LEAD STATS
# =========================================================

class LeadStatsView(APIView):

    permission_classes = [
        IsAdminRole
    ]

    def get(self, request):

        total_leads = Lead.objects.count()

        hot_leads = Lead.objects.filter(
            score='hot'
        ).count()

        warm_leads = Lead.objects.filter(
            score='warm'
        ).count()

        cold_leads = Lead.objects.filter(
            score='cold'
        ).count()

        interested = Lead.objects.filter(
            status='interested'
        ).count()

        site_visits = Lead.objects.filter(
            status='site_visit_scheduled'
        ).count()

        confirmed = Lead.objects.filter(
            status='franchise_confirmed'
        ).count()

        lost = Lead.objects.filter(
            status='lost'
        ).count()

        pipeline_query = (
            Lead.objects
            .values(
                'status'
            )
            .annotate(
                count=Count('id')
            )
            .order_by()
        )

        pipeline = {}

        for item in pipeline_query:

            pipeline[
                item['status']
            ] = item['count']

        conversion_rate = 0

        if total_leads > 0:

            conversion_rate = round(
                (
                    confirmed
                    / total_leads
                ) * 100,
                2
            )

        return Response(
            {
                'success': True,

                'stats': {
                    'total_leads':
                        total_leads,

                    'hot_leads':
                        hot_leads,

                    'warm_leads':
                        warm_leads,

                    'cold_leads':
                        cold_leads,

                    'interested':
                        interested,

                    'site_visits':
                        site_visits,

                    'confirmed':
                        confirmed,

                    'lost':
                        lost,

                    'conversion_rate':
                        conversion_rate,

                    'pipeline':
                        pipeline,
                }
            },
            status=status.HTTP_200_OK
        )
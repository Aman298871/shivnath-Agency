from django.db.models import Q, Count
from django.shortcuts import get_object_or_404
from django.utils import timezone

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

def _normalize_phone(p):
    if not p:
        return ""
    import re
    digits = re.sub(r'\D', '', str(p))
    return digits[-10:] if len(digits) >= 10 else digits


class PublicLeadCaptureView(APIView):
    permission_classes = []
    authentication_classes = []

    def post(self, request):
        name = str(request.data.get('name', '')).strip()
        phone = str(request.data.get('phone', '')).strip()
        email = str(request.data.get('email', '')).strip().lower()
        city = str(request.data.get('city', '')).strip()
        district = str(request.data.get('district', '')).strip()
        budget = str(request.data.get('budget') or request.data.get('investment_budget', '')).strip()
        space = str(request.data.get('space') or request.data.get('commercial_space', 'no')).strip().lower()
        experience = str(request.data.get('experience') or request.data.get('previous_experience', '')).strip()
        location = str(request.data.get('location') or request.data.get('preferred_location', '')).strip()
        territory = str(request.data.get('territory') or location).strip()
        inquiry_type = str(request.data.get('inquiry_type', 'customer')).strip().lower()
        if inquiry_type not in ['customer', 'franchise']:
            inquiry_type = 'customer'
        selected_options = request.data.get('selected_options', [])
        notes = str(request.data.get('notes', '')).strip()
        conversation_history = request.data.get('conversation_history', [])

        if not name or name.strip() == '':
            name = "Public Customer" if inquiry_type == 'customer' else "Franchise Prospect"
        if not phone:
            return Response(
                {'success': False, 'message': 'Mobile number is required to register inquiry.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        norm_phone = _normalize_phone(phone)
        
        # 1. Check for existing Customer/UserProfile record
        from accounts.models import (
            UserProfile,
            AdminNotification,
            FranchiseProfile,
            FranchiseTerritoryAssignment,
            FranchiseNotification,
        )
        existing_customer_profile = None
        if norm_phone:
            existing_customer_profile = UserProfile.objects.filter(phone__icontains=norm_phone).first()
        if not existing_customer_profile and email and not email.endswith('@franchiseprospect.com') and not email.endswith('@purewatercrm.com'):
            existing_customer_profile = UserProfile.objects.filter(user__email__iexact=email).first()

        # 2. Check for existing Lead by phone or email
        existing_lead = None
        if norm_phone:
            existing_lead = Lead.objects.filter(phone__icontains=norm_phone).first()
        if not existing_lead and email and not email.endswith('@franchiseprospect.com') and not email.endswith('@purewatercrm.com'):
            existing_lead = Lead.objects.filter(email__iexact=email).first()

        score = 'warm'
        if '10 lakh' in budget.lower() or '20 lakh' in budget.lower() or 'yes' in space.lower() or 'bulk' in notes.lower():
            score = 'hot'

        # Route to territory franchise
        matched_franchise = None
        if territory:
            assignment = FranchiseTerritoryAssignment.objects.filter(
                is_active=True,
                zone__name__icontains=territory
            ).select_related('franchise').first()
            if assignment:
                matched_franchise = assignment.franchise
            else:
                matched_franchise = FranchiseProfile.objects.filter(
                    status='approved',
                    territory__icontains=territory
                ).first()
        if not matched_franchise and city:
            matched_franchise = FranchiseProfile.objects.filter(
                status='approved',
                city__icontains=city
            ).first()
        if not matched_franchise and district:
            assignment = FranchiseTerritoryAssignment.objects.filter(
                is_active=True,
                zone__district__name__icontains=district
            ).select_related('franchise').first()
            if assignment:
                matched_franchise = assignment.franchise
            else:
                matched_franchise = FranchiseProfile.objects.filter(
                    status='approved',
                    user__user_profile__district__icontains=district
                ).first()

        # Build clean, structured note and inquiry details
        note_details = f"Inquiry Category: {inquiry_type.upper()}"
        if selected_options:
            if isinstance(selected_options, list):
                opts_str = " -> ".join([str(o) for o in selected_options if o])
            else:
                opts_str = str(selected_options)
            note_details += f"\nInquiry Navigation Path: {opts_str}"
        if district:
            note_details += f"\nDistrict: {district}"
        if city:
            note_details += f"\nCity / Location: {city}"
        if territory:
            note_details += f"\nTerritory / Area: {territory}"
        if matched_franchise:
            note_details += f"\nRouted Franchise: {matched_franchise.business_name} ({matched_franchise.territory or matched_franchise.city})"
        if budget:
            note_details += f"\nInvestment / Budget Tier: {budget}"
        if space and space != 'no':
            note_details += f"\nCommercial Space: {space}"
        if experience:
            note_details += f"\nExperience: {experience}"
        if notes:
            note_details += f"\nSpecific Inquiry Notes: {notes}"

        # Append formatted conversation transcript
        if conversation_history and isinstance(conversation_history, list):
            conv_lines = []
            for item in conversation_history:
                if isinstance(item, dict):
                    role = item.get('role', 'user')
                    content = str(item.get('content', '')).strip()
                    if content:
                        prefix = "👤 User" if role == 'user' else "🤖 Chatbot"
                        conv_lines.append(f"{prefix}: {content}")
            if conv_lines:
                note_details += "\n\n=== CHATBOT CONVERSATION TRANSCRIPT ===\n" + "\n".join(conv_lines)

        pref_loc = f"{territory}, {city}".strip(', ') if territory else (city or location)

        if existing_customer_profile and not existing_lead:
            # Existing registered customer opened the chatbot
            # Link to their customer profile without creating duplicate new lead records
            existing_lead = Lead.objects.filter(converted_user=existing_customer_profile.user).first()

        if existing_lead:
            # Update existing lead without creating duplicate card in Admin
            if name and existing_lead.name in ['Public Prospect', 'Public Customer', 'Guest Customer', '', 'Prospect']:
                existing_lead.name = name
            if city:
                existing_lead.city = city
            if district:
                existing_lead.district = district
            if territory:
                existing_lead.territory = territory
            if pref_loc:
                existing_lead.preferred_location = pref_loc
            if matched_franchise:
                existing_lead.assigned_franchise = matched_franchise
                existing_lead.assigned_executive = matched_franchise.business_name
            if budget:
                existing_lead.investment_budget = budget
            if 'available' in space or 'yes' in space or 'searching' in space:
                existing_lead.commercial_space = 'available' if ('available' in space or 'yes' in space) else 'searching'
            if experience and not existing_lead.previous_experience:
                existing_lead.previous_experience = experience
            if score == 'hot':
                existing_lead.score = 'hot'
            if existing_customer_profile and not existing_lead.converted_user:
                existing_lead.converted_user = existing_customer_profile.user
            
            existing_lead.notes = (existing_lead.notes + f"\n\n[{inquiry_type.upper()} UPDATE - {timezone.now().strftime('%d %b %Y %I:%M %p')}]\n" + note_details).strip()
            existing_lead.save()

            LeadActivity.objects.create(
                lead=existing_lead,
                activity_type='whatsapp' if 'whatsapp' in notes.lower() else 'note',
                title=f'Chatbot Inquiry Update ({inquiry_type.capitalize()})',
                description=note_details,
            )

            try:
                AdminNotification.objects.create(
                    title='Lead Inquiry Updated',
                    message=f'Existing Lead {existing_lead.name} ({existing_lead.phone}) submitted a new {inquiry_type} inquiry via Chatbot.',
                    notification_type='general',
                    reference_id=existing_lead.id,
                )
            except Exception:
                pass

            if matched_franchise:
                try:
                    FranchiseNotification.objects.create(
                        franchise=matched_franchise,
                        title='Customer Inquiry Updated',
                        message=f'Lead {existing_lead.name} ({existing_lead.phone}) updated inquiry in {territory or city}, District: {district}.',
                        notification_type='new_customer',
                        reference_id=existing_lead.id,
                    )
                except Exception:
                    pass

            return Response(
                {
                    'success': True,
                    'is_duplicate': True,
                    'message': 'Inquiry linked to existing lead profile successfully without duplicates.',
                    'lead': LeadSerializer(existing_lead).data,
                },
                status=status.HTTP_200_OK,
            )

        # Create brand new Lead
        new_lead = Lead.objects.create(
            name=name,
            phone=phone,
            email=email,
            city=city or 'Raipur',
            district=district,
            territory=territory,
            assigned_franchise=matched_franchise,
            assigned_executive=matched_franchise.business_name if matched_franchise else '',
            investment_budget=budget,
            existing_business='yes' if 'yes' in str(request.data.get('existing_business', '')).lower() else 'no',
            commercial_space='available' if ('available' in space or 'yes' in space) else ('searching' if 'searching' in space else 'no'),
            previous_experience=experience,
            preferred_location=pref_loc or city or 'Raipur',
            score=score,
            status='new_lead',
            source='Public AI Chatbot',
            notes=note_details,
            converted_user=existing_customer_profile.user if existing_customer_profile else None,
        )

        LeadActivity.objects.create(
            lead=new_lead,
            activity_type='note',
            title=f'New {inquiry_type.capitalize()} Chatbot Lead',
            description=note_details,
        )

        try:
            AdminNotification.objects.create(
                title='New Lead Received',
                message=f'New {inquiry_type} lead received from {new_lead.name} ({new_lead.phone}) in {territory or city}, District: {district}.',
                notification_type='general',
                reference_id=new_lead.id,
            )
        except Exception:
            pass

        if matched_franchise:
            try:
                FranchiseNotification.objects.create(
                    franchise=matched_franchise,
                    title='New Customer Lead in Your Territory',
                    message=f'New customer inquiry from {new_lead.name} ({new_lead.phone}) in {territory or city}, District: {district}.',
                    notification_type='new_customer',
                    reference_id=new_lead.id,
                )
            except Exception:
                pass

        return Response(
            {
                'success': True,
                'is_duplicate': False,
                'message': 'New lead captured successfully in Admin CRM and routed to territory franchise.',
                'lead': LeadSerializer(new_lead).data,
            },
            status=status.HTTP_201_CREATED,
        )


class LeadListCreateView(APIView):
    permission_classes = [IsAdminRole]

    def get(self, request):
        leads = (
            Lead.objects
            .select_related('created_by')
            .prefetch_related('activities', 'activities__created_by')
            .all()
        )

        search = request.query_params.get('search', '').strip()
        if search:
            leads = leads.filter(
                Q(name__icontains=search)
                | Q(phone__icontains=search)
                | Q(city__icontains=search)
                | Q(district__icontains=search)
                | Q(preferred_location__icontains=search)
                | Q(assigned_executive__icontains=search)
            )

        lead_status = request.query_params.get('status', '').strip()
        if lead_status:
            leads = leads.filter(status=lead_status)

        score = request.query_params.get('score', '').strip()
        if score:
            leads = leads.filter(score=score)

        city = request.query_params.get('city', '').strip()
        if city:
            leads = leads.filter(city__iexact=city)

        district = request.query_params.get('district', '').strip()
        if district:
            leads = leads.filter(district__iexact=district)

        serializer = LeadSerializer(leads, many=True)
        return Response(
            {
                'success': True,
                'count': leads.count(),
                'leads': serializer.data,
            },
            status=status.HTTP_200_OK,
        )

    def post(self, request):
        # Check duplicate before creating
        phone = str(request.data.get('phone', '')).strip()
        norm_phone = _normalize_phone(phone)

        if norm_phone:
            existing = Lead.objects.filter(phone__icontains=norm_phone).first()
            if existing:
                serializer = LeadSerializer(existing, data=request.data, partial=True)
                if serializer.is_valid():
                    lead = serializer.save()
                    _sync_followup(lead, request.user)
                    LeadActivity.objects.create(
                        lead=lead,
                        activity_type='note',
                        title='Lead Details Updated',
                        description='Existing lead updated via Lead Management.',
                        created_by=request.user,
                    )
                    return Response(
                        {
                            'success': True,
                            'message': 'Existing lead updated successfully.',
                            'lead': LeadSerializer(lead).data,
                        },
                        status=status.HTTP_200_OK,
                    )

        serializer = LeadSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(
                {
                    'success': False,
                    'errors': serializer.errors,
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        lead = serializer.save(created_by=request.user)
        _sync_followup(lead, request.user)

        LeadActivity.objects.create(
            lead=lead,
            activity_type='note',
            title='Lead Created',
            description='New lead added to CRM.',
            created_by=request.user,
        )

        return Response(
            {
                'success': True,
                'message': 'Lead created successfully.',
                'lead': LeadSerializer(lead).data,
            },
            status=status.HTTP_201_CREATED,
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
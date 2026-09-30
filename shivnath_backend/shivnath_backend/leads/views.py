from django.db.models import Q, Count
from django.shortcuts import get_object_or_404
from django.utils import timezone

from rest_framework import status
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.permissions import AllowAny
from django.core.exceptions import ValidationError

from accounts.permissions import IsAdminRole, IsAdminOrApprovedFranchise, IsAdminOrSalesExecutiveRole
from accounts.services import apply_data_scope

from .models import (
    Lead,
    LeadActivity,
    MarketingSpend,
    WhatsAppMessageLog,
    LeadJourneyState,
    CRMActivityLog,
)

from .serializers import (
    LeadSerializer,
    LeadActivitySerializer,
    MarketingSpendSerializer,
    WhatsAppMessageLogSerializer,
    LeadJourneyStateSerializer,
    CRMActivityLogSerializer,
)
from .services import (
    validate_and_create_chatbot_inquiry,
    handle_incoming_whatsapp_reply,
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

# =========================================================
# PHONE NORMALIZER & PUBLIC LEAD CAPTURE
# =========================================================


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
        name = str(request.data.get('name') or request.data.get('full_name') or '').strip()
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

        # Strict mobile validation: EXACTLY 10 digits starting with 6, 7, 8, or 9
        phone_raw = str(phone).strip()
        if not phone_raw:
            return Response(
                {'success': False, 'message': 'Mobile number is required to register inquiry.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        import re as _re2
        if not _re2.fullmatch(r'^[6-9]\d{9}$', phone_raw):
            return Response(
                {'success': False, 'message': 'Mobile number must be exactly 10 digits and start with 6, 7, 8, or 9.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        phone = phone_raw

        # Strict name validation: 2-30 chars, at least some alphabetic, not purely numeric/symbol
        name_clean = name.strip()
        if not name_clean or len(name_clean) < 2 or len(name_clean) > 30:
            return Response(
                {'success': False, 'message': 'Full name must be between 2 and 30 characters.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if not _re2.search(r'[a-zA-Z]', name_clean) or _re2.fullmatch(r'^[0-9\W_]+$', name_clean):
            return Response(
                {'success': False, 'message': 'Full name must contain meaningful alphabetic characters.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        name = name_clean

        # Email validation: required field and valid format
        email_clean = str(email).strip().lower()
        if not email_clean or email_clean in ['skip', 'skip email', 'none', 'null']:
            return Response(
                {'success': False, 'message': 'Email address is required to register inquiry.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        import re as _re3
        email_regex = _re3.compile(r'^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+$')
        if not email_regex.fullmatch(email_clean):
            return Response(
                {'success': False, 'message': 'Please provide a valid email address.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        email = email_clean

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
            if not existing_lead.source or existing_lead.source in ['Public AI Chatbot', 'Public Inbound Chatbot', '']:
                existing_lead.source = 'PUBLIC_CHATBOT'
            existing_lead.save()

            LeadActivity.objects.create(
                lead=existing_lead,
                activity_type='whatsapp' if 'whatsapp' in notes.lower() else 'note',
                title=f'Chatbot Inquiry Update ({inquiry_type.capitalize()})',
                description=note_details,
            )

            CRMActivityLog.objects.create(
                lead=existing_lead,
                activity_type='NOTE_ADDED',
                description=f"Public Chatbot inquiry update received ({inquiry_type}). Notes: {note_details[:300]}"
            )

            # Link ChatSession
            session_id = str(request.data.get('session_id', '')).strip()
            from chat.models import ChatSession
            if session_id:
                ChatSession.objects.filter(session_id=session_id).update(
                    lead=existing_lead, customer_name=name or existing_lead.name, customer_phone=phone or existing_lead.phone, customer_email=email or existing_lead.email
                )
            if norm_phone:
                ChatSession.objects.filter(customer_phone__icontains=norm_phone).filter(lead__isnull=True).update(lead=existing_lead)
            if email:
                ChatSession.objects.filter(customer_email__iexact=email).filter(lead__isnull=True).update(lead=existing_lead)

            try:
                AdminNotification.objects.create(
                    title='Lead Inquiry Updated',
                    message=f'Existing Lead {existing_lead.name} ({existing_lead.phone}) submitted a new {inquiry_type} inquiry via Chatbot.',
                    notification_type='general',
                    reference_id=existing_lead.id,
                )
                from accounts.fcm_services import notify_lead_created
                notify_lead_created(existing_lead, is_update=True)
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
            locality=location or territory,
            assigned_franchise=matched_franchise,
            assigned_executive=matched_franchise.business_name if matched_franchise else '',
            investment_budget=budget,
            existing_business='yes' if 'yes' in str(request.data.get('existing_business', '')).lower() else 'no',
            commercial_space='available' if ('available' in space or 'yes' in space) else ('searching' if 'searching' in space else 'no'),
            previous_experience=experience,
            preferred_location=pref_loc or city or 'Raipur',
            score=score,
            status='NEW',
            source='PUBLIC_CHATBOT',
            notes=note_details,
            converted_user=existing_customer_profile.user if existing_customer_profile else None,
        )

        LeadActivity.objects.create(
            lead=new_lead,
            activity_type='note',
            title=f'New {inquiry_type.capitalize()} Chatbot Lead',
            description=note_details,
        )

        CRMActivityLog.objects.create(
            lead=new_lead,
            activity_type='STATUS_CHANGED',
            description=f"Inbound public chatbot inquiry received. Source: PUBLIC_CHATBOT. Score: {new_lead.score_category} ({new_lead.lead_score_number})"
        )

        # Link ChatSession
        session_id = str(request.data.get('session_id', '')).strip()
        from chat.models import ChatSession
        if session_id:
            ChatSession.objects.filter(session_id=session_id).update(
                lead=new_lead, customer_name=name, customer_phone=phone, customer_email=email
            )
        if norm_phone:
            ChatSession.objects.filter(customer_phone__icontains=norm_phone).filter(lead__isnull=True).update(lead=new_lead)
        if email:
            ChatSession.objects.filter(customer_email__iexact=email).filter(lead__isnull=True).update(lead=new_lead)

        try:
            AdminNotification.objects.create(
                title='New Lead Received',
                message=f'New {inquiry_type} lead received from {new_lead.name} ({new_lead.phone}) in {territory or city}, District: {district}.',
                notification_type='general',
                reference_id=new_lead.id,
            )
            from accounts.fcm_services import notify_lead_created
            notify_lead_created(new_lead, is_update=False)
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
    permission_classes = [IsAdminOrApprovedFranchise]

    def get(self, request):
        user = request.user
        profile = getattr(user, 'profile', None)
        role = profile.role if profile else 'admin'

        leads = (
            Lead.objects
            .select_related('created_by', 'assigned_franchise')
            .prefetch_related('activities', 'activities__created_by')
            .all()
        )

        if role == 'franchise' and not user.is_superuser:
            fp = getattr(user, 'franchise_profile', None)
            if fp:
                leads = leads.filter(Q(assigned_franchise=fp) | Q(assigned_franchise__isnull=True))

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
        IsAdminOrApprovedFranchise
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
            score_category='HOT'
        ).count() or Lead.objects.filter(score__iexact='hot').count()

        warm_leads = Lead.objects.filter(
            score_category='WARM'
        ).count() or Lead.objects.filter(score__iexact='warm').count()

        cold_leads = Lead.objects.filter(
            score_category='COLD'
        ).count() or Lead.objects.filter(score__iexact='cold').count()

        interested = Lead.objects.filter(
            status__iexact='interested'
        ).count()

        site_visits = Lead.objects.filter(
            status__iexact='site_visit_scheduled'
        ).count()

        confirmed = Lead.objects.filter(
            status__iexact='franchise_confirmed'
        ).count()

        lost = Lead.objects.filter(
            status__iexact='lost'
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
            # Normalize to lowercase key so Flutter can map consistently
            pipeline[
                item['status'].lower()
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


# =========================================================
# PUBLIC CHATBOT LEAD CAPTURE (INBOUND CRM)
# =========================================================

class PublicChatbotInquiryView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        """
        Public endpoint for customer/dealer website or mobile chatbot inquiry.
        Enforces required email, 10-digit phone, calculates score, and starts 15-day WhatsApp drip.
        """
        is_dealer = request.data.get('inquiry_type') in ['DEALER', 'FRANCHISE', 'WHOLESALE_DEALER'] or request.data.get('is_dealer_inquiry') is True
        try:
            lead = validate_and_create_chatbot_inquiry(request.data, is_dealer_inquiry=is_dealer)
            return Response({
                'success': True,
                'message': 'Thank you! Your inquiry has been registered. Our representative will contact you shortly.',
                'lead_id': lead.id,
                'lead_score': lead.score,
                'status': lead.status,
            }, status=status.HTTP_201_CREATED)
        except ValidationError as e:
            return Response({
                'success': False,
                'error': 'validation_error',
                'message': str(e.message if hasattr(e, 'message') else e),
            }, status=status.HTTP_400_BAD_REQUEST)
        except Exception as e:
            return Response({
                'success': False,
                'error': 'server_error',
                'message': str(e),
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


# =========================================================
# WHATSAPP WEBHOOK (INBOUND MESSAGES & REPLIES)
# =========================================================

class WhatsAppWebhookView(APIView):
    permission_classes = [AllowAny]

    def get(self, request):
        """Webhook verification challenge handler (for Meta Cloud API / BSPs)."""
        mode = request.query_params.get('hub.mode')
        token = request.query_params.get('hub.verify_token')
        challenge = request.query_params.get('hub.challenge')
        if mode == 'subscribe' and challenge:
            return Response(challenge, content_type='text/plain')
        return Response({'status': 'active'}, status=200)

    def post(self, request):
        """Webhook event payload for incoming replies from leads/customers."""
        sender_phone = request.data.get('from') or request.data.get('sender_phone', '')
        message_text = request.data.get('text') or request.data.get('message', '')
        button_payload = request.data.get('button_payload') or request.data.get('payload', '')

        if not sender_phone:
            return Response({'success': False, 'message': 'sender_phone is required.'}, status=400)

        result = handle_incoming_whatsapp_reply(
            sender_phone=sender_phone,
            message_text=message_text,
            button_payload=button_payload,
        )

        return Response({
            'success': True,
            'result': result,
        })


# =========================================================
# MARKETING SPEND & CAC ANALYTICS
# =========================================================

class MarketingSpendListCreateView(APIView):
    permission_classes = [IsAdminRole]

    def get(self, request):
        spends = MarketingSpend.objects.all()
        serializer = MarketingSpendSerializer(spends, many=True)
        return Response({
            'success': True,
            'count': spends.count(),
            'spends': serializer.data,
        })

    def post(self, request):
        serializer = MarketingSpendSerializer(data=request.data)
        if not serializer.is_valid():
            return Response({'success': False, 'errors': serializer.errors}, status=400)
        spend = serializer.save()
        return Response({
            'success': True,
            'message': 'Marketing spend logged successfully.',
            'spend': MarketingSpendSerializer(spend).data,
        }, status=201)


# =========================================================
# LEAD SCORE RECALCULATION
# =========================================================

class LeadScoreRecalculateView(APIView):
    permission_classes = [IsAdminRole]

    def post(self, request, pk):
        lead = get_object_or_404(Lead, pk=pk)
        old_score = lead.score
        lead.calculate_lead_score()
        lead.save(update_fields=['score', 'score_category', 'lead_score_number', 'updated_at'])
        return Response({
            'success': True,
            'lead_id': lead.id,
            'previous_score': old_score,
            'updated_score': lead.score,
            'score_category': lead.score_category,
            'lead_score_number': lead.lead_score_number,
            'status': lead.status,
        })


# =========================================================
# LEAD CONVERSION (CUSTOMER / FRANCHISE ONBOARDING)
# =========================================================

class LeadConvertAPIView(APIView):
    permission_classes = [IsAdminOrApprovedFranchise]

    def post(self, request, pk):
        lead = get_object_or_404(Lead, pk=pk)
        action = str(request.data.get('action', 'convert_to_customer')).strip().lower()
        actor = request.user if request.user.is_authenticated else None

        from django.contrib.auth.models import User
        from accounts.models import UserProfile, FranchiseProfile, CustomerDealerRelationship

        if action in ['convert_to_customer', 'customer']:
            user = None
            if lead.converted_user:
                user = lead.converted_user
            elif lead.phone:
                user = User.objects.filter(username=lead.phone).first()
            if not user and lead.email and not lead.email.endswith('@purewatercrm.com'):
                user = User.objects.filter(email__iexact=lead.email).first()

            if not user:
                username = lead.phone if lead.phone else f"cust_{lead.id}"
                user = User.objects.create_user(
                    username=username,
                    email=lead.email or f"{username}@purewatercrm.com",
                    first_name=lead.name[:30],
                )
                user.set_unusable_password()
                user.save()

            prof, _ = UserProfile.objects.get_or_create(user=user)
            prof.role = 'customer'
            if lead.phone and not prof.phone:
                prof.phone = lead.phone
            if lead.city and not prof.city:
                prof.city = lead.city
            if lead.district and not prof.district:
                prof.district = lead.district
            if lead.territory and not prof.territory:
                prof.territory = lead.territory
            prof.save()

            if lead.assigned_franchise:
                CustomerDealerRelationship.objects.get_or_create(
                    customer=user,
                    defaults={
                        'registered_franchise': lead.assigned_franchise,
                        'current_serving_franchise': lead.assigned_franchise,
                        'district': lead.district or lead.assigned_franchise.district,
                    }
                )

            lead.converted_user = user
            lead.status = 'CONVERTED'
            lead.save()

            LeadActivity.objects.create(
                lead=lead,
                activity_type='status_change',
                title='Lead Converted to Customer',
                description=f'Customer account linked: {user.username} ({user.first_name or user.username})',
                created_by=actor
            )

            CRMActivityLog.objects.create(
                lead=lead,
                actor=actor,
                activity_type='STATUS_CHANGED',
                description=f'Lead converted to Customer profile (User ID: {user.id}, Username: {user.username})'
            )

            return Response({
                'success': True,
                'message': f'Lead successfully converted to Customer profile ({user.username}).',
                'lead': LeadSerializer(lead).data,
                'customer_id': user.id,
                'username': user.username,
            }, status=status.HTTP_200_OK)

        elif action in ['start_franchise_onboarding', 'franchise', 'franchise_onboarding']:
            user = None
            if lead.converted_user:
                user = lead.converted_user
            elif lead.phone:
                user = User.objects.filter(username=lead.phone).first()

            if not user:
                username = lead.phone if lead.phone else f"franchise_{lead.id}"
                user = User.objects.create_user(
                    username=username,
                    email=lead.email or f"{username}@franchiseprospect.com",
                    first_name=lead.name[:30],
                )
                user.set_unusable_password()
                user.save()

            prof, _ = UserProfile.objects.get_or_create(user=user)
            prof.role = 'franchise'
            prof.phone = lead.phone or prof.phone
            prof.city = lead.city or prof.city
            prof.district = lead.district or prof.district
            prof.territory = lead.territory or prof.territory
            prof.save()

            fp, created = FranchiseProfile.objects.get_or_create(
                user=user,
                defaults={
                    'business_name': f"{lead.name} Agency",
                    'city': lead.city or 'Raipur',
                    'district': lead.district or '',
                    'territory': lead.territory or '',
                    'phone': lead.phone,
                    'status': 'pending',
                }
            )

            lead.converted_user = user
            lead.status = 'AGREEMENT_PENDING'
            lead.lead_type = 'FRANCHISE'
            lead.save()

            LeadActivity.objects.create(
                lead=lead,
                activity_type='status_change',
                title='Franchise Onboarding Started',
                description=f'Onboarding initiated for franchise {fp.business_name}. Status: PENDING / UNDER_REVIEW.',
                created_by=actor
            )

            CRMActivityLog.objects.create(
                lead=lead,
                actor=actor,
                activity_type='STATUS_CHANGED',
                description=f'Franchise onboarding initiated (Profile ID: {fp.id}, Status: PENDING / UNDER_REVIEW)'
            )

            return Response({
                'success': True,
                'message': 'Franchise onboarding started successfully. Status set to PENDING / UNDER_REVIEW.',
                'lead': LeadSerializer(lead).data,
                'franchise_id': fp.id,
                'business_name': fp.business_name,
            }, status=status.HTTP_200_OK)

        return Response({
            'success': False,
            'message': f"Unknown conversion action '{action}'. Supported actions: 'convert_to_customer', 'start_franchise_onboarding'."
        }, status=status.HTTP_400_BAD_REQUEST)
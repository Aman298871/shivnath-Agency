import re
from django.db import transaction
from django.core.exceptions import ValidationError
from django.utils import timezone
from datetime import timedelta

from leads.models import (
    Lead,
    LeadJourneyState,
    WhatsAppIntegrationConfig,
    WhatsAppTemplate,
    WhatsAppMessageLog,
    CRMActivityLog,
)


class WhatsAppProviderBase:
    def send_message(self, recipient_phone, content, template_id=None, button_payloads=None):
        raise NotImplementedError

    def verify_webhook_signature(self, payload, signature):
        return True


class MockWhatsAppProvider(WhatsAppProviderBase):
    """
    Mock / Development WhatsApp provider that logs messages to WhatsAppMessageLog and console.
    """
    def send_message(self, recipient_phone, content, template_id=None, button_payloads=None):
        return {
            'status': 'SENT',
            'provider_message_id': f"MOCK-WA-{timezone.now().strftime('%Y%m%d%H%M%S%f')}",
            'error': None
        }


def get_active_whatsapp_provider():
    config = WhatsAppIntegrationConfig.objects.filter(is_active=True).first()
    # Default to MockWhatsAppProvider for safe local development and unit tests
    return MockWhatsAppProvider()


def validate_and_create_chatbot_inquiry(data, is_dealer_inquiry=False):
    """
    Validates and processes public inbound chatbot inquiries.
    Enforces REQUIRED email, exactly 10-digit mobile starting with 6/7/8/9,
    and deduplicates by phone/email.
    """
    from leads.models import LeadActivity
    from chat.models import ChatSession
    from django.db.models import Q

    name = (data.get('name') or data.get('full_name') or '').strip()
    phone = data.get('phone', '').strip()
    email = data.get('email', '').strip()
    district = data.get('district', '').strip()
    territory = data.get('territory', '').strip()
    locality = data.get('locality_or_address') or data.get('locality') or data.get('address', '').strip()
    session_id = str(data.get('session_id', '')).strip()

    # Validation
    if not (2 <= len(name) <= 50) or not re.search(r'[A-Za-z]', name):
        raise ValidationError("Full name must be 2 to 30 meaningful characters containing alphabetic letters.")

    clean_phone = re.sub(r'[^0-9]', '', phone)
    if clean_phone.startswith('91') and len(clean_phone) == 12:
        clean_phone = clean_phone[2:]
    if not (len(clean_phone) == 10 and clean_phone[0] in '6789'):
        raise ValidationError("Mobile number must be exactly 10 digits starting with 6, 7, 8, or 9.")

    if not email or '@' not in email or '.' not in email:
        raise ValidationError("A valid Email address is required.")

    # Deduplication check by phone OR email
    lead = Lead.objects.filter(phone=clean_phone).first() or Lead.objects.filter(email__iexact=email).first()

    is_new = False
    if not lead:
        lead = Lead(
            name=name,
            phone=clean_phone,
            email=email,
            district=district,
            territory=territory,
            locality=locality,
            city=district or 'Raipur',
            status='NEW',
            source='PUBLIC_CHATBOT'
        )
        is_new = True
    else:
        # Update existing lead fields if missing or default
        if name and lead.name in ['Guest Customer', 'Public Prospect', 'Prospect', 'Public Customer', '']:
            lead.name = name
        if email and not lead.email:
            lead.email = email
        if district and not lead.district:
            lead.district = district
        if territory and not lead.territory:
            lead.territory = territory
        if locality and not lead.locality:
            lead.locality = locality
        if not lead.source:
            lead.source = 'PUBLIC_CHATBOT'

    if is_dealer_inquiry:
        lead.investment_budget = data.get('investment_budget', '')
        lead.existing_business = 'yes' if data.get('existing_business') in [True, 'yes', 'Yes'] else 'no'
        lead.commercial_space = data.get('commercial_space', 'available')
        lead.previous_experience = data.get('previous_experience', '')
        lead.preferred_location = data.get('preferred_location', locality)

    lead.calculate_lead_score()
    lead.save()

    # Link any matching ChatSession to this Lead
    if session_id:
        ChatSession.objects.filter(session_id=session_id).update(
            lead=lead, customer_name=name, customer_phone=clean_phone, customer_email=email
        )
    ChatSession.objects.filter(
        Q(customer_phone=clean_phone) | Q(customer_email__iexact=email)
    ).filter(lead__isnull=True).update(lead=lead)

    # Initialize 15-day journey state if new
    journey, created = LeadJourneyState.objects.get_or_create(
        lead=lead,
        defaults={
            'current_step': 1,
            'scheduled_day_offset': 1,
            'next_scheduled_at': timezone.now() + timedelta(hours=2)
        }
    )

    action_text = "created" if is_new else "updated"
    CRMActivityLog.objects.create(
        lead=lead,
        activity_type='STATUS_CHANGED' if is_new else 'NOTE_ADDED',
        description=f"Inbound public chatbot inquiry {action_text}. Source: PUBLIC_CHATBOT. Qualified as {lead.score_category} (Score: {lead.lead_score_number})"
    )

    LeadActivity.objects.create(
        lead=lead,
        activity_type='note',
        title=f"Public Chatbot Inquiry ({'New' if is_new else 'Updated'})",
        description=f"Public Chatbot inquiry received for {name} ({clean_phone}). District: {district}, Territory: {territory}",
    )

    # Authoritative Admin & Super Admin notification
    try:
        from accounts.models import AdminNotification
        AdminNotification.objects.create(
            title=f"Chatbot Enquiry: {lead.name}",
            message=f"Inbound public chatbot enquiry ({action_text}) from {lead.name} ({clean_phone}). Qualified as {lead.score_category} (Score: {lead.lead_score_number}).",
            notification_type='general',
            reference_id=lead.id,
        )
    except Exception:
        pass

    return lead


def send_lead_journey_step(lead_id, step=1):
    """
    Executes automated nurture outreach for a step in the 15-day journey.
    Day 1: Welcome & Product Catalog
    Day 3: Wholesale Investment & Unit Economics
    Day 5: Quality Standards (RO + Mineral Fortification)
    Day 7: Dealer Support & Plant Visit Invitation
    Day 10: Logistics & Delivery Assurance
    Day 15: Final Follow-up & Territory Exclusivity Check
    """
    lead = Lead.objects.get(id=lead_id)
    journey = lead.journey_state

    if journey.is_paused:
        return False, f"Journey paused: {journey.pause_reason}"

    step_templates = {
        1: ("welcome_dealer_inquiry", "Welcome to Shivnath Agency! Pure drinking water wholesale distribution."),
        2: ("day_3_economics", "Shivnath Agency Wholesale Economics: Attractive dealer margins and volume incentives."),
        3: ("day_5_quality", "Shivnath Pure Water: Advanced multi-stage purification and automated bottling."),
        4: ("day_7_visit", "Schedule your Shivnath central manufacturing plant visit today."),
        5: ("day_10_logistics", "Dedicated dispatch logistics and buffer stock management for distributors."),
        6: ("day_15_final", "Final check on dealership territory exclusivity for your area.")
    }

    template_key, default_body = step_templates.get(step, ("general_followup", "Shivnath Agency Follow-up"))
    template = WhatsAppTemplate.objects.filter(template_name=template_key).first()
    body_text = template.body_content if template else default_body

    provider = get_active_whatsapp_provider()
    result = provider.send_message(
        recipient_phone=lead.phone,
        content=body_text,
        template_id=template.provider_template_id if template else None
    )

    # Log outbound WhatsApp message
    msg = WhatsAppMessageLog.objects.create(
        message_id=result.get('provider_message_id', ''),
        lead=lead,
        recipient_phone=lead.phone,
        direction='OUTBOUND',
        template_used=template,
        raw_content=body_text,
        delivery_status=result.get('status', 'SENT')
    )

    # Advance journey step
    journey.last_triggered_at = timezone.now()
    step_offsets = {1: 3, 2: 5, 3: 7, 4: 10, 5: 15, 6: None}
    next_offset = step_offsets.get(step)
    if next_offset:
        journey.current_step = step + 1
        journey.scheduled_day_offset = next_offset
        journey.next_scheduled_at = timezone.now() + timedelta(days=(next_offset - (1 if step == 1 else step_offsets.get(step - 1, 1))))
    else:
        journey.completed_at = timezone.now()
    journey.save()

    return True, msg


def handle_incoming_whatsapp_reply(phone_number=None, text_content=None, sender_phone=None, message_text=None, button_payload='', provider_message_id=''):
    """
    Processes inbound WhatsApp reply from user or prospective dealer.
    Handles opt-outs (STOP), high-intent human takeover, and persists interaction.
    """
    phone = phone_number or sender_phone or ''
    text = text_content or message_text or button_payload or ''

    lead = Lead.objects.filter(phone=phone).first()

    # Log inbound message
    WhatsAppMessageLog.objects.create(
        message_id=provider_message_id or f"IN-{timezone.now().strftime('%Y%m%d%H%M%S')}",
        lead=lead,
        recipient_phone=phone,
        direction='INBOUND',
        raw_content=text,
        delivery_status='DELIVERED'
    )

    if not lead:
        return "Acknowledged"

    text_lower = text.strip().lower()

    # Check Opt-out
    if text_lower in ['stop', 'unsubscribe', 'optout', 'cancel']:
        if hasattr(lead, 'journey_state'):
            lead.journey_state.is_paused = True
            lead.journey_state.pause_reason = 'OPT_OUT'
            lead.journey_state.save()
        CRMActivityLog.objects.create(
            lead=lead,
            activity_type='NOTE_ADDED',
            description="Customer opted out via WhatsApp reply (STOP)."
        )
        return "Opt-out processed"

    # High-intent lead reply -> Human Takeover
    if any(k in text_lower for k in ['dealer', 'distributor', 'visit', 'call', 'meeting', 'interested', 'order', 'quotation']):
        if hasattr(lead, 'journey_state'):
            lead.journey_state.is_paused = True
            lead.journey_state.pause_reason = 'HUMAN_TAKEOVER'
            lead.journey_state.save()
        CRMActivityLog.objects.create(
            lead=lead,
            activity_type='NOTE_ADDED',
            description=f"Automated journey paused for human sales intervention upon reply: '{text}'"
        )
        return "Human takeover triggered"

    CRMActivityLog.objects.create(
        lead=lead,
        activity_type='NOTE_ADDED',
        description=f"Inbound reply received: '{text}'"
    )
    return "Processed"

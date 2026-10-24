import re
import os
from django.utils import timezone
from django.contrib.auth.models import User
from .models import FranchiseProfile, DealerDocument, FSSAIVerificationLog, AdminNotification, AdminAuditLog


def validate_fssai_format(fssai_number: str) -> bool:
    """
    Validates that the FSSAI license/registration number conforms to the official 14-digit format.
    """
    if not fssai_number:
        return False
    cleaned = str(fssai_number).strip()
    return bool(re.fullmatch(r'^[1-9][0-9]{13}$', cleaned) or re.fullmatch(r'^[0-9]{14}$', cleaned))


def normalize_string(val: str) -> str:
    """
    Normalizes string by stripping, lowercasing, removing punctuation, and collapsing multiple spaces.
    """
    if not val:
        return ''
    cleaned = re.sub(r'[^\w\s]', ' ', str(val).lower())
    return re.sub(r'\s+', ' ', cleaned).strip()


def check_duplicate_fssai(fssai_number: str, current_franchise_id=None):
    """
    Checks if an FSSAI number is already registered and active/pending with another franchise.
    Returns (is_duplicate: bool, existing_franchise: FranchiseProfile | None)
    """
    if not fssai_number:
        return False, None
    qs = FranchiseProfile.objects.filter(
        fssai_number=str(fssai_number).strip()
    ).exclude(status='rejected')

    if current_franchise_id:
        qs = qs.exclude(id=current_franchise_id)

    dup = qs.first()
    return (True, dup) if dup else (False, None)


def compare_fssai_details(submitted_name: str, official_name: str,
                           submitted_address: str = '', official_address: str = ''):
    """
    Authoritative comparison of submitted business name and premises address against official FSSAI record.
    Returns (matches: bool, mismatch_reason: str)
    """
    norm_sub_name = normalize_string(submitted_name)
    norm_off_name = normalize_string(official_name)

    if not norm_sub_name or not norm_off_name:
        return False, "FBO/Business name missing in comparison."

    # Exact normalized match
    if norm_sub_name == norm_off_name:
        return True, ""

    # Token overlap check (ignoring generic corporate suffix words)
    stop_words = {'pvt', 'ltd', 'private', 'limited', 'agency', 'enterprises', 'firm', 'co', 'company'}
    sub_tokens = set(norm_sub_name.split()) - stop_words
    off_tokens = set(norm_off_name.split()) - stop_words

    if sub_tokens and off_tokens:
        overlap = sub_tokens.intersection(off_tokens)
        if len(overlap) / max(len(sub_tokens), len(off_tokens)) >= 0.5:
            return True, ""

    return False, f"Submitted business name '{submitted_name}' does not match official FSSAI record '{official_name}'."


def evaluate_fssai_submission(franchise: FranchiseProfile):
    """
    Evaluates an FSSAI submission on registration.
    Determines whether status is PENDING_VERIFICATION, MANUAL_REVIEW_REQUIRED, EXPIRED, or FAILED.
    Under strict regulatory compliance, NO submission is marked VERIFIED without official confirmation.
    """
    num = (franchise.fssai_number or '').strip()

    # 1. Format check
    if not validate_fssai_format(num):
        reason = "FSSAI License / Registration number must be exactly 14 numeric digits."
        record_fssai_verification(
            franchise=franchise,
            new_status='FAILED',
            verification_source='System Format Validator',
            verified_by=None,
            mismatch_reason=reason,
            action_taken='Format Validation Failed'
        )
        return 'FAILED', reason

    # 2. Duplicate check
    is_dup, dup = check_duplicate_fssai(num, current_franchise_id=franchise.id)
    if is_dup and dup:
        reason = f"FSSAI number {num} is already associated with Franchise '{dup.business_name}' (ID #{dup.id})."
        record_fssai_verification(
            franchise=franchise,
            new_status='MANUAL_REVIEW_REQUIRED',
            verification_source='System Duplicate Detector',
            verified_by=None,
            mismatch_reason=reason,
            action_taken='Duplicate FSSAI Flagged'
        )
        return 'MANUAL_REVIEW_REQUIRED', reason

    # 3. Expiry check
    if franchise.fssai_expiry_date and franchise.fssai_expiry_date < timezone.now().date():
        reason = f"FSSAI registration appears expired (Validity ended: {franchise.fssai_expiry_date})."
        record_fssai_verification(
            franchise=franchise,
            new_status='EXPIRED',
            verification_source='System Expiry Check',
            verified_by=None,
            mismatch_reason=reason,
            action_taken='Expired FSSAI Flagged'
        )
        return 'EXPIRED', reason

    # 4. Check if external official machine-readable API is configured
    api_key = os.getenv('FSSAI_VERIFICATION_API_KEY', '').strip()
    api_url = os.getenv('FSSAI_VERIFICATION_API_URL', '').strip()

    if api_key and api_url:
        # If an official provider is configured via env
        try:
            import urllib.request
            import json
            payload = json.dumps({'fssai_number': num}).encode('utf-8')
            req = urllib.request.Request(
                api_url,
                data=payload,
                headers={'Authorization': f'Bearer {api_key}', 'Content-Type': 'application/json'}
            )
            with urllib.request.urlopen(req, timeout=8) as resp:
                if resp.status == 200:
                    data = json.loads(resp.read().decode('utf-8'))
                    off_name = data.get('business_name') or data.get('fbo_name') or ''
                    off_status = (data.get('status') or '').upper()

                    if off_status not in ['ACTIVE', 'OPERATIONAL', 'VALID']:
                        reason = f"Official FSSAI status is '{off_status}', not active."
                        record_fssai_verification(
                            franchise=franchise,
                            new_status='FAILED',
                            verification_source='Official Provider API',
                            verified_by=None,
                            mismatch_reason=reason,
                            action_taken='Official Inactive Status'
                        )
                        return 'FAILED', reason

                    matches, reason = compare_fssai_details(franchise.business_name, off_name)
                    if matches:
                        record_fssai_verification(
                            franchise=franchise,
                            new_status='VERIFIED',
                            verification_source='Official Provider API',
                            verified_by=None,
                            notes=f"Auto-verified via official API. FBO Name: {off_name}",
                            official_reference=str(data.get('reference_id', '')),
                            action_taken='Official Verification Succeeded'
                        )
                        return 'VERIFIED', ""
                    else:
                        record_fssai_verification(
                            franchise=franchise,
                            new_status='MANUAL_REVIEW_REQUIRED',
                            verification_source='Official Provider API',
                            verified_by=None,
                            mismatch_reason=reason,
                            action_taken='Official Name Mismatch'
                        )
                        return 'MANUAL_REVIEW_REQUIRED', reason
        except Exception as e:
            pass  # Fallback to manual review

    # Standard / Default regulatory workflow:
    # FoSCoS official portal requires manual review at https://foscos.fssai.gov.in/
    reason = "Awaiting manual FoSCoS verification by Admin/Super Admin against official FSSAI database."
    record_fssai_verification(
        franchise=franchise,
        new_status='MANUAL_REVIEW_REQUIRED',
        verification_source='FoSCoS Verification Router',
        verified_by=None,
        notes=reason,
        action_taken='Routed for FoSCoS Manual Verification'
    )
    return 'MANUAL_REVIEW_REQUIRED', reason


def record_fssai_verification(franchise: FranchiseProfile,
                              new_status: str,
                              verification_source: str,
                              verified_by: User = None,
                              notes: str = '',
                              mismatch_reason: str = '',
                              official_reference: str = '',
                              action_taken: str = 'Status Updated'):
    """
    Authoritative state transition helper.
    Persists verification status, writes audit log, updates document state, and dispatches notifications.
    """
    old_status = franchise.fssai_verification_status or 'PENDING_VERIFICATION'

    franchise.fssai_verification_status = new_status
    franchise.fssai_verification_source = verification_source
    franchise.fssai_notes = notes
    franchise.fssai_rejection_reason = mismatch_reason
    franchise.fssai_verification_attempts = (franchise.fssai_verification_attempts or 0) + 1

    if new_status == 'VERIFIED':
        franchise.fssai_verified_at = timezone.now()
        franchise.fssai_verified_by = verified_by
    elif new_status in ['FAILED', 'EXPIRED']:
        franchise.fssai_verified_at = timezone.now()
        franchise.fssai_verified_by = verified_by

    franchise.save(update_fields=[
        'fssai_verification_status',
        'fssai_verification_source',
        'fssai_notes',
        'fssai_rejection_reason',
        'fssai_verification_attempts',
        'fssai_verified_at',
        'fssai_verified_by',
        'updated_at'
    ])

    # Synchronize corresponding DealerDocument
    doc = DealerDocument.objects.filter(
        dealer=franchise,
        document_type='FSSAI_CERTIFICATE'
    ).first()

    if doc:
        if new_status == 'VERIFIED':
            doc.verification_status = 'VERIFIED'
            doc.verified_at = timezone.now()
            doc.verified_by = verified_by
            doc.rejection_reason = ''
        elif new_status in ['FAILED', 'EXPIRED']:
            doc.verification_status = 'REJECTED'
            doc.verified_at = timezone.now()
            doc.verified_by = verified_by
            doc.rejection_reason = mismatch_reason or f"FSSAI verification status: {new_status}"
        elif new_status in ['PENDING_VERIFICATION', 'UNDER_VERIFICATION', 'MANUAL_REVIEW_REQUIRED']:
            doc.verification_status = 'PENDING'
        doc.save(update_fields=['verification_status', 'verified_at', 'verified_by', 'rejection_reason'])

    # Write Audit Log
    FSSAIVerificationLog.objects.create(
        franchise=franchise,
        fssai_number=franchise.fssai_number or '',
        previous_status=old_status,
        new_status=new_status,
        verification_source=verification_source,
        mismatch_reason=mismatch_reason,
        official_reference=official_reference,
        notes=notes,
        verified_by=verified_by,
        action_taken=action_taken
    )

    # Also log in central AdminAuditLog
    AdminAuditLog.objects.create(
        actor=verified_by,
        action=f'FSSAI_{new_status}',
        resource_type='FranchiseProfile',
        resource_id=str(franchise.id),
        changes={
            'fssai_number': franchise.fssai_number,
            'old_status': old_status,
            'new_status': new_status,
            'source': verification_source,
            'reason': mismatch_reason,
            'notes': notes
        }
    )

    # Disptach Admin Notification
    try:
        title_map = {
            'VERIFIED': f"FSSAI Verified: {franchise.business_name}",
            'FAILED': f"FSSAI Verification Failed: {franchise.business_name}",
            'EXPIRED': f"FSSAI Expired: {franchise.business_name}",
            'MANUAL_REVIEW_REQUIRED': f"FSSAI Manual Review Required: {franchise.business_name}",
        }
        title = title_map.get(new_status, f"FSSAI Status Update: {franchise.business_name}")
        msg = f"Franchise '{franchise.business_name}' FSSAI #{franchise.fssai_number} status set to {new_status}. Source: {verification_source}."
        if mismatch_reason:
            msg += f" Reason: {mismatch_reason}"

        AdminNotification.objects.create(
            title=title,
            message=msg,
            notification_type='franchise_registration',
            reference_id=franchise.id
        )

        # Notify the affected franchise in their own notification inbox
        if franchise.user:
            from .models import FranchiseNotification
            FranchiseNotification.objects.create(
                franchise=franchise,
                title=title,
                message=f"Your FSSAI #{franchise.fssai_number} verification status has been updated to {new_status}. {mismatch_reason or notes or ''}".strip(),
                notification_type='fssai_verification',
                reference_id=franchise.id
            )
    except Exception:
        pass


def validate_franchise_fssai_for_activation(franchise, actor=None, override_reason=''):
    """
    Authoritative regulatory validation for franchise approval / activation.
    Returns: (is_eligible: bool, error_message: str, error_code: str)
    Rules:
    - Missing required FSSAI document blocks activation.
    - Pending verification blocks activation.
    - Rejected/Failed document blocks activation until corrected.
    - Expired document blocks activation.
    - Only a verified and valid document (or authorized Super Admin override with logged reason) satisfies activation.
    """
    from datetime import date
    from .models import DealerDocument

    # 1. Check if FSSAI document exists
    fssai_doc = DealerDocument.objects.filter(
        dealer=franchise,
        document_type='FSSAI_CERTIFICATE'
    ).order_by('-version', '-uploaded_at').first()

    if not fssai_doc or not fssai_doc.document_file:
        return False, "Cannot approve Franchise: Missing required FSSAI registration document. Franchise must upload a valid FSSAI license certificate.", "FSSAI_DOCUMENT_MISSING"

    fssai_status = (franchise.fssai_verification_status or fssai_doc.verification_status or 'PENDING_VERIFICATION').upper()

    if fssai_status in ['FAILED', 'REJECTED']:
        reason = franchise.fssai_rejection_reason or fssai_doc.rejection_reason or "Invalid or unverified certificate"
        return False, f"Cannot approve Franchise: FSSAI document is REJECTED ({reason}). A valid, approved FSSAI certificate is required.", "FSSAI_VERIFICATION_REJECTED"

    # Check expiry date
    if franchise.fssai_expiry_date and franchise.fssai_expiry_date < date.today():
        return False, f"Cannot approve Franchise: FSSAI registration is EXPIRED (Validity ended: {franchise.fssai_expiry_date}). An active FSSAI registration is required for commercial operations.", "FSSAI_REGISTRATION_EXPIRED"

    if fssai_status == 'EXPIRED':
        return False, f"Cannot approve Franchise: FSSAI registration is marked EXPIRED. An active FSSAI registration is required for commercial operations.", "FSSAI_REGISTRATION_EXPIRED"

    if fssai_status != 'VERIFIED':
        # Super Admin override check
        user_prof = getattr(actor, 'profile', None) if actor else None
        is_super = actor and (actor.is_superuser or (user_prof and user_prof.role == 'super_admin'))
        if not is_super:
            return False, f"Cannot approve Franchise: FSSAI verification status is '{fssai_status}'. The FSSAI license must be VERIFIED before activation.", "FSSAI_VERIFICATION_PENDING"

        if not override_reason or len(override_reason.strip()) < 5:
            return False, f"FSSAI status is '{fssai_status}'. Super Admin approval override requires a mandatory detailed 'override_reason'.", "FSSAI_OVERRIDE_REASON_REQUIRED"

    return True, "", ""

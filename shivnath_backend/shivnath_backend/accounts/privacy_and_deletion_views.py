import logging
from django.contrib.auth import get_user_model
from django.db import transaction
from django.http import HttpResponse
from django.utils import timezone
from rest_framework import status
from rest_framework.permissions import IsAuthenticated, AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import AccountDeletionRequest, DeviceToken, UserProfile, FranchiseProfile

logger = logging.getLogger(__name__)
User = get_user_model()


class AccountDeletionAPIView(APIView):
    """
    In-App Account Deletion Endpoint (Play Store Compliance).
    Allows authenticated users to delete their account directly within the app.
    - Requires password verification.
    - For customers: Anonymizes PII, revokes tokens, deactivates account,
      and marks request COMPLETED while legally preserving statutory tax/invoice history.
    - For franchises/admins: Registers a PENDING request for administrative review
      due to active inventory and financial ledger dependencies.
    """
    permission_classes = [IsAuthenticated]

    def post(self, request):
        user = request.user
        password = request.data.get('password', '').strip()
        reason = request.data.get('reason', 'In-App Account Deletion Request').strip()

        if not password:
            return Response(
                {
                    'success': False,
                    'message': 'Password is required to confirm account deletion for security verification.'
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        if not user.check_password(password):
            return Response(
                {
                    'success': False,
                    'message': 'Incorrect password. Verification failed.'
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        user_role = getattr(getattr(user, 'profile', None), 'role', 'customer')

        with transaction.atomic():
            if user_role == 'customer':
                # Deactivate all active FCM device tokens
                DeviceToken.objects.filter(user=user).update(is_active=False)

                # Anonymize personal profile data
                anonymized_tag = f"anon_{user.id}_{int(timezone.now().timestamp())}"
                user.first_name = "Deleted"
                user.last_name = "User"
                user.email = f"{anonymized_tag}@waternow.internal"
                user.is_active = False

                # If CustomerProfile exists, anonymize contact details
                if hasattr(user, 'customer_profile'):
                    cp = user.customer_profile
                    cp.address = "Anonymized on user request"
                    cp.notes = "Account deleted via in-app user request."
                    cp.save(update_fields=['address', 'notes'])

                if hasattr(user, 'profile'):
                    p = user.profile
                    p.phone = f"00000{user.id}"[-10:]
                    p.address = "Anonymized on user request"
                    p.save(update_fields=['phone', 'address'])

                user.save()

                del_req = AccountDeletionRequest.objects.create(
                    user=user,
                    identifier=user.username,
                    reason=reason,
                    status='COMPLETED',
                    requested_via='IN_APP',
                    ip_address=request.META.get('REMOTE_ADDR'),
                    processed_at=timezone.now(),
                    audit_notes="Customer self-deleted in-app. PII anonymized; statutory GST invoices retained."
                )

                logger.info(
                    "SECURITY: Customer account '%s' (ID %d) deleted and anonymized in-app.",
                    user.username,
                    user.id
                )

                return Response(
                    {
                        'success': True,
                        'message': (
                            'Your account has been deleted successfully. Your personal details, login access, '
                            'and device notifications have been removed. In accordance with statutory Indian tax and '
                            'accounting laws (CGST Act 2017), past order and invoice records are preserved for audit purposes.'
                        ),
                        'request_id': del_req.id,
                        'status': 'COMPLETED',
                    },
                    status=status.HTTP_200_OK
                )
            else:
                # Privileged accounts (Franchise, Admin, Super Admin)
                del_req = AccountDeletionRequest.objects.create(
                    user=user,
                    identifier=user.username,
                    reason=reason,
                    status='PENDING',
                    requested_via='IN_APP',
                    ip_address=request.META.get('REMOTE_ADDR'),
                    audit_notes=f"Privileged role ({user_role}) deletion request submitted. Requires manual review."
                )

                logger.info(
                    "SECURITY: Privileged account '%s' (role: %s) requested deletion. Pending manual review.",
                    user.username,
                    user_role
                )

                return Response(
                    {
                        'success': True,
                        'message': (
                            'Account deletion request submitted for administrative review. Because your account '
                            'is associated with enterprise inventory or operations, central administration will '
                            'reconcile any pending ledgers and finalize the request within 2 business days.'
                        ),
                        'request_id': del_req.id,
                        'status': 'PENDING',
                    },
                    status=status.HTTP_200_OK
                )


def privacy_policy_html_view(request):
    """
    Publicly accessible, mobile-responsive HTML Privacy Policy for Play Store compliance.
    Loads without authentication over HTTPS.
    """
    html = """<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Privacy Policy — WATERNow (Shivnath Agency)</title>
    <style>
        :root {
            --primary: #0284C7;
            --primary-dark: #0369A1;
            --text-main: #1E293B;
            --text-muted: #64748B;
            --bg-page: #F8FAFC;
            --bg-card: #FFFFFF;
            --border: #E2E8F0;
        }
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
            margin: 0;
            padding: 0;
            background-color: var(--bg-page);
            color: var(--text-main);
            line-height: 1.6;
        }
        header {
            background: linear-gradient(135deg, #0284C7 0%, #0369A1 100%);
            color: white;
            padding: 36px 20px;
            text-align: center;
        }
        header h1 {
            margin: 0 0 8px 0;
            font-size: 28px;
            font-weight: 800;
            letter-spacing: -0.5px;
        }
        header p {
            margin: 0;
            font-size: 14px;
            opacity: 0.9;
        }
        .container {
            max-width: 820px;
            margin: -20px auto 40px auto;
            padding: 0 16px;
        }
        .card {
            background: var(--bg-card);
            border-radius: 14px;
            padding: 28px 24px;
            margin-bottom: 20px;
            border: 1px solid var(--border);
            box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.05);
        }
        h2 {
            color: var(--primary-dark);
            font-size: 20px;
            margin-top: 0;
            margin-bottom: 14px;
            border-bottom: 2px solid #E0F2FE;
            padding-bottom: 8px;
        }
        ul {
            padding-left: 20px;
            margin: 10px 0;
        }
        li {
            margin-bottom: 8px;
        }
        .badge {
            display: inline-block;
            background: #E0F2FE;
            color: #0369A1;
            font-size: 12px;
            font-weight: 700;
            padding: 4px 10px;
            border-radius: 20px;
            margin-bottom: 12px;
        }
        .contact-box {
            background: #F0F9FF;
            border-left: 4px solid var(--primary);
            padding: 16px;
            border-radius: 0 8px 8px 0;
            margin-top: 14px;
        }
        a {
            color: var(--primary);
            text-decoration: none;
            font-weight: 600;
        }
        a:hover {
            text-decoration: underline;
        }
        footer {
            text-align: center;
            padding: 24px;
            color: var(--text-muted);
            font-size: 13px;
        }
    </style>
</head>
<body>
    <header>
        <h1>WATERNow Privacy Policy</h1>
        <p>Enterprise Packaged Drinking Water Distribution Platform — Shivnath Agency</p>
        <p style="margin-top: 6px; font-size: 12px;">Last Updated: October 12, 2026</p>
    </header>

    <div class="container">
        <div class="card">
            <span class="badge">Official Compliance Document</span>
            <h2>1. Introduction & Overview</h2>
            <p>
                Welcome to <strong>WATERNow</strong>, an enterprise packaged drinking water ordering, supply chain, and distribution platform operated by <strong>Shivnath Agency</strong> ("we", "us", or "our"). 
                We are committed to protecting the privacy, security, and personal data of our customers, franchise distributors, and administrative users.
            </p>
            <p>
                This Privacy Policy explains how our mobile application (<strong>Water Wala</strong>, Application ID: <code>com.shivnath.waterwala</code>) and associated backend APIs collect, process, retain, and protect your information in full accordance with the Information Technology Act 2000, the Digital Personal Data Protection (DPDP) Act 2023, and Google Play Store policies.
            </p>
        </div>

        <div class="card">
            <h2>2. Information We Collect</h2>
            <p>We collect only the minimum information necessary to fulfill water deliveries, process payments, and manage territory logistics:</p>
            <ul>
                <li><strong>Personal Identifiers:</strong> Name, phone number, email address, and customer identification code (e.g. <code>CUST-XXXXXX</code>).</li>
                <li><strong>Delivery & Location Information:</strong> Physical delivery address, locality/service area, district, and territory zone in Chhattisgarh, India. Location is used solely to route water deliveries to the nearest serving franchise.</li>
                <li><strong>Transaction & Order History:</strong> Products ordered (200ml, 250ml, 500ml, 1L, 20L jars), quantities, billing invoices, delivery statuses, and payment modes.</li>
                <li><strong>Franchise Business Information:</strong> Commercial business name, GSTIN (optional), FSSAI license numbers, and territory operations data for verified dealers.</li>
                <li><strong>Device & Notification Data:</strong> Firebase Cloud Messaging (FCM) device registration tokens used strictly to deliver real-time order tracking and dispatch alerts.</li>
            </ul>
        </div>

        <div class="card">
            <h2>3. Third-Party Services & Payment Security</h2>
            <p>We integrate with industry-leading, compliant third-party infrastructure:</p>
            <ul>
                <li>
                    <strong>Razorpay (Payment Gateway):</strong> Online payments (UPI, Cards, NetBanking, Wallets) are processed directly by Razorpay Software Private Limited. 
                    <em>WATERNow never collects, processes, or stores your credit/debit card numbers, CVVs, netbanking passwords, or UPI MPINs on our servers.</em>
                </li>
                <li>
                    <strong>Firebase Cloud Messaging (Google LLC):</strong> Used to deliver critical real-time push notifications regarding order confirmation, dispatch, and delivery.
                </li>
            </ul>
        </div>

        <div class="card">
            <h2>4. Data Retention & Legal Storage Exceptions</h2>
            <p>
                We retain your personal account data as long as your account remains active.
            </p>
            <p>
                <strong>Statutory Accounting Exception:</strong> Under the Central Goods and Services Tax (CGST) Act 2017 and Section 128 of the Companies Act 2013, businesses in India are legally mandated to retain books of accounts, tax invoices, and financial transaction records for a minimum statutory period of <strong>7 to 8 years</strong>. If an account is deleted, personal marketing contact details and device tokens are removed immediately, while historical invoice records are retained in an anonymized, audited ledger.
            </p>
        </div>

        <div class="card">
            <h2>5. Your Rights & In-App Account Deletion</h2>
            <p>You have full control over your personal data:</p>
            <ul>
                <li><strong>In-App Deletion:</strong> You can delete your account at any time directly in the WaterNow application by navigating to: <strong>Profile / Settings &rarr; Account &rarr; Delete Account</strong>.</li>
                <li><strong>Web-Based Request:</strong> If you do not have the app installed, you can submit an account deletion request via our public portal at: <a href="/account-deletion/">https://shivnath-agency.onrender.com/account-deletion/</a>.</li>
                <li><strong>Right to Rectification:</strong> You may update your profile or delivery address at any time within the app or by contacting customer support.</li>
            </ul>
        </div>

        <div class="card">
            <h2>6. Security Practices</h2>
            <p>
                All communications between the mobile application and backend services are encrypted in transit using Transport Layer Security (TLS 1.3 / HTTPS). Passwords are cryptographically hashed using PBKDF2 with SHA-256 and salted. Sensitive payment secrets remain server-side and are never bundled in application binaries.
            </p>
            <div class="contact-box">
                <strong>Grievance & Privacy Contact:</strong><br>
                Shivnath Agency (WATERNow Enterprise)<br>
                Farishta Complex, G.E. Road, Raipur, Chhattisgarh - 492001, India<br>
                Admin Helpline: <strong>+91 98062 47194</strong><br>
                Privacy Email: <strong>privacy@waternow.in</strong> / <strong>support@waternow.in</strong>
            </div>
        </div>
    </div>

    <footer>
        &copy; 2026 Shivnath Agency. All rights reserved. WaterNow Packaged Drinking Water Distribution.
    </footer>
</body>
</html>"""
    return HttpResponse(html, content_type='text/html')


def public_account_deletion_html_view(request):
    """
    Publicly accessible web page allowing users to request account deletion
    without reinstalling the application (Google Play Requirement).
    """
    message = None
    message_type = None

    if request.method == 'POST':
        identifier = request.POST.get('identifier', '').strip()
        reason = request.POST.get('reason', '').strip()
        consent = request.POST.get('consent')

        if not identifier:
            message = "Please provide your registered phone number, email, or Customer Code."
            message_type = "error"
        elif not consent:
            message = "Please confirm that you understand the account deletion and tax retention terms."
            message_type = "error"
        else:
            # Register web deletion request safely
            matched_user = (
                User.objects.filter(username__iexact=identifier).first() or
                User.objects.filter(email__iexact=identifier).first() or
                User.objects.filter(profile__phone__iexact=identifier).first()
            )

            req = AccountDeletionRequest.objects.create(
                user=matched_user,
                identifier=identifier,
                reason=reason or "Requested via public web page",
                status='PENDING',
                requested_via='WEB',
                ip_address=request.META.get('REMOTE_ADDR'),
                audit_notes="Submitted via public web form. Awaiting customer contact verification."
            )

            message = (
                f"Your account deletion request has been registered (Reference ID: #{req.id}). "
                "Our team will verify ownership and process the deletion within 2 business days. "
                "You will receive an SMS/email confirmation once complete."
            )
            message_type = "success"

    html = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Request Account Deletion — WATERNow</title>
    <style>
        :root {{
            --primary: #0284C7;
            --primary-dark: #0369A1;
            --text-main: #1E293B;
            --text-muted: #64748B;
            --bg-page: #F8FAFC;
            --bg-card: #FFFFFF;
            --border: #E2E8F0;
        }}
        body {{
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
            margin: 0;
            padding: 0;
            background-color: var(--bg-page);
            color: var(--text-main);
            line-height: 1.6;
        }}
        header {{
            background: linear-gradient(135deg, #0284C7 0%, #0369A1 100%);
            color: white;
            padding: 32px 20px;
            text-align: center;
        }}
        header h1 {{
            margin: 0 0 6px 0;
            font-size: 26px;
            font-weight: 800;
        }}
        .container {{
            max-width: 680px;
            margin: -20px auto 40px auto;
            padding: 0 16px;
        }}
        .card {{
            background: var(--bg-card);
            border-radius: 14px;
            padding: 28px 24px;
            border: 1px solid var(--border);
            box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.05);
        }}
        .alert {{
            padding: 14px 16px;
            border-radius: 8px;
            margin-bottom: 20px;
            font-size: 14px;
        }}
        .alert-success {{
            background: #ECFDF5;
            color: #065F46;
            border: 1px solid #A7F3D0;
        }}
        .alert-error {{
            background: #FEF2F2;
            color: #991B1B;
            border: 1px solid #FECACA;
        }}
        label {{
            display: block;
            font-weight: 600;
            margin-top: 16px;
            margin-bottom: 6px;
            font-size: 14px;
        }}
        input[type="text"], textarea {{
            width: 100%;
            box-sizing: border-box;
            padding: 12px;
            border: 1px solid var(--border);
            border-radius: 8px;
            font-size: 15px;
        }}
        input[type="text"]:focus, textarea:focus {{
            outline: none;
            border-color: var(--primary);
            box-shadow: 0 0 0 3px rgba(2, 132, 199, 0.15);
        }}
        .checkbox-container {{
            display: flex;
            align-items: flex-start;
            margin-top: 18px;
            gap: 10px;
            font-size: 13px;
            color: var(--text-muted);
        }}
        .btn {{
            background: #DC2626;
            color: white;
            border: none;
            padding: 14px 20px;
            border-radius: 8px;
            font-size: 16px;
            font-weight: 700;
            width: 100%;
            cursor: pointer;
            margin-top: 22px;
            transition: background 0.2s;
        }}
        .btn:hover {{
            background: #B91C1C;
        }}
        .info-box {{
            background: #F1F5F9;
            padding: 14px;
            border-radius: 8px;
            font-size: 13px;
            color: var(--text-muted);
            margin-top: 20px;
        }}
        footer {{
            text-align: center;
            padding: 24px;
            color: var(--text-muted);
            font-size: 13px;
        }}
    </style>
</head>
<body>
    <header>
        <h1>WATERNow Account Deletion Portal</h1>
        <p>Public Self-Service Request — Shivnath Agency</p>
    </header>

    <div class="container">
        <div class="card">
            {"<div class='alert alert-" + message_type + "'>" + message + "</div>" if message else ""}

            <p style="margin-top: 0; font-size: 14px; color: var(--text-muted);">
                If you have an active WaterNow customer or franchise account and wish to delete your account and associated personal data, submit your request below without reinstalling the application.
            </p>

            <form method="POST">
                <label for="identifier">Registered Phone Number, Email, or Customer ID *</label>
                <input type="text" id="identifier" name="identifier" required placeholder="e.g. 9806247194 or CUST-655760">

                <label for="reason">Reason for Deletion (Optional)</label>
                <textarea id="reason" name="reason" rows="3" placeholder="Let us know why you wish to delete your account..."></textarea>

                <div class="checkbox-container">
                    <input type="checkbox" id="consent" name="consent" required style="margin-top: 3px;">
                    <label for="consent" style="margin: 0; font-weight: normal;">
                        I understand that deleting my account permanently deactivates my login credentials, deletes registered push notification tokens, and anonymizes my profile. Statutory invoices and order transactions will be retained in accordance with Indian GST and accounting regulations.
                    </label>
                </div>

                <button type="submit" class="btn">Submit Account Deletion Request</button>
            </form>

            <div class="info-box">
                <strong>Need immediate assistance?</strong><br>
                You can also contact our Data Protection Officer directly:<br>
                Admin Helpline: <strong>+91 98062 47194</strong> | Email: <strong>support@waternow.in</strong><br>
                View our complete <a href="/privacy-policy/" style="color: var(--primary);">Privacy Policy</a>.
            </div>
        </div>
    </div>

    <footer>
        &copy; 2026 Shivnath Agency. All rights reserved.
    </footer>
</body>
</html>"""
    return HttpResponse(html, content_type='text/html')

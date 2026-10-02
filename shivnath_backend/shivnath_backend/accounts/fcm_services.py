import os
import logging
from django.conf import settings
from django.contrib.auth import get_user_model

logger = logging.getLogger(__name__)

_firebase_initialized = False

def _init_firebase():
    global _firebase_initialized
    if _firebase_initialized:
        return True

    try:
        # pyrefly: ignore [missing-import]
        import firebase_admin
        # pyrefly: ignore [missing-import]
        from firebase_admin import credentials

        if firebase_admin._apps:
            _firebase_initialized = True
            return True

        # Check for raw JSON credentials in environment variable
        raw_json = os.environ.get('FIREBASE_SERVICE_ACCOUNT_JSON')
        if raw_json and raw_json.strip():
            import json
            cred_dict = json.loads(raw_json)
            cred = credentials.Certificate(cred_dict)
            firebase_admin.initialize_app(cred)
            _firebase_initialized = True
            logger.info("FCM: Firebase Admin SDK initialized successfully from FIREBASE_SERVICE_ACCOUNT_JSON env var.")
            return True

        # Candidate paths for serviceAccountKey.json
        base_dir = getattr(settings, 'BASE_DIR', '')
        candidates = [
            os.environ.get('FIREBASE_CREDENTIALS_PATH'),
            os.environ.get('GOOGLE_APPLICATION_CREDENTIALS'),
            os.path.join(base_dir, 'serviceAccountKey.json'),
            os.path.join(base_dir, 'shivnath_backend', 'serviceAccountKey.json'),
            os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'serviceAccountKey.json'),
            os.path.join(os.path.dirname(os.path.abspath(__file__)), 'serviceAccountKey.json'),
            os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), 'serviceAccountKey.json'),
            os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), 'shivnath_backend', 'serviceAccountKey.json'),
        ]

        key_path = None
        for path in candidates:
            if path and os.path.exists(path):
                key_path = path
                break

        if not key_path:
            logger.warning("FCM: serviceAccountKey.json not found in candidates: %s", [c for c in candidates if c])
            return False

        cred = credentials.Certificate(key_path)
        firebase_admin.initialize_app(cred)
        _firebase_initialized = True
        logger.info("FCM: Firebase Admin SDK initialized successfully with %s", key_path)
        return True
    except Exception as e:
        logger.error("FCM: Failed to initialize Firebase Admin SDK: %s", e)
        return False


def send_fcm_notification(users, title, body, data=None, notification_type='general', reference_id=None):
    """
    Sends real Firebase Cloud Messaging (FCM) push notifications to one or multiple users.
    Automatically deactivates invalid/unregistered tokens.
    """
    if not users:
        return {'success': False, 'message': 'No users specified.'}

    User = get_user_model()
    if isinstance(users, User):
        users = [users]
    elif hasattr(users, '__iter__') and not isinstance(users, (list, tuple)):
        users = list(users)

    # 1. Ensure Firebase Admin is initialized
    if not _init_firebase():
        return {'success': False, 'message': 'Firebase Admin SDK not configured.'}

    # 2. Query active device tokens for these users
    from accounts.models import DeviceToken
    device_tokens_qs = DeviceToken.objects.filter(user__in=users, is_active=True)
    tokens = list(device_tokens_qs.values_list('token', flat=True).distinct())

    if not tokens:
        logger.info("FCM: No active device tokens found for users: %s", [u.username for u in users])
        return {'success': True, 'delivered_count': 0, 'message': 'No registered devices for user(s).'}

    # 3. Build string data payload (FCM requirement)
    clean_data = {}
    if data and isinstance(data, dict):
        for k, v in data.items():
            clean_data[str(k)] = str(v)
    clean_data['notification_type'] = str(notification_type)
    if reference_id:
        clean_data['reference_id'] = str(reference_id)
    clean_data['click_action'] = 'FLUTTER_NOTIFICATION_CLICK'

    try:
        from firebase_admin import messaging

        message = messaging.MulticastMessage(
            tokens=tokens,
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            data=clean_data,
            android=messaging.AndroidConfig(
                priority='high',
                notification=messaging.AndroidNotification(
                    title=title,
                    body=body,
                    sound='default',
                    channel_id='high_importance_channel',
                    icon='@mipmap/ic_launcher',
                )
            ),
            apns=messaging.ApnsConfig(
                payload=messaging.ApnsPayload(
                    aps=messaging.Aps(
                        alert=messaging.ApsAlert(
                            title=title,
                            body=body,
                        ),
                        sound='default',
                        badge=1,
                    )
                )
            ),
        )

        response = messaging.send_each_for_multicast(message)
        logger.info(
            "FCM: Sent %d/%d push messages successfully for '%s'",
            response.success_count,
            len(tokens),
            title
        )

        # 4. Handle expired / unregistered tokens
        if response.failure_count > 0:
            for idx, resp in enumerate(response.responses):
                if not resp.success:
                    err = resp.exception
                    bad_token = tokens[idx]
                    logger.warning("FCM: Delivery failed for token %s...: %s", bad_token[:10], err)
                    err_str = str(getattr(err, 'code', '') or err).upper()
                    if any(term in err_str for term in ['UNREGISTERED', 'INVALID', 'NOT_FOUND', 'REGISTRATION-TOKEN-NOT-REGISTERED']):
                        DeviceToken.objects.filter(token=bad_token).update(is_active=False)

        return {
            'success': True,
            'success_count': response.success_count,
            'failure_count': response.failure_count,
            'total_tokens': len(tokens),
        }
    except Exception as e:
        logger.error("FCM: Exception during send_each_for_multicast: %s", e)
        return {'success': False, 'error': str(e)}


# =========================================================
# REAL BUSINESS EVENT DISPATCHERS
# =========================================================

def notify_order_created(order):
    """
    Triggered when a new Order is placed.
    Notifies:
    1. Super Admin, Staff Admin, and Role Admins
    2. Serving Wholesale Dealer (Franchise)
    """
    User = get_user_model()
    admin_users = list(User.objects.filter(is_superuser=True))
    staff_admins = list(User.objects.filter(is_staff=True).exclude(is_superuser=True))
    role_admins = list(User.objects.filter(profile__role__in=['admin', 'super_admin']).exclude(is_superuser=True))
    all_admins = list(set(admin_users + staff_admins + role_admins))

    client_name = order.client_name or (order.created_by.get_full_name() if order.created_by else 'Client')
    title = f"New Order Placed: #{order.order_code}"
    body = f"Order #{order.order_code} for ₹{order.amount or order.grand_total} placed by {client_name}."

    # In-App Notification records (idempotent)
    try:
        from accounts.models import AdminNotification, FranchiseNotification
        AdminNotification.objects.get_or_create(
            title=f"New Order #{order.order_code} Placed",
            notification_type='order_placed',
            reference_id=order.id,
            defaults={'message': body}
        )
        if order.serving_franchise:
            FranchiseNotification.objects.get_or_create(
                franchise=order.serving_franchise,
                notification_type='order_placed',
                reference_id=order.id,
                defaults={'title': f"New Order #{order.order_code}", 'message': body}
            )
    except Exception as e:
        logger.warning("FCM: DB notification create warning in notify_order_created: %s", e)

    # Send to Admins
    send_fcm_notification(
        users=all_admins,
        title=title,
        body=body,
        data={'order_id': order.id, 'order_code': order.order_code, 'screen': 'admin_orders'},
        notification_type='order_placed',
        reference_id=order.id
    )

    # Send to Serving Franchise
    if order.serving_franchise and order.serving_franchise.user:
        send_fcm_notification(
            users=[order.serving_franchise.user],
            title=f"Order Assigned: #{order.order_code}",
            body=f"Client {client_name} placed order #{order.order_code} assigned to your territory.",
            data={'order_id': order.id, 'order_code': order.order_code, 'screen': 'franchise_orders'},
            notification_type='order_placed',
            reference_id=order.id
        )


def notify_order_status_update(order, new_status, actor_name=''):
    """
    Triggered when order status changes (Approval, Dispatched, Delivered, Cancelled).
    Notifies:
    1. The Customer who placed the order.
    2. Relevant Admins if action was taken by Franchise.
    """
    if not order.created_by:
        return

    status_titles = {
        'plant_approval': 'Order Approved!',
        'invoice_generated': 'Invoice Generated!',
        'preparing': 'Order Being Prepared!',
        'dispatch': 'Order Dispatched for Delivery! 🚚',
        'delivered': 'Order Delivered Successfully! ✅',
        'cancelled': 'Order Cancelled',
    }

    status_bodies = {
        'plant_approval': f"Your order #{order.order_code} has been approved by the plant.",
        'invoice_generated': f"Tax invoice has been generated for order #{order.order_code}.",
        'preparing': f"Your order #{order.order_code} is being packed and staged.",
        'dispatch': f"Your order #{order.order_code} has been dispatched and is on its way!",
        'delivered': f"Your order #{order.order_code} has been delivered. Thank you!",
        'cancelled': f"Your order #{order.order_code} has been cancelled.",
    }

    st_clean = (new_status or '').lower()
    title = status_titles.get(st_clean, f"Order #{order.order_code} Update")
    body = status_bodies.get(st_clean, f"Status of #{order.order_code} updated to {new_status}.")

    # In-App Customer Notification inbox
    try:
        from accounts.models import CustomerNotification
        CustomerNotification.objects.create(
            customer=order.created_by,
            title=title,
            message=body,
            notification_type='order_update',
            reference_id=order.id
        )
    except Exception as e:
        logger.warning("FCM: CustomerNotification create warning: %s", e)

    send_fcm_notification(
        users=[order.created_by],
        title=title,
        body=body,
        data={'order_id': order.id, 'order_code': order.order_code, 'status': new_status, 'screen': 'customer_orders'},
        notification_type='order_status',
        reference_id=order.id
    )


def notify_payment_received(order, amount, actor_name='', collector_name=None, **kwargs):
    """
    Triggered when payment is collected for an order.
    Notifies:
    1. Customer (Receipt of payment)
    2. Admins (Cash / Collection audit)
    """
    collector = collector_name or actor_name or 'Staff'

    if order.created_by:
        try:
            from accounts.models import CustomerNotification
            CustomerNotification.objects.create(
                customer=order.created_by,
                title="Payment Received! 💳",
                message=f"Payment of ₹{amount} for order #{order.order_code} received successfully.",
                notification_type='order_update',
                reference_id=order.id
            )
        except Exception as e:
            logger.warning("FCM: CustomerNotification create warning: %s", e)

        send_fcm_notification(
            users=[order.created_by],
            title="Payment Received! 💳",
            body=f"Payment of ₹{amount} for order #{order.order_code} received successfully.",
            data={'order_id': order.id, 'order_code': order.order_code, 'screen': 'customer_orders'},
            notification_type='payment_received',
            reference_id=order.id
        )

    User = get_user_model()
    admin_users = list(User.objects.filter(is_superuser=True))
    if admin_users:
        try:
            from accounts.models import AdminNotification
            AdminNotification.objects.create(
                title=f"Payment Collected: #{order.order_code}",
                message=f"₹{amount} collected for #{order.order_code} by {collector}.",
                notification_type='payment_verification',
                reference_id=order.id
            )
        except Exception as e:
            logger.warning("FCM: AdminNotification create warning: %s", e)

        send_fcm_notification(
            users=admin_users,
            title=f"Payment Collected: #{order.order_code}",
            body=f"₹{amount} collected for #{order.order_code} by {collector}.",
            data={'order_id': order.id, 'order_code': order.order_code, 'screen': 'admin_billing'},
            notification_type='payment_collected',
            reference_id=order.id
        )


def notify_stock_request_created(stock_req):
    """
    Triggered when a Franchise creates a new Stock Request.
    Notifies Super Admin and Admins with actionable stock alert.
    """
    User = get_user_model()
    admin_users = list(User.objects.filter(is_superuser=True))
    staff_admins = list(User.objects.filter(is_staff=True).exclude(is_superuser=True))
    role_admins = list(User.objects.filter(profile__role__in=['admin', 'super_admin']).exclude(is_superuser=True))
    all_admins = list(set(admin_users + staff_admins + role_admins))

    dealer_name = stock_req.dealer.business_name if stock_req.dealer else 'Franchise'
    prod_name = stock_req.product.name if stock_req.product else 'Stock'
    sku = stock_req.product.sku if stock_req.product else ''
    qty = stock_req.requested_quantity

    title = f"New Stock Request: {dealer_name}"
    body = f"{dealer_name} requested {qty:,} units of {sku} ({prod_name}). Request #{stock_req.request_number}."

    try:
        from accounts.models import AdminNotification
        AdminNotification.objects.get_or_create(
            title=title,
            notification_type='stock_alert',
            reference_id=stock_req.id,
            defaults={'message': body}
        )
    except Exception as e:
        logger.warning("FCM: AdminNotification create warning: %s", e)

    send_fcm_notification(
        users=all_admins,
        title=title,
        body=body,
        data={
            'stock_request_id': stock_req.id,
            'request_number': stock_req.request_number,
            'dealer_id': stock_req.dealer_id,
            'screen': 'admin_stock_requests',
            'action': 'view_request',
        },
        notification_type='stock_alert',
        reference_id=stock_req.id
    )


def _get_all_admins():
    User = get_user_model()
    admin_users = list(User.objects.filter(is_superuser=True))
    staff_admins = list(User.objects.filter(is_staff=True).exclude(is_superuser=True))
    role_admins = list(User.objects.filter(profile__role__in=['admin', 'super_admin']).exclude(is_superuser=True))
    return list(set(admin_users + staff_admins + role_admins))


def notify_customer_registered(customer_user, rel=None):
    """
    Triggered when a new customer registers via App/Web.
    Notifies Super Admin, Admins, and assigned Franchise.
    """
    all_admins = _get_all_admins()
    cust_name = customer_user.get_full_name() or customer_user.username
    phone = getattr(getattr(customer_user, 'profile', None), 'phone', '')
    reg_f_name = rel.registered_franchise.business_name if rel and rel.registered_franchise else 'Direct'

    title = f"New Customer Registered: {cust_name}"
    body = f"Customer {cust_name} ({phone}) registered in {rel.zone.name if rel and rel.zone else 'Pure Water'}. Assigned to {reg_f_name}."

    try:
        from accounts.models import AdminNotification
        AdminNotification.objects.get_or_create(
            title=title,
            notification_type='customer_registration',
            reference_id=customer_user.id,
            defaults={'message': body}
        )
        if rel and rel.registered_franchise:
            from accounts.models import FranchiseNotification
            FranchiseNotification.objects.get_or_create(
                franchise=rel.registered_franchise,
                notification_type='new_customer',
                reference_id=customer_user.id,
                defaults={
                    'title': "New Customer Registered in Your Area",
                    'message': f"{cust_name} ({phone}) registered and assigned to your franchise territory."
                }
            )
    except Exception as e:
        logger.warning("FCM: DB notification create warning in notify_customer_registered: %s", e)

    # Send to all Admins
    send_fcm_notification(
        users=all_admins,
        title=title,
        body=body,
        data={
            'customer_id': customer_user.id,
            'screen': 'admin_users',
            'role': 'customer',
        },
        notification_type='customer_registration',
        reference_id=customer_user.id,
    )

    # Send to assigned Franchise
    if rel and rel.registered_franchise and rel.registered_franchise.user:
        send_fcm_notification(
            users=[rel.registered_franchise.user],
            title="New Customer Registered in Your Area",
            body=f"{cust_name} ({phone}) registered and assigned to your franchise territory.",
            data={'customer_id': customer_user.id, 'screen': 'franchise_customers'},
            notification_type='new_customer',
            reference_id=customer_user.id,
        )


def notify_franchise_registered(franchise):
    """
    Triggered when a new Franchise submits an application.
    Notifies Super Admin and Admins.
    """
    all_admins = _get_all_admins()
    b_name = franchise.business_name
    city = franchise.city
    title = f"New Franchise Registration: {b_name}"
    body = f"A new Franchise application has been submitted by {b_name} ({city})."

    try:
        from accounts.models import AdminNotification
        AdminNotification.objects.get_or_create(
            title=title,
            notification_type='franchise_registration',
            reference_id=franchise.id,
            defaults={'message': body}
        )
    except Exception as e:
        logger.warning("FCM: AdminNotification create warning: %s", e)

    send_fcm_notification(
        users=all_admins,
        title=title,
        body=body,
        data={
            'franchise_id': franchise.id,
            'screen': 'admin_franchises',
        },
        notification_type='franchise_registration',
        reference_id=franchise.id,
    )


def notify_franchise_approval_status(franchise, new_status, reason='', actor_name=''):
    """
    Triggered when Admin/Super Admin updates Franchise application status (approved, rejected, suspended).
    Notifies the Franchise applicant.
    """
    if not franchise or not franchise.user:
        return

    st_clean = (new_status or '').lower()
    if st_clean == 'approved':
        title = "Franchise Application Approved! 🎉"
        body = f"Congratulations! Your franchise application for {franchise.business_name} has been approved."
    elif st_clean == 'rejected':
        title = "Franchise Application Update"
        reason_text = f" Reason: {reason}" if reason else ""
        body = f"Your franchise application for {franchise.business_name} requires attention.{reason_text}"
    else:
        title = f"Franchise Application: {new_status.title()}"
        body = f"Your franchise status has been updated to {new_status}."

    try:
        from accounts.models import FranchiseNotification
        FranchiseNotification.objects.create(
            franchise=franchise,
            title=title,
            message=body,
            notification_type='service_status',
            reference_id=franchise.id,
        )
    except Exception as e:
        logger.warning("FCM: FranchiseNotification create warning: %s", e)

    send_fcm_notification(
        users=[franchise.user],
        title=title,
        body=body,
        data={
            'franchise_id': franchise.id,
            'status': new_status,
            'screen': 'franchise_profile',
        },
        notification_type='service_status',
        reference_id=franchise.id,
    )


def notify_lead_created(lead, is_update=False):
    """
    Triggered when a new Lead or Public Chatbot Inquiry is captured.
    Notifies Super Admin, Admins, and assigned Franchise.
    """
    all_admins = _get_all_admins()
    src_label = "Public Chatbot" if lead.source == 'PUBLIC_CHATBOT' else lead.source
    action_label = "Updated" if is_update else "New Inbound"

    title = f"{action_label} Lead ({src_label}): {lead.name}"
    body = f"{lead.name} ({lead.phone}) inquired from {lead.district or lead.city}. Status: {lead.get_status_display()} ({lead.score.upper()})."

    try:
        from accounts.models import AdminNotification
        AdminNotification.objects.get_or_create(
            title=title,
            notification_type='general',
            reference_id=lead.id,
            defaults={'message': body}
        )
        if lead.assigned_franchise:
            from accounts.models import FranchiseNotification
            FranchiseNotification.objects.get_or_create(
                franchise=lead.assigned_franchise,
                notification_type='general',
                reference_id=lead.id,
                defaults={'title': f"New Lead Assigned: {lead.name}", 'message': f"Inquiry from {lead.name} ({lead.phone}) in your territory ({lead.territory or lead.city})."}
            )
    except Exception as e:
        logger.warning("FCM: DB notification create warning in notify_lead_created: %s", e)

    # Send to Admins
    send_fcm_notification(
        users=all_admins,
        title=title,
        body=body,
        data={
            'lead_id': lead.id,
            'screen': 'admin_leads',
            'source': lead.source,
        },
        notification_type='lead_alert',
        reference_id=lead.id,
    )

    # Send to matched Franchise if assigned
    if lead.assigned_franchise and lead.assigned_franchise.user:
        send_fcm_notification(
            users=[lead.assigned_franchise.user],
            title=f"New Lead Assigned: {lead.name}",
            body=f"Inquiry from {lead.name} ({lead.phone}) in your territory ({lead.territory or lead.city}).",
            data={'lead_id': lead.id, 'screen': 'franchise_leads'},
            notification_type='lead_alert',
            reference_id=lead.id,
        )


def notify_stock_request_status_update(stock_req, new_status, actor_name=''):
    """
    Triggered when Stock Request is Approved, Dispatched, or Delivered.
    Notifies the Franchise dealer.
    """
    if not stock_req.dealer or not stock_req.dealer.user:
        return

    status_titles = {
        'APPROVED': 'Stock Request Approved! ✅',
        'DISPATCHED': 'Stock Dispatched from Central Plant! 🚚',
        'RECEIVED': 'Stock Delivery Confirmed! 📦',
        'REJECTED': 'Stock Request Declined',
    }
    title = status_titles.get(new_status.upper(), f"Stock Request #{stock_req.request_number} Update")
    by_text = f" by {actor_name}" if actor_name else ""
    body = f"Your request for {stock_req.requested_quantity}x {stock_req.product.sku if stock_req.product else 'Stock'} is now {new_status}{by_text}."

    try:
        from accounts.models import FranchiseNotification
        FranchiseNotification.objects.create(
            franchise=stock_req.dealer,
            title=title,
            message=body,
            notification_type='stock_alert',
            reference_id=stock_req.id,
        )
    except Exception as e:
        logger.warning("FCM: FranchiseNotification create warning: %s", e)

    send_fcm_notification(
        users=[stock_req.dealer.user],
        title=title,
        body=body,
        data={
            'stock_request_id': stock_req.id,
            'request_number': stock_req.request_number,
            'status': new_status,
            'screen': 'franchise_stock_requests',
        },
        notification_type='stock_alert',
        reference_id=stock_req.id,
    )


notify_stock_request_status = notify_stock_request_status_update




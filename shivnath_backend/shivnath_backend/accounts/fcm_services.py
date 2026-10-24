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

        # Check for individual environment variables
        fb_project_id = os.environ.get('FIREBASE_PROJECT_ID')
        fb_client_email = os.environ.get('FIREBASE_CLIENT_EMAIL')
        fb_private_key = os.environ.get('FIREBASE_PRIVATE_KEY')
        if fb_project_id and fb_client_email and fb_private_key:
            formatted_key = fb_private_key.replace('\\n', '\n')
            cred_dict = {
                "type": "service_account",
                "project_id": fb_project_id,
                "private_key_id": os.environ.get('FIREBASE_PRIVATE_KEY_ID', 'shivnath-key'),
                "private_key": formatted_key,
                "client_email": fb_client_email,
                "client_id": os.environ.get('FIREBASE_CLIENT_ID', ''),
                "auth_uri": "https://accounts.google.com/o/oauth2/auth",
                "token_uri": "https://oauth2.googleapis.com/token",
                "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
                "client_x509_cert_url": f"https://www.googleapis.com/robot/v1/metadata/x509/{fb_client_email.replace('@', '%40')}"
            }
            cred = credentials.Certificate(cred_dict)
            firebase_admin.initialize_app(cred)
            _firebase_initialized = True
            logger.info("FCM: Firebase Admin SDK initialized successfully from individual environment variables.")
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
            logger.warning("FCM: serviceAccountKey.json not found in candidate paths.")
            return False

        cred = credentials.Certificate(key_path)
        firebase_admin.initialize_app(cred)
        _firebase_initialized = True
        logger.info("FCM: Firebase Admin SDK initialized successfully with %s", key_path)
        return True
    except Exception as e:
        logger.error("FCM: Failed to initialize Firebase Admin SDK: %s", e)
        return False


def _get_all_admins():
    """
    Returns all active Admin, Super Admin, and Staff users.
    Strictly excludes inactive users or deactivated profiles.
    """
    User = get_user_model()
    admin_users = list(User.objects.filter(is_superuser=True, is_active=True).exclude(profile__status='inactive'))
    staff_admins = list(User.objects.filter(is_staff=True, is_active=True).exclude(profile__status='inactive').exclude(is_superuser=True))
    role_admins = list(User.objects.filter(profile__role__in=['admin', 'super_admin'], is_active=True, profile__status='active').exclude(is_superuser=True))
    resolved = list(set(admin_users + staff_admins + role_admins))
    logger.info("FCM: [RECIPIENT_RESOLVED] Resolved %d admin recipient(s): %s", len(resolved), [u.username for u in resolved])
    return resolved


def send_fcm_notification(users, title, body, data=None, notification_type='general', reference_id=None):
    """
    Sends real Firebase Cloud Messaging (FCM) push notifications to one or multiple users.
    Enforces structured logging:
    - RECIPIENT_RESOLVED
    - FCM_TOKEN_FOUND
    - FCM_SEND_STARTED
    - FCM_SEND_SUCCESS
    - FCM_SEND_FAILURE
    - INVALID_TOKEN_REMOVED
    Automatically deactivates invalid/unregistered tokens.
    """
    if not users:
        logger.warning("FCM: [FCM_SEND_FAILURE] No recipient users specified for '%s'.", title)
        return {'success': False, 'message': 'No users specified.'}

    User = get_user_model()
    if isinstance(users, User):
        users = [users]
    elif hasattr(users, '__iter__') and not isinstance(users, (list, tuple)):
        users = list(users)

    # Filter out None or invalid objects
    valid_users = [u for u in users if u is not None and getattr(u, 'id', None) is not None]
    if not valid_users:
        logger.warning("FCM: [FCM_SEND_FAILURE] No valid user instances provided for '%s'.", title)
        return {'success': False, 'message': 'No valid users provided.'}

    logger.info(
        "FCM: [RECIPIENT_RESOLVED] Target recipients for '%s': %s (count: %d)",
        title,
        [u.username for u in valid_users],
        len(valid_users)
    )

    # 1. Ensure Firebase Admin is initialized
    if not _init_firebase():
        logger.warning("FCM: [FCM_SEND_FAILURE] Firebase Admin SDK not configured or credentials missing.")
        return {'success': False, 'message': 'Firebase Admin SDK not configured.'}

    # 2. Query active device tokens for these users
    from accounts.models import DeviceToken
    device_tokens_qs = DeviceToken.objects.filter(user__in=valid_users, is_active=True)

    # Role-based cross-contamination safeguard:
    # If this push is targeted for admins, strictly exclude any tokens currently active for non-admin users.
    # If targeted for customers, strictly exclude tokens active for admins.
    is_admin_push = (notification_type in ['admin', 'admin_order', 'admin_alert']) or (data and str(data.get('recipient_role', '')).lower() == 'admin')
    is_cust_push = (notification_type in ['customer', 'customer_order', 'status_update', 'order_status']) or (data and str(data.get('recipient_role', '')).lower() == 'customer')

    if is_admin_push:
        non_admin_tokens = DeviceToken.objects.filter(
            is_active=True,
            user__profile__role__in=['customer', 'franchise', 'dealer']
        ).values_list('token', flat=True)
        device_tokens_qs = device_tokens_qs.exclude(token__in=non_admin_tokens)
    elif is_cust_push:
        admin_tokens = DeviceToken.objects.filter(
            is_active=True,
            user__profile__role__in=['admin', 'super_admin']
        ).values_list('token', flat=True)
        device_tokens_qs = device_tokens_qs.exclude(token__in=admin_tokens)

    tokens = list(device_tokens_qs.values_list('token', flat=True).distinct())

    if not tokens:
        logger.info(
            "FCM: [FCM_TOKEN_FOUND] 0 active device tokens found for users: %s. Notification saved in DB only.",
            [u.username for u in valid_users]
        )
        return {'success': True, 'delivered_count': 0, 'message': 'No registered active devices for user(s).'}

    logger.info(
        "FCM: [FCM_TOKEN_FOUND] Found %d active token(s) across %d user(s).",
        len(tokens),
        len(valid_users)
    )

    # 3. Build string data payload (FCM requirement: all values must be strings)
    clean_data = {}
    if data and isinstance(data, dict):
        for k, v in data.items():
            if v is not None:
                clean_data[str(k)] = str(v)
    clean_data['title'] = str(title)
    clean_data['body'] = str(body)
    clean_data['notification_type'] = str(notification_type)
    if reference_id:
        clean_data['reference_id'] = str(reference_id)
    clean_data['click_action'] = 'FLUTTER_NOTIFICATION_CLICK'

    logger.info("FCM: [FCM_SEND_STARTED] Dispatching push to %d device(s) | Title: '%s' | Type: %s", len(tokens), title, notification_type)

    try:
        from firebase_admin import messaging

        apns_config = None
        APNSConfigClass = getattr(messaging, 'APNSConfig', getattr(messaging, 'ApnsConfig', None))
        APNSPayloadClass = getattr(messaging, 'APNSPayload', getattr(messaging, 'ApnsPayload', None))
        ApsClass = getattr(messaging, 'Aps', None)
        ApsAlertClass = getattr(messaging, 'ApsAlert', None)
        if APNSConfigClass and APNSPayloadClass and ApsClass and ApsAlertClass:
            try:
                apns_config = APNSConfigClass(
                    payload=APNSPayloadClass(
                        aps=ApsClass(
                            alert=ApsAlertClass(
                                title=title,
                                body=body,
                            ),
                            sound='default',
                            badge=1,
                        )
                    )
                )
            except Exception:
                apns_config = None

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
                    click_action='FLUTTER_NOTIFICATION_CLICK',
                )
            ),
            apns=apns_config,
        )

        response = messaging.send_each_for_multicast(message)
        logger.info(
            "FCM: [FCM_SEND_SUCCESS] Sent %d/%d push messages successfully for '%s'",
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
                    logger.warning(
                        "FCM: [FCM_SEND_FAILURE] Delivery failed for token %s...: %s",
                        bad_token[:12],
                        err
                    )
                    err_str = str(getattr(err, 'code', '') or err).upper()
                    if any(term in err_str for term in ['UNREGISTERED', 'INVALID', 'NOT_FOUND', 'REGISTRATION-TOKEN-NOT-REGISTERED']):
                        DeviceToken.objects.filter(token=bad_token).update(is_active=False)
                        logger.info("FCM: [INVALID_TOKEN_REMOVED] Deactivated stale device token: %s...", bad_token[:12])

        return {
            'success': True,
            'success_count': response.success_count,
            'failure_count': response.failure_count,
            'total_tokens': len(tokens),
        }
    except Exception as e:
        logger.error("FCM: [FCM_SEND_FAILURE] Exception during multicast send: %s", e)
        return {'success': False, 'error': str(e)}


# =========================================================
# REAL BUSINESS EVENT DISPATCHERS
# =========================================================

def notify_order_created(order):
    """
    Triggered when a new Customer Order is placed.
    Authoritative routing & recipient isolation:
    - If DIRECT COMPANY: Notifies Super Admin, Staff Admin, and Customer. NO Franchise notification.
    - If FRANCHISE: Notifies Super Admin, Staff Admin, Serving Franchise, and Customer.
    """
    logger.info("FCM: [EVENT_CREATED] Customer Order Created: #%s (ID: %s)", getattr(order, 'order_code', 'N/A'), order.id)

    all_admins = _get_all_admins()

    client_name = order.client_name or (order.created_by.get_full_name() if order.created_by else 'Customer')
    amount = order.amount or order.grand_total or 0.0
    items_count = order.items_count or (order.items.count() if hasattr(order, 'items') else 1)
    is_direct = getattr(order, 'order_source', '') == 'DIRECT_COMPANY' or not order.serving_franchise

    # Fetch product summary for meaningful notification body
    item_summary = ""
    try:
        first_item = order.items.first()
        if first_item:
            item_summary = f" • {first_item.product_name or first_item.size} (Qty: {first_item.quantity})"
    except Exception:
        pass

    title = "New Customer Order"
    if is_direct:
        admin_body = f"Customer: {client_name} • #{order.order_code}{item_summary} • ₹{amount:,.2f} (Direct Company Order)"
        cust_body = f"Your order #{order.order_code} for ₹{amount:,.2f}{item_summary} has been placed with WaterNow Central Dispatch."
    else:
        f_name = order.serving_franchise.business_name
        admin_body = f"Customer: {client_name} • #{order.order_code}{item_summary} • ₹{amount:,.2f} (Fulfilled by {f_name})"
        cust_body = f"Your order #{order.order_code} for ₹{amount:,.2f}{item_summary} is assigned to {f_name}."

    # 1. In-App Notification records (idempotent)
    try:
        from accounts.models import AdminNotification, FranchiseNotification, CustomerNotification
        an, c_an = AdminNotification.objects.get_or_create(
            title=f"New Customer Order: #{order.order_code}",
            notification_type='order_placed',
            reference_id=order.id,
            defaults={'message': admin_body}
        )
        if c_an:
            logger.info("FCM: [NOTIFICATION_CREATED] AdminNotification #%d created for Order #%s", an.id, order.order_code)

        if not is_direct and order.serving_franchise:
            fn, c_fn = FranchiseNotification.objects.get_or_create(
                franchise=order.serving_franchise,
                notification_type='order_placed',
                reference_id=order.id,
                defaults={
                    'title': f"New Order Assigned: #{order.order_code}",
                    'message': f"Client {client_name} placed order #{order.order_code} (₹{amount:,.2f}, {items_count} items) in your territory."
                }
            )
            if c_fn:
                logger.info("FCM: [NOTIFICATION_CREATED] FranchiseNotification #%d created for Franchise %s", fn.id, order.serving_franchise.business_name)

        if order.created_by:
            cn, c_cn = CustomerNotification.objects.get_or_create(
                customer=order.created_by,
                notification_type='order_status',
                reference_id=order.id,
                defaults={
                    'title': "Order Confirmed! 🎉",
                    'message': cust_body
                }
            )
            if c_cn:
                logger.info("FCM: [NOTIFICATION_CREATED] CustomerNotification #%d created for Customer %s", cn.id, order.created_by.username)
    except Exception as e:
        logger.warning("FCM: DB notification create warning in notify_order_created: %s", e)

    # 2. Send FCM to Admins
    admin_payload = {
        'event_type': 'customer_order',
        'entity_type': 'order',
        'entity_id': order.id,
        'order_id': order.id,
        'order_code': order.order_code,
        'customer_id': order.created_by_id if order.created_by else None,
        'customer_name': client_name,
        'amount': str(amount),
        'items_count': str(items_count),
        'fulfillment_source': 'COMPANY' if is_direct else 'FRANCHISE',
        'screen': 'admin_orders',
        'recipient_role': 'admin',
    }
    if not is_direct and order.serving_franchise:
        admin_payload['franchise_id'] = order.serving_franchise.id
        admin_payload['franchise_name'] = order.serving_franchise.business_name

    send_fcm_notification(
        users=all_admins,
        title=title,
        body=admin_body,
        data=admin_payload,
        notification_type='order_placed',
        reference_id=order.id
    )

    # 3. Send FCM to Serving Franchise (ONLY IF FRANCHISE ORDER)
    if not is_direct and order.serving_franchise and order.serving_franchise.user:
        send_fcm_notification(
            users=[order.serving_franchise.user],
            title=f"New Order Assigned: #{order.order_code}",
            body=f"Client {client_name} placed order #{order.order_code} (₹{amount:,.2f}{item_summary}) in your territory.",
            data={
                'event_type': 'customer_order',
                'entity_type': 'order',
                'entity_id': order.id,
                'order_id': order.id,
                'order_code': order.order_code,
                'franchise_id': order.serving_franchise.id,
                'customer_name': client_name,
                'amount': str(amount),
                'screen': 'franchise_orders',
                'recipient_role': 'franchise',
            },
            notification_type='order_placed',
            reference_id=order.id
        )

    # 4. Send FCM confirmation to Customer
    if order.created_by:
        send_fcm_notification(
            users=[order.created_by],
            title="Order Confirmed! 🎉",
            body=cust_body,
            data={
                'event_type': 'order_confirmed',
                'entity_type': 'order',
                'entity_id': order.id,
                'order_id': order.id,
                'order_code': order.order_code,
                'screen': 'customer_orders',
                'recipient_role': 'customer',
            },
            notification_type='order_status',
            reference_id=order.id
        )


def notify_order_status_update(order, new_status, actor_name=''):
    """
    Triggered when order status changes (Approval, Dispatched, Delivered, Cancelled).
    Notifies:
    1. The Customer who placed the order.
    2. Relevant Admins and Serving Franchise.
    """
    logger.info("FCM: [EVENT_CREATED] Order Status Transition: #%s -> %s (by %s)", getattr(order, 'order_code', 'N/A'), new_status, actor_name or 'System')

    st_clean = (new_status or '').lower()
    status_titles = {
        'plant_approval': 'Order Approved! ✅',
        'invoice_generated': 'Invoice Generated 📄',
        'preparing': 'Order Being Prepared 📦',
        'dispatch': 'Order Dispatched for Delivery! 🚚',
        'delivered': 'Order Delivered Successfully! 🎉',
        'cancelled': 'Order Cancelled ❌',
    }

    status_bodies = {
        'plant_approval': f"Your order #{order.order_code} has been approved by the plant.",
        'invoice_generated': f"Tax invoice has been generated for order #{order.order_code}.",
        'preparing': f"Your order #{order.order_code} is being packed and staged.",
        'dispatch': f"Your order #{order.order_code} has been dispatched and is on its way!",
        'delivered': f"Your order #{order.order_code} has been delivered. Thank you!",
        'cancelled': f"Your order #{order.order_code} has been cancelled.",
    }

    title = status_titles.get(st_clean, f"Order #{order.order_code} Update")
    body = status_bodies.get(st_clean, f"Status of #{order.order_code} updated to {new_status}.")

    # 1. In-App Customer Notification inbox + FCM Push
    if order.created_by:
        try:
            from accounts.models import CustomerNotification
            cn = CustomerNotification.objects.create(
                customer=order.created_by,
                title=title,
                message=body,
                notification_type='order_update',
                reference_id=order.id
            )
            logger.info("FCM: [NOTIFICATION_CREATED] CustomerNotification #%d created for %s", cn.id, order.created_by.username)
        except Exception as e:
            logger.warning("FCM: CustomerNotification create warning: %s", e)

        send_fcm_notification(
            users=[order.created_by],
            title=title,
            body=body,
            data={
                'order_id': order.id,
                'order_code': order.order_code,
                'status': new_status,
                'screen': 'customer_orders',
                'click_action': 'FLUTTER_NOTIFICATION_CLICK'
            },
            notification_type='order_status',
            reference_id=order.id
        )

    # 2. Serving Franchise Notification (In-App + FCM Push)
    if order.serving_franchise and order.serving_franchise.user:
        f_title = f"Order #{order.order_code}: {title}"
        f_body = f"Customer {order.client_name or 'Customer'} order #{order.order_code} status transitioned to {new_status}."
        try:
            from accounts.models import FranchiseNotification
            fn = FranchiseNotification.objects.create(
                franchise=order.serving_franchise,
                title=f_title,
                message=f_body,
                notification_type='order_update',
                reference_id=order.id
            )
            logger.info("FCM: [NOTIFICATION_CREATED] FranchiseNotification #%d created for Franchise %s", fn.id, order.serving_franchise.business_name)
        except Exception as e:
            logger.warning("FCM: FranchiseNotification create warning: %s", e)

        send_fcm_notification(
            users=[order.serving_franchise.user],
            title=f_title,
            body=f_body,
            data={
                'order_id': order.id,
                'order_code': order.order_code,
                'status': new_status,
                'screen': 'franchise_orders',
                'click_action': 'FLUTTER_NOTIFICATION_CLICK'
            },
            notification_type='order_update',
            reference_id=order.id
        )

    # 3. Admin & Super Admin Push Notification
    all_admins = _get_all_admins()
    if all_admins:
        admin_title = f"Order #{order.order_code} Status Updated"
        admin_body = f"Order #{order.order_code} for {order.client_name or 'Customer'} transitioned to {new_status} (by {actor_name or 'System'})."
        send_fcm_notification(
            users=all_admins,
            title=admin_title,
            body=admin_body,
            data={
                'order_id': order.id,
                'order_code': order.order_code,
                'status': new_status,
                'screen': 'admin_orders',
                'click_action': 'FLUTTER_NOTIFICATION_CLICK'
            },
            notification_type='order_update',
            reference_id=order.id
        )


def notify_payment_received(order, amount, actor_name='', collector_name=None, is_pending=False, invoice=None, **kwargs):
    """
    Triggered when payment is submitted or collected for an order/invoice.
    - If is_pending=True: Notifies Admins that Payment Verification is required.
    - If is_pending=False: Notifies Customer and Submitting Franchise that Payment is verified/recorded.
    """
    logger.info("FCM: [EVENT_CREATED] Payment Event: Order #%s | Amount: ₹%s | Pending: %s", getattr(order, 'order_code', 'N/A') if order else 'N/A', amount, is_pending)

    collector = collector_name or actor_name or 'Staff'
    client_name = 'Customer'
    order_code = ''
    ref_id = None

    if order:
        client_name = order.client_name or (order.created_by.get_full_name() if order.created_by else 'Customer')
        order_code = order.order_code
        ref_id = order.id
    elif invoice:
        client_name = invoice.billed_to_name or 'Customer'
        order_code = invoice.invoice_number
        ref_id = invoice.id

    if is_pending:
        # 1. Admin notification for verification
        all_admins = _get_all_admins()
        if all_admins:
            admin_title = "Payment Verification Required"
            admin_body = f"{client_name} submitted ₹{amount:,.2f} for verification (Order #{order_code} via {collector})"
            try:
                from accounts.models import AdminNotification
                an = AdminNotification.objects.create(
                    title=f"Payment Submitted: #{order_code}",
                    message=admin_body,
                    notification_type='payment_verification',
                    reference_id=ref_id
                )
                logger.info("FCM: [NOTIFICATION_CREATED] AdminNotification #%d for payment verification", an.id)
            except Exception as e:
                logger.warning("FCM: AdminNotification create warning: %s", e)

            send_fcm_notification(
                users=all_admins,
                title=admin_title,
                body=admin_body,
                data={
                    'event_type': 'payment_verification',
                    'entity_type': 'order' if order else 'invoice',
                    'entity_id': ref_id,
                    'order_id': order.id if order else '',
                    'order_code': order_code,
                    'amount': str(amount),
                    'collector': collector,
                    'screen': 'admin_billing',
                },
                notification_type='payment_verification',
                reference_id=ref_id
            )
    else:
        # 2. Confirmed Payment receipt
        if order and order.created_by:
            cust_title = "Payment Received! 💳"
            cust_body = f"Payment of ₹{amount:,.2f} for order #{order.order_code} received successfully."
            try:
                from accounts.models import CustomerNotification
                cn = CustomerNotification.objects.create(
                    customer=order.created_by,
                    title=cust_title,
                    message=cust_body,
                    notification_type='order_update',
                    reference_id=order.id
                )
                logger.info("FCM: [NOTIFICATION_CREATED] CustomerNotification #%d for payment received", cn.id)
            except Exception as e:
                logger.warning("FCM: CustomerNotification create warning: %s", e)

            send_fcm_notification(
                users=[order.created_by],
                title=cust_title,
                body=cust_body,
                data={
                    'event_type': 'payment_received',
                    'entity_type': 'order',
                    'entity_id': order.id,
                    'order_id': order.id,
                    'order_code': order.order_code,
                    'amount': str(amount),
                    'screen': 'customer_orders',
                },
                notification_type='payment_received',
                reference_id=order.id
            )

        # Notify serving franchise if applicable
        if order and order.serving_franchise and order.serving_franchise.user:
            try:
                from accounts.models import FranchiseNotification
                FranchiseNotification.objects.create(
                    franchise=order.serving_franchise,
                    title=f"Payment Recorded: #{order.order_code}",
                    message=f"Payment of ₹{amount:,.2f} recorded for order #{order.order_code}.",
                    notification_type='payment_recorded',
                    reference_id=order.id,
                )
            except Exception:
                pass


def notify_stock_request_created(stock_req):
    """
    Triggered when a Franchise creates a new Stock Request.
    Notifies Super Admin and Admins with actionable stock alert.
    """
    logger.info("FCM: [EVENT_CREATED] Stock Request Created: #%s (ID: %s)", getattr(stock_req, 'request_number', 'N/A'), stock_req.id)

    all_admins = _get_all_admins()

    dealer_name = stock_req.dealer.business_name if stock_req.dealer else 'Franchise'
    prod_name = stock_req.product.name if stock_req.product else 'Stock'
    sku = stock_req.product.sku if stock_req.product else ''
    qty = stock_req.requested_quantity

    title = "New Franchise Stock Request"
    body = f"Franchise: {dealer_name} • Request #{stock_req.request_number} • {qty:,} units of {sku} ({prod_name})"

    try:
        from accounts.models import AdminNotification
        an, created = AdminNotification.objects.get_or_create(
            title=f"New Stock Request: {dealer_name}",
            notification_type='stock_alert',
            reference_id=stock_req.id,
            defaults={'message': f"{dealer_name} requested {qty:,} units of {sku} ({prod_name}). Request #{stock_req.request_number}."}
        )
        if created:
            logger.info("FCM: [NOTIFICATION_CREATED] AdminNotification #%d created for Stock Request #%s", an.id, stock_req.request_number)
    except Exception as e:
        logger.warning("FCM: AdminNotification create warning: %s", e)

    send_fcm_notification(
        users=all_admins,
        title=title,
        body=body,
        data={
            'event_type': 'stock_request',
            'entity_type': 'stock_request',
            'entity_id': stock_req.id,
            'stock_request_id': stock_req.id,
            'request_number': stock_req.request_number,
            'dealer_id': stock_req.dealer_id,
            'dealer_name': dealer_name,
            'sku': sku,
            'quantity': str(qty),
            'screen': 'admin_stock_requests',
            'action': 'view_request',
        },
        notification_type='stock_alert',
        reference_id=stock_req.id
    )


def notify_stock_request_status_update(stock_req, new_status, actor_name=''):
    """
    Triggered when Stock Request is Approved, Dispatched, or Delivered.
    Notifies the Franchise dealer.
    """
    logger.info("FCM: [EVENT_CREATED] Stock Request Status Update: #%s -> %s", getattr(stock_req, 'request_number', 'N/A'), new_status)

    if not stock_req.dealer or not stock_req.dealer.user:
        logger.warning("FCM: Stock request #%s has no associated dealer user.", getattr(stock_req, 'request_number', 'N/A'))
        return

    dealer_name = stock_req.dealer.business_name
    sku = stock_req.product.sku if stock_req.product else 'Stock'
    qty = stock_req.dispatched_quantity or stock_req.requested_quantity

    st_upper = (new_status or '').upper()
    if st_upper == 'DISPATCHED':
        title = "Stock Dispatched"
        body = f"{qty:,} units dispatched to {dealer_name} ({sku}) from Central Plant."
    elif st_upper == 'APPROVED':
        title = "Stock Request Approved ✅"
        body = f"Request #{stock_req.request_number} for {qty:,} units of {sku} approved by Central Plant."
    elif st_upper == 'RECEIVED':
        title = "Stock Delivery Confirmed"
        body = f"{dealer_name} confirmed receipt of {qty:,} units of {sku}."
    else:
        title = f"Stock Request {new_status.title()}"
        body = f"Your request for {qty:,} units of {sku} is now {new_status}."

    try:
        from accounts.models import FranchiseNotification
        fn = FranchiseNotification.objects.create(
            franchise=stock_req.dealer,
            title=title,
            message=body,
            notification_type='stock_alert',
            reference_id=stock_req.id,
        )
        logger.info("FCM: [NOTIFICATION_CREATED] FranchiseNotification #%d created for Franchise %s", fn.id, dealer_name)
    except Exception as e:
        logger.warning("FCM: FranchiseNotification create warning: %s", e)

    send_fcm_notification(
        users=[stock_req.dealer.user],
        title=title,
        body=body,
        data={
            'event_type': 'stock_dispatch' if st_upper == 'DISPATCHED' else 'stock_status',
            'entity_type': 'stock_request',
            'entity_id': stock_req.id,
            'stock_request_id': stock_req.id,
            'request_number': stock_req.request_number,
            'dealer_name': dealer_name,
            'status': new_status,
            'screen': 'franchise_stock_requests',
        },
        notification_type='stock_alert',
        reference_id=stock_req.id,
    )


notify_stock_request_status = notify_stock_request_status_update


def notify_customer_registered(customer_user, rel=None):
    """
    Triggered when a new customer registers via App/Web.
    Notifies Super Admin, Admins, and assigned Franchise.
    """
    logger.info("FCM: [EVENT_CREATED] Customer Registration: %s", customer_user.username)

    all_admins = _get_all_admins()
    cust_name = customer_user.get_full_name() or customer_user.username
    phone = getattr(getattr(customer_user, 'profile', None), 'phone', '')
    zone_name = rel.zone.name if rel and rel.zone else 'Pure Water Territory'
    reg_f_name = rel.registered_franchise.business_name if rel and rel.registered_franchise else 'Direct Company'

    title = "New Customer Registered"
    body = f"{cust_name} ({phone}) • {zone_name} • Assigned to {reg_f_name}"

    try:
        from accounts.models import AdminNotification
        an, created = AdminNotification.objects.get_or_create(
            title=f"New Customer Registered: {cust_name}",
            notification_type='customer_registration',
            reference_id=customer_user.id,
            defaults={'message': body}
        )
        if created:
            logger.info("FCM: [NOTIFICATION_CREATED] AdminNotification #%d for Customer registration %s", an.id, cust_name)

        if rel and rel.registered_franchise:
            from accounts.models import FranchiseNotification
            fn, f_created = FranchiseNotification.objects.get_or_create(
                franchise=rel.registered_franchise,
                notification_type='new_customer',
                reference_id=customer_user.id,
                defaults={
                    'title': "New Customer Registered in Your Area",
                    'message': f"{cust_name} ({phone}) registered and assigned to your franchise territory."
                }
            )
            if f_created:
                logger.info("FCM: [NOTIFICATION_CREATED] FranchiseNotification #%d for Franchise %s", fn.id, rel.registered_franchise.business_name)
    except Exception as e:
        logger.warning("FCM: DB notification create warning in notify_customer_registered: %s", e)

    # Send to all Admins
    send_fcm_notification(
        users=all_admins,
        title=title,
        body=body,
        data={
            'event_type': 'customer_registration',
            'entity_type': 'customer',
            'entity_id': customer_user.id,
            'customer_id': customer_user.id,
            'customer_name': cust_name,
            'phone': phone,
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
            data={
                'event_type': 'customer_registration',
                'entity_type': 'customer',
                'entity_id': customer_user.id,
                'customer_id': customer_user.id,
                'screen': 'franchise_customers',
            },
            notification_type='new_customer',
            reference_id=customer_user.id,
        )


def notify_franchise_registered(franchise):
    """
    Triggered when a new Franchise submits an application.
    Notifies Super Admin and Admins.
    """
    logger.info("FCM: [EVENT_CREATED] Franchise Application: %s (%s)", franchise.business_name, franchise.city)

    all_admins = _get_all_admins()
    b_name = franchise.business_name
    city = franchise.city
    title = "New Franchise Application"
    body = f"{b_name} ({city}) submitted a new franchise application."

    try:
        from accounts.models import AdminNotification
        an, created = AdminNotification.objects.get_or_create(
            title=f"New Franchise Registration: {b_name}",
            notification_type='franchise_registration',
            reference_id=franchise.id,
            defaults={'message': body}
        )
        if created:
            logger.info("FCM: [NOTIFICATION_CREATED] AdminNotification #%d for Franchise %s", an.id, b_name)
    except Exception as e:
        logger.warning("FCM: AdminNotification create warning: %s", e)

    send_fcm_notification(
        users=all_admins,
        title=title,
        body=body,
        data={
            'event_type': 'franchise_registration',
            'entity_type': 'franchise',
            'entity_id': franchise.id,
            'franchise_id': franchise.id,
            'franchise_name': b_name,
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
    logger.info("FCM: [EVENT_CREATED] Franchise Status: %s -> %s", franchise.business_name, new_status)

    if not franchise or not franchise.user:
        return

    st_clean = (new_status or '').lower()
    if st_clean == 'approved':
        title = "Franchise Application Approved! 🎉"
        body = f"Congratulations! Your franchise application for {franchise.business_name} has been approved."
    elif st_clean == 'rejected':
        title = "Franchise Application Update"
        reason_text = f" Reason: {reason}" if reason else ""
        body = f"{franchise.business_name} application requires your attention.{reason_text}"
    else:
        title = "Franchise Application Update"
        body = f"{franchise.business_name} application status updated to {new_status}."

    try:
        from accounts.models import FranchiseNotification
        fn = FranchiseNotification.objects.create(
            franchise=franchise,
            title=title,
            message=body,
            notification_type='service_status',
            reference_id=franchise.id,
        )
        logger.info("FCM: [NOTIFICATION_CREATED] FranchiseNotification #%d for Franchise %s", fn.id, franchise.business_name)
    except Exception as e:
        logger.warning("FCM: FranchiseNotification create warning: %s", e)

    send_fcm_notification(
        users=[franchise.user],
        title=title,
        body=body,
        data={
            'event_type': 'franchise_status',
            'entity_type': 'franchise',
            'entity_id': franchise.id,
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
    logger.info("FCM: [EVENT_CREATED] Lead Captured: %s | Source: %s | Update: %s", lead.name, lead.source, is_update)

    all_admins = _get_all_admins()
    src_label = "Public Chatbot" if lead.source == 'PUBLIC_CHATBOT' else (lead.source or 'Direct')
    location = lead.district or lead.city or 'Chhattisgarh'

    title = "New Lead Received"
    body = f"Lead: {lead.name} ({lead.phone}) • {location} • Source: {src_label}"

    try:
        from accounts.models import AdminNotification
        an, created = AdminNotification.objects.get_or_create(
            title=f"New Lead: {lead.name}",
            notification_type='general',
            reference_id=lead.id,
            defaults={'message': f"{lead.name} ({lead.phone}) inquired from {location}. Source: {src_label}. Status: {lead.get_status_display()}."}
        )
        if created:
            logger.info("FCM: [NOTIFICATION_CREATED] AdminNotification #%d for Lead %s", an.id, lead.name)

        if lead.assigned_franchise:
            from accounts.models import FranchiseNotification
            fn, f_created = FranchiseNotification.objects.get_or_create(
                franchise=lead.assigned_franchise,
                notification_type='general',
                reference_id=lead.id,
                defaults={'title': f"New Lead Assigned: {lead.name}", 'message': f"Inquiry from {lead.name} ({lead.phone}) in your territory ({location})."}
            )
            if f_created:
                logger.info("FCM: [NOTIFICATION_CREATED] FranchiseNotification #%d for Franchise %s", fn.id, lead.assigned_franchise.business_name)
    except Exception as e:
        logger.warning("FCM: DB notification create warning in notify_lead_created: %s", e)

    # Send to Admins
    send_fcm_notification(
        users=all_admins,
        title=title,
        body=body,
        data={
            'event_type': 'new_lead',
            'entity_type': 'lead',
            'entity_id': lead.id,
            'lead_id': lead.id,
            'name': lead.name,
            'phone': lead.phone,
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
            title="New Lead Assigned",
            body=f"{lead.name} • {location} • Assigned to your franchise territory",
            data={
                'event_type': 'new_lead',
                'entity_type': 'lead',
                'entity_id': lead.id,
                'lead_id': lead.id,
                'screen': 'franchise_leads',
            },
            notification_type='lead_alert',
            reference_id=lead.id,
        )

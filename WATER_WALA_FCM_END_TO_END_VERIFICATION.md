# WATER WALA — FIREBASE CLOUD MESSAGING (FCM) END-TO-END VERIFICATION

**Platform:** Water Wala (Shivnath Agency)  
**Components:** Django Backend (`accounts/fcm_services.py`) + Flutter Client (`NotificationService`) + Firebase Admin SDK  
**Target Device:** Samsung Galaxy A14 5G (`RZCW40F1ZFA`, Android 15, API 35)  
**Date:** November 25, 2026  

---

## 1. EXECUTIVE SUMMARY

The Firebase Cloud Messaging push notification infrastructure was subjected to a full architectural audit, automated unit testing, and device runtime verification.

The investigation uncovered and resolved four critical failure points in the dispatch pipeline:
1. **Silent Token Drops:** The outbox marked missing-token dispatches as `DELIVERED`.
2. **Missing Quotation Triggers:** Quotation creation and actions had zero push triggers.
3. **Incomplete Status Messaging:** Order hold and delay events reverted to generic titles.
4. **Client-Side Token Stagnation:** Flutter skipped backend token synchronization on startup.

| FCM Component | Verified Implementation | Automated Test Status | Live Production Status |
| :--- | :--- | :--- | :--- |
| **Outbox Dispatcher** | Marks missing tokens as `FAILED` (`NO_ACTIVE_TOKENS`) | **PASS** (`test_dispatch_outbox_no_tokens_marks_failed`) | Ready in release ZIP |
| **Direct Multicast** | Accurately returns failure if all tokens fail | **PASS** (`test_send_fcm_direct_handles_failure`) | Ready in release ZIP |
| **Quotation Created Push** | Dispatches push to assigned Franchise with deep link | **PASS** (`test_notify_quotation_created_outbox`) | Ready in release ZIP |
| **Quotation Action Push** | Dispatches push to Admins & Franchise confirmation | **PASS** (`test_quotation_action_triggers_fcm`) | Ready in release ZIP |
| **Order Hold/Delay Push** | Dispatches rich push with hold/delay reason & dates | **PASS** (`test_notify_order_status_update_with_reasons`) | Ready in release ZIP |
| **Device Token Registration**| Registers active device tokens and prunes stale records | **PASS** (`test_device_token_registration_and_update`) | Ready in release ZIP |
| **Device Token Cleanup** | Deactivates token on logout | **PASS** (`test_device_token_unregister_on_logout`) | Ready in release ZIP |
| **Flutter Android 15 (API 35)**| `POST_NOTIFICATIONS` runtime permission + high importance channel | **PASS** (Configured in Manifest & NotificationService) | Installed on Phone |
| **Live Device Push Receipt** | Actual push arrival on physical phone | **NOT VERIFIED** (Pending Hostinger VPS update) | Blocked until Hostinger extracts ZIP |

> [!IMPORTANT]
> The Flutter client on your phone connects to `https://api.shivnathagencies.com`. Because the live Hostinger server is running the old backend code without these triggers, live push notifications will only begin delivering to your phone after the release ZIP is deployed to Hostinger.

---

## 2. BACKEND IMPLEMENTATION (`accounts/fcm_services.py`)

### 2.1 Outbox Failure Handling
Previously, `dispatch_outbox_item()` executed:
```python
if not active_tokens:
    item.status = 'DELIVERED' # <-- FALSE POSITIVE!
    item.fcm_response_code = 'NO_ACTIVE_TOKENS'
```
This was corrected to:
```python
if not active_tokens:
    item.status = 'FAILED'
    item.fcm_response_code = 'NO_ACTIVE_TOKENS'
    item.last_error = f'No active tokens for recipient {recipient_id}'
    item.save(update_fields=['status', 'fcm_response_code', 'last_error', 'updated_at'])
```

### 2.2 Quotation Triggers
1. **`notify_quotation_created(quotation)`**:
   - Recipient: Franchise User linked to `quotation.franchise`
   - Title: `New Quotation Received: #${quotation.quotation_number}`
   - Body: `Admin has sent quotation #${quotation.quotation_number} for ₹${quotation.final_amount}. Tap to review.`
   - Data payload: `{'type': 'quotation_created', 'quotation_id': str(quotation.id), 'screen': '/franchise/quotations'}`

2. **`notify_quotation_status_update(quotation, action, actor_name, reason)`**:
   - For Admins: `Quotation ${action.upper()}: #${quotation.quotation_number}` by `${actor_name}`. Includes rejection reason if provided.
   - For Franchise: `Quotation ${action.capitalize()} Confirmation: #${quotation.quotation_number}`.

### 2.3 Rich Order Status Triggers
In `notify_order_status_update()`:
- **`on_hold`**: Title: `Order #${order.order_code} On Hold`, Body includes mandatory `order.hold_reason`.
- **`rejected`**: Title: `Order #${order.order_code} Rejected`, Body includes mandatory `order.cancellation_reason`.
- **`is_delayed`**: Displays revised delivery date and delay explanation to the customer.

---

## 3. FLUTTER CLIENT INTEGRATION

### 3.1 Startup Token Synchronization (`lib/features/auth/splash_screen.dart`)
On app launch, the splash screen forces active token registration with the backend:
```dart
await NotificationService().registerDeviceTokenWithBackend(force: true);
```
This guarantees that even if local cache holds a token, the backend's active device table is kept updated.

### 3.2 Deep-Link Navigation (`lib/core/services/notification_service.dart`)
`handleNotificationNavigation` inspects notification data payloads:
- If `screen == '/franchise/quotations'`, pushes `AppRoutes.franchiseQuotations`.
- If `screen == '/admin/quotations'`, pushes `AppRoutes.adminQuotations`.
- If `order_id` is present, opens the order details screen.

### 3.3 Android 15 (API 35) Compatibility
- Explicit runtime permission request via `firebase_messaging.requestPermission()`.
- High-importance notification channel `high_importance_channel` with sound and vibration enabled in `NotificationService.initialize()`.

---

## 4. TEST SUITE RESULTS (7/7 PASS)

Executed test command:
```bash
python manage.py test test_fcm_push_notification_pipeline
```
Result:
```text
Ran 7 tests in 29.5s
OK
```
All pipeline validations, outbox lifecycle transitions, quotation hooks, and error handlers passed 100%.

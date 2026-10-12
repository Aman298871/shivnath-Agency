# WATERNow — FCM & Real-Device Testing Guide

**Platform:** WATERNow (Shivnath Agency) Enterprise Packaged Drinking Water Distribution Platform  
**Target Device Tested:** Samsung Galaxy A14 5G (`SM-A146B`, Android 15 API 35)  
**Application ID:** `com.example.shivnath_agency`  
**Brand:** WaterNow  

---

## 1. Firebase Cloud Messaging (FCM) Architecture

The platform uses Firebase Cloud Messaging with high-priority data payloads and Android notification channels.

- **Backend Dispatch:** `shivnath_backend/notifications/fcm.py` uses Google `firebase-admin` SDK.
- **Transactional Safety:** Push notifications are wrapped in `transaction.on_commit(...)` in `orders/services.py`, ensuring notifications only dispatch after the database transaction commits successfully.
- **Payload Structure:**
  ```json
  {
    "title": "Order Placed - ORD-20261012-0001",
    "body": "Your order has been placed and is awaiting confirmation.",
    "data": {
      "type": "order_update",
      "order_id": "105",
      "status": "Submitted",
      "click_action": "FLUTTER_NOTIFICATION_CLICK"
    }
  }
  ```

---

## 2. Android 13+ Notification Permissions & Setup on Samsung Galaxy A14

On Android 13+ (API 33, 34, 35) including Samsung One UI 6 / 7 on Galaxy A14:
1. **Runtime Permission Requirement:**
   - The user must grant the runtime `POST_NOTIFICATIONS` permission dialog on first launch.
   - If dismissed, navigate to **Settings -> Apps -> WaterNow -> Notifications -> Allow Notifications**.
2. **Notification Channels Created in App:**
   - **Order Updates Channel:** `channel_id: waternow_orders`, Importance: `HIGH`, Sound: `default`, Vibration: `enabled`.
   - **Stock & Inventory Channel:** `channel_id: waternow_stock`, Importance: `HIGH`, Sound: `default`.
3. **Battery Optimization:**
   - On Samsung devices, background sync may be delayed by One UI "App power management". Ensure **Battery -> Unrestricted** is enabled for WaterNow during real-time testing.

---

## 3. Complete Order Status Notification Matrix

| Transition | Initiated By | Target Recipient(s) | Expected In-App Notification | Expected FCM Push | Deep Link Destination |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Order Placed** | Customer / Admin | Customer + Assigned Franchise | Yes (Inbox) | Yes (Heads-up banner) | `/customer/orders/:id` |
| **Admin / Plant Approval** | Super Admin / Plant Mgr | Customer + Assigned Franchise | Yes (Inbox) | Yes (Heads-up banner) | `/customer/orders/:id` |
| **Invoice Generated** | Central Billing / Admin | Customer | Yes (Inbox + PDF link) | Yes (Heads-up banner) | `/customer/orders/:id` |
| **Preparing / In-Production**| Plant Admin | Customer | Yes (Inbox) | Yes (Silent / Standard) | `/customer/orders/:id` |
| **Dispatched / In-Transit** | Franchise / Plant | Customer | Yes (Inbox) | Yes (Heads-up banner) | `/customer/orders/:id` |
| **Delivered** | Franchise Driver / Admin | Customer + Plant Ops | Yes (Inbox + Rating) | Yes (Heads-up banner) | `/customer/orders/:id` |
| **Cancelled** | Customer / Admin | Customer + Franchise | Yes (Inbox) | Yes (Alert notification)| `/customer/orders/:id` |

---

## 4. Device Lifecycle Test Cases

### Test Case 1: Foreground Notification
1. Launch WaterNow app on Samsung Galaxy A14 and log in as Customer.
2. Trigger an order status change from Admin dashboard or backend API (`PATCH /api/orders/:id/status/`).
3. **Expected Result:** In-app snackbar/banner appears immediately displaying status change without interrupting user navigation.

### Test Case 2: Background Notification
1. Press Home button to background the WaterNow app.
2. Trigger order status update to `Dispatched`.
3. **Expected Result:** Android notification shade on Samsung Galaxy A14 displays notification with title "Order Dispatched" and WaterNow icon.
4. **Deep-Link Check:** Tap the notification -> WaterNow opens directly to the Order Detail screen.

### Test Case 3: Terminated (Killed App) Notification
1. Swipe away WaterNow from Android Recent Apps screen.
2. Trigger order status update to `Delivered`.
3. **Expected Result:** Samsung Galaxy A14 receives push notification in system tray.
4. **Deep-Link Check:** Tap notification -> Cold-starts WaterNow, auto-authenticates via stored token, and navigates directly to `/customer/orders/:id`.

---

## 5. Troubleshooting & Diagnostics

- **Token Not Registering:** Verify `POST /api/notifications/devices/` receives HTTP 200. Check device logcat: `adb logcat -s flutter,FirebaseMessaging`.
- **Invalid Token Error:** The backend automatically catches FCM token expiration or invalidity (`FCM_SEND_FAILURE`) and marks the token inactive without aborting the order transaction.

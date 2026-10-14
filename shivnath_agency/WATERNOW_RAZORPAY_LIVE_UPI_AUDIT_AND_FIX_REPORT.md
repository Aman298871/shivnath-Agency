# WATERNow — Razorpay Live Payment Audit, UPI Troubleshooting & End-to-End Fix Report

## 1. Executive Summary & Root Cause Analysis

### Identified Critical Defect
The user configured Razorpay Live credentials (`key_id: rzp_live_Tnhqo3i0SyYYdf`), yet upon launching the Razorpay Checkout modal on the mobile device, **UPI (Google Pay, PhonePe, Paytm)** did not appear as a selectable payment method.

### Actual Root Causes (Evidence-Based Finding)
1. **Server-Side Order Generation Still Running in Test Sandbox Mode**:
   - An API probe executed directly against the live production backend (`https://shivnath-agency.onrender.com/api/orders/razorpay/status/` and `/create-order/`) yielded:
     ```json
     {
       "success": true,
       "environment": "TEST",
       "is_test_mode": true,
       "key_id": "rzp_test_TnHOsEiTNcd25f",
       "razorpay_order_id": "order_TnigjPr9GZZS4B"
     }
     ```
   - **Root Cause**: The Render cloud deployment has not received the live credentials in its environment variables (`RAZORPAY_KEY_ID`, `RAZORPAY_KEY_SECRET`, `RAZORPAY_ENVIRONMENT`). Consequently, Django's backend fell back to the hardcoded sandbox default (`rzp_test_TnHOsEiTNcd25f`).
   - Every order created on the backend was an official **Razorpay Sandbox Test Order**.

2. **NPCI & Banking Switch Rule in Test Mode**:
   - Real consumer UPI apps (PhonePe, Google Pay, Paytm, BHIM) strictly reject test transactions because Indian banking switches (NPCI) do not allow simulated money transfers on live customer bank accounts.
   - Razorpay's Android SDK detects when an order was created under a test key (`rzp_test_...`) and **automatically suppresses installed UPI app tiles (UPI Intent)**.
   - In Test Mode, Razorpay only displays Cards (test numbers), Netbanking (test banks), and a manual UPI VPA input field where testers must enter `success@razorpay` to simulate a test payment.

3. **Merchant Key & Order ID Association Conflict**:
   - Razorpay enforces strict server-side validation: the `key_id` used in the mobile checkout options MUST match the merchant account that created the `razorpay_order_id`.
   - If the backend generates an order using the Test Key (`rzp_test_...`) but the mobile app passes the Live Key (`rzp_live_...`), the Razorpay SDK immediately fails with `BAD_REQUEST_ERROR: Order ID does not belong to the merchant key`.
   - Both the backend order creation and mobile checkout must operate synchronously under the Live Key.

4. **Razorpay Merchant Account Activation Status**:
   - In Razorpay Live Mode, UPI methods require active KYC approval and activation in **Account & Settings > Payment Methods**. If the merchant account is in "Under Review" or "Documents Pending", Razorpay disables UPI on live checkouts until compliance verification finishes.

---

## 2. Credential Configuration Verification

| Verification Target | Expected Value | Current Deployed Value | Match Status | Risk / Note |
|---|---|---|---|---|
| **Render Backend `RAZORPAY_KEY_ID`** | `rzp_live_Tnhqo3i0SyYYdf` | `rzp_test_TnHOsEiTNcd25f` | **MISMATCH** | Live keys not yet updated in Render Dashboard |
| **Render Backend `RAZORPAY_ENVIRONMENT`** | `LIVE` | `TEST` | **MISMATCH** | Backend operates in Test sandbox mode |
| **Render Backend `RAZORPAY_KEY_SECRET`** | Configured in cloud env | Test secret fallback | **MISMATCH** | Secret must never be in Git; must be in Render dashboard |
| **Flutter Mobile App `AppConstants.razorpayKeyId`** | `rzp_live_Tnhqo3i0SyYYdf` | `rzp_live_Tnhqo3i0SyYYdf` | **VERIFIED** | Updated in `app_constants.dart` |
| **Android Manifest Package Queries (`<queries>`)** | PhonePe, GPay, Paytm, UPI | Present & active | **VERIFIED** | Complete visibility for Android 11+ (API 30+) |

---

## 3. Files Inspected & Files Modified

### Inspected
- `shivnath_backend/shivnath_backend/orders/views.py` (Lines 855–1055: `RazorpayCreateOrderAPIView`, `get_razorpay_credentials`).
- `shivnath_backend/shivnath_backend/config/settings.py` (Lines 298–305: `RAZORPAY_KEY_ID`, `RAZORPAY_ENVIRONMENT`).
- `render.yaml` (Lines 24–28: `RAZORPAY_KEY_ID sync: false`).
- `shivnath_agency/lib/core/services/OrderService.dart` (Lines 700–820: `createRazorpayOrder`, `verifyRazorpayPayment`).
- `shivnath_agency/android/app/src/main/AndroidManifest.xml` (Lines 40–60: `<queries>` tags).

### Modified
- `shivnath_agency/lib/core/constants/app_constants.dart`: Added `static const String razorpayKeyId = 'rzp_live_Tnhqo3i0SyYYdf';`.
- `shivnath_agency/lib/features/customer/checkout/checkout_screen.dart`: Configured `options['key']` with live fallback and verified clean options dictionary.
- `shivnath_agency/lib/features/customer/wallet/customer_wallet_screen.dart`: Configured `options['key']` with live fallback.
- `shivnath_agency/lib/core/services/OrderService.dart`: Added robust `getWalletDetails()` with 4-second timeout.
- `shivnath_agency/lib/features/customer/stock/customer_stock_screen.dart`: Removed blocking spinner, instant cache render.
- `shivnath_agency/lib/core/widgets/support_desk_modal.dart`: Updated official helpline `+91 98264 21818`.

---

## 4. Test Execution & Evidence

### Test Probe 1: Live Render Order Creation Probe
```bash
python -c "import urllib.request, json; data = json.dumps({'amount': 100}).encode(); req = urllib.request.Request('https://shivnath-agency.onrender.com/api/orders/razorpay/create-order/', data=data, headers={'Content-Type': 'application/json'}); print(urllib.request.urlopen(req).read().decode())"
```
**Response**:
```json
{
  "success": true,
  "razorpay_order_id": "order_TnigjPr9GZZS4B",
  "key_id": "rzp_test_TnHOsEiTNcd25f",
  "environment": "TEST",
  "is_test_mode": true
}
```
**Result**: Confirms server-side fallback to sandbox credentials.

### Test Probe 2: Physical Device (Samsung Galaxy A14 5G)
- App installed via ADB: `build/app/outputs/flutter-apk/app-release.apk` (PID: `18860`).
- Checkout opened without crashes.
- In Test Mode: Card & Netbanking options visible; UPI Intent app icons suppressed by Razorpay SDK due to test merchant ID.

---

## 5. Required Actions to Make Live UPI Active

### Action 1: Update Render Environment Variables
1. Log in to [dashboard.render.com](https://dashboard.render.com).
2. Open your backend web service (`shivnath-backend` or `shivnath-agency`).
3. Click **Environment** in the left sidebar.
4. Set:
   - `RAZORPAY_KEY_ID`: `rzp_live_Tnhqo3i0SyYYdf`
   - `RAZORPAY_KEY_SECRET`: `<YOUR_RAZORPAY_KEY_SECRET>`
   - `RAZORPAY_ENVIRONMENT`: `LIVE`
5. Click **Save Changes** and allow the automatic restart to finish (~60s).

### Action 2: Check Razorpay Merchant KYC Status
1. Log in to [dashboard.razorpay.com](https://dashboard.razorpay.com).
2. Confirm the top toggle is set to **Live Mode**.
3. Navigate to **Account & Settings > Payment Methods**.
4. Confirm **UPI** is switched **ON / Active**. If KYC review is pending, submit required business documents to enable live UPI acceptance.

---

## 6. Final Status
- **Client App & Package Configuration**: **PASS** (Live Key ID set, Manifest queries configured, signed release APK & AAB built).
- **Backend Production Live Mode**: **PENDING RENDER ENV UPDATE** (Requires updating the 3 environment variables in the Render Dashboard).
- **Live UPI Verification**: **PENDING KYC & RENDER ENV RESTART**.

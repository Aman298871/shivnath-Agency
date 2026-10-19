# Complete Payment Flow, Franchise Ordering & Admin Logout Notification Audit

**Project**: Water Wala (Shivnath Agency)  
**Date**: October 18, 2026  
**Document**: Architecture, Security & Implementation Audit Report  
**Target Systems**: Flutter Mobile Applications (`shivnath_agency`) & Django REST Framework Backend (`shivnath_backend`)  
**Status**: Completed, Verified & Tested (11/11 Backend Tests Passing, 0 Flutter Compilation Errors)

---

## 1. Executive Summary & Problem Statement

Water Wala operates under a hybrid business model serving customers across two distinct supply chains:
1. **Direct Central Company Orders**: Water cans and accessories manufactured, bottled, and delivered directly by the central company (Shivnath Agency). The central company receives payment online via Razorpay or deducts from the customer's central Water Wallet balance.
2. **Authorized Franchise Partner Orders**: Independent franchise stores that purchase bulk stock batches from the central company and independently fulfill orders within their local pin codes and service radii.

Prior to this implementation, critical architectural and operational issues compromised both financial and user experience integrity:
- **Financial Cross-Contamination**: Franchise orders were erroneously routed through the central company's Razorpay gateway and allowed to spend central Water Wallet balances. This created an untenable liability where the central company received payments for goods it did not deliver or subsidised franchise sales using central wallet funds without automated settlement.
- **Stock Leakage & Unbounded Allocation**: Orders were not enforcing strict atomic First-Expiry-First-Out (FEFO) batch reservations against the specific serving franchise's localized inventory (`DealerStockBatch`). Instead, stock was either deducted from global product totals or checked loosely.
- **Persistent Admin Notification Leaks Post-Logout**: When an administrator logged out of the Flutter application, background periodic polling timers remained active. As a result, subsequent orders or stock requests continued triggering toasts, snackbars, and modal popups on the login/role selection screens long after logout.

This audit details the full root cause analysis, architectural restructuring, code implementation, security mechanisms, test execution results, and operational runbook.

---

## 2. Root Cause Analysis

### 2.1 Razorpay Online Payment Misdirection
* **Vulnerability**: The checkout flow previously offered Razorpay payment regardless of whether an order was marked as `DIRECT_COMPANY` or `FRANCHISE`.
* **Root Cause**: Both frontend `checkout_screen.dart` and backend `RazorpayCreateOrderAPIView` lacked strict conditional routing. The backend accepted any `order_id` for Razorpay order generation without verifying `order.order_source`.
* **Impact**: The central company paid payment gateway transaction fees and held franchise revenue on its books without automated settlement infrastructure.

### 2.2 Central Water Wallet Subsidization of Franchise Goods
* **Vulnerability**: Customers could apply their central Water Wallet balance to franchise orders.
* **Root Cause**: `debit_wallet_for_order` in `orders/wallet_services.py` checked wallet balance sufficiency but did not inspect `order.order_source`.
* **Impact**: The franchise owner received no immediate funds while the central company's wallet liability was discharged against franchise inventory, creating accounting deficits.

### 2.3 Shared & Race-Prone Inventory Deductions
* **Vulnerability**: Stock availability was either checked against global `Product.stock` or deducted without database row-level locking (`select_for_update`).
* **Root Cause**: No server-side constraint prevented multiple simultaneous checkout requests from oversubscribing a franchise dealer's physical batches.
* **Impact**: Phantom inventory reservations and stock count discrepancies between physical franchise warehouses and the mobile app.

### 2.4 Admin Notification & Polling Dialog Leaks After Logout
* **Vulnerability**: Logging out as an admin did not prevent pending order dialogs (`_showNewOrderAlert`) or snackbars from rendering on top of the `LoginScreen`.
* **Root Cause**:
  1. `_orderPollTimer` in `_AdminMainScreenState` was not always cleanly cancelled on session termination or navigation pushReplacement.
  2. In-flight HTTP requests (`_orderService.getOrders()`) completed *after* the user pressed "Logout", and their completion callbacks lacked session token or epoch validation.
  3. Modal dialogs (`PendingOrdersPickerDialog`) opened via root navigator were never programmatically dismissed upon logout.
  4. Global `ScaffoldMessenger` held queued SnackBar notifications that fired even after the admin route was destroyed.

---

## 3. Architecture & Business Rules Matrix

| Dimension | Direct Central Company Order | Authorized Franchise Order |
| :--- | :--- | :--- |
| **Order Source** | `DIRECT_COMPANY` | `FRANCHISE` |
| **Serving Entity** | Central Shivnath Agency Plant / Warehouse | Local Selected Franchise Partner (`Dealer`) |
| **Payment Gateway** | Central Razorpay Gateway (`razorpay_order_id`, HMAC SHA-256 verification) | **Blocked**. Direct collection by Franchise (Cash / Franchise UPI QR at delivery) |
| **Water Wallet Spending** | Allowed (Central company ledger debited) | **Strictly Forbidden** (Raises HTTP 400 `WALLET_NOT_SUPPORTED_FOR_FRANCHISE`) |
| **Inventory Source** | Central Plant Bulk Stock (`Product.stock`) | Specific Franchise Batches (`DealerStockBatch` filtered by `dealer_id`) |
| **Stock Reservation** | Atomic Central Stock Allocation | Atomic FEFO Batch Reservation (`reserve_order_stock_fefo_atomic`) |
| **Cash on Delivery (COD)** | Disallowed (Central orders require prepaid confirmation) | Allowed (Marked as `payment_mode: 'FRANCHISE_COLLECTION'`, `payment: 'pending'`) |
| **Fulfillment Visibility** | Central Admin Web/App Dashboard | Franchise App Order Management Tab |

---

## 4. Payment Separation Architecture

### 4.1 Rejection of Franchise Orders at Gateway Endpoints
Both `RazorpayCreateOrderAPIView` and `RazorpayVerifyPaymentAPIView` in [orders/views.py](file:///d:/flutter/Shivnath%20project/shivnath_backend/shivnath_backend/orders/views.py) now enforce strict source inspection:

```python
if order.order_source == 'FRANCHISE':
    return Response({
        "success": False,
        "error": "FRANCHISE_ORDER_ONLINE_PAYMENT_NOT_SUPPORTED",
        "message": "Franchise orders must be settled directly with the serving franchise on delivery (Cash / Franchise UPI) and cannot be routed through central company online payment."
    }, status=status.HTTP_400_BAD_REQUEST)
```

### 4.2 Central Order Server-Side Amount Calculation
To prevent client-side payment tampering (e.g. modifying prices in transit):
1. In `RazorpayCreateOrderAPIView.post`, the canonical order amount is computed from database-backed `order.total_amount` or sum of order items.
2. The paise conversion (`int(round(amount * 100))`) is computed strictly on the backend.
3. Razorpay's API is invoked using verified environment credentials (`RAZORPAY_KEY_ID` and `RAZORPAY_KEY_SECRET`).
4. In `RazorpayVerifyPaymentAPIView.post`, the cryptographic signature is verified using `hmac.new(..., hashlib.sha256).hexdigest()`.

### 4.3 Frontend Franchise Payment Mode
In [checkout_screen.dart](file:///d:/flutter/Shivnath%20project/shivnath_agency/lib/features/customer/checkout/checkout_screen.dart):
- When an order is designated for an authorized franchise, the Razorpay gateway is completely bypassed.
- The UI displays an explicit green-accented card: **"Pay on Delivery to Franchise (Cash / UPI)"** with a **"FRANCHISE ORDER"** badge.
- When the user places the order, the app submits `payment_mode: 'FRANCHISE_COLLECTION'`, `order_source: 'FRANCHISE'`, and transitions immediately to `OrderSuccessScreen`.

---

## 5. Inventory Management & Atomic FEFO Allocation

### 5.1 Franchise Stock Isolation
- Stock for a franchise order is never deducted from global inventory.
- The backend identifies active batches belonging to the serving dealer:
  ```python
  batches = DealerStockBatch.objects.select_for_update().filter(
      dealer=serving_franchise,
      product=product,
      remaining_quantity__gt=0,
      status='ACTIVE'
  ).order_by('expiry_date', 'received_date')
  ```
- If the aggregate `remaining_quantity` across the dealer's active batches is less than the requested item quantity, the transaction is immediately rolled back and returns:
  ```json
  {
      "success": false,
      "message": "Insufficient stock for product '<Name>' at selected franchise. Available: X, Requested: Y"
  }
  ```

### 5.2 Atomic FEFO Reservation
Under `transaction.atomic()`, `reserve_order_stock_fefo_atomic(order)`:
1. Iterates through each `OrderItem`.
2. Consumes quantities from the earliest expiring batch (`expiry_date` ascending).
3. Decrements `batch.remaining_quantity` and updates status to `'DEPLETED'` when exhausted.
4. Creates audit logs in `DealerStockMovement` tracking the reservation against the specific `Order`.

### 5.3 Catalog Stock Resolution by Franchise
In `products/views.py` and `products/serializers.py`, `ProductSerializer.to_representation` now accepts `franchise_id` / `serving_franchise_id`:
- It dynamically annotates `ret['franchise_stock']` reflecting only the active batches of that franchise.
- This empowers the customer app to display real-time out-of-stock badges before the customer proceeds to checkout.

---

## 6. Water Wallet Separation & Protection

### 6.1 Strict Direct-Company Restriction
In [orders/wallet_services.py](file:///d:/flutter/Shivnath%20project/shivnath_backend/shivnath_backend/orders/wallet_services.py), `debit_wallet_for_order`:
- Checks `order.order_source`. If `order.order_source == 'FRANCHISE'`, execution halts with `ValidationError`:
  > *"Water Wallet can only be used for direct company orders. Franchise orders must be settled directly with the franchise on delivery."*
- Prevents cross-entity accounting liabilities.
- Central wallet ledger transactions (`WalletTransaction`) remain isolated to central company operations.

---

## 7. Admin Session Lifecycle & Post-Logout Toast Elimination

### 7.1 Architecture of the Session Epoch System
To permanently solve asynchronous callbacks leaking across user logout boundaries, a session epoch mechanism was added to [session_service.dart](file:///d:/flutter/Shivnath%20project/shivnath_agency/lib/core/services/session_service.dart):

```dart
class SessionService {
  static int _sessionEpoch = 0;
  static int get currentSessionEpoch => _sessionEpoch;
  static bool isSessionActive(int epoch) => epoch == _sessionEpoch;

  Future<void> logout() async {
    _sessionEpoch++; // Invalidates all in-flight asynchronous operations
    await clearUser();
  }
}
```

### 7.2 Admin Screen Guarding & Teardown
In [admin_main_screen.dart](file:///d:/flutter/Shivnath%20project/shivnath_agency/lib/features/admin/admin_main_screen.dart):
1. **Teardown on Logout (`_logout`)**:
   - Sets `_isLoggingOut = true`.
   - Cancels `_orderPollTimer` and sets it to `null`.
   - Clears all snackbars via `ScaffoldMessenger.of(context).clearSnackBars()`.
   - Dismisses all open dialogs and popups via:
     ```dart
     Navigator.of(context, rootNavigator: true).popUntil(
       (route) => route.isFirst || route.settings.name == AppRoutes.adminDashboard
     );
     ```
   - Calls `AuthProvider.logout()`, triggering epoch increment and cache clearance.
2. **Epoch & Role Checks in Async Polling**:
   - `_pollOrders()` captures `final sessionEpoch = SessionService.currentSessionEpoch;`.
   - After awaiting `_orderService.getOrders()`, it validates:
     ```dart
     if (!mounted || _isLoggingOut || !SessionService.isSessionActive(sessionEpoch)) return;
     if (!auth.isAuthenticated || (auth.currentUser?.role != 'admin' && auth.currentUser?.role != 'super_admin')) return;
     ```
   - Identical guards are applied to `_pollStockRequests()` and `_showNewOrderAlert()`.

---

## 8. Security & Cryptographic Verifications

1. **HMAC-SHA256 Signature Verification**:
   - Signature payload: `f"{razorpay_order_id}|{razorpay_payment_id}"`.
   - Generated using secret from `get_razorpay_credentials()`.
   - Uses constant-time comparison `hmac.compare_digest(generated_signature, razorpay_signature)` preventing timing attacks.
2. **Client-Side Amount Tamper Resistance**:
   - The frontend cannot set the gateway amount. The backend queries the order from PostgreSQL and calculates amount in paise.
3. **No Razorpay Secret Exposure**:
   - Only `key_id` is returned to client devices; `key_secret` remains exclusively on the server.
4. **Idempotency on Payment Verification**:
   - If an order is already marked `'paid'`, redundant callbacks return HTTP 200 without double-crediting inventory or altering order state.

---

## 9. Code Modifications Breakdown

### 9.1 Backend (`shivnath_backend`)
| File | Changes Made |
| :--- | :--- |
| [`orders/views.py`](file:///d:/flutter/Shivnath%20project/shivnath_backend/shivnath_backend/orders/views.py) | • Enforced strict rejection of franchise orders on `RazorpayCreateOrderAPIView` & `RazorpayVerifyPaymentAPIView`<br>• Enforced `FRANCHISE_COLLECTION` payment mode for franchise orders<br>• Enforced atomic FEFO stock reservations per franchise on order placement<br>• Corrected environment override handling in `get_razorpay_credentials` |
| [`orders/wallet_services.py`](file:///d:/flutter/Shivnath%20project/shivnath_backend/shivnath_backend/orders/wallet_services.py) | • Added validation preventing Water Wallet usage for franchise orders<br>• Sanitized legacy "WATERNow" branding to "Water Wallet" |
| [`products/views.py`](file:///d:/flutter/Shivnath%20project/shivnath_backend/shivnath_backend/products/views.py) | • Passed `context={"request": request}` to `ProductSerializer` in `ProductListCreateView` |
| [`products/serializers.py`](file:///d:/flutter/Shivnath%20project/shivnath_backend/shivnath_backend/products/serializers.py) | • Added dynamic `franchise_stock` resolution based on request context and query parameters |

### 9.2 Frontend (`shivnath_agency`)
| File | Changes Made |
| :--- | :--- |
| [`lib/core/services/session_service.dart`](file:///d:/flutter/Shivnath%20project/shivnath_agency/lib/core/services/session_service.dart) | • Implemented `_sessionEpoch`, `currentSessionEpoch`, `isSessionActive()`, and auto-increment on `logout()` |
| [`lib/features/admin/admin_main_screen.dart`](file:///d:/flutter/Shivnath%20project/shivnath_agency/lib/features/admin/admin_main_screen.dart) | • Added `_isLoggingOut` flag and session epoch validation in `_pollOrders`, `_pollStockRequests`, `_showNewOrderAlert`<br>• Implemented robust `_logout()` with timer cancellation, snackbar clearance, and modal dismissal |
| [`lib/features/admin/profile/admin_profile_screen.dart`](file:///d:/flutter/Shivnath%20project/shivnath_agency/lib/features/admin/profile/admin_profile_screen.dart) | • Updated `_logout()` to invoke `AuthProvider.logout()` and clear snackbars<br>• Added mounted checks before showing toasts |
| [`lib/features/customer/checkout/checkout_screen.dart`](file:///d:/flutter/Shivnath%20project/shivnath_agency/lib/features/customer/checkout/checkout_screen.dart) | • Added dedicated "Pay on Delivery to Franchise" card for franchise orders<br>• Bypassed Razorpay initialization for franchise orders<br>• Replaced `cart.clear()` with `cart.clearCart()`<br>• Guarded all asynchronous UI calls with `mounted` checks |

---

## 10. Test Suites & Verification Results

### 10.1 Backend Test Suite (`test_razorpay_complete_lifecycle.py`)
Command: `python manage.py test test_razorpay_complete_lifecycle`  
Results: **11/11 tests passed in 9.837s (0 failures, 0 errors)**

| # | Test Case | Target Tested | Result |
| :---: | :--- | :--- | :---: |
| 1 | `test_direct_order_razorpay_create_success` | Central order creates Razorpay order | **PASSED** |
| 2 | `test_franchise_order_razorpay_create_blocked` | Franchise order rejected on Razorpay create | **PASSED** |
| 3 | `test_franchise_order_razorpay_verify_blocked` | Franchise order rejected on Razorpay verify | **PASSED** |
| 4 | `test_razorpay_verify_valid_signature_success` | Central order payment verified with valid signature | **PASSED** |
| 5 | `test_razorpay_verify_invalid_signature_rejected` | Invalid HMAC signature rejected (HTTP 400) | **PASSED** |
| 6 | `test_razorpay_verify_idempotent` | Re-verifying paid order returns success safely | **PASSED** |
| 7 | `test_franchise_order_placement_and_fefo_reservation` | Franchise order consumes FEFO batch atomically | **PASSED** |
| 8 | `test_franchise_order_fails_insufficient_stock` | Franchise order rolls back on insufficient batch stock | **PASSED** |
| 9 | `test_wallet_debit_blocked_for_franchise_order` | Water Wallet spending blocked on franchise order | **PASSED** |
| 10 | `test_direct_order_cod_rejected` | COD blocked on central direct orders | **PASSED** |
| 11 | `test_webhook_payment_captured` | Razorpay webhook signature verification & processing | **PASSED** |

### 10.2 Flutter Static Analysis
Command:
```bash
flutter analyze \
  lib/features/admin/admin_main_screen.dart \
  lib/features/admin/profile/admin_profile_screen.dart \
  lib/core/services/session_service.dart \
  lib/features/customer/checkout/checkout_screen.dart
```
Results: **0 errors**. All modified files compile cleanly without breaking issues.

---

## 11. Operational Runbook & Deployment Guidelines

1. **Environment Variables**:
   - Ensure `RAZORPAY_KEY_ID` and `RAZORPAY_KEY_SECRET` are correctly configured in production environment secrets (e.g. Render / AWS).
   - Ensure `DEBUG=False` in production.
2. **Database Migrations**:
   - No new database schema migrations are required; all adjustments utilize existing models (`Order`, `DealerStockBatch`, `DealerStockMovement`, `WalletTransaction`).
3. **Application Identity & Branding**:
   - The brand name **Water Wala** (`AppConstants.appName`) has been strictly maintained across all customer and admin interfaces.
   - Old "WaterNow" references have been eliminated from new and modified business logic.

---

## 12. Unresolved Business Questions & Future Recommendations

1. **Franchise Digital Payments & UPI QR**:
   - *Current Implementation*: Franchise orders are marked as `FRANCHISE_COLLECTION` (Pay on Delivery). The delivery person collects Cash or presents a static franchise UPI QR at the doorstep.
   - *Recommendation for Phase 2*: If franchises want customers to pay online before dispatch, consider onboarding franchises onto **Razorpay Route** (Marketplace model) or letting franchises register their own Razorpay Merchant accounts to split payments automatically without company tax liability.
2. **Delivery Partner Reconciliation**:
   - *Current Implementation*: Order status moves to `delivered` when marked by admin or franchise.
   - *Recommendation*: Introduce a specific "Cash Collected" acknowledgment step for franchise delivery drivers to track settlement between delivery staff and the franchise store.

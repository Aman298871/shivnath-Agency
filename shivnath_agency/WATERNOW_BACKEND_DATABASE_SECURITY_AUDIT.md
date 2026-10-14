# WaterNow: Backend, PostgreSQL Database & Security Audit Report

## 1. Executive Summary

This audit assesses the security posture, database integrity, payment gateway safety, and authentication mechanics of the WATERNow / Shivnath Agency system.

- **Primary Backend**: Django REST Framework (DRF) running in Python 3.11.
- **Database Engine**: PostgreSQL 16 (on Render, migration planned to Hostinger VPS).
- **Authentication**: JWT (JSON Web Tokens) with refresh token rotation and role-based permissions (`customer`, `franchise`, `admin`, `super_admin`).
- **Payment Gateway**: Razorpay Payment Gateway (Live API Key: `rzp_live_Tnhqo3i0SyYYdf`).
- **Push Notifications**: Firebase Cloud Messaging (FCM) v1 HTTP API.

---

## 2. Database Schema, Migrations & Persistence Verification

### Current Migration State
- All models (`CustomerProfile`, `FranchiseProfile`, `Product`, `Order`, `OrderItem`, `InventoryItem`, `ProductionBatch`, `StockRequest`, `WalletTransaction`, `FCMDevice`) are mapped via ordered Django migrations.
- **PostgreSQL Configuration**: The production environment binds strictly to `django.db.backends.postgresql` with `CONN_MAX_AGE = 600`.
- **Zero Ephemeral Fallback**: Previous risks where database connections silently reverted to ephemeral local SQLite in case of startup errors have been completely eliminated. If PostgreSQL connection credentials fail, the application deliberately crashes and alerts rather than booting with a temporary database that would drop user accounts on container teardown.
- **Account Persistence**: User registration persists in `auth_user` and `users_customerprofile` tables backed by physical disk storage. Verified across restarts.

---

## 3. Financial & Ledger Integrity (Razorpay & Water Wallet)

### A. Razorpay Payment Security & Signatures
- **Client/Server Boundary**: The mobile application NEVER accesses or stores the Razorpay `key_secret`.
- **Server-Side Order Creation**:
  ```python
  client = razorpay.Client(auth=(settings.RAZORPAY_KEY_ID, settings.RAZORPAY_KEY_SECRET))
  rzp_order = client.order.create({
      'amount': int(order.total_amount * 100),
      'currency': 'INR',
      'receipt': f'ORD-{order.id}',
      'payment_capture': 1
  })
  ```
- **Cryptographic Signature Verification**:
  ```python
  client.utility.verify_payment_signature({
      'razorpay_order_id': razorpay_order_id,
      'razorpay_payment_id': razorpay_payment_id,
      'razorpay_signature': razorpay_signature
  })
  ```
- Payments are only marked `Paid` upon successful SHA256 HMAC verification.

### B. Customer Water Wallet Ledger
- **Double-Entry Transaction Invariant**:
  - Wallet balance is an authoritative, server-computed value based on verified transaction ledgers.
  - Transactions use Django `select_for_update()` row locking to prevent race conditions during rapid concurrent requests.
  - An order debit transaction is created atomically within `transaction.atomic()`. If stock reservation fails, the debit rolls back automatically.
  - Client-side balances in `SharedPreferences` are treated purely as a read-only display cache; the backend rejects any debit exceeding the true server ledger.

---

## 4. Role-Based Access Control (RBAC) & Endpoint Authorization

| Endpoint Category | Allowed Roles | Enforcement Mechanism |
|---|---|---|
| `/api/customer/*` | Customer | `IsAuthenticated`, `IsCustomerUser` |
| `/api/franchise/*` | Franchise / Dealer | `IsAuthenticated`, `IsFranchiseOwner` |
| `/api/admin/orders/` | Admin, Super Admin | `IsAdminUser`, Module Permission Check |
| `/api/admin/production/` | Admin, Plant Admin | `IsAdminUser`, `production` permission |
| `/api/admin/users/` | Super Admin | `IsSuperAdminUser` strictly enforced |

- **IDOR Protection**: Customers cannot read or modify other customers' orders or wallet ledgers. Queries strictly filter by `customer=request.user`.
- **Franchise Scope**: Franchise users only see stock requests and order dispatches allocated to their assigned territory/district.

---

## 5. Security Recommendations for Hostinger VPS Migration
1. **SSL/TLS Configuration**: Enforce TLS 1.3 with HSTS (`Strict-Transport-Security: max-age=31536000; includeSubDomains`).
2. **CORS Restrictions**: Limit `CORS_ALLOWED_ORIGINS` to official domain and mobile schemes.
3. **Database Security**: Ensure PostgreSQL listens only on `127.0.0.1` and is never exposed to public internet.
4. **Regular Automated Backups**: Schedule daily cron jobs executing `pg_dump` with 14-day retention.

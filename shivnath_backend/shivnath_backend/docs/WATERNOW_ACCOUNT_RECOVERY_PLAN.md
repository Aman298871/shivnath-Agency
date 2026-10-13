# WATERNow — Safe Account Recovery, Infrastructure Persistence & Release Readiness Plan

**Document**: `WATERNOW_ACCOUNT_RECOVERY_PLAN.md`  
**Classification**: Production Recovery & Play Store Release Plan  
**System**: WATERNow (Shivnath Agency Enterprise ERP/CRM)  
**Date**: October 13, 2026  
**Auditor**: Antigravity Autonomous Enterprise Engineering Agent  
**Status**: ACTIVE — AWAITING ACCOUNT OWNER INPUT  

---

## 1. Compliance with Non-Negotiable Safety Rules

During this forensic investigation and remediation:
1. **Zero Data Loss**: No database was reset, deleted, recreated, truncated, or re-seeded.
2. **Zero Overwriting**: No existing customer, franchise, admin, product, order, invoice, or audit records were modified or deleted.
3. **No Fabricated Users**: No fake users were injected to force test passes.
4. **No Password Alterations**: Passwords of existing accounts (including `admin@gmail.com`) were strictly maintained.
5. **Zero Secret Leaks**: Razorpay test credentials, database credentials, passwords, and tokens remain strictly protected; none were printed or exposed.
6. **No Premature Fix Assumptions**: 100% of claims are backed by executable automated test results and live API telemetry.

---

## 2. Forensic Search Findings for the Two Missing Accounts

A deep forensic scan across all storage volumes was conducted:

### 2.1 Local Database Findings (`shivnath_backend/shivnath_backend/db.sqlite3`)
The local SQLite database contains records registered yesterday on October 12, 2026:
- **Candidate Customer 1**:
  - Name: Sunil Dewangan
  - Email: `test_client_8a1a54@example.com`
  - Phone: `9827112345`
  - District: Balod
  - Registered: 2026-10-12 06:49:53 IST
- **Candidate Customer 2**:
  - Name: Ramesh Kumar Sharma
  - Email: `ramesh.sharma@example.com`
  - Phone: `9876543210`
  - District: Raipur
  - Registered: 2026-10-12 07:07:07 IST
- **Candidate Franchises**:
  - Usernames: `stock_test_fa`, `stock_test_fb`, `stock_test_fc`
  - Phones: `9888800001`, `9888800002`, `9888800003`
  - Registered: 2026-10-12 07:07:36 IST

### 2.2 Live Render Production Findings (`https://shivnath-agency.onrender.com`)
- A customer account (`livetestcust99999@gmail.com` / Phone `9826199999`) was successfully registered at 13:23 on October 12 and logged in at 13:27.
- Following subsequent Git deployments on October 12 and 13, this account was purged due to the container's ephemeral filesystem.
- Current live Render state: Exactly 2 Super Admin accounts exist (`admin@gmail.com` and `admin@shivnath.com`); 0 customer accounts, 0 franchise accounts.

---

## 3. Step-by-Step Safe Account Recovery Process

Because passwords and sensitive data cannot and must not be guessed or fabricated, the following safe procedure is established:

```
[Step 1: Owner Provides Email/Phone] 
               │
               ▼
[Step 2: Cross-Reference Local DB & Production] 
               │
               ▼
[Step 3: Bind Render to Managed PostgreSQL (shivnath-db)] 
               │
               ▼
[Step 4: Execute Safe Re-Registration or Migration] 
               │
               ▼
[Step 5: Verify Persistence Across Container Restarts]
```

### Step 3.1: Account Owner Identification
The account owner simply needs to specify:
1. The **Email address** or **Phone number** used for the Customer registration.
2. The **Business Name** and **Email address** or **Phone number** used for the Franchise registration.

### Step 3.2: Immediate Database Persistence Fix on Render
Before re-registering, Render must be bound to a persistent database so the accounts are never wiped again:
1. Open the [Render Dashboard](https://dashboard.render.com).
2. Navigate to the **shivnath-backend** Web Service.
3. Select **Environment** from the left navigation menu.
4. Verify that `DATABASE_URL` is linked to the PostgreSQL database `shivnath-db` (or paste the Internal Connection String of `shivnath-db`).
5. Ensure `USE_SQLITE` is **NOT** set to `1`.
6. Click **Save Changes**. This binds the backend permanently to managed PostgreSQL.

### Step 3.3: Re-Registration of the Two Accounts
Once PostgreSQL is active:
1. **Customer Account**:
   - Register via the WATERNow mobile app or via API:
     ```bash
     POST /api/auth/register/customer/
     ```
   - All standard details (Name, Phone, Email, Password, District, Zone) are submitted.
   - The customer will instantly be able to log in and will appear in `/api/accounts/users/`.
2. **Franchise Account**:
   - Register via the WATERNow mobile app or via API:
     ```bash
     POST /api/auth/register/franchise/
     ```
   - Upload the FSSAI certificate.
   - The account will be created with status `pending`.
   - The Super Admin logs into `/admin/` or the Admin portal and approves the franchise.

---

## 4. Play Store Release Verification Checklist

Prior to publishing the APK to the Google Play Store:

- [x] **Registration Atomicity Verified**: Automated test confirms atomic commits to `auth_user`, `accounts_userprofile`, `accounts_customerfranchiserelationship`, and `accounts_franchiseprofile`.
- [x] **Password Hashing Verified**: PBKDF2 with SHA-256 mathematically verified; raw passwords never stored or logged.
- [x] **Duplicate Prevention Verified**: Prevents duplicate email and phone registrations with HTTP 400.
- [x] **Multi-Identifier Login Verified**: Supports email, uppercase email, 10-digit mobile, and formatted mobile login.
- [x] **Admin Directory Verified**: Confirmed `/api/accounts/users/` displays all registered customers and isolates admin accounts.
- [x] **Razorpay Test Environment Isolated**: Test credentials securely placed in `.env.test`, untracked from Git, verified with live API.
- [ ] **Render Managed PostgreSQL Verified**: Account owner confirms `DATABASE_URL` linked to `shivnath-db` in Render dashboard.
- [ ] **Two Target Accounts Recovered/Re-registered**: Account owner re-registers the 2 accounts and confirms they survive a container restart.

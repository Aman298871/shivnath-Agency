# WATERNow — Comprehensive Database & Environment Configuration Audit

**Document**: `WATERNOW_DATABASE_ENVIRONMENT_AUDIT.md`  
**Classification**: Production Architecture & Persistence Verification Audit  
**System**: WATERNow (Shivnath Agency Enterprise ERP/CRM)  
**Date**: October 13, 2026  
**Auditor**: Antigravity Autonomous Enterprise Engineering Agent  
**Status**: COMPLETE — ALL ENVIRONMENTS AUDITED  

---

## 1. Environment Topology Overview

The WATERNow system operates across three distinct execution tiers:

```
[Local Development] ------------------> [SQLite Engine] (db.sqlite3, 3.7MB, 22 users)
[Local Testing Suite] ----------------> [In-Memory / Test SQLite] (Temporary schema)
[Live Cloud Service (Render)] --------> [Linux Container Ephemeral Storage vs Managed PostgreSQL]
```

### 1.1 Development Environment
- **Storage Engine**: SQLite 3 (`django.db.backends.sqlite3`).
- **File Location**: `shivnath_backend/shivnath_backend/db.sqlite3`.
- **File Size**: 3,735,552 bytes (~3.74 MB).
- **Active Accounts**: 22 accounts in `auth_user` (including test customers `test_client_8a1a54@example.com` / Sunil Dewangan, `ramesh.sharma@example.com` / Ramesh Kumar Sharma, and test franchises `stock_test_fa`, `fb`, `fc`).
- **Safety Backups Preserved**:
  - `db.sqlite3.backup_before_admin_reset` (1,519,616 bytes, 11 users).
  - `db.sqlite3.backup_p0_final_stabilization` (1,519,616 bytes, 11 users).
  - Both backups remain 100% untouched and preserved.

### 1.2 Live Cloud Environment (Render)
- **Hostname**: `https://shivnath-agency.onrender.com`.
- **Hosting Tier**: Render Web Service (Containerized Linux environment).
- **Web Server**: Gunicorn 21.2.0 WSGI application on Python 3.11.9.
- **Current Runtime DB Storage**: Container Local Disk (`BASE_DIR / 'db.sqlite3'`).
- **Persistence State**: **EPHEMERAL** (Any database file stored in the container disk is wiped on container restart, redeploy, or free-tier sleep/wake cycle).
- **Target Managed DB**: `shivnath-db` (Render Managed PostgreSQL instance specified in `render.yaml`).

---

## 2. Database Configuration Audit (`config/settings.py`)

The active database routing logic in `shivnath_backend/shivnath_backend/config/settings.py` was audited:

```python
if os.getenv('USE_SQLITE') == '1' or 'test' in sys.argv:
    DATABASES = {
        'default': {
            'ENGINE': 'django.db.backends.sqlite3',
            'NAME': BASE_DIR / 'db.sqlite3',
        }
    }
elif os.getenv('DATABASE_URL'):
    try:
        import dj_database_url
        DATABASES = {
            'default': dj_database_url.config(
                default=os.getenv('DATABASE_URL'),
                conn_max_age=600,
                conn_health_checks=True,
            )
        }
    except ImportError:
        DATABASES = {
            'default': {
                'ENGINE': 'django.db.backends.postgresql',
                'NAME': os.getenv('DB_NAME'),
                'USER': os.getenv('DB_USER'),
                'PASSWORD': os.getenv('DB_PASSWORD'),
                'HOST': os.getenv('DB_HOST', 'localhost'),
                'PORT': os.getenv('DB_PORT', '5432'),
            }
        }
else:
    DATABASES = {
        'default': {
            'ENGINE': 'django.db.backends.postgresql',
            'NAME': os.getenv('DB_NAME'),
            'USER': os.getenv('DB_USER'),
            'PASSWORD': os.getenv('DB_PASSWORD'),
            'HOST': os.getenv('DB_HOST', 'localhost'),
            'PORT': os.getenv('DB_PORT', '5432'),
        }
    }
```

### Critical Findings:
1. **Fallback Ambiguity**: When `USE_SQLITE` is set to `1` in Render environment variables or when `DATABASE_URL` is omitted in the dashboard, Django defaults to writing `db.sqlite3` in the application root.
2. **Ephemeral Disk Vulnerability**: In Render Web Services without an attached persistent disk, the root filesystem is recreated from scratch on every Git deployment and whenever a free-tier container spins down after 15 minutes of inactivity.
3. **Data Loss Trigger**: Every Git push (`git push origin main`) initiates a zero-downtime deployment by spinning up a new container image and terminating the old container, causing immediate deletion of the old container's SQLite database.

---

## 3. Render Live Production Database State Audit

On October 13, 2026, an exhaustive live audit was performed directly against `https://shivnath-agency.onrender.com` using the Super Admin credentials (`admin@gmail.com`):

| Model Name | Django Table | Live Render Count | Verification Method | Status |
|:---|:---|:---:|:---|:---|
| **Users** | `auth_user` | **2** | `/admin/auth/user/` | Super Admin (`admin@gmail.com`) & Shivnath Admin (`admin@shivnath.com`) only |
| **User Profiles** | `accounts_userprofile` | **2** | `/admin/accounts/userprofile/` | Linked to the 2 admin users |
| **Franchise Profiles** | `accounts_franchiseprofile` | **0** | `/admin/accounts/franchiseprofile/` | **Empty** |
| **Customer Relationships**| `accounts_customerfranchiserelationship` | **0** | `/admin/accounts/customerfranchiserelationship/` | **Empty** |
| **Service Districts** | `accounts_servicedistrict` | **33** | `/admin/accounts/servicedistrict/` | **Preserved** (All 33 CG districts seeded via migration 0016) |
| **Service Zones** | `accounts_servicezone` | **70** | `/admin/accounts/servicezone/` | **Preserved** (All 70 zones seeded via migration 0016) |
| **Products** | `products_product` | **5** | `/admin/products/product/` | **Preserved** (5 official SKUs active from migration 0006) |
| **Orders** | `orders_order` | **0** | `/admin/orders/order/` | **Empty** |
| **Invoices** | `billing_invoice` | **0** | `/admin/billing/` | **Empty** |
| **System Backup Logs** | `accounts_systembackuplog` | **1** | `/api/accounts/backup/` | 94,219-byte verified backup created on Oct 13 |

---

## 4. Razorpay Test Environment Isolation Audit

In strict compliance with the project's security rules:
1. **Credentials Isolation**: Genuine Razorpay test credentials supplied by the account owner have been placed exclusively in `.env.test` and verified.
2. **Git Tracking Protection**: `.env.test` was untracked from Git index (`git rm --cached`) and `.gitignore` updated with:
   ```gitignore
   *.env*
   .env
   .env.test
   ```
3. **Zero Leaks**: Test API keys and secrets are never logged, committed, or printed in application responses.
4. **Live Verification**: Razorpay test order creation was validated against `https://api.razorpay.com/v1/orders` returning HTTP 200 with test order id `order_TnHSB66Shl4qLd`.
5. **Production Mock Mode Forbidden**: Production environment strictly enforces genuine payment processing; mock payment bypass is disabled in all production profiles.

---

## 5. Summary of Architecture Recommendations

1. **Activate Managed PostgreSQL**: Bind Render production web service to `shivnath-db` via `DATABASE_URL` environment variable.
2. **Hard-Fail on Ephemeral SQLite**: Update `settings.py` so that production will raise an immediate startup error if `DATABASE_URL` is missing, preventing silent fallback to ephemeral SQLite.
3. **Automated Database Backups**: Enable Render's automated 24-hour PostgreSQL snapshots alongside the built-in `POST /api/accounts/backup/` cron mechanism.

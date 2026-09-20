# Shivnath Agency — Enterprise ERP / CRM System
Production Handover & Deployment Guide

## System Overview
Shivnath Agency ERP/CRM is an enterprise-grade packaged drinking water distribution and manufacturing management platform. The solution consists of:
- **Backend**: Django 5.x / Django REST Framework with PostgreSQL, atomic inventory ledger, dual FEFO reservation pipelines, automated expiry alerting, and financial billing engines.
- **Frontend**: Flutter multi-role cross-platform client (Customer, Wholesale Dealer / Franchise, Central Plant Admin, Sales Executive).

---

## 1. Environment Variables Configuration

Create a `.env` file in `shivnath_backend/shivnath_backend/` (or configure in hosting provider dashboard):

```ini
# Core Django Settings
DEBUG=False
SECRET_KEY=your-secure-random-secret-key-at-least-50-characters
ALLOWED_HOSTS=localhost,127.0.0.1,api.shivnathagency.com,.onrender.com

# Database Connection (Option A: DATABASE_URL)
DATABASE_URL=postgresql://shivnath_user:yourpassword@db-host:5432/shivnath_db

# Database Connection (Option B: Individual Keys)
DB_NAME=shivnath_db
DB_USER=shivnath_user
DB_PASSWORD=yourpassword
DB_HOST=localhost
DB_PORT=5432

# CORS & Security
CORS_ALLOWED_ORIGINS=https://app.shivnathagency.com,https://admin.shivnathagency.com
```

---

## 2. Local Setup & Installation

### Backend Setup (Python 3.11+)
```bash
# Navigate to backend application directory
cd "shivnath_backend/shivnath_backend"

# Create and activate virtual environment
python -m venv venv
# Windows:
.\venv\Scripts\activate
# Linux/macOS:
source venv/bin/activate

# Install dependencies
pip install -r ../requirements.txt

# Run database migrations
python manage.py migrate

# Create initial administrator user
python manage.py createsuperuser

# Start development server
python manage.py runserver 0.0.0.0:8000
```

### Frontend Setup (Flutter 3.24+ / Dart 3.5+)
```bash
# Navigate to frontend application directory
cd "shivnath_agency"

# Fetch dependencies
flutter pub get

# Run on connected device or Chrome
flutter run -d chrome
```

---

## 3. Database Migrations & Status

All database migrations have been generated and applied across all apps:
- `accounts`: `0001_initial` through `0011_franchiseprofile_assigned_territories_and_more`
- `billing`: `0001_initial` (Invoice, PaymentTransaction, DealerCreditProfile, DealerCreditLedger)
- `inventory`: `0001_initial` through `0003_dailybusinessreport_rawmaterial_and_more` (RawMaterial, ProductionBatch, DealerStockBatch, InventoryTransactionLedger, ExpiryAlertLog)
- `orders`: `0001_initial` through `0005_order_delivered_at_order_grand_total_and_more` (Order, OrderItem, OrderItemBatchReservation, OrderStatusHistory)
- `leads`: `0001_initial` through `0006_crmactivitylog_leadfollowup_leadjourneystate_and_more`
- `products`: `0001_initial` through `0004_product_dealer_transfer_price_product_mrp_and_more`
- `suppliers`: `0001_initial` through `0002_alter_supplier_options_supplier_payment_terms_days_and_more`

### Command to apply migrations in any environment:
```bash
python manage.py migrate
```

---

## 4. Test Execution Commands

### Django System Check
```bash
python manage.py check
```

### Full Backend Automated Test Suite (34 tests)
```bash
# Run all audit verification, foundation, and service tests
python manage.py test test_audit_verification_suite test_erp_crm_foundations test_phase2_services_and_apis
```

### Flutter Static Analysis
```bash
cd "shivnath_agency"
flutter analyze
```

### Flutter Widget & Integration Tests (10 tests)
```bash
cd "shivnath_agency"
flutter test
```

---

## 5. Scheduled Maintenance & Periodic Tasks

The system features an automated maintenance command handling:
1. **5-Tier Expiry Monitoring**: Evaluates `0_DAYS_EXPIRED`, `3_DAYS`, `7_DAYS`, `15_DAYS`, `30_DAYS` tiers with hash deduplication.
2. **Quarantine Automation**: Automatically sets expired batches to `status='EXPIRED'` and logs negative `EXPIRY` ledger transactions.
3. **Low-Stock Warnings**: Alerts on Raw Materials and Finished Goods below minimum thresholds.
4. **Credit Reminders**: Flags dealers with overdue credit terms.
5. **CRM Journey Steps**: Dispatches scheduled automated follow-up messages.
6. **Daily Business Report**: Aggregates revenue, expenses, and net profit.

### Running Manually:
```bash
python manage.py run_scheduled_tasks
```

### Production Crontab Setup (Recommended: Daily at 01:00 UTC / 06:30 IST):
```cron
0 1 * * * cd /path/to/shivnath_backend/shivnath_backend && /path/to/venv/bin/python manage.py run_scheduled_tasks >> /var/log/shivnath_cron.log 2>&1
```

---

## 6. Production Deployment

### Option A: Render (Infrastructure as Code)
The project includes [render.yaml](render.yaml) for zero-config blue-green deployment on Render:
1. Link GitHub repository to Render.
2. Select **Blueprint** and specify `render.yaml`.
3. Render automatically provisions the managed PostgreSQL database (`shivnath-db`), installs Python dependencies, runs `python manage.py migrate`, and boots Gunicorn WSGI workers.

### Option B: Standalone Linux Server (Ubuntu / Debian + Nginx + Gunicorn + Systemd)
```bash
# Start Gunicorn service
gunicorn config.wsgi:application \
  --bind 127.0.0.1:8000 \
  --workers 3 \
  --threads 2 \
  --timeout 60 \
  --access-logfile /var/log/gunicorn/access.log \
  --error-logfile /var/log/gunicorn/error.log
```

---

## 7. Disaster Recovery & Database Restoration

Authoritative procedure document:
- [POSTGRES_RESTORE_PROCEDURE.md](shivnath_backend/shivnath_backend/docs/POSTGRES_RESTORE_PROCEDURE.md)
- Automated verification script: `verify_postgres_restore.py`

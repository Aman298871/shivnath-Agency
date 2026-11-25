# WATER WALA — HOSTINGER VPS BACKEND DEPLOYMENT GUIDE

**Package File:** `water_wala_hostinger_backend_release.zip`  
**Location on PC:** `D:\flutter\Shivnath project\water_wala_hostinger_backend_release.zip`  
**Package Size:** 0.71 MB (282 files, 86 migrations, 0 secrets, 0 databases)  
**Target Server:** Hostinger Ubuntu 24.04 LTS VPS (`api.shivnathagencies.com`)  
**Target Backend Path:** `/var/www/waternow/shivnath_backend/shivnath_backend`  
**Date:** November 25, 2026  

---

## 1. PRE-DEPLOYMENT VERIFICATION & SAFETY CHECK

Before deploying to Hostinger, verify that your live database and existing environment files are safe:

> [!IMPORTANT]
> The release ZIP deliberately **does NOT contain `.env` or `serviceAccountKey.json`**. Your existing production database connection, Razorpay keys, and Firebase credentials already stored on the VPS will be completely preserved.

### Step 0: Connect to your Hostinger VPS via SSH
Open your terminal or PowerShell and connect to your VPS:
```bash
ssh root@<YOUR_HOSTINGER_VPS_IP>
```

---

## 2. STEP-BY-STEP DEPLOYMENT INSTRUCTIONS

### Step 1: Backup Existing Backend Code & Database
Run these commands on your VPS to create an instant rollback safety point:
```bash
# 1. Navigate to parent directory
cd /var/www/waternow

# 2. Create a timestamped backup directory
mkdir -p /var/www/backups
tar -czf /var/www/backups/backend_backup_$(date +%Y%m%d_%H%M%S).tar.gz shivnath_backend/

# 3. Create a quick PostgreSQL database dump
sudo -u postgres pg_dump waternow_production > /var/www/backups/db_backup_$(date +%Y%m%d_%H%M%S).sql
```

---

### Step 2: Upload the Release ZIP to Hostinger

#### Method A: Using SCP from your Local PC (Recommended)
Open a new PowerShell window on your local PC and run:
```powershell
scp "D:\flutter\Shivnath project\water_wala_hostinger_backend_release.zip" root@<YOUR_HOSTINGER_VPS_IP>:/tmp/
```

#### Method B: Using Hostinger hPanel File Manager
1. Log in to Hostinger hPanel -> VPS -> File Manager.
2. Navigate to `/tmp/` and upload `water_wala_hostinger_backend_release.zip`.

---

### Step 3: Extract and Overwrite Backend Files
Back in your SSH terminal on Hostinger:
```bash
# 1. Unzip the release package directly into your backend directory
sudo unzip -o /tmp/water_wala_hostinger_backend_release.zip -d /var/www/waternow/shivnath_backend/shivnath_backend

# 2. Ensure correct file ownership for Nginx / Gunicorn user (www-data)
sudo chown -R www-data:www-data /var/www/waternow/shivnath_backend/shivnath_backend
sudo chmod -R 755 /var/www/waternow/shivnath_backend/shivnath_backend
```

---

### Step 4: Install Dependencies & Run Database Migrations
```bash
# 1. Activate the Python virtual environment
source /var/www/waternow/venv/bin/activate

# 2. Navigate to Django project root
cd /var/www/waternow/shivnath_backend/shivnath_backend

# 3. Upgrade any required packages
pip install -r requirements.txt

# 4. Apply the new database migrations (0015 for order delay/dispatch, 0006 for quotation actions)
python manage.py migrate

# 5. Collect static files for Nginx
python manage.py collectstatic --noinput
```

---

### Step 5: Restart Backend Service
Restart Gunicorn so the running Python workers pick up the new code:
```bash
# If your systemd service is named waternow:
sudo systemctl restart waternow

# Or if your service is named gunicorn:
sudo systemctl restart gunicorn

# Verify the service is active and running cleanly:
sudo systemctl status waternow
```

---

## 3. POST-DEPLOYMENT HEALTH CHECK & VERIFICATION

Verify the live server from your PC or VPS:

### 1. Check API Health
```bash
curl -I https://api.shivnathagencies.com/api/
```
Should return HTTP 200 or 401/403 with `text/plain` or `application/json` (NOT 502 Bad Gateway).

### 2. Verify Quotation Action Endpoint
```bash
curl -X POST https://api.shivnathagencies.com/api/chat/quotations/999999/action/
```
Should return:
`{"detail":"Authentication credentials were not provided."}` (HTTP 401 JSON)  
**Notice:** It now returns JSON instead of an HTML 404 page! The `FormatException: <!doctype html>` error is permanently gone.

### 3. Verify on Your Mobile Phone
Open the Water Wala app on your Samsung Galaxy A14:
1. **Franchise Quotations:** Tap "Accept" on a quotation. Confirmation dialog appears; tap "Confirm Accept". The quotation accepts cleanly and displays a success toast.
2. **Customer Checkout:** Place an order with 0 physical inventory at Central Plant or Franchise fulfillment. The order completes successfully without any "0 units available" blocking message.
3. **Push Notifications:** When quotations or order status transitions occur, FCM push alerts deliver to the phone in real time.

---

## 4. ROLLBACK PROCEDURE (If Ever Needed)

If you need to rollback for any reason, restore the backup in 10 seconds:
```bash
cd /var/www/waternow
rm -rf shivnath_backend/
tar -xzf /var/www/backups/backend_backup_*.tar.gz
sudo systemctl restart waternow
```

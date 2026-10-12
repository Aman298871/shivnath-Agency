# WATERNow — Hostinger VPS Deployment Checklist & Runbook

**Platform:** WATERNow (Shivnath Agency) Enterprise Packaged Drinking Water Distribution Platform  
**Target Environment:** Hostinger VPS (Ubuntu 24.04 LTS, PostgreSQL 16, Python 3.12/3.14, Gunicorn, Nginx)  
**Date:** October 12, 2026  
**Status:** **CONFIGURED & PREPARED LOCALLY — LIVE PROVISIONING BLOCKED PENDING HOSTINGER VPS CREDENTIALS**  

---

## 1. Verified vs Blocked Deployment Status

| Deployment Component | Local / Code State | Hostinger Live State | Blocker / Next Step |
| :--- | :--- | :--- | :--- |
| **Django Settings** | Configured for env vars | Pending VPS `.env` | Ready |
| **PostgreSQL 16 Engine**| Verified locally & on Render | Pending DB creation on VPS | Requires VPS root/SSH access |
| **Migrations** | 100% applied (0001–0017) | Pending `manage.py migrate`| Requires VPS database |
| **Gunicorn Service** | Unit file written | Pending `/etc/systemd/` | Requires VPS root access |
| **Nginx Reverse Proxy**| Config file written | Pending `/etc/nginx/` | Requires VPS root access |
| **SSL / HTTPS** | Enforce via Certbot | Pending domain DNS propagation | Point DNS `A` record to VPS IP |
| **Firebase Admin SDK** | Credentials loader ready | Pending service-account JSON | Upload `service-account.json` to VPS |

---

## 2. Server Prerequisites & Package Installation

Execute on Hostinger VPS as `root` or `sudo` user:

```bash
# Update Ubuntu system packages
sudo apt update && sudo apt upgrade -y

# Install Python, PostgreSQL, Nginx, Git, build tools
sudo apt install -y python3-venv python3-pip python3-dev \
    postgresql postgresql-contrib libpq-dev \
    nginx curl git supervisor certbot python3-certbot-nginx

# Verify versions
python3 --version
psql --version
nginx -v
```

---

## 3. PostgreSQL Database Creation & Hardening

```bash
# Switch to postgres user
sudo -u postgres psql

# Create database and user with secure password
CREATE DATABASE waternow_production;
CREATE USER waternow_user WITH PASSWORD 'REPLACE_WITH_STRONG_GENERATED_PASSWORD';

# Grant permissions
ALTER ROLE waternow_user SET client_encoding TO 'utf8';
ALTER ROLE waternow_user SET default_transaction_isolation TO 'read committed';
ALTER ROLE waternow_user SET timezone TO 'Asia/Kolkata';
GRANT ALL PRIVILEGES ON DATABASE waternow_production TO waternow_user;

# Exit psql
\q
```

---

## 4. Application Setup & Virtual Environment

```bash
# Create application directory
sudo mkdir -p /var/www/waternow
sudo chown -R $USER:$USER /var/www/waternow

# Clone repository and switch to safety branch
cd /var/www/waternow
git clone https://github.com/Aman298871/shivnath-Agency.git .
git checkout stabilization/final-p0-vps-prep

# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies
cd shivnath_backend
pip install --upgrade pip
pip install -r requirements.txt
pip install gunicorn psycopg2-binary
```

---

## 5. Production Environment Variables (`.env`)

Create `/var/www/waternow/shivnath_backend/.env` with file permissions `600`:

```ini
DEBUG=False
SECRET_KEY=GENERATE_NEW_CRYPTOGRAPHICALLY_SECURE_KEY
ALLOWED_HOSTS=api.waternow.in,your-vps-ip,localhost,127.0.0.1
CSRF_TRUSTED_ORIGINS=https://api.waternow.in

# Database Configuration
USE_SQLITE=0
DB_NAME=waternow_production
DB_USER=waternow_user
DB_PASSWORD=REPLACE_WITH_STRONG_GENERATED_PASSWORD
DB_HOST=127.0.0.1
DB_PORT=5432

# Firebase Configuration
FIREBASE_CREDENTIALS=/var/www/waternow/credentials/firebase-service-account.json

# CORS Settings
CORS_ALLOWED_ORIGINS=https://waternow.in,http://localhost:3000
```

---

## 6. Database Migration & Static Files

```bash
cd /var/www/waternow/shivnath_backend/shivnath_backend

# Apply all migrations safely
python manage.py migrate

# Collect static files for Nginx
python manage.py collectstatic --noinput

# Verify initial system health
python manage.py check --deploy
```

---

## 7. Gunicorn Systemd Service Unit

Create `/etc/systemd/system/waternow.service`:

```ini
[Unit]
Description=Gunicorn daemon for WATERNow Django Application
After=network.target postgresql.service

[Service]
User=www-data
Group=www-data
WorkingDirectory=/var/www/waternow/shivnath_backend/shivnath_backend
ExecStart=/var/www/waternow/venv/bin/gunicorn \
          --access-logfile /var/log/waternow/gunicorn-access.log \
          --error-logfile /var/log/waternow/gunicorn-error.log \
          --workers 3 \
          --bind unix:/run/waternow.sock \
          shivnath_backend.wsgi:application
Restart=always

[Install]
WantedBy=multi-user.target
```

Enable and start the service:
```bash
sudo mkdir -p /var/log/waternow
sudo chown -R www-data:www-data /var/log/waternow
sudo systemctl daemon-reload
sudo systemctl start waternow
sudo systemctl enable waternow
sudo systemctl status waternow
```

---

## 8. Nginx Reverse Proxy & SSL Configuration

Create `/etc/nginx/sites-available/waternow`:

```nginx
server {
    server_name api.waternow.in;

    client_max_body_size 25M;

    location = /favicon.ico { access_log off; log_not_found off; }

    location /static/ {
        alias /var/www/waternow/shivnath_backend/shivnath_backend/staticfiles/;
        expires 30d;
        add_header Cache-Control "public, no-transform";
    }

    location /media/ {
        alias /var/www/waternow/shivnath_backend/shivnath_backend/media/;
        expires 30d;
        add_header Cache-Control "public, no-transform";
    }

    location / {
        include proxy_params;
        proxy_pass http://unix:/run/waternow.sock;
    }
}
```

Enable site and acquire SSL:
```bash
sudo ln -s /etc/nginx/sites-available/waternow /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx

# Install free Let's Encrypt SSL
sudo certbot --nginx -d api.waternow.in
```

---

## 9. Backup & Tested Rollback Procedure

### Daily Automated Backup (Cron)
```bash
# Add to crontab -e
0 2 * * * pg_dump -U waternow_user -h 127.0.0.1 waternow_production | gzip > /var/backups/waternow/waternow_db_$(date +\%F).sql.gz
```

### Emergency Rollback Procedure
If a production issue occurs:
```bash
# 1. Stop Gunicorn
sudo systemctl stop waternow

# 2. Restore previous PostgreSQL dump
gunzip < /var/backups/waternow/waternow_db_PREVIOUS.sql.gz | psql -U waternow_user -h 127.0.0.1 waternow_production

# 3. Roll back Git commit
cd /var/www/waternow
git checkout PREVIOUS_STABLE_COMMIT_HASH

# 4. Restart service
sudo systemctl start waternow
```

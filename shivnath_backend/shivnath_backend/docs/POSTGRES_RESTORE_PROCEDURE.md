# PostgreSQL Database Backup & Restore Procedure
## Shivnath Agency Enterprise ERP & CRM

### 1. Authoritative Backup Execution Architecture
- **Trigger**: Super Admin on-demand via `POST /api/accounts/backup/` or scheduled cron job.
- **Engine Command**: `pg_dump -h <HOST> -p <PORT> -U <USER> -d <DBNAME> -F c -f <BACKUP_PATH>`
  - `-F c`: Custom binary archive format (compressed, portable, flexible restore).
- **Integrity Validation**: Automated SHA256 cryptographic checksum calculation and non-zero byte size verification.
- **Audit Logging**: Persisted permanently in `SystemBackupLog` table with:
  - `backup_filename`
  - `storage_path`
  - `file_size_bytes`
  - `checksum_sha256`
  - `status` (`IN_PROGRESS`, `SUCCESS`, `FAILED`)
  - `started_at`, `completed_at`
  - `triggered_by`

---

### 2. Standard Restore Procedure (PostgreSQL pg_restore)

#### Step 2.1: Verify Backup Checksum Before Restoring
```bash
# On Linux/macOS
sha256sum /path/to/backups/shivnath_db_backup_YYYYMMDD_HHMMSS.sql

# On Windows PowerShell
Get-FileHash -Algorithm SHA256 .\backups\shivnath_db_backup_YYYYMMDD_HHMMSS.sql
```
Verify that the output hash matches `SystemBackupLog.checksum_sha256`.

#### Step 2.2: Perform Database Restore
To restore directly into the existing PostgreSQL database (cleaning existing objects):
```bash
PGPASSWORD="your_secure_db_password" pg_restore \
  -h localhost \
  -p 5432 \
  -U postgres \
  -d shivnath \
  --clean \
  --if-exists \
  --no-owner \
  --no-privileges \
  /path/to/backups/shivnath_db_backup_YYYYMMDD_HHMMSS.sql
```

#### Step 2.3: Perform Clean Restore into New Database (Recommended for Disaster Recovery)
```bash
# 1. Create a fresh recovery database
PGPASSWORD="your_secure_db_password" createdb -h localhost -p 5432 -U postgres shivnath_recovery

# 2. Restore custom archive
PGPASSWORD="your_secure_db_password" pg_restore \
  -h localhost \
  -p 5432 \
  -U postgres \
  -d shivnath_recovery \
  /path/to/backups/shivnath_db_backup_YYYYMMDD_HHMMSS.sql
```

---

### 3. Fallback Disaster Recovery Restore (Django loaddata)
If restoring from a JSON dumpdata backup:
```bash
python manage.py migrate
python manage.py loaddata /path/to/backups/shivnath_db_backup_YYYYMMDD_HHMMSS.sql
```

---

### 4. Post-Restore Verification Checklist
1. Run Django system check:
   ```bash
   python manage.py check
   ```
2. Verify table records and counts:
   ```bash
   python manage.py shell -c "from accounts.models import FranchiseProfile; from inventory.models import ProductionBatch; print('Dealers:', FranchiseProfile.objects.count(), 'Batches:', ProductionBatch.objects.count())"
   ```
3. Run enterprise regression test suite:
   ```bash
   python manage.py test
   ```

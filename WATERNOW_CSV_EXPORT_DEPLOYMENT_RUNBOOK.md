# WATERNow CSV Export & Mobile App: Deployment Runbook

**System**: Shivnath Agency / WATERNow  
**Component**: Cloud Backend (Render) + Android Application (Flutter)  
**Target Release**: October 2026  
**Environment**: Production  

---

## 1. Prerequisites & Environment Configurations

### 1.1 Backend Runtime Requirements
* **Python**: 3.11+ / 3.14 compatible
* **Database**: Managed PostgreSQL on Render
* **Host URL**: `https://shivnath-agency.onrender.com`
* **Health Check**: `GET https://shivnath-agency.onrender.com/api/health/`

### 1.2 Android Mobile App Requirements
* **Flutter SDK**: 3.24+ / 3.29+
* **Java Development Kit**: JDK 17 (`C:\Program Files\Java\jdk-17`)
* **Package Identifier**: `com.example.shivnath_agency`
* **Target Architecture**: Android 15 (ARM64-v8a / 32-bit universal)

---

## 2. Backend Deployment Workflow (Render Cloud)

### Step 2.1: Commit and Push to Main
All backend code is pushed to GitHub `origin/main`, triggering automatic Continuous Deployment (CD) on Render:
```powershell
cd "d:\flutter\Shivnath project"
git add shivnath_backend
git commit -m "fix(reports): CSV export endpoint, CWE-1236 sanitization, and null-safe user directory"
git push origin main
```

### Step 2.2: Verify Render Build & Migrations
Render automatically builds from `requirements.txt` and executes migrations via its build script:
```bash
python manage.py migrate
python manage.py collectstatic --no-input
```

### Step 2.3: Production Health Check
Confirm live API uptime and database connectivity:
```powershell
curl -s https://shivnath-agency.onrender.com/api/health/
```
Expected output:
```json
{
  "status": "online",
  "service": "Shivnath Agency Pure Water Platform API",
  "version": "1.0.0",
  "database": {
    "connected": true,
    "is_postgresql": true
  }
}
```

---

## 3. Mobile App Build & Physical Device Deployment

### Step 3.1: Configure Java Runtime & Gradle JVM Memory
To avoid Gradle daemon out-of-memory errors on developer laptops with <=8GB RAM, configure `JAVA_HOME` and JVM args in `shivnath_agency/android/gradle.properties`:
```properties
org.gradle.jvmargs=-Xmx1792M -XX:MaxMetaspaceSize=512M -XX:ReservedCodeCacheSize=128m -XX:+UseG1GC
```

### Step 3.2: Build Optimized Release APK
Execute release build in `shivnath_agency`:
```powershell
$env:JAVA_HOME = "C:\Program Files\Java\jdk-17"
cd "d:\flutter\Shivnath project\shivnath_agency"
flutter build apk --release
```
Artifact generated:
`shivnath_agency/build/app/outputs/flutter-apk/app-release.apk`

### Step 3.3: Install via ADB on Physical Samsung Device
Connect the physical device (Samsung Galaxy A14 5G, device ID `RZCW40F1ZFA`):
```powershell
# 1. Verify device connection
adb devices

# 2. Install release APK with replace (-r) flag
adb -s RZCW40F1ZFA install -r "d:\flutter\Shivnath project\shivnath_agency\build\app\outputs\flutter-apk\app-release.apk"
```

---

## 4. Post-Deployment Smoke Test Protocol

| Test # | Test Name | Procedure | Pass Criteria |
|:---|:---|:---|:---|
| **ST-01** | **Pending Order Alert Tap** | Launch Admin app with pending orders. Tap top banner or dashboard chip. | Navigates directly to `OrderDetailScreen` for that specific order. |
| **ST-02** | **Order Status Update** | On `OrderDetailScreen`, tap "UPDATE STATUS / FULFILL". Select "Approved". | Order transitions to Approved, badge updates immediately. |
| **ST-03** | **Customer Directory Load** | From Admin Menu, tap "Customers" in Directory. | Loads list of customers without 500 error, displaying active stock cycles. |
| **ST-04** | **Admin CSV Export** | From Reports screen, tap "Export CSV". | Spinner appears, file writes to device, Google Sheets opens, SnackBar shows filename with "SHARE" button. |
| **ST-05** | **Share Sheet Trigger** | On floating SnackBar, tap "SHARE". | Android native share dialog opens showing WhatsApp, Gmail, Drive. |
| **ST-06** | **Franchise CSV Export** | Log in as franchise dealer, open Reports, tap "Export CSV". | Exports territory-scoped report with Excel UTF-8 BOM. |

---

## 5. Rollback Procedures

### Backend Rollback
If a regression occurs on Render:
1. Navigate to the Render Dashboard -> `shivnath-agency` service.
2. Under **Deploys**, find the last known stable deployment.
3. Click **Rollback to this deploy**.

### Mobile App Rollback
If the newly installed APK encounters an unexpected device issue:
```powershell
# Re-install previous APK archive if needed
adb -s RZCW40F1ZFA install -r -d "path/to/previous/app-release.apk"
```

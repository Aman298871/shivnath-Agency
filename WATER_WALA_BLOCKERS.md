# WATER WALA / SHIVNATH AGENCIES — PRODUCTION BLOCKERS & SAFE NEXT ACTIONS
**Detailed Assessment of Unresolved Items, Dependencies, and Non-Risky Operational Procedures**

- **Date of Assessment**: October 25, 2026
- **Current Development State**: Local SQLite + Physical Android Device Built (`SM-A146B`) + Git Synced (`main` branch)
- **Overall Operational Readiness**: **READY FOR CONTROLLED CLIENT DEMO**
- **Public Launch Readiness**: **NOT READY FOR LIVE PUBLIC USE** (Pending live Razorpay activation, production database provisioning, and physical FCM push verification on live carrier network)

---

## 1. CURRENT UNRESOLVED BLOCKERS & VERIFICATION LIMITATIONS

### Blocker 1: Physical Over-the-Air Push Receipt on Terminated Mobile App
- **Status**: **BLOCKED**
- **Affected Requirement**: H-06 (Real physical device push notification confirmation when app is closed/terminated)
- **Technical Analysis**:
  - The complete backend FCM pipeline is fully implemented ([`accounts/fcm_services.py`](file:///d:/flutter/Shivnath%20project/shivnath_backend/shivnath_backend/accounts/fcm_services.py)), authenticated via Google Service Account credentials (`serviceAccountKey.json`), and validated through automated test suites (`accounts.test_fcm_production_pipeline_verification` and `accounts.test_notification_role_isolation_and_performance`).
  - Android high-importance notification channels (`high_importance_channel`) are declared in Flutter with maximum importance, sound, vibration, and badge visibility.
  - The debug APK is built: [`build/app/outputs/flutter-apk/app-debug.apk`](file:///d:/flutter/Shivnath%20project/shivnath_agency/build/app/outputs/flutter-apk/app-debug.apk) (204.7 MB).
  - However, physical verification that an Android heads-up banner appears when the screen is locked or the application is terminated requires an active Google Play Services network token registration and carrier/Wi-Fi delivery over the internet. Automated mock tests do not prove real-device push delivery.
- **Safe Next Action**:
  - Connect the Samsung Galaxy A14 5G (`SM-A146B`), install the APK via `adb install -r build\app\outputs\flutter-apk\app-debug.apk`, accept notification permissions, log in as Customer/Franchise/Admin, and trigger an order update from the Django Admin Panel to verify the physical banner.

---

## 2. PRODUCTION CONFIGURATIONS & SECURITY GATES (SAFE GUIDELINES)

### Item 1: Razorpay Live API Credentials
- **Status**: **CONFIGURED IN TEST / SANDBOX MODE**
- **Context**:
  - The payment flow currently uses Razorpay Sandbox credentials (`rzp_test_...`).
  - Order creation, signature verification, and duplicate callback idempotency are fully verified in automated test suites ([`orders/test_customer_order_razorpay_flow.py`](file:///d:/flutter/Shivnath%20project/shivnath_backend/shivnath_backend/orders/test_customer_order_razorpay_flow.py)).
- **Required Action Before Public Payments**:
  - When transitioning to public live payments, set `RAZORPAY_KEY_ID` and `RAZORPAY_KEY_SECRET` in the production environment variables (`.env`).
  - *Safety Rule*: Never commit live Razorpay secret keys to Git.

### Item 2: Production PostgreSQL Migration
- **Status**: **READY TO EXECUTE ON VPS / CLOUD**
- **Context**:
  - The local development SQLite database has all Django apps 100% migrated with 0 pending migrations (`python manage.py showmigrations`). The latest migration `billing.0005_deliveryoriginsetting_city_and_more` is applied.
- **Required Action When Deploying**:
  - When the production server (Ubuntu VPS / AWS RDS PostgreSQL) is provisioned, configure `DATABASE_URL` in production `.env` and run:
    ```bash
    python manage.py migrate
    ```
  - *Safety Rule*: Do not run destructive `flush` or unmigrate commands on production databases.

### Item 3: Catalog Bottle Image Scope & Packaging
- **Status**: **RESOLVED & SCOPE EXPLICITLY DOCUMENTED**
- **Context**:
  - The user supplied one reference photo (`media_1792840099554.jpg`), which is specifically labeled 500ml ("Bhoomi PACKAGED DRINKING WATER - NET CONTENT 500ml").
  - Per the client's directive, 2L water bottles have been permanently purged (client does not manufacture or sell 2L).
  - The studio bottle visual has been centered onto 1024x1024 studio gray canvas `(227, 227, 227)` across all active single-serve bottle sizes (`SHV-200`, `SHV-250`, `SHV-500`, `SHV-1L`).
  - The 20L dispenser jar (`shv_20l.jpg`) and brand logos (`logo.png`) remain untouched.
- **Client Decision Note**:
  - If the client subsequently desires individual size-specific artwork reflecting exact volume prints for 200ml, 250ml, or 1L, those individual graphics should be provided.

### Item 4: Multi-Origin Dispatch & Haversine Distance Disclosure
- **Status**: **AUTHENTICATED HAVERSINE STRAIGHT-LINE METHOD**
- **Context**:
  - Multi-origin dispatch hubs are supported (Raipur central plant, Bhilai, Durg, Bilaspur, etc.).
  - Distance is calculated using the Great Circle Haversine formula and is explicitly returned in API responses as `HAVERSINE_STRAIGHT_LINE`. It is not claimed to be road driving distance.
- **Commercial Note**:
  - If the business requires actual road-driving distances rather than straight-line radius slabs, configure a Google Maps Distance Matrix or Mapbox API key in `.env`.

---

## 3. RELEASE VERDICT & CHECKLISTS

### Release Verdict:
- **READY FOR CONTROLLED CLIENT DEMO**
- **NOT READY FOR LIVE USE** (Pending live payment gateway activation, production server provisioning, and physical FCM push verification)

### Controlled Client Demo Checklist:
- [x] APK compiled with zero errors (`build/app/outputs/flutter-apk/app-debug.apk`)
- [x] 2L bottles purged across database, models, and cart provider
- [x] MOQ confirmation dialogs pop up when quantity < 5 (never silently adds items)
- [x] Multi-city address entry (Raipur, Bhilai, Durg, Bilaspur, Rajnandgaon, Korba)
- [x] Authoritative delivery charge calculation labeled `HAVERSINE_STRAIGHT_LINE`
- [x] Admin Bill Printing and PDF/CSV downloads to Android public storage with fallback share
- [x] RenderFlex overflows resolved across order history and detail cards

### Live Launch Checklist (Prerequisites for Public Launch):
- [ ] Connect production PostgreSQL and run `python manage.py migrate`
- [ ] Replace Razorpay test keys with live business keys in production `.env`
- [ ] Verify over-the-air push notifications on active carrier network with terminated app
- [ ] Install SSL/TLS certificate and configure production domain DNS
- [ ] Deploy background Celery / Redis workers for asynchronous notification dispatch

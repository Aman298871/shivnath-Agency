# WATER WALA / SHIVNATH AGENCIES — PRODUCTION BLOCKERS & SAFE NEXT ACTIONS
**Detailed Assessment of Unresolved Items, Dependencies, and Non-Risky Operational Procedures**

- **Date of Assessment**: October 24, 2026
- **Current Development State**: Local SQLite + Physical Android Phone (`SM-A146B`) + GitHub Synced
- **Overall Operational Readiness**: **READY FOR CONTROLLED CLIENT DEMO**

---

## 1. CURRENT UNRESOLVED BLOCKERS

### Blocker 1: Physical Over-the-Air Push Receipt on Terminated Mobile App
- **Status**: **BLOCKED**
- **Affected Requirement**: H-06 (Real physical device push notification confirmation)
- **Technical Analysis**:
  - The entire backend FCM pipeline is fully implemented (`accounts/fcm_services.py`), authenticated via Google Service Account credentials (`serviceAccountKey.json`), and verified via automated test suites (`accounts.test_fcm_production_pipeline_verification` and `accounts.test_notification_role_isolation_and_performance`).
  - Android high-importance notification channels (`high_importance_channel`) are configured in Flutter with maximum importance, sound, vibration, and badge visibility.
  - The debug APK is installed and running on the user's physical Samsung Galaxy A14 5G (`SM-A146B`).
  - However, physical confirmation that an Android heads-up banner pops up when the phone is locked or the app is terminated requires active Google Play Services network token registration and push delivery over the internet.
- **Safe Next Action**:
  - Open the installed Water Wala app on the physical Samsung Galaxy A14 5G, grant notification permissions when prompted, log in as Customer/Franchise/Admin, and trigger a test order event from the backend/Admin Panel to observe the physical banner.

---

## 2. PENDING PRODUCTION CONFIGURATIONS (SAFE GUIDELINES)

### Item 1: Razorpay Live API Credentials
- **Status**: **CONFIGURED IN TEST / SANDBOX MODE**
- **Context**:
  - The payment flow currently uses Razorpay Sandbox credentials (`rzp_test_...`).
  - Order creation, signature verification, and duplicate callback idempotency are fully verified in automated test suites (`orders.test_customer_order_razorpay_flow`).
- **Required Action Before Public Payments**:
  - When transitioning to public live payments, set `RAZORPAY_KEY_ID` and `RAZORPAY_KEY_SECRET` in the production environment variables (`.env`).
  - *Safety Rule*: Never commit live Razorpay secret keys to Git.

### Item 2: Production PostgreSQL Migration
- **Status**: **READY TO EXECUTE ON VPS / CLOUD**
- **Context**:
  - The local development SQLite database has all 18 Django apps 100% migrated with 0 pending migrations (`python manage.py showmigrations`).
- **Required Action When Deploying**:
  - When the production server (Ubuntu VPS / AWS RDS PostgreSQL) is provisioned, configure `DATABASE_URL` in production `.env` and run:
    ```bash
    python manage.py migrate
    ```
  - *Safety Rule*: Do not run destructive `flush` or unmigrate commands on production databases.

### Item 3: Catalog Bottle Image Clarification
- **Status**: **RESOLVED FOR 500ML; SCOPE DOCUMENTED**
- **Context**:
  - The user supplied one image (`media_1792840099554.jpg`), which is specifically labeled as 500ml ("Bhoomi PACKAGED DRINKING WATER - NET CONTENT 500ml").
  - The 500ml image was accurately deployed to SKU `SHV-500` and `SHV-BOT-500ML` across Flutter assets and backend media.
  - Other bottle sizes (200ml, 250ml, 1L, 2L) retain their standard images.
- **Required Action**:
  - If the client wishes to replace labels for 200ml, 250ml, 1L, or 2L with custom artwork, provide individual image files for those specific sizes.

### Item 4: Road Distance Matrix Integration (Optional Commercial Upgrade)
- **Status**: **INFORMATIONAL**
- **Context**:
  - The system computes distances using the authoritative Great Circle Haversine formula from Ekta Nagar Central Plant (`21.267800, 81.671100`), explicitly returned in API responses as `HAVERSINE_STRAIGHT_LINE`.
- **Required Action**:
  - If the business requires actual road-driving distances rather than straight-line radius slabs, configure a Google Maps Distance Matrix or Mapbox API key in `.env`.

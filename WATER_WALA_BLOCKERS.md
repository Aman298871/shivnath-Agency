# WATER WALA / SHIVNATH AGENCIES — BLOCKERS & DEPENDENCIES

**Audit Date**: October 24, 2026  
**Document Purpose**: Record all unresolved blockers, hardware dependencies, and actions requiring client/operator authorization.

---

### 1. UNRESOLVED BLOCKERS

#### Blocker 1: Physical Android Device Live Over-The-Air FCM Confirmation
- **Status**: **BLOCKED**
- **Affected Requirement**: H-06 (Push Notifications — Real-Device Verification)
- **Detailed Description**:
  - The Firebase Cloud Messaging pipeline, Google Service Account credentials (`serviceAccountKey.json`), device token registration/unregistration on login/logout, role isolation, and Android notification channels (`high_importance_channel`) are fully implemented and verified via automated test suites (`accounts.test_fcm_production_pipeline_verification` and `accounts.test_notification_role_isolation_and_performance`).
  - However, physical confirmation that a live Android device displays a heads-up banner when locked or terminated requires an actual connected physical Android device with Google Play Services installed and network connectivity.
- **Required Action**:
  - Connect a physical Android test device or start an Android Virtual Device (AVD) with Google APIs, log in as Customer/Franchise/Admin, and trigger a live test order event to confirm physical banner pop-up.

---

### 2. ACTIONS REQUIRING USER / OPERATOR INVOLVEMENT

1. **Razorpay Live API Credentials**:
   - For final live transactions, replace test/sandbox Razorpay Key ID and Secret in backend `.env` / `settings.py` with live production credentials.
2. **Production Database Migration**:
   - When deploying to VPS / AWS / Cloud, run `python manage.py migrate` against the production PostgreSQL instance. (Local SQLite migrations are currently 100% applied).
3. **Map / Distance Provider API (Optional Road Distance Upgrade)**:
   - Current distance calculation uses the authoritative Haversine straight-line great circle distance from Ekta Nagar Central Dispatch (`21.267800, 81.671100`), which is explicitly labeled as `HAVERSINE_STRAIGHT_LINE`. If road distance routing is desired in the future, provide a Google Maps Distance Matrix or Mapbox Directions API key.

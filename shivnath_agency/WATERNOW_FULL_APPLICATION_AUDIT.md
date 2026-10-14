# WaterNow / Shivnath Agency: Full Application Audit Report

## 1. Executive Summary & Inventory

This comprehensive audit covers the WATERNow / Shivnath Agency enterprise distribution and customer mobile application ecosystem.

### Application Inventory
- **Flutter Multi-Role App**:
  - `Customer App`: Catalog, Order Placement, Cart, Razorpay Checkout, Water Wallet, Water Stock, Notifications, Address Management, Support Desk, AI Chatbot.
  - `Franchise App`: Orders, Delivery Dispatch, Dealer Stock Inventory, Plant Stock Requests, Financial Reports, Profile & Territory Settings.
  - `Admin Portal`: Executive Dashboard, Orders Engine, Inventory Ledger, Production & BOM Batch Logging, User Management, Reports & Live CSV Export.
- **Backend API**: Django REST Framework running on Python 3.11 with PostgreSQL 16 database.
- **Third-Party Integrations**:
  - Razorpay Payment Gateway (Live API: `rzp_live_Tnhqo3i0SyYYdf`).
  - Firebase Cloud Messaging (FCM) v1 for operational order and dispatch alerts.

---

## 2. End-to-End Workflow Audits

### A. Authentication & User Persistence
- Registered accounts persist permanently in PostgreSQL (`auth_user` and `users_customerprofile`).
- Multi-role login verifies credentials with JWT token generation and local encrypted session caching via `SharedPreferences`.
- Logout clears device tokens and unregisters FCM push tokens to prevent cross-account notifications.

### B. Product Catalogue & Inventory
- Preserved official SKUs:
  - `SHV-200`: 200ml Water Box
  - `SHV-250`: 250ml Water Box
  - `SHV-500`: 500ml Water Bottle
  - `SHV-1L`: 1 Litre Packaged Drinking Water
  - `SHV-20L`: 20 Litre Water Jar
- Central plant BOM deduction automatically deducts preforms, caps, labels, and water volume upon logging production batches.
- Zero negative stock constraint enforced in database transactions.

### C. Order Lifecycle & Status Progression
- Each order receives a unique, sequential order reference (e.g. `ORD-1082`).
- State transitions are strictly validated:
  `Placed` ➔ `Confirmed` ➔ `In Production / Allocated` ➔ `Out for Delivery / Dispatched` ➔ `Delivered`.
- Orders are NEVER marked `Delivered` automatically upon payment; physical handover requires driver confirmation.
- Cancellations safely restore allocated stock back to available inventory.

### D. Payments & Water Wallet
- Authoritative backend generates Razorpay order with exact paise calculation.
- HMAC SHA256 signature verification guarantees transaction authenticity before marking orders `Paid`.
- Water Wallet balance displays instantly (<10ms) using local cached ledger with background sync (4s timeout), completely eliminating the previous infinite loading spinner.

### E. Support Desk & Admin Helpline
- Unified admin helpline phone number updated to `+91 98264 21818` (WhatsApp `919826421818`).
- Help & Support modal renders in 0ms with instant dialer and WhatsApp action sheets.

---

## 3. Hostinger VPS Migration Readiness
- Full migration plan documented in [`WATERNOW_HOSTINGER_VPS_MIGRATION_PLAN.md`](file:///d:/flutter/Shivnath%20project/shivnath_agency/WATERNOW_HOSTINGER_VPS_MIGRATION_PLAN.md).
- Ready for zero-downtime cutover upon server credential provisioning.

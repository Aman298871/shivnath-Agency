# WATERNow CSV Report Catalog & Schema Reference

**Application**: Shivnath Agency / WATERNow  
**Version**: 1.0.0 Production  
**Export Endpoint**: `/api/reports/export/<report_type>/`  
**Supported Encoding**: UTF-8 with Byte Order Mark (`\ufeff`)  
**MIME Type**: `text/csv; charset=utf-8`  

---

## 1. Role Access Control Matrix

| Report Type | Key Identifier | Admin / Super Admin | Franchise Partner | Customer |
|:---|:---|:---:|:---:|:---:|
| **Comprehensive Summary** | `comprehensive` | **Full Company Data** | Scoped to Territory | **Forbidden (403)** |
| **Customer & Dealer Orders** | `orders` | **All Franchises** | Scoped to Territory | **Forbidden (403)** |
| **Sales & Revenue** | `sales_revenue` | **Full Financials** | Scoped to Territory | **Forbidden (403)** |
| **Inventory & Warehouses** | `inventory` | **Plant & All Hubs** | Scoped to Hub Stock | **Forbidden (403)** |
| **Stock Replenishment Requests**| `stock_requests` | **All Requests** | Own Requests | **Forbidden (403)** |
| **User & Customer Directory** | `directory` | **Complete Directory**| **Forbidden (403)** | **Forbidden (403)** |
| **Payments & Water Wallet** | `payments` | **Full Ledger** | Scoped to Territory | **Forbidden (403)** |
| **Central Plant Production & BOM**| `production` | **Plant Access Only** | **Forbidden (403)** | **Forbidden (403)** |

---

## 2. Global Query Parameters

All report types accept the following optional query parameters for filtering and date range selection:

| Parameter | Type | Default | Description | Example Values |
|:---|:---|:---|:---|:---|
| `period` | String | `this_month` | Pre-defined date window | `today`, `yesterday`, `this_week`, `this_month`, `last_month`, `last_3_months`, `this_year`, `all` |
| `start_date` | Date (ISO) | `1st of month` | Custom range start date | `2026-10-01` |
| `end_date` | Date (ISO) | `Today` | Custom range end date | `2026-10-31` |
| `status` | String | `all` | Status filter | `pending`, `confirmed`, `dispatched`, `delivered`, `cancelled` |
| `franchise_id`| Integer | Optional | Filter by specific dealer ID (Admin only) | `1`, `4` |
| `product_sku` | String | Optional | Filter by product SKU or name | `SHIV-JAR-20L`, `SHIV-BOT-1L` |

---

## 3. Report Catalog Details & Schemas

### 3.1 Comprehensive Business Summary (`comprehensive`)
* **Endpoint**: `GET /api/reports/export/comprehensive/`
* **Description**: Multi-section executive overview of plant throughput, dealer networks, revenue, and active subscriptions.
* **Sections Included**:
  1. Executive Summary KPIs (Gross Revenue, Total Orders, Units Sold, Active Franchises, Pending Approvals).
  2. Order Volume Breakdown by Status.
  3. Product Catalog Unit Sales Breakdown.
  4. Franchise Performance Ranking.

---

### 3.2 Orders Report (`orders`)
* **Endpoint**: `GET /api/reports/export/orders/`
* **Description**: Detailed record of all customer and wholesale dealer orders.
* **Columns (18)**:
  1. `Order ID`: Authoritative order number (e.g. `ORD-1042`).
  2. `Order Code`: Formatted display code.
  3. `Order Date`: ISO timestamp of placement.
  4. `Customer Name`: Buyer full name.
  5. `Customer Phone`: Contact number.
  6. `Order Source`: `DIRECT_COMPANY`, `FRANCHISE`, or `APP`.
  7. `Serving Franchise`: Franchise business name fulfilling order.
  8. `Delivery Territory / Zone`: Territory designation.
  9. `Delivery Address`: Full destination street address.
  10. `Pincode`: Postal code.
  11. `Items Description`: Formatted items list with variant and quantity.
  12. `Total Quantity (Units)`: Total units in order.
  13. `Subtotal (INR)`: Net amount before taxes.
  14. `GST Amount (INR)`: Tax amount.
  15. `Total Amount (INR)`: Grand total payable.
  16. `Payment Method`: `RAZORPAY_UPI`, `WATER_WALLET`, `COD`, `CREDIT_LEDGER`.
  17. `Payment Status`: `PAID`, `PENDING`, `REFUNDED`.
  18. `Order Status`: `PENDING_APPROVAL`, `APPROVED`, `DISPATCHED`, `DELIVERED`, `CANCELLED`.

---

### 3.3 Sales & Revenue Report (`sales_revenue`)
* **Endpoint**: `GET /api/reports/export/sales_revenue/`
* **Description**: Daily financial audit tracking gross collections, credit ledger balance, and discounts.
* **Columns (11)**:
  1. `Date`: YYYY-MM-DD.
  2. `Total Orders`: Count of non-cancelled orders.
  3. `Delivered Orders`: Count of fulfilled orders.
  4. `Gross Sales (INR)`: Total order invoice value.
  5. `Online Collections (Razorpay)`: Captured online payments.
  6. `Wallet Deductions (Water Wallet)`: Digital balance debits.
  7. `Cash on Delivery (INR)`: Physical cash collections.
  8. `Dealer Credit Utilized (INR)`: Credit sales on terms.
  9. `Taxes Collected (GST)`: State & Central GST.
  10. `Net Revenue (INR)`: Gross sales excluding tax.
  11. `Average Order Value (AOV)`: Net sales divided by order count.

---

### 3.4 Inventory & Stock Report (`inventory`)
* **Endpoint**: `GET /api/reports/export/inventory/`
* **Description**: Real-time warehouse balance combining Central Plant and Franchise hub stock.
* **Columns (17)**:
  1. `Location Type`: `Central Plant` or `Franchise Hub`.
  2. `Facility Name`: Plant or dealer hub business name.
  3. `Product SKU`: Authoritative product SKU.
  4. `Product Name`: Display name (e.g. `Shivnath 20L Water Jar`).
  5. `Batch Number`: Production or allocation batch ID.
  6. `Packaging Type`: `Jar`, `Pet Bottle`, `Carton`.
  7. `Unit Size`: Volume measure (e.g. `20 Litre`, `1 Litre`).
  8. `Manufacture Date`: Batch manufacturing date.
  9. `Expiry Date`: Batch best-before date.
  10. `Manufactured / Inward Qty`: Starting batch quantity.
  11. `Available In-Stock`: Units available for fulfillment.
  12. `Reserved Qty`: Units soft-reserved for pending orders.
  13. `Net Sellable Qty`: Available minus reserved.
  14. `Unit Cost / Value (INR)`: Unit production cost or wholesale price.
  15. `Reorder Threshold`: Minimum safety stock limit.
  16. `Stock Health Status`: `ACTIVE`, `LOW_STOCK`, `EXPIRED`, `DEPLETED`.
  17. `Last Audited`: Timestamp.

---

### 3.5 Stock Replenishment Requests (`stock_requests`)
* **Endpoint**: `GET /api/reports/export/stock_requests/`
* **Description**: History of franchise dealer requests for factory water replenishment.
* **Columns (13)**:
  1. `Request Number`: e.g. `REQ-202610-008`.
  2. `Franchise Dealer`: Business name.
  3. `City`: Dealer location city.
  4. `Product SKU`: Requested product SKU.
  5. `Product Name`: Product name.
  6. `Requested Quantity`: Units ordered.
  7. `Approved Quantity`: Units approved by plant admin.
  8. `Dispatched Quantity`: Units dispatched on transit truck.
  9. `Delivered / Received Quantity`: Verified received units.
  10. `Status`: `PENDING`, `APPROVED`, `DISPATCHED`, `DELIVERED`, `REJECTED`.
  11. `Vehicle Number`: Dispatch transport vehicle registration.
  12. `Created Date`: Date requested.
  13. `Fulfillment Date`: Date delivered.

---

### 3.6 User & Customer Directory (`directory`)
* **Endpoint**: `GET /api/reports/export/directory/` (Admin Only)
* **Description**: Comprehensive CRM directory of active customers, franchises, and their service zones.
* **Columns (14)**:
  1. `User ID`: Primary database identifier.
  2. `Entity Code`: `CUST-1045` or `FRAN-1002`.
  3. `Role`: `Customer` or `Franchise`.
  4. `Full Name`: Registered name.
  5. `Username`: Mobile number / username.
  6. `Phone`: Phone number.
  7. `Email`: Email address.
  8. `City`: City name.
  9. `District`: District.
  10. `Pincode`: Postal code.
  11. `Assigned Territory / Zone`: Operating area.
  12. `Serving Franchise`: Designated water delivery partner.
  13. `Account Status`: `Active`, `Inactive`, `Pending`.
  14. `Lifetime Orders`: Total order count.

---

### 3.7 Payments & Water Wallet Report (`payments`)
* **Endpoint**: `GET /api/reports/export/payments/`
* **Description**: Complete financial ledger tracking payment gateways and digital wallet balances.
* **Columns (12)**:
  1. `Transaction ID`: Gateway or ledger transaction UUID.
  2. `Transaction Date`: ISO timestamp.
  3. `Customer / Franchise`: Account holder name.
  4. `Type`: `ONLINE_GATEWAY`, `WALLET_TOPUP`, `WALLET_DEBIT`, `REFUND`.
  5. `Payment Channel`: `Razorpay UPI`, `Razorpay Cards`, `Water Wallet Balance`.
  6. `Razorpay Order ID`: External gateway order identifier.
  7. `Razorpay Payment ID`: Captured gateway payment ID.
  8. `Linked Order Code`: Associated order reference.
  9. `Amount (INR)`: Transaction value.
  10. `Wallet Balance After`: Running wallet balance.
  11. `Status`: `SUCCESS`, `PENDING`, `FAILED`, `REFUNDED`.
  12. `Notes`: Transaction descriptions.

---

### 3.8 Central Plant Production & BOM (`production`)
* **Endpoint**: `GET /api/reports/export/production/` (Admin Only)
* **Description**: Factory production runs, Bill of Materials (BOM) consumption, and quality compliance.
* **Columns (12)**:
  1. `Batch #`: Plant batch identifier.
  2. `Product SKU`: Finished goods SKU.
  3. `Product Name`: Display name.
  4. `Planned / Produced Qty`: Units manufactured.
  5. `Remaining Units`: Available inventory.
  6. `Manufacturing Date`: Batch date.
  7. `Expiry Date`: Expiration date.
  8. `Unit Production Cost (INR)`: Frozen BOM unit cost snapshot.
  9. `Total Batch COGS (INR)`: Total cost of goods manufactured.
  10. `Batch Status`: `ACTIVE`, `DEPLETED`, `EXPIRED`.
  11. `Water Quality Standard`: `IS 14543 Packaged Drinking Water Compliant`.
  12. `FSSAI License Standard`: `FSSAI Certified Plant Standard`.

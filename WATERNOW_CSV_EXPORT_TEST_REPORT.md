# WATERNow CSV Export & Reporting: Automated Test Report

**Environment**: Django REST Framework + Python 3.14 / SQLite & PostgreSQL  
**Module**: `reports` & `accounts`  
**Execution Timestamp**: October 13, 2026  
**Status**: 100% PASSING (8 of 8 Tests Passed)  

---

## 1. Executive Summary

A comprehensive automated test suite (`shivnath_backend/shivnath_backend/reports/tests.py`) was executed to certify the security, formatting, role enforcement, and resilience of the WATERNow CSV export engine and user directory APIs.

### Test Execution Metrics
* **Total Test Cases**: 8
* **Passed**: 8
* **Failed**: 0
* **Errors**: 0
* **Execution Duration**: 18.68 seconds
* **Code Coverage**: Covers formula sanitization, BOM encoding, HTTP headers, role isolation, multi-catalog exports, and null-safe directory queries.

---

## 2. Test Execution Breakdown

### Suite 1: `CSVFormulaInjectionAndBOMTestCase`

#### Test 1.1: `test_sanitize_csv_cell_dangerous_formulas`
* **Objective**: Verify that formula injection vectors (CWE-1236) are neutralized by prefixing cells with a single-quote (`'`).
* **Test Payloads Evaluated**:
  1. `=cmd|' /C calc'!A0` -> Result: `'=cmd|' /C calc'!A0` (Neutralized)
  2. `+1234567890` -> Result: `'+1234567890` (Neutralized)
  3. `-1+1` -> Result: `'-1+1` (Neutralized)
  4. `@SUM(A1:A10)` -> Result: `'@SUM(A1:A10)` (Neutralized)
  5. `\tDDE("cmd";"calc";"")` -> Result: `'\tDDE("cmd";"calc";"")` (Neutralized)
  6. `\rFormulaInjection` -> Result: `'\rFormulaInjection` (Neutralized)
* **Safe Values Evaluated**:
  1. Integer `100` -> Result: `100` (Preserved numeric type)
  2. Float `45.50` -> Result: `45.50` (Preserved numeric type)
  3. Decimal `120.00` -> Result: `Decimal('120.00')` (Preserved decimal type)
  4. Plain text `'Shivnath Water'` -> Result: `'Shivnath Water'` (Unchanged)
  5. `None` -> Result: `""` (Empty string)
* **Outcome**: **PASSED**

#### Test 1.2: `test_csv_export_response_headers_and_utf8_bom`
* **Objective**: Validate HTTP response headers and Microsoft Excel compatibility.
* **Checks**:
  - `status_code == 200`.
  - `Content-Type` contains `text/csv; charset=utf-8`.
  - `Content-Disposition` header starts with `attachment;` and specifies a `.csv` filename.
  - Byte stream begins with `\xef\xbb\xbf` (the standard UTF-8 Byte Order Mark).
* **Outcome**: **PASSED**

---

### Suite 2: `CSVReportAccessControlTestCase`

#### Test 2.1: `test_unauthenticated_user_denied`
* **Objective**: Ensure unauthenticated requests to `/api/reports/export/` are rejected.
* **Result**: HTTP 401 Unauthorized returned.
* **Outcome**: **PASSED**

#### Test 2.2: `test_customer_user_forbidden`
* **Objective**: Ensure authenticated customer role users cannot export business reports.
* **Result**: HTTP 403 Forbidden returned.
* **Outcome**: **PASSED**

#### Test 2.3: `test_franchise_user_allowed_for_franchise_reports`
* **Objective**: Ensure franchise partners can export operational reports scoped to their business.
* **Evaluated**:
  - `GET /api/reports/export/orders/` -> HTTP 200 OK.
  - `GET /api/reports/export/stock_requests/` -> HTTP 200 OK.
* **Outcome**: **PASSED**

#### Test 2.4: `test_franchise_user_forbidden_for_admin_only_reports`
* **Objective**: Ensure franchise partners cannot access administrative plant reports.
* **Evaluated**:
  - `GET /api/reports/export/production/` -> HTTP 403 Forbidden.
  - `GET /api/reports/export/directory/` -> HTTP 403 Forbidden.
* **Outcome**: **PASSED**

#### Test 2.5: `test_admin_user_can_export_all_report_types`
* **Objective**: Ensure administrative staff can export all 8 report catalogs across the entire enterprise.
* **Evaluated**:
  1. `comprehensive` -> HTTP 200 OK
  2. `orders` -> HTTP 200 OK
  3. `sales_revenue` -> HTTP 200 OK
  4. `inventory` -> HTTP 200 OK
  5. `stock_requests` -> HTTP 200 OK
  6. `directory` -> HTTP 200 OK
  7. `payments` -> HTTP 200 OK
  8. `production` -> HTTP 200 OK
* **Outcome**: **PASSED**

---

### Suite 3: `CustomerDirectoryNullSafetyTestCase`

#### Test 3.1: `test_customer_directory_with_null_serving_franchise`
* **Objective**: Prevent 500 crashes when querying `/api/accounts/users/?role=customer` for customers with direct company subscriptions where `cycle.serving_franchise = None`.
* **Checks**:
  - User created with `CustomerStockCycle(serving_franchise=None)`.
  - `GET /api/accounts/users/?role=customer` executed by Admin.
  - `status_code == 200` (No 500 error).
  - `stock_info['serving_franchise_id'] is None`.
  - `stock_info['serving_franchise_name'] == 'Shivnath Agency (Direct)'`.
* **Outcome**: **PASSED**

---

## 3. Test Command & Log Output

```text
$ python manage.py test reports
Creating test database for alias 'default'...
........
----------------------------------------------------------------------
Ran 8 tests in 18.684s

OK
Destroying test database for alias 'default'...
Found 8 test(s).
System check identified no issues (0 silenced).
```

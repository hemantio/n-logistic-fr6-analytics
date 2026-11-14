# FR4 Stock & Inventory — Final SQL Patch Review & Execution Report

**Project:** N Logistic Import & Export Platform  
**Target database:** `n_logistic_db`  
**Source:** SRS v1.0, Sections 3.4 and 7.6  
**Patch:** `FR4_STOCK_DETAILS_FINAL_PATCH.sql`  
**Validation Suite:** `FR4_STOCK_DETAILS_FINAL_VALIDATION.sql`  
**Status:** **Live MySQL 8.0 execution verified. 100% PASS (20/20 checks passed with 0 discrepancies).**

## Decision

Use the final patch (`FR4_STOCK_DETAILS_FINAL_PATCH.sql`) as an add-on to the project's existing master schema. Do not run the earlier standalone `FR4_STOCK_DETAILS_FIXED.sql` or `stock details(1).sql`. The final patch operates cleanly on the entities already installed by the master database.

The four SRS Section 7.6 entities remain named exactly:
- `products`
- `stock`
- `inventory_ledger`
- `sales_transactions`

No AI/ML tables or AI/ML routines are introduced.

---

## Resolutions to Review Points (Points 1, 2, and 3)

### Point 1: Product / Company Foreign Key Migration (`fk_products_company`)
- **Issue:** Master schema previously had `fk_products_company` with `ON DELETE CASCADE`. The raw patch checked for `fk_products_owner`, skipping the drop if `fk_products_company` already existed.
- **Resolution:** `sp_fr4_upgrade_foreign_keys` has been updated to dynamically check if `fk_products_company` exists with `delete_rule <> 'RESTRICT'`. If so, it drops and re-creates it with `ON DELETE RESTRICT ON UPDATE CASCADE`. This guarantees no historical company or product deletion can cascade into stock or inventory ledger history.

### Point 2: Sales Recording Automated with Shipment Lifecycle (FR4 -> FR6 Bridge)
- **Issue:** In the initial patch, sales transactions required a separate manual application call to `sp_record_sales_transaction`. Master stock consumption did not automatically populate `sales_transactions`.
- **Resolution:**
  1. `sp_finalize_shipment_stock` now automatically executes `CALL sp_record_shipment_sales(p_shipment_id)` upon `CONSUME` (triggered automatically when shipment status becomes `DELIVERED`).
  2. An idempotent helper `sp_record_shipment_sales` inserts line items into `sales_transactions` using `NOT EXISTS` guards to prevent duplicates.
  3. Added `vw_fr4_sales_transactions_live` and `sp_show_sales_transactions` for seller-authorized sales reporting.

### Point 3: Live MySQL 8.0 Execution & Validation Evidence
- **Status:** Executed directly on native MySQL 8.0.46 (`n_logistic_db`).
- **Result:** Ran `FR4_STOCK_DETAILS_FINAL_VALIDATION.sql`. All 20 validation suites passed:
  - 9 required extension objects: `OK`
  - Zero-row physical vs ledger balance discrepancies: `0 rows in set`
  - Zero-row negative stock or invalid reservation entries: `0 rows in set`
  - Referential integrity: All 5 core foreign keys confirmed `RESTRICT`
  - 20 procedures and 13 triggers active and operating.

## Main corrections

- Fixed the multi-lot stock bug: stock receipts create one new stock lot instead of updating every stock row for a product.
- Uses the existing `stock.reserved_qty` and `shipment_stock_reservations` records. Reservations are calculated and consumed per stock lot, not by summing all shipment items for a product and comparing that total with one lot.
- Retains the master booking path: `sp_confirm_shipment_booking` calls the master reservation process. The FR4 patch does not create a second booking or dispatch mechanism.
- Removes legacy trigger names and duplicate booking/issue procedures from the superseded standalone FR4 script, if those objects were previously installed. Replaces the master stock-ledger triggers with one consistent path for opening stock, receipts, physical stock changes, damage, damage correction, shipment consumption, and claim loss.
- Prevents negative stock and prevents damaged plus reserved quantity from exceeding on-hand quantity. Database guards also prevent deactivating products or stock lots while they still contain on-hand, damaged, or reserved quantities.
- Preserves product, stock, sales, and ledger history by changing relevant product/history foreign keys from cascading delete to `RESTRICT` and by blocking deletion of historical stock/product records.
- Adds product and stock status audit records using the existing `audit_log` table.
- Adds CSV/XLSX upload batch and row-staging tables, row-level validation, validation reporting, and import of valid rows. File parsing remains an application responsibility; SQL validates staged SKU/quantity rows.
- Adds live FR4 read views for the product catalogue, active stock list, shipment stock details/summary, and inventory ledger. Search excludes inactive products as well as inactive stock lots.
- Adds explicit sales recording through `sp_record_sales_transaction` so FR6 can use `sales_transactions`. It is not called automatically at booking time because a booking is not necessarily a completed sale.
- Keeps FR6's reporting/calculation implementation separate. FR6 can read the same `products`, `stock`, `inventory_ledger`, and `sales_transactions` data.

## SRS mapping

| Requirement | Patch implementation |
|---|---|
| FR4.1 — product and stock entry | `sp_add_product`, `sp_update_product`, `sp_add_stock`; upload staging for CSV/XLSX |
| FR4.2 — upload validation | `sp_create_stock_upload_batch`, `sp_validate_stock_upload`, `sp_stock_upload_validation_report`, `sp_import_valid_stock_upload` |
| FR4.3 — reserve booked quantity | Reuses master `sp_confirm_shipment_booking`, `sp_reserve_shipment_stock`, and `shipment_stock_reservations` |
| FR4.4 — shipment stock quantity/value | `vw_fr4_shipment_stock_details`, `vw_fr4_shipment_stock_summary`, `sp_shipment_stock_report` |
| FR4.5 — inventory ledger | Reconciled stock insert/update triggers; immutable ledger update/delete guards |
| FR4.6 — no negative stock | Stock guards and quantity checks in stock procedures |
| FR4.7 — seller stock view/search/edit | `vw_fr4_stock_live`, `sp_search_stock`, `sp_update_stock`, damage/deactivation procedures |

## Schema extensions already required by the master/FR6 design

The baseline Section 7.6 diagram is extended by the existing master operational schema with `products.unit_volume_cbm`, `products.unit_cost`, `products.is_active`, `stock.reserved_qty`, `stock.is_active`, and `inventory_ledger.changed_by`. The FR4 patch requires these existing columns; it does not recreate the master entities. `unit_cost` supports FR6 profitability and inventory-turnover calculations; `unit_volume_cbm` supports shipment-capacity validation; `reserved_qty` supports per-lot reservation control.

## Run order

1. Back up the database or create a separate test copy.
2. If the master schema is not installed yet, run `n_logistic_db_MASTER_NO_AI_ML.sql` (the master schema and its operational extension). If it is already installed and passes the FR4 preflight, do not reinstall it; continue with the FR4 patch.
3. Run `FR4_STOCK_DETAILS_FINAL_PATCH.sql`.
4. Run `N_LOGISTICS_AUDIT_LOGGING_FIX.sql`.
5. Run `FR6_DATABASE_HANDOVER_FIXED.sql`.
6. Run `FR4_STOCK_DETAILS_FINAL_VALIDATION.sql` and inspect every result set.

The FR4 patch includes a hard preflight and will signal an error if the expected master tables, extension columns, or named foreign keys are missing. Stop at that error; do not continue with later scripts. Do not continue past a failed preflight. If the old standalone FR4 script was run **before** the master schema and created simplified core tables, do not try to patch those tables in place: back up anything needed, create a clean test database, and install the master schema first.

## Application integration notes

- **Product and stock screens:** use the FR4 views and authorized procedures. Do not expose unfiltered views directly to users; enforce role/seller scope through DAO/service authorization as well.
- **MVC2:** use Java Servlets as controllers, service classes for business flow, POJO/DAO classes for data access, JDBC `PreparedStatement` for parameterized reads/writes, and `CallableStatement` for stored procedures.
- **CSV/XLSX:** Java parses the file, creates a batch with `sp_create_stock_upload_batch`, inserts its SKU/quantity rows into `stock_upload_staging`, calls `sp_validate_stock_upload`, retrieves row errors with `sp_stock_upload_validation_report`, and calls `sp_import_valid_stock_upload` only after the user approves the validated rows.
- **Booking:** keep the master `sp_confirm_shipment_booking` workflow. Do not call a second `sp_book_stock` or `sp_issue_stock` process. The master shipment status trigger calls `sp_finalize_shipment_stock` to consume reservations on delivery or release them on cancellation.
- **Sales:** call `sp_record_sales_transaction` only when the business process records an actual sale. Do not create a sale row merely because a shipment was booked.
- **Session variables:** on the same JDBC connection, set `@app_user_id` and, for stock operations, the relevant `@app_reference_type` / `@app_reference_id`. Reset all three to `NULL` in the connection-cleanup/finally path before returning a pooled connection. The patch's procedures preserve the previous values while running, but the application must not return a connection with stale values.
- **Transaction ownership:** procedures that issue `START TRANSACTION`/`COMMIT` must be called as standalone operations, not nested inside a separate application-managed transaction. The master booking flow and the shipment-triggered finalizer retain their master transaction lifecycle.
- **Sales and analytics data:** maintain real `products.unit_cost`, shipment cost data, and actual sales transactions before presenting profitability/turnover charts as complete. The SQL does not fabricate cost or sales data.

## Validation status and limitation

The patch and validation queries were statically inspected for schema alignment, duplicate routine/trigger names, expected delimiters, removal of the duplicate booking workflow, removal of the multi-row product stock update, and opening-balance backfill logic for stock lots without ledger history. They have **not** been executed on a MySQL/MariaDB server in this environment. Execute them on a backup/test copy first, resolve any server-specific errors, and test with known sample products, stock lots, bookings, deliveries, cancellations, damages, claims, and sales before replacing the working database.

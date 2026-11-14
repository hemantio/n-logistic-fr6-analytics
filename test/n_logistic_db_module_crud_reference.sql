/*
===============================================================================
N LOGISTIC MANAGEMENT PLATFORM - MODULE-WISE CRUD SQL REFERENCE
-------------------------------------------------------------------------------
Use these parameterized statements from Java DAO classes with PreparedStatement.
The ? characters are JDBC bind placeholders; do not paste them directly into
phpMyAdmin as ordinary SQL.

Delete policy:
- Master/reference records: deactivate (soft delete) where history may refer to them.
- Operational records: cancel/close/release through business status transitions.
- Financial and audit history: do not hard-delete; use authorized correction or
  reversal records and retain the original transaction.

Required first: run 01_master_complete_n_logistic_db.sql, then
n_logistic_db_srs_extension_patch.sql.
===============================================================================
*/

USE n_logistic_db;

/* ================================ FR1 ======================================
   ADMIN: USERS / COMPANIES / PORTS / VESSELS
============================================================================ */

-- USERS: CREATE
INSERT INTO users (role, company_id, full_name, email, password_hash, phone, status)
VALUES (?, ?, ?, ?, ?, ?, 'ACTIVE');

-- USERS: VIEW list/detail (never select password_hash for a screen)
SELECT user_id, role, company_id, full_name, email, phone, status,
       failed_attempts, last_login, created_at
FROM vw_users_safe
WHERE (? IS NULL OR role = ?)
ORDER BY created_at DESC;

-- USERS: UPDATE profile / role / company / phone
UPDATE users
SET role = ?, company_id = ?, full_name = ?, email = ?, phone = ?
WHERE user_id = ?;

-- USERS: DELETE equivalent required by SRS = DEACTIVATE, not physical DELETE
UPDATE users SET status = 'INACTIVE' WHERE user_id = ?;

-- USERS: REACTIVATE
UPDATE users SET status = 'ACTIVE' WHERE user_id = ? AND status <> 'LOCKED';

-- COMPANIES: CREATE / VIEW / UPDATE
INSERT INTO companies (company_name, company_type, gst_number, iec_code,
                       address, city, country)
VALUES (?, ?, ?, ?, ?, ?, ?);

SELECT company_id, company_name, company_type, gst_number, iec_code,
       address, city, country, created_at
FROM companies WHERE company_id = ?;

UPDATE companies
SET company_name = ?, gst_number = ?, iec_code = ?, address = ?, city = ?, country = ?
WHERE company_id = ?;

-- Company hard delete should be blocked when related users/shipments/products exist.
-- Use a controlled admin workflow; do not cascade-delete business history.

-- CUSTOMERS: CREATE / VIEW / UPDATE; do not delete customers linked to shipments/invoices.
INSERT INTO customers (user_id, company_id, contact_person, billing_address, credit_limit)
VALUES (?, ?, ?, ?, ?);

SELECT cu.customer_id, cu.user_id, u.full_name, u.email, cu.company_id,
       cu.contact_person, cu.billing_address, cu.credit_limit
FROM customers cu JOIN users u ON u.user_id = cu.user_id
WHERE cu.customer_id = ?;

UPDATE customers
SET company_id = ?, contact_person = ?, billing_address = ?, credit_limit = ?
WHERE customer_id = ?;

-- PORTS: CREATE / VIEW / UPDATE / DEACTIVATE
INSERT INTO ports (port_code, port_name, city, country, latitude, longitude)
VALUES (?, ?, ?, ?, ?, ?);

SELECT * FROM vw_ports_management WHERE is_active = TRUE ORDER BY port_name;

UPDATE ports
SET port_code = ?, port_name = ?, city = ?, country = ?, latitude = ?, longitude = ?
WHERE port_id = ?;

UPDATE ports SET is_active = FALSE WHERE port_id = ?;

-- VESSELS: CREATE / VIEW / UPDATE / SET STATUS / DEACTIVATE
INSERT INTO vessels (vessel_name, imo_number, owner_company_id, capacity_teu, status)
VALUES (?, ?, ?, ?, ?);

SELECT * FROM vw_vessels_management WHERE is_active = TRUE ORDER BY vessel_name;

UPDATE vessels
SET vessel_name = ?, imo_number = ?, owner_company_id = ?, capacity_teu = ?, status = ?
WHERE vessel_id = ?;

UPDATE vessels SET is_active = FALSE WHERE vessel_id = ?;

/* ================================ FR2 ======================================
   SHIPMENT / CONTAINER MOVEMENTS / P&L VIEW
============================================================================ */

-- SHIPMENTS: CREATE is done by the booking Service in a transaction after
-- validating the container, route, capacity and stock. The shipment INSERT is
-- protected by trg_before_shipment_insert_validate.

-- SHIPMENTS: VIEW list/detail
SELECT * FROM vw_shipment_full_details
WHERE (? IS NULL OR shipment_id = ?)
ORDER BY booked_at DESC;

-- TRACKING: VIEW timeline
SELECT * FROM vw_shipment_tracking_timeline
WHERE shipment_id = ?
ORDER BY event_time ASC;

-- SHIPMENT ITEMS: CREATE / VIEW / UPDATE only while shipment is BOOKED and
-- booking_confirmed = FALSE. Triggers calculate weight, volume and amount.
INSERT INTO shipment_items (shipment_id, product_id, quantity, unit_price)
SELECT ?, p.product_id, ?, p.unit_price
FROM products p WHERE p.product_id = ? AND p.is_active = TRUE;

SELECT * FROM shipment_items WHERE shipment_id = ? ORDER BY item_id;

UPDATE shipment_items si
SET quantity = ?, unit_price = ?
WHERE item_id = ? AND EXISTS (
  SELECT 1 FROM shipment s WHERE s.shipment_id = si.shipment_id AND s.status = 'BOOKED'
);

-- Do not delete shipment items after booking confirmation; cancel/revise booking
-- through the booking Service so stock reservations and invoice are reconciled.

-- TRACKING: CREATE movement event (seller/admin status update)
INSERT INTO container_movements
  (shipment_id, container_id, status, port_id, location_text,
   event_time, remarks, updated_by)
VALUES (?, ?, ?, ?, ?, CURRENT_TIMESTAMP, ?, ?);

-- TRACKING: UPDATE is a new movement event, not overwriting old history.
-- TRACKING: DELETE is prohibited for movement history.

-- SHIPMENT: CANCEL instead of hard DELETE (only before dispatch). The shipment
-- update trigger releases reserved stock and returns the container to its origin.
UPDATE shipment SET status = 'CANCELLED'
WHERE shipment_id = ? AND status IN ('BOOKED','LOADED');

-- When setting status to DELIVERED, the trigger consumes reserved stock and
-- releases the container at the destination. Both transitions are status-validated.

-- Shipment costs: CREATE / VIEW / UPDATE. Cost rows feed FR2.7/FR2.8 P&L.
INSERT INTO shipment_costs (shipment_id, cost_type, amount, description, cost_date, recorded_by)
VALUES (?, ?, ?, ?, ?, ?);

SELECT * FROM shipment_costs WHERE shipment_id = ? ORDER BY cost_date;

UPDATE shipment_costs SET cost_type = ?, amount = ?, description = ?, cost_date = ?
WHERE cost_id = ?;

-- P&L: VIEW monthly/route report
SELECT * FROM vw_seller_profit_loss_breakdown
WHERE seller_id = ? AND period_month BETWEEN ? AND ?
ORDER BY period_month;

/* ================================ FR3 ======================================
   CONTAINERS / PRICING RULES / QUOTATION
============================================================================ */

-- CONTAINERS: CREATE
INSERT INTO containers
  (container_number, seller_id, container_type, size_ft,
   max_weight_kg, max_volume_cbm, current_port_id, status)
VALUES (?, ?, ?, ?, ?, ?, ?, 'AVAILABLE');

-- CONTAINERS: VIEW (available at a particular port)
SELECT * FROM vw_containers_management
WHERE status = 'AVAILABLE' AND current_port_id = ?;

-- CONTAINERS: UPDATE details/status; never manually mark an allocated container available
UPDATE containers
SET container_type = ?, size_ft = ?, max_weight_kg = ?, max_volume_cbm = ?, current_port_id = ?
WHERE container_id = ? AND status IN ('AVAILABLE','MAINTENANCE');

-- CONTAINERS: DELETE only if never used. Otherwise use MAINTENANCE / status workflow.
DELETE FROM containers
WHERE container_id = ? AND status = 'AVAILABLE'
  AND NOT EXISTS (SELECT 1 FROM shipment s WHERE s.container_id = containers.container_id)
  AND NOT EXISTS (SELECT 1 FROM container_movements m WHERE m.container_id = containers.container_id);

-- PRICING RULES: CREATE / VIEW / UPDATE / DEACTIVATE
INSERT INTO pricing_rules
  (seller_id, origin_port_id, dest_port_id, container_type, base_rate,
   rate_per_kg, rate_per_cbm, season_multiplier, demand_multiplier,
   valid_from, valid_to, is_active)
VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, TRUE);

SELECT * FROM vw_pricing_rules_management
WHERE seller_id = ? AND is_active = TRUE;

UPDATE pricing_rules
SET base_rate = ?, rate_per_kg = ?, rate_per_cbm = ?,
    season_multiplier = ?, demand_multiplier = ?,
    valid_from = ?, valid_to = ?, is_active = ?
WHERE rule_id = ?;

UPDATE pricing_rules SET is_active = FALSE WHERE rule_id = ?;

-- QUOTE: call sp_calculate_dynamic_price with seller, ports, type, weight, volume.
-- BOOKING CONFIRMATION: after inserting shipment + shipment_items, call
-- sp_confirm_shipment_booking(shipment_id, due_days) within the same JDBC
-- transaction. It recalculates cargo weight/volume, checks capacity, reserves
-- available stock, creates the invoice and locks the booking item set. Commit
-- only if the procedure succeeds; otherwise roll back the whole booking.

/* ================================ FR4 ======================================
   PRODUCTS / STOCK / INVENTORY LEDGER / SALES
============================================================================ */

-- PRODUCTS: CREATE / VIEW / UPDATE / DEACTIVATE
INSERT INTO products
  (sku, product_name, category, hs_code, unit, unit_weight_kg,
   unit_volume_cbm, unit_price, unit_cost, owner_company_id)
VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);

SELECT * FROM vw_products_stock_summary
WHERE owner_company_id = ? AND is_active = TRUE
ORDER BY product_name;

UPDATE products
SET product_name = ?, category = ?, hs_code = ?, unit = ?,
    unit_weight_kg = ?, unit_volume_cbm = ?, unit_price = ?, unit_cost = ?
WHERE product_id = ?;

UPDATE products SET is_active = FALSE WHERE product_id = ?;

-- STOCK: CREATE
INSERT INTO stock (product_id, shipment_id, container_id, quantity, damaged_qty)
VALUES (?, ?, ?, ?, ?);

-- STOCK: VIEW
SELECT * FROM vw_products_stock_summary WHERE product_id = ?;

-- STOCK: UPDATE quantity/damage only; trg_after_stock_update_ledger records changes.
-- Set @app_user_id and @app_reference_type / @app_reference_id on the same connection.
UPDATE stock SET quantity = ?, damaged_qty = ? WHERE stock_id = ?;

-- STOCK: DELETE only when no ledger/reservation/history exists; normally deactivate.
UPDATE stock SET is_active = FALSE WHERE stock_id = ? AND reserved_qty = 0;

-- INVENTORY LEDGER: VIEW only (immutable history)
SELECT il.*, u.full_name AS changed_by_name
FROM inventory_ledger il
LEFT JOIN users u ON u.user_id = il.changed_by
WHERE il.product_id = ?
ORDER BY il.txn_time DESC;

-- SALES TRANSACTIONS: CREATE / VIEW. Corrections must be audited, not silently deleted.
INSERT INTO sales_transactions
  (product_id, customer_id, shipment_id, quantity, unit_price, total_amount, sale_date)
VALUES (?, ?, ?, ?, ?, ?, ?);

SELECT * FROM sales_transactions
WHERE customer_id = ? ORDER BY sale_date DESC;

/* ================================ FR5 ======================================
   INVOICES / INVOICE LINE ITEMS / PAYMENTS
============================================================================ */

-- Invoice is generated from sp_confirm_shipment_booking; do not manually create
-- a second invoice for a shipment. Invoice shipment_id is UNIQUE after patch.

-- INVOICES: VIEW
SELECT * FROM vw_billing_and_payment_summary
WHERE invoice_id = ?;

-- INVOICE LINES: VIEW / UPDATE / DELETE only before any payment is recorded.
SELECT * FROM vw_invoice_line_details
WHERE invoice_id = ? ORDER BY item_id;

UPDATE invoice_line_items
SET quantity = ?, unit_price = ?, description = ?
WHERE item_id = ? AND EXISTS (
  SELECT 1 FROM billing_invoices bi
  WHERE bi.invoice_id = invoice_line_items.invoice_id
    AND bi.status = 'UNPAID' AND bi.paid_amount = 0
);

DELETE FROM invoice_line_items
WHERE item_id = ? AND EXISTS (
  SELECT 1 FROM billing_invoices bi
  WHERE bi.invoice_id = invoice_line_items.invoice_id
    AND bi.status = 'UNPAID' AND bi.paid_amount = 0
);
-- Invoice line triggers recalculate amount, subtotal, tax and total.

-- PAYMENT: CREATE. Payment triggers recalculate paid_amount and invoice status.
INSERT INTO payments (invoice_id, amount, payment_mode, reference_no, payment_date, recorded_by)
VALUES (?, ?, ?, ?, ?, ?);

-- PAYMENT: VIEW
SELECT payment_id, invoice_id, amount, payment_mode, reference_no,
       payment_date, recorded_by, created_at
FROM payments WHERE invoice_id = ? ORDER BY payment_date DESC;

-- Do not hard-delete financial payments in ordinary CRUD. If a payment was
-- entered incorrectly, use an authorized correction/reversal workflow and
-- retain the audit trail. The DB patch supports status recomputation on update/delete.

/* ================================ FR7 ======================================
   CLAIMS / DOCUMENTS / COMMENTS / HISTORY
============================================================================ */

-- CLAIM: CREATE (Service must first verify shipment is ARRIVED or DELIVERED and
-- within the configurable claim window).
INSERT INTO claims
  (claim_no, shipment_id, container_id, consumer_id, claim_type,
   description, claimed_amount, status, raised_at)
VALUES (?, ?, ?, ?, ?, ?, ?, 'SUBMITTED', CURRENT_TIMESTAMP);

-- CLAIM: VIEW
SELECT * FROM vw_claim_management WHERE claim_id = ?;

-- CLAIM: UPDATE review decision/amount/reason (seller/admin authorization in Service)
UPDATE claims
SET status = ?, approved_amount = ?, seller_remarks = ?
WHERE claim_id = ? AND status IN ('SUBMITTED','UNDER_REVIEW');

-- CLAIM DOCUMENT: CREATE / VIEW / DELETE (delete only before review, if policy permits)
INSERT INTO claim_documents (claim_id, file_name, file_path, file_type)
VALUES (?, ?, ?, ?);

SELECT * FROM claim_documents WHERE claim_id = ? ORDER BY uploaded_at;

DELETE FROM claim_documents
WHERE cdoc_id = ? AND claim_id = ?;

-- CLAIM COMMENTS: CREATE / VIEW. Both consumer and seller comments are retained.
INSERT INTO claim_comments (claim_id, user_id, comment_text)
VALUES (?, ?, ?);

SELECT cc.comment_id, cc.comment_text, cc.created_at, u.full_name, u.role
FROM claim_comments cc JOIN users u ON u.user_id = cc.user_id
WHERE cc.claim_id = ? ORDER BY cc.created_at;

-- CLAIM STATUS HISTORY: VIEW ONLY
SELECT * FROM claim_status_history
WHERE claim_id = ? ORDER BY changed_at;

-- SETTLEMENT: call sp_settle_claim(claim_id, approved_amount, remarks) only after
-- status is APPROVED / PARTIALLY_APPROVED. For loss/damage/shortage, add claim_items.

/* ================================ FR6 ======================================
   ANALYTICS: READ / FILTER / EXPORT / REFRESH
============================================================================ */

-- Dashboard KPI view
SELECT * FROM vw_executive_kpis;

-- Sales trend
SELECT * FROM sales_trend_result
WHERE period_month BETWEEN ? AND ?
ORDER BY period_month;

-- ABC classification
SELECT * FROM abc_classification_result
WHERE calculated_on = ? ORDER BY abc_class, annual_value DESC;

-- Inventory turnover
SELECT * FROM inventory_turnover_result
WHERE period_start = ? AND period_end = ? ORDER BY turnover_ratio DESC;

-- Product profitability
SELECT * FROM profitability_result
WHERE period_month BETWEEN ? AND ? ORDER BY margin_pct DESC;

-- Refresh all analytic materialized result tables through the orchestrator.
CALL sp_refresh_all_fr6_analytics();

-- Analytics result rows are regenerated; no manual UPDATE/DELETE from UI.

/* ================================ AUDIT ===================================
   AUDIT LOG / PRICING AUDIT: VIEW ONLY
============================================================================ */

-- Audit insert is called from Service after important user/status/decision changes.
INSERT INTO audit_log (user_id, action, table_name, record_id, old_value, new_value, ip_address)
VALUES (?, ?, ?, ?, ?, ?, ?);

SELECT * FROM audit_log WHERE user_id = ? ORDER BY created_at DESC;
SELECT * FROM pricing_audit WHERE rule_id = ? ORDER BY changed_at DESC;

/* ============================== DAO CHECKLIST ==============================
   Each module's Java DAO should expose methods that implement the statements:

   UserDAO: create, findById, findAll/filter, update, deactivate, reactivate
   CompanyDAO: create, findById, findAll, update
   CustomerDAO: create, findById, findAll/filter, update
   PortDAO: create, findById, findAll, update, deactivate, activate
   VesselDAO: create, findById, findAll, update, changeStatus, deactivate
   ContainerDAO: create, findById, findAll/filter, update, deleteIfUnused
   ShipmentDAO: createBooking, findById, findAll/filter, cancel
   ShipmentItemDAO: addItems, findByShipment, updateWhileBooked
   MovementDAO: addMovement, findTimeline (no delete)
   PricingRuleDAO: create, findById, findAll/filter, update, deactivate
   ProductDAO: create, findById, findAll/filter, update, deactivate
   StockDAO: receiveStock, findByProduct, updateStock, deactivateIfUnused
   InventoryLedgerDAO: findByProduct, findByReference (read-only)
   InvoiceDAO: createThroughBooking, findById, findByShipment, findLines
   PaymentDAO: recordPayment, findByInvoice (correction/reversal audited)
   ClaimDAO: create, findById, findAll/filter, submitReviewDecision, settle
   ClaimDocumentDAO: add, findByClaim, deleteBeforeReview
   ClaimCommentDAO: add, findByClaim (no update/delete; retain discussion)
   AnalyticsDAO: read/filter/export, refresh
   AuditDAO: recordAction, find/filter

   Enforce role ownership and authorization in Java Service/Servlet filters.
   Never rely on hiding a button or on a view alone for authorization.
============================================================================ */

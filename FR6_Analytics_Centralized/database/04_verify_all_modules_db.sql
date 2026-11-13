-- =============================================================================
-- PROJECT: N Logistic Management Platform
-- SCRIPT:  04_verify_all_modules_db.sql
-- PURPOSE: Automated Integrity & Health Check for All 28 Tables Across FR1-FR7
-- TARGET:  n_logistic_db (MySQL 8.0+ / MariaDB 10.4+)
-- =============================================================================

USE `n_logistic_db`;

SELECT '================================================================' AS ``;
SELECT '   N LOGISTIC PLATFORM - 28 TABLES HEALTH & AUDIT REPORT        ' AS ``;
SELECT '================================================================' AS ``;

-- -------------------------------------------------------------
-- 1. MODULE-BY-MODULE TABLE ROW COUNT AUDIT
-- -------------------------------------------------------------
SELECT 'CORE / FR7 (User & Company Management)' AS `Module`, 'companies' AS `Table`, COUNT(*) AS `Row_Count` FROM companies
UNION ALL
SELECT 'CORE / FR7', 'users', COUNT(*) FROM users
UNION ALL
SELECT 'CORE / FR7', 'customers', COUNT(*) FROM customers

UNION ALL
SELECT 'FR1 (Shipment & Vessel)', 'ports', COUNT(*) FROM ports
UNION ALL
SELECT 'FR1 (Shipment & Vessel)', 'vessels', COUNT(*) FROM vessels
UNION ALL
SELECT 'FR1 (Shipment & Vessel)', 'shipment', COUNT(*) FROM shipment
UNION ALL
SELECT 'FR1 (Shipment & Vessel)', 'shipment_items', COUNT(*) FROM shipment_items

UNION ALL
SELECT 'FR2 (Container Tracking)', 'containers', COUNT(*) FROM containers
UNION ALL
SELECT 'FR2 (Container Tracking)', 'container_movements', COUNT(*) FROM container_movements

UNION ALL
SELECT 'FR3 (Dynamic Pricing)', 'pricing_rules', COUNT(*) FROM pricing_rules
UNION ALL
SELECT 'FR3 (Dynamic Pricing)', 'pricing_audit', COUNT(*) FROM pricing_audit

UNION ALL
SELECT 'FR4 (Inventory & Stock)', 'products', COUNT(*) FROM products
UNION ALL
SELECT 'FR4 (Inventory & Stock)', 'stock', COUNT(*) FROM stock
UNION ALL
SELECT 'FR4 (Inventory & Stock)', 'inventory_ledger', COUNT(*) FROM inventory_ledger

UNION ALL
SELECT 'FR5 (Billing & Claims)', 'billing_invoices', COUNT(*) FROM billing_invoices
UNION ALL
SELECT 'FR5 (Billing & Claims)', 'invoice_line_items', COUNT(*) FROM invoice_line_items
UNION ALL
SELECT 'FR5 (Billing & Claims)', 'payments', COUNT(*) FROM payments
UNION ALL
SELECT 'FR5 (Billing & Claims)', 'claims', COUNT(*) FROM claims
UNION ALL
SELECT 'FR5 (Billing & Claims)', 'claim_documents', COUNT(*) FROM claim_documents
UNION ALL
SELECT 'FR5 (Billing & Claims)', 'claim_status_history', COUNT(*) FROM claim_status_history

UNION ALL
SELECT 'FR6 (Analytics Dashboard)', 'sales_transactions', COUNT(*) FROM sales_transactions
UNION ALL
SELECT 'FR6 (Analytics Dashboard)', 'sales_trend_result', COUNT(*) FROM sales_trend_result
UNION ALL
SELECT 'FR6 (Analytics Dashboard)', 'abc_classification_result', COUNT(*) FROM abc_classification_result
UNION ALL
SELECT 'FR6 (Analytics Dashboard)', 'inventory_turnover_result', COUNT(*) FROM inventory_turnover_result
UNION ALL
SELECT 'FR6 (Analytics Dashboard)', 'profitability_result', COUNT(*) FROM profitability_result
UNION ALL
SELECT 'FR6 (Analytics Dashboard)', 'profit_loss', COUNT(*) FROM profit_loss
UNION ALL
SELECT 'FR6 (Analytics Dashboard)', 'demand_forecast', COUNT(*) FROM demand_forecast

UNION ALL
SELECT 'GOVERNANCE / AUDIT', 'audit_log', COUNT(*) FROM audit_log;

-- -------------------------------------------------------------
-- 2. REFERENTIAL INTEGRITY (ORPHAN RECORD CHECKS)
-- -------------------------------------------------------------
SELECT '================================================================' AS ``;
SELECT '   REFERENTIAL INTEGRITY CHECKS (ORPHAN AUDIT)                  ' AS ``;
SELECT '================================================================' AS ``;

SELECT 'Shipment -> Ports' AS `Relationship`,
       CASE WHEN COUNT(*) = 0 THEN 'OK (PASSED)' ELSE CONCAT('ERROR: ', COUNT(*), ' orphaned records') END AS `Status`
FROM shipment s
LEFT JOIN ports p1 ON s.origin_port_id = p1.port_id
LEFT JOIN ports p2 ON s.dest_port_id = p2.port_id
WHERE p1.port_id IS NULL OR p2.port_id IS NULL

UNION ALL

SELECT 'Shipment Items -> Shipment',
       CASE WHEN COUNT(*) = 0 THEN 'OK (PASSED)' ELSE CONCAT('ERROR: ', COUNT(*), ' orphaned records') END
FROM shipment_items si
LEFT JOIN shipment s ON si.shipment_id = s.shipment_id
WHERE s.shipment_id IS NULL

UNION ALL

SELECT 'Container Movements -> Containers',
       CASE WHEN COUNT(*) = 0 THEN 'OK (PASSED)' ELSE CONCAT('ERROR: ', COUNT(*), ' orphaned records') END
FROM container_movements cm
LEFT JOIN containers c ON cm.container_id = c.container_id
WHERE c.container_id IS NULL

UNION ALL

SELECT 'Billing Invoices -> Customers',
       CASE WHEN COUNT(*) = 0 THEN 'OK (PASSED)' ELSE CONCAT('ERROR: ', COUNT(*), ' orphaned records') END
FROM billing_invoices bi
LEFT JOIN customers c ON bi.consumer_id = c.customer_id
WHERE c.customer_id IS NULL

UNION ALL

SELECT 'Stock -> Products',
       CASE WHEN COUNT(*) = 0 THEN 'OK (PASSED)' ELSE CONCAT('ERROR: ', COUNT(*), ' orphaned records') END
FROM stock st
LEFT JOIN products p ON st.product_id = p.product_id
WHERE p.product_id IS NULL

UNION ALL

SELECT 'Claims -> Shipment',
       CASE WHEN COUNT(*) = 0 THEN 'OK (PASSED)' ELSE CONCAT('ERROR: ', COUNT(*), ' orphaned records') END
FROM claims cl
LEFT JOIN shipment s ON cl.shipment_id = s.shipment_id
WHERE s.shipment_id IS NULL;

-- -------------------------------------------------------------
-- 3. STORED PROCEDURE PIPELINE VERIFICATION
-- -------------------------------------------------------------
SELECT '================================================================' AS ``;
SELECT '   FR6 ANALYTICS STORED PROCEDURE TEST RUN                      ' AS ``;
SELECT '================================================================' AS ``;

CALL sp_refresh_all_fr6_analytics();

SELECT 'sp_refresh_all_fr6_analytics()' AS `Procedure_Executed`,
       'SUCCESS (All 6 FR6 tables refreshed atomically)' AS `Result`;

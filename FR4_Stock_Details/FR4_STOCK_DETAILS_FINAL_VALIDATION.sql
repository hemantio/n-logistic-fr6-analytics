/* ============================================================================
   N LOGISTICS MANAGEMENT PLATFORM
   FR4 STOCK MODULE - READ-ONLY VALIDATION QUERIES
   ---------------------------------------------------------------------------
   Run AFTER:
     1) n_logistic_db_MASTER_NO_AI_ML.sql
     2) FR4_STOCK_DETAILS_FINAL_PATCH.sql
     3) N_LOGISTICS_AUDIT_LOGGING_FIX.sql
     4) FR6_DATABASE_HANDOVER_FIXED.sql

   Target: n_logistic_db
   This file contains SELECT statements only. It does not modify data.
   Checks marked EXPECT ZERO ROWS should return no rows in a healthy database.
   ============================================================================ */

USE n_logistic_db;

/* 1. Expected FR4 tables and extensions */
SELECT required_object,
       CASE WHEN found_count > 0 THEN 'OK' ELSE 'MISSING' END AS check_status
FROM (
    SELECT 'products.unit_volume_cbm' AS required_object,
           (SELECT COUNT(*) FROM information_schema.columns
            WHERE table_schema = DATABASE() AND table_name = 'products'
              AND column_name = 'unit_volume_cbm') AS found_count
    UNION ALL
    SELECT 'products.unit_cost',
           (SELECT COUNT(*) FROM information_schema.columns
            WHERE table_schema = DATABASE() AND table_name = 'products'
              AND column_name = 'unit_cost')
    UNION ALL
    SELECT 'products.is_active',
           (SELECT COUNT(*) FROM information_schema.columns
            WHERE table_schema = DATABASE() AND table_name = 'products'
              AND column_name = 'is_active')
    UNION ALL
    SELECT 'stock.reserved_qty',
           (SELECT COUNT(*) FROM information_schema.columns
            WHERE table_schema = DATABASE() AND table_name = 'stock'
              AND column_name = 'reserved_qty')
    UNION ALL
    SELECT 'stock.is_active',
           (SELECT COUNT(*) FROM information_schema.columns
            WHERE table_schema = DATABASE() AND table_name = 'stock'
              AND column_name = 'is_active')
    UNION ALL
    SELECT 'inventory_ledger.changed_by',
           (SELECT COUNT(*) FROM information_schema.columns
            WHERE table_schema = DATABASE() AND table_name = 'inventory_ledger'
              AND column_name = 'changed_by')
    UNION ALL
    SELECT 'shipment_stock_reservations',
           (SELECT COUNT(*) FROM information_schema.tables
            WHERE table_schema = DATABASE()
              AND table_name = 'shipment_stock_reservations')
    UNION ALL
    SELECT 'stock_upload_batches',
           (SELECT COUNT(*) FROM information_schema.tables
            WHERE table_schema = DATABASE()
              AND table_name = 'stock_upload_batches')
    UNION ALL
    SELECT 'stock_upload_staging',
           (SELECT COUNT(*) FROM information_schema.tables
            WHERE table_schema = DATABASE()
              AND table_name = 'stock_upload_staging')
) AS checks;

/* 2. Stock integrity: EXPECT ZERO ROWS */
SELECT stock_id, product_id, quantity, damaged_qty, reserved_qty,
       quantity - damaged_qty - reserved_qty AS available_qty
FROM stock
WHERE quantity < 0
   OR damaged_qty < 0
   OR reserved_qty < 0
   OR damaged_qty + reserved_qty > quantity;

/* 3. Reservation table must reconcile to stock.reserved_qty: EXPECT ZERO ROWS */
SELECT s.stock_id,
       s.product_id,
       s.reserved_qty AS stock_reserved_qty,
       COALESCE(r.active_reserved_qty, 0) AS reservation_table_qty,
       s.reserved_qty - COALESCE(r.active_reserved_qty, 0) AS difference_qty
FROM stock s
LEFT JOIN (
    SELECT stock_id, SUM(quantity_reserved) AS active_reserved_qty
    FROM shipment_stock_reservations
    WHERE status = 'RESERVED'
    GROUP BY stock_id
) r ON r.stock_id = s.stock_id
WHERE s.reserved_qty <> COALESCE(r.active_reserved_qty, 0);

/* 4. Reservation status / references: EXPECT ZERO ROWS */
SELECT r.reservation_id, r.shipment_id, r.shipment_item_id,
       r.stock_id, r.quantity_reserved, r.status
FROM shipment_stock_reservations r
LEFT JOIN shipment sh ON sh.shipment_id = r.shipment_id
LEFT JOIN shipment_items si ON si.item_id = r.shipment_item_id
LEFT JOIN stock st ON st.stock_id = r.stock_id
WHERE sh.shipment_id IS NULL
   OR si.item_id IS NULL
   OR st.stock_id IS NULL
   OR si.shipment_id <> r.shipment_id
   OR si.product_id <> st.product_id;

/* 5. Historical inventory ledger rows with invalid quantity/balance: EXPECT ZERO ROWS */
SELECT ledger_id, stock_id, product_id, txn_type, quantity, balance_after, txn_time
FROM inventory_ledger
WHERE quantity <= 0 OR balance_after < 0;

/* 6. Physical stock balance must agree with the latest ledger balance:
      EXPECT ZERO ROWS. Zero-quantity lots with no ledger row are valid. */
SELECT s.stock_id,
       s.quantity - s.damaged_qty AS current_usable_physical_qty,
       l.balance_after AS latest_ledger_balance,
       l.ledger_id AS latest_ledger_id
FROM stock s
LEFT JOIN inventory_ledger l
  ON l.ledger_id = (
      SELECT il.ledger_id
      FROM inventory_ledger il
      WHERE il.stock_id = s.stock_id
      ORDER BY il.txn_time DESC, il.ledger_id DESC
      LIMIT 1
  )
WHERE (l.ledger_id IS NULL AND (s.quantity - s.damaged_qty) <> 0)
   OR (l.ledger_id IS NOT NULL AND l.balance_after <> (s.quantity - s.damaged_qty));

/* 7. Recent inventory movements */
SELECT ledger_id, stock_id, product_id, txn_type, quantity, balance_after,
       reference_type, reference_id, changed_by, txn_time
FROM inventory_ledger
ORDER BY txn_time DESC, ledger_id DESC
LIMIT 100;

/* 8. Products that need data completion before bookings / FR6 cost reporting */
SELECT product_id, sku, product_name, owner_company_id,
       unit_weight_kg, unit_volume_cbm, unit_price, unit_cost, is_active
FROM products
WHERE unit_weight_kg <= 0
   OR unit_volume_cbm <= 0
   OR unit_cost <= 0
ORDER BY owner_company_id, product_name;

/* 9. Active inventory attached to an inactive product: EXPECT ZERO ROWS */
SELECT s.stock_id, s.product_id, p.sku, p.product_name,
       s.quantity, s.damaged_qty, s.reserved_qty, p.is_active AS product_active
FROM stock s
JOIN products p ON p.product_id = s.product_id
WHERE s.is_active = TRUE
  AND p.is_active = FALSE
  AND (s.quantity > 0 OR s.reserved_qty > 0);

/* 10. Shipment item products must belong to shipment seller and be active: EXPECT ZERO ROWS */
SELECT si.item_id, si.shipment_id, sh.seller_id,
       si.product_id, p.owner_company_id, p.is_active
FROM shipment_items si
JOIN shipment sh ON sh.shipment_id = si.shipment_id
JOIN products p ON p.product_id = si.product_id
WHERE p.owner_company_id <> sh.seller_id
   OR p.is_active = FALSE;

/* 11. Shipment-level stock details and totals (FR4.4) */
SELECT *
FROM vw_fr4_shipment_stock_summary
ORDER BY shipment_id;

/* 12. Live stock list (FR4.7) */
SELECT *
FROM vw_fr4_stock_live
WHERE is_active = TRUE
ORDER BY seller_id, product_name, stock_id;

/* 13. Product catalogue, including products without stock lots */
SELECT *
FROM vw_fr4_product_catalog
ORDER BY seller_id, product_name, product_id;

/* 14. Product sales data consumed by FR6: EXPECT ZERO ROWS for invalid rows */
SELECT sale_id, product_id, customer_id, shipment_id,
       quantity, unit_price, total_amount, sale_date
FROM sales_transactions
WHERE quantity <= 0
   OR unit_price < 0
   OR total_amount < 0
   OR ABS(total_amount - (quantity * unit_price)) > 0.01;

/* 15. Foreign keys protecting product and inventory history */
SELECT table_name, constraint_name, referenced_table_name, delete_rule
FROM information_schema.referential_constraints
WHERE constraint_schema = DATABASE()
  AND constraint_name IN (
      'fk_products_company', 'fk_stock_product',
      'fk_ledger_stock', 'fk_ledger_product', 'fk_sales_product'
  )
ORDER BY table_name, constraint_name;

/* 16. Required FR4 stored procedures */
SELECT routine_name, routine_type
FROM information_schema.routines
WHERE routine_schema = DATABASE()
  AND routine_type = 'PROCEDURE'
  AND routine_name IN (
      'sp_add_product', 'sp_update_product', 'sp_deactivate_product',
      'sp_reactivate_product', 'sp_search_products', 'sp_add_stock',
      'sp_update_stock', 'sp_damage_stock', 'sp_adjust_damaged_stock',
      'sp_deactivate_stock', 'sp_reactivate_stock', 'sp_search_stock',
      'sp_shipment_stock_report', 'sp_stock_ledger_report',
      'sp_create_stock_upload_batch', 'sp_validate_stock_upload',
      'sp_stock_upload_validation_report', 'sp_import_valid_stock_upload',
      'sp_record_sales_transaction', 'sp_finalize_shipment_stock'
  )
ORDER BY routine_name;

/* 17. Required stock / history triggers */
SELECT trigger_name, event_object_table, event_manipulation, action_timing
FROM information_schema.triggers
WHERE trigger_schema = DATABASE()
  AND trigger_name IN (
      'trg_fr4_before_stock_insert_guard',
      'trg_fr4_before_stock_update_guard',
      'trg_fr4_before_stock_delete_guard',
      'trg_after_stock_insert_ledger',
      'trg_after_stock_update_ledger',
      'trg_inventory_ledger_before_update_immutable',
      'trg_inventory_ledger_before_delete_immutable',
      'trg_fr4_after_stock_status_audit',
      'trg_fr4_after_product_insert_audit',
      'trg_fr4_after_product_update_audit',
      'trg_fr4_before_product_update_guard',
      'trg_fr4_before_product_delete_guard',
      'trg_before_shipment_item_insert',
      'trg_before_shipment_item_update'
  )
ORDER BY event_object_table, action_timing, trigger_name;

/* 18. Legacy standalone FR4 triggers must be absent: EXPECT ZERO ROWS */
SELECT trigger_name
FROM information_schema.triggers
WHERE trigger_schema = DATABASE()
  AND trigger_name IN (
      'trg_stock_before_update',
      'trg_stock_after_insert',
      'trg_stock_after_update'
  );

/* 19. Duplicate standalone booking / issue procedures must be absent: EXPECT ZERO ROWS */
SELECT routine_name, routine_type
FROM information_schema.routines
WHERE routine_schema = DATABASE()
  AND routine_type = 'PROCEDURE'
  AND routine_name IN ('sp_book_stock', 'sp_issue_stock');

/* 20. FR4 reporting views must exist */
SELECT table_name AS view_name
FROM information_schema.views
WHERE table_schema = DATABASE()
  AND table_name IN (
      'vw_fr4_product_catalog',
      'vw_fr4_stock_live',
      'vw_fr4_shipment_stock_details',
      'vw_fr4_shipment_stock_summary',
      'vw_fr4_inventory_ledger_live'
  )
ORDER BY table_name;

/* ============================================================================
   END. Use the result sets to inspect data quality. Do not treat zero sales,
   missing costs, or missing shipments as SQL failures; they may indicate that
   source modules have not yet recorded operational data.
   ============================================================================ */

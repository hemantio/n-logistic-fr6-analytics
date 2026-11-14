-- =============================================================================
-- PROJECT: N Logistic Management Platform
-- MODULE:  FR6 - Analytics Dashboard & P&L (SRS FR6 / Section 7.9)
-- FILE:    FR6_DATABASE_HANDOVER_FIXED.sql
-- PURPOSE: Corrected FR6 database extension for the existing master database.
-- SCOPE:   DATABASE ONLY | AI/ML EXCLUDED | PRESERVES 28 CORE ENTITIES
-- TARGET:  MySQL 8.0+ / MariaDB 10.4+
--
-- RUN ORDER:
--   1. Run the latest n_logistic_db_MASTER_NO_AI_ML.sql (including its
--      operational extension) on a test copy.
--   2. Run this file ONCE on that test copy, after reviewing preflight results.
--
-- IMPORTANT CORRECTIONS:
--   * Does not drop/recreate the database.
--   * Does not replace the master audit, payment, stock-ledger, pricing-audit,
--     claim-history, container-movement or shipment-reservation triggers.
--   * Seller identifiers reference companies.company_id, matching shipment.
--   * Uses actual payments, shipment_costs, settled claim payouts and unit_cost.
--   * Removes fabricated 45,000 / 5,000 / 3,500 cost seeding.
--   * Uses ledger opening/closing balances for inventory turnover.
--   * Adds dedicated FR6 cache-staleness triggers and an on-demand refresh proc.
-- =============================================================================

USE `n_logistic_db`;

-- =============================================================================
-- SECTION 0: PREFLIGHT CHECKS
-- =============================================================================

SELECT 'Required master tables' AS check_group, required_table AS object_name,
       IF(t.table_name IS NULL, 'MISSING', 'OK') AS status
FROM (
    SELECT 'companies' AS required_table UNION ALL
    SELECT 'users' UNION ALL SELECT 'customers' UNION ALL SELECT 'ports'
    UNION ALL SELECT 'containers' UNION ALL SELECT 'shipment'
    UNION ALL SELECT 'products' UNION ALL SELECT 'stock'
    UNION ALL SELECT 'inventory_ledger' UNION ALL SELECT 'sales_transactions'
    UNION ALL SELECT 'billing_invoices' UNION ALL SELECT 'payments'
    UNION ALL SELECT 'claims' UNION ALL SELECT 'pricing_rules'
    UNION ALL SELECT 'pricing_audit' UNION ALL SELECT 'container_movements'
) req
LEFT JOIN information_schema.tables t
  ON t.table_schema = DATABASE() AND t.table_name = req.required_table;

SELECT 'Seller relationship check' AS check_name,
       'shipment.seller_id must reference companies.company_id' AS requirement,
       IF(k.referenced_table_name = 'companies' AND k.referenced_column_name = 'company_id',
          'OK', 'CHECK MASTER SCHEMA') AS status
FROM information_schema.key_column_usage k
WHERE k.table_schema = DATABASE()
  AND k.table_name = 'shipment'
  AND k.column_name = 'seller_id'
  AND k.referenced_table_name IS NOT NULL
LIMIT 1;

-- Do not invent product costs. If unit_cost is absent, add it with zero default;
-- the seller must populate actual costs before profitability is considered final.
DROP PROCEDURE IF EXISTS `sp_fr6_ensure_unit_cost`;
DELIMITER $$
CREATE PROCEDURE `sp_fr6_ensure_unit_cost`()
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = DATABASE()
          AND table_name = 'products'
          AND column_name = 'unit_cost'
    ) THEN
        ALTER TABLE `products`
            ADD COLUMN `unit_cost` DECIMAL(12,2) NOT NULL DEFAULT 0.00 AFTER `unit_price`;
    END IF;
END$$
DELIMITER ;
CALL `sp_fr6_ensure_unit_cost`();
DROP PROCEDURE IF EXISTS `sp_fr6_ensure_unit_cost`;

-- Report products with no configured cost. No 65% estimate is assigned.
SELECT product_id, sku, product_name, unit_price, unit_cost
FROM products
WHERE unit_cost IS NULL OR unit_cost <= 0
ORDER BY owner_company_id, product_id;

-- Shipment costs are real operational values. Do not seed made-up costs.
CREATE TABLE IF NOT EXISTS `shipment_costs` (
    `cost_id` BIGINT AUTO_INCREMENT PRIMARY KEY,
    `shipment_id` INT NOT NULL,
    `cost_type` ENUM('FREIGHT','PORT','HANDLING','CUSTOMS','INSURANCE','OTHER') NOT NULL,
    `amount` DECIMAL(14,2) NOT NULL DEFAULT 0.00,
    `description` VARCHAR(255) NULL,
    `cost_date` DATE NOT NULL,
    `recorded_by` INT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT `chk_fr6_shipment_cost_nonnegative` CHECK (`amount` >= 0.00),
    CONSTRAINT `fk_fr6_shipment_cost_shipment` FOREIGN KEY (`shipment_id`)
        REFERENCES `shipment`(`shipment_id`) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT `fk_fr6_shipment_cost_user` FOREIGN KEY (`recorded_by`)
        REFERENCES `users`(`user_id`) ON DELETE SET NULL ON UPDATE CASCADE,
    INDEX `idx_fr6_shipment_cost_date` (`shipment_id`, `cost_date`, `cost_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Ensure shipment_stock_reservations exists for available inventory calculations
CREATE TABLE IF NOT EXISTS `shipment_stock_reservations` (
    `reservation_id` BIGINT AUTO_INCREMENT PRIMARY KEY,
    `shipment_id` INT NOT NULL,
    `product_id` INT NOT NULL,
    `reserved_quantity` INT NOT NULL,
    `status` ENUM('RESERVED','CONSUMED','RELEASED') NOT NULL DEFAULT 'RESERVED',
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_ssr_prod_status` (`product_id`, `status`),
    INDEX `idx_ssr_shipment` (`shipment_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================================
-- SECTION 1: FR6 RESULT TABLES
-- =============================================================================

-- The following five are the SRS Section 7.9 tables. CREATE IF NOT EXISTS
-- preserves the existing master definitions and existing data.
CREATE TABLE IF NOT EXISTS `sales_trend_result` (
    `result_id` INT AUTO_INCREMENT PRIMARY KEY,
    `period_month` DATE NOT NULL,
    `origin_port_id` INT NULL,
    `dest_port_id` INT NULL,
    `total_sales` DECIMAL(14,2) NOT NULL DEFAULT 0.00,
    `total_qty` INT NOT NULL DEFAULT 0,
    `growth_pct` DECIMAL(6,2) NOT NULL DEFAULT 0.00,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT `fk_fr6_sales_origin_port` FOREIGN KEY (`origin_port_id`) REFERENCES `ports`(`port_id`) ON DELETE SET NULL,
    CONSTRAINT `fk_fr6_sales_dest_port` FOREIGN KEY (`dest_port_id`) REFERENCES `ports`(`port_id`) ON DELETE SET NULL,
    CONSTRAINT `chk_fr6_sales_total_nonnegative` CHECK (`total_sales` >= 0.00 AND `total_qty` >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `abc_classification_result` (
    `result_id` INT AUTO_INCREMENT PRIMARY KEY,
    `product_id` INT NOT NULL,
    `annual_value` DECIMAL(14,2) NOT NULL DEFAULT 0.00,
    `cumulative_pct` DECIMAL(5,2) NOT NULL DEFAULT 0.00,
    `abc_class` CHAR(1) NOT NULL,
    `calculated_on` DATE NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT `fk_fr6_abc_product` FOREIGN KEY (`product_id`) REFERENCES `products`(`product_id`) ON DELETE CASCADE,
    CONSTRAINT `chk_fr6_abc_class` CHECK (`abc_class` IN ('A','B','C')),
    CONSTRAINT `chk_fr6_abc_pct` CHECK (`cumulative_pct` BETWEEN 0.00 AND 100.00)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `inventory_turnover_result` (
    `result_id` INT AUTO_INCREMENT PRIMARY KEY,
    `product_id` INT NOT NULL,
    `period_start` DATE NOT NULL,
    `period_end` DATE NOT NULL,
    `cogs` DECIMAL(14,2) NOT NULL DEFAULT 0.00,
    `avg_inventory` DECIMAL(14,2) NOT NULL DEFAULT 0.00,
    `turnover_ratio` DECIMAL(8,2) NOT NULL DEFAULT 0.00,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT `fk_fr6_turnover_product` FOREIGN KEY (`product_id`) REFERENCES `products`(`product_id`) ON DELETE CASCADE,
    CONSTRAINT `chk_fr6_turnover_dates` CHECK (`period_start` <= `period_end`),
    CONSTRAINT `chk_fr6_turnover_values` CHECK (`cogs` >= 0.00 AND `avg_inventory` >= 0.00 AND `turnover_ratio` >= 0.00)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `profitability_result` (
    `result_id` INT AUTO_INCREMENT PRIMARY KEY,
    `product_id` INT NOT NULL,
    `period_month` DATE NOT NULL,
    `revenue` DECIMAL(14,2) NOT NULL DEFAULT 0.00,
    `cost` DECIMAL(14,2) NOT NULL DEFAULT 0.00,
    `margin_pct` DECIMAL(6,2) NOT NULL DEFAULT 0.00,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT `fk_fr6_profitability_product` FOREIGN KEY (`product_id`) REFERENCES `products`(`product_id`) ON DELETE CASCADE,
    CONSTRAINT `chk_fr6_profitability_values` CHECK (`revenue` >= 0.00 AND `cost` >= 0.00)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- SRS 7.9 seller_id references companies, because shipment.seller_id is a
-- company_id (not users.user_id).
CREATE TABLE IF NOT EXISTS `profit_loss` (
    `pl_id` INT AUTO_INCREMENT PRIMARY KEY,
    `shipment_id` INT NULL,
    `seller_id` INT NOT NULL,
    `period_month` DATE NOT NULL COMMENT 'First day of month',
    `revenue` DECIMAL(14,2) NOT NULL DEFAULT 0.00,
    `freight_cost` DECIMAL(14,2) NOT NULL DEFAULT 0.00,
    `port_cost` DECIMAL(14,2) NOT NULL DEFAULT 0.00,
    `handling_cost` DECIMAL(14,2) NOT NULL DEFAULT 0.00,
    `claim_loss` DECIMAL(14,2) NOT NULL DEFAULT 0.00,
    `net_profit` DECIMAL(14,2) GENERATED ALWAYS AS
        (`revenue` - `freight_cost` - `port_cost` - `handling_cost` - `claim_loss`) STORED,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT `fk_fr6_pl_shipment` FOREIGN KEY (`shipment_id`) REFERENCES `shipment`(`shipment_id`) ON DELETE SET NULL,
    CONSTRAINT `fk_fr6_pl_seller_company` FOREIGN KEY (`seller_id`) REFERENCES `companies`(`company_id`) ON DELETE RESTRICT,
    CONSTRAINT `chk_fr6_pl_amounts` CHECK (`revenue` >= 0 AND `freight_cost` >= 0 AND `port_cost` >= 0 AND `handling_cost` >= 0 AND `claim_loss` >= 0),
    UNIQUE KEY `uq_profit_loss_shipment_month` (`shipment_id`,`period_month`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Ensure an existing profit_loss.net_profit column is a generated column.
DROP PROCEDURE IF EXISTS `sp_fr6_ensure_generated_net_profit`;
DELIMITER $$
CREATE PROCEDURE `sp_fr6_ensure_generated_net_profit`()
BEGIN
    DECLARE v_extra VARCHAR(100) DEFAULT '';
    SELECT COALESCE(MAX(`EXTRA`), '') INTO v_extra
    FROM information_schema.columns
    WHERE table_schema = DATABASE()
      AND table_name = 'profit_loss'
      AND column_name = 'net_profit';

    IF v_extra NOT LIKE '%GENERATED%' THEN
        ALTER TABLE `profit_loss`
            MODIFY COLUMN `net_profit` DECIMAL(14,2)
            GENERATED ALWAYS AS (`revenue` - `freight_cost` - `port_cost` - `handling_cost` - `claim_loss`) STORED;
    END IF;
END$$
DELIMITER ;
CALL `sp_fr6_ensure_generated_net_profit`();
DROP PROCEDURE IF EXISTS `sp_fr6_ensure_generated_net_profit`;

-- Demand forecast remains part of FR6.6 / SRS 7.5, even though AI/ML is excluded.
CREATE TABLE IF NOT EXISTS `demand_forecast` (
    `forecast_id` INT AUTO_INCREMENT PRIMARY KEY,
    `origin_port_id` INT NOT NULL,
    `dest_port_id` INT NOT NULL,
    `container_type` ENUM('DRY','REEFER','OPEN_TOP','TANK') NOT NULL,
    `forecast_month` DATE NOT NULL,
    `predicted_bookings` INT NOT NULL DEFAULT 0,
    `confidence_pct` DECIMAL(5,2) NOT NULL DEFAULT 0.00,
    `suggested_multiplier` DECIMAL(4,2) NOT NULL DEFAULT 1.00,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT `fk_fr6_df_origin` FOREIGN KEY (`origin_port_id`) REFERENCES `ports`(`port_id`) ON DELETE CASCADE,
    CONSTRAINT `fk_fr6_df_dest` FOREIGN KEY (`dest_port_id`) REFERENCES `ports`(`port_id`) ON DELETE CASCADE,
    CONSTRAINT `chk_fr6_df_values` CHECK (`predicted_bookings` >= 0 AND `confidence_pct` BETWEEN 0 AND 100 AND `suggested_multiplier` > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Supporting result tables needed to satisfy FR6.2, FR6.3 and FR6.5 dimensions.
CREATE TABLE IF NOT EXISTS `customer_abc_classification_result` (
    `result_id` INT AUTO_INCREMENT PRIMARY KEY,
    `customer_id` INT NOT NULL,
    `annual_value` DECIMAL(14,2) NOT NULL DEFAULT 0.00,
    `cumulative_pct` DECIMAL(5,2) NOT NULL DEFAULT 0.00,
    `abc_class` CHAR(1) NOT NULL,
    `calculated_on` DATE NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT `fk_fr6_customer_abc_customer` FOREIGN KEY (`customer_id`) REFERENCES `customers`(`customer_id`) ON DELETE CASCADE,
    CONSTRAINT `chk_fr6_customer_abc_class` CHECK (`abc_class` IN ('A','B','C')),
    CONSTRAINT `chk_fr6_customer_abc_pct` CHECK (`cumulative_pct` BETWEEN 0 AND 100)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `sales_trend_product_result` (
    `result_id` INT AUTO_INCREMENT PRIMARY KEY,
    `product_id` INT NOT NULL,
    `period_month` DATE NOT NULL,
    `total_sales` DECIMAL(14,2) NOT NULL DEFAULT 0.00,
    `total_qty` INT NOT NULL DEFAULT 0,
    `growth_pct` DECIMAL(6,2) NOT NULL DEFAULT 0.00,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT `fk_fr6_st_product` FOREIGN KEY (`product_id`) REFERENCES `products`(`product_id`) ON DELETE CASCADE,
    CONSTRAINT `chk_fr6_st_product_values` CHECK (`total_sales` >= 0 AND `total_qty` >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `sales_trend_customer_result` (
    `result_id` INT AUTO_INCREMENT PRIMARY KEY,
    `customer_id` INT NOT NULL,
    `period_month` DATE NOT NULL,
    `total_sales` DECIMAL(14,2) NOT NULL DEFAULT 0.00,
    `total_qty` INT NOT NULL DEFAULT 0,
    `growth_pct` DECIMAL(6,2) NOT NULL DEFAULT 0.00,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT `fk_fr6_st_customer` FOREIGN KEY (`customer_id`) REFERENCES `customers`(`customer_id`) ON DELETE CASCADE,
    CONSTRAINT `chk_fr6_st_customer_values` CHECK (`total_sales` >= 0 AND `total_qty` >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `shipment_profitability_result` (
    `result_id` INT AUTO_INCREMENT PRIMARY KEY,
    `shipment_id` INT NOT NULL,
    `seller_id` INT NOT NULL COMMENT 'company_id matching shipment.seller_id',
    `period_month` DATE NOT NULL,
    `revenue` DECIMAL(14,2) NOT NULL DEFAULT 0.00,
    `cost` DECIMAL(14,2) NOT NULL DEFAULT 0.00,
    `margin_pct` DECIMAL(6,2) NOT NULL DEFAULT 0.00,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT `fk_fr6_ship_profit_shipment` FOREIGN KEY (`shipment_id`) REFERENCES `shipment`(`shipment_id`) ON DELETE CASCADE,
    CONSTRAINT `fk_fr6_ship_profit_seller` FOREIGN KEY (`seller_id`) REFERENCES `companies`(`company_id`) ON DELETE RESTRICT,
    CONSTRAINT `chk_fr6_ship_profit_values` CHECK (`revenue` >= 0 AND `cost` >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Normalize seller_id FKs to companies.company_id. Shipment.seller_id is a company_id.
-- Drop an incorrect FK first (if an earlier draft pointed seller_id at users),
-- then reconcile shipment-linked rows, and finally add/verify the companies FK.
DROP PROCEDURE IF EXISTS `sp_fr6_drop_wrong_company_seller_fk`;
DELIMITER //
CREATE PROCEDURE `sp_fr6_drop_wrong_company_seller_fk`(IN p_table_name VARCHAR(64))
BEGIN
    DECLARE v_fk_name VARCHAR(64) DEFAULT NULL;
    DECLARE v_ref_table VARCHAR(64) DEFAULT NULL;
    DECLARE v_count INT DEFAULT 0;
    SELECT COUNT(*) INTO v_count
    FROM information_schema.key_column_usage
    WHERE table_schema = DATABASE() AND table_name = p_table_name
      AND column_name = 'seller_id' AND referenced_table_name IS NOT NULL;
    IF v_count > 0 THEN
        SELECT constraint_name, referenced_table_name
          INTO v_fk_name, v_ref_table
        FROM information_schema.key_column_usage
        WHERE table_schema = DATABASE() AND table_name = p_table_name
          AND column_name = 'seller_id' AND referenced_table_name IS NOT NULL
        LIMIT 1;
        IF v_ref_table <> 'companies' THEN
            SET @fr6_fk_ddl = CONCAT('ALTER TABLE `', REPLACE(p_table_name,'`',''), '` DROP FOREIGN KEY `', REPLACE(v_fk_name,'`',''), '`');
            PREPARE fr6_fk_stmt FROM @fr6_fk_ddl;
            EXECUTE fr6_fk_stmt;
            DEALLOCATE PREPARE fr6_fk_stmt;
        END IF;
    END IF;
END//
DELIMITER ;
CALL `sp_fr6_drop_wrong_company_seller_fk`('profit_loss');
CALL `sp_fr6_drop_wrong_company_seller_fk`('shipment_profitability_result');
DROP PROCEDURE IF EXISTS `sp_fr6_drop_wrong_company_seller_fk`;

UPDATE profit_loss pl
JOIN shipment s ON s.shipment_id = pl.shipment_id
SET pl.seller_id = s.seller_id
WHERE pl.seller_id <> s.seller_id;

UPDATE shipment_profitability_result spr
JOIN shipment s ON s.shipment_id = spr.shipment_id
SET spr.seller_id = s.seller_id
WHERE spr.seller_id <> s.seller_id;

-- Investigate any remaining rows before adding the company FK. These should
-- return zero rows; seller-level rows with shipment_id NULL need valid company_id.
SELECT 'P&L seller IDs without a matching company' AS check_name, pl.pl_id AS record_id, pl.seller_id
FROM profit_loss pl
LEFT JOIN companies c ON c.company_id = pl.seller_id
WHERE c.company_id IS NULL
UNION ALL
SELECT 'Shipment profitability seller IDs without a matching company', spr.result_id, spr.seller_id
FROM shipment_profitability_result spr
LEFT JOIN companies c ON c.company_id = spr.seller_id
WHERE c.company_id IS NULL;

DROP PROCEDURE IF EXISTS `sp_fr6_ensure_company_seller_fk`;
DELIMITER //
CREATE PROCEDURE `sp_fr6_ensure_company_seller_fk`(IN p_table_name VARCHAR(64), IN p_new_fk_name VARCHAR(64))
BEGIN
    DECLARE v_fk_name VARCHAR(64) DEFAULT NULL;
    DECLARE v_ref_table VARCHAR(64) DEFAULT NULL;
    DECLARE v_count INT DEFAULT 0;
    SELECT COUNT(*) INTO v_count
    FROM information_schema.key_column_usage
    WHERE table_schema = DATABASE() AND table_name = p_table_name
      AND column_name = 'seller_id' AND referenced_table_name IS NOT NULL;
    IF v_count > 0 THEN
        SELECT constraint_name, referenced_table_name
          INTO v_fk_name, v_ref_table
        FROM information_schema.key_column_usage
        WHERE table_schema = DATABASE() AND table_name = p_table_name
          AND column_name = 'seller_id' AND referenced_table_name IS NOT NULL
        LIMIT 1;
    END IF;
    IF v_count = 0 OR v_ref_table <> 'companies' THEN
        SET @fr6_fk_ddl = CONCAT('ALTER TABLE `', REPLACE(p_table_name,'`',''), '` ADD CONSTRAINT `', REPLACE(p_new_fk_name,'`',''), '` FOREIGN KEY (`seller_id`) REFERENCES `companies`(`company_id`) ON DELETE RESTRICT ON UPDATE CASCADE');
        PREPARE fr6_fk_stmt FROM @fr6_fk_ddl;
        EXECUTE fr6_fk_stmt;
        DEALLOCATE PREPARE fr6_fk_stmt;
    END IF;
END//
DELIMITER ;
CALL `sp_fr6_ensure_company_seller_fk`('profit_loss','fk_fr6_pl_seller_company');
CALL `sp_fr6_ensure_company_seller_fk`('shipment_profitability_result','fk_fr6_ship_profit_seller');
DROP PROCEDURE IF EXISTS `sp_fr6_ensure_company_seller_fk`;

-- FR6.7 cache freshness state. This is not an audit/event log; it is a refresh flag.
CREATE TABLE IF NOT EXISTS `analytics_staleness` (
    `module_name` VARCHAR(40) PRIMARY KEY,
    `is_stale` TINYINT(1) NOT NULL DEFAULT 1,
    `last_refreshed_at` TIMESTAMP NULL,
    `stale_reason` VARCHAR(255) NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO `analytics_staleness` (`module_name`, `is_stale`, `stale_reason`) VALUES
('sales_trends',1,'Initial load'),
('abc_classification',1,'Initial load'),
('inventory_turnover',1,'Initial load'),
('profitability',1,'Initial load'),
('shipment_profitability',1,'Initial load'),
('profit_loss',1,'Initial load'),
('demand_forecast',1,'Initial load')
ON DUPLICATE KEY UPDATE `module_name` = VALUES(`module_name`);

-- =============================================================================
-- SECTION 2: UNIQUE KEYS AND REPORTING INDEXES
-- =============================================================================

-- Drop duplicate cached rows before adding their natural unique keys.
-- These are derived/cache tables; latest result_id is retained.
DELETE newer FROM `sales_trend_result` newer
JOIN `sales_trend_result` older
  ON newer.period_month = older.period_month
 AND newer.origin_port_id = older.origin_port_id
 AND newer.dest_port_id = older.dest_port_id
 AND newer.result_id > older.result_id
WHERE newer.origin_port_id IS NOT NULL AND newer.dest_port_id IS NOT NULL;

DELETE newer FROM `abc_classification_result` newer
JOIN `abc_classification_result` older
  ON newer.product_id = older.product_id
 AND newer.calculated_on = older.calculated_on
 AND newer.result_id > older.result_id;

DELETE newer FROM `inventory_turnover_result` newer
JOIN `inventory_turnover_result` older
  ON newer.product_id = older.product_id
 AND newer.period_start = older.period_start
 AND newer.period_end = older.period_end
 AND newer.result_id > older.result_id;

DELETE newer FROM `profitability_result` newer
JOIN `profitability_result` older
  ON newer.product_id = older.product_id
 AND newer.period_month = older.period_month
 AND newer.result_id > older.result_id;

DELETE newer FROM `customer_abc_classification_result` newer
JOIN `customer_abc_classification_result` older
  ON newer.customer_id = older.customer_id
 AND newer.calculated_on = older.calculated_on
 AND newer.result_id > older.result_id;

DELETE newer FROM `sales_trend_product_result` newer
JOIN `sales_trend_product_result` older
  ON newer.product_id = older.product_id
 AND newer.period_month = older.period_month
 AND newer.result_id > older.result_id;

DELETE newer FROM `sales_trend_customer_result` newer
JOIN `sales_trend_customer_result` older
  ON newer.customer_id = older.customer_id
 AND newer.period_month = older.period_month
 AND newer.result_id > older.result_id;

DELETE newer FROM `shipment_profitability_result` newer
JOIN `shipment_profitability_result` older
  ON newer.shipment_id = older.shipment_id
 AND newer.period_month = older.period_month
 AND newer.result_id > older.result_id;

DELETE newer FROM `demand_forecast` newer
JOIN `demand_forecast` older
  ON newer.origin_port_id = older.origin_port_id
 AND newer.dest_port_id = older.dest_port_id
 AND newer.container_type = older.container_type
 AND newer.forecast_month = older.forecast_month
 AND newer.forecast_id > older.forecast_id;

DELETE newer FROM `profit_loss` newer
JOIN `profit_loss` older
  ON newer.shipment_id = older.shipment_id
 AND newer.period_month = older.period_month
 AND newer.pl_id > older.pl_id
WHERE newer.shipment_id IS NOT NULL;

DROP PROCEDURE IF EXISTS `sp_fr6_add_index_if_missing`;
DELIMITER $$
CREATE PROCEDURE `sp_fr6_add_index_if_missing`(
    IN p_table VARCHAR(64), IN p_index VARCHAR(64),
    IN p_columns VARCHAR(255), IN p_unique TINYINT
)
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.statistics
        WHERE table_schema = DATABASE() AND table_name = p_table AND index_name = p_index
    ) THEN
        SET @fr6_ddl = CONCAT('ALTER TABLE `', REPLACE(p_table,'`',''), '` ADD ',
            IF(p_unique = 1, 'UNIQUE ', ''), 'INDEX `', REPLACE(p_index,'`',''), '` (', p_columns, ')');
        PREPARE fr6_stmt FROM @fr6_ddl;
        EXECUTE fr6_stmt;
        DEALLOCATE PREPARE fr6_stmt;
    END IF;
END$$
DELIMITER ;

-- Natural keys required by the upsert procedures.
CALL `sp_fr6_add_index_if_missing`('sales_trend_result','uq_fr6_sales_route_month','`period_month`,`origin_port_id`,`dest_port_id`',1);
CALL `sp_fr6_add_index_if_missing`('abc_classification_result','uq_fr6_abc_product_date','`product_id`,`calculated_on`',1);
CALL `sp_fr6_add_index_if_missing`('inventory_turnover_result','uq_fr6_turnover_period','`product_id`,`period_start`,`period_end`',1);
CALL `sp_fr6_add_index_if_missing`('profitability_result','uq_fr6_profitability_month','`product_id`,`period_month`',1);
CALL `sp_fr6_add_index_if_missing`('demand_forecast','uq_fr6_forecast_route_month','`origin_port_id`,`dest_port_id`,`container_type`,`forecast_month`',1);
CALL `sp_fr6_add_index_if_missing`('profit_loss','uq_profit_loss_shipment_month','`shipment_id`,`period_month`',1);
CALL `sp_fr6_add_index_if_missing`('customer_abc_classification_result','uq_fr6_customer_abc_date','`customer_id`,`calculated_on`',1);
CALL `sp_fr6_add_index_if_missing`('sales_trend_product_result','uq_fr6_product_trend_month','`product_id`,`period_month`',1);
CALL `sp_fr6_add_index_if_missing`('sales_trend_customer_result','uq_fr6_customer_trend_month','`customer_id`,`period_month`',1);
CALL `sp_fr6_add_index_if_missing`('shipment_profitability_result','uq_fr6_shipment_profit_month','`shipment_id`,`period_month`',1);

-- Query indexes (the helper skips indexes that already exist under these names).
CALL `sp_fr6_add_index_if_missing`('sales_transactions','idx_fr6_sales_date_product','`sale_date`,`product_id`',0);
CALL `sp_fr6_add_index_if_missing`('sales_transactions','idx_fr6_sales_date_customer','`sale_date`,`customer_id`',0);
CALL `sp_fr6_add_index_if_missing`('sales_transactions','idx_fr6_sales_shipment_date','`shipment_id`,`sale_date`',0);
CALL `sp_fr6_add_index_if_missing`('profitability_result','idx_fr6_profit_prod_month','`product_id`,`period_month`',0);
CALL `sp_fr6_add_index_if_missing`('inventory_turnover_result','idx_fr6_turnover_prod_dates','`product_id`,`period_start`,`period_end`',0);
CALL `sp_fr6_add_index_if_missing`('shipment_profitability_result','idx_fr6_ship_profit_seller_month','`seller_id`,`period_month`',0);
DROP PROCEDURE IF EXISTS `sp_fr6_add_index_if_missing`;

-- =============================================================================
-- SECTION 3: LIVE AND CACHED REPORTING VIEWS
-- =============================================================================

CREATE OR REPLACE VIEW `vw_fr6_kpi_live` AS
SELECT
    (SELECT COUNT(*) FROM shipment WHERE status NOT IN ('CANCELLED','DELIVERED')) AS active_shipments,
    (SELECT COUNT(*) FROM containers WHERE status = 'AVAILABLE') AS available_containers,
    (SELECT COALESCE(SUM(paid_amount),0.00) FROM billing_invoices) AS revenue_collected,
    (SELECT COALESCE(SUM(total_amount - paid_amount),0.00) FROM billing_invoices WHERE status <> 'PAID') AS pending_invoices,
    (SELECT COUNT(*) FROM claims WHERE status IN ('SUBMITTED','UNDER_REVIEW')) AS open_claims;

CREATE OR REPLACE VIEW `vw_fr6_sales_route_live` AS
SELECT
    STR_TO_DATE(DATE_FORMAT(st.sale_date,'%Y-%m-01'),'%Y-%m-%d') AS period_month,
    s.origin_port_id, op.port_name AS origin_port,
    s.dest_port_id, dp.port_name AS destination_port,
    SUM(st.total_amount) AS total_sales,
    SUM(st.quantity) AS total_quantity
FROM sales_transactions st
JOIN shipment s ON s.shipment_id = st.shipment_id
JOIN ports op ON op.port_id = s.origin_port_id
JOIN ports dp ON dp.port_id = s.dest_port_id
GROUP BY STR_TO_DATE(DATE_FORMAT(st.sale_date,'%Y-%m-01'),'%Y-%m-%d'),
         s.origin_port_id, op.port_name, s.dest_port_id, dp.port_name;

CREATE OR REPLACE VIEW `vw_fr6_sales_product_live` AS
SELECT
    STR_TO_DATE(DATE_FORMAT(st.sale_date,'%Y-%m-01'),'%Y-%m-%d') AS period_month,
    p.product_id, p.sku, p.product_name, p.category, p.owner_company_id,
    SUM(st.total_amount) AS total_sales, SUM(st.quantity) AS total_quantity
FROM sales_transactions st
JOIN products p ON p.product_id = st.product_id
GROUP BY STR_TO_DATE(DATE_FORMAT(st.sale_date,'%Y-%m-01'),'%Y-%m-%d'),
         p.product_id, p.sku, p.product_name, p.category, p.owner_company_id;

CREATE OR REPLACE VIEW `vw_fr6_sales_customer_live` AS
SELECT
    STR_TO_DATE(DATE_FORMAT(st.sale_date,'%Y-%m-01'),'%Y-%m-%d') AS period_month,
    cu.customer_id, u.full_name AS customer_name,
    SUM(st.total_amount) AS total_sales, SUM(st.quantity) AS total_quantity
FROM sales_transactions st
JOIN customers cu ON cu.customer_id = st.customer_id
JOIN users u ON u.user_id = cu.user_id
GROUP BY STR_TO_DATE(DATE_FORMAT(st.sale_date,'%Y-%m-01'),'%Y-%m-%d'),
         cu.customer_id, u.full_name;

CREATE OR REPLACE VIEW `vw_fr6_inventory_live` AS
SELECT
    p.product_id, p.sku, p.product_name, p.category,
    c.company_id AS seller_id, c.company_name AS seller_name,
    COALESCE(stk.on_hand_qty,0) AS on_hand_qty,
    COALESCE(stk.damaged_qty,0) AS damaged_qty,
    COALESCE(res.reserved_qty,0) AS reserved_qty,
    COALESCE(stk.on_hand_qty,0) - COALESCE(stk.damaged_qty,0) - COALESCE(res.reserved_qty,0) AS available_qty,
    p.unit_price, p.unit_cost,
    ROUND((COALESCE(stk.on_hand_qty,0) - COALESCE(stk.damaged_qty,0)) * p.unit_price,2) AS market_value,
    ROUND((COALESCE(stk.on_hand_qty,0) - COALESCE(stk.damaged_qty,0)) * p.unit_cost,2) AS cost_value
FROM products p
JOIN companies c ON c.company_id = p.owner_company_id
LEFT JOIN (
    SELECT product_id, SUM(quantity) AS on_hand_qty,
           SUM(damaged_qty) AS damaged_qty
    FROM stock
    GROUP BY product_id
) stk ON stk.product_id = p.product_id
LEFT JOIN (
    SELECT product_id, SUM(reserved_quantity) AS reserved_qty
    FROM shipment_stock_reservations
    WHERE status = 'RESERVED'
    GROUP BY product_id
) res ON res.product_id = p.product_id;

-- Live shipment profitability uses actual payment, shipment-cost and settled-claim data.
-- Seller id is company_id, matching shipment.seller_id.
CREATE OR REPLACE VIEW `vw_fr6_shipment_profitability_live` AS
SELECT
    s.shipment_id, s.shipment_no, s.seller_id, c.company_name AS seller_name,
    STR_TO_DATE(DATE_FORMAT(s.created_at,'%Y-%m-01'),'%Y-%m-%d') AS period_month,
    COALESCE((SELECT SUM(py.amount)
              FROM billing_invoices bi JOIN payments py ON py.invoice_id = bi.invoice_id
              WHERE bi.shipment_id = s.shipment_id),0.00) AS paid_revenue,
    COALESCE((SELECT SUM(si.quantity * p.unit_cost)
              FROM shipment_items si JOIN products p ON p.product_id = si.product_id
              WHERE si.shipment_id = s.shipment_id),0.00) AS goods_cogs,
    COALESCE((SELECT SUM(sc.amount) FROM shipment_costs sc WHERE sc.shipment_id = s.shipment_id),0.00) AS actual_shipment_costs,
    COALESCE((SELECT SUM(cl.approved_amount) FROM claims cl
              WHERE cl.shipment_id = s.shipment_id AND cl.status = 'SETTLED'),0.00) AS settled_claim_loss,
    COALESCE((SELECT SUM(si.quantity * p.unit_cost)
              FROM shipment_items si JOIN products p ON p.product_id = si.product_id
              WHERE si.shipment_id = s.shipment_id),0.00)
      + COALESCE((SELECT SUM(sc.amount) FROM shipment_costs sc WHERE sc.shipment_id = s.shipment_id),0.00)
      + COALESCE((SELECT SUM(cl.approved_amount) FROM claims cl
                  WHERE cl.shipment_id = s.shipment_id AND cl.status = 'SETTLED'),0.00) AS total_cost,
    COALESCE((SELECT SUM(py.amount)
              FROM billing_invoices bi JOIN payments py ON py.invoice_id = bi.invoice_id
              WHERE bi.shipment_id = s.shipment_id),0.00)
      - COALESCE((SELECT SUM(si.quantity * p.unit_cost)
                  FROM shipment_items si JOIN products p ON p.product_id = si.product_id
                  WHERE si.shipment_id = s.shipment_id),0.00)
      - COALESCE((SELECT SUM(sc.amount) FROM shipment_costs sc WHERE sc.shipment_id = s.shipment_id),0.00)
      - COALESCE((SELECT SUM(cl.approved_amount) FROM claims cl
                  WHERE cl.shipment_id = s.shipment_id AND cl.status = 'SETTLED'),0.00) AS net_profit,
    CASE
      WHEN COALESCE((SELECT SUM(py.amount)
                     FROM billing_invoices bi JOIN payments py ON py.invoice_id = bi.invoice_id
                     WHERE bi.shipment_id = s.shipment_id),0.00) > 0
      THEN ROUND((
          COALESCE((SELECT SUM(py.amount)
                    FROM billing_invoices bi JOIN payments py ON py.invoice_id = bi.invoice_id
                    WHERE bi.shipment_id = s.shipment_id),0.00)
          - COALESCE((SELECT SUM(si.quantity * p.unit_cost)
                      FROM shipment_items si JOIN products p ON p.product_id = si.product_id
                      WHERE si.shipment_id = s.shipment_id),0.00)
          - COALESCE((SELECT SUM(sc.amount) FROM shipment_costs sc WHERE sc.shipment_id = s.shipment_id),0.00)
          - COALESCE((SELECT SUM(cl.approved_amount) FROM claims cl
                      WHERE cl.shipment_id = s.shipment_id AND cl.status = 'SETTLED'),0.00)
      ) / (SELECT SUM(py.amount) FROM billing_invoices bi JOIN payments py ON py.invoice_id = bi.invoice_id
           WHERE bi.shipment_id = s.shipment_id) * 100,2)
      ELSE 0.00
    END AS margin_pct
FROM shipment s
JOIN companies c ON c.company_id = s.seller_id
WHERE s.status <> 'CANCELLED';

CREATE OR REPLACE VIEW `vw_fr6_seller_pnl_live` AS
SELECT
    pl.seller_id, c.company_name AS seller_name,
    s.shipment_no, pl.period_month,
    pl.revenue, pl.freight_cost, pl.port_cost, pl.handling_cost,
    pl.claim_loss, pl.net_profit
FROM profit_loss pl
JOIN companies c ON c.company_id = pl.seller_id
LEFT JOIN shipment s ON s.shipment_id = pl.shipment_id;

CREATE OR REPLACE VIEW `vw_fr6_demand_forecast_live` AS
SELECT df.forecast_id, df.origin_port_id, op.port_name AS origin, op.port_code AS origin_code,
       df.dest_port_id, dp.port_name AS destination, dp.port_code AS destination_code,
       df.container_type, df.forecast_month, df.predicted_bookings,
       df.confidence_pct, df.suggested_multiplier, df.created_at
FROM demand_forecast df
JOIN ports op ON op.port_id = df.origin_port_id
JOIN ports dp ON dp.port_id = df.dest_port_id;

CREATE OR REPLACE VIEW `vw_fr6_abc_product` AS
SELECT a.result_id, p.product_id, p.sku, p.product_name, p.category,
       c.company_name AS owner_company, a.annual_value, a.cumulative_pct,
       a.abc_class, a.calculated_on
FROM abc_classification_result a
JOIN products p ON p.product_id = a.product_id
JOIN companies c ON c.company_id = p.owner_company_id;

CREATE OR REPLACE VIEW `vw_fr6_abc_customer` AS
SELECT a.result_id, cu.customer_id, u.full_name AS customer_name,
       u.email AS customer_email, a.annual_value, a.cumulative_pct,
       a.abc_class, a.calculated_on
FROM customer_abc_classification_result a
JOIN customers cu ON cu.customer_id = a.customer_id
JOIN users u ON u.user_id = cu.user_id;

CREATE OR REPLACE VIEW `vw_fr6_inventory_turnover` AS
SELECT r.*, p.sku, p.product_name, p.category
FROM inventory_turnover_result r
JOIN products p ON p.product_id = r.product_id;

CREATE OR REPLACE VIEW `vw_fr6_product_profitability` AS
SELECT r.*, p.sku, p.product_name, p.category, p.owner_company_id
FROM profitability_result r
JOIN products p ON p.product_id = r.product_id;

CREATE OR REPLACE VIEW `vw_fr6_shipment_profitability` AS
SELECT r.*, s.shipment_no, c.company_name AS seller_name
FROM shipment_profitability_result r
JOIN shipment s ON s.shipment_id = r.shipment_id
JOIN companies c ON c.company_id = r.seller_id;

CREATE OR REPLACE VIEW `vw_fr6_sales_route_cached` AS
SELECT r.*, op.port_name AS origin_port, op.port_code AS origin_code,
       dp.port_name AS destination_port, dp.port_code AS destination_code
FROM sales_trend_result r
LEFT JOIN ports op ON op.port_id = r.origin_port_id
LEFT JOIN ports dp ON dp.port_id = r.dest_port_id;

CREATE OR REPLACE VIEW `vw_fr6_sales_product_cached` AS
SELECT r.*, p.sku, p.product_name, p.category
FROM sales_trend_product_result r
JOIN products p ON p.product_id = r.product_id;

CREATE OR REPLACE VIEW `vw_fr6_sales_customer_cached` AS
SELECT r.*, cu.user_id, u.full_name AS customer_name, u.email AS customer_email
FROM sales_trend_customer_result r
JOIN customers cu ON cu.customer_id = r.customer_id
JOIN users u ON u.user_id = cu.user_id;

CREATE OR REPLACE VIEW `vw_fr6_seller_pl_summary` AS
SELECT period_month, seller_id, seller_name,
       COUNT(shipment_no) AS total_shipments,
       SUM(revenue) AS total_paid_revenue,
       SUM(freight_cost) AS total_freight_cost,
       SUM(port_cost) AS total_port_cost,
       SUM(handling_cost) AS total_handling_cost,
       SUM(claim_loss) AS total_claim_loss,
       SUM(net_profit) AS net_profit,
       CASE WHEN SUM(revenue) > 0 THEN ROUND(SUM(net_profit) / SUM(revenue) * 100,2) ELSE 0.00 END AS margin_pct
FROM vw_fr6_seller_pnl_live
GROUP BY period_month, seller_id, seller_name;

-- =============================================================================
-- SECTION 4: ANALYTICS STORED PROCEDURES
-- =============================================================================

DROP PROCEDURE IF EXISTS `sp_refresh_sales_trends`;
DROP PROCEDURE IF EXISTS `sp_calculate_product_sales_trends`;
DROP PROCEDURE IF EXISTS `sp_calculate_customer_sales_trends`;
DROP PROCEDURE IF EXISTS `sp_calculate_abc_classification`;
DROP PROCEDURE IF EXISTS `sp_calculate_customer_abc`;
DROP PROCEDURE IF EXISTS `sp_calculate_inventory_turnover`;
DROP PROCEDURE IF EXISTS `sp_calculate_profitability`;
DROP PROCEDURE IF EXISTS `sp_calculate_shipment_profitability`;
DROP PROCEDURE IF EXISTS `sp_calculate_profit_loss`;
DROP PROCEDURE IF EXISTS `sp_generate_demand_forecast`;
DROP PROCEDURE IF EXISTS `sp_apply_forecast_pricing`;
DROP PROCEDURE IF EXISTS `sp_refresh_all_fr6_analytics`;
DROP PROCEDURE IF EXISTS `sp_refresh_fr6_if_stale`;

DELIMITER $$

CREATE PROCEDURE `sp_refresh_sales_trends`()
BEGIN
    DELETE FROM sales_trend_result;
    INSERT INTO sales_trend_result
        (period_month, origin_port_id, dest_port_id, total_sales, total_qty, growth_pct)
    SELECT period_month, origin_port_id, dest_port_id, total_sales, total_qty,
           CASE WHEN prev_sales IS NULL OR prev_sales = 0 THEN 0.00
                ELSE ROUND((total_sales - prev_sales) / prev_sales * 100, 2) END AS growth_pct
    FROM (
        SELECT period_month, origin_port_id, dest_port_id, total_sales, total_qty,
               LAG(total_sales) OVER (PARTITION BY origin_port_id, dest_port_id ORDER BY period_month) AS prev_sales
        FROM (
            SELECT STR_TO_DATE(DATE_FORMAT(st.sale_date, '%Y-%m-01'), '%Y-%m-%d') AS period_month,
                   s.origin_port_id, s.dest_port_id,
                   SUM(st.total_amount) AS total_sales,
                   SUM(st.quantity) AS total_qty
            FROM sales_transactions st
            JOIN shipment s ON s.shipment_id = st.shipment_id
            GROUP BY STR_TO_DATE(DATE_FORMAT(st.sale_date, '%Y-%m-01'), '%Y-%m-%d'),
                     s.origin_port_id, s.dest_port_id
        ) sub
    ) ranked;
END$$

CREATE PROCEDURE `sp_calculate_product_sales_trends`()
BEGIN
    DELETE FROM sales_trend_product_result;
    INSERT INTO sales_trend_product_result
        (product_id, period_month, total_sales, total_qty, growth_pct)
    SELECT product_id, period_month, total_sales, total_qty,
           CASE WHEN prev_sales IS NULL OR prev_sales = 0 THEN 0.00
                ELSE ROUND((total_sales - prev_sales) / prev_sales * 100, 2) END AS growth_pct
    FROM (
        SELECT product_id, period_month, total_sales, total_qty,
               LAG(total_sales) OVER (PARTITION BY product_id ORDER BY period_month) AS prev_sales
        FROM (
            SELECT st.product_id,
                   STR_TO_DATE(DATE_FORMAT(st.sale_date, '%Y-%m-01'), '%Y-%m-%d') AS period_month,
                   SUM(st.total_amount) AS total_sales,
                   SUM(st.quantity) AS total_qty
            FROM sales_transactions st
            GROUP BY st.product_id, STR_TO_DATE(DATE_FORMAT(st.sale_date, '%Y-%m-01'), '%Y-%m-%d')
        ) sub
    ) ranked;
END$$

CREATE PROCEDURE `sp_calculate_customer_sales_trends`()
BEGIN
    DELETE FROM sales_trend_customer_result;
    INSERT INTO sales_trend_customer_result
        (customer_id, period_month, total_sales, total_qty, growth_pct)
    SELECT customer_id, period_month, total_sales, total_qty,
           CASE WHEN prev_sales IS NULL OR prev_sales = 0 THEN 0.00
                ELSE ROUND((total_sales - prev_sales) / prev_sales * 100, 2) END AS growth_pct
    FROM (
        SELECT customer_id, period_month, total_sales, total_qty,
               LAG(total_sales) OVER (PARTITION BY customer_id ORDER BY period_month) AS prev_sales
        FROM (
            SELECT st.customer_id,
                   STR_TO_DATE(DATE_FORMAT(st.sale_date, '%Y-%m-01'), '%Y-%m-%d') AS period_month,
                   SUM(st.total_amount) AS total_sales,
                   SUM(st.quantity) AS total_qty
            FROM sales_transactions st
            GROUP BY st.customer_id, STR_TO_DATE(DATE_FORMAT(st.sale_date, '%Y-%m-01'), '%Y-%m-%d')
        ) sub
    ) ranked;
END$$

CREATE PROCEDURE `sp_calculate_abc_classification`()
BEGIN
    DECLARE v_from DATE;
    DECLARE v_total DECIMAL(18,2) DEFAULT 0.00;
    SET v_from = DATE_SUB(CURDATE(), INTERVAL 12 MONTH);

    SELECT COALESCE(SUM(total_amount),0.00) INTO v_total
    FROM sales_transactions
    WHERE sale_date >= v_from AND sale_date <= CURDATE();

    INSERT INTO abc_classification_result
        (product_id, annual_value, cumulative_pct, abc_class, calculated_on)
    SELECT product_id, annual_value, cumulative_pct,
           CASE WHEN v_total = 0 THEN 'C'
                WHEN cumulative_pct <= 70 THEN 'A'
                WHEN cumulative_pct <= 90 THEN 'B' ELSE 'C' END,
           CURDATE()
    FROM (
        SELECT ranked.product_id, ranked.annual_value,
               CASE WHEN v_total = 0 THEN 100.00
                    ELSE LEAST(100.00, ROUND(ranked.running_value / v_total * 100,2)) END AS cumulative_pct
        FROM (
            SELECT values_by_product.*,
                   SUM(values_by_product.annual_value) OVER
                     (ORDER BY values_by_product.annual_value DESC, values_by_product.product_id
                      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_value
            FROM (
                SELECT p.product_id, COALESCE(SUM(st.total_amount),0.00) AS annual_value
                FROM products p
                LEFT JOIN sales_transactions st
                  ON st.product_id = p.product_id
                 AND st.sale_date >= v_from AND st.sale_date <= CURDATE()
                GROUP BY p.product_id
            ) values_by_product
        ) ranked
    ) classified
    ON DUPLICATE KEY UPDATE
        annual_value = VALUES(annual_value), cumulative_pct = VALUES(cumulative_pct), abc_class = VALUES(abc_class);
END$$

CREATE PROCEDURE `sp_calculate_customer_abc`()
BEGIN
    DECLARE v_from DATE;
    DECLARE v_total DECIMAL(18,2) DEFAULT 0.00;
    SET v_from = DATE_SUB(CURDATE(), INTERVAL 12 MONTH);

    SELECT COALESCE(SUM(total_amount),0.00) INTO v_total
    FROM sales_transactions
    WHERE sale_date >= v_from AND sale_date <= CURDATE();

    INSERT INTO customer_abc_classification_result
        (customer_id, annual_value, cumulative_pct, abc_class, calculated_on)
    SELECT customer_id, annual_value, cumulative_pct,
           CASE WHEN v_total = 0 THEN 'C'
                WHEN cumulative_pct <= 70 THEN 'A'
                WHEN cumulative_pct <= 90 THEN 'B' ELSE 'C' END,
           CURDATE()
    FROM (
        SELECT ranked.customer_id, ranked.annual_value,
               CASE WHEN v_total = 0 THEN 100.00
                    ELSE LEAST(100.00, ROUND(ranked.running_value / v_total * 100,2)) END AS cumulative_pct
        FROM (
            SELECT values_by_customer.*,
                   SUM(values_by_customer.annual_value) OVER
                     (ORDER BY values_by_customer.annual_value DESC, values_by_customer.customer_id
                      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_value
            FROM (
                SELECT cu.customer_id, COALESCE(SUM(st.total_amount),0.00) AS annual_value
                FROM customers cu
                LEFT JOIN sales_transactions st
                  ON st.customer_id = cu.customer_id
                 AND st.sale_date >= v_from AND st.sale_date <= CURDATE()
                GROUP BY cu.customer_id
            ) values_by_customer
        ) ranked
    ) classified
    ON DUPLICATE KEY UPDATE
        annual_value = VALUES(annual_value), cumulative_pct = VALUES(cumulative_pct), abc_class = VALUES(abc_class);
END$$

CREATE PROCEDURE `sp_calculate_inventory_turnover`(IN p_start DATE, IN p_end DATE)
BEGIN
    IF p_start IS NULL THEN SET p_start = DATE_SUB(CURDATE(), INTERVAL 3 MONTH); END IF;
    IF p_end IS NULL THEN SET p_end = CURDATE(); END IF;
    IF p_start > p_end THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Inventory turnover start date must be on or before end date';
    END IF;

    DROP TEMPORARY TABLE IF EXISTS tmp_fr6_opening;
    DROP TEMPORARY TABLE IF EXISTS tmp_fr6_closing;
    DROP TEMPORARY TABLE IF EXISTS tmp_fr6_out_qty;

    CREATE TEMPORARY TABLE tmp_fr6_opening AS
    SELECT l.product_id, SUM(l.balance_after) AS opening_qty
    FROM inventory_ledger l
    JOIN (
        SELECT stock_id, MAX(ledger_id) AS last_ledger_id
        FROM inventory_ledger
        WHERE txn_time < p_start
        GROUP BY stock_id
    ) last_row ON last_row.last_ledger_id = l.ledger_id
    GROUP BY l.product_id;

    CREATE TEMPORARY TABLE tmp_fr6_closing AS
    SELECT l.product_id, SUM(l.balance_after) AS closing_qty
    FROM inventory_ledger l
    JOIN (
        SELECT stock_id, MAX(ledger_id) AS last_ledger_id
        FROM inventory_ledger
        WHERE txn_time < DATE_ADD(p_end, INTERVAL 1 DAY)
        GROUP BY stock_id
    ) last_row ON last_row.last_ledger_id = l.ledger_id
    GROUP BY l.product_id;

    CREATE TEMPORARY TABLE tmp_fr6_out_qty AS
    SELECT product_id, SUM(quantity) AS out_qty
    FROM inventory_ledger
    WHERE txn_type = 'OUT'
      AND txn_time >= p_start
      AND txn_time < DATE_ADD(p_end, INTERVAL 1 DAY)
    GROUP BY product_id;

    INSERT INTO inventory_turnover_result
        (product_id, period_start, period_end, cogs, avg_inventory, turnover_ratio)
    SELECT p.product_id, p_start, p_end,
           COALESCE(o.out_qty,0) * p.unit_cost AS cogs,
           ((COALESCE(op.opening_qty,0) + COALESCE(cl.closing_qty,0)) / 2) * p.unit_cost AS avg_inventory,
           CASE
             WHEN ((COALESCE(op.opening_qty,0) + COALESCE(cl.closing_qty,0)) / 2) * p.unit_cost = 0 THEN 0.00
             ELSE ROUND((COALESCE(o.out_qty,0) * p.unit_cost) /
                  (((COALESCE(op.opening_qty,0) + COALESCE(cl.closing_qty,0)) / 2) * p.unit_cost),2)
           END AS turnover_ratio
    FROM products p
    LEFT JOIN tmp_fr6_opening op ON op.product_id = p.product_id
    LEFT JOIN tmp_fr6_closing cl ON cl.product_id = p.product_id
    LEFT JOIN tmp_fr6_out_qty o ON o.product_id = p.product_id
    ON DUPLICATE KEY UPDATE
        cogs = VALUES(cogs), avg_inventory = VALUES(avg_inventory), turnover_ratio = VALUES(turnover_ratio);

    DROP TEMPORARY TABLE IF EXISTS tmp_fr6_opening;
    DROP TEMPORARY TABLE IF EXISTS tmp_fr6_closing;
    DROP TEMPORARY TABLE IF EXISTS tmp_fr6_out_qty;
END$$

CREATE PROCEDURE `sp_calculate_profitability`()
BEGIN
    DELETE FROM profitability_result;
    INSERT INTO profitability_result
        (product_id, period_month, revenue, cost, margin_pct)
    SELECT p.product_id,
           STR_TO_DATE(DATE_FORMAT(st.sale_date,'%Y-%m-01'),'%Y-%m-%d') AS period_month,
           SUM(st.total_amount) AS revenue,
           SUM(st.quantity * p.unit_cost) AS cost,
           CASE WHEN SUM(st.total_amount) > 0
                THEN ROUND((SUM(st.total_amount) - SUM(st.quantity * p.unit_cost)) / SUM(st.total_amount) * 100,2)
                ELSE 0.00 END AS margin_pct
    FROM sales_transactions st
    JOIN products p ON p.product_id = st.product_id
    GROUP BY p.product_id, STR_TO_DATE(DATE_FORMAT(st.sale_date,'%Y-%m-01'),'%Y-%m-%d')
    ON DUPLICATE KEY UPDATE
        revenue = VALUES(revenue), cost = VALUES(cost), margin_pct = VALUES(margin_pct);
END$$

-- Shipment-level profitability is a cumulative snapshot for the shipment's
-- booking month: paid receipts less goods COGS, recorded shipment costs and settled claims.
CREATE PROCEDURE `sp_calculate_shipment_profitability`()
BEGIN
    DELETE FROM shipment_profitability_result;
    INSERT INTO shipment_profitability_result
        (shipment_id, seller_id, period_month, revenue, cost, margin_pct)
    SELECT s.shipment_id, s.seller_id,
           STR_TO_DATE(DATE_FORMAT(s.created_at,'%Y-%m-01'),'%Y-%m-%d') AS period_month,
           COALESCE((SELECT SUM(py.amount)
                     FROM billing_invoices bi JOIN payments py ON py.invoice_id = bi.invoice_id
                     WHERE bi.shipment_id = s.shipment_id),0.00) AS revenue,
           COALESCE((SELECT SUM(si.quantity * p.unit_cost)
                         FROM shipment_items si JOIN products p ON p.product_id = si.product_id
                         WHERE si.shipment_id = s.shipment_id),0.00)
             + COALESCE((SELECT SUM(sc.amount) FROM shipment_costs sc WHERE sc.shipment_id = s.shipment_id),0.00)
             + COALESCE((SELECT SUM(cl.approved_amount) FROM claims cl
                         WHERE cl.shipment_id = s.shipment_id AND cl.status = 'SETTLED'),0.00) AS total_cost,
           CASE WHEN COALESCE((SELECT SUM(py.amount)
                               FROM billing_invoices bi JOIN payments py ON py.invoice_id = bi.invoice_id
                               WHERE bi.shipment_id = s.shipment_id),0.00) > 0
                THEN ROUND((
                    COALESCE((SELECT SUM(py.amount)
                              FROM billing_invoices bi JOIN payments py ON py.invoice_id = bi.invoice_id
                              WHERE bi.shipment_id = s.shipment_id),0.00)
                    - COALESCE((SELECT SUM(si.quantity * p.unit_cost)
                                FROM shipment_items si JOIN products p ON p.product_id = si.product_id
                                WHERE si.shipment_id = s.shipment_id),0.00)
                    - COALESCE((SELECT SUM(sc.amount) FROM shipment_costs sc WHERE sc.shipment_id = s.shipment_id),0.00)
                    - COALESCE((SELECT SUM(cl.approved_amount) FROM claims cl
                                WHERE cl.shipment_id = s.shipment_id AND cl.status = 'SETTLED'),0.00)
                ) / (SELECT SUM(py.amount) FROM billing_invoices bi JOIN payments py ON py.invoice_id = bi.invoice_id
                     WHERE bi.shipment_id = s.shipment_id) * 100,2)
                ELSE 0.00 END AS margin_pct
    FROM shipment s
    WHERE s.status <> 'CANCELLED'
    ON DUPLICATE KEY UPDATE
        seller_id = VALUES(seller_id), revenue = VALUES(revenue),
        cost = VALUES(cost), margin_pct = VALUES(margin_pct);
END$$

-- P&L is posted by financial event month. Revenue is actual payment receipts;
-- costs use shipment_costs; claim loss uses only SETTLED approved amounts.
CREATE PROCEDURE `sp_calculate_profit_loss`()
BEGIN
    DROP TEMPORARY TABLE IF EXISTS tmp_fr6_pl_revenue;
    DROP TEMPORARY TABLE IF EXISTS tmp_fr6_pl_costs;
    DROP TEMPORARY TABLE IF EXISTS tmp_fr6_pl_claims;
    DROP TEMPORARY TABLE IF EXISTS tmp_fr6_pl_keys;

    DELETE FROM profit_loss WHERE shipment_id IS NOT NULL;

    CREATE TEMPORARY TABLE tmp_fr6_pl_revenue AS
    SELECT s.shipment_id, s.seller_id,
           STR_TO_DATE(DATE_FORMAT(py.payment_date,'%Y-%m-01'),'%Y-%m-%d') AS period_month,
           SUM(py.amount) AS revenue
    FROM payments py
    JOIN billing_invoices bi ON bi.invoice_id = py.invoice_id
    JOIN shipment s ON s.shipment_id = bi.shipment_id
    GROUP BY s.shipment_id, s.seller_id,
             STR_TO_DATE(DATE_FORMAT(py.payment_date,'%Y-%m-01'),'%Y-%m-%d');

    CREATE TEMPORARY TABLE tmp_fr6_pl_costs AS
    SELECT s.shipment_id, s.seller_id,
           STR_TO_DATE(DATE_FORMAT(sc.cost_date,'%Y-%m-01'),'%Y-%m-%d') AS period_month,
           SUM(CASE WHEN sc.cost_type = 'FREIGHT' THEN sc.amount ELSE 0 END) AS freight_cost,
           SUM(CASE WHEN sc.cost_type = 'PORT' THEN sc.amount ELSE 0 END) AS port_cost,
           SUM(CASE WHEN sc.cost_type = 'HANDLING' THEN sc.amount ELSE 0 END) AS handling_cost
    FROM shipment_costs sc
    JOIN shipment s ON s.shipment_id = sc.shipment_id
    GROUP BY s.shipment_id, s.seller_id,
             STR_TO_DATE(DATE_FORMAT(sc.cost_date,'%Y-%m-01'),'%Y-%m-%d');

    CREATE TEMPORARY TABLE tmp_fr6_pl_claims AS
    SELECT s.shipment_id, s.seller_id,
           STR_TO_DATE(DATE_FORMAT(cl.settled_at,'%Y-%m-01'),'%Y-%m-%d') AS period_month,
           SUM(cl.approved_amount) AS claim_loss
    FROM claims cl
    JOIN shipment s ON s.shipment_id = cl.shipment_id
    WHERE cl.status = 'SETTLED' AND cl.settled_at IS NOT NULL
    GROUP BY s.shipment_id, s.seller_id,
             STR_TO_DATE(DATE_FORMAT(cl.settled_at,'%Y-%m-01'),'%Y-%m-%d');

    CREATE TEMPORARY TABLE tmp_fr6_pl_keys AS
    SELECT shipment_id, seller_id, period_month FROM tmp_fr6_pl_revenue
    UNION
    SELECT shipment_id, seller_id, period_month FROM tmp_fr6_pl_costs
    UNION
    SELECT shipment_id, seller_id, period_month FROM tmp_fr6_pl_claims;

    INSERT INTO profit_loss
        (shipment_id, seller_id, period_month, revenue, freight_cost, port_cost, handling_cost, claim_loss)
    SELECT k.shipment_id, k.seller_id, k.period_month,
           COALESCE(r.revenue,0.00), COALESCE(c.freight_cost,0.00),
           COALESCE(c.port_cost,0.00), COALESCE(c.handling_cost,0.00),
           COALESCE(cl.claim_loss,0.00)
    FROM tmp_fr6_pl_keys k
    LEFT JOIN tmp_fr6_pl_revenue r
      ON r.shipment_id = k.shipment_id AND r.period_month = k.period_month
    LEFT JOIN tmp_fr6_pl_costs c
      ON c.shipment_id = k.shipment_id AND c.period_month = k.period_month
    LEFT JOIN tmp_fr6_pl_claims cl
      ON cl.shipment_id = k.shipment_id AND cl.period_month = k.period_month
    ON DUPLICATE KEY UPDATE
        revenue = VALUES(revenue), freight_cost = VALUES(freight_cost),
        port_cost = VALUES(port_cost), handling_cost = VALUES(handling_cost),
        claim_loss = VALUES(claim_loss);

    DROP TEMPORARY TABLE IF EXISTS tmp_fr6_pl_revenue;
    DROP TEMPORARY TABLE IF EXISTS tmp_fr6_pl_costs;
    DROP TEMPORARY TABLE IF EXISTS tmp_fr6_pl_claims;
    DROP TEMPORARY TABLE IF EXISTS tmp_fr6_pl_keys;
END$$

-- SQL-only 6-month moving-average forecast (not an ML model).
-- confidence_pct is a data-coverage indicator: observed active months / 6.
CREATE PROCEDURE `sp_generate_demand_forecast`()
BEGIN
    DECLARE v_from DATE;
    DECLARE v_until DATE;
    DECLARE v_forecast_month DATE;
    SET v_until = STR_TO_DATE(DATE_FORMAT(CURDATE(),'%Y-%m-01'),'%Y-%m-%d');
    SET v_from = DATE_SUB(v_until, INTERVAL 6 MONTH);
    SET v_forecast_month = DATE_ADD(v_until, INTERVAL 1 MONTH);

    DELETE FROM demand_forecast WHERE forecast_month = v_forecast_month;

    INSERT INTO demand_forecast
        (origin_port_id, dest_port_id, container_type, forecast_month,
         predicted_bookings, confidence_pct, suggested_multiplier)
    SELECT origin_port_id, dest_port_id, container_type,
           v_forecast_month,
           GREATEST(ROUND(bookings_6m / 6.0),0) AS predicted_bookings,
           LEAST(100.00, ROUND(observed_months / 6.0 * 100,2)) AS confidence_pct,
           CASE WHEN ROUND(bookings_6m / 6.0) >= 10 THEN 1.20
                WHEN ROUND(bookings_6m / 6.0) >= 5 THEN 1.10
                ELSE 1.00 END AS suggested_multiplier
    FROM (
        SELECT s.origin_port_id, s.dest_port_id, c.container_type,
               COUNT(*) AS bookings_6m,
               COUNT(DISTINCT DATE_FORMAT(s.created_at,'%Y-%m')) AS observed_months
        FROM shipment s
        JOIN containers c ON c.container_id = s.container_id
        WHERE s.created_at >= v_from
          AND s.created_at <= NOW()
          AND s.status <> 'CANCELLED'
        GROUP BY s.origin_port_id, s.dest_port_id, c.container_type
    ) hist
    ON DUPLICATE KEY UPDATE
        predicted_bookings = VALUES(predicted_bookings),
        confidence_pct = VALUES(confidence_pct),
        suggested_multiplier = VALUES(suggested_multiplier);
END$$

CREATE PROCEDURE `sp_apply_forecast_pricing`()
BEGIN
    UPDATE pricing_rules pr
    JOIN demand_forecast df
      ON df.origin_port_id = pr.origin_port_id
     AND df.dest_port_id = pr.dest_port_id
     AND df.container_type = pr.container_type
    SET pr.demand_multiplier = df.suggested_multiplier
    WHERE df.forecast_month = STR_TO_DATE(DATE_FORMAT(DATE_ADD(CURDATE(), INTERVAL 1 MONTH),'%Y-%m-01'),'%Y-%m-%d')
      AND df.confidence_pct >= 75.00
      AND pr.is_active = TRUE
      AND (pr.valid_from IS NULL OR pr.valid_from <= df.forecast_month)
      AND (pr.valid_to IS NULL OR pr.valid_to >= df.forecast_month)
      AND NOT (pr.demand_multiplier <=> df.suggested_multiplier);
END$$

CREATE PROCEDURE `sp_refresh_all_fr6_analytics`()
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        UPDATE analytics_staleness
        SET is_stale = 1, stale_reason = 'Refresh failed; retry required'
        WHERE module_name IN ('sales_trends','abc_classification','inventory_turnover',
                              'profitability','shipment_profitability','profit_loss','demand_forecast');
        RESIGNAL;
    END;

    START TRANSACTION;
    CALL sp_refresh_sales_trends();
    CALL sp_calculate_product_sales_trends();
    CALL sp_calculate_customer_sales_trends();
    CALL sp_calculate_abc_classification();
    CALL sp_calculate_customer_abc();
    CALL sp_calculate_inventory_turnover(NULL,NULL);
    CALL sp_calculate_profitability();
    CALL sp_calculate_shipment_profitability();
    CALL sp_calculate_profit_loss();
    CALL sp_generate_demand_forecast();
    CALL sp_apply_forecast_pricing();

    UPDATE analytics_staleness
    SET is_stale = 0, last_refreshed_at = CURRENT_TIMESTAMP, stale_reason = NULL
    WHERE module_name IN ('sales_trends','abc_classification','inventory_turnover',
                          'profitability','shipment_profitability','profit_loss','demand_forecast');
    COMMIT;
END$$

-- Call this procedure when the Analytics Dashboard is opened. It recalculates
-- only when one or more relevant source modules have marked the cache stale.
CREATE PROCEDURE `sp_refresh_fr6_if_stale`()
BEGIN
    IF EXISTS (SELECT 1 FROM analytics_staleness WHERE is_stale = 1) THEN
        CALL sp_refresh_all_fr6_analytics();
    END IF;
END$$

DELIMITER ;

-- =============================================================================
-- SECTION 5: FR6 CACHE-STALE TRIGGERS
-- =============================================================================
-- These triggers only mark cached analytics stale. They deliberately do not
-- replace the master operational/audit triggers already installed on the DB.

DROP TRIGGER IF EXISTS `trg_fr6_sales_txn_ai_stale`;
DROP TRIGGER IF EXISTS `trg_fr6_sales_txn_au_stale`;
DROP TRIGGER IF EXISTS `trg_fr6_sales_txn_ad_stale`;
DROP TRIGGER IF EXISTS `trg_fr6_payment_ai_stale`;
DROP TRIGGER IF EXISTS `trg_fr6_payment_au_stale`;
DROP TRIGGER IF EXISTS `trg_fr6_payment_ad_stale`;
DROP TRIGGER IF EXISTS `trg_fr6_ledger_ai_stale`;
DROP TRIGGER IF EXISTS `trg_fr6_stock_ai_stale`;
DROP TRIGGER IF EXISTS `trg_fr6_stock_au_stale`;
DROP TRIGGER IF EXISTS `trg_fr6_claim_au_stale`;
DROP TRIGGER IF EXISTS `trg_fr6_shipment_cost_ai_stale`;
DROP TRIGGER IF EXISTS `trg_fr6_shipment_cost_au_stale`;
DROP TRIGGER IF EXISTS `trg_fr6_shipment_cost_ad_stale`;
DROP TRIGGER IF EXISTS `trg_fr6_product_ai_stale`;
DROP TRIGGER IF EXISTS `trg_fr6_customer_ai_stale`;
DROP TRIGGER IF EXISTS `trg_fr6_product_au_stale`;
DROP TRIGGER IF EXISTS `trg_fr6_shipment_ai_stale`;
DROP TRIGGER IF EXISTS `trg_fr6_shipment_au_stale`;
DROP TRIGGER IF EXISTS `trg_fr6_container_au_stale`;
DROP TRIGGER IF EXISTS `trg_fr6_shipment_item_ai_stale`;
DROP TRIGGER IF EXISTS `trg_fr6_shipment_item_au_stale`;
DROP TRIGGER IF EXISTS `trg_fr6_shipment_item_ad_stale`;
DROP TRIGGER IF EXISTS `trg_fr6_claim_ai_stale`;
DROP TRIGGER IF EXISTS `trg_fr6_claim_ad_stale`;

DELIMITER $$

CREATE TRIGGER `trg_fr6_sales_txn_ai_stale`
AFTER INSERT ON `sales_transactions` FOR EACH ROW
BEGIN
    UPDATE analytics_staleness SET is_stale = 1, stale_reason = 'Sales transaction inserted'
    WHERE module_name IN ('sales_trends','abc_classification','profitability','shipment_profitability');
END$$

CREATE TRIGGER `trg_fr6_sales_txn_au_stale`
AFTER UPDATE ON `sales_transactions` FOR EACH ROW
BEGIN
    UPDATE analytics_staleness SET is_stale = 1, stale_reason = 'Sales transaction updated'
    WHERE module_name IN ('sales_trends','abc_classification','profitability','shipment_profitability');
END$$

CREATE TRIGGER `trg_fr6_sales_txn_ad_stale`
AFTER DELETE ON `sales_transactions` FOR EACH ROW
BEGIN
    UPDATE analytics_staleness SET is_stale = 1, stale_reason = 'Sales transaction deleted'
    WHERE module_name IN ('sales_trends','abc_classification','profitability','shipment_profitability');
END$$

CREATE TRIGGER `trg_fr6_payment_ai_stale`
AFTER INSERT ON `payments` FOR EACH ROW
BEGIN
    UPDATE analytics_staleness SET is_stale = 1, stale_reason = 'Payment received'
    WHERE module_name IN ('profit_loss','shipment_profitability');
END$$

CREATE TRIGGER `trg_fr6_ledger_ai_stale`
AFTER INSERT ON `inventory_ledger` FOR EACH ROW
BEGIN
    UPDATE analytics_staleness SET is_stale = 1, stale_reason = 'Inventory ledger entry inserted'
    WHERE module_name = 'inventory_turnover';
END$$

CREATE TRIGGER `trg_fr6_payment_au_stale`
AFTER UPDATE ON `payments` FOR EACH ROW
BEGIN
    UPDATE analytics_staleness SET is_stale = 1, stale_reason = 'Payment corrected'
    WHERE module_name IN ('profit_loss','shipment_profitability');
END$$

CREATE TRIGGER `trg_fr6_payment_ad_stale`
AFTER DELETE ON `payments` FOR EACH ROW
BEGIN
    UPDATE analytics_staleness SET is_stale = 1, stale_reason = 'Payment reversed/deleted'
    WHERE module_name IN ('profit_loss','shipment_profitability');
END$$

CREATE TRIGGER `trg_fr6_stock_ai_stale`
AFTER INSERT ON `stock` FOR EACH ROW
BEGIN
    UPDATE analytics_staleness SET is_stale = 1, stale_reason = 'Stock received'
    WHERE module_name = 'inventory_turnover';
END$$

CREATE TRIGGER `trg_fr6_stock_au_stale`
AFTER UPDATE ON `stock` FOR EACH ROW
BEGIN
    IF NOT (OLD.quantity <=> NEW.quantity) OR NOT (OLD.damaged_qty <=> NEW.damaged_qty) THEN
        UPDATE analytics_staleness SET is_stale = 1, stale_reason = 'Stock quantity/damage changed'
        WHERE module_name = 'inventory_turnover';
    END IF;
END$$

CREATE TRIGGER `trg_fr6_claim_au_stale`
AFTER UPDATE ON `claims` FOR EACH ROW
BEGIN
    IF NOT (OLD.status <=> NEW.status) OR NOT (OLD.approved_amount <=> NEW.approved_amount) THEN
        UPDATE analytics_staleness SET is_stale = 1, stale_reason = 'Claim status/settlement changed'
        WHERE module_name IN ('profit_loss','shipment_profitability');
    END IF;
END$$

CREATE TRIGGER `trg_fr6_shipment_cost_ai_stale`
AFTER INSERT ON `shipment_costs` FOR EACH ROW
BEGIN
    UPDATE analytics_staleness SET is_stale = 1, stale_reason = 'Shipment cost inserted'
    WHERE module_name IN ('profit_loss','shipment_profitability');
END$$

CREATE TRIGGER `trg_fr6_shipment_cost_au_stale`
AFTER UPDATE ON `shipment_costs` FOR EACH ROW
BEGIN
    UPDATE analytics_staleness SET is_stale = 1, stale_reason = 'Shipment cost updated'
    WHERE module_name IN ('profit_loss','shipment_profitability');
END$$

CREATE TRIGGER `trg_fr6_shipment_cost_ad_stale`
AFTER DELETE ON `shipment_costs` FOR EACH ROW
BEGIN
    UPDATE analytics_staleness SET is_stale = 1, stale_reason = 'Shipment cost deleted'
    WHERE module_name IN ('profit_loss','shipment_profitability');
END$$

CREATE TRIGGER `trg_fr6_product_ai_stale`
AFTER INSERT ON `products` FOR EACH ROW
BEGIN
    UPDATE analytics_staleness SET is_stale = 1, stale_reason = 'Product created'
    WHERE module_name IN ('abc_classification','inventory_turnover','profitability');
END$$

CREATE TRIGGER `trg_fr6_customer_ai_stale`
AFTER INSERT ON `customers` FOR EACH ROW
BEGIN
    UPDATE analytics_staleness SET is_stale = 1, stale_reason = 'Customer created'
    WHERE module_name = 'abc_classification';
END$$

CREATE TRIGGER `trg_fr6_product_au_stale`
AFTER UPDATE ON `products` FOR EACH ROW
BEGIN
    IF NOT (OLD.unit_cost <=> NEW.unit_cost) OR NOT (OLD.unit_price <=> NEW.unit_price) THEN
        UPDATE analytics_staleness SET is_stale = 1, stale_reason = 'Product cost/price changed'
        WHERE module_name IN ('profitability','inventory_turnover','abc_classification');
    END IF;
END$$

CREATE TRIGGER `trg_fr6_shipment_ai_stale`
AFTER INSERT ON `shipment` FOR EACH ROW
BEGIN
    UPDATE analytics_staleness SET is_stale = 1, stale_reason = 'Shipment created or booked'
    WHERE module_name IN ('sales_trends','demand_forecast','shipment_profitability');
END$$

CREATE TRIGGER `trg_fr6_shipment_au_stale`
AFTER UPDATE ON `shipment` FOR EACH ROW
BEGIN
    IF NOT (OLD.origin_port_id <=> NEW.origin_port_id)
       OR NOT (OLD.dest_port_id <=> NEW.dest_port_id)
       OR NOT (OLD.container_id <=> NEW.container_id)
       OR NOT (OLD.seller_id <=> NEW.seller_id)
       OR NOT (OLD.status <=> NEW.status) THEN
        UPDATE analytics_staleness SET is_stale = 1, stale_reason = 'Shipment route/container/status changed'
        WHERE module_name IN ('sales_trends','demand_forecast','shipment_profitability','profit_loss');
    END IF;
END$$

CREATE TRIGGER `trg_fr6_container_au_stale`
AFTER UPDATE ON `containers` FOR EACH ROW
BEGIN
    IF NOT (OLD.container_type <=> NEW.container_type) THEN
        UPDATE analytics_staleness SET is_stale = 1, stale_reason = 'Container type changed'
        WHERE module_name = 'demand_forecast';
    END IF;
END$$

-- Shipment item changes affect shipment-level COGS and profitability.
CREATE TRIGGER `trg_fr6_shipment_item_ai_stale`
AFTER INSERT ON `shipment_items` FOR EACH ROW
BEGIN
    UPDATE analytics_staleness SET is_stale = 1, stale_reason = 'Shipment item inserted'
    WHERE module_name = 'shipment_profitability';
END$$

CREATE TRIGGER `trg_fr6_shipment_item_au_stale`
AFTER UPDATE ON `shipment_items` FOR EACH ROW
BEGIN
    UPDATE analytics_staleness SET is_stale = 1, stale_reason = 'Shipment item updated'
    WHERE module_name = 'shipment_profitability';
END$$

CREATE TRIGGER `trg_fr6_shipment_item_ad_stale`
AFTER DELETE ON `shipment_items` FOR EACH ROW
BEGIN
    UPDATE analytics_staleness SET is_stale = 1, stale_reason = 'Shipment item deleted'
    WHERE module_name = 'shipment_profitability';
END$$

-- Claim insert/delete can change claim-loss reporting if a settled row is entered or removed.
CREATE TRIGGER `trg_fr6_claim_ai_stale`
AFTER INSERT ON `claims` FOR EACH ROW
BEGIN
    UPDATE analytics_staleness SET is_stale = 1, stale_reason = 'Claim inserted'
    WHERE module_name IN ('profit_loss','shipment_profitability');
END$$

CREATE TRIGGER `trg_fr6_claim_ad_stale`
AFTER DELETE ON `claims` FOR EACH ROW
BEGIN
    UPDATE analytics_staleness SET is_stale = 1, stale_reason = 'Claim deleted'
    WHERE module_name IN ('profit_loss','shipment_profitability');
END$$

DELIMITER ;

-- =============================================================================
-- SECTION 6: DASHBOARD FILTER / REPORT QUERIES
-- =============================================================================

/* Parameterized examples for PreparedStatement; keep commented in a SQL console script.
-- Route-wise sales by month.
SELECT * FROM vw_fr6_sales_route_live
WHERE (? IS NULL OR origin_port_id = ?)
  AND (? IS NULL OR dest_port_id = ?)
  AND (? IS NULL OR period_month >= ?)
  AND (? IS NULL OR period_month <= ?)
ORDER BY period_month DESC, total_sales DESC;

-- Product-wise sales and growth.
SELECT * FROM vw_fr6_sales_product_cached
WHERE (? IS NULL OR product_id = ?)
  AND (? IS NULL OR period_month >= ?)
  AND (? IS NULL OR period_month <= ?)
ORDER BY period_month DESC, total_sales DESC;

-- Customer-wise sales and growth.
SELECT * FROM vw_fr6_sales_customer_cached
WHERE (? IS NULL OR customer_id = ?)
  AND (? IS NULL OR period_month >= ?)
  AND (? IS NULL OR period_month <= ?)
ORDER BY period_month DESC, total_sales DESC;

-- Product ABC.
SELECT * FROM vw_fr6_abc_product
WHERE (? IS NULL OR abc_class = ?)
ORDER BY annual_value DESC;

-- Customer ABC.
SELECT * FROM vw_fr6_abc_customer
WHERE (? IS NULL OR abc_class = ?)
ORDER BY annual_value DESC;

-- Seller P&L by company and period.
SELECT * FROM vw_fr6_seller_pl_summary
WHERE (? IS NULL OR seller_id = ?)
  AND (? IS NULL OR period_month >= ?)
  AND (? IS NULL OR period_month <= ?)
ORDER BY period_month DESC;

-- Shipment cost detail.
SELECT s.shipment_no, sc.cost_type, sc.cost_date, sc.amount, sc.description
FROM shipment_costs sc
JOIN shipment s ON s.shipment_id = sc.shipment_id
WHERE (? IS NULL OR s.shipment_id = ?)
  AND (? IS NULL OR sc.cost_date >= ?)
  AND (? IS NULL OR sc.cost_date <= ?)
ORDER BY sc.cost_date DESC;

-- Demand forecast by route and forecast month.
SELECT * FROM vw_fr6_demand_forecast_live
WHERE (? IS NULL OR origin_port_id = ?)
  AND (? IS NULL OR dest_port_id = ?)
  AND (? IS NULL OR forecast_month = ?)
  AND (? IS NULL OR container_type = ?)
ORDER BY forecast_month DESC;
*/

-- =============================================================================
-- SECTION 7: OPTIONAL DAILY REFRESH EVENT AND INITIAL POPULATION
-- =============================================================================

-- MySQL EVENT execution requires the global event_scheduler to be ON.
-- Check with: SHOW VARIABLES LIKE 'event_scheduler';
DROP EVENT IF EXISTS `evt_daily_fr6_analytics_refresh`;
DELIMITER $$
CREATE EVENT `evt_daily_fr6_analytics_refresh`
ON SCHEDULE EVERY 1 DAY
STARTS CURRENT_TIMESTAMP + INTERVAL 1 DAY
DO
BEGIN
    CALL `sp_refresh_all_fr6_analytics`();
END$$
DELIMITER ;

-- Initial population. On subsequent dashboard opens use sp_refresh_fr6_if_stale().
CALL `sp_refresh_all_fr6_analytics`();

-- =============================================================================
-- SECTION 8: VERIFICATION QUERIES
-- =============================================================================

SELECT 'sales_trend_result' AS result_table, COUNT(*) AS row_count FROM sales_trend_result
UNION ALL SELECT 'sales_trend_product_result', COUNT(*) FROM sales_trend_product_result
UNION ALL SELECT 'sales_trend_customer_result', COUNT(*) FROM sales_trend_customer_result
UNION ALL SELECT 'abc_classification_result', COUNT(*) FROM abc_classification_result
UNION ALL SELECT 'customer_abc_classification_result', COUNT(*) FROM customer_abc_classification_result
UNION ALL SELECT 'inventory_turnover_result', COUNT(*) FROM inventory_turnover_result
UNION ALL SELECT 'profitability_result', COUNT(*) FROM profitability_result
UNION ALL SELECT 'shipment_profitability_result', COUNT(*) FROM shipment_profitability_result
UNION ALL SELECT 'profit_loss', COUNT(*) FROM profit_loss
UNION ALL SELECT 'demand_forecast', COUNT(*) FROM demand_forecast;

SELECT module_name, is_stale, last_refreshed_at, stale_reason
FROM analytics_staleness
ORDER BY module_name;

-- Products with sales but no configured actual cost must be corrected; no cost ratio is fabricated.
SELECT DISTINCT p.product_id, p.sku, p.product_name, p.unit_cost
FROM products p
JOIN sales_transactions st ON st.product_id = p.product_id
WHERE p.unit_cost IS NULL OR p.unit_cost <= 0;

-- Must return zero rows: P&L formula mismatch is impossible when net_profit is generated.
SELECT pl_id, revenue, freight_cost, port_cost, handling_cost, claim_loss, net_profit,
       (revenue - freight_cost - port_cost - handling_cost - claim_loss) AS expected_net_profit
FROM profit_loss
WHERE ABS(net_profit - (revenue - freight_cost - port_cost - handling_cost - claim_loss)) > 0.01;

-- Must return zero rows after successful refresh.
SELECT 'Duplicate route trend' AS check_name, period_month, origin_port_id, dest_port_id, COUNT(*) AS duplicate_count
FROM sales_trend_result GROUP BY period_month, origin_port_id, dest_port_id HAVING COUNT(*) > 1;

-- End of FR6 database extension.

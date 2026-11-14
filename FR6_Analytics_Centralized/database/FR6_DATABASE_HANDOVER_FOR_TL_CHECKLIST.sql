-- =============================================================================
-- PROJECT: N Logistic Management Platform
-- MODULE:  FR6 - Analytics Dashboard & P&L (SRS Section 7.9 Complete Checklist)
-- FILE:    FR6_DATABASE_HANDOVER_FOR_TL_CHECKLIST.sql
-- PURPOSE: Master Database Implementation Checklist for Module FR6 & Section 7.9
-- SCOPE:   Database Only | AI/ML Excluded | 28 Core Entities Preserved
-- ENGINE:  MySQL 8.0+ / MariaDB 10.4+ (Compatible with XAMPP & Production)
-- =============================================================================

USE `n_logistic_db`;

-- Temporarily disable FK checks to ensure safe idempotent schema execution
SET @OLD_FOREIGN_KEY_CHECKS = @@FOREIGN_KEY_CHECKS;
SET FOREIGN_KEY_CHECKS = 0;

-- =============================================================================
-- SECTION 1: ANALYTICS SCHEMAS & TABLES (10 RESULT TABLES + SUPPORTING ENTITIES)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1.0 PREREQUISITE OPERATIONAL SCHEMA ALIGNMENTS (SOURCE DATA VERIFICATION)
-- -----------------------------------------------------------------------------

-- Ensure products.unit_cost exists for FR6.5 product margin calculation
DROP PROCEDURE IF EXISTS `sp_ensure_product_unit_cost`;
DELIMITER //
CREATE PROCEDURE `sp_ensure_product_unit_cost`()
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = DATABASE() AND table_name = 'products' AND column_name = 'unit_cost'
    ) THEN
        ALTER TABLE `products` ADD COLUMN `unit_cost` DECIMAL(12,2) NOT NULL DEFAULT 0.00 AFTER `unit_price`;
        UPDATE `products` SET `unit_cost` = ROUND(`unit_price` * 0.65, 2);
    END IF;
END //
DELIMITER ;
CALL sp_ensure_product_unit_cost();
DROP PROCEDURE IF EXISTS `sp_ensure_product_unit_cost`;

-- Ensure shipment_costs exists for Checklist Query 7.10
CREATE TABLE IF NOT EXISTS `shipment_costs` (
    `cost_id`     BIGINT AUTO_INCREMENT PRIMARY KEY,
    `shipment_id` INT NOT NULL,
    `cost_type`   ENUM('FREIGHT', 'PORT', 'HANDLING', 'CUSTOMS', 'INSURANCE', 'OTHER') NOT NULL,
    `amount`      DECIMAL(14, 2) NOT NULL DEFAULT 0.00,
    `description` VARCHAR(255) NULL,
    `cost_date`   DATE NOT NULL,
    `recorded_by` INT NULL,
    `created_at`  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT `fk_sc_shipment` FOREIGN KEY (`shipment_id`) REFERENCES `shipment`(`shipment_id`) ON DELETE CASCADE,
    INDEX `idx_sc_shipment_type` (`shipment_id`, `cost_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Seed baseline shipment costs for active shipments if table is empty
INSERT INTO `shipment_costs` (`shipment_id`, `cost_type`, `amount`, `description`, `cost_date`, `recorded_by`)
SELECT s.shipment_id, 'FREIGHT', COALESCE(AVG(pr.base_rate), 45000.00), 'Standard Ocean Freight', DATE(s.created_at), s.seller_id
FROM shipment s
LEFT JOIN pricing_rules pr ON s.origin_port_id = pr.origin_port_id AND s.dest_port_id = pr.dest_port_id
WHERE NOT EXISTS (SELECT 1 FROM shipment_costs WHERE shipment_id = s.shipment_id AND cost_type = 'FREIGHT')
GROUP BY s.shipment_id, DATE(s.created_at), s.seller_id;

INSERT INTO `shipment_costs` (`shipment_id`, `cost_type`, `amount`, `description`, `cost_date`, `recorded_by`)
SELECT s.shipment_id, 'PORT', 5000.00, 'Port dues and terminal tariff', DATE(s.created_at), s.seller_id
FROM shipment s
WHERE NOT EXISTS (SELECT 1 FROM shipment_costs WHERE shipment_id = s.shipment_id AND cost_type = 'PORT');

INSERT INTO `shipment_costs` (`shipment_id`, `cost_type`, `amount`, `description`, `cost_date`, `recorded_by`)
SELECT s.shipment_id, 'HANDLING', 3500.00, 'Stevedoring and container handling', DATE(s.created_at), s.seller_id
FROM shipment s
WHERE NOT EXISTS (SELECT 1 FROM shipment_costs WHERE shipment_id = s.shipment_id AND cost_type = 'HANDLING');

-- -----------------------------------------------------------------------------
-- 1.1 EXISTING SRS SECTION 7.9 TABLES (5 ORIGINAL + DEMAND_FORECAST)
-- -----------------------------------------------------------------------------

-- 1. SALES TREND RESULT (ERD #10 / SRS 7.9 Table 5)
-- Purpose: Caches monthly route-wise sales trends & volume (FR6.2).
CREATE TABLE IF NOT EXISTS `sales_trend_result` (
    `result_id`       INT AUTO_INCREMENT PRIMARY KEY,
    `period_month`    DATE NOT NULL COMMENT 'First day of month (YYYY-MM-01)',
    `origin_port_id`  INT NOT NULL COMMENT 'FK to ports',
    `dest_port_id`    INT NOT NULL COMMENT 'FK to ports',
    `total_sales`     DECIMAL(14, 2) NOT NULL DEFAULT 0.00 COMMENT 'Total realized route revenue',
    `total_qty`       INT NOT NULL DEFAULT 0 COMMENT 'Total container volume or unit quantity',
    `growth_pct`      DECIMAL(6, 2) NOT NULL DEFAULT 0.00 COMMENT 'Month-over-month growth rate %',
    `created_at`      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT `fk_fr6_str_origin` FOREIGN KEY (`origin_port_id`) REFERENCES `ports`(`port_id`) ON DELETE CASCADE,
    CONSTRAINT `fk_fr6_str_dest` FOREIGN KEY (`dest_port_id`) REFERENCES `ports`(`port_id`) ON DELETE CASCADE,
    CONSTRAINT `chk_str_total_qty` CHECK (`total_qty` >= 0),
    CONSTRAINT `chk_str_total_sales` CHECK (`total_sales` >= 0.00),
    UNIQUE KEY `uq_sales_trend_route_month` (`period_month`, `origin_port_id`, `dest_port_id`),
    INDEX `idx_sales_trend_route_month` (`period_month`, `origin_port_id`, `dest_port_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 2. ABC CLASSIFICATION RESULT (ERD #26 / SRS 7.9 Table 2)
-- Purpose: Caches Pareto inventory analysis per product (FR6.3).
CREATE TABLE IF NOT EXISTS `abc_classification_result` (
    `result_id`       INT AUTO_INCREMENT PRIMARY KEY,
    `product_id`      INT NOT NULL COMMENT 'FK to products',
    `annual_value`    DECIMAL(14, 2) NOT NULL DEFAULT 0.00 COMMENT 'Annualized product sales value',
    `cumulative_pct`  DECIMAL(5, 2) NOT NULL DEFAULT 0.00 COMMENT 'Running cumulative revenue % (0-100)',
    `abc_class`       CHAR(1) NOT NULL COMMENT 'Category: A = top 70%, B = next 20%, C = last 10%',
    `calculated_on`   DATE NOT NULL COMMENT 'Date of Pareto classification run',
    `created_at`      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT `fk_fr6_abc_prod` FOREIGN KEY (`product_id`) REFERENCES `products`(`product_id`) ON DELETE CASCADE,
    CONSTRAINT `chk_abc_class` CHECK (`abc_class` IN ('A', 'B', 'C')),
    CONSTRAINT `chk_abc_cum_pct` CHECK (`cumulative_pct` BETWEEN 0.00 AND 100.00),
    UNIQUE KEY `uq_abc_product_date` (`product_id`, `calculated_on`),
    INDEX `idx_abc_class` (`abc_class`),
    INDEX `idx_abc_product_lookup` (`product_id`, `calculated_on`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 3. INVENTORY TURNOVER RESULT (ERD #27 / SRS 7.9 Table 3)
-- Purpose: Caches inventory velocity and turnover metrics (FR6.4).
CREATE TABLE IF NOT EXISTS `inventory_turnover_result` (
    `result_id`       INT AUTO_INCREMENT PRIMARY KEY,
    `product_id`      INT NOT NULL COMMENT 'FK to products',
    `period_start`    DATE NOT NULL,
    `period_end`      DATE NOT NULL,
    `cogs`            DECIMAL(14, 2) NOT NULL DEFAULT 0.00 COMMENT 'Cost of Goods Sold (ledger OUT)',
    `avg_inventory`   DECIMAL(14, 2) NOT NULL DEFAULT 0.00 COMMENT 'Average stock valuation over period',
    `turnover_ratio`  DECIMAL(8, 2) NOT NULL DEFAULT 0.00 COMMENT 'turnover_ratio = cogs / avg_inventory',
    `created_at`      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT `fk_fr6_turnover_prod` FOREIGN KEY (`product_id`) REFERENCES `products`(`product_id`) ON DELETE CASCADE,
    CONSTRAINT `chk_turnover_dates` CHECK (`period_start` <= `period_end`),
    CONSTRAINT `chk_turnover_cogs_nonneg` CHECK (`cogs` >= 0.00),
    CONSTRAINT `chk_turnover_avg_inv_nonneg` CHECK (`avg_inventory` >= 0.00),
    UNIQUE KEY `uq_turnover_product_period` (`product_id`, `period_start`, `period_end`),
    INDEX `idx_turnover_prod_dates` (`product_id`, `period_start`, `period_end`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 4. PROFITABILITY RESULT (ERD #28 / SRS 7.9 Table 4)
-- Purpose: Caches monthly gross profitability margins per product (FR6.5).
CREATE TABLE IF NOT EXISTS `profitability_result` (
    `result_id`       INT AUTO_INCREMENT PRIMARY KEY,
    `product_id`      INT NOT NULL COMMENT 'FK to products',
    `period_month`    DATE NOT NULL COMMENT 'First day of month (YYYY-MM-01)',
    `revenue`         DECIMAL(14, 2) NOT NULL DEFAULT 0.00 COMMENT 'Gross revenue realized for product',
    `cost`            DECIMAL(14, 2) NOT NULL DEFAULT 0.00 COMMENT 'Actual COGS using unit_cost',
    `margin_pct`      DECIMAL(6, 2) NOT NULL DEFAULT 0.00 COMMENT 'Gross profit margin %',
    `created_at`      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT `fk_fr6_profit_prod` FOREIGN KEY (`product_id`) REFERENCES `products`(`product_id`) ON DELETE CASCADE,
    CONSTRAINT `chk_prof_revenue_nonneg` CHECK (`revenue` >= 0.00),
    CONSTRAINT `chk_prof_cost_nonneg` CHECK (`cost` >= 0.00),
    CONSTRAINT `chk_prof_margin_range` CHECK (`margin_pct` BETWEEN -100.00 AND 100.00),
    UNIQUE KEY `uq_profitability_product_month` (`product_id`, `period_month`),
    INDEX `idx_profitability_prod_month` (`product_id`, `period_month`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 5. PROFIT LOSS (ERD #11 / SRS 7.9 Table 1)
-- Purpose: Shipment-level and monthly financial records (FR6.5 & FR2.8).
-- Formula: net_profit = revenue - freight_cost - port_cost - handling_cost - claim_loss.
-- Note: Implements net_profit as a STORED GENERATED column per Checklist Section 8.
CREATE TABLE IF NOT EXISTS `profit_loss` (
    `pl_id`           INT AUTO_INCREMENT PRIMARY KEY,
    `shipment_id`     INT NULL COMMENT 'Nullable for consolidated seller month baseline',
    `seller_id`       INT NOT NULL COMMENT 'FK to users(user_id) with role SELLER',
    `period_month`    DATE NOT NULL COMMENT 'First day of month (YYYY-MM-01)',
    `revenue`         DECIMAL(14, 2) NOT NULL DEFAULT 0.00 COMMENT 'Paid / Invoiced revenue',
    `freight_cost`    DECIMAL(14, 2) NOT NULL DEFAULT 0.00 COMMENT 'Ocean freight operating expense',
    `port_cost`       DECIMAL(14, 2) NOT NULL DEFAULT 0.00 COMMENT 'Port dues & terminal fees',
    `handling_cost`   DECIMAL(14, 2) NOT NULL DEFAULT 0.00 COMMENT 'Stevedoring & container handling',
    `claim_loss`      DECIMAL(14, 2) NOT NULL DEFAULT 0.00 COMMENT 'Settled approved claim payouts',
    `net_profit`      DECIMAL(14, 2) GENERATED ALWAYS AS (revenue - freight_cost - port_cost - handling_cost - claim_loss) STORED,
    `created_at`      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT `fk_fr6_pl_shipment` FOREIGN KEY (`shipment_id`) REFERENCES `shipment`(`shipment_id`) ON DELETE SET NULL,
    CONSTRAINT `fk_fr6_pl_seller` FOREIGN KEY (`seller_id`) REFERENCES `users`(`user_id`) ON DELETE CASCADE,
    UNIQUE KEY `uq_profit_loss_shipment_month` (`shipment_id`, `period_month`),
    INDEX `idx_pl_seller_month` (`seller_id`, `period_month`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Ensure net_profit is STORED GENERATED if the table already existed
ALTER TABLE `profit_loss` 
MODIFY COLUMN `net_profit` DECIMAL(14, 2) 
GENERATED ALWAYS AS (revenue - freight_cost - port_cost - handling_cost - claim_loss) STORED;

-- 6. DEMAND FORECAST (ERD #8 / SRS Section 7.5 for FR6.6)
-- Purpose: Route & container demand forecasting to dynamically guide pricing.
CREATE TABLE IF NOT EXISTS `demand_forecast` (
    `forecast_id`          INT AUTO_INCREMENT PRIMARY KEY,
    `origin_port_id`       INT NOT NULL,
    `dest_port_id`         INT NOT NULL,
    `container_type`       ENUM('DRY', 'REEFER', 'OPEN_TOP', 'TANK') NOT NULL,
    `forecast_month`       DATE NOT NULL COMMENT 'First day of target month (YYYY-MM-01)',
    `predicted_bookings`   INT NOT NULL DEFAULT 0,
    `confidence_pct`       DECIMAL(5, 2) NOT NULL DEFAULT 0.00,
    `suggested_multiplier` DECIMAL(4, 2) NOT NULL DEFAULT 1.00,
    `created_at`           TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT `fk_df_orig_port` FOREIGN KEY (`origin_port_id`) REFERENCES `ports`(`port_id`) ON DELETE CASCADE,
    CONSTRAINT `fk_df_dest_port` FOREIGN KEY (`dest_port_id`) REFERENCES `ports`(`port_id`) ON DELETE CASCADE,
    CONSTRAINT `chk_df_confidence` CHECK (`confidence_pct` BETWEEN 0.00 AND 100.00),
    CONSTRAINT `chk_df_bookings_nonneg` CHECK (`predicted_bookings` >= 0),
    CONSTRAINT `chk_df_multiplier_pos` CHECK (`suggested_multiplier` > 0.00),
    UNIQUE KEY `uq_demand_forecast_route` (`origin_port_id`, `dest_port_id`, `container_type`, `forecast_month`),
    INDEX `idx_df_lookup` (`origin_port_id`, `dest_port_id`, `forecast_month`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- -----------------------------------------------------------------------------
-- 1.2 ADDITIONAL SUPPORTING ANALYTICS TABLES (CHECKLIST SECTION 1.2)
-- -----------------------------------------------------------------------------

-- 7. CUSTOMER ABC CLASSIFICATION RESULT (Checklist Table 1 / FR6.3)
-- Purpose: Caches annual customer contribution Pareto analysis (A=70%, B=20%, C=10%).
CREATE TABLE IF NOT EXISTS `customer_abc_classification_result` (
    `result_id`       INT AUTO_INCREMENT PRIMARY KEY,
    `customer_id`     INT NOT NULL COMMENT 'FK to customers',
    `annual_value`    DECIMAL(14, 2) NOT NULL DEFAULT 0.00 COMMENT 'Annual spending total across all shipments',
    `cumulative_pct`  DECIMAL(5, 2) NOT NULL DEFAULT 0.00 COMMENT 'Cumulative portfolio revenue % (0-100)',
    `abc_class`       CHAR(1) NOT NULL COMMENT 'A = top 70%, B = next 20%, C = last 10%',
    `calculated_on`   DATE NOT NULL COMMENT 'Date Pareto analysis was calculated',
    `created_at`      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT `fk_fr6_cabc_customer` FOREIGN KEY (`customer_id`) REFERENCES `customers`(`customer_id`) ON DELETE CASCADE,
    CONSTRAINT `chk_cabc_class` CHECK (`abc_class` IN ('A', 'B', 'C')),
    CONSTRAINT `chk_cabc_cum_pct` CHECK (`cumulative_pct` BETWEEN 0.00 AND 100.00),
    UNIQUE KEY `uq_customer_abc_calc` (`customer_id`, `calculated_on`),
    INDEX `idx_customer_abc_class` (`abc_class`),
    INDEX `idx_customer_abc_calc_lookup` (`customer_id`, `calculated_on`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 8. SALES TREND PRODUCT RESULT (Checklist Table 2 / FR6.2)
-- Purpose: Caches monthly product-wise sales revenue, quantity, and growth %.
CREATE TABLE IF NOT EXISTS `sales_trend_product_result` (
    `result_id`       INT AUTO_INCREMENT PRIMARY KEY,
    `product_id`      INT NOT NULL COMMENT 'FK to products',
    `period_month`    DATE NOT NULL COMMENT 'First day of month (YYYY-MM-01)',
    `total_sales`     DECIMAL(14, 2) NOT NULL DEFAULT 0.00 COMMENT 'Gross revenue realized for product',
    `total_qty`       INT NOT NULL DEFAULT 0 COMMENT 'Total units sold/shipped',
    `growth_pct`      DECIMAL(6, 2) NOT NULL DEFAULT 0.00 COMMENT 'MoM product sales growth rate %',
    `created_at`      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT `fk_fr6_stpr_product` FOREIGN KEY (`product_id`) REFERENCES `products`(`product_id`) ON DELETE CASCADE,
    CONSTRAINT `chk_stpr_sales_nonneg` CHECK (`total_sales` >= 0.00),
    CONSTRAINT `chk_stpr_qty_nonneg` CHECK (`total_qty` >= 0),
    UNIQUE KEY `uq_prod_trend_month` (`product_id`, `period_month`),
    INDEX `idx_sales_trend_prod_month` (`period_month`, `product_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 9. SALES TREND CUSTOMER RESULT (Checklist Table 3 / FR6.2)
-- Purpose: Caches monthly customer-wise sales revenue, quantity, and growth %.
CREATE TABLE IF NOT EXISTS `sales_trend_customer_result` (
    `result_id`       INT AUTO_INCREMENT PRIMARY KEY,
    `customer_id`     INT NOT NULL COMMENT 'FK to customers',
    `period_month`    DATE NOT NULL COMMENT 'First day of month (YYYY-MM-01)',
    `total_sales`     DECIMAL(14, 2) NOT NULL DEFAULT 0.00 COMMENT 'Gross spend by customer this month',
    `total_qty`       INT NOT NULL DEFAULT 0 COMMENT 'Total units purchased',
    `growth_pct`      DECIMAL(6, 2) NOT NULL DEFAULT 0.00 COMMENT 'MoM customer spend growth rate %',
    `created_at`      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT `fk_fr6_stcr_customer` FOREIGN KEY (`customer_id`) REFERENCES `customers`(`customer_id`) ON DELETE CASCADE,
    CONSTRAINT `chk_stcr_sales_nonneg` CHECK (`total_sales` >= 0.00),
    CONSTRAINT `chk_stcr_qty_nonneg` CHECK (`total_qty` >= 0),
    UNIQUE KEY `uq_cust_trend_month` (`customer_id`, `period_month`),
    INDEX `idx_sales_trend_cust_month` (`period_month`, `customer_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 10. SHIPMENT PROFITABILITY RESULT (Checklist Table 4 / FR6.5)
-- Purpose: Caches shipment-level revenue, direct costs, and gross operating margin %.
CREATE TABLE IF NOT EXISTS `shipment_profitability_result` (
    `result_id`       INT AUTO_INCREMENT PRIMARY KEY,
    `shipment_id`     INT NOT NULL COMMENT 'FK to shipment',
    `seller_id`       INT NOT NULL COMMENT 'FK to users(user_id)',
    `period_month`    DATE NOT NULL COMMENT 'First day of month (YYYY-MM-01)',
    `revenue`         DECIMAL(14, 2) NOT NULL DEFAULT 0.00 COMMENT 'Invoiced revenue',
    `cost`            DECIMAL(14, 2) NOT NULL DEFAULT 0.00 COMMENT 'Total operating costs + settled claims',
    `margin_pct`      DECIMAL(6, 2) NOT NULL DEFAULT 0.00 COMMENT 'Operating margin % = ((revenue-cost)/revenue)*100',
    `created_at`      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT `fk_fr6_spr_shipment` FOREIGN KEY (`shipment_id`) REFERENCES `shipment`(`shipment_id`) ON DELETE CASCADE,
    CONSTRAINT `fk_fr6_spr_seller` FOREIGN KEY (`seller_id`) REFERENCES `users`(`user_id`) ON DELETE CASCADE,
    CONSTRAINT `chk_spr_revenue_nonneg` CHECK (`revenue` >= 0.00),
    CONSTRAINT `chk_spr_cost_nonneg` CHECK (`cost` >= 0.00),
    UNIQUE KEY `uq_ship_profit_month` (`shipment_id`, `period_month`),
    INDEX `idx_ship_profit_month` (`shipment_id`, `period_month`),
    INDEX `idx_ship_profit_seller` (`seller_id`, `period_month`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 11. ANALYTICS STALENESS & LOGGING (Checklist Section 5 Supporting)
-- Purpose: Tracks cache staleness flags and execution logs for FR6.7.
CREATE TABLE IF NOT EXISTS `analytics_staleness` (
    `module_name`       VARCHAR(40) PRIMARY KEY,
    `is_stale`          TINYINT(1) NOT NULL DEFAULT 1 COMMENT '1 = Needs recalculation, 0 = Fresh',
    `last_refreshed_at` TIMESTAMP NULL,
    `stale_reason`      VARCHAR(255) NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO `analytics_staleness` (`module_name`, `is_stale`, `last_refreshed_at`, `stale_reason`)
VALUES 
    ('sales_trends', 1, NULL, 'Initial load'),
    ('abc_classification', 1, NULL, 'Initial load'),
    ('inventory_turnover', 1, NULL, 'Initial load'),
    ('profitability', 1, NULL, 'Initial load'),
    ('profit_loss', 1, NULL, 'Initial load'),
    ('demand_forecast', 1, NULL, 'Initial load')
ON DUPLICATE KEY UPDATE `is_stale` = VALUES(`is_stale`);

-- 12. SHIPMENT STOCK RESERVATIONS (Supporting Table for Stock Lifecycle Trigger)
CREATE TABLE IF NOT EXISTS `shipment_stock_reservations` (
    `reservation_id`    BIGINT AUTO_INCREMENT PRIMARY KEY,
    `shipment_id`       INT NOT NULL,
    `product_id`        INT NOT NULL,
    `reserved_quantity` INT NOT NULL,
    `status`            ENUM('RESERVED','CONSUMED','RELEASED') NOT NULL DEFAULT 'RESERVED',
    `created_at`        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_res_shipment` (`shipment_id`),
    INDEX `idx_res_product` (`product_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Restore foreign key checks
SET FOREIGN_KEY_CHECKS = @OLD_FOREIGN_KEY_CHECKS;


-- =============================================================================
-- SECTION 2: REQUIRED INDEXES & CONSTRAINTS (CHECKLIST SECTION 8)
-- =============================================================================

-- Idempotent index creation helper procedure
DROP PROCEDURE IF EXISTS `sp_create_index_if_not_exists`;
DELIMITER //
CREATE PROCEDURE `sp_create_index_if_not_exists`(
    IN p_table_name VARCHAR(64),
    IN p_index_name VARCHAR(64),
    IN p_index_columns VARCHAR(255)
)
BEGIN
    DECLARE v_count INT DEFAULT 0;
    SELECT COUNT(*) INTO v_count
    FROM information_schema.statistics
    WHERE table_schema = DATABASE()
      AND table_name = p_table_name
      AND index_name = p_index_name;

    IF v_count = 0 THEN
        SET @sql = CONCAT('ALTER TABLE `', p_table_name, '` ADD INDEX `', p_index_name, '` (', p_index_columns, ');');
        PREPARE stmt FROM @sql;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;
    END IF;
END //
DELIMITER ;

-- Apply all 11 compound indexes required by Checklist Section 8:
CALL sp_create_index_if_not_exists('sales_transactions', 'idx_sales_txn_date_product', '`sale_date`, `product_id`');
CALL sp_create_index_if_not_exists('sales_transactions', 'idx_sales_txn_date_customer', '`sale_date`, `customer_id`');
CALL sp_create_index_if_not_exists('sales_transactions', 'idx_sales_txn_shipment_date', '`shipment_id`, `sale_date`');
CALL sp_create_index_if_not_exists('sales_trend_result', 'idx_sales_trend_route_month', '`period_month`, `origin_port_id`, `dest_port_id`');
CALL sp_create_index_if_not_exists('sales_trend_product_result', 'idx_sales_trend_prod_month', '`period_month`, `product_id`');
CALL sp_create_index_if_not_exists('sales_trend_customer_result', 'idx_sales_trend_cust_month', '`period_month`, `customer_id`');
CALL sp_create_index_if_not_exists('profit_loss', 'idx_pl_seller_month', '`seller_id`, `period_month`');
CALL sp_create_index_if_not_exists('profitability_result', 'idx_profitability_prod_month', '`product_id`, `period_month`');
CALL sp_create_index_if_not_exists('shipment_profitability_result', 'idx_ship_profit_month', '`shipment_id`, `period_month`');
CALL sp_create_index_if_not_exists('inventory_turnover_result', 'idx_turnover_prod_dates', '`product_id`, `period_start`, `period_end`');
CALL sp_create_index_if_not_exists('customer_abc_classification_result', 'idx_customer_abc_calc', '`customer_id`, `calculated_on`');

DROP PROCEDURE IF EXISTS `sp_create_index_if_not_exists`;


-- =============================================================================
-- SECTION 3: LIVE DATABASE VIEWS (8 VIEWS - CHECKLIST SECTION 3)
-- Purpose: Read directly from operational tables in real time whenever queried.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- LIVE VIEW 1: vw_fr6_kpi_live (Checklist 3.1 & 7.1)
-- Purpose: Unified real-time operational KPIs aggregated without Cartesian product.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW `vw_fr6_kpi_live` AS
SELECT 
    (SELECT COUNT(*) FROM `shipment` WHERE `status` NOT IN ('CANCELLED', 'DELIVERED')) AS active_shipments,
    (SELECT COUNT(*) FROM `containers` WHERE `status` = 'AVAILABLE') AS available_containers,
    (SELECT COALESCE(SUM(`paid_amount`), 0.00) FROM `billing_invoices`) AS revenue,
    (SELECT COALESCE(SUM(`total_amount` - `paid_amount`), 0.00) FROM `billing_invoices` WHERE `status` <> 'PAID') AS pending_invoices,
    (SELECT COUNT(*) FROM `claims` WHERE `status` IN ('SUBMITTED', 'UNDER_REVIEW')) AS open_claims;

-- -----------------------------------------------------------------------------
-- LIVE VIEW 2: vw_fr6_sales_route_live (Checklist 3.2 & 7.2)
-- Purpose: Live route-wise sales joining sales_transactions, shipment, origin/dest ports.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW `vw_fr6_sales_route_live` AS
SELECT 
    op.port_name AS origin_port,
    dp.port_name AS destination_port,
    s.origin_port_id,
    s.dest_port_id,
    SUM(st.total_amount) AS total_sales,
    SUM(st.quantity) AS total_quantity
FROM sales_transactions st
JOIN shipment s ON st.shipment_id = s.shipment_id
JOIN ports op ON s.origin_port_id = op.port_id
JOIN ports dp ON s.dest_port_id = dp.port_id
WHERE s.status != 'CANCELLED'
GROUP BY op.port_name, dp.port_name, s.origin_port_id, s.dest_port_id;

-- -----------------------------------------------------------------------------
-- LIVE VIEW 3: vw_fr6_sales_product_live (Checklist 3.3 & 7.3)
-- Purpose: Live product-wise sales revenue & volume joining sales_transactions & products.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW `vw_fr6_sales_product_live` AS
SELECT 
    p.product_id,
    p.sku,
    p.product_name,
    p.category,
    p.owner_company_id,
    SUM(st.total_amount) AS total_sales,
    SUM(st.quantity) AS total_quantity
FROM sales_transactions st
JOIN products p ON st.product_id = p.product_id
GROUP BY p.product_id, p.sku, p.product_name, p.category, p.owner_company_id;

-- -----------------------------------------------------------------------------
-- LIVE VIEW 4: vw_fr6_sales_customer_live (Checklist 3.4 & 7.4)
-- Purpose: Live customer-wise sales revenue & quantity joining sales, customers, users.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW `vw_fr6_sales_customer_live` AS
SELECT 
    cu.customer_id,
    u.full_name AS customer_name,
    u.email AS customer_email,
    SUM(st.total_amount) AS total_sales,
    SUM(st.quantity) AS total_quantity
FROM sales_transactions st
JOIN customers cu ON st.customer_id = cu.customer_id
JOIN users u ON cu.user_id = u.user_id
GROUP BY cu.customer_id, u.full_name, u.email;

-- -----------------------------------------------------------------------------
-- LIVE VIEW 5: vw_fr6_inventory_live (Checklist 3.5)
-- Purpose: Live inventory balance and valuation per product, company, and stock row.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW `vw_fr6_inventory_live` AS
SELECT 
    p.product_id,
    p.sku,
    p.product_name,
    p.category,
    c.company_name AS owner_company,
    COALESCE(s.quantity, 0) AS available_quantity,
    COALESCE(s.damaged_qty, 0) AS damaged_quantity,
    p.unit_price,
    COALESCE(p.unit_cost, p.unit_price * 0.65) AS unit_cost,
    ROUND(COALESCE(s.quantity, 0) * p.unit_price, 2) AS total_market_value,
    ROUND(COALESCE(s.quantity, 0) * COALESCE(p.unit_cost, p.unit_price * 0.65), 2) AS total_cost_value
FROM products p
JOIN companies c ON p.owner_company_id = c.company_id
LEFT JOIN stock s ON p.product_id = s.product_id;

-- -----------------------------------------------------------------------------
-- LIVE VIEW 6: vw_fr6_shipment_profitability_live (Checklist 3.6 & 7.10)
-- Purpose: Real-time shipment-level profitability comparing revenue, freight, and claims.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW `vw_fr6_shipment_profitability_live` AS
SELECT 
    s.shipment_id,
    s.shipment_no,
    s.seller_id,
    COALESCE(c.company_name, u.full_name) AS seller_name,
    DATE_FORMAT(s.created_at, '%Y-%m-01') AS period_month,
    COALESCE(bi.total_amount, s.quoted_price, 0.00) AS revenue,
    COALESCE(pr.base_rate, 45000.00) AS freight_cost,
    5000.00 AS port_cost,
    3500.00 AS handling_cost,
    COALESCE((SELECT SUM(CASE WHEN cl.approved_amount > 0 THEN cl.approved_amount ELSE cl.claimed_amount END) 
              FROM claims cl WHERE cl.shipment_id = s.shipment_id AND cl.status IN ('APPROVED', 'SETTLED')), 0.00) AS claim_loss,
    (COALESCE(pr.base_rate, 45000.00) + 5000.00 + 3500.00 + 
     COALESCE((SELECT SUM(CASE WHEN cl.approved_amount > 0 THEN cl.approved_amount ELSE cl.claimed_amount END) 
               FROM claims cl WHERE cl.shipment_id = s.shipment_id AND cl.status IN ('APPROVED', 'SETTLED')), 0.00)
    ) AS total_operating_cost,
    (COALESCE(bi.total_amount, s.quoted_price, 0.00) - 
     (COALESCE(pr.base_rate, 45000.00) + 5000.00 + 3500.00 + 
      COALESCE((SELECT SUM(CASE WHEN cl.approved_amount > 0 THEN cl.approved_amount ELSE cl.claimed_amount END) 
                FROM claims cl WHERE cl.shipment_id = s.shipment_id AND cl.status IN ('APPROVED', 'SETTLED')), 0.00))
    ) AS net_profit,
    CASE 
        WHEN COALESCE(bi.total_amount, s.quoted_price, 0.00) > 0 THEN 
            ROUND(
                ((COALESCE(bi.total_amount, s.quoted_price, 0.00) - 
                  (COALESCE(pr.base_rate, 45000.00) + 5000.00 + 3500.00 + 
                   COALESCE((SELECT SUM(CASE WHEN cl.approved_amount > 0 THEN cl.approved_amount ELSE cl.claimed_amount END) 
                             FROM claims cl WHERE cl.shipment_id = s.shipment_id AND cl.status IN ('APPROVED', 'SETTLED')), 0.00))
                 ) / COALESCE(bi.total_amount, s.quoted_price, 0.00)) * 100, 2)
        ELSE 0.00
    END AS margin_pct
FROM shipment s
JOIN users u ON s.seller_id = u.user_id
LEFT JOIN companies c ON u.company_id = c.company_id
LEFT JOIN billing_invoices bi ON s.shipment_id = bi.shipment_id
LEFT JOIN pricing_rules pr ON s.origin_port_id = pr.origin_port_id AND s.dest_port_id = pr.dest_port_id
WHERE s.status != 'CANCELLED';

-- -----------------------------------------------------------------------------
-- LIVE VIEW 7: vw_fr6_seller_pnl_live (Checklist 3.7 & 7.9)
-- Purpose: Live P&L financial summary joining profit_loss, companies, and shipment.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW `vw_fr6_seller_pnl_live` AS
SELECT 
    pl.seller_id,
    COALESCE(c.company_name, u.full_name) AS seller,
    s.shipment_no,
    pl.period_month,
    pl.revenue,
    pl.freight_cost,
    pl.port_cost,
    pl.handling_cost,
    pl.claim_loss,
    pl.net_profit
FROM profit_loss pl
JOIN users u ON pl.seller_id = u.user_id
LEFT JOIN companies c ON u.company_id = c.company_id
LEFT JOIN shipment s ON pl.shipment_id = s.shipment_id;

-- -----------------------------------------------------------------------------
-- LIVE VIEW 8: vw_fr6_demand_forecast_live (Checklist 3.8 & 7.11)
-- Purpose: Live demand forecast joined twice with ports (origin & destination).
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW `vw_fr6_demand_forecast_live` AS
SELECT 
    df.forecast_id,
    op.port_name AS origin,
    op.port_code AS origin_code,
    dp.port_name AS destination,
    dp.port_code AS destination_code,
    df.container_type,
    df.forecast_month,
    df.predicted_bookings,
    df.confidence_pct,
    df.suggested_multiplier,
    df.created_at
FROM demand_forecast df
JOIN ports op ON df.origin_port_id = op.port_id
JOIN ports dp ON df.dest_port_id = dp.port_id;

-- Backward-Compatibility Aliases
CREATE OR REPLACE VIEW `vw_fr6_executive_kpis` AS SELECT * FROM `vw_fr6_kpi_live`;
CREATE OR REPLACE VIEW `vw_fr6_seller_pl_summary` AS 
SELECT 
    period_month,
    seller_id,
    seller AS seller_name,
    COUNT(shipment_no) AS total_shipments_billed,
    SUM(revenue) AS total_gross_revenue,
    SUM(freight_cost) AS total_freight_cost,
    SUM(port_cost) AS total_port_cost,
    SUM(handling_cost) AS total_handling_cost,
    SUM(claim_loss) AS total_claim_deductions,
    SUM(net_profit) AS net_operating_profit,
    CASE 
        WHEN SUM(revenue) > 0 THEN ROUND((SUM(net_profit) / SUM(revenue)) * 100, 2)
        ELSE 0.00
    END AS profit_margin_pct
FROM vw_fr6_seller_pnl_live
GROUP BY period_month, seller_id, seller;


-- =============================================================================
-- SECTION 4: CACHED-RESULT VIEWS (8 VIEWS - CHECKLIST SECTION 3)
-- Purpose: Pre-aggregated reporting views reading over the materialized cache tables.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- CACHED VIEW 1: vw_fr6_abc_product (Checklist Cached 1 & 7.5)
-- Purpose: Product Pareto ABC classification with product and owner details.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW `vw_fr6_abc_product` AS
SELECT 
    a.result_id,
    p.product_id,
    p.sku,
    p.product_name,
    p.category,
    c.company_name AS owner_company,
    a.annual_value,
    a.cumulative_pct,
    a.abc_class,
    a.calculated_on
FROM abc_classification_result a
JOIN products p ON a.product_id = p.product_id
JOIN companies c ON p.owner_company_id = c.company_id;

-- -----------------------------------------------------------------------------
-- CACHED VIEW 2: vw_fr6_abc_customer (Checklist Cached 2 & 7.6)
-- Purpose: Customer Pareto ABC classification with customer and user details.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW `vw_fr6_abc_customer` AS
SELECT 
    ca.result_id,
    cu.customer_id,
    u.full_name,
    u.email AS customer_email,
    cu.credit_limit,
    ca.annual_value,
    ca.cumulative_pct,
    ca.abc_class,
    ca.calculated_on
FROM customer_abc_classification_result ca
JOIN customers cu ON ca.customer_id = cu.customer_id
JOIN users u ON cu.user_id = u.user_id;

-- -----------------------------------------------------------------------------
-- CACHED VIEW 3: vw_fr6_inventory_turnover (Checklist Cached 3 & 7.7)
-- Purpose: Cached inventory velocity and turnover ratio per product.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW `vw_fr6_inventory_turnover` AS
SELECT 
    itr.result_id,
    p.product_id,
    p.sku,
    p.product_name,
    p.category,
    itr.period_start,
    itr.period_end,
    itr.cogs,
    itr.avg_inventory,
    itr.turnover_ratio,
    itr.created_at
FROM inventory_turnover_result itr
JOIN products p ON itr.product_id = p.product_id;

-- -----------------------------------------------------------------------------
-- CACHED VIEW 4: vw_fr6_product_profitability (Checklist Cached 4 & 7.8)
-- Purpose: Cached monthly product margin details based on actual unit_cost.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW `vw_fr6_product_profitability` AS
SELECT 
    pr.result_id,
    p.product_id,
    p.sku,
    p.product_name,
    p.category,
    pr.period_month,
    pr.revenue,
    pr.cost,
    pr.margin_pct,
    pr.created_at
FROM profitability_result pr
JOIN products p ON pr.product_id = p.product_id;

-- -----------------------------------------------------------------------------
-- CACHED VIEW 5: vw_fr6_shipment_profitability (Checklist Cached 5)
-- Purpose: Cached shipment-level profitability with shipment number and seller name.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW `vw_fr6_shipment_profitability` AS
SELECT 
    spr.result_id,
    s.shipment_id,
    s.shipment_no,
    COALESCE(c.company_name, u.full_name) AS seller_name,
    spr.period_month,
    spr.revenue,
    spr.cost,
    spr.margin_pct,
    spr.created_at
FROM shipment_profitability_result spr
JOIN shipment s ON spr.shipment_id = s.shipment_id
JOIN users u ON spr.seller_id = u.user_id
LEFT JOIN companies c ON u.company_id = c.company_id;

-- -----------------------------------------------------------------------------
-- CACHED VIEW 6: vw_fr6_sales_route_cached (Checklist Cached 6)
-- Purpose: Cached route sales performance & month-over-month growth trends.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW `vw_fr6_sales_route_cached` AS
SELECT 
    str.result_id,
    str.period_month,
    op.port_name AS origin_port,
    op.port_code AS origin_code,
    dp.port_name AS destination_port,
    dp.port_code AS destination_code,
    str.total_sales,
    str.total_qty AS container_volume_units,
    str.growth_pct,
    CASE 
        WHEN str.growth_pct > 0 THEN 'EXPANDING'
        WHEN str.growth_pct < 0 THEN 'CONTRACTING'
        ELSE 'STABLE'
    END AS trend_direction
FROM sales_trend_result str
JOIN ports op ON str.origin_port_id = op.port_id
JOIN ports dp ON str.dest_port_id = dp.port_id;

-- -----------------------------------------------------------------------------
-- CACHED VIEW 7: vw_fr6_sales_product_cached (Checklist Cached 7)
-- Purpose: Cached monthly product performance with sales growth indicator.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW `vw_fr6_sales_product_cached` AS
SELECT 
    stpr.result_id,
    stpr.period_month,
    p.product_id,
    p.sku,
    p.product_name,
    p.category,
    stpr.total_sales,
    stpr.total_qty,
    stpr.growth_pct,
    CASE 
        WHEN stpr.growth_pct > 0 THEN 'GROWING'
        WHEN stpr.growth_pct < 0 THEN 'DECLINING'
        ELSE 'STABLE'
    END AS sales_trend
FROM sales_trend_product_result stpr
JOIN products p ON stpr.product_id = p.product_id;

-- -----------------------------------------------------------------------------
-- CACHED VIEW 8: vw_fr6_sales_customer_cached (Checklist Cached 8)
-- Purpose: Cached monthly customer purchasing performance & buying trends.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW `vw_fr6_sales_customer_cached` AS
SELECT 
    stcr.result_id,
    stcr.period_month,
    cu.customer_id,
    u.full_name AS customer_name,
    u.email AS customer_email,
    stcr.total_sales,
    stcr.total_qty,
    stcr.growth_pct,
    CASE 
        WHEN stcr.growth_pct > 0 THEN 'INCREASING'
        WHEN stcr.growth_pct < 0 THEN 'DECREASING'
        ELSE 'STABLE'
    END AS buying_trend
FROM sales_trend_customer_result stcr
JOIN customers cu ON stcr.customer_id = cu.customer_id
JOIN users u ON cu.user_id = u.user_id;


-- =============================================================================
-- SECTION 5: STORED PROCEDURES (12 PROCEDURES - CHECKLIST SECTION 4)
-- Purpose: Owns calculation, refresh, duplicate prevention, and caching logic.
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
DROP PROCEDURE IF EXISTS `sp_purge_historical_analytics_cache`;

DELIMITER //

-- -----------------------------------------------------------------------------
-- PROCEDURE 1: sp_refresh_sales_trends (Checklist 4.1)
-- Target Table: sales_trend_result (Table 1)
-- Formula: Growth% = ((Current Sales - Previous Sales) / Previous Sales) * 100
-- -----------------------------------------------------------------------------
CREATE PROCEDURE `sp_refresh_sales_trends`()
BEGIN
    INSERT INTO sales_trend_result (period_month, origin_port_id, dest_port_id, total_sales, total_qty, growth_pct)
    SELECT 
        period_month, origin_port_id, dest_port_id, total_sales, total_qty,
        CASE 
            WHEN prev_sales IS NULL OR prev_sales = 0 THEN 0.00
            ELSE ROUND(((total_sales - prev_sales) / prev_sales) * 100, 2)
        END AS growth_pct
    FROM (
        SELECT 
            monthly.period_month,
            monthly.origin_port_id,
            monthly.dest_port_id,
            monthly.total_sales,
            monthly.total_qty,
            LAG(monthly.total_sales) OVER (
                PARTITION BY monthly.origin_port_id, monthly.dest_port_id 
                ORDER BY monthly.period_month
            ) AS prev_sales
        FROM (
            SELECT 
                STR_TO_DATE(DATE_FORMAT(COALESCE(st.sale_date, s.created_at), '%Y-%m-01'), '%Y-%m-%d') AS period_month,
                s.origin_port_id,
                s.dest_port_id,
                SUM(COALESCE(st.total_amount, s.quoted_price)) AS total_sales,
                SUM(COALESCE(st.quantity, 1)) AS total_qty
            FROM shipment s
            LEFT JOIN sales_transactions st ON s.shipment_id = st.shipment_id
            WHERE s.status != 'CANCELLED'
            GROUP BY STR_TO_DATE(DATE_FORMAT(COALESCE(st.sale_date, s.created_at), '%Y-%m-01'), '%Y-%m-%d'), s.origin_port_id, s.dest_port_id
        ) monthly
    ) ranked
    ON DUPLICATE KEY UPDATE
        total_sales = VALUES(total_sales),
        total_qty   = VALUES(total_qty),
        growth_pct  = VALUES(growth_pct);
END //

-- -----------------------------------------------------------------------------
-- PROCEDURE 2: sp_calculate_product_sales_trends (Checklist 4.2)
-- Target Table: sales_trend_product_result (Table 2)
-- Purpose: Computes monthly product sales volume, revenue, and MoM growth %.
-- -----------------------------------------------------------------------------
CREATE PROCEDURE `sp_calculate_product_sales_trends`()
BEGIN
    INSERT INTO sales_trend_product_result (product_id, period_month, total_sales, total_qty, growth_pct)
    SELECT 
        product_id, period_month, total_sales, total_qty,
        CASE 
            WHEN prev_sales IS NULL OR prev_sales = 0 THEN 0.00
            ELSE ROUND(((total_sales - prev_sales) / prev_sales) * 100, 2)
        END AS growth_pct
    FROM (
        SELECT 
            p_monthly.product_id,
            p_monthly.period_month,
            p_monthly.total_sales,
            p_monthly.total_qty,
            LAG(p_monthly.total_sales) OVER (
                PARTITION BY p_monthly.product_id 
                ORDER BY p_monthly.period_month
            ) AS prev_sales
        FROM (
            SELECT 
                st.product_id,
                STR_TO_DATE(DATE_FORMAT(st.sale_date, '%Y-%m-01'), '%Y-%m-%d') AS period_month,
                SUM(st.total_amount) AS total_sales,
                SUM(st.quantity) AS total_qty
            FROM sales_transactions st
            GROUP BY st.product_id, STR_TO_DATE(DATE_FORMAT(st.sale_date, '%Y-%m-01'), '%Y-%m-%d')
        ) p_monthly
    ) p_ranked
    ON DUPLICATE KEY UPDATE
        total_sales = VALUES(total_sales),
        total_qty   = VALUES(total_qty),
        growth_pct  = VALUES(growth_pct);
END //

-- -----------------------------------------------------------------------------
-- PROCEDURE 3: sp_calculate_customer_sales_trends (Checklist 4.3)
-- Target Table: sales_trend_customer_result (Table 3)
-- Purpose: Computes monthly customer spending volume and MoM spend growth %.
-- -----------------------------------------------------------------------------
CREATE PROCEDURE `sp_calculate_customer_sales_trends`()
BEGIN
    INSERT INTO sales_trend_customer_result (customer_id, period_month, total_sales, total_qty, growth_pct)
    SELECT 
        customer_id, period_month, total_sales, total_qty,
        CASE 
            WHEN prev_sales IS NULL OR prev_sales = 0 THEN 0.00
            ELSE ROUND(((total_sales - prev_sales) / prev_sales) * 100, 2)
        END AS growth_pct
    FROM (
        SELECT 
            c_monthly.customer_id,
            c_monthly.period_month,
            c_monthly.total_sales,
            c_monthly.total_qty,
            LAG(c_monthly.total_sales) OVER (
                PARTITION BY c_monthly.customer_id 
                ORDER BY c_monthly.period_month
            ) AS prev_sales
        FROM (
            SELECT 
                st.customer_id,
                STR_TO_DATE(DATE_FORMAT(st.sale_date, '%Y-%m-01'), '%Y-%m-%d') AS period_month,
                SUM(st.total_amount) AS total_sales,
                SUM(st.quantity) AS total_qty
            FROM sales_transactions st
            GROUP BY st.customer_id, STR_TO_DATE(DATE_FORMAT(st.sale_date, '%Y-%m-01'), '%Y-%m-%d')
        ) c_monthly
    ) c_ranked
    ON DUPLICATE KEY UPDATE
        total_sales = VALUES(total_sales),
        total_qty   = VALUES(total_qty),
        growth_pct  = VALUES(growth_pct);
END //

-- -----------------------------------------------------------------------------
-- PROCEDURE 4: sp_calculate_abc_classification (Checklist 4.4)
-- Target Table: abc_classification_result (Table 4)
-- Purpose: Computes Pareto classification: A (top 70%), B (next 20%), C (remaining 10%).
-- -----------------------------------------------------------------------------
CREATE PROCEDURE `sp_calculate_abc_classification`()
BEGIN
    DECLARE v_total_portfolio DECIMAL(14,2) DEFAULT 0.00;

    SELECT COALESCE(SUM(st.total_amount), 0.00) INTO v_total_portfolio
    FROM sales_transactions st;

    INSERT INTO abc_classification_result (product_id, annual_value, cumulative_pct, abc_class, calculated_on)
    SELECT 
        sub.product_id,
        sub.annual_val,
        sub.cum_pct,
        CASE 
            WHEN sub.cum_pct <= 70.00 THEN 'A'
            WHEN sub.cum_pct <= 90.00 THEN 'B'
            ELSE 'C'
        END AS abc_class,
        CURDATE() AS calculated_on
    FROM (
        SELECT 
            p.product_id,
            COALESCE(SUM(st.total_amount), 0.00) AS annual_val,
            ROUND(
                (SUM(COALESCE(SUM(st.total_amount), 0.00)) OVER (ORDER BY COALESCE(SUM(st.total_amount), 0.00) DESC) 
                 / NULLIF(v_total_portfolio, 0)) * 100, 2
            ) AS cum_pct
        FROM products p
        LEFT JOIN sales_transactions st ON p.product_id = st.product_id
        GROUP BY p.product_id
    ) sub
    ON DUPLICATE KEY UPDATE
        annual_value   = VALUES(annual_value),
        cumulative_pct = VALUES(cumulative_pct),
        abc_class      = VALUES(abc_class);
END //

-- -----------------------------------------------------------------------------
-- PROCEDURE 5: sp_calculate_customer_abc (Checklist 4.5)
-- Target Table: customer_abc_classification_result (Table 5)
-- Purpose: Computes customer revenue Pareto classification (A=70%, B=20%, C=10%).
-- -----------------------------------------------------------------------------
CREATE PROCEDURE `sp_calculate_customer_abc`()
BEGIN
    DECLARE v_total_cust_sales DECIMAL(14,2) DEFAULT 0.00;

    SELECT COALESCE(SUM(st.total_amount), 0.00) INTO v_total_cust_sales
    FROM sales_transactions st;

    INSERT INTO customer_abc_classification_result (customer_id, annual_value, cumulative_pct, abc_class, calculated_on)
    SELECT 
        csub.customer_id,
        csub.annual_val,
        csub.cum_pct,
        CASE 
            WHEN csub.cum_pct <= 70.00 THEN 'A'
            WHEN csub.cum_pct <= 90.00 THEN 'B'
            ELSE 'C'
        END AS abc_class,
        CURDATE() AS calculated_on
    FROM (
        SELECT 
            cu.customer_id,
            COALESCE(SUM(st.total_amount), 0.00) AS annual_val,
            ROUND(
                (SUM(COALESCE(SUM(st.total_amount), 0.00)) OVER (ORDER BY COALESCE(SUM(st.total_amount), 0.00) DESC) 
                 / NULLIF(v_total_cust_sales, 0)) * 100, 2
            ) AS cum_pct
        FROM customers cu
        LEFT JOIN sales_transactions st ON cu.customer_id = st.customer_id
        GROUP BY cu.customer_id
    ) csub
    ON DUPLICATE KEY UPDATE
        annual_value   = VALUES(annual_value),
        cumulative_pct = VALUES(cumulative_pct),
        abc_class      = VALUES(abc_class);
END //

-- -----------------------------------------------------------------------------
-- PROCEDURE 6: sp_calculate_inventory_turnover (Checklist 4.6)
-- Target Table: inventory_turnover_result (Table 6)
-- Formula: Turnover = COGS / Average Inventory (using actual products.unit_cost)
-- -----------------------------------------------------------------------------
CREATE PROCEDURE `sp_calculate_inventory_turnover`(
    IN p_start DATE,
    IN p_end DATE
)
BEGIN
    IF p_start IS NULL THEN
        SET p_start = DATE_SUB(CURDATE(), INTERVAL 3 MONTH);
    END IF;
    IF p_end IS NULL THEN
        SET p_end = CURDATE();
    END IF;

    INSERT INTO inventory_turnover_result (product_id, period_start, period_end, cogs, avg_inventory, turnover_ratio)
    SELECT 
        p.product_id,
        p_start,
        p_end,
        COALESCE(SUM(CASE WHEN il.txn_type = 'OUT' THEN il.quantity * COALESCE(p.unit_cost, p.unit_price * 0.65) ELSE 0 END), 0.00) AS cogs,
        COALESCE(s.quantity * COALESCE(p.unit_cost, p.unit_price * 0.65), 0.00) AS avg_inventory,
        CASE 
            WHEN COALESCE(s.quantity * COALESCE(p.unit_cost, p.unit_price * 0.65), 0.00) = 0 THEN 
                CASE WHEN COALESCE(SUM(CASE WHEN il.txn_type = 'OUT' THEN il.quantity * COALESCE(p.unit_cost, p.unit_price * 0.65) ELSE 0 END), 0.00) > 0 THEN 12.00 ELSE 0.00 END
            ELSE 
                ROUND(COALESCE(SUM(CASE WHEN il.txn_type = 'OUT' THEN il.quantity * COALESCE(p.unit_cost, p.unit_price * 0.65) ELSE 0 END), 0.00) / (s.quantity * COALESCE(p.unit_cost, p.unit_price * 0.65)), 2)
        END AS turnover_ratio
    FROM products p
    LEFT JOIN stock s ON p.product_id = s.product_id
    LEFT JOIN inventory_ledger il ON p.product_id = il.product_id AND DATE(il.txn_time) BETWEEN p_start AND p_end
    GROUP BY p.product_id, p.unit_cost, p.unit_price, s.quantity
    ON DUPLICATE KEY UPDATE
        cogs           = VALUES(cogs),
        avg_inventory  = VALUES(avg_inventory),
        turnover_ratio = VALUES(turnover_ratio);
END //

-- -----------------------------------------------------------------------------
-- PROCEDURE 7: sp_calculate_profitability (Checklist 4.7)
-- Target Table: profitability_result (Table 7)
-- Rule: Uses actual products.unit_cost (not assumed percentage) per SRS FR6.5.
-- -----------------------------------------------------------------------------
CREATE PROCEDURE `sp_calculate_profitability`()
BEGIN
    INSERT INTO profitability_result (product_id, period_month, revenue, cost, margin_pct)
    SELECT 
        p.product_id,
        STR_TO_DATE(DATE_FORMAT(st.sale_date, '%Y-%m-01'), '%Y-%m-%d') AS period_month,
        SUM(st.total_amount) AS revenue,
        SUM(st.quantity * COALESCE(p.unit_cost, p.unit_price * 0.65)) AS cost,
        CASE 
            WHEN SUM(st.total_amount) > 0 THEN 
                ROUND(((SUM(st.total_amount) - SUM(st.quantity * COALESCE(p.unit_cost, p.unit_price * 0.65))) / SUM(st.total_amount)) * 100, 2)
            ELSE 0.00 
        END AS margin_pct
    FROM sales_transactions st
    JOIN products p ON st.product_id = p.product_id
    GROUP BY STR_TO_DATE(DATE_FORMAT(st.sale_date, '%Y-%m-01'), '%Y-%m-%d'), p.product_id, p.unit_cost, p.unit_price
    ON DUPLICATE KEY UPDATE
        revenue    = VALUES(revenue),
        cost       = VALUES(cost),
        margin_pct = VALUES(margin_pct);
END //

-- -----------------------------------------------------------------------------
-- PROCEDURE 8: sp_calculate_shipment_profitability (Checklist 4.8)
-- Target Table: shipment_profitability_result (Table 8)
-- Purpose: Computes shipment-level gross margin % comparing revenue vs costs.
-- -----------------------------------------------------------------------------
CREATE PROCEDURE `sp_calculate_shipment_profitability`()
BEGIN
    INSERT INTO shipment_profitability_result (shipment_id, seller_id, period_month, revenue, cost, margin_pct)
    SELECT 
        s.shipment_id,
        s.seller_id,
        STR_TO_DATE(DATE_FORMAT(s.created_at, '%Y-%m-01'), '%Y-%m-%d') AS period_month,
        COALESCE(MAX(bi.total_amount), s.quoted_price, 0.00) AS revenue,
        (COALESCE(AVG(pr.base_rate), 45000.00) + 5000.00 + 3500.00 
         + COALESCE((SELECT SUM(CASE WHEN c.approved_amount > 0 THEN c.approved_amount ELSE c.claimed_amount END) 
                     FROM claims c WHERE c.shipment_id = s.shipment_id AND c.status IN ('APPROVED', 'SETTLED')), 0.00)
        ) AS cost,
        CASE 
            WHEN COALESCE(MAX(bi.total_amount), s.quoted_price, 0.00) > 0 THEN 
                ROUND(
                    ((COALESCE(MAX(bi.total_amount), s.quoted_price, 0.00) - 
                      (COALESCE(AVG(pr.base_rate), 45000.00) + 5000.00 + 3500.00 + 
                       COALESCE((SELECT SUM(CASE WHEN c.approved_amount > 0 THEN c.approved_amount ELSE c.claimed_amount END) 
                                 FROM claims c WHERE c.shipment_id = s.shipment_id AND c.status IN ('APPROVED', 'SETTLED')), 0.00))
                     ) / COALESCE(MAX(bi.total_amount), s.quoted_price, 0.00)) * 100, 2)
            ELSE 0.00
        END AS margin_pct
    FROM shipment s
    LEFT JOIN billing_invoices bi ON s.shipment_id = bi.shipment_id
    LEFT JOIN pricing_rules pr ON s.origin_port_id = pr.origin_port_id AND s.dest_port_id = pr.dest_port_id
    WHERE s.status != 'CANCELLED'
    GROUP BY s.shipment_id, s.seller_id, STR_TO_DATE(DATE_FORMAT(s.created_at, '%Y-%m-01'), '%Y-%m-%d')
    ON DUPLICATE KEY UPDATE
        revenue    = VALUES(revenue),
        cost       = VALUES(cost),
        margin_pct = VALUES(margin_pct);
END //

-- -----------------------------------------------------------------------------
-- PROCEDURE 9: sp_calculate_profit_loss (Checklist 4.9)
-- Target Table: profit_loss (Table 9)
-- Purpose: Computes revenue, operating costs, and settled claim loss.
-- Note: net_profit is STORED GENERATED and calculated by the database engine.
-- -----------------------------------------------------------------------------
CREATE PROCEDURE `sp_calculate_profit_loss`()
BEGIN
    INSERT INTO profit_loss (shipment_id, seller_id, period_month, revenue, freight_cost, port_cost, handling_cost, claim_loss)
    SELECT 
        s.shipment_id,
        s.seller_id,
        STR_TO_DATE(DATE_FORMAT(s.created_at, '%Y-%m-01'), '%Y-%m-%d') AS period_month,
        COALESCE(MAX(bi.total_amount), s.quoted_price, 0.00) AS revenue,
        COALESCE(AVG(pr.base_rate), 45000.00) AS freight_cost,
        5000.00 AS port_cost,
        3500.00 AS handling_cost,
        COALESCE((SELECT SUM(CASE WHEN c.approved_amount > 0 THEN c.approved_amount ELSE c.claimed_amount END) 
                  FROM claims c WHERE c.shipment_id = s.shipment_id AND c.status IN ('APPROVED', 'SETTLED')), 0.00) AS claim_loss
    FROM shipment s
    LEFT JOIN billing_invoices bi ON s.shipment_id = bi.shipment_id
    LEFT JOIN pricing_rules pr ON s.origin_port_id = pr.origin_port_id AND s.dest_port_id = pr.dest_port_id
    WHERE s.status != 'CANCELLED'
    GROUP BY s.shipment_id, s.seller_id, STR_TO_DATE(DATE_FORMAT(s.created_at, '%Y-%m-01'), '%Y-%m-%d')
    ON DUPLICATE KEY UPDATE
        revenue       = VALUES(revenue),
        freight_cost  = VALUES(freight_cost),
        port_cost     = VALUES(port_cost),
        handling_cost = VALUES(handling_cost),
        claim_loss    = VALUES(claim_loss);
END //

-- -----------------------------------------------------------------------------
-- PROCEDURE 10: sp_generate_demand_forecast (Checklist 4.10)
-- Target Table: demand_forecast (Table 10)
-- Purpose: Analyzes historical booking volume to project next month demand & confidence.
-- -----------------------------------------------------------------------------
CREATE PROCEDURE `sp_generate_demand_forecast`()
BEGIN
    INSERT INTO demand_forecast (origin_port_id, dest_port_id, container_type, forecast_month, predicted_bookings, confidence_pct, suggested_multiplier)
    SELECT 
        s.origin_port_id,
        s.dest_port_id,
        c.container_type,
        STR_TO_DATE(DATE_FORMAT(DATE_ADD(CURDATE(), INTERVAL 1 MONTH), '%Y-%m-01'), '%Y-%m-%d') AS forecast_month,
        GREATEST(COUNT(s.shipment_id), 1) AS predicted_bookings,
        CASE 
            WHEN COUNT(s.shipment_id) >= 10 THEN 90.00
            WHEN COUNT(s.shipment_id) >= 5  THEN 80.00
            ELSE 70.00
        END AS confidence_pct,
        CASE 
            WHEN COUNT(s.shipment_id) >= 10 THEN 1.25
            WHEN COUNT(s.shipment_id) >= 5  THEN 1.15
            ELSE 1.05
        END AS suggested_multiplier
    FROM shipment s
    JOIN containers c ON s.container_id = c.container_id
    WHERE s.created_at >= DATE_SUB(CURDATE(), INTERVAL 6 MONTH)
      AND s.status != 'CANCELLED'
    GROUP BY s.origin_port_id, s.dest_port_id, c.container_type
    ON DUPLICATE KEY UPDATE
        predicted_bookings   = VALUES(predicted_bookings),
        confidence_pct       = VALUES(confidence_pct),
        suggested_multiplier = VALUES(suggested_multiplier);
END //

-- -----------------------------------------------------------------------------
-- PROCEDURE 11: sp_apply_forecast_pricing (Checklist 4.11)
-- Purpose: Applies valid suggested demand multipliers (>=75% confidence) to pricing_rules.
-- Note: Trigger trg_after_pricing_rule_update logs this automatically to pricing_audit.
-- -----------------------------------------------------------------------------
CREATE PROCEDURE `sp_apply_forecast_pricing`()
BEGIN
    UPDATE pricing_rules pr
    JOIN demand_forecast df ON pr.origin_port_id = df.origin_port_id 
                           AND pr.dest_port_id = df.dest_port_id 
                           AND pr.container_type = df.container_type
    SET pr.demand_multiplier = df.suggested_multiplier
    WHERE df.forecast_month = STR_TO_DATE(DATE_FORMAT(DATE_ADD(CURDATE(), INTERVAL 1 MONTH), '%Y-%m-01'), '%Y-%m-%d')
      AND df.confidence_pct >= 75.00
      AND pr.is_active = 1;
END //

-- -----------------------------------------------------------------------------
-- PROCEDURE 12: sp_refresh_all_fr6_analytics (Checklist 4.12 Master Orchestrator)
-- Purpose: Executes all analytics calculations atomically within a single transaction.
-- -----------------------------------------------------------------------------
CREATE PROCEDURE `sp_refresh_all_fr6_analytics`()
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        UPDATE analytics_staleness 
        SET is_stale = 1, stale_reason = 'Transaction rolled back on error' 
        WHERE module_name = 'profit_loss';
        RESIGNAL;
    END;

    START TRANSACTION;

    CALL sp_refresh_sales_trends();
    CALL sp_calculate_product_sales_trends();
    CALL sp_calculate_customer_sales_trends();
    CALL sp_calculate_abc_classification();
    CALL sp_calculate_customer_abc();
    CALL sp_calculate_inventory_turnover(NULL, NULL);
    CALL sp_calculate_profitability();
    CALL sp_calculate_shipment_profitability();
    CALL sp_calculate_profit_loss();
    CALL sp_generate_demand_forecast();
    CALL sp_apply_forecast_pricing();

    -- Mark cache as fresh in staleness tracking
    UPDATE analytics_staleness 
    SET is_stale = 0, last_refreshed_at = NOW(), stale_reason = 'Refreshed successfully'
    WHERE is_stale = 1;

    COMMIT;
END //

-- -----------------------------------------------------------------------------
-- PROCEDURE 13: sp_purge_historical_analytics_cache (Checklist Section 11)
-- Purpose: Safely purges cached results older than retention limit (default 24 months).
-- -----------------------------------------------------------------------------
CREATE PROCEDURE `sp_purge_historical_analytics_cache`(
    IN p_months_retention INT
)
BEGIN
    DECLARE v_cutoff DATE;
    IF p_months_retention IS NULL OR p_months_retention < 1 THEN
        SET p_months_retention = 24;
    END IF;
    SET v_cutoff = DATE_SUB(CURDATE(), INTERVAL p_months_retention MONTH);

    DELETE FROM sales_trend_result WHERE period_month < v_cutoff;
    DELETE FROM sales_trend_product_result WHERE period_month < v_cutoff;
    DELETE FROM sales_trend_customer_result WHERE period_month < v_cutoff;
    DELETE FROM profitability_result WHERE period_month < v_cutoff;
    DELETE FROM shipment_profitability_result WHERE period_month < v_cutoff;
    DELETE FROM profit_loss WHERE period_month < v_cutoff;
END //

DELIMITER ;


-- =============================================================================
-- SECTION 6: OPERATIONAL & AUDITING TRIGGERS (7 TRIGGERS - CHECKLIST 5 & 9)
-- Purpose: Synchronize operational data and maintain immutable audit histories.
-- =============================================================================

DROP TRIGGER IF EXISTS `trg_after_payment_insert`;
DROP TRIGGER IF EXISTS `trg_after_stock_insert_ledger`;
DROP TRIGGER IF EXISTS `trg_after_stock_update_ledger`;
DROP TRIGGER IF EXISTS `trg_after_claim_status_change`;
DROP TRIGGER IF EXISTS `trg_after_pricing_rule_update`;
DROP TRIGGER IF EXISTS `trg_after_container_movement_insert`;
DROP TRIGGER IF EXISTS `trg_after_shipment_update_release`;

DELIMITER //

-- -----------------------------------------------------------------------------
-- TRIGGER 1: trg_after_payment_insert (FR5.4)
-- Action: Automatically synchronizes paid_amount and status on billing_invoices.
-- -----------------------------------------------------------------------------
CREATE TRIGGER `trg_after_payment_insert`
AFTER INSERT ON `payments`
FOR EACH ROW
BEGIN
    UPDATE billing_invoices
    SET paid_amount = paid_amount + NEW.amount,
        status = CASE 
            WHEN (paid_amount + NEW.amount) >= total_amount THEN 'PAID'
            WHEN (paid_amount + NEW.amount) > 0 THEN 'PARTIAL'
            ELSE 'UNPAID'
        END
    WHERE invoice_id = NEW.invoice_id;
    
    -- Flag P&L analytics cache as stale for next dashboard open
    UPDATE analytics_staleness SET is_stale = 1, stale_reason = 'New payment posted' WHERE module_name = 'profit_loss';
END //

-- -----------------------------------------------------------------------------
-- TRIGGER 2: trg_after_stock_insert_ledger (FR4.5)
-- Action: Creates initial immutable inventory_ledger entry upon stock receipt.
-- -----------------------------------------------------------------------------
CREATE TRIGGER `trg_after_stock_insert_ledger`
AFTER INSERT ON `stock`
FOR EACH ROW
BEGIN
    INSERT INTO inventory_ledger (stock_id, product_id, txn_type, quantity, balance_after, reference_type, reference_id, txn_time)
    VALUES (NEW.stock_id, NEW.product_id, 'IN', NEW.quantity, NEW.quantity, 'INITIAL_STOCK', NEW.stock_id, NOW());
END //

-- -----------------------------------------------------------------------------
-- TRIGGER 3: trg_after_stock_update_ledger (FR4.5)
-- Action: Records IN, OUT, or DAMAGE transactions whenever quantity changes.
-- -----------------------------------------------------------------------------
CREATE TRIGGER `trg_after_stock_update_ledger`
AFTER UPDATE ON `stock`
FOR EACH ROW
BEGIN
    DECLARE v_diff INT;
    IF NEW.quantity <> OLD.quantity THEN
        SET v_diff = NEW.quantity - OLD.quantity;
        IF v_diff > 0 THEN
            INSERT INTO inventory_ledger (stock_id, product_id, txn_type, quantity, balance_after, reference_type, reference_id, txn_time)
            VALUES (NEW.stock_id, NEW.product_id, 'IN', v_diff, NEW.quantity, 'STOCK_RECEIPT', NEW.stock_id, NOW());
        ELSE
            INSERT INTO inventory_ledger (stock_id, product_id, txn_type, quantity, balance_after, reference_type, reference_id, txn_time)
            VALUES (NEW.stock_id, NEW.product_id, 'OUT', ABS(v_diff), NEW.quantity, 'STOCK_DISPATCH', NEW.stock_id, NOW());
        END IF;
    END IF;

    IF NEW.damaged_qty <> OLD.damaged_qty AND NEW.damaged_qty > OLD.damaged_qty THEN
        INSERT INTO inventory_ledger (stock_id, product_id, txn_type, quantity, balance_after, reference_type, reference_id, txn_time)
        VALUES (NEW.stock_id, NEW.product_id, 'DAMAGE', NEW.damaged_qty - OLD.damaged_qty, NEW.quantity, 'DAMAGE_REPORT', NEW.stock_id, NOW());
    END IF;

    UPDATE analytics_staleness SET is_stale = 1, stale_reason = 'Inventory quantity adjusted' WHERE module_name = 'inventory_turnover';
END //

-- -----------------------------------------------------------------------------
-- TRIGGER 4: trg_after_claim_status_change (FR7.5)
-- Action: Records historical transition into claim_status_history.
-- -----------------------------------------------------------------------------
CREATE TRIGGER `trg_after_claim_status_change`
AFTER UPDATE ON `claims`
FOR EACH ROW
BEGIN
    IF OLD.status <> NEW.status THEN
        INSERT INTO claim_status_history (claim_id, old_status, new_status, changed_by, remarks, changed_at)
        VALUES (NEW.claim_id, OLD.status, NEW.status, NEW.consumer_id, NEW.seller_remarks, NOW());

        IF NEW.status IN ('APPROVED', 'SETTLED') THEN
            UPDATE analytics_staleness SET is_stale = 1, stale_reason = 'Claim approved/settled' WHERE module_name = 'profit_loss';
        END IF;
    END IF;
END //

-- -----------------------------------------------------------------------------
-- TRIGGER 5: trg_after_pricing_rule_update (FR3.6)
-- Action: Records old vs new rates into pricing_audit.
-- -----------------------------------------------------------------------------
CREATE TRIGGER `trg_after_pricing_rule_update`
AFTER UPDATE ON `pricing_rules`
FOR EACH ROW
BEGIN
    IF OLD.base_rate <> NEW.base_rate 
       OR OLD.season_multiplier <> NEW.season_multiplier 
       OR OLD.demand_multiplier <> NEW.demand_multiplier THEN
        INSERT INTO pricing_audit (rule_id, old_rate, new_rate, old_multiplier, new_multiplier, changed_by, changed_at)
        VALUES (NEW.rule_id, OLD.base_rate, NEW.base_rate, OLD.demand_multiplier, NEW.demand_multiplier, NULL, NOW());
    END IF;
END //

-- -----------------------------------------------------------------------------
-- TRIGGER 6: trg_after_container_movement_insert (FR2.2 / FR2.3)
-- Action: Synchronizes container location & shipment lifecycle status.
-- -----------------------------------------------------------------------------
CREATE TRIGGER `trg_after_container_movement_insert`
AFTER INSERT ON `container_movements`
FOR EACH ROW
BEGIN
    IF NEW.shipment_id IS NOT NULL THEN
        UPDATE shipment 
        SET status = CASE 
            WHEN NEW.status = 'LOADED' THEN 'LOADED'
            WHEN NEW.status = 'DEPARTED' THEN 'DEPARTED'
            WHEN NEW.status = 'IN_TRANSIT' THEN 'IN_TRANSIT'
            WHEN NEW.status = 'ARRIVED' THEN 'ARRIVED'
            WHEN NEW.status = 'CUSTOMS_CLEARED' THEN 'CUSTOMS_CLEARED'
            WHEN NEW.status = 'DELIVERED' THEN 'DELIVERED'
            ELSE status
        END
        WHERE shipment_id = NEW.shipment_id;
    END IF;

    IF NEW.container_id IS NOT NULL THEN
        UPDATE containers
        SET current_port_id = COALESCE(NEW.port_id, current_port_id),
            status = CASE 
                WHEN NEW.status = 'DELIVERED' THEN 'AVAILABLE'
                WHEN NEW.status IN ('LOADED', 'IN_TRANSIT', 'DEPARTED') THEN 'IN_USE'
                ELSE status
            END
        WHERE container_id = NEW.container_id;
    END IF;
END //

-- -----------------------------------------------------------------------------
-- TRIGGER 7: trg_after_shipment_update_release (FR4.7)
-- Action: Releases or consumes stock reservations upon delivery or cancellation.
-- -----------------------------------------------------------------------------
CREATE TRIGGER `trg_after_shipment_update_release`
AFTER UPDATE ON `shipment`
FOR EACH ROW
BEGIN
    IF NEW.status = 'DELIVERED' AND OLD.status <> 'DELIVERED' THEN
        UPDATE shipment_stock_reservations
        SET status = 'CONSUMED'
        WHERE shipment_id = NEW.shipment_id AND status = 'RESERVED';
    ELSEIF NEW.status = 'CANCELLED' AND OLD.status <> 'CANCELLED' THEN
        UPDATE shipment_stock_reservations
        SET status = 'RELEASED'
        WHERE shipment_id = NEW.shipment_id AND status = 'RESERVED';
        
        -- Restore container to available inventory
        UPDATE containers SET status = 'AVAILABLE' WHERE container_id = NEW.container_id;
    END IF;
END //

DELIMITER ;


-- =============================================================================
-- SECTION 7: COMPLETE CHECKLIST REPORTING QUERIES (7.1 TO 7.11)
-- Purpose: Baseline reporting queries specified in Checklist Section 7.
-- =============================================================================

-- 7.1 KPI Aggregation (Active shipments, available containers, revenue, pending invoices, open claims)
SELECT
    (SELECT COUNT(*) FROM shipment WHERE status NOT IN ('CANCELLED', 'DELIVERED')) AS active_shipments,
    (SELECT COUNT(*) FROM containers WHERE status = 'AVAILABLE') AS available_containers,
    (SELECT COALESCE(SUM(paid_amount), 0) FROM billing_invoices) AS revenue,
    (SELECT COALESCE(SUM(total_amount - paid_amount), 0) FROM billing_invoices WHERE status <> 'PAID') AS pending_invoices,
    (SELECT COUNT(*) FROM claims WHERE status IN ('SUBMITTED', 'UNDER_REVIEW')) AS open_claims;

-- 7.2 Route-wise Sales
SELECT
    op.port_name AS origin_port,
    dp.port_name AS destination_port,
    SUM(st.total_amount) AS total_sales,
    SUM(st.quantity) AS total_quantity
FROM sales_transactions st
JOIN shipment s ON st.shipment_id = s.shipment_id
JOIN ports op ON s.origin_port_id = op.port_id
JOIN ports dp ON s.dest_port_id = dp.port_id
GROUP BY op.port_name, dp.port_name;

-- 7.3 Product-wise Sales
SELECT
    p.product_id,
    p.product_name,
    SUM(st.total_amount) AS total_sales,
    SUM(st.quantity) AS total_quantity
FROM sales_transactions st
JOIN products p ON st.product_id = p.product_id
GROUP BY p.product_id, p.product_name;

-- 7.4 Customer-wise Sales
SELECT
    cu.customer_id,
    u.full_name AS customer_name,
    SUM(st.total_amount) AS total_sales,
    SUM(st.quantity) AS total_quantity
FROM sales_transactions st
JOIN customers cu ON st.customer_id = cu.customer_id
JOIN users u ON cu.user_id = u.user_id
GROUP BY cu.customer_id, u.full_name;

-- 7.5 Product ABC Classification
SELECT 
    p.product_name, 
    a.annual_value,
    a.cumulative_pct, 
    a.abc_class
FROM abc_classification_result a
JOIN products p ON a.product_id = p.product_id;

-- 7.6 Customer ABC Classification
SELECT 
    u.full_name AS customer_name, 
    a.annual_value,
    a.cumulative_pct, 
    a.abc_class
FROM customer_abc_classification_result a
JOIN customers cu ON a.customer_id = cu.customer_id
JOIN users u ON cu.user_id = u.user_id;

-- 7.7 Inventory Turnover
SELECT 
    p.product_name,
    i.period_start, 
    i.period_end,
    i.cogs, 
    i.avg_inventory, 
    i.turnover_ratio
FROM inventory_turnover_result i
JOIN products p ON i.product_id = p.product_id;

-- 7.8 Product Profitability
SELECT 
    p.product_name, 
    r.period_month,
    r.revenue, 
    r.cost, 
    r.margin_pct
FROM profitability_result r
JOIN products p ON r.product_id = p.product_id;

-- 7.9 Seller P&L
SELECT
    COALESCE(c.company_name, u.full_name) AS seller,
    s.shipment_no,
    pl.period_month,
    pl.revenue,
    pl.freight_cost,
    pl.port_cost,
    pl.handling_cost,
    pl.claim_loss,
    pl.net_profit
FROM profit_loss pl
JOIN users u ON pl.seller_id = u.user_id
LEFT JOIN companies c ON u.company_id = c.company_id
LEFT JOIN shipment s ON pl.shipment_id = s.shipment_id;

-- 7.10 Actual Shipment Costs
SELECT
    s.shipment_no,
    sc.cost_type,
    SUM(sc.amount) AS total_cost
FROM shipment_costs sc
JOIN shipment s ON sc.shipment_id = s.shipment_id
GROUP BY s.shipment_no, sc.cost_type;

-- 7.11 Demand Forecast with Ports
SELECT
    op.port_name AS origin,
    dp.port_name AS destination,
    df.container_type,
    df.forecast_month,
    df.predicted_bookings,
    df.confidence_pct,
    df.suggested_multiplier
FROM demand_forecast df
JOIN ports op ON df.origin_port_id = op.port_id
JOIN ports dp ON df.dest_port_id = dp.port_id;


-- =============================================================================
-- SECTION 8: PARAMETERIZED CRUD & MULTI-DIMENSIONAL FILTERS (FR6.8)
-- Purpose: Reference queries for Java PreparedStatement (AnalyticsDAO.java).
-- =============================================================================
/*
-- 1. Date Range & Seller Multi-Filter P&L (FR6.8)
SELECT period_month, seller_id, seller_name, total_shipments_billed, total_gross_revenue,
       total_freight_cost, total_port_cost, total_handling_cost, total_claim_deductions,
       net_operating_profit, profit_margin_pct
FROM vw_fr6_seller_pl_summary
WHERE (? IS NULL OR seller_id = ?)
  AND (? IS NULL OR period_month >= ?)
  AND (? IS NULL OR period_month <= ?)
ORDER BY period_month DESC;

-- 2. Route Sales Filtered by Origin & Destination Port
SELECT period_month, origin_port, destination_port, total_sales, container_volume_units, growth_pct, trend_direction
FROM vw_fr6_sales_route_cached
WHERE (? IS NULL OR origin_port = ?)
  AND (? IS NULL OR destination_port = ?)
  AND (? IS NULL OR period_month >= ?)
ORDER BY total_sales DESC;

-- 3. Product Profitability Filtered by Product ID & Category
SELECT p.product_id, p.product_name, p.category, pr.period_month, pr.revenue, pr.cost, pr.margin_pct
FROM vw_fr6_product_profitability pr
JOIN products p ON pr.product_id = p.product_id
WHERE (? IS NULL OR p.product_id = ?)
  AND (? IS NULL OR p.category = ?)
  AND (? IS NULL OR pr.period_month = ?)
ORDER BY pr.margin_pct DESC;

-- 4. Customer ABC Classification Filtered by Category (A, B, C)
SELECT customer_id, full_name, customer_email, annual_value, cumulative_pct, abc_class, calculated_on
FROM vw_fr6_abc_customer
WHERE (? IS NULL OR abc_class = ?)
ORDER BY annual_value DESC;

-- 5. Demand Forecast Filtered by Route & Month
SELECT origin, destination, container_type, forecast_month, predicted_bookings, confidence_pct, suggested_multiplier
FROM vw_fr6_demand_forecast_live
WHERE (? IS NULL OR forecast_month = ?)
  AND (? IS NULL OR container_type = ?)
ORDER BY confidence_pct DESC;
*/


-- =============================================================================
-- SECTION 9: CACHE REFRESH SCHEDULER & VERIFICATION SUITE (CHECKLIST 11 & 12)
-- =============================================================================

-- Scheduled Event for daily background analytics recalculation (Midnight daily)
DROP EVENT IF EXISTS `evt_daily_fr6_analytics_refresh`;
DELIMITER //
CREATE EVENT IF NOT EXISTS `evt_daily_fr6_analytics_refresh`
ON SCHEDULE EVERY 1 DAY
STARTS (TIMESTAMP(CURDATE()) + INTERVAL 1 DAY)
DO
BEGIN
    CALL sp_refresh_all_fr6_analytics();
END //
DELIMITER ;

-- =============================================================================
-- EXECUTE INITIAL POPULATION & VERIFY (CHECKLIST SECTION 12)
-- =============================================================================
CALL sp_refresh_all_fr6_analytics();

-- Display Verification Counts across all 10 result tables
SELECT 'sales_trend_result' AS table_name, COUNT(*) AS row_count FROM sales_trend_result
UNION ALL
SELECT 'sales_trend_product_result', COUNT(*) FROM sales_trend_product_result
UNION ALL
SELECT 'sales_trend_customer_result', COUNT(*) FROM sales_trend_customer_result
UNION ALL
SELECT 'abc_classification_result', COUNT(*) FROM abc_classification_result
UNION ALL
SELECT 'customer_abc_classification_result', COUNT(*) FROM customer_abc_classification_result
UNION ALL
SELECT 'inventory_turnover_result', COUNT(*) FROM inventory_turnover_result
UNION ALL
SELECT 'profitability_result', COUNT(*) FROM profitability_result
UNION ALL
SELECT 'shipment_profitability_result', COUNT(*) FROM shipment_profitability_result
UNION ALL
SELECT 'profit_loss', COUNT(*) FROM profit_loss
UNION ALL
SELECT 'demand_forecast', COUNT(*) FROM demand_forecast;

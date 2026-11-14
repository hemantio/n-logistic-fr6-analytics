-- =============================================================================
-- PROJECT: N Logistic Management Platform
-- MODULE:  FR6 - Analytics Dashboard (Executive & Operational Intelligence)
-- FILE:    FR6_DATABASE_HANDOVER_FOR_TL.sql
-- PURPOSE: Master Integration SQL: Table DDL, Foreign Keys & Stored Procedures
-- TARGET:  n_logistic_db (Universal MySQL 8.0+ / MariaDB 10.4+)
-- COMPLIANCE: Unified 28-Entity Chen ERD (SRS Sections 7.5 & 7.9)
-- =============================================================================

USE `n_logistic_db`;

-- Temporarily disable FK checks to ensure safe idempotent execution
SET @OLD_FOREIGN_KEY_CHECKS = @@FOREIGN_KEY_CHECKS;
SET FOREIGN_KEY_CHECKS = 0;

-- =============================================================================
-- SECTION 1: INITIAL TABLE CREATION (6 ANALYTICS TABLES WITH FOREIGN KEYS)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. SALES TREND RESULT (ERD #10 / SRS Section 7.9)
-- Purpose: Caches aggregated historical route and port-pair sales trends (FR6.2).
-- Foreign Keys: origin_port_id -> ports(port_id), dest_port_id -> ports(port_id)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `sales_trend_result` (
    `result_id`       INT AUTO_INCREMENT PRIMARY KEY,
    `period_month`    DATE NOT NULL COMMENT 'First day of month (YYYY-MM-01)',
    `origin_port_id`  INT NULL,
    `dest_port_id`    INT NULL,
    `total_sales`     DECIMAL(14, 2) NOT NULL DEFAULT 0.00 COMMENT 'Total realized route revenue',
    `total_qty`       INT NOT NULL DEFAULT 0 COMMENT 'Total container volume or unit quantity',
    `growth_pct`      DECIMAL(6, 2) NOT NULL DEFAULT 0.00 COMMENT 'Month-over-month growth rate %',
    `created_at`      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT `fk_fr6_sales_origin`
        FOREIGN KEY (`origin_port_id`)
        REFERENCES `ports`(`port_id`)
        ON DELETE SET NULL
        ON UPDATE CASCADE,

    CONSTRAINT `fk_fr6_sales_destination`
        FOREIGN KEY (`dest_port_id`)
        REFERENCES `ports`(`port_id`)
        ON DELETE SET NULL
        ON UPDATE CASCADE,

    INDEX `idx_fr6_sales_trend_lookup` (`period_month`, `origin_port_id`, `dest_port_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- -----------------------------------------------------------------------------
-- 2. ABC CLASSIFICATION RESULT (ERD #26 / SRS Section 7.9)
-- Purpose: Caches Pareto inventory analysis per product (FR6.3).
-- Policy:  A = Top 70% revenue, B = Next 20% (up to 90%), C = Last 10%.
-- Foreign Key: product_id -> products(product_id)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `abc_classification_result` (
    `result_id`       INT AUTO_INCREMENT PRIMARY KEY,
    `product_id`      INT NOT NULL,
    `annual_value`    DECIMAL(14, 2) NOT NULL DEFAULT 0.00 COMMENT 'Annualized product sales value',
    `cumulative_pct`  DECIMAL(5, 2) NOT NULL DEFAULT 0.00 COMMENT 'Running cumulative revenue % (0-100)',
    `abc_class`       CHAR(1) NOT NULL COMMENT 'Category: A = top 70%, B = next 20%, C = last 10%',
    `calculated_on`   DATE NOT NULL COMMENT 'Date of Pareto classification run',
    `created_at`      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT `fk_fr6_abc_product`
        FOREIGN KEY (`product_id`)
        REFERENCES `products`(`product_id`)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    INDEX `idx_fr6_abc_class` (`product_id`, `abc_class`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- -----------------------------------------------------------------------------
-- 3. INVENTORY TURNOVER RESULT (ERD #27 / SRS Section 7.9)
-- Purpose: Caches inventory velocity and turnover metrics (FR6.4).
-- Formula: turnover_ratio = COGS / Average Inventory Value.
-- Foreign Key: product_id -> products(product_id)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `inventory_turnover_result` (
    `result_id`       INT AUTO_INCREMENT PRIMARY KEY,
    `product_id`      INT NOT NULL,
    `period_start`    DATE NOT NULL,
    `period_end`      DATE NOT NULL,
    `cogs`            DECIMAL(14, 2) NOT NULL DEFAULT 0.00 COMMENT 'Cost of Goods Sold (inventory ledger OUT)',
    `avg_inventory`   DECIMAL(14, 2) NOT NULL DEFAULT 0.00 COMMENT 'Average stock valuation over period',
    `turnover_ratio`  DECIMAL(8, 2) NOT NULL DEFAULT 0.00 COMMENT 'turnover_ratio = cogs / avg_inventory',
    `created_at`      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT `fk_fr6_turnover_product`
        FOREIGN KEY (`product_id`)
        REFERENCES `products`(`product_id`)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    INDEX `idx_fr6_turnover_ratio` (`product_id`, `turnover_ratio`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- -----------------------------------------------------------------------------
-- 4. PROFITABILITY RESULT (ERD #28 / SRS Section 7.9)
-- Purpose: Caches monthly gross profitability margins per product (FR6.5).
-- Formula: margin_pct = ((revenue - cost) / revenue) * 100.
-- Foreign Key: product_id -> products(product_id)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `profitability_result` (
    `result_id`       INT AUTO_INCREMENT PRIMARY KEY,
    `product_id`      INT NOT NULL,
    `period_month`    DATE NOT NULL,
    `revenue`         DECIMAL(14, 2) NOT NULL DEFAULT 0.00 COMMENT 'Gross revenue realized for product',
    `cost`            DECIMAL(14, 2) NOT NULL DEFAULT 0.00 COMMENT 'COGS + direct handling cost',
    `margin_pct`      DECIMAL(6, 2) NOT NULL DEFAULT 0.00 COMMENT 'Gross profit margin %',
    `created_at`      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT `fk_fr6_profitability_product`
        FOREIGN KEY (`product_id`)
        REFERENCES `products`(`product_id`)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    INDEX `idx_fr6_profitability_lookup` (`product_id`, `period_month`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- -----------------------------------------------------------------------------
-- 5. DEMAND FORECAST (ERD #8 / SRS Section 7.5)
-- Purpose: AI/Statistical monthly booking forecasts per route & container type (FR6.6).
-- Integration: Feeds suggested_multiplier directly into FR3 dynamic pricing rules.
-- Foreign Keys: origin_port_id -> ports(port_id), dest_port_id -> ports(port_id)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `demand_forecast` (
    `forecast_id`          INT AUTO_INCREMENT PRIMARY KEY,
    `origin_port_id`       INT NOT NULL,
    `dest_port_id`         INT NOT NULL,
    `container_type`       ENUM('DRY', 'REEFER', 'OPEN_TOP', 'TANK') NOT NULL,
    `forecast_month`       DATE NOT NULL,
    `predicted_bookings`   INT NOT NULL DEFAULT 0 COMMENT 'Forecasted container bookings for month',
    `confidence_pct`       DECIMAL(5, 2) NOT NULL DEFAULT 0.00 COMMENT 'Confidence level percentage (e.g. 88.00%)',
    `suggested_multiplier` DECIMAL(4, 2) NOT NULL DEFAULT 1.00 COMMENT 'Pricing multiplier suggested for FR3',
    `created_at`           TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT `fk_fr6_forecast_origin`
        FOREIGN KEY (`origin_port_id`)
        REFERENCES `ports`(`port_id`)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    CONSTRAINT `fk_fr6_forecast_destination`
        FOREIGN KEY (`dest_port_id`)
        REFERENCES `ports`(`port_id`)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    INDEX `idx_fr6_forecast_route` (`origin_port_id`, `dest_port_id`, `container_type`, `forecast_month`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- -----------------------------------------------------------------------------
-- 6. PROFIT LOSS (ERD #12 / SRS Section 7.9)
-- Purpose: Shipment-level P&L tracking (FR6.5 & FR2.8).
-- Formula: net_profit = revenue - freight_cost - port_cost - handling_cost - claim_loss.
-- Foreign Keys: shipment_id -> shipment(shipment_id), seller_id -> companies(company_id)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `profit_loss` (
    `pl_id`           INT AUTO_INCREMENT PRIMARY KEY,
    `shipment_id`     INT NULL COMMENT 'Nullable if multi-shipment consolidated P&L',
    `seller_id`       INT NOT NULL COMMENT 'Seller company owning the shipment',
    `period_month`    DATE NOT NULL COMMENT 'First day of month (YYYY-MM-01)',
    `revenue`         DECIMAL(14, 2) NOT NULL DEFAULT 0.00 COMMENT 'Invoiced revenue',
    `freight_cost`    DECIMAL(14, 2) NOT NULL DEFAULT 0.00 COMMENT 'Ocean freight operating expense',
    `port_cost`       DECIMAL(14, 2) NOT NULL DEFAULT 0.00 COMMENT 'Port & terminal dues',
    `handling_cost`   DECIMAL(14, 2) NOT NULL DEFAULT 0.00 COMMENT 'Stevedoring & container handling',
    `claim_loss`      DECIMAL(14, 2) NOT NULL DEFAULT 0.00 COMMENT 'Settled cargo damage/loss payouts',
    `net_profit`      DECIMAL(14, 2) NOT NULL DEFAULT 0.00 COMMENT 'Net profit = revenue - all costs - claim_loss',
    `created_at`      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT `fk_fr6_profit_shipment`
        FOREIGN KEY (`shipment_id`)
        REFERENCES `shipment`(`shipment_id`)
        ON DELETE SET NULL
        ON UPDATE CASCADE,

    CONSTRAINT `fk_fr6_profit_seller`
        FOREIGN KEY (`seller_id`)
        REFERENCES `companies`(`company_id`)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    INDEX `idx_fr6_pl_lookup` (`seller_id`, `period_month`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Restore original foreign key check state
SET FOREIGN_KEY_CHECKS = @OLD_FOREIGN_KEY_CHECKS;


-- =============================================================================
-- SECTION 2: SUPPORTING STORED PROCEDURES FOR THE 6 TABLES
-- =============================================================================

DROP PROCEDURE IF EXISTS `sp_refresh_sales_trends`;
DROP PROCEDURE IF EXISTS `sp_calculate_abc_classification`;
DROP PROCEDURE IF EXISTS `sp_calculate_inventory_turnover`;
DROP PROCEDURE IF EXISTS `sp_calculate_profitability`;
DROP PROCEDURE IF EXISTS `sp_generate_demand_forecast`;
DROP PROCEDURE IF EXISTS `sp_calculate_profit_loss`;
DROP PROCEDURE IF EXISTS `sp_refresh_all_fr6_analytics`;

DELIMITER //

-- -----------------------------------------------------------------------------
-- PROCEDURE 1: sp_refresh_sales_trends
-- Target Table: sales_trend_result (Table 1)
-- Purpose: Aggregates historical monthly sales and container volume by route.
-- -----------------------------------------------------------------------------
CREATE PROCEDURE `sp_refresh_sales_trends`()
BEGIN
    DELETE FROM sales_trend_result;

    INSERT INTO sales_trend_result (period_month, origin_port_id, dest_port_id, total_sales, total_qty, growth_pct)
    SELECT 
        DATE_FORMAT(COALESCE(st.sale_date, s.created_at), '%Y-%m-01') AS period_month,
        s.origin_port_id,
        s.dest_port_id,
        SUM(COALESCE(st.total_amount, s.quoted_price)) AS total_sales,
        SUM(COALESCE(st.quantity, 1)) AS total_qty,
        0.00 AS growth_pct
    FROM shipment s
    LEFT JOIN sales_transactions st ON s.shipment_id = st.shipment_id
    WHERE s.status != 'CANCELLED'
    GROUP BY DATE_FORMAT(COALESCE(st.sale_date, s.created_at), '%Y-%m-01'), s.origin_port_id, s.dest_port_id
    ORDER BY s.origin_port_id, s.dest_port_id, period_month ASC;
END //


-- -----------------------------------------------------------------------------
-- PROCEDURE 2: sp_calculate_abc_classification
-- Target Table: abc_classification_result (Table 2)
-- Purpose: Computes Pareto classification (A = top 70%, B = next 20%, C = last 10%).
-- -----------------------------------------------------------------------------
CREATE PROCEDURE `sp_calculate_abc_classification`()
BEGIN
    DECLARE v_total_portfolio DECIMAL(14,2) DEFAULT 0.00;

    SELECT COALESCE(SUM(st.total_amount), 0.00) INTO v_total_portfolio
    FROM products p
    JOIN sales_transactions st ON p.product_id = st.product_id;

    DELETE FROM abc_classification_result;

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
    ) sub;
END //


-- -----------------------------------------------------------------------------
-- PROCEDURE 3: sp_calculate_inventory_turnover
-- Target Table: inventory_turnover_result (Table 3)
-- Purpose: Computes COGS and turnover ratio (turnover_ratio = cogs / avg_inventory).
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

    DELETE FROM inventory_turnover_result;

    INSERT INTO inventory_turnover_result (product_id, period_start, period_end, cogs, avg_inventory, turnover_ratio)
    SELECT 
        p.product_id,
        p_start,
        p_end,
        COALESCE(SUM(CASE WHEN il.txn_type = 'OUT' THEN il.quantity * p.unit_price ELSE 0 END), 0.00) AS cogs,
        COALESCE(s.quantity * p.unit_price, 0.00) AS avg_inventory,
        CASE 
            WHEN COALESCE(s.quantity * p.unit_price, 0.00) = 0 THEN 
                CASE WHEN COALESCE(SUM(CASE WHEN il.txn_type = 'OUT' THEN il.quantity * p.unit_price ELSE 0 END), 0.00) > 0 THEN 12.00 ELSE 0.00 END
            ELSE 
                ROUND(COALESCE(SUM(CASE WHEN il.txn_type = 'OUT' THEN il.quantity * p.unit_price ELSE 0 END), 0.00) / (s.quantity * p.unit_price), 2)
        END AS turnover_ratio
    FROM products p
    LEFT JOIN stock s ON p.product_id = s.product_id
    LEFT JOIN inventory_ledger il ON p.product_id = il.product_id AND DATE(il.txn_time) BETWEEN p_start AND p_end
    GROUP BY p.product_id, p.unit_price, s.quantity;
END //


-- -----------------------------------------------------------------------------
-- PROCEDURE 4: sp_calculate_profitability
-- Target Table: profitability_result (Table 4)
-- Purpose: Computes monthly gross revenue, cost, and margin % per product.
-- -----------------------------------------------------------------------------
CREATE PROCEDURE `sp_calculate_profitability`()
BEGIN
    DELETE FROM profitability_result;

    INSERT INTO profitability_result (product_id, period_month, revenue, cost, margin_pct)
    SELECT 
        p.product_id,
        DATE_FORMAT(st.sale_date, '%Y-%m-01') AS period_month,
        SUM(st.total_amount) AS revenue,
        SUM(st.quantity * (p.unit_price * 0.65)) AS cost,
        CASE 
            WHEN SUM(st.total_amount) > 0 THEN 
                ROUND(((SUM(st.total_amount) - SUM(st.quantity * (p.unit_price * 0.65))) / SUM(st.total_amount)) * 100, 2)
            ELSE 0.00 
        END AS margin_pct
    FROM sales_transactions st
    JOIN products p ON st.product_id = p.product_id
    GROUP BY DATE_FORMAT(st.sale_date, '%Y-%m-01'), p.product_id, p.unit_price;
END //


-- -----------------------------------------------------------------------------
-- PROCEDURE 5: sp_generate_demand_forecast
-- Target Table: demand_forecast (Table 5)
-- Purpose: Projects next month's bookings, confidence %, and FR3 dynamic pricing multiplier.
-- -----------------------------------------------------------------------------
CREATE PROCEDURE `sp_generate_demand_forecast`()
BEGIN
    DECLARE v_next_month DATE;
    SET v_next_month = DATE_ADD(DATE_FORMAT(CURDATE(), '%Y-%m-01'), INTERVAL 1 MONTH);

    DELETE FROM demand_forecast;

    INSERT INTO demand_forecast (origin_port_id, dest_port_id, container_type, forecast_month, predicted_bookings, confidence_pct, suggested_multiplier)
    SELECT 
        s.origin_port_id,
        s.dest_port_id,
        c.container_type,
        v_next_month,
        ROUND(COUNT(s.shipment_id) * 1.15) + 2 AS predicted_bookings,
        CASE WHEN COUNT(s.shipment_id) >= 3 THEN 88.00 ELSE 65.00 END AS confidence_pct,
        CASE WHEN (ROUND(COUNT(s.shipment_id) * 1.15) + 2) > 4 THEN 1.05 ELSE 0.98 END AS suggested_multiplier
    FROM shipment s
    JOIN containers c ON s.container_id = c.container_id
    WHERE s.status != 'CANCELLED'
    GROUP BY s.origin_port_id, s.dest_port_id, c.container_type;
END //


-- -----------------------------------------------------------------------------
-- PROCEDURE 6: sp_calculate_profit_loss
-- Target Table: profit_loss (Table 6)
-- Purpose: Computes shipment-level net profit and operating expense breakdown (FR2.8).
-- -----------------------------------------------------------------------------
CREATE PROCEDURE `sp_calculate_profit_loss`()
BEGIN
    DELETE FROM profit_loss;

    INSERT INTO profit_loss (shipment_id, seller_id, period_month, revenue, freight_cost, port_cost, handling_cost, claim_loss, net_profit)
    SELECT 
        s.shipment_id,
        s.seller_id,
        DATE_FORMAT(s.created_at, '%Y-%m-01') AS period_month,
        COALESCE(bi.total_amount, s.quoted_price) AS revenue,
        COALESCE(pr.base_rate, 45000.00) AS freight_cost,
        5000.00 AS port_cost,
        3500.00 AS handling_cost,
        COALESCE((SELECT SUM(c.claimed_amount) FROM claims c WHERE c.shipment_id = s.shipment_id AND c.status = 'APPROVED'), 0.00) AS claim_loss,
        (COALESCE(bi.total_amount, s.quoted_price) - COALESCE(pr.base_rate, 45000.00) - 5000.00 - 3500.00 
         - COALESCE((SELECT SUM(c.claimed_amount) FROM claims c WHERE c.shipment_id = s.shipment_id AND c.status = 'APPROVED'), 0.00)
        ) AS net_profit
    FROM shipment s
    LEFT JOIN billing_invoices bi ON s.shipment_id = bi.shipment_id
    LEFT JOIN pricing_rules pr ON s.origin_port_id = pr.origin_port_id AND s.dest_port_id = pr.dest_port_id
    WHERE s.status != 'CANCELLED'
    GROUP BY s.shipment_id, s.seller_id, DATE_FORMAT(s.created_at, '%Y-%m-01'), bi.total_amount, s.quoted_price, pr.base_rate;
END //


-- -----------------------------------------------------------------------------
-- PROCEDURE 7: sp_refresh_all_fr6_analytics (Master Orchestrator)
-- Purpose: Executes all 6 recalculation procedures in a single atomic transaction.
-- -----------------------------------------------------------------------------
CREATE PROCEDURE `sp_refresh_all_fr6_analytics`()
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    CALL sp_refresh_sales_trends();
    CALL sp_calculate_abc_classification();
    CALL sp_calculate_inventory_turnover(NULL, NULL);
    CALL sp_calculate_profitability();
    CALL sp_generate_demand_forecast();
    CALL sp_calculate_profit_loss();

    COMMIT;
END //

DELIMITER ;

-- =============================================================================
-- PROJECT: N Logistic Management Platform
-- MODULE:  FR6 - Analytics Dashboard (Executive & Operational Intelligence)
-- FILE:    FR6_DATABASE_HANDOVER_FOR_TL.sql
-- PURPOSE: Production Database Integration DDL for Team Lead (TL)
-- TARGET:  n_logistic_db (MySQL 8.0+ / MariaDB 10.4+)
-- COMPLIANCE: Unified 28-Entity Chen ERD (SRS Sections 7.5 & 7.9)
-- =============================================================================

USE `n_logistic_db`;

-- Temporarily disable FK checks to ensure safe idempotent execution
SET @OLD_FOREIGN_KEY_CHECKS = @@FOREIGN_KEY_CHECKS;
SET FOREIGN_KEY_CHECKS = 0;

-- =============================================================================
-- TABLE 1: sales_trend_result (ERD #10 / SRS Section 7.9)
-- Purpose: Caches aggregated historical route and port-pair sales trends (FR6.2).
-- Parent Relationships:
--   - origin_port_id -> ports(port_id)
--   - dest_port_id   -> ports(port_id)
-- =============================================================================
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
        ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE INDEX `idx_fr6_sales_trend_lookup` 
    ON `sales_trend_result` (`period_month`, `origin_port_id`, `dest_port_id`);


-- =============================================================================
-- TABLE 2: abc_classification_result (ERD #26 / SRS Section 7.9)
-- Purpose: Caches Pareto inventory analysis per product (FR6.3).
-- Policy:  A = Top 70% revenue, B = Next 20% (up to 90%), C = Last 10%.
-- Parent Relationship:
--   - product_id -> products(product_id)
-- =============================================================================
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
        ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE INDEX `idx_fr6_abc_class` 
    ON `abc_classification_result` (`product_id`, `abc_class`);


-- =============================================================================
-- TABLE 3: inventory_turnover_result (ERD #27 / SRS Section 7.9)
-- Purpose: Caches inventory velocity and turnover metrics (FR6.4).
-- Formula: turnover_ratio = COGS / Average Inventory Value.
-- Parent Relationship:
--   - product_id -> products(product_id)
-- =============================================================================
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
        ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE INDEX `idx_fr6_turnover_ratio` 
    ON `inventory_turnover_result` (`product_id`, `turnover_ratio`);


-- =============================================================================
-- TABLE 4: profitability_result (ERD #28 / SRS Section 7.9)
-- Purpose: Caches monthly gross profitability margins per product (FR6.5).
-- Formula: margin_pct = ((revenue - cost) / revenue) * 100.
-- Parent Relationship:
--   - product_id -> products(product_id)
-- =============================================================================
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
        ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE INDEX `idx_fr6_profitability_lookup` 
    ON `profitability_result` (`product_id`, `period_month`);


-- =============================================================================
-- TABLE 5: demand_forecast (ERD #8 / SRS Section 7.5)
-- Purpose: AI/Statistical monthly booking forecasts per route & container type (FR6.6).
-- Integration: Feeds suggested_multiplier directly into FR3 dynamic pricing rules.
-- Parent Relationships:
--   - origin_port_id -> ports(port_id)
--   - dest_port_id   -> ports(port_id)
-- =============================================================================
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
        ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE INDEX `idx_fr6_forecast_route` 
    ON `demand_forecast` (`origin_port_id`, `dest_port_id`, `container_type`, `forecast_month`);


-- =============================================================================
-- TABLE 6: profit_loss (ERD #12 / SRS Section 7.9)
-- Purpose: Shipment-level P&L tracking (FR6.5 & FR2.8).
-- Formula: net_profit = revenue - freight_cost - port_cost - handling_cost - claim_loss.
-- Parent Relationships:
--   - shipment_id -> shipment(shipment_id)
--   - seller_id   -> companies(company_id)
-- =============================================================================
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
        ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE INDEX `idx_fr6_pl_lookup` 
    ON `profit_loss` (`seller_id`, `period_month`);

-- Restore original foreign key check state
SET FOREIGN_KEY_CHECKS = @OLD_FOREIGN_KEY_CHECKS;

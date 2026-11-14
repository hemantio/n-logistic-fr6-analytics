-- =============================================================================
-- Module: FR6 - Analytics Dashboard
-- Script: fr6_schema.sql
-- Description: DDL script creating FR6 analytics tables with full Foreign Keys
-- Target Database: n_logistic_db
-- Compliance: Strictly adheres to SRS Section 7.9 & Unified 28-Entity Chen ERD
-- =============================================================================

USE `n_logistic_db`;

-- =====================================================
-- 1. SALES TREND RESULT (SRS 7.9 / ERD #10)
-- References: ports(port_id)
-- =====================================================
CREATE TABLE IF NOT EXISTS `sales_trend_result` (
    `result_id` INT AUTO_INCREMENT PRIMARY KEY,
    `period_month` DATE NOT NULL,
    `origin_port_id` INT NULL,
    `dest_port_id` INT NULL,
    `total_sales` DECIMAL(14, 2) NOT NULL DEFAULT 0.00,
    `total_qty` INT NOT NULL DEFAULT 0,
    `growth_pct` DECIMAL(6, 2) NOT NULL DEFAULT 0.00,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT `fk_fr6_sales_origin`
        FOREIGN KEY (`origin_port_id`)
        REFERENCES `ports`(`port_id`)
        ON DELETE SET NULL,

    CONSTRAINT `fk_fr6_sales_destination`
        FOREIGN KEY (`dest_port_id`)
        REFERENCES `ports`(`port_id`)
        ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- =====================================================
-- 2. ABC CLASSIFICATION RESULT (SRS 7.9 / ERD #26)
-- References: products(product_id)
-- =====================================================
CREATE TABLE IF NOT EXISTS `abc_classification_result` (
    `result_id` INT AUTO_INCREMENT PRIMARY KEY,
    `product_id` INT NOT NULL,
    `annual_value` DECIMAL(14, 2) NOT NULL DEFAULT 0.00,
    `cumulative_pct` DECIMAL(5, 2) NOT NULL DEFAULT 0.00,
    `abc_class` CHAR(1) NOT NULL COMMENT 'A = top 70%, B = next 20%, C = last 10%',
    `calculated_on` DATE NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT `fk_fr6_abc_product`
        FOREIGN KEY (`product_id`)
        REFERENCES `products`(`product_id`)
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- =====================================================
-- 3. INVENTORY TURNOVER RESULT (SRS 7.9 / ERD #27)
-- References: products(product_id)
-- =====================================================
CREATE TABLE IF NOT EXISTS `inventory_turnover_result` (
    `result_id` INT AUTO_INCREMENT PRIMARY KEY,
    `product_id` INT NOT NULL,
    `period_start` DATE NOT NULL,
    `period_end` DATE NOT NULL,
    `cogs` DECIMAL(14, 2) NOT NULL DEFAULT 0.00 COMMENT 'Cost of goods sold',
    `avg_inventory` DECIMAL(14, 2) NOT NULL DEFAULT 0.00,
    `turnover_ratio` DECIMAL(8, 2) NOT NULL DEFAULT 0.00 COMMENT 'COGS / Average Inventory',
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT `fk_fr6_turnover_product`
        FOREIGN KEY (`product_id`)
        REFERENCES `products`(`product_id`)
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- =====================================================
-- 4. PROFITABILITY RESULT (SRS 7.9 / ERD #28)
-- References: products(product_id)
-- =====================================================
CREATE TABLE IF NOT EXISTS `profitability_result` (
    `result_id` INT AUTO_INCREMENT PRIMARY KEY,
    `product_id` INT NOT NULL,
    `period_month` DATE NOT NULL,
    `revenue` DECIMAL(14, 2) NOT NULL DEFAULT 0.00,
    `cost` DECIMAL(14, 2) NOT NULL DEFAULT 0.00,
    `margin_pct` DECIMAL(6, 2) NOT NULL DEFAULT 0.00,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT `fk_fr6_profitability_product`
        FOREIGN KEY (`product_id`)
        REFERENCES `products`(`product_id`)
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- =====================================================
-- 5. PROFIT AND LOSS (SRS 7.9 / ERD #11)
-- References: shipment(shipment_id), companies(company_id)
-- =====================================================
CREATE TABLE IF NOT EXISTS `profit_loss` (
    `pl_id` INT AUTO_INCREMENT PRIMARY KEY,
    `shipment_id` INT NULL,
    `seller_id` INT NOT NULL,
    `period_month` DATE NOT NULL COMMENT 'First day of month',
    `revenue` DECIMAL(14, 2) NOT NULL DEFAULT 0.00,
    `freight_cost` DECIMAL(14, 2) NOT NULL DEFAULT 0.00,
    `port_cost` DECIMAL(14, 2) NOT NULL DEFAULT 0.00,
    `handling_cost` DECIMAL(14, 2) NOT NULL DEFAULT 0.00,
    `claim_loss` DECIMAL(14, 2) NOT NULL DEFAULT 0.00 COMMENT 'Added when claim is settled',
    `net_profit` DECIMAL(14, 2) NOT NULL DEFAULT 0.00 COMMENT 'revenue - all costs - claim_loss',
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT `fk_fr6_profit_shipment`
        FOREIGN KEY (`shipment_id`)
        REFERENCES `shipment`(`shipment_id`)
        ON DELETE SET NULL,

    CONSTRAINT `fk_fr6_profit_seller`
        FOREIGN KEY (`seller_id`)
        REFERENCES `companies`(`company_id`)
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

/*
===============================================================================
N LOGISTIC DATABASE - CONSOLIDATED MASTER SCRIPT (BASE + SRS FIX PATCH)
===============================================================================
This file combines the uploaded original master SQL and the extension patch.
Run ONCE against a fresh/test n_logistic_db database after backing up existing
data. The extension section includes ALTER TABLE statements and is not safe to
re-run on a database that already has those added columns/constraints.
See n_logistic_db_module_crud_reference.sql for parameterized Java DAO SQL.
===============================================================================
*/

-- =============================================================================
-- PROJECT: N Logistic Import & Export / Logistics Management Platform
-- DATABASE: n_logistic_db (MySQL 8.0+ / MariaDB 10.4+ on XAMPP)
-- ENGINE:   InnoDB, CHARSET: utf8mb4, COLLATION: utf8mb4_unicode_ci
-- PURPOSE:  COMPLETE MASTER DATABASE IMPLEMENTATION:
--           1. All 28 Tables (Exact SRS Section 7 & Chen ERD Compliance)
--           2. Foreign Keys, Cascades & Integrity Constraints
--           3. High-Performance Query & Join Indexes
--           4. Cross-Module JOIN Views (Analytics, Operations, Invoicing, Claims)
--           5. Automated Business Triggers (Ledger, Invoices, Claims, Status History)
--           6. Core Stored Procedures (Dynamic Pricing, Claim Settlement & Analytics)
-- =============================================================================

CREATE DATABASE IF NOT EXISTS `n_logistic_db` 
    DEFAULT CHARACTER SET utf8mb4 
    COLLATE utf8mb4_unicode_ci;

USE `n_logistic_db`;

-- Temporarily disable FK checks to ensure safe idempotent DDL execution
SET @OLD_FOREIGN_KEY_CHECKS = @@FOREIGN_KEY_CHECKS;
SET FOREIGN_KEY_CHECKS = 0;

-- =============================================================================
-- SECTION 1: MASTER SCHEMA DDL - ALL 28 TABLES
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. COMPANIES (SRS 7.3 / ERD #2)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `companies` (
    `company_id`    INT AUTO_INCREMENT PRIMARY KEY,
    `company_name`  VARCHAR(150) NOT NULL,
    `company_type`  ENUM('CONSUMER', 'SELLER') NOT NULL,
    `gst_number`    VARCHAR(20) UNIQUE NULL,
    `iec_code`      VARCHAR(15) NULL COMMENT 'Import Export Code',
    `address`       TEXT NULL,
    `city`          VARCHAR(60) NULL,
    `country`       VARCHAR(60) NULL,
    `created_at`    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    INDEX `idx_companies_type` (`company_type`),
    INDEX `idx_companies_gst` (`gst_number`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- -----------------------------------------------------------------------------
-- 2. USERS (SRS 7.3 / ERD #1)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `users` (
    `user_id`         INT AUTO_INCREMENT PRIMARY KEY,
    `role`            ENUM('ADMIN', 'CONSUMER', 'SELLER') NOT NULL,
    `company_id`      INT NULL COMMENT 'NULL for Admin',
    `full_name`       VARCHAR(100) NOT NULL,
    `email`           VARCHAR(120) NOT NULL UNIQUE,
    `password_hash`   VARCHAR(255) NOT NULL COMMENT 'BCrypt hash',
    `phone`           VARCHAR(20) NULL,
    `status`          ENUM('ACTIVE', 'INACTIVE', 'LOCKED') NOT NULL DEFAULT 'ACTIVE',
    `failed_attempts` INT NOT NULL DEFAULT 0,
    `last_login`      DATETIME NULL,
    `created_at`      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT `fk_users_company`
        FOREIGN KEY (`company_id`)
        REFERENCES `companies`(`company_id`)
        ON DELETE SET NULL
        ON UPDATE CASCADE,

    INDEX `idx_users_email` (`email`),
    INDEX `idx_users_role_status` (`role`, `status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- -----------------------------------------------------------------------------
-- 3. CUSTOMERS (SRS 7.3 / ERD #3)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `customers` (
    `customer_id`    INT AUTO_INCREMENT PRIMARY KEY,
    `user_id`        INT NOT NULL UNIQUE,
    `company_id`     INT NULL,
    `contact_person` VARCHAR(100) NULL,
    `billing_address` TEXT NULL,
    `credit_limit`   DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    `created_at`     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT `fk_customers_user`
        FOREIGN KEY (`user_id`)
        REFERENCES `users`(`user_id`)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    CONSTRAINT `fk_customers_company`
        FOREIGN KEY (`company_id`)
        REFERENCES `companies`(`company_id`)
        ON DELETE SET NULL
        ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- -----------------------------------------------------------------------------
-- 4. AUDIT_LOG (SRS 7.3 / ERD #4)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `audit_log` (
    `log_id`      BIGINT AUTO_INCREMENT PRIMARY KEY,
    `user_id`     INT NULL,
    `action`      VARCHAR(100) NOT NULL COMMENT 'INSERT, UPDATE, DELETE, LOGIN...',
    `table_name`  VARCHAR(60) NULL,
    `record_id`   BIGINT NULL,
    `old_value`   JSON NULL,
    `new_value`   JSON NULL,
    `ip_address`  VARCHAR(45) NULL,
    `created_at`  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT `fk_audit_user`
        FOREIGN KEY (`user_id`)
        REFERENCES `users`(`user_id`)
        ON DELETE SET NULL
        ON UPDATE CASCADE,

    INDEX `idx_audit_table_record` (`table_name`, `record_id`),
    INDEX `idx_audit_user_action` (`user_id`, `action`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- -----------------------------------------------------------------------------
-- 5. PORTS (SRS 7.4 / ERD #9)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `ports` (
    `port_id`    INT AUTO_INCREMENT PRIMARY KEY,
    `port_code`  VARCHAR(10) NOT NULL UNIQUE COMMENT 'e.g. INNSA, SGSIN',
    `port_name`  VARCHAR(100) NOT NULL,
    `city`       VARCHAR(60) NOT NULL,
    `country`    VARCHAR(60) NOT NULL,
    `latitude`   DECIMAL(9, 6) NULL,
    `longitude`  DECIMAL(9, 6) NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    INDEX `idx_ports_code` (`port_code`),
    INDEX `idx_ports_country` (`country`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- -----------------------------------------------------------------------------
-- 6. VESSELS (SRS 7.4 / ERD #5)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `vessels` (
    `vessel_id`         INT AUTO_INCREMENT PRIMARY KEY,
    `vessel_name`       VARCHAR(100) NOT NULL,
    `imo_number`        VARCHAR(15) UNIQUE NULL,
    `owner_company_id`  INT NULL,
    `capacity_teu`      INT NOT NULL DEFAULT 0,
    `status`            ENUM('ACTIVE', 'MAINTENANCE') NOT NULL DEFAULT 'ACTIVE',
    `created_at`        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT `fk_vessels_owner`
        FOREIGN KEY (`owner_company_id`)
        REFERENCES `companies`(`company_id`)
        ON DELETE SET NULL
        ON UPDATE CASCADE,

    INDEX `idx_vessels_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- -----------------------------------------------------------------------------
-- 7. CONTAINERS (SRS 7.4 / ERD #14)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `containers` (
    `container_id`     INT AUTO_INCREMENT PRIMARY KEY,
    `container_number` VARCHAR(15) NOT NULL UNIQUE,
    `seller_id`        INT NOT NULL,
    `container_type`   ENUM('DRY', 'REEFER', 'OPEN_TOP', 'TANK') NOT NULL,
    `size_ft`          TINYINT NOT NULL COMMENT '20 or 40',
    `max_weight_kg`    DECIMAL(10, 2) NOT NULL,
    `max_volume_cbm`   DECIMAL(8, 2) NOT NULL,
    `current_port_id`  INT NULL,
    `status`           ENUM('AVAILABLE', 'ALLOCATED', 'IN_TRANSIT', 'MAINTENANCE') NOT NULL DEFAULT 'AVAILABLE',
    `created_at`       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT `fk_containers_seller`
        FOREIGN KEY (`seller_id`)
        REFERENCES `companies`(`company_id`)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,

    CONSTRAINT `fk_containers_port`
        FOREIGN KEY (`current_port_id`)
        REFERENCES `ports`(`port_id`)
        ON DELETE SET NULL
        ON UPDATE CASCADE,

    INDEX `idx_containers_status_port` (`status`, `current_port_id`),
    INDEX `idx_containers_seller` (`seller_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- -----------------------------------------------------------------------------
-- 8. SHIPMENT (SRS 7.4 / ERD #11)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `shipment` (
    `shipment_id`        INT AUTO_INCREMENT PRIMARY KEY,
    `shipment_no`        VARCHAR(20) NOT NULL UNIQUE,
    `consumer_id`        INT NOT NULL,
    `seller_id`          INT NOT NULL,
    `container_id`       INT NOT NULL,
    `vessel_id`          INT NULL,
    `origin_port_id`     INT NOT NULL,
    `dest_port_id`       INT NOT NULL,
    `cargo_description`  VARCHAR(255) NULL,
    `cargo_weight_kg`    DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
    `cargo_volume_cbm`   DECIMAL(8, 2) NOT NULL DEFAULT 0.00,
    `quoted_price`       DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    `status`             ENUM('BOOKED', 'LOADED', 'DEPARTED', 'IN_TRANSIT', 'ARRIVED', 'CUSTOMS_CLEARED', 'DELIVERED', 'CANCELLED') NOT NULL DEFAULT 'BOOKED',
    `etd`                DATE NULL,
    `eta`                DATE NULL,
    `actual_arrival`     DATE NULL,
    `created_at`         TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT `fk_shipment_consumer`
        FOREIGN KEY (`consumer_id`)
        REFERENCES `customers`(`customer_id`)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,

    CONSTRAINT `fk_shipment_seller`
        FOREIGN KEY (`seller_id`)
        REFERENCES `companies`(`company_id`)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,

    CONSTRAINT `fk_shipment_container`
        FOREIGN KEY (`container_id`)
        REFERENCES `containers`(`container_id`)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,

    CONSTRAINT `fk_shipment_vessel`
        FOREIGN KEY (`vessel_id`)
        REFERENCES `vessels`(`vessel_id`)
        ON DELETE SET NULL
        ON UPDATE CASCADE,

    CONSTRAINT `fk_shipment_origin_port`
        FOREIGN KEY (`origin_port_id`)
        REFERENCES `ports`(`port_id`)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,

    CONSTRAINT `fk_shipment_dest_port`
        FOREIGN KEY (`dest_port_id`)
        REFERENCES `ports`(`port_id`)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,

    INDEX `idx_shipment_status` (`status`),
    INDEX `idx_shipment_route` (`origin_port_id`, `dest_port_id`),
    INDEX `idx_shipment_seller_consumer` (`seller_id`, `consumer_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- -----------------------------------------------------------------------------
-- 9. CONTAINER_MOVEMENTS (SRS 7.4 / ERD #13)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `container_movements` (
    `movement_id`    BIGINT AUTO_INCREMENT PRIMARY KEY,
    `shipment_id`    INT NOT NULL,
    `container_id`   INT NOT NULL,
    `status`         ENUM('BOOKED', 'LOADED', 'DEPARTED', 'IN_TRANSIT', 'ARRIVED', 'CUSTOMS_CLEARED', 'DELIVERED', 'CANCELLED') NOT NULL,
    `port_id`        INT NULL,
    `location_text`  VARCHAR(150) NULL,
    `event_time`     DATETIME NOT NULL,
    `remarks`        VARCHAR(255) NULL,
    `updated_by`     INT NULL,
    `created_at`     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT `fk_movement_shipment`
        FOREIGN KEY (`shipment_id`)
        REFERENCES `shipment`(`shipment_id`)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    CONSTRAINT `fk_movement_container`
        FOREIGN KEY (`container_id`)
        REFERENCES `containers`(`container_id`)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    CONSTRAINT `fk_movement_port`
        FOREIGN KEY (`port_id`)
        REFERENCES `ports`(`port_id`)
        ON DELETE SET NULL
        ON UPDATE CASCADE,

    CONSTRAINT `fk_movement_user`
        FOREIGN KEY (`updated_by`)
        REFERENCES `users`(`user_id`)
        ON DELETE SET NULL
        ON UPDATE CASCADE,

    INDEX `idx_movement_shipment_time` (`shipment_id`, `event_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- -----------------------------------------------------------------------------
-- 10. PRODUCTS (SRS 7.6 / ERD #24)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `products` (
    `product_id`        INT AUTO_INCREMENT PRIMARY KEY,
    `sku`               VARCHAR(40) NOT NULL UNIQUE,
    `product_name`      VARCHAR(120) NOT NULL,
    `category`          VARCHAR(60) NULL,
    `hs_code`           VARCHAR(12) NULL COMMENT 'Harmonized System tariff code',
    `unit`              VARCHAR(10) NULL COMMENT 'kg, box, pcs',
    `unit_weight_kg`    DECIMAL(8, 3) NOT NULL DEFAULT 1.000,
    `unit_price`        DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    `owner_company_id`  INT NOT NULL,
    `created_at`        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT `fk_products_company`
        FOREIGN KEY (`owner_company_id`)
        REFERENCES `companies`(`company_id`)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    INDEX `idx_products_owner` (`owner_company_id`),
    INDEX `idx_products_sku` (`sku`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- -----------------------------------------------------------------------------
-- 11. SHIPMENT_ITEMS (SRS 7.4 / ERD #16)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `shipment_items` (
    `item_id`      INT AUTO_INCREMENT PRIMARY KEY,
    `shipment_id`  INT NOT NULL,
    `product_id`   INT NOT NULL,
    `quantity`     INT NOT NULL,
    `unit_price`   DECIMAL(12, 2) NOT NULL,
    `weight_kg`    DECIMAL(10, 2) NOT NULL DEFAULT 0.00 COMMENT 'quantity x unit weight',
    `volume_cbm`   DECIMAL(8, 2) NOT NULL DEFAULT 0.00,
    `amount`       DECIMAL(14, 2) NOT NULL DEFAULT 0.00 COMMENT 'quantity x unit_price',
    `created_at`   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT `chk_shipment_item_qty` CHECK (`quantity` > 0),

    CONSTRAINT `fk_shipment_items_shipment`
        FOREIGN KEY (`shipment_id`)
        REFERENCES `shipment`(`shipment_id`)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    CONSTRAINT `fk_shipment_items_product`
        FOREIGN KEY (`product_id`)
        REFERENCES `products`(`product_id`)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,

    INDEX `idx_shipment_items_lookup` (`shipment_id`, `product_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- -----------------------------------------------------------------------------
-- 12. PRICING_RULES (SRS 7.5 / ERD #6)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `pricing_rules` (
    `rule_id`           INT AUTO_INCREMENT PRIMARY KEY,
    `seller_id`         INT NOT NULL,
    `origin_port_id`    INT NOT NULL,
    `dest_port_id`      INT NOT NULL,
    `container_type`    ENUM('DRY', 'REEFER', 'OPEN_TOP', 'TANK') NOT NULL,
    `base_rate`         DECIMAL(12, 2) NOT NULL,
    `rate_per_kg`       DECIMAL(8, 4) NOT NULL DEFAULT 0.0000,
    `rate_per_cbm`      DECIMAL(6, 2) NOT NULL DEFAULT 0.00,
    `season_multiplier` DECIMAL(4, 2) NOT NULL DEFAULT 1.00,
    `demand_multiplier` DECIMAL(4, 2) NOT NULL DEFAULT 1.00,
    `valid_from`        DATE NULL,
    `valid_to`          DATE NULL,
    `is_active`         BOOLEAN NOT NULL DEFAULT TRUE,
    `created_at`        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT `fk_pricing_seller`
        FOREIGN KEY (`seller_id`)
        REFERENCES `companies`(`company_id`)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    CONSTRAINT `fk_pricing_origin_port`
        FOREIGN KEY (`origin_port_id`)
        REFERENCES `ports`(`port_id`)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    CONSTRAINT `fk_pricing_dest_port`
        FOREIGN KEY (`dest_port_id`)
        REFERENCES `ports`(`port_id`)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    INDEX `idx_pricing_route_type` (`origin_port_id`, `dest_port_id`, `container_type`, `is_active`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- -----------------------------------------------------------------------------
-- 13. PRICING_AUDIT (SRS 7.5 / ERD #7)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `pricing_audit` (
    `audit_id`       INT AUTO_INCREMENT PRIMARY KEY,
    `rule_id`        INT NOT NULL,
    `old_rate`       DECIMAL(12, 2) NULL,
    `new_rate`       DECIMAL(12, 2) NOT NULL,
    `old_multiplier` DECIMAL(4, 2) NULL,
    `new_multiplier` DECIMAL(4, 2) NOT NULL,
    `changed_by`     INT NULL,
    `changed_at`     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT `fk_pricing_audit_rule`
        FOREIGN KEY (`rule_id`)
        REFERENCES `pricing_rules`(`rule_id`)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    CONSTRAINT `fk_pricing_audit_user`
        FOREIGN KEY (`changed_by`)
        REFERENCES `users`(`user_id`)
        ON DELETE SET NULL
        ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- -----------------------------------------------------------------------------
-- 14. DEMAND_FORECAST (SRS 7.5 / ERD #8)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `demand_forecast` (
    `forecast_id`          INT AUTO_INCREMENT PRIMARY KEY,
    `origin_port_id`       INT NOT NULL,
    `dest_port_id`         INT NOT NULL,
    `container_type`       ENUM('DRY', 'REEFER', 'OPEN_TOP', 'TANK') NOT NULL,
    `forecast_month`       DATE NOT NULL,
    `predicted_bookings`   INT NOT NULL DEFAULT 0,
    `confidence_pct`       DECIMAL(5, 2) NOT NULL DEFAULT 0.00,
    `suggested_multiplier` DECIMAL(4, 2) NOT NULL DEFAULT 1.00,
    `created_at`           TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT `fk_forecast_origin_port`
        FOREIGN KEY (`origin_port_id`)
        REFERENCES `ports`(`port_id`)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    CONSTRAINT `fk_forecast_dest_port`
        FOREIGN KEY (`dest_port_id`)
        REFERENCES `ports`(`port_id`)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    INDEX `idx_demand_forecast_route` (`origin_port_id`, `dest_port_id`, `forecast_month`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- -----------------------------------------------------------------------------
-- 15. STOCK (SRS 7.6 / ERD #15)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `stock` (
    `stock_id`      INT AUTO_INCREMENT PRIMARY KEY,
    `product_id`    INT NOT NULL,
    `shipment_id`   INT NULL COMMENT 'NULL until linked to active shipment',
    `container_id`  INT NULL,
    `quantity`      INT NOT NULL DEFAULT 0,
    `damaged_qty`   INT NOT NULL DEFAULT 0,
    `last_updated`  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    `created_at`    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT `chk_stock_quantity` CHECK (`quantity` >= 0),

    CONSTRAINT `fk_stock_product`
        FOREIGN KEY (`product_id`)
        REFERENCES `products`(`product_id`)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    CONSTRAINT `fk_stock_shipment`
        FOREIGN KEY (`shipment_id`)
        REFERENCES `shipment`(`shipment_id`)
        ON DELETE SET NULL
        ON UPDATE CASCADE,

    CONSTRAINT `fk_stock_container`
        FOREIGN KEY (`container_id`)
        REFERENCES `containers`(`container_id`)
        ON DELETE SET NULL
        ON UPDATE CASCADE,

    INDEX `idx_stock_product_shipment` (`product_id`, `shipment_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- -----------------------------------------------------------------------------
-- 16. INVENTORY_LEDGER (SRS 7.6 / ERD #25)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `inventory_ledger` (
    `ledger_id`       BIGINT AUTO_INCREMENT PRIMARY KEY,
    `stock_id`        INT NOT NULL,
    `product_id`      INT NOT NULL,
    `txn_type`        ENUM('IN', 'OUT', 'DAMAGE', 'ADJUST', 'CLAIM_LOSS') NOT NULL,
    `quantity`        INT NOT NULL,
    `balance_after`   INT NOT NULL,
    `reference_type`  VARCHAR(30) NULL COMMENT 'SHIPMENT, CLAIM, UPLOAD',
    `reference_id`    BIGINT NULL,
    `txn_time`        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT `fk_ledger_stock`
        FOREIGN KEY (`stock_id`)
        REFERENCES `stock`(`stock_id`)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    CONSTRAINT `fk_ledger_product`
        FOREIGN KEY (`product_id`)
        REFERENCES `products`(`product_id`)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    INDEX `idx_ledger_product_time` (`product_id`, `txn_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- -----------------------------------------------------------------------------
-- 17. SALES_TRANSACTIONS (SRS 7.6 / ERD #23)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `sales_transactions` (
    `sale_id`       BIGINT AUTO_INCREMENT PRIMARY KEY,
    `product_id`    INT NOT NULL,
    `customer_id`   INT NOT NULL,
    `shipment_id`   INT NULL,
    `quantity`      INT NOT NULL,
    `unit_price`    DECIMAL(12, 2) NOT NULL,
    `total_amount`  DECIMAL(14, 2) NOT NULL,
    `sale_date`     DATE NOT NULL,
    `created_at`    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT `fk_sales_product`
        FOREIGN KEY (`product_id`)
        REFERENCES `products`(`product_id`)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    CONSTRAINT `fk_sales_customer`
        FOREIGN KEY (`customer_id`)
        REFERENCES `customers`(`customer_id`)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,

    CONSTRAINT `fk_sales_shipment`
        FOREIGN KEY (`shipment_id`)
        REFERENCES `shipment`(`shipment_id`)
        ON DELETE SET NULL
        ON UPDATE CASCADE,

    INDEX `idx_sales_product_date` (`product_id`, `sale_date`),
    INDEX `idx_sales_customer` (`customer_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- -----------------------------------------------------------------------------
-- 18. BILLING_INVOICES (SRS 7.7 / ERD #17)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `billing_invoices` (
    `invoice_id`    INT AUTO_INCREMENT PRIMARY KEY,
    `invoice_no`    VARCHAR(20) NOT NULL UNIQUE,
    `shipment_id`   INT NOT NULL,
    `consumer_id`   INT NOT NULL,
    `seller_id`     INT NOT NULL,
    `sub_total`     DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    `tax_amount`    DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    `total_amount`  DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    `paid_amount`   DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    `status`        ENUM('UNPAID', 'PARTIAL', 'PAID') NOT NULL DEFAULT 'UNPAID',
    `issue_date`    DATE NOT NULL,
    `due_date`      DATE NOT NULL,
    `created_at`    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT `fk_invoices_shipment`
        FOREIGN KEY (`shipment_id`)
        REFERENCES `shipment`(`shipment_id`)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,

    CONSTRAINT `fk_invoices_consumer`
        FOREIGN KEY (`consumer_id`)
        REFERENCES `customers`(`customer_id`)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,

    CONSTRAINT `fk_invoices_seller`
        FOREIGN KEY (`seller_id`)
        REFERENCES `companies`(`company_id`)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,

    INDEX `idx_invoices_status` (`status`),
    INDEX `idx_invoices_shipment` (`shipment_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- -----------------------------------------------------------------------------
-- 19. INVOICE_LINE_ITEMS (SRS 7.7 / ERD #18)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `invoice_line_items` (
    `item_id`      INT AUTO_INCREMENT PRIMARY KEY,
    `invoice_id`   INT NOT NULL,
    `item_type`    ENUM('FREIGHT', 'HANDLING', 'CUSTOMS', 'TAX', 'INSURANCE', 'OTHER') NOT NULL,
    `description`  VARCHAR(150) NULL,
    `quantity`     DECIMAL(8, 2) NOT NULL DEFAULT 1.00,
    `unit_price`   DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    `amount`       DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    `created_at`   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT `fk_line_items_invoice`
        FOREIGN KEY (`invoice_id`)
        REFERENCES `billing_invoices`(`invoice_id`)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    INDEX `idx_line_items_invoice` (`invoice_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- -----------------------------------------------------------------------------
-- 20. PAYMENTS (SRS 7.7 / ERD #19)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `payments` (
    `payment_id`    INT AUTO_INCREMENT PRIMARY KEY,
    `invoice_id`    INT NOT NULL,
    `amount`        DECIMAL(12, 2) NOT NULL,
    `payment_mode`  ENUM('BANK', 'UPI', 'CHEQUE', 'CASH') NOT NULL,
    `reference_no`  VARCHAR(50) NULL,
    `payment_date`  DATE NOT NULL,
    `recorded_by`   INT NULL,
    `created_at`    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT `chk_payment_amount` CHECK (`amount` > 0),

    CONSTRAINT `fk_payments_invoice`
        FOREIGN KEY (`invoice_id`)
        REFERENCES `billing_invoices`(`invoice_id`)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,

    CONSTRAINT `fk_payments_user`
        FOREIGN KEY (`recorded_by`)
        REFERENCES `users`(`user_id`)
        ON DELETE SET NULL
        ON UPDATE CASCADE,

    INDEX `idx_payments_invoice` (`invoice_id`),
    INDEX `idx_payments_date` (`payment_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- -----------------------------------------------------------------------------
-- 21. CLAIMS (SRS 7.8 / ERD #20)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `claims` (
    `claim_id`        INT AUTO_INCREMENT PRIMARY KEY,
    `claim_no`        VARCHAR(20) NOT NULL UNIQUE,
    `shipment_id`     INT NOT NULL,
    `container_id`    INT NULL,
    `consumer_id`     INT NOT NULL,
    `claim_type`      ENUM('LOSS', 'DAMAGE', 'DELAY', 'SHORTAGE') NOT NULL,
    `description`     TEXT NOT NULL,
    `claimed_amount`  DECIMAL(12, 2) NOT NULL,
    `approved_amount` DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    `status`          ENUM('SUBMITTED', 'UNDER_REVIEW', 'APPROVED', 'PARTIALLY_APPROVED', 'REJECTED', 'SETTLED') NOT NULL DEFAULT 'SUBMITTED',
    `seller_remarks`  VARCHAR(255) NULL,
    `raised_at`       DATETIME NOT NULL,
    `settled_at`      DATETIME NULL,
    `created_at`      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT `fk_claims_shipment`
        FOREIGN KEY (`shipment_id`)
        REFERENCES `shipment`(`shipment_id`)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,

    CONSTRAINT `fk_claims_container`
        FOREIGN KEY (`container_id`)
        REFERENCES `containers`(`container_id`)
        ON DELETE SET NULL
        ON UPDATE CASCADE,

    CONSTRAINT `fk_claims_consumer`
        FOREIGN KEY (`consumer_id`)
        REFERENCES `customers`(`customer_id`)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,

    INDEX `idx_claims_status` (`status`),
    INDEX `idx_claims_shipment` (`shipment_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- -----------------------------------------------------------------------------
-- 22. CLAIM_DOCUMENTS (SRS 7.8 / ERD #21)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `claim_documents` (
    `cdoc_id`     INT AUTO_INCREMENT PRIMARY KEY,
    `claim_id`    INT NOT NULL,
    `file_name`   VARCHAR(150) NOT NULL,
    `file_path`   VARCHAR(255) NOT NULL,
    `file_type`   VARCHAR(10) NOT NULL COMMENT 'PDF, JPG, PNG',
    `uploaded_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT `fk_claim_docs_claim`
        FOREIGN KEY (`claim_id`)
        REFERENCES `claims`(`claim_id`)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    INDEX `idx_claim_docs_claim` (`claim_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- -----------------------------------------------------------------------------
-- 23. CLAIM_STATUS_HISTORY (SRS 7.8 / ERD #22)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `claim_status_history` (
    `history_id`  BIGINT AUTO_INCREMENT PRIMARY KEY,
    `claim_id`    INT NOT NULL,
    `old_status`  VARCHAR(20) NULL,
    `new_status`  VARCHAR(20) NOT NULL,
    `changed_by`  INT NULL,
    `remarks`     VARCHAR(255) NULL,
    `changed_at`  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT `fk_claim_history_claim`
        FOREIGN KEY (`claim_id`)
        REFERENCES `claims`(`claim_id`)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    CONSTRAINT `fk_claim_history_user`
        FOREIGN KEY (`changed_by`)
        REFERENCES `users`(`user_id`)
        ON DELETE SET NULL
        ON UPDATE CASCADE,

    INDEX `idx_claim_history_claim` (`claim_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- -----------------------------------------------------------------------------
-- 24. PROFIT_LOSS (SRS 7.9 / ERD #12)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `profit_loss` (
    `pl_id`           INT AUTO_INCREMENT PRIMARY KEY,
    `shipment_id`     INT NULL COMMENT 'Nullable for aggregate seller P&L',
    `seller_id`       INT NOT NULL,
    `period_month`    DATE NOT NULL COMMENT 'First day of month (YYYY-MM-01)',
    `revenue`         DECIMAL(14, 2) NOT NULL DEFAULT 0.00,
    `freight_cost`    DECIMAL(14, 2) NOT NULL DEFAULT 0.00,
    `port_cost`       DECIMAL(14, 2) NOT NULL DEFAULT 0.00,
    `handling_cost`   DECIMAL(14, 2) NOT NULL DEFAULT 0.00,
    `claim_loss`      DECIMAL(14, 2) NOT NULL DEFAULT 0.00 COMMENT 'Settled claim payout',
    `net_profit`      DECIMAL(14, 2) NOT NULL DEFAULT 0.00 COMMENT 'revenue - all costs - claim_loss',
    `created_at`      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT `fk_pl_shipment`
        FOREIGN KEY (`shipment_id`)
        REFERENCES `shipment`(`shipment_id`)
        ON DELETE SET NULL
        ON UPDATE CASCADE,

    CONSTRAINT `fk_pl_seller`
        FOREIGN KEY (`seller_id`)
        REFERENCES `companies`(`company_id`)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    INDEX `idx_pl_seller_period` (`seller_id`, `period_month`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- -----------------------------------------------------------------------------
-- 25. ABC_CLASSIFICATION_RESULT (SRS 7.9 / ERD #26)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `abc_classification_result` (
    `result_id`       INT AUTO_INCREMENT PRIMARY KEY,
    `product_id`      INT NOT NULL,
    `annual_value`    DECIMAL(14, 2) NOT NULL DEFAULT 0.00,
    `cumulative_pct`  DECIMAL(5, 2) NOT NULL DEFAULT 0.00,
    `abc_class`       CHAR(1) NOT NULL COMMENT 'A = top 70%, B = next 20%, C = last 10%',
    `calculated_on`   DATE NOT NULL,
    `created_at`      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT `fk_abc_product`
        FOREIGN KEY (`product_id`)
        REFERENCES `products`(`product_id`)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    INDEX `idx_abc_class` (`product_id`, `abc_class`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- -----------------------------------------------------------------------------
-- 26. INVENTORY_TURNOVER_RESULT (SRS 7.9 / ERD #27)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `inventory_turnover_result` (
    `result_id`       INT AUTO_INCREMENT PRIMARY KEY,
    `product_id`      INT NOT NULL,
    `period_start`    DATE NOT NULL,
    `period_end`      DATE NOT NULL,
    `cogs`            DECIMAL(14, 2) NOT NULL DEFAULT 0.00,
    `avg_inventory`   DECIMAL(14, 2) NOT NULL DEFAULT 0.00,
    `turnover_ratio`  DECIMAL(8, 2) NOT NULL DEFAULT 0.00 COMMENT 'cogs / avg_inventory',
    `created_at`      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT `fk_turnover_product`
        FOREIGN KEY (`product_id`)
        REFERENCES `products`(`product_id`)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    INDEX `idx_turnover_product` (`product_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- -----------------------------------------------------------------------------
-- 27. PROFITABILITY_RESULT (SRS 7.9 / ERD #28)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `profitability_result` (
    `result_id`       INT AUTO_INCREMENT PRIMARY KEY,
    `product_id`      INT NOT NULL,
    `period_month`    DATE NOT NULL,
    `revenue`         DECIMAL(14, 2) NOT NULL DEFAULT 0.00,
    `cost`            DECIMAL(14, 2) NOT NULL DEFAULT 0.00,
    `margin_pct`      DECIMAL(6, 2) NOT NULL DEFAULT 0.00,
    `created_at`      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT `fk_profitability_product`
        FOREIGN KEY (`product_id`)
        REFERENCES `products`(`product_id`)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    INDEX `idx_profitability_product` (`product_id`, `period_month`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- -----------------------------------------------------------------------------
-- 28. SALES_TREND_RESULT (SRS 7.9 / ERD #10)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `sales_trend_result` (
    `result_id`       INT AUTO_INCREMENT PRIMARY KEY,
    `period_month`    DATE NOT NULL,
    `origin_port_id`  INT NULL,
    `dest_port_id`    INT NULL,
    `total_sales`     DECIMAL(14, 2) NOT NULL DEFAULT 0.00,
    `total_qty`       INT NOT NULL DEFAULT 0,
    `growth_pct`      DECIMAL(6, 2) NOT NULL DEFAULT 0.00,
    `created_at`      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT `fk_sales_origin_port`
        FOREIGN KEY (`origin_port_id`)
        REFERENCES `ports`(`port_id`)
        ON DELETE SET NULL
        ON UPDATE CASCADE,

    CONSTRAINT `fk_sales_dest_port`
        FOREIGN KEY (`dest_port_id`)
        REFERENCES `ports`(`port_id`)
        ON DELETE SET NULL
        ON UPDATE CASCADE,

    INDEX `idx_sales_trend_month` (`period_month`, `origin_port_id`, `dest_port_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Re-enable foreign key constraints
SET FOREIGN_KEY_CHECKS = @OLD_FOREIGN_KEY_CHECKS;


-- =============================================================================
-- SECTION 2: CROSS-MODULE JOIN VIEWS (ANALYTICS & OPERATIONS)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- VIEW 1: vw_shipment_full_details
-- Joins 7 tables: shipment, companies (seller), customers, users, containers, vessels, ports
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW `vw_shipment_full_details` AS
SELECT 
    s.shipment_id,
    s.shipment_no,
    s.status AS shipment_status,
    s.cargo_description,
    s.cargo_weight_kg,
    s.cargo_volume_cbm,
    s.quoted_price,
    s.etd,
    s.eta,
    s.actual_arrival,
    s.created_at AS booked_at,
    -- Seller Details
    seller.company_id AS seller_id,
    seller.company_name AS seller_name,
    seller.gst_number AS seller_gst,
    -- Consumer Details
    cust.customer_id,
    u_consumer.full_name AS consumer_name,
    u_consumer.email AS consumer_email,
    u_consumer.phone AS consumer_phone,
    -- Container Details
    c.container_id,
    c.container_number,
    c.container_type,
    c.size_ft AS container_size,
    c.status AS container_status,
    -- Vessel Details
    v.vessel_id,
    v.vessel_name,
    v.imo_number,
    -- Route / Port Details
    p_orig.port_id AS origin_port_id,
    p_orig.port_code AS origin_code,
    p_orig.port_name AS origin_name,
    p_dest.port_id AS dest_port_id,
    p_dest.port_code AS dest_code,
    p_dest.port_name AS dest_name
FROM shipment s
JOIN companies seller ON s.seller_id = seller.company_id
JOIN customers cust ON s.consumer_id = cust.customer_id
JOIN users u_consumer ON cust.user_id = u_consumer.user_id
JOIN containers c ON s.container_id = c.container_id
LEFT JOIN vessels v ON s.vessel_id = v.vessel_id
JOIN ports p_orig ON s.origin_port_id = p_orig.port_id
JOIN ports p_dest ON s.dest_port_id = p_dest.port_id;


-- -----------------------------------------------------------------------------
-- VIEW 2: vw_seller_profit_loss_breakdown
-- Joins profit_loss, shipment, companies, billing_invoices and claims
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW `vw_seller_profit_loss_breakdown` AS
SELECT 
    pl.pl_id,
    pl.period_month,
    comp.company_id AS seller_id,
    comp.company_name AS seller_name,
    s.shipment_id,
    s.shipment_no,
    pl.revenue,
    pl.freight_cost,
    pl.port_cost,
    pl.handling_cost,
    pl.claim_loss,
    pl.net_profit,
    CASE 
        WHEN pl.revenue > 0 THEN ROUND((pl.net_profit / pl.revenue) * 100, 2)
        ELSE 0.00 
    END AS net_profit_margin_pct,
    bi.invoice_no,
    bi.status AS invoice_status,
    (SELECT COUNT(*) FROM claims cl WHERE cl.shipment_id = s.shipment_id) AS total_claims_count
FROM profit_loss pl
JOIN companies comp ON pl.seller_id = comp.company_id
LEFT JOIN shipment s ON pl.shipment_id = s.shipment_id
LEFT JOIN billing_invoices bi ON s.shipment_id = bi.shipment_id;


-- -----------------------------------------------------------------------------
-- VIEW 3: vw_billing_and_payment_summary
-- Joins billing_invoices, shipment, companies, customers, and aggregates payments
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW `vw_billing_and_payment_summary` AS
SELECT 
    bi.invoice_id,
    bi.invoice_no,
    bi.issue_date,
    bi.due_date,
    bi.status AS payment_status,
    bi.sub_total,
    bi.tax_amount,
    bi.total_amount,
    bi.paid_amount,
    (bi.total_amount - bi.paid_amount) AS balance_due,
    s.shipment_id,
    s.shipment_no,
    seller.company_name AS seller_name,
    u.full_name AS consumer_name,
    COUNT(p.payment_id) AS payment_transactions_count,
    MAX(p.payment_date) AS last_payment_date
FROM billing_invoices bi
JOIN shipment s ON bi.shipment_id = s.shipment_id
JOIN companies seller ON bi.seller_id = seller.company_id
JOIN customers cust ON bi.consumer_id = cust.customer_id
JOIN users u ON cust.user_id = u.user_id
LEFT JOIN payments p ON bi.invoice_id = p.invoice_id
GROUP BY bi.invoice_id, bi.invoice_no, bi.issue_date, bi.due_date, bi.status, 
         bi.sub_total, bi.tax_amount, bi.total_amount, bi.paid_amount, 
         s.shipment_id, s.shipment_no, seller.company_name, u.full_name;


-- -----------------------------------------------------------------------------
-- VIEW 4: vw_inventory_live_valuation
-- Joins stock, products, companies and containers
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW `vw_inventory_live_valuation` AS
SELECT 
    stk.stock_id,
    p.product_id,
    p.sku,
    p.product_name,
    p.category,
    p.unit_price,
    p.unit_weight_kg,
    comp.company_id AS seller_id,
    comp.company_name AS seller_name,
    stk.quantity AS available_qty,
    stk.damaged_qty,
    (stk.quantity * p.unit_price) AS total_valuation,
    c.container_number,
    c.container_type,
    stk.shipment_id,
    stk.last_updated
FROM stock stk
JOIN products p ON stk.product_id = p.product_id
JOIN companies comp ON p.owner_company_id = comp.company_id
LEFT JOIN containers c ON stk.container_id = c.container_id;


-- -----------------------------------------------------------------------------
-- VIEW 5: vw_claims_investigation_overview
-- Joins claims, shipment, customers, users, containers, and claim_documents
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW `vw_claims_investigation_overview` AS
SELECT 
    c.claim_id,
    c.claim_no,
    c.claim_type,
    c.status AS claim_status,
    c.claimed_amount,
    c.approved_amount,
    c.raised_at,
    c.settled_at,
    s.shipment_id,
    s.shipment_no,
    u.full_name AS consumer_name,
    u.phone AS consumer_phone,
    cont.container_number,
    COUNT(cd.cdoc_id) AS uploaded_documents_count
FROM claims c
JOIN shipment s ON c.shipment_id = s.shipment_id
JOIN customers cust ON c.consumer_id = cust.customer_id
JOIN users u ON cust.user_id = u.user_id
LEFT JOIN containers cont ON c.container_id = cont.container_id
LEFT JOIN claim_documents cd ON c.claim_id = cd.claim_id
GROUP BY c.claim_id, c.claim_no, c.claim_type, c.status, c.claimed_amount, 
         c.approved_amount, c.raised_at, c.settled_at, s.shipment_id, 
         s.shipment_no, u.full_name, u.phone, cont.container_number;


-- -----------------------------------------------------------------------------
-- VIEW 6: vw_executive_kpis
-- Unified Executive KPI Aggregations (FR6.1)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW `vw_executive_kpis` AS
SELECT 
    (SELECT COUNT(*) FROM shipment WHERE status NOT IN ('CANCELLED', 'DELIVERED')) AS active_shipments_count,
    (SELECT COUNT(*) FROM containers WHERE status = 'AVAILABLE') AS available_containers_count,
    (SELECT COALESCE(SUM(paid_amount), 0.00) FROM billing_invoices) AS total_revenue_collected,
    (SELECT COALESCE(SUM(total_amount - paid_amount), 0.00) FROM billing_invoices WHERE status != 'PAID') AS pending_invoices_amount,
    (SELECT COUNT(*) FROM claims WHERE status IN ('SUBMITTED', 'UNDER_REVIEW')) AS open_claims_count;


-- =============================================================================
-- SECTION 3: AUTOMATED BUSINESS TRIGGERS
-- =============================================================================

DROP TRIGGER IF EXISTS `trg_after_payment_insert`;
DROP TRIGGER IF EXISTS `trg_after_claim_status_change`;
DROP TRIGGER IF EXISTS `trg_after_pricing_rule_update`;
DROP TRIGGER IF EXISTS `trg_after_container_movement_insert`;

DELIMITER //

-- -----------------------------------------------------------------------------
-- TRIGGER 1: Auto-update invoice status on payment insertion (FR5.4)
-- -----------------------------------------------------------------------------
CREATE TRIGGER `trg_after_payment_insert`
AFTER INSERT ON `payments`
FOR EACH ROW
BEGIN
    DECLARE v_total DECIMAL(12,2);
    DECLARE v_paid DECIMAL(12,2);

    SELECT total_amount, paid_amount + NEW.amount 
    INTO v_total, v_paid
    FROM billing_invoices 
    WHERE invoice_id = NEW.invoice_id;

    UPDATE billing_invoices
    SET paid_amount = v_paid,
        status = CASE 
            WHEN v_paid >= v_total THEN 'PAID'
            WHEN v_paid > 0 THEN 'PARTIAL'
            ELSE 'UNPAID'
        END
    WHERE invoice_id = NEW.invoice_id;
END //


-- -----------------------------------------------------------------------------
-- TRIGGER 2: Log claim status transition history automatically (FR7.5)
-- -----------------------------------------------------------------------------
CREATE TRIGGER `trg_after_claim_status_change`
AFTER UPDATE ON `claims`
FOR EACH ROW
BEGIN
    IF OLD.status != NEW.status THEN
        INSERT INTO claim_status_history (claim_id, old_status, new_status, changed_by, remarks, changed_at)
        VALUES (NEW.claim_id, OLD.status, NEW.status, NULL, NEW.seller_remarks, CURRENT_TIMESTAMP);
    END IF;
END //


-- -----------------------------------------------------------------------------
-- TRIGGER 3: Log pricing modifications to pricing_audit table (FR3.6)
-- -----------------------------------------------------------------------------
CREATE TRIGGER `trg_after_pricing_rule_update`
AFTER UPDATE ON `pricing_rules`
FOR EACH ROW
BEGIN
    IF (OLD.base_rate != NEW.base_rate OR OLD.season_multiplier != NEW.season_multiplier OR OLD.demand_multiplier != NEW.demand_multiplier) THEN
        INSERT INTO pricing_audit (rule_id, old_rate, new_rate, old_multiplier, new_multiplier, changed_by, changed_at)
        VALUES (NEW.rule_id, OLD.base_rate, NEW.base_rate, OLD.demand_multiplier, NEW.demand_multiplier, NULL, CURRENT_TIMESTAMP);
    END IF;
END //


-- -----------------------------------------------------------------------------
-- TRIGGER 4: Sync shipment and container status on movement tracking event (FR2.2 / FR2.3)
-- -----------------------------------------------------------------------------
CREATE TRIGGER `trg_after_container_movement_insert`
AFTER INSERT ON `container_movements`
FOR EACH ROW
BEGIN
    UPDATE shipment 
    SET status = NEW.status 
    WHERE shipment_id = NEW.shipment_id;

    IF NEW.status IN ('LOADED', 'DEPARTED', 'IN_TRANSIT') THEN
        UPDATE containers SET status = 'IN_TRANSIT', current_port_id = NEW.port_id WHERE container_id = NEW.container_id;
    ELSEIF NEW.status IN ('DELIVERED', 'CUSTOMS_CLEARED') THEN
        UPDATE containers SET status = 'AVAILABLE', current_port_id = NEW.port_id WHERE container_id = NEW.container_id;
    END IF;
END //

DELIMITER ;


-- =============================================================================
-- SECTION 4: STORED PROCEDURES (OPERATIONS & ANALYTICS)
-- =============================================================================

DROP PROCEDURE IF EXISTS `sp_calculate_dynamic_price`;
DROP PROCEDURE IF EXISTS `sp_settle_claim`;
DROP PROCEDURE IF EXISTS `sp_refresh_sales_trends`;
DROP PROCEDURE IF EXISTS `sp_calculate_abc_classification`;
DROP PROCEDURE IF EXISTS `sp_calculate_inventory_turnover`;
DROP PROCEDURE IF EXISTS `sp_calculate_profitability`;
DROP PROCEDURE IF EXISTS `sp_generate_demand_forecast`;
DROP PROCEDURE IF EXISTS `sp_calculate_profit_loss`;
DROP PROCEDURE IF EXISTS `sp_refresh_all_fr6_analytics`;

DELIMITER //

-- -----------------------------------------------------------------------------
-- PROCEDURE 1: sp_calculate_dynamic_price (FR3.5)
-- Calculates price quotation = (base + wt_rate*wt + vol_rate*vol) * season * demand
-- -----------------------------------------------------------------------------
CREATE PROCEDURE `sp_calculate_dynamic_price`(
    IN p_seller_id INT,
    IN p_orig_port INT,
    IN p_dest_port INT,
    IN p_type VARCHAR(10),
    IN p_weight DECIMAL(10,2),
    IN p_volume DECIMAL(8,2),
    OUT p_final_price DECIMAL(12,2)
)
BEGIN
    DECLARE v_base DECIMAL(12,2) DEFAULT 45000.00;
    DECLARE v_wt_rate DECIMAL(8,4) DEFAULT 0.00;
    DECLARE v_vol_rate DECIMAL(6,2) DEFAULT 0.00;
    DECLARE v_season DECIMAL(4,2) DEFAULT 1.00;
    DECLARE v_demand DECIMAL(4,2) DEFAULT 1.00;

    SELECT base_rate, rate_per_kg, rate_per_cbm, season_multiplier, demand_multiplier
    INTO v_base, v_wt_rate, v_vol_rate, v_season, v_demand
    FROM pricing_rules
    WHERE seller_id = p_seller_id 
      AND origin_port_id = p_orig_port 
      AND dest_port_id = p_dest_port 
      AND container_type = p_type 
      AND is_active = TRUE
    LIMIT 1;

    SET p_final_price = ROUND((v_base + (p_weight * v_wt_rate) + (p_volume * v_vol_rate)) * v_season * v_demand, 2);
END //


-- -----------------------------------------------------------------------------
-- PROCEDURE 2: sp_settle_claim (FR7.6)
-- Settles claim, adjusts inventory ledger, and adds loss to P&L
-- -----------------------------------------------------------------------------
CREATE PROCEDURE `sp_settle_claim`(
    IN p_claim_id INT,
    IN p_approved_amount DECIMAL(12,2),
    IN p_seller_remarks VARCHAR(255)
)
BEGIN
    DECLARE v_shipment_id INT;
    DECLARE v_seller_id INT;

    START TRANSACTION;

    SELECT shipment_id INTO v_shipment_id FROM claims WHERE claim_id = p_claim_id;
    SELECT seller_id INTO v_seller_id FROM shipment WHERE shipment_id = v_shipment_id;

    UPDATE claims
    SET approved_amount = p_approved_amount,
        status = 'SETTLED',
        seller_remarks = p_seller_remarks,
        settled_at = CURRENT_TIMESTAMP
    WHERE claim_id = p_claim_id;

    -- Update or insert claim_loss into profit_loss
    UPDATE profit_loss
    SET claim_loss = claim_loss + p_approved_amount,
        net_profit = net_profit - p_approved_amount
    WHERE shipment_id = v_shipment_id;

    COMMIT;
END //


-- -----------------------------------------------------------------------------
-- PROCEDURE 3: sp_refresh_sales_trends (FR6.2)
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
-- PROCEDURE 4: sp_calculate_abc_classification (FR6.3)
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
-- PROCEDURE 5: sp_calculate_inventory_turnover (FR6.4)
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
-- PROCEDURE 6: sp_calculate_profitability (FR6.5)
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
-- PROCEDURE 7: sp_generate_demand_forecast (FR6.6)
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
-- PROCEDURE 8: sp_calculate_profit_loss (FR6.5 & FR2.8)
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
-- PROCEDURE 9: sp_refresh_all_fr6_analytics (Master Orchestrator)
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


/*
===============================================================================
N LOGISTIC DB - SRS EXTENSION / CRUD SUPPORT PATCH
-------------------------------------------------------------------------------
Apply AFTER 01_master_complete_n_logistic_db.sql on a TEST COPY first.
This is a one-time patch (ALTER TABLE statements are not idempotent).
It preserves the original 28 core table names and adds supporting structures
for requirements that appear elsewhere in the SRS (FR5.2, FR7.7, FR8, FR9).

IMPORTANT:
- Back up the database first.
- Check for duplicate billing_invoices.shipment_id values before adding the
  one-invoice-per-shipment unique key.
- Module CRUD SELECT/INSERT/UPDATE/DELETE statements are in the companion file:
  n_logistic_db_module_crud_reference.sql
- Java Servlets/Services/DAOs must call these operations with PreparedStatement.
===============================================================================
*/

USE n_logistic_db;

/* ---------------------------------------------------------------------------
   1. SUPPORT REQUIRED MODULE OPERATIONS
--------------------------------------------------------------------------- */

-- Admin needs to deactivate ports. Preserve the port row for historical routes.
ALTER TABLE ports
  ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT TRUE AFTER longitude;

-- Allow a vessel to be deactivated without erasing its history.
ALTER TABLE vessels
  ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT TRUE AFTER status;

-- FR3.4 requires volume to be calculated from goods, not typed in manually.
-- FR6.5 needs an actual cost basis; do not assume cost is 65% of selling price.
-- is_active provides safe product deactivation instead of destructive DELETE.
ALTER TABLE products
  ADD COLUMN IF NOT EXISTS unit_volume_cbm DECIMAL(10,4) NOT NULL DEFAULT 0.0000 AFTER unit_weight_kg,
  ADD COLUMN IF NOT EXISTS unit_cost DECIMAL(12,2) NOT NULL DEFAULT 0.00 AFTER unit_price;

ALTER TABLE products
  ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT TRUE AFTER unit_cost;

-- Keep on-hand, damaged and reserved amounts distinct. Available quantity is:
-- quantity - damaged_qty - reserved_qty.
ALTER TABLE stock
  ADD COLUMN IF NOT EXISTS reserved_qty INT NOT NULL DEFAULT 0 AFTER damaged_qty,
  ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT TRUE AFTER reserved_qty;

-- Prevent goods/quantities from being changed after booking confirmation.
ALTER TABLE shipment
  ADD COLUMN IF NOT EXISTS booking_confirmed BOOLEAN NOT NULL DEFAULT FALSE AFTER status;

ALTER TABLE stock
  ADD CONSTRAINT chk_stock_damaged_nonnegative CHECK (damaged_qty >= 0),
  ADD CONSTRAINT chk_stock_reserved_nonnegative CHECK (reserved_qty >= 0),
  ADD CONSTRAINT chk_stock_reserved_available CHECK (reserved_qty <= quantity - damaged_qty);

-- Track who performed automatic inventory ledger entries. The application sets
-- @app_user_id on the same JDBC connection before a write transaction.
ALTER TABLE inventory_ledger
  ADD COLUMN IF NOT EXISTS changed_by INT NULL AFTER reference_id,
  ADD CONSTRAINT fk_ledger_changed_by
    FOREIGN KEY (changed_by) REFERENCES users(user_id)
    ON DELETE SET NULL ON UPDATE CASCADE;

-- Expand price audit so changes to weight/volume rates and both multipliers
-- are not lost inside the old generic multiplier columns.
ALTER TABLE pricing_audit
  ADD COLUMN IF NOT EXISTS old_rate_per_kg DECIMAL(8,4) NULL AFTER new_rate,
  ADD COLUMN IF NOT EXISTS new_rate_per_kg DECIMAL(8,4) NULL AFTER old_rate_per_kg,
  ADD COLUMN IF NOT EXISTS old_rate_per_cbm DECIMAL(8,2) NULL AFTER new_rate_per_kg,
  ADD COLUMN IF NOT EXISTS new_rate_per_cbm DECIMAL(8,2) NULL AFTER old_rate_per_cbm,
  ADD COLUMN IF NOT EXISTS old_season_multiplier DECIMAL(4,2) NULL AFTER new_multiplier,
  ADD COLUMN IF NOT EXISTS new_season_multiplier DECIMAL(4,2) NULL AFTER old_season_multiplier,
  ADD COLUMN IF NOT EXISTS old_demand_multiplier DECIMAL(4,2) NULL AFTER new_season_multiplier,
  ADD COLUMN IF NOT EXISTS new_demand_multiplier DECIMAL(4,2) NULL AFTER old_demand_multiplier;

-- SRS Section 7.10 specifies shipment 1:1 billing invoice. Check duplicates
-- before this patch; the following SELECT must return zero rows.
SELECT shipment_id, COUNT(*) AS invoice_count
FROM billing_invoices
GROUP BY shipment_id
HAVING COUNT(*) > 1;

-- One P&L row per shipment and month. This SELECT must also return zero rows.
SELECT shipment_id, period_month, COUNT(*) AS row_count
FROM profit_loss
WHERE shipment_id IS NOT NULL
GROUP BY shipment_id, period_month
HAVING COUNT(*) > 1;

-- A foreign key alone only enforces existence, not one-to-one cardinality.
ALTER TABLE billing_invoices
  ADD CONSTRAINT uq_billing_invoice_shipment UNIQUE (shipment_id);

-- One P&L row per shipment and accounting month, while allowing seller-level
-- aggregate rows with shipment_id NULL.
ALTER TABLE profit_loss
  ADD CONSTRAINT uq_profit_loss_shipment_month UNIQUE (shipment_id, period_month);

/* ---------------------------------------------------------------------------
   2. SUPPORTING TABLES MISSING FROM THE FUNCTIONAL SRS SECTIONS
--------------------------------------------------------------------------- */

-- FR5.2: configurable tax rates used when creating invoices.
CREATE TABLE IF NOT EXISTS tax_rates (
  tax_rate_id INT AUTO_INCREMENT PRIMARY KEY,
  tax_code VARCHAR(30) NOT NULL UNIQUE,
  tax_name VARCHAR(100) NOT NULL,
  rate_pct DECIMAL(7,4) NOT NULL,
  valid_from DATE NOT NULL,
  valid_to DATE NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT chk_tax_rate_range CHECK (rate_pct >= 0 AND rate_pct <= 100),
  INDEX idx_tax_rate_active_dates (is_active, valid_from, valid_to)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- FR7.7: both consumer and seller can add comments to a claim.
CREATE TABLE IF NOT EXISTS system_settings (
  setting_key VARCHAR(100) PRIMARY KEY,
  setting_value VARCHAR(255) NOT NULL,
  updated_by INT NULL,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_system_settings_user FOREIGN KEY (updated_by)
    REFERENCES users(user_id) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO system_settings (setting_key, setting_value)
VALUES ('claim_window_days', '30')
ON DUPLICATE KEY UPDATE setting_key = VALUES(setting_key);

CREATE TABLE IF NOT EXISTS claim_comments (
  comment_id BIGINT AUTO_INCREMENT PRIMARY KEY,
  claim_id INT NOT NULL,
  user_id INT NOT NULL,
  comment_text TEXT NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_claim_comments_claim FOREIGN KEY (claim_id)
    REFERENCES claims(claim_id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_claim_comments_user FOREIGN KEY (user_id)
    REFERENCES users(user_id) ON DELETE RESTRICT ON UPDATE CASCADE,
  INDEX idx_claim_comments_claim_time (claim_id, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- FR7.6: identify affected stock rows and quantities for loss/damage settlement.
CREATE TABLE IF NOT EXISTS claim_items (
  claim_item_id BIGINT AUTO_INCREMENT PRIMARY KEY,
  claim_id INT NOT NULL,
  stock_id INT NOT NULL,
  quantity_affected INT NOT NULL,
  disposition ENUM('LOSS','DAMAGE') NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT chk_claim_item_qty CHECK (quantity_affected > 0),
  CONSTRAINT fk_claim_items_claim FOREIGN KEY (claim_id)
    REFERENCES claims(claim_id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_claim_items_stock FOREIGN KEY (stock_id)
    REFERENCES stock(stock_id) ON DELETE RESTRICT ON UPDATE CASCADE,
  INDEX idx_claim_items_claim (claim_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- FR2.7 / FR2.8: record actual shipment-level costs rather than hardcoding
-- port_cost and handling_cost inside the P&L procedure.
CREATE TABLE IF NOT EXISTS shipment_costs (
  cost_id BIGINT AUTO_INCREMENT PRIMARY KEY,
  shipment_id INT NOT NULL,
  cost_type ENUM('FREIGHT','PORT','HANDLING','CUSTOMS','INSURANCE','OTHER') NOT NULL,
  amount DECIMAL(14,2) NOT NULL,
  description VARCHAR(255) NULL,
  cost_date DATE NOT NULL,
  recorded_by INT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT chk_shipment_cost_amount CHECK (amount >= 0),
  CONSTRAINT fk_shipment_costs_shipment FOREIGN KEY (shipment_id)
    REFERENCES shipment(shipment_id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_shipment_costs_user FOREIGN KEY (recorded_by)
    REFERENCES users(user_id) ON DELETE SET NULL ON UPDATE CASCADE,
  INDEX idx_shipment_costs_shipment_date (shipment_id, cost_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- [AI/ML TABLES OMITTED - MODULES FR1-FR7 INDEPENDENT]


/* ---------------------------------------------------------------------------
   3. MODULE-SPECIFIC READ VIEWS
   These support list/detail screens. They do NOT replace DAO CRUD methods.
--------------------------------------------------------------------------- */

CREATE OR REPLACE VIEW vw_users_safe AS
SELECT user_id, role, company_id, full_name, email, phone, status,
       failed_attempts, last_login, created_at
FROM users;

CREATE OR REPLACE VIEW vw_ports_management AS
SELECT port_id, port_code, port_name, city, country, latitude, longitude,
       is_active, created_at
FROM ports;

CREATE OR REPLACE VIEW vw_vessels_management AS
SELECT v.vessel_id, v.vessel_name, v.imo_number, v.owner_company_id,
       c.company_name AS owner_company, v.capacity_teu, v.status,
       v.is_active, v.created_at
FROM vessels v
LEFT JOIN companies c ON c.company_id = v.owner_company_id;

CREATE OR REPLACE VIEW vw_containers_management AS
SELECT c.container_id, c.container_number, c.seller_id,
       co.company_name AS seller_name, c.container_type, c.size_ft,
       c.max_weight_kg, c.max_volume_cbm, c.current_port_id,
       p.port_code, p.port_name, c.status, c.created_at
FROM containers c
JOIN companies co ON co.company_id = c.seller_id
LEFT JOIN ports p ON p.port_id = c.current_port_id;

CREATE OR REPLACE VIEW vw_products_stock_summary AS
SELECT p.product_id, p.sku, p.product_name, p.category, p.hs_code,
       p.unit, p.unit_weight_kg, p.unit_volume_cbm, p.unit_price,
       p.unit_cost, p.owner_company_id, p.is_active,
       COALESCE(SUM(s.quantity),0) AS on_hand_qty,
       COALESCE(SUM(s.damaged_qty),0) AS damaged_qty,
       COALESCE(SUM(s.reserved_qty),0) AS reserved_qty,
       COALESCE(SUM(s.quantity - s.damaged_qty - s.reserved_qty),0) AS available_qty,
       COALESCE(SUM((s.quantity - s.damaged_qty - s.reserved_qty) * p.unit_cost),0) AS available_cost_value
FROM products p
LEFT JOIN stock s ON s.product_id = p.product_id AND s.is_active = TRUE
GROUP BY p.product_id, p.sku, p.product_name, p.category, p.hs_code,
         p.unit, p.unit_weight_kg, p.unit_volume_cbm, p.unit_price,
         p.unit_cost, p.owner_company_id, p.is_active;

CREATE OR REPLACE VIEW vw_pricing_rules_management AS
SELECT pr.rule_id, pr.seller_id, c.company_name AS seller_name,
       pr.origin_port_id, po.port_name AS origin_port,
       pr.dest_port_id, pd.port_name AS destination_port,
       pr.container_type, pr.base_rate, pr.rate_per_kg, pr.rate_per_cbm,
       pr.season_multiplier, pr.demand_multiplier,
       pr.valid_from, pr.valid_to, pr.is_active, pr.created_at
FROM pricing_rules pr
JOIN companies c ON c.company_id = pr.seller_id
JOIN ports po ON po.port_id = pr.origin_port_id
JOIN ports pd ON pd.port_id = pr.dest_port_id;

-- One row per movement event; suitable for the tracking timeline.
CREATE OR REPLACE VIEW vw_shipment_tracking_timeline AS
SELECT s.shipment_id, s.shipment_no, s.consumer_id, s.seller_id,
       s.container_id, s.status AS current_shipment_status,
       s.origin_port_id, op.port_name AS origin_port,
       s.dest_port_id, dp.port_name AS destination_port,
       cm.movement_id, cm.status AS event_status, cm.port_id,
       p.port_name AS event_port, cm.location_text, cm.event_time,
       cm.remarks, cm.updated_by
FROM shipment s
LEFT JOIN container_movements cm ON cm.shipment_id = s.shipment_id
LEFT JOIN ports p ON p.port_id = cm.port_id
JOIN ports op ON op.port_id = s.origin_port_id
JOIN ports dp ON dp.port_id = s.dest_port_id;

CREATE OR REPLACE VIEW vw_invoice_line_details AS
SELECT bi.invoice_id, bi.invoice_no, bi.shipment_id, bi.consumer_id,
       bi.seller_id, bi.issue_date, bi.due_date, bi.status,
       bi.sub_total, bi.tax_amount, bi.total_amount, bi.paid_amount,
       (bi.total_amount - bi.paid_amount) AS balance_due,
       ili.item_id, ili.item_type, ili.description, ili.quantity,
       ili.unit_price, ili.amount
FROM billing_invoices bi
LEFT JOIN invoice_line_items ili ON ili.invoice_id = bi.invoice_id;

CREATE OR REPLACE VIEW vw_claim_management AS
SELECT cl.claim_id, cl.claim_no, cl.shipment_id, s.shipment_no,
       cl.container_id, cl.consumer_id, cl.claim_type, cl.description,
       cl.claimed_amount, cl.approved_amount, cl.status,
       cl.seller_remarks, cl.raised_at, cl.settled_at,
       (SELECT COUNT(*) FROM claim_documents d WHERE d.claim_id = cl.claim_id) AS document_count,
       (SELECT COUNT(*) FROM claim_comments cc WHERE cc.claim_id = cl.claim_id) AS comment_count
FROM claims cl
JOIN shipment s ON s.shipment_id = cl.shipment_id;


/* ---------------------------------------------------------------------------
   4A. INVOICE LINE ITEM CALCULATION AND TOTALS
   Keep line amounts and invoice totals synchronized after line INSERT/UPDATE/
   DELETE. The helper is deliberately before the payment helper section.
--------------------------------------------------------------------------- */

DROP TRIGGER IF EXISTS trg_before_invoice_line_insert;
DROP TRIGGER IF EXISTS trg_before_invoice_line_update;
DROP TRIGGER IF EXISTS trg_after_invoice_line_insert;
DROP TRIGGER IF EXISTS trg_after_invoice_line_update;
DROP TRIGGER IF EXISTS trg_after_invoice_line_delete;
DROP PROCEDURE IF EXISTS sp_sync_invoice_line_totals;

DELIMITER $$

CREATE PROCEDURE sp_sync_invoice_line_totals(IN p_invoice_id INT)
BEGIN
  UPDATE billing_invoices bi
  SET bi.sub_total = COALESCE((
        SELECT SUM(ili.amount) FROM invoice_line_items ili
        WHERE ili.invoice_id = p_invoice_id AND ili.item_type <> 'TAX'
      ),0.00),
      bi.tax_amount = COALESCE((
        SELECT SUM(ili.amount) FROM invoice_line_items ili
        WHERE ili.invoice_id = p_invoice_id AND ili.item_type = 'TAX'
      ),0.00),
      bi.total_amount = COALESCE((
        SELECT SUM(ili.amount) FROM invoice_line_items ili
        WHERE ili.invoice_id = p_invoice_id
      ),0.00)
  WHERE bi.invoice_id = p_invoice_id;
END$$

CREATE TRIGGER trg_before_invoice_line_insert
BEFORE INSERT ON invoice_line_items
FOR EACH ROW
BEGIN
  IF NEW.quantity <= 0 OR NEW.unit_price < 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invoice line quantity/price is invalid';
  END IF;
  SET NEW.amount = ROUND(NEW.quantity * NEW.unit_price, 2);
END$$

CREATE TRIGGER trg_before_invoice_line_update
BEFORE UPDATE ON invoice_line_items
FOR EACH ROW
BEGIN
  IF NEW.quantity <= 0 OR NEW.unit_price < 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invoice line quantity/price is invalid';
  END IF;
  SET NEW.amount = ROUND(NEW.quantity * NEW.unit_price, 2);
END$$

CREATE TRIGGER trg_after_invoice_line_insert
AFTER INSERT ON invoice_line_items
FOR EACH ROW
BEGIN
  CALL sp_sync_invoice_line_totals(NEW.invoice_id);
END$$

CREATE TRIGGER trg_after_invoice_line_update
AFTER UPDATE ON invoice_line_items
FOR EACH ROW
BEGIN
  CALL sp_sync_invoice_line_totals(OLD.invoice_id);
  IF NEW.invoice_id <> OLD.invoice_id THEN
    CALL sp_sync_invoice_line_totals(NEW.invoice_id);
  END IF;
END$$

CREATE TRIGGER trg_after_invoice_line_delete
AFTER DELETE ON invoice_line_items
FOR EACH ROW
BEGIN
  CALL sp_sync_invoice_line_totals(OLD.invoice_id);
END$$

DELIMITER ;

/* ---------------------------------------------------------------------------
   4. AUTOMATIC PAYMENT TOTAL SYNCHRONIZATION
   Replaces the old INSERT-only payment trigger. The invoice total is derived
   from all payment rows, so update/delete corrections stay consistent too.
--------------------------------------------------------------------------- */

DROP TRIGGER IF EXISTS trg_before_payment_insert_validate;
DROP TRIGGER IF EXISTS trg_before_payment_update_validate;
DROP TRIGGER IF EXISTS trg_after_payment_insert;
DROP TRIGGER IF EXISTS trg_after_payment_update;
DROP TRIGGER IF EXISTS trg_after_payment_delete;
DROP PROCEDURE IF EXISTS sp_sync_invoice_payment_total;

DELIMITER $$

CREATE PROCEDURE sp_sync_invoice_payment_total(IN p_invoice_id INT)
BEGIN
  UPDATE billing_invoices bi
  SET bi.paid_amount = (
        SELECT COALESCE(SUM(p.amount),0)
        FROM payments p
        WHERE p.invoice_id = p_invoice_id
      ),
      bi.status = CASE
        WHEN (
          SELECT COALESCE(SUM(p.amount),0)
          FROM payments p
          WHERE p.invoice_id = p_invoice_id
        ) >= bi.total_amount THEN 'PAID'
        WHEN (
          SELECT COALESCE(SUM(p.amount),0)
          FROM payments p
          WHERE p.invoice_id = p_invoice_id
        ) > 0 THEN 'PARTIAL'
        ELSE 'UNPAID'
      END
  WHERE bi.invoice_id = p_invoice_id;
END$$

CREATE TRIGGER trg_before_payment_insert_validate
BEFORE INSERT ON payments
FOR EACH ROW
BEGIN
  DECLARE v_total DECIMAL(12,2);
  DECLARE v_paid DECIMAL(12,2);
  SELECT total_amount INTO v_total
  FROM billing_invoices WHERE invoice_id = NEW.invoice_id FOR UPDATE;
  SELECT COALESCE(SUM(amount),0.00) INTO v_paid
  FROM payments WHERE invoice_id = NEW.invoice_id;
  IF NEW.amount <= 0 OR v_paid + NEW.amount > v_total THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Payment must be positive and cannot exceed the invoice balance';
  END IF;
END$$

CREATE TRIGGER trg_before_payment_update_validate
BEFORE UPDATE ON payments
FOR EACH ROW
BEGIN
  DECLARE v_total DECIMAL(12,2);
  DECLARE v_paid DECIMAL(12,2);
  SELECT total_amount INTO v_total
  FROM billing_invoices WHERE invoice_id = NEW.invoice_id FOR UPDATE;
  SELECT COALESCE(SUM(amount),0.00) INTO v_paid
  FROM payments
  WHERE invoice_id = NEW.invoice_id AND payment_id <> OLD.payment_id;
  IF NEW.amount <= 0 OR v_paid + NEW.amount > v_total THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Updated payment must be positive and cannot exceed the invoice balance';
  END IF;
END$$

CREATE TRIGGER trg_after_payment_insert
AFTER INSERT ON payments
FOR EACH ROW
BEGIN
  CALL sp_sync_invoice_payment_total(NEW.invoice_id);
END$$

CREATE TRIGGER trg_after_payment_update
AFTER UPDATE ON payments
FOR EACH ROW
BEGIN
  CALL sp_sync_invoice_payment_total(OLD.invoice_id);
  IF NEW.invoice_id <> OLD.invoice_id THEN
    CALL sp_sync_invoice_payment_total(NEW.invoice_id);
  END IF;
END$$

CREATE TRIGGER trg_after_payment_delete
AFTER DELETE ON payments
FOR EACH ROW
BEGIN
  CALL sp_sync_invoice_payment_total(OLD.invoice_id);
END$$

DELIMITER ;

/* ---------------------------------------------------------------------------
   5. INVOICE GENERATION PROCEDURE
   Call from the booking Service/DAO inside the same JDBC transaction after the
   shipment is confirmed. It uses configured tax_rates; it does not invent a
   tax percentage. If no active rate exists, tax is zero until configured.
--------------------------------------------------------------------------- */

DROP PROCEDURE IF EXISTS sp_create_invoice_for_shipment;

DELIMITER $$

CREATE PROCEDURE sp_create_invoice_for_shipment(
  IN p_shipment_id INT,
  IN p_due_days INT
)
BEGIN
  DECLARE v_consumer_id INT;
  DECLARE v_seller_id INT;
  DECLARE v_quote DECIMAL(12,2);
  DECLARE v_tax_rate DECIMAL(7,4) DEFAULT 0.0000;
  DECLARE v_tax_amount DECIMAL(12,2) DEFAULT 0.00;
  DECLARE v_invoice_id INT;
  DECLARE v_existing INT DEFAULT 0;

  SELECT COUNT(*) INTO v_existing
  FROM billing_invoices
  WHERE shipment_id = p_shipment_id;

  IF v_existing > 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'An invoice already exists for this shipment';
  END IF;

  SELECT consumer_id, seller_id, quoted_price
    INTO v_consumer_id, v_seller_id, v_quote
  FROM shipment
  WHERE shipment_id = p_shipment_id;

  SET v_tax_rate = COALESCE((
    SELECT rate_pct
    FROM tax_rates
    WHERE is_active = TRUE
      AND valid_from <= CURDATE()
      AND (valid_to IS NULL OR valid_to >= CURDATE())
    ORDER BY valid_from DESC
    LIMIT 1
  ), 0.0000);

  SET v_tax_amount = ROUND(v_quote * v_tax_rate / 100, 2);

  INSERT INTO billing_invoices
    (invoice_no, shipment_id, consumer_id, seller_id, sub_total,
     tax_amount, total_amount, paid_amount, status, issue_date, due_date)
  VALUES
    (CONCAT('INV-', DATE_FORMAT(CURDATE(), '%Y%m%d'), '-', LPAD(p_shipment_id, 8, '0')),
     p_shipment_id, v_consumer_id, v_seller_id, v_quote,
     v_tax_amount, v_quote + v_tax_amount, 0.00, 'UNPAID',
     CURDATE(), DATE_ADD(CURDATE(), INTERVAL GREATEST(COALESCE(p_due_days,30),0) DAY));

  SET v_invoice_id = LAST_INSERT_ID();

  INSERT INTO invoice_line_items
    (invoice_id, item_type, description, quantity, unit_price, amount)
  VALUES
    (v_invoice_id, 'FREIGHT', 'Shipment freight charge', 1.00, v_quote, v_quote);

  IF v_tax_amount > 0 THEN
    INSERT INTO invoice_line_items
      (invoice_id, item_type, description, quantity, unit_price, amount)
    VALUES
      (v_invoice_id, 'TAX', CONCAT('Configured tax at ', v_tax_rate, '%'),
       1.00, v_tax_amount, v_tax_amount);
  END IF;
END$$

DELIMITER ;

/* ---------------------------------------------------------------------------
   6. CLAIM STATUS AUDIT USER CONTEXT
   Before INSERT/UPDATE on claims, Java should execute:
     SET @app_user_id = ?
   on the same JDBC Connection. Do not trust a user id sent from the browser.
--------------------------------------------------------------------------- */

DROP TRIGGER IF EXISTS trg_before_claim_insert_eligibility;
DROP TRIGGER IF EXISTS trg_after_claim_status_change;
DROP TRIGGER IF EXISTS trg_after_claim_insert_history;

DELIMITER $$

CREATE TRIGGER trg_before_claim_insert_eligibility
BEFORE INSERT ON claims
FOR EACH ROW
BEGIN
  DECLARE v_status VARCHAR(30);
  DECLARE v_arrival DATETIME;
  DECLARE v_window INT DEFAULT 30;
  SELECT status, actual_arrival INTO v_status, v_arrival
  FROM shipment WHERE shipment_id = NEW.shipment_id;
  SET v_window = CAST(COALESCE((
    SELECT setting_value FROM system_settings WHERE setting_key = 'claim_window_days'
  ), '30') AS UNSIGNED);
  IF v_status NOT IN ('ARRIVED','DELIVERED') THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Claims can only be raised for ARRIVED or DELIVERED shipments';
  END IF;
  SET v_arrival = COALESCE(v_arrival, (
    SELECT MAX(event_time) FROM container_movements
    WHERE shipment_id = NEW.shipment_id AND status IN ('ARRIVED','DELIVERED')
  ));
  IF v_arrival IS NULL OR DATEDIFF(CURDATE(), DATE(v_arrival)) > v_window THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Claim is outside the configured claim window';
  END IF;
END$$

CREATE TRIGGER trg_after_claim_insert_history
AFTER INSERT ON claims
FOR EACH ROW
BEGIN
  INSERT INTO claim_status_history
    (claim_id, old_status, new_status, changed_by, remarks, changed_at)
  VALUES
    (NEW.claim_id, NULL, NEW.status, @app_user_id, 'Claim created', CURRENT_TIMESTAMP);
END$$

CREATE TRIGGER trg_after_claim_status_change
AFTER UPDATE ON claims
FOR EACH ROW
BEGIN
  IF OLD.status <> NEW.status THEN
    INSERT INTO claim_status_history
      (claim_id, old_status, new_status, changed_by, remarks, changed_at)
    VALUES
      (NEW.claim_id, OLD.status, NEW.status, @app_user_id,
       NEW.seller_remarks, CURRENT_TIMESTAMP);
  END IF;
END$$

DELIMITER ;

/* ---------------------------------------------------------------------------
   7. COMPLETE PRICING AUDIT
--------------------------------------------------------------------------- */

DROP TRIGGER IF EXISTS trg_after_pricing_rule_update;

DELIMITER $$

CREATE TRIGGER trg_after_pricing_rule_update
AFTER UPDATE ON pricing_rules
FOR EACH ROW
BEGIN
  IF NOT (OLD.base_rate <=> NEW.base_rate)
     OR NOT (OLD.rate_per_kg <=> NEW.rate_per_kg)
     OR NOT (OLD.rate_per_cbm <=> NEW.rate_per_cbm)
     OR NOT (OLD.season_multiplier <=> NEW.season_multiplier)
     OR NOT (OLD.demand_multiplier <=> NEW.demand_multiplier)
     OR NOT (OLD.valid_from <=> NEW.valid_from)
     OR NOT (OLD.valid_to <=> NEW.valid_to)
     OR NOT (OLD.is_active <=> NEW.is_active) THEN
    INSERT INTO pricing_audit
      (rule_id, old_rate, new_rate,
       old_rate_per_kg, new_rate_per_kg,
       old_rate_per_cbm, new_rate_per_cbm,
       old_multiplier, new_multiplier,
       old_season_multiplier, new_season_multiplier,
       old_demand_multiplier, new_demand_multiplier,
       changed_by, changed_at)
    VALUES
      (NEW.rule_id, OLD.base_rate, NEW.base_rate,
       OLD.rate_per_kg, NEW.rate_per_kg,
       OLD.rate_per_cbm, NEW.rate_per_cbm,
       OLD.demand_multiplier, NEW.demand_multiplier,
       OLD.season_multiplier, NEW.season_multiplier,
       OLD.demand_multiplier, NEW.demand_multiplier,
       @app_user_id, CURRENT_TIMESTAMP);
  END IF;
END$$

DELIMITER ;


/* ---------------------------------------------------------------------------
   7A. DYNAMIC PRICING: VALIDITY-WINDOW-AWARE RULE SELECTION
--------------------------------------------------------------------------- */

DROP PROCEDURE IF EXISTS sp_calculate_dynamic_price;

DELIMITER $$

CREATE PROCEDURE sp_calculate_dynamic_price(
  IN p_seller_id INT,
  IN p_orig_port INT,
  IN p_dest_port INT,
  IN p_type VARCHAR(10),
  IN p_weight DECIMAL(10,2),
  IN p_volume DECIMAL(8,2),
  OUT p_final_price DECIMAL(12,2)
)
BEGIN
  DECLARE v_base DECIMAL(12,2);
  DECLARE v_wt_rate DECIMAL(8,4);
  DECLARE v_vol_rate DECIMAL(8,2);
  DECLARE v_season DECIMAL(4,2);
  DECLARE v_demand DECIMAL(4,2);
  DECLARE v_rule_count INT DEFAULT 0;

  IF p_weight < 0 OR p_volume < 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cargo weight and volume cannot be negative';
  END IF;

  SELECT COUNT(*) INTO v_rule_count
  FROM pricing_rules
  WHERE seller_id = p_seller_id
    AND origin_port_id = p_orig_port
    AND dest_port_id = p_dest_port
    AND container_type = p_type
    AND is_active = TRUE
    AND (valid_from IS NULL OR valid_from <= CURDATE())
    AND (valid_to IS NULL OR valid_to >= CURDATE());

  IF v_rule_count = 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'No active pricing rule is valid for this seller, route and container type';
  END IF;

  SELECT base_rate, rate_per_kg, rate_per_cbm,
         season_multiplier, demand_multiplier
    INTO v_base, v_wt_rate, v_vol_rate, v_season, v_demand
  FROM pricing_rules
  WHERE seller_id = p_seller_id
    AND origin_port_id = p_orig_port
    AND dest_port_id = p_dest_port
    AND container_type = p_type
    AND is_active = TRUE
    AND (valid_from IS NULL OR valid_from <= CURDATE())
    AND (valid_to IS NULL OR valid_to >= CURDATE())
  ORDER BY valid_from DESC
  LIMIT 1;

  SET p_final_price = ROUND(
    (v_base + (p_weight * v_wt_rate) + (p_volume * v_vol_rate)) * v_season * v_demand,
    2
  );
END$$

DELIMITER ;

/* ---------------------------------------------------------------------------
   8. SHIPMENT CONTAINER VALIDATION AND ALLOCATION
   The INSERT is rejected unless the container belongs to the seller, is
   available at the origin, and has enough weight/volume capacity.
--------------------------------------------------------------------------- */

DROP TRIGGER IF EXISTS trg_before_shipment_insert_validate;
DROP TRIGGER IF EXISTS trg_before_shipment_update_status;
DROP TRIGGER IF EXISTS trg_after_shipment_insert_allocate;
DROP TRIGGER IF EXISTS trg_after_shipment_update_release;
DROP TRIGGER IF EXISTS trg_after_container_movement_insert;

DELIMITER $$

CREATE TRIGGER trg_before_shipment_insert_validate
BEFORE INSERT ON shipment
FOR EACH ROW
BEGIN
  DECLARE v_status VARCHAR(20);
  DECLARE v_port_id INT;
  DECLARE v_seller_id INT;
  DECLARE v_max_weight DECIMAL(10,2);
  DECLARE v_max_volume DECIMAL(8,2);

  SELECT status, current_port_id, seller_id, max_weight_kg, max_volume_cbm
    INTO v_status, v_port_id, v_seller_id, v_max_weight, v_max_volume
  FROM containers
  WHERE container_id = NEW.container_id
  FOR UPDATE;

  IF v_status <> 'AVAILABLE' THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Container is not available for booking';
  END IF;

  IF v_port_id IS NULL OR v_port_id <> NEW.origin_port_id THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Container is not available at the selected origin port';
  END IF;

  IF v_seller_id <> NEW.seller_id THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Container does not belong to the selected seller';
  END IF;

  IF NEW.cargo_weight_kg > v_max_weight OR NEW.cargo_volume_cbm > v_max_volume THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Cargo exceeds container weight or volume capacity';
  END IF;

  IF NEW.origin_port_id = NEW.dest_port_id THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Origin and destination ports must be different';
  END IF;
END$$

CREATE TRIGGER trg_before_shipment_update_status
BEFORE UPDATE ON shipment
FOR EACH ROW
BEGIN
  IF OLD.status <> NEW.status AND NOT (
       (OLD.status = 'BOOKED' AND NEW.status IN ('LOADED','CANCELLED'))
    OR (OLD.status = 'LOADED' AND NEW.status IN ('DEPARTED','CANCELLED'))
    OR (OLD.status = 'DEPARTED' AND NEW.status = 'IN_TRANSIT')
    OR (OLD.status = 'IN_TRANSIT' AND NEW.status = 'ARRIVED')
    OR (OLD.status = 'ARRIVED' AND NEW.status = 'CUSTOMS_CLEARED')
    OR (OLD.status = 'CUSTOMS_CLEARED' AND NEW.status = 'DELIVERED')
  ) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid shipment status transition';
  END IF;
END$$

CREATE TRIGGER trg_after_shipment_insert_allocate
AFTER INSERT ON shipment
FOR EACH ROW
BEGIN
  UPDATE containers
  SET status = 'ALLOCATED'
  WHERE container_id = NEW.container_id;
END$$

CREATE TRIGGER trg_after_shipment_update_release
AFTER UPDATE ON shipment
FOR EACH ROW
BEGIN
  IF OLD.status <> NEW.status AND NEW.status IN ('DELIVERED','CANCELLED') THEN
    UPDATE containers
    SET status = 'AVAILABLE',
        current_port_id = CASE
          WHEN NEW.status = 'DELIVERED' THEN NEW.dest_port_id
          ELSE NEW.origin_port_id
        END
    WHERE container_id = NEW.container_id;
  END IF;
END$$

CREATE TRIGGER trg_after_container_movement_insert
AFTER INSERT ON container_movements
FOR EACH ROW
BEGIN
  UPDATE shipment
  SET status = NEW.status
  WHERE shipment_id = NEW.shipment_id
    AND status <> NEW.status;

  UPDATE containers
  SET current_port_id = COALESCE(NEW.port_id, current_port_id),
      status = CASE
        WHEN NEW.status = 'BOOKED' THEN 'ALLOCATED'
        WHEN NEW.status IN ('LOADED','DEPARTED','IN_TRANSIT','ARRIVED','CUSTOMS_CLEARED') THEN 'IN_TRANSIT'
        WHEN NEW.status IN ('DELIVERED','CANCELLED') THEN 'AVAILABLE'
        ELSE status
      END
  WHERE container_id = NEW.container_id;
END$$

DELIMITER ;

/* ---------------------------------------------------------------------------
   9. STOCK LEDGER SYNCHRONIZATION
   Every physical stock insert/update writes a ledger row. Reservation-only
   changes do not create IN/OUT movements. App sets @app_user_id and, when
   relevant, @app_reference_type / @app_reference_id on the same connection.
--------------------------------------------------------------------------- */

DROP TRIGGER IF EXISTS trg_after_stock_insert_ledger;
DROP TRIGGER IF EXISTS trg_after_stock_update_ledger;

DELIMITER $$

CREATE TRIGGER trg_after_stock_insert_ledger
AFTER INSERT ON stock
FOR EACH ROW
BEGIN
  IF NEW.quantity > 0 THEN
    INSERT INTO inventory_ledger
      (stock_id, product_id, txn_type, quantity, balance_after,
       reference_type, reference_id, changed_by, txn_time)
    SELECT NEW.stock_id, NEW.product_id, 'IN', NEW.quantity,
           NEW.quantity - NEW.damaged_qty,
           COALESCE(@app_reference_type,'OPENING'), @app_reference_id,
           @app_user_id, CURRENT_TIMESTAMP;
  END IF;
END$$

CREATE TRIGGER trg_after_stock_update_ledger
AFTER UPDATE ON stock
FOR EACH ROW
BEGIN
  IF NEW.quantity > OLD.quantity THEN
    INSERT INTO inventory_ledger
      (stock_id, product_id, txn_type, quantity, balance_after,
       reference_type, reference_id, changed_by, txn_time)
    VALUES
      (NEW.stock_id, NEW.product_id, 'IN', NEW.quantity - OLD.quantity,
       NEW.quantity - NEW.damaged_qty,
       COALESCE(@app_reference_type,'STOCK_UPDATE'), @app_reference_id,
       @app_user_id, CURRENT_TIMESTAMP);
  ELSEIF NEW.quantity < OLD.quantity THEN
    INSERT INTO inventory_ledger
      (stock_id, product_id, txn_type, quantity, balance_after,
       reference_type, reference_id, changed_by, txn_time)
    VALUES
      (NEW.stock_id, NEW.product_id,
       IF(@app_reference_type = 'CLAIM','CLAIM_LOSS','OUT'),
       OLD.quantity - NEW.quantity,
       NEW.quantity - NEW.damaged_qty,
       COALESCE(@app_reference_type,'STOCK_UPDATE'), @app_reference_id,
       @app_user_id, CURRENT_TIMESTAMP);
  END IF;

  IF NEW.damaged_qty > OLD.damaged_qty THEN
    INSERT INTO inventory_ledger
      (stock_id, product_id, txn_type, quantity, balance_after,
       reference_type, reference_id, changed_by, txn_time)
    VALUES
      (NEW.stock_id, NEW.product_id, 'DAMAGE', NEW.damaged_qty - OLD.damaged_qty,
       NEW.quantity - NEW.damaged_qty,
       COALESCE(@app_reference_type,'STOCK_UPDATE'), @app_reference_id,
       @app_user_id, CURRENT_TIMESTAMP);
  END IF;
END$$

DELIMITER ;

-- One-time ledger opening balances for stock rows that existed before this patch.
INSERT INTO inventory_ledger
  (stock_id, product_id, txn_type, quantity, balance_after,
   reference_type, reference_id, changed_by, txn_time)
SELECT s.stock_id, s.product_id, 'IN', s.quantity,
       s.quantity - s.damaged_qty, 'MIGRATION', NULL, NULL, CURRENT_TIMESTAMP
FROM stock s
WHERE NOT EXISTS (
  SELECT 1 FROM inventory_ledger il
  WHERE il.stock_id = s.stock_id
);

/* ---------------------------------------------------------------------------
   9A. SHIPMENT ITEM CALCULATION / LOCKING
   Weight, volume and amount are derived from product dimensions and quantity.
   Item changes are blocked after booking confirmation.
--------------------------------------------------------------------------- */

DROP TRIGGER IF EXISTS trg_before_shipment_item_insert;
DROP TRIGGER IF EXISTS trg_before_shipment_item_update;
DROP TRIGGER IF EXISTS trg_before_shipment_item_delete;
DROP TRIGGER IF EXISTS trg_after_shipment_item_insert;
DROP TRIGGER IF EXISTS trg_after_shipment_item_update;
DROP TRIGGER IF EXISTS trg_after_shipment_item_delete;

DELIMITER $$

CREATE TRIGGER trg_before_shipment_item_insert
BEFORE INSERT ON shipment_items
FOR EACH ROW
BEGIN
  DECLARE v_unit_weight DECIMAL(8,3);
  DECLARE v_unit_volume DECIMAL(10,4);
  DECLARE v_status VARCHAR(30);
  DECLARE v_confirmed BOOLEAN;

  SELECT status, booking_confirmed INTO v_status, v_confirmed
  FROM shipment WHERE shipment_id = NEW.shipment_id;
  IF v_status <> 'BOOKED' OR v_confirmed = TRUE THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Shipment items can only be added before booking confirmation';
  END IF;
  IF NEW.quantity <= 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Shipment item quantity must be greater than zero';
  END IF;

  SELECT unit_weight_kg, unit_volume_cbm
    INTO v_unit_weight, v_unit_volume
  FROM products
  WHERE product_id = NEW.product_id AND is_active = TRUE;

  SET NEW.weight_kg = NEW.quantity * v_unit_weight;
  SET NEW.volume_cbm = NEW.quantity * v_unit_volume;
  SET NEW.amount = NEW.quantity * NEW.unit_price;
END$$

CREATE TRIGGER trg_before_shipment_item_update
BEFORE UPDATE ON shipment_items
FOR EACH ROW
BEGIN
  DECLARE v_unit_weight DECIMAL(8,3);
  DECLARE v_unit_volume DECIMAL(10,4);
  DECLARE v_status VARCHAR(30);
  DECLARE v_confirmed BOOLEAN;

  SELECT status, booking_confirmed INTO v_status, v_confirmed
  FROM shipment WHERE shipment_id = OLD.shipment_id;
  IF v_status <> 'BOOKED' OR v_confirmed = TRUE THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Confirmed shipment items cannot be edited';
  END IF;
  IF NEW.quantity <= 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Shipment item quantity must be greater than zero';
  END IF;

  SELECT unit_weight_kg, unit_volume_cbm
    INTO v_unit_weight, v_unit_volume
  FROM products
  WHERE product_id = NEW.product_id AND is_active = TRUE;

  SET NEW.weight_kg = NEW.quantity * v_unit_weight;
  SET NEW.volume_cbm = NEW.quantity * v_unit_volume;
  SET NEW.amount = NEW.quantity * NEW.unit_price;
END$$

CREATE TRIGGER trg_before_shipment_item_delete
BEFORE DELETE ON shipment_items
FOR EACH ROW
BEGIN
  DECLARE v_status VARCHAR(30);
  DECLARE v_confirmed BOOLEAN;
  SELECT status, booking_confirmed INTO v_status, v_confirmed
  FROM shipment WHERE shipment_id = OLD.shipment_id;
  IF v_status <> 'BOOKED' OR v_confirmed = TRUE THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Confirmed shipment items cannot be deleted';
  END IF;
END$$

CREATE TRIGGER trg_after_shipment_item_insert
AFTER INSERT ON shipment_items
FOR EACH ROW
BEGIN
  UPDATE shipment s
  SET cargo_weight_kg = (SELECT COALESCE(SUM(weight_kg),0) FROM shipment_items WHERE shipment_id = NEW.shipment_id),
      cargo_volume_cbm = (SELECT COALESCE(SUM(volume_cbm),0) FROM shipment_items WHERE shipment_id = NEW.shipment_id)
  WHERE s.shipment_id = NEW.shipment_id;
END$$

CREATE TRIGGER trg_after_shipment_item_update
AFTER UPDATE ON shipment_items
FOR EACH ROW
BEGIN
  UPDATE shipment s
  SET cargo_weight_kg = (SELECT COALESCE(SUM(weight_kg),0) FROM shipment_items WHERE shipment_id = NEW.shipment_id),
      cargo_volume_cbm = (SELECT COALESCE(SUM(volume_cbm),0) FROM shipment_items WHERE shipment_id = NEW.shipment_id)
  WHERE s.shipment_id = NEW.shipment_id;
END$$

CREATE TRIGGER trg_after_shipment_item_delete
AFTER DELETE ON shipment_items
FOR EACH ROW
BEGIN
  UPDATE shipment s
  SET cargo_weight_kg = (SELECT COALESCE(SUM(weight_kg),0) FROM shipment_items WHERE shipment_id = OLD.shipment_id),
      cargo_volume_cbm = (SELECT COALESCE(SUM(volume_cbm),0) FROM shipment_items WHERE shipment_id = OLD.shipment_id)
  WHERE s.shipment_id = OLD.shipment_id;
END$$

DELIMITER ;

/* ---------------------------------------------------------------------------
   10. BOOKING SUPPORT PROCEDURE
   Run from the Booking Service after inserting shipment + shipment_items, on
   the same JDBC transaction. It reserves goods by locking stock rows and then
   creates the invoice. Commit only after this procedure succeeds.
--------------------------------------------------------------------------- */

CREATE TABLE IF NOT EXISTS shipment_stock_reservations (
  reservation_id BIGINT AUTO_INCREMENT PRIMARY KEY,
  shipment_id INT NOT NULL,
  shipment_item_id INT NOT NULL,
  stock_id INT NOT NULL,
  quantity_reserved INT NOT NULL,
  status ENUM('RESERVED','CONSUMED','RELEASED') NOT NULL DEFAULT 'RESERVED',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT chk_reservation_qty CHECK (quantity_reserved > 0),
  CONSTRAINT fk_reservation_shipment FOREIGN KEY (shipment_id)
    REFERENCES shipment(shipment_id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_reservation_item FOREIGN KEY (shipment_item_id)
    REFERENCES shipment_items(item_id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_reservation_stock FOREIGN KEY (stock_id)
    REFERENCES stock(stock_id) ON DELETE RESTRICT ON UPDATE CASCADE,
  INDEX idx_reservation_shipment_status (shipment_id, status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP PROCEDURE IF EXISTS sp_reserve_shipment_stock;
DROP PROCEDURE IF EXISTS sp_finalize_shipment_stock;
DROP PROCEDURE IF EXISTS sp_confirm_shipment_booking;

DELIMITER $$

CREATE PROCEDURE sp_reserve_shipment_stock(IN p_shipment_id INT)
BEGIN
  DECLARE v_done INT DEFAULT 0;
  DECLARE v_item_id INT;
  DECLARE v_product_id INT;
  DECLARE v_required INT;
  DECLARE v_remaining INT;

  DECLARE cur_items CURSOR FOR
    SELECT item_id, product_id, quantity
    FROM shipment_items
    WHERE shipment_id = p_shipment_id
    ORDER BY item_id;
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = 1;

  IF NOT EXISTS (SELECT 1 FROM shipment_items WHERE shipment_id = p_shipment_id) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'A shipment must contain at least one item before stock reservation';
  END IF;
  IF EXISTS (SELECT 1 FROM shipment_stock_reservations WHERE shipment_id = p_shipment_id AND status = 'RESERVED') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Stock has already been reserved for this shipment';
  END IF;

  OPEN cur_items;
  item_loop: LOOP
    FETCH cur_items INTO v_item_id, v_product_id, v_required;
    IF v_done = 1 THEN
      LEAVE item_loop;
    END IF;

    SET v_remaining = v_required;

    BEGIN
      DECLARE v_stock_done INT DEFAULT 0;
      DECLARE v_stock_id INT;
      DECLARE v_qty INT;
      DECLARE v_damaged INT;
      DECLARE v_reserved INT;
      DECLARE v_take INT;

      DECLARE cur_stock CURSOR FOR
        SELECT stock_id, quantity, damaged_qty, reserved_qty
        FROM stock
        WHERE product_id = v_product_id
          AND is_active = TRUE
          AND (quantity - damaged_qty - reserved_qty) > 0
        ORDER BY stock_id
        FOR UPDATE;
      DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_stock_done = 1;

      OPEN cur_stock;
      stock_loop: LOOP
        FETCH cur_stock INTO v_stock_id, v_qty, v_damaged, v_reserved;
        IF v_stock_done = 1 OR v_remaining <= 0 THEN
          LEAVE stock_loop;
        END IF;

        SET v_take = LEAST(v_remaining, v_qty - v_damaged - v_reserved);
        IF v_take > 0 THEN
          UPDATE stock SET reserved_qty = reserved_qty + v_take
          WHERE stock_id = v_stock_id;

          INSERT INTO shipment_stock_reservations
            (shipment_id, shipment_item_id, stock_id, quantity_reserved, status)
          VALUES
            (p_shipment_id, v_item_id, v_stock_id, v_take, 'RESERVED');

          SET v_remaining = v_remaining - v_take;
        END IF;
      END LOOP;
      CLOSE cur_stock;
    END;

    IF v_remaining > 0 THEN
      SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Insufficient available stock for one or more shipment items';
    END IF;
  END LOOP;
  CLOSE cur_items;
END$$

CREATE PROCEDURE sp_finalize_shipment_stock(
  IN p_shipment_id INT,
  IN p_action VARCHAR(10)
)
BEGIN
  DECLARE v_done INT DEFAULT 0;
  DECLARE v_reservation_id BIGINT;
  DECLARE v_stock_id INT;
  DECLARE v_qty INT;
  DECLARE v_status VARCHAR(20);

  DECLARE cur_reservations CURSOR FOR
    SELECT reservation_id, stock_id, quantity_reserved, status
    FROM shipment_stock_reservations
    WHERE shipment_id = p_shipment_id AND status = 'RESERVED'
    ORDER BY reservation_id
    FOR UPDATE;
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = 1;

  IF p_action NOT IN ('CONSUME','RELEASE') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Action must be CONSUME or RELEASE';
  END IF;

  SET @app_reference_type = 'SHIPMENT';
  SET @app_reference_id = p_shipment_id;

  OPEN cur_reservations;
  reservation_loop: LOOP
    FETCH cur_reservations INTO v_reservation_id, v_stock_id, v_qty, v_status;
    IF v_done = 1 THEN LEAVE reservation_loop; END IF;

    IF p_action = 'CONSUME' THEN
      UPDATE stock
      SET reserved_qty = reserved_qty - v_qty,
          quantity = quantity - v_qty
      WHERE stock_id = v_stock_id
        AND reserved_qty >= v_qty
        AND quantity - v_qty >= damaged_qty;
      IF ROW_COUNT() <> 1 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Unable to consume reserved stock';
      END IF;
      UPDATE shipment_stock_reservations
      SET status = 'CONSUMED' WHERE reservation_id = v_reservation_id;
    ELSE
      UPDATE stock
      SET reserved_qty = reserved_qty - v_qty
      WHERE stock_id = v_stock_id AND reserved_qty >= v_qty;
      IF ROW_COUNT() <> 1 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Unable to release reserved stock';
      END IF;
      UPDATE shipment_stock_reservations
      SET status = 'RELEASED' WHERE reservation_id = v_reservation_id;
    END IF;
  END LOOP;
  CLOSE cur_reservations;
END$$

CREATE PROCEDURE sp_confirm_shipment_booking(
  IN p_shipment_id INT,
  IN p_due_days INT
)
BEGIN
  DECLARE v_status VARCHAR(30);
  DECLARE v_confirmed BOOLEAN;
  DECLARE v_container_id INT;
  DECLARE v_weight DECIMAL(10,2);
  DECLARE v_volume DECIMAL(8,2);
  DECLARE v_max_weight DECIMAL(10,2);
  DECLARE v_max_volume DECIMAL(8,2);

  SELECT status, booking_confirmed, container_id
    INTO v_status, v_confirmed, v_container_id
  FROM shipment WHERE shipment_id = p_shipment_id FOR UPDATE;

  IF v_status <> 'BOOKED' OR v_confirmed = TRUE THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Only an unconfirmed BOOKED shipment can be confirmed';
  END IF;

  SELECT COALESCE(SUM(weight_kg),0), COALESCE(SUM(volume_cbm),0)
    INTO v_weight, v_volume
  FROM shipment_items WHERE shipment_id = p_shipment_id;

  SELECT max_weight_kg, max_volume_cbm
    INTO v_max_weight, v_max_volume
  FROM containers WHERE container_id = v_container_id FOR UPDATE;

  IF NOT EXISTS (SELECT 1 FROM shipment_items WHERE shipment_id = p_shipment_id) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Shipment must contain at least one item before confirmation';
  END IF;
  IF EXISTS (
    SELECT 1
    FROM shipment_items si
    JOIN products p ON p.product_id = si.product_id
    WHERE si.shipment_id = p_shipment_id
      AND (p.unit_weight_kg <= 0 OR p.unit_volume_cbm <= 0 OR p.is_active = FALSE)
  ) THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Every shipment product must be active and have positive weight and volume';
  END IF;
  IF v_weight <= 0 OR v_volume <= 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Shipment must contain valid goods with positive weight and volume';
  END IF;
  IF v_weight > v_max_weight OR v_volume > v_max_volume THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Goods exceed container weight or volume capacity';
  END IF;

  UPDATE shipment
  SET cargo_weight_kg = v_weight,
      cargo_volume_cbm = v_volume
  WHERE shipment_id = p_shipment_id;

  CALL sp_reserve_shipment_stock(p_shipment_id);
  CALL sp_create_invoice_for_shipment(p_shipment_id, p_due_days);

  UPDATE shipment
  SET booking_confirmed = TRUE
  WHERE shipment_id = p_shipment_id;
END$$

DELIMITER ;

/* ---------------------------------------------------------------------------
   11. CLAIM SETTLEMENT: APPROVED AMOUNT, INVENTORY AND P&L
   Before CALL, the application should set @app_user_id on this connection.
   Claims of type LOSS/SHORTAGE/DAMAGE must have claim_items rows.
--------------------------------------------------------------------------- */

DROP PROCEDURE IF EXISTS sp_settle_claim;

DELIMITER $$

CREATE PROCEDURE sp_settle_claim(
  IN p_claim_id INT,
  IN p_approved_amount DECIMAL(12,2),
  IN p_seller_remarks VARCHAR(255)
)
BEGIN
  DECLARE v_status VARCHAR(30);
  DECLARE v_claimed DECIMAL(12,2);
  DECLARE v_type VARCHAR(20);
  DECLARE v_shipment_id INT;
  DECLARE v_seller_id INT;
  DECLARE v_period DATE;
  DECLARE v_done INT DEFAULT 0;
  DECLARE v_stock_id INT;
  DECLARE v_qty INT;
  DECLARE v_disposition VARCHAR(10);
  DECLARE v_product_id INT;
  DECLARE v_on_hand INT;
  DECLARE v_damaged INT;
  DECLARE v_reserved INT;

  DECLARE cur_claim_items CURSOR FOR
    SELECT ci.stock_id, ci.quantity_affected, ci.disposition
    FROM claim_items ci
    WHERE ci.claim_id = p_claim_id
    ORDER BY ci.claim_item_id;
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = 1;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  START TRANSACTION;

  IF NOT EXISTS (SELECT 1 FROM claims WHERE claim_id = p_claim_id) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Claim does not exist';
  END IF;

  SELECT cl.status, cl.claimed_amount, cl.claim_type,
         cl.shipment_id, s.seller_id
    INTO v_status, v_claimed, v_type, v_shipment_id, v_seller_id
  FROM claims cl
  JOIN shipment s ON s.shipment_id = cl.shipment_id
  WHERE cl.claim_id = p_claim_id
  FOR UPDATE;

  IF v_status NOT IN ('APPROVED','PARTIALLY_APPROVED') THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Only approved or partially approved claims can be settled';
  END IF;

  IF p_approved_amount < 0 OR p_approved_amount > v_claimed THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Approved amount must be between zero and the claimed amount';
  END IF;

  IF v_type IN ('LOSS','DAMAGE','SHORTAGE') THEN
    IF NOT EXISTS (SELECT 1 FROM claim_items WHERE claim_id = p_claim_id) THEN
      SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Add affected stock items before settling a goods-loss/damage claim';
    END IF;
  END IF;

  SET @app_reference_type = 'CLAIM';
  SET @app_reference_id = p_claim_id;

  UPDATE claims
  SET approved_amount = p_approved_amount,
      status = 'SETTLED',
      seller_remarks = p_seller_remarks,
      settled_at = CURRENT_TIMESTAMP
  WHERE claim_id = p_claim_id;

  OPEN cur_claim_items;
  claim_item_loop: LOOP
    FETCH cur_claim_items INTO v_stock_id, v_qty, v_disposition;
    IF v_done = 1 THEN LEAVE claim_item_loop; END IF;

    SELECT product_id, quantity, damaged_qty, reserved_qty
      INTO v_product_id, v_on_hand, v_damaged, v_reserved
    FROM stock
    WHERE stock_id = v_stock_id
    FOR UPDATE;

    IF v_qty > (v_on_hand - v_damaged - v_reserved) THEN
      SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Claim quantity exceeds unreserved usable stock';
    END IF;

    IF v_disposition = 'LOSS' THEN
      UPDATE stock SET quantity = quantity - v_qty WHERE stock_id = v_stock_id;
    ELSE
      UPDATE stock SET damaged_qty = damaged_qty + v_qty WHERE stock_id = v_stock_id;
    END IF;
  END LOOP;
  CLOSE cur_claim_items;

  SET v_period = STR_TO_DATE(DATE_FORMAT(CURDATE(), '%Y-%m-01'), '%Y-%m-%d');

  INSERT INTO profit_loss
    (shipment_id, seller_id, period_month, revenue, freight_cost,
     port_cost, handling_cost, claim_loss, net_profit)
  VALUES
    (v_shipment_id, v_seller_id, v_period, 0.00, 0.00,
     0.00, 0.00, p_approved_amount, -p_approved_amount)
  ON DUPLICATE KEY UPDATE
    claim_loss = claim_loss + VALUES(claim_loss),
    net_profit = net_profit - VALUES(claim_loss);

  COMMIT;
END$$

DELIMITER ;



/* ---------------------------------------------------------------------------
   10A. AUTOMATIC STOCK RELEASE / CONSUMPTION WHEN SHIPMENT CLOSES
--------------------------------------------------------------------------- */

DROP TRIGGER IF EXISTS trg_after_shipment_update_release;

DELIMITER $$

CREATE TRIGGER trg_after_shipment_update_release
AFTER UPDATE ON shipment
FOR EACH ROW
BEGIN
  IF OLD.status <> NEW.status AND NEW.status = 'DELIVERED' THEN
    CALL sp_finalize_shipment_stock(NEW.shipment_id, 'CONSUME');
    UPDATE containers
    SET status = 'AVAILABLE', current_port_id = NEW.dest_port_id
    WHERE container_id = NEW.container_id;
  ELSEIF OLD.status <> NEW.status AND NEW.status = 'CANCELLED' THEN
    CALL sp_finalize_shipment_stock(NEW.shipment_id, 'RELEASE');
    UPDATE containers
    SET status = 'AVAILABLE', current_port_id = NEW.origin_port_id
    WHERE container_id = NEW.container_id;
  END IF;
END$$

DELIMITER ;

/* ---------------------------------------------------------------------------
   10B. CORRECTED ANALYTICS PROCEDURES
   - sales growth uses previous month by route
   - ABC uses the trailing 12 months
   - inventory turnover uses ledger opening/closing balances and unit_cost
   - product profitability uses configured unit_cost, not a hardcoded 65%
   - P&L uses payments, recorded shipment_costs and SETTLED approved claim amounts
--------------------------------------------------------------------------- */

DROP PROCEDURE IF EXISTS sp_refresh_sales_trends;
DROP PROCEDURE IF EXISTS sp_calculate_abc_classification;
DROP PROCEDURE IF EXISTS sp_calculate_inventory_turnover;
DROP PROCEDURE IF EXISTS sp_calculate_profitability;
DROP PROCEDURE IF EXISTS sp_calculate_profit_loss;

DELIMITER $$

CREATE PROCEDURE sp_refresh_sales_trends()
BEGIN
  DELETE FROM sales_trend_result;

  INSERT INTO sales_trend_result
    (period_month, origin_port_id, dest_port_id, total_sales, total_qty, growth_pct)
  SELECT period_month, origin_port_id, dest_port_id, total_sales, total_qty,
         CASE
           WHEN previous_month_sales IS NULL OR previous_month_sales = 0 THEN 0.00
           ELSE ROUND(((total_sales - previous_month_sales) / previous_month_sales) * 100, 2)
         END AS growth_pct
  FROM (
    SELECT monthly_sales.*,
           LAG(total_sales) OVER (
             PARTITION BY origin_port_id, dest_port_id ORDER BY period_month
           ) AS previous_month_sales
    FROM (
      SELECT STR_TO_DATE(DATE_FORMAT(st.sale_date, '%Y-%m-01'), '%Y-%m-%d') AS period_month,
             s.origin_port_id, s.dest_port_id,
             SUM(st.total_amount) AS total_sales,
             SUM(st.quantity) AS total_qty
      FROM sales_transactions st
      LEFT JOIN shipment s ON s.shipment_id = st.shipment_id
      GROUP BY STR_TO_DATE(DATE_FORMAT(st.sale_date, '%Y-%m-01'), '%Y-%m-%d'),
               s.origin_port_id, s.dest_port_id
    ) AS monthly_sales
  ) AS trend;
END$$

CREATE PROCEDURE sp_calculate_abc_classification()
BEGIN
  DECLARE v_total_portfolio DECIMAL(14,2) DEFAULT 0.00;
  DECLARE v_from DATE;
  SET v_from = DATE_SUB(CURDATE(), INTERVAL 1 YEAR);

  SELECT COALESCE(SUM(total_amount),0.00)
    INTO v_total_portfolio
  FROM sales_transactions
  WHERE sale_date >= v_from AND sale_date <= CURDATE();

  DELETE FROM abc_classification_result;

  INSERT INTO abc_classification_result
    (product_id, annual_value, cumulative_pct, abc_class, calculated_on)
  SELECT product_id, annual_value, cumulative_pct,
         CASE
           WHEN v_total_portfolio = 0 THEN 'C'
           WHEN cumulative_pct <= 70.00 THEN 'A'
           WHEN cumulative_pct <= 90.00 THEN 'B'
           ELSE 'C'
         END,
         CURDATE()
  FROM (
    SELECT ranked.product_id, ranked.annual_value,
           CASE WHEN v_total_portfolio = 0 THEN 100.00
                ELSE ROUND(ranked.running_value / v_total_portfolio * 100, 2)
           END AS cumulative_pct
    FROM (
      SELECT values_by_product.*,
             SUM(annual_value) OVER (
               ORDER BY annual_value DESC, product_id
               ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
             ) AS running_value
      FROM (
        SELECT p.product_id,
               COALESCE(SUM(st.total_amount),0.00) AS annual_value
        FROM products p
        LEFT JOIN sales_transactions st
          ON st.product_id = p.product_id
         AND st.sale_date >= v_from
         AND st.sale_date <= CURDATE()
        GROUP BY p.product_id
      ) AS values_by_product
    ) AS ranked
  ) AS classified;
END$$

CREATE PROCEDURE sp_calculate_inventory_turnover(
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
  IF p_start > p_end THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Inventory turnover start date must not exceed end date';
  END IF;

  DROP TEMPORARY TABLE IF EXISTS tmp_inv_opening;
  DROP TEMPORARY TABLE IF EXISTS tmp_inv_closing;
  DROP TEMPORARY TABLE IF EXISTS tmp_inv_out;

  CREATE TEMPORARY TABLE tmp_inv_opening AS
  SELECT l.product_id, SUM(l.balance_after) AS opening_qty
  FROM inventory_ledger l
  JOIN (
    SELECT stock_id, MAX(ledger_id) AS last_ledger_id
    FROM inventory_ledger
    WHERE txn_time < p_start
    GROUP BY stock_id
  ) x ON x.last_ledger_id = l.ledger_id
  GROUP BY l.product_id;

  CREATE TEMPORARY TABLE tmp_inv_closing AS
  SELECT l.product_id, SUM(l.balance_after) AS closing_qty
  FROM inventory_ledger l
  JOIN (
    SELECT stock_id, MAX(ledger_id) AS last_ledger_id
    FROM inventory_ledger
    WHERE txn_time < DATE_ADD(p_end, INTERVAL 1 DAY)
    GROUP BY stock_id
  ) x ON x.last_ledger_id = l.ledger_id
  GROUP BY l.product_id;

  CREATE TEMPORARY TABLE tmp_inv_out AS
  SELECT product_id, SUM(quantity) AS out_qty
  FROM inventory_ledger
  WHERE txn_type = 'OUT'
    AND txn_time >= p_start
    AND txn_time < DATE_ADD(p_end, INTERVAL 1 DAY)
  GROUP BY product_id;

  DELETE FROM inventory_turnover_result;

  INSERT INTO inventory_turnover_result
    (product_id, period_start, period_end, cogs, avg_inventory, turnover_ratio)
  SELECT p.product_id, p_start, p_end,
         COALESCE(o.out_qty,0) * p.unit_cost AS cogs,
         ((COALESCE(op.opening_qty,0) + COALESCE(cl.closing_qty,0)) / 2) * p.unit_cost AS avg_inventory,
         CASE
           WHEN ((COALESCE(op.opening_qty,0) + COALESCE(cl.closing_qty,0)) / 2) * p.unit_cost = 0 THEN 0.00
           ELSE ROUND(
             (COALESCE(o.out_qty,0) * p.unit_cost) /
             (((COALESCE(op.opening_qty,0) + COALESCE(cl.closing_qty,0)) / 2) * p.unit_cost), 2
           )
         END AS turnover_ratio
  FROM products p
  LEFT JOIN tmp_inv_opening op ON op.product_id = p.product_id
  LEFT JOIN tmp_inv_closing cl ON cl.product_id = p.product_id
  LEFT JOIN tmp_inv_out o ON o.product_id = p.product_id;

  DROP TEMPORARY TABLE IF EXISTS tmp_inv_opening;
  DROP TEMPORARY TABLE IF EXISTS tmp_inv_closing;
  DROP TEMPORARY TABLE IF EXISTS tmp_inv_out;
END$$

CREATE PROCEDURE sp_calculate_profitability()
BEGIN
  DELETE FROM profitability_result;

  INSERT INTO profitability_result
    (product_id, period_month, revenue, cost, margin_pct)
  SELECT p.product_id,
         STR_TO_DATE(DATE_FORMAT(st.sale_date, '%Y-%m-01'), '%Y-%m-%d') AS period_month,
         SUM(st.total_amount) AS revenue,
         SUM(st.quantity * p.unit_cost) AS cost,
         CASE
           WHEN SUM(st.total_amount) > 0 THEN
             ROUND(((SUM(st.total_amount) - SUM(st.quantity * p.unit_cost)) / SUM(st.total_amount)) * 100, 2)
           ELSE 0.00
         END AS margin_pct
  FROM sales_transactions st
  JOIN products p ON p.product_id = st.product_id
  GROUP BY p.product_id,
           STR_TO_DATE(DATE_FORMAT(st.sale_date, '%Y-%m-01'), '%Y-%m-%d');
END$$

CREATE PROCEDURE sp_calculate_profit_loss()
BEGIN
  DROP TEMPORARY TABLE IF EXISTS tmp_pl_revenue;
  DROP TEMPORARY TABLE IF EXISTS tmp_pl_costs;
  DROP TEMPORARY TABLE IF EXISTS tmp_pl_claims;
  DROP TEMPORARY TABLE IF EXISTS tmp_pl_keys;

  CREATE TEMPORARY TABLE tmp_pl_revenue AS
  SELECT s.shipment_id, s.seller_id,
         STR_TO_DATE(DATE_FORMAT(p.payment_date, '%Y-%m-01'), '%Y-%m-%d') AS period_month,
         SUM(p.amount) AS revenue
  FROM payments p
  JOIN billing_invoices bi ON bi.invoice_id = p.invoice_id
  JOIN shipment s ON s.shipment_id = bi.shipment_id
  GROUP BY s.shipment_id, s.seller_id,
           STR_TO_DATE(DATE_FORMAT(p.payment_date, '%Y-%m-01'), '%Y-%m-%d');

  CREATE TEMPORARY TABLE tmp_pl_costs AS
  SELECT sc.shipment_id, s.seller_id,
         STR_TO_DATE(DATE_FORMAT(sc.cost_date, '%Y-%m-01'), '%Y-%m-%d') AS period_month,
         SUM(CASE WHEN sc.cost_type = 'FREIGHT' THEN sc.amount ELSE 0 END) AS freight_cost,
         SUM(CASE WHEN sc.cost_type = 'PORT' THEN sc.amount ELSE 0 END) AS port_cost,
         SUM(CASE WHEN sc.cost_type = 'HANDLING' THEN sc.amount ELSE 0 END) AS handling_cost
  FROM shipment_costs sc
  JOIN shipment s ON s.shipment_id = sc.shipment_id
  GROUP BY sc.shipment_id, s.seller_id,
           STR_TO_DATE(DATE_FORMAT(sc.cost_date, '%Y-%m-01'), '%Y-%m-%d');

  CREATE TEMPORARY TABLE tmp_pl_claims AS
  SELECT cl.shipment_id, s.seller_id,
         STR_TO_DATE(DATE_FORMAT(cl.settled_at, '%Y-%m-01'), '%Y-%m-%d') AS period_month,
         SUM(cl.approved_amount) AS claim_loss
  FROM claims cl
  JOIN shipment s ON s.shipment_id = cl.shipment_id
  WHERE cl.status = 'SETTLED' AND cl.settled_at IS NOT NULL
  GROUP BY cl.shipment_id, s.seller_id,
           STR_TO_DATE(DATE_FORMAT(cl.settled_at, '%Y-%m-01'), '%Y-%m-%d');

  CREATE TEMPORARY TABLE tmp_pl_keys AS
  SELECT shipment_id, seller_id, period_month FROM tmp_pl_revenue
  UNION
  SELECT shipment_id, seller_id, period_month FROM tmp_pl_costs
  UNION
  SELECT shipment_id, seller_id, period_month FROM tmp_pl_claims;

  DELETE FROM profit_loss WHERE shipment_id IS NOT NULL;

  INSERT INTO profit_loss
    (shipment_id, seller_id, period_month, revenue, freight_cost,
     port_cost, handling_cost, claim_loss, net_profit)
  SELECT k.shipment_id, k.seller_id, k.period_month,
         COALESCE(r.revenue,0.00),
         COALESCE(c.freight_cost,0.00),
         COALESCE(c.port_cost,0.00),
         COALESCE(c.handling_cost,0.00),
         COALESCE(cl.claim_loss,0.00),
         COALESCE(r.revenue,0.00)
           - COALESCE(c.freight_cost,0.00)
           - COALESCE(c.port_cost,0.00)
           - COALESCE(c.handling_cost,0.00)
           - COALESCE(cl.claim_loss,0.00)
  FROM tmp_pl_keys k
  LEFT JOIN tmp_pl_revenue r
    ON r.shipment_id = k.shipment_id AND r.period_month = k.period_month
  LEFT JOIN tmp_pl_costs c
    ON c.shipment_id = k.shipment_id AND c.period_month = k.period_month
  LEFT JOIN tmp_pl_claims cl
    ON cl.shipment_id = k.shipment_id AND cl.period_month = k.period_month;

  DROP TEMPORARY TABLE IF EXISTS tmp_pl_revenue;
  DROP TEMPORARY TABLE IF EXISTS tmp_pl_costs;
  DROP TEMPORARY TABLE IF EXISTS tmp_pl_claims;
  DROP TEMPORARY TABLE IF EXISTS tmp_pl_keys;
END$$

DELIMITER ;


/* ---------------------------------------------------------------------------
   10C. ANALYTICS ORCHESTRATOR
   Demand forecasting is produced by the ML REST service specified in SRS 3.9.
   The legacy SQL heuristic is intentionally not called here because it is not
   Prophet/ARIMA and must not overwrite actual model output.
--------------------------------------------------------------------------- */

DROP PROCEDURE IF EXISTS sp_refresh_all_fr6_analytics;

DELIMITER $$

CREATE PROCEDURE sp_refresh_all_fr6_analytics()
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
  CALL sp_calculate_profit_loss();
  COMMIT;
END$$

DELIMITER ;

/* ---------------------------------------------------------------------------
   12. POST-PATCH CHECKS
--------------------------------------------------------------------------- */
SELECT 'Core tables' AS check_name, COUNT(*) AS result
FROM information_schema.tables
WHERE table_schema = DATABASE() AND table_type = 'BASE TABLE';

SELECT 'Views' AS check_name, COUNT(*) AS result
FROM information_schema.views
WHERE table_schema = DATABASE();

SELECT 'Duplicate invoice per shipment (must return zero rows)' AS check_name,
       shipment_id, COUNT(*) AS invoice_count
FROM billing_invoices
GROUP BY shipment_id
HAVING COUNT(*) > 1;

SELECT 'Duplicate shipment/month P&L rows (must return zero rows)' AS check_name,
       shipment_id, period_month, COUNT(*) AS row_count
FROM profit_loss
WHERE shipment_id IS NOT NULL
GROUP BY shipment_id, period_month
HAVING COUNT(*) > 1;

SELECT 'Invalid stock availability (must return zero rows)' AS check_name,
       stock_id, quantity, damaged_qty, reserved_qty
FROM stock
WHERE quantity < 0 OR damaged_qty < 0
   OR reserved_qty < 0 OR reserved_qty > quantity - damaged_qty;

-- End of patch.



-- =============================================================================
-- SECTION 5: MODULE-BY-MODULE CRUD OPERATIONS REFERENCE (FOR JAVA DAO & VIVA)
-- =============================================================================
/*
The following parameterized queries and CRUD standards map directly to the
Java DAO classes (UsersDAO, ShipmentDAO, PricingDAO, StockDAO, BillingDAO,
AnalyticsDAO, ClaimsDAO) as required by SRS v1.0.
*/
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

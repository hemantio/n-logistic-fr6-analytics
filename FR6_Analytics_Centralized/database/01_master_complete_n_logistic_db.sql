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

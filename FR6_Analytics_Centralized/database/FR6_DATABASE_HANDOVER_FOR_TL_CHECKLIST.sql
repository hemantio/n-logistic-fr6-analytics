-- =============================================================================
-- PROJECT: N Logistic Management Platform
-- MODULE:  FR6 - Analytics Dashboard & P&L (SRS Section 7.9 Complete Checklist)
-- FILE:    FR6_DATABASE_HANDOVER_FOR_TL_CHECKLIST.sql
-- PURPOSE: Master Database Implementation Checklist for Module FR6 & Section 7.9
-- TARGET:  Dedicated Dummy/Test Database: `n_logistic_dummy_db`
-- SCOPE:   Database Only | AI/ML Excluded | 28 Core Entities Preserved
-- ENGINE:  MySQL 8.0+ / MariaDB 10.4+ (Compatible with XAMPP & Production)
-- NOTICE:  This script is 100% self-contained. It creates `n_logistic_dummy_db`,
--          seeds realistic operational test data, creates all 10 analytics tables,
--          11 indexes, 16 views, 12 procedures, 7 triggers, and executes the
--          complete verification test suite without touching any production db.
-- =============================================================================

-- =============================================================================
-- STEP 0: CREATE AND SWITCH TO DEDICATED DUMMY DATABASE
-- =============================================================================
CREATE DATABASE IF NOT EXISTS `n_logistic_dummy_db` 
    DEFAULT CHARACTER SET utf8mb4 
    COLLATE utf8mb4_unicode_ci;

USE `n_logistic_dummy_db`;

-- Temporarily disable foreign key checks for safe idempotent initialization
SET @OLD_FOREIGN_KEY_CHECKS = @@FOREIGN_KEY_CHECKS;
SET FOREIGN_KEY_CHECKS = 0;

-- =============================================================================
-- STEP 1: PREREQUISITE OPERATIONAL CORE ENTITIES (28 CORE TABLES)
-- =============================================================================

-- 1. Companies (SRS 7.3 / ERD #3)
CREATE TABLE IF NOT EXISTS `companies` (
    `company_id` INT AUTO_INCREMENT PRIMARY KEY,
    `company_name` VARCHAR(150) NOT NULL,
    `company_type` ENUM('CONSUMER', 'SELLER') NOT NULL,
    `gst_number` VARCHAR(20) UNIQUE,
    `iec_code` VARCHAR(15) NULL,
    `address` TEXT NULL,
    `city` VARCHAR(60) NULL,
    `country` VARCHAR(60) NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 2. Users (SRS 7.3 / ERD #2)
CREATE TABLE IF NOT EXISTS `users` (
    `user_id` INT AUTO_INCREMENT PRIMARY KEY,
    `role` ENUM('ADMIN', 'CONSUMER', 'SELLER') NOT NULL,
    `company_id` INT NULL,
    `full_name` VARCHAR(100) NOT NULL,
    `email` VARCHAR(120) NOT NULL UNIQUE,
    `password_hash` VARCHAR(255) NOT NULL,
    `phone` VARCHAR(20) NULL,
    `status` ENUM('ACTIVE', 'INACTIVE', 'LOCKED') NOT NULL DEFAULT 'ACTIVE',
    `failed_attempts` INT NOT NULL DEFAULT 0,
    `last_login` DATETIME NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT `fk_dummy_users_company` FOREIGN KEY (`company_id`) REFERENCES `companies` (`company_id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 3. Customers (SRS 7.3 / ERD #5)
CREATE TABLE IF NOT EXISTS `customers` (
    `customer_id` INT AUTO_INCREMENT PRIMARY KEY,
    `user_id` INT NOT NULL UNIQUE,
    `company_id` INT NULL,
    `contact_person` VARCHAR(100) NULL,
    `billing_address` TEXT NULL,
    `credit_limit` DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT `fk_dummy_customers_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE,
    CONSTRAINT `fk_dummy_customers_company` FOREIGN KEY (`company_id`) REFERENCES `companies` (`company_id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 4. Audit Log (SRS 7.3 / ERD #1)
CREATE TABLE IF NOT EXISTS `audit_log` (
    `log_id` BIGINT AUTO_INCREMENT PRIMARY KEY,
    `user_id` INT NULL,
    `action` VARCHAR(100) NOT NULL,
    `table_name` VARCHAR(60) NULL,
    `record_id` BIGINT NULL,
    `old_value` LONGTEXT NULL,
    `new_value` LONGTEXT NULL,
    `ip_address` VARCHAR(45) NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT `fk_dummy_audit_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 5. Ports (SRS 7.4 / ERD #9)
CREATE TABLE IF NOT EXISTS `ports` (
    `port_id` INT AUTO_INCREMENT PRIMARY KEY,
    `port_code` VARCHAR(10) NOT NULL UNIQUE,
    `port_name` VARCHAR(100) NOT NULL,
    `city` VARCHAR(60) NULL,
    `country` VARCHAR(60) NULL,
    `latitude` DECIMAL(9, 6) NULL,
    `longitude` DECIMAL(9, 6) NULL,
    `is_active` TINYINT(1) NOT NULL DEFAULT 1,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 6. Vessels (SRS 7.4 / ERD #4)
CREATE TABLE IF NOT EXISTS `vessels` (
    `vessel_id` INT AUTO_INCREMENT PRIMARY KEY,
    `vessel_name` VARCHAR(100) NOT NULL,
    `imo_number` VARCHAR(15) UNIQUE NULL,
    `owner_company_id` INT NULL,
    `capacity_teu` INT NULL,
    `status` ENUM('ACTIVE', 'MAINTENANCE') NOT NULL DEFAULT 'ACTIVE',
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT `fk_dummy_vessels_company` FOREIGN KEY (`owner_company_id`) REFERENCES `companies` (`company_id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 7. Containers (SRS 7.4 / ERD #11)
CREATE TABLE IF NOT EXISTS `containers` (
    `container_id` INT AUTO_INCREMENT PRIMARY KEY,
    `container_number` VARCHAR(15) NOT NULL UNIQUE,
    `seller_id` INT NOT NULL,
    `container_type` ENUM('DRY', 'REEFER', 'OPEN_TOP', 'TANK') NOT NULL,
    `size_ft` TINYINT NOT NULL COMMENT '20 or 40',
    `max_weight_kg` DECIMAL(10, 2) NOT NULL,
    `max_volume_cbm` DECIMAL(8, 2) NOT NULL,
    `current_port_id` INT NULL,
    `status` ENUM('AVAILABLE', 'ALLOCATED', 'IN_TRANSIT', 'MAINTENANCE') NOT NULL DEFAULT 'AVAILABLE',
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT `fk_dummy_containers_seller` FOREIGN KEY (`seller_id`) REFERENCES `companies` (`company_id`) ON DELETE RESTRICT,
    CONSTRAINT `fk_dummy_containers_port` FOREIGN KEY (`current_port_id`) REFERENCES `ports` (`port_id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 8. Shipment (SRS 7.4 / ERD #14)
CREATE TABLE IF NOT EXISTS `shipment` (
    `shipment_id` INT AUTO_INCREMENT PRIMARY KEY,
    `shipment_no` VARCHAR(20) NOT NULL UNIQUE,
    `consumer_id` INT NOT NULL,
    `seller_id` INT NOT NULL,
    `container_id` INT NOT NULL,
    `vessel_id` INT NULL,
    `origin_port_id` INT NOT NULL,
    `dest_port_id` INT NOT NULL,
    `cargo_description` VARCHAR(255) NULL,
    `cargo_weight_kg` DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
    `cargo_volume_cbm` DECIMAL(8, 2) NOT NULL DEFAULT 0.00,
    `quoted_price` DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    `status` ENUM('BOOKED', 'LOADED', 'DEPARTED', 'IN_TRANSIT', 'ARRIVED', 'CUSTOMS_CLEARED', 'DELIVERED', 'CANCELLED') NOT NULL DEFAULT 'BOOKED',
    `booking_confirmed` TINYINT(1) NOT NULL DEFAULT 1,
    `etd` DATE NULL,
    `eta` DATE NULL,
    `actual_arrival` DATE NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT `fk_dummy_shipment_consumer` FOREIGN KEY (`consumer_id`) REFERENCES `customers` (`customer_id`) ON DELETE RESTRICT,
    CONSTRAINT `fk_dummy_shipment_seller` FOREIGN KEY (`seller_id`) REFERENCES `users` (`user_id`) ON DELETE RESTRICT,
    CONSTRAINT `fk_dummy_shipment_container` FOREIGN KEY (`container_id`) REFERENCES `containers` (`container_id`) ON DELETE RESTRICT,
    CONSTRAINT `fk_dummy_shipment_vessel` FOREIGN KEY (`vessel_id`) REFERENCES `vessels` (`vessel_id`) ON DELETE SET NULL,
    CONSTRAINT `fk_dummy_shipment_origin` FOREIGN KEY (`origin_port_id`) REFERENCES `ports` (`port_id`) ON DELETE RESTRICT,
    CONSTRAINT `fk_dummy_shipment_dest` FOREIGN KEY (`dest_port_id`) REFERENCES `ports` (`port_id`) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 9. Container Movements (SRS 7.4 / ERD #13)
CREATE TABLE IF NOT EXISTS `container_movements` (
    `movement_id` BIGINT AUTO_INCREMENT PRIMARY KEY,
    `shipment_id` INT NOT NULL,
    `container_id` INT NOT NULL,
    `status` ENUM('BOOKED', 'LOADED', 'DEPARTED', 'IN_TRANSIT', 'ARRIVED', 'CUSTOMS_CLEARED', 'DELIVERED', 'CANCELLED') NOT NULL,
    `port_id` INT NULL,
    `location_text` VARCHAR(150) NULL,
    `event_time` DATETIME NOT NULL,
    `remarks` VARCHAR(255) NULL,
    `updated_by` INT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT `fk_dummy_movement_shipment` FOREIGN KEY (`shipment_id`) REFERENCES `shipment` (`shipment_id`) ON DELETE CASCADE,
    CONSTRAINT `fk_dummy_movement_container` FOREIGN KEY (`container_id`) REFERENCES `containers` (`container_id`) ON DELETE CASCADE,
    CONSTRAINT `fk_dummy_movement_port` FOREIGN KEY (`port_id`) REFERENCES `ports` (`port_id`) ON DELETE SET NULL,
    CONSTRAINT `fk_dummy_movement_user` FOREIGN KEY (`updated_by`) REFERENCES `users` (`user_id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 10. Products (SRS 7.6 / ERD #24)
CREATE TABLE IF NOT EXISTS `products` (
    `product_id` INT AUTO_INCREMENT PRIMARY KEY,
    `sku` VARCHAR(40) NOT NULL UNIQUE,
    `product_name` VARCHAR(120) NOT NULL,
    `category` VARCHAR(60) NULL,
    `hs_code` VARCHAR(12) NULL,
    `unit` VARCHAR(10) NULL,
    `unit_weight_kg` DECIMAL(8, 3) NULL,
    `unit_volume_cbm` DECIMAL(10, 4) NOT NULL DEFAULT 0.0000,
    `unit_price` DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    `unit_cost` DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    `owner_company_id` INT NOT NULL,
    `is_active` TINYINT(1) NOT NULL DEFAULT 1,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT `fk_dummy_products_owner` FOREIGN KEY (`owner_company_id`) REFERENCES `companies` (`company_id`) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 11. Shipment Items (SRS 7.4 / ERD #18)
CREATE TABLE IF NOT EXISTS `shipment_items` (
    `item_id` INT AUTO_INCREMENT PRIMARY KEY,
    `shipment_id` INT NOT NULL,
    `product_id` INT NOT NULL,
    `quantity` INT NOT NULL,
    `unit_price` DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    `weight_kg` DECIMAL(10, 2) NULL,
    `volume_cbm` DECIMAL(8, 2) NULL,
    `amount` DECIMAL(14, 2) NOT NULL DEFAULT 0.00,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT `fk_dummy_items_shipment` FOREIGN KEY (`shipment_id`) REFERENCES `shipment` (`shipment_id`) ON DELETE CASCADE,
    CONSTRAINT `fk_dummy_items_product` FOREIGN KEY (`product_id`) REFERENCES `products` (`product_id`) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 12. Pricing Rules (SRS 7.5 / ERD #7)
CREATE TABLE IF NOT EXISTS `pricing_rules` (
    `rule_id` INT AUTO_INCREMENT PRIMARY KEY,
    `seller_id` INT NOT NULL,
    `origin_port_id` INT NOT NULL,
    `dest_port_id` INT NOT NULL,
    `container_type` ENUM('DRY', 'REEFER', 'OPEN_TOP', 'TANK') NOT NULL,
    `base_rate` DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    `rate_per_kg` DECIMAL(8, 4) NOT NULL DEFAULT 0.0000,
    `rate_per_cbm` DECIMAL(6, 2) NOT NULL DEFAULT 0.00,
    `season_multiplier` DECIMAL(4, 2) NOT NULL DEFAULT 1.00,
    `demand_multiplier` DECIMAL(4, 2) NOT NULL DEFAULT 1.00,
    `valid_from` DATE NOT NULL,
    `valid_to` DATE NOT NULL,
    `is_active` TINYINT(1) NOT NULL DEFAULT 1,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT `fk_dummy_pricing_seller` FOREIGN KEY (`seller_id`) REFERENCES `companies` (`company_id`) ON DELETE CASCADE,
    CONSTRAINT `fk_dummy_pricing_origin` FOREIGN KEY (`origin_port_id`) REFERENCES `ports` (`port_id`) ON DELETE RESTRICT,
    CONSTRAINT `fk_dummy_pricing_dest` FOREIGN KEY (`dest_port_id`) REFERENCES `ports` (`port_id`) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 13. Pricing Audit (SRS 7.5 / ERD #8)
CREATE TABLE IF NOT EXISTS `pricing_audit` (
    `audit_id` INT AUTO_INCREMENT PRIMARY KEY,
    `rule_id` INT NOT NULL,
    `old_rate` DECIMAL(12, 2) NULL,
    `new_rate` DECIMAL(12, 2) NULL,
    `old_multiplier` DECIMAL(4, 2) NULL,
    `new_multiplier` DECIMAL(4, 2) NULL,
    `changed_by` INT NULL,
    `changed_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT `fk_dummy_pricing_audit_rule` FOREIGN KEY (`rule_id`) REFERENCES `pricing_rules` (`rule_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 14. Stock (SRS 7.6 / ERD #21)
CREATE TABLE IF NOT EXISTS `stock` (
    `stock_id` INT AUTO_INCREMENT PRIMARY KEY,
    `product_id` INT NOT NULL,
    `shipment_id` INT NULL,
    `container_id` INT NULL,
    `quantity` INT NOT NULL DEFAULT 0,
    `damaged_qty` INT NOT NULL DEFAULT 0,
    `last_updated` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT `fk_dummy_stock_product` FOREIGN KEY (`product_id`) REFERENCES `products` (`product_id`) ON DELETE CASCADE,
    CONSTRAINT `chk_dummy_stock_qty` CHECK (`quantity` >= 0),
    CONSTRAINT `chk_dummy_stock_damaged` CHECK (`damaged_qty` >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 15. Inventory Ledger (SRS 7.6 / ERD #23)
CREATE TABLE IF NOT EXISTS `inventory_ledger` (
    `ledger_id` BIGINT AUTO_INCREMENT PRIMARY KEY,
    `stock_id` INT NOT NULL,
    `product_id` INT NOT NULL,
    `txn_type` ENUM('IN', 'OUT', 'DAMAGE', 'ADJUST', 'CLAIM_LOSS') NOT NULL,
    `quantity` INT NOT NULL,
    `balance_after` INT NOT NULL,
    `reference_type` VARCHAR(30) NULL,
    `reference_id` BIGINT NULL,
    `txn_time` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT `fk_dummy_ledger_stock` FOREIGN KEY (`stock_id`) REFERENCES `stock` (`stock_id`) ON DELETE CASCADE,
    CONSTRAINT `fk_dummy_ledger_product` FOREIGN KEY (`product_id`) REFERENCES `products` (`product_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 16. Sales Transactions (SRS 7.6 / ERD #22)
CREATE TABLE IF NOT EXISTS `sales_transactions` (
    `sale_id` BIGINT AUTO_INCREMENT PRIMARY KEY,
    `product_id` INT NOT NULL,
    `customer_id` INT NOT NULL,
    `shipment_id` INT NULL,
    `quantity` INT NOT NULL,
    `unit_price` DECIMAL(12, 2) NOT NULL,
    `total_amount` DECIMAL(14, 2) NOT NULL,
    `sale_date` DATE NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT `fk_dummy_sales_product` FOREIGN KEY (`product_id`) REFERENCES `products` (`product_id`) ON DELETE RESTRICT,
    CONSTRAINT `fk_dummy_sales_customer` FOREIGN KEY (`customer_id`) REFERENCES `customers` (`customer_id`) ON DELETE RESTRICT,
    CONSTRAINT `fk_dummy_sales_shipment` FOREIGN KEY (`shipment_id`) REFERENCES `shipment` (`shipment_id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 17. Billing Invoices (SRS 7.7 / ERD #16)
CREATE TABLE IF NOT EXISTS `billing_invoices` (
    `invoice_id` INT AUTO_INCREMENT PRIMARY KEY,
    `invoice_no` VARCHAR(25) NOT NULL UNIQUE,
    `shipment_id` INT NOT NULL,
    `consumer_id` INT NOT NULL,
    `seller_id` INT NOT NULL,
    `sub_total` DECIMAL(14, 2) NOT NULL DEFAULT 0.00,
    `tax_amount` DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    `total_amount` DECIMAL(14, 2) NOT NULL DEFAULT 0.00,
    `paid_amount` DECIMAL(14, 2) NOT NULL DEFAULT 0.00,
    `status` ENUM('UNPAID', 'PARTIAL', 'PAID', 'OVERDUE') NOT NULL DEFAULT 'UNPAID',
    `issue_date` DATE NOT NULL,
    `due_date` DATE NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT `fk_dummy_invoice_shipment` FOREIGN KEY (`shipment_id`) REFERENCES `shipment` (`shipment_id`) ON DELETE RESTRICT,
    CONSTRAINT `fk_dummy_invoice_consumer` FOREIGN KEY (`consumer_id`) REFERENCES `customers` (`customer_id`) ON DELETE RESTRICT,
    CONSTRAINT `fk_dummy_invoice_seller` FOREIGN KEY (`seller_id`) REFERENCES `companies` (`company_id`) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 18. Invoice Line Items (SRS 7.7 / ERD #17)
CREATE TABLE IF NOT EXISTS `invoice_line_items` (
    `item_id` INT AUTO_INCREMENT PRIMARY KEY,
    `invoice_id` INT NOT NULL,
    `item_type` ENUM('FREIGHT', 'HANDLING', 'PORT', 'CUSTOMS', 'TAX', 'OTHER') NOT NULL,
    `description` VARCHAR(255) NOT NULL,
    `quantity` INT NOT NULL DEFAULT 1,
    `unit_price` DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    `amount` DECIMAL(14, 2) NOT NULL DEFAULT 0.00,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT `fk_dummy_line_invoice` FOREIGN KEY (`invoice_id`) REFERENCES `billing_invoices` (`invoice_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 19. Payments (SRS 7.7 / ERD #19)
CREATE TABLE IF NOT EXISTS `payments` (
    `payment_id` INT AUTO_INCREMENT PRIMARY KEY,
    `invoice_id` INT NOT NULL,
    `amount` DECIMAL(14, 2) NOT NULL,
    `payment_mode` ENUM('BANK_TRANSFER', 'CREDIT_CARD', 'LETTER_OF_CREDIT') NOT NULL,
    `reference_no` VARCHAR(60) NULL,
    `payment_date` DATE NOT NULL,
    `recorded_by` INT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT `fk_dummy_payment_invoice` FOREIGN KEY (`invoice_id`) REFERENCES `billing_invoices` (`invoice_id`) ON DELETE RESTRICT,
    CONSTRAINT `fk_dummy_payment_user` FOREIGN KEY (`recorded_by`) REFERENCES `users` (`user_id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 20. Claims (SRS 7.8 / ERD #20)
CREATE TABLE IF NOT EXISTS `claims` (
    `claim_id` INT AUTO_INCREMENT PRIMARY KEY,
    `claim_no` VARCHAR(20) NOT NULL UNIQUE,
    `shipment_id` INT NOT NULL,
    `container_id` INT NULL,
    `consumer_id` INT NOT NULL,
    `claim_type` ENUM('LOSS', 'DAMAGE', 'DELAY', 'SHORTAGE') NOT NULL,
    `description` TEXT NOT NULL,
    `claimed_amount` DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    `approved_amount` DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    `status` ENUM('SUBMITTED', 'UNDER_REVIEW', 'APPROVED', 'PARTIALLY_APPROVED', 'REJECTED', 'SETTLED') NOT NULL DEFAULT 'SUBMITTED',
    `seller_remarks` VARCHAR(255) NULL,
    `raised_at` DATETIME NULL,
    `settled_at` DATETIME NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT `fk_dummy_claim_shipment` FOREIGN KEY (`shipment_id`) REFERENCES `shipment` (`shipment_id`) ON DELETE RESTRICT,
    CONSTRAINT `fk_dummy_claim_consumer` FOREIGN KEY (`consumer_id`) REFERENCES `customers` (`customer_id`) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 21. Claim Documents (SRS 7.8 / ERD #25)
CREATE TABLE IF NOT EXISTS `claim_documents` (
    `doc_id` INT AUTO_INCREMENT PRIMARY KEY,
    `claim_id` INT NOT NULL,
    `file_path` VARCHAR(255) NOT NULL,
    `file_type` VARCHAR(50) NULL,
    `uploaded_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT `fk_dummy_claim_doc` FOREIGN KEY (`claim_id`) REFERENCES `claims` (`claim_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 22. Claim Status History (SRS 7.8)
CREATE TABLE IF NOT EXISTS `claim_status_history` (
    `history_id` BIGINT AUTO_INCREMENT PRIMARY KEY,
    `claim_id` INT NOT NULL,
    `old_status` VARCHAR(20) NULL,
    `new_status` VARCHAR(20) NULL,
    `changed_by` INT NULL,
    `remarks` VARCHAR(255) NULL,
    `changed_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT `fk_dummy_claim_hist` FOREIGN KEY (`claim_id`) REFERENCES `claims` (`claim_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 23. Shipment Costs (Checklist Query 7.10)
CREATE TABLE IF NOT EXISTS `shipment_costs` (
    `cost_id` BIGINT AUTO_INCREMENT PRIMARY KEY,
    `shipment_id` INT NOT NULL,
    `cost_type` ENUM('FREIGHT', 'PORT', 'HANDLING', 'CUSTOMS', 'INSURANCE', 'OTHER') NOT NULL,
    `amount` DECIMAL(14, 2) NOT NULL DEFAULT 0.00,
    `description` VARCHAR(255) NULL,
    `cost_date` DATE NOT NULL,
    `recorded_by` INT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT `fk_dummy_sc_shipment` FOREIGN KEY (`shipment_id`) REFERENCES `shipment`(`shipment_id`) ON DELETE CASCADE,
    INDEX `idx_dummy_sc_shipment_type` (`shipment_id`, `cost_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 24. Shipment Stock Reservations (FR4.7 Trigger Support)
CREATE TABLE IF NOT EXISTS `shipment_stock_reservations` (
    `reservation_id` BIGINT AUTO_INCREMENT PRIMARY KEY,
    `shipment_id` INT NOT NULL,
    `product_id` INT NOT NULL,
    `reserved_quantity` INT NOT NULL,
    `status` ENUM('RESERVED','CONSUMED','RELEASED') NOT NULL DEFAULT 'RESERVED',
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_dummy_res_shipment` (`shipment_id`),
    INDEX `idx_dummy_res_product` (`product_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 25. Tax Rates (Supporting Table)
CREATE TABLE IF NOT EXISTS `tax_rates` (
    `tax_id` INT AUTO_INCREMENT PRIMARY KEY,
    `tax_name` VARCHAR(50) NOT NULL,
    `rate_pct` DECIMAL(5, 2) NOT NULL,
    `is_active` TINYINT(1) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 26. System Settings (Supporting Table)
CREATE TABLE IF NOT EXISTS `system_settings` (
    `setting_key` VARCHAR(50) PRIMARY KEY,
    `setting_value` VARCHAR(255) NOT NULL,
    `description` VARCHAR(255) NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 27. Claim Comments (Supporting Table)
CREATE TABLE IF NOT EXISTS `claim_comments` (
    `comment_id` INT AUTO_INCREMENT PRIMARY KEY,
    `claim_id` INT NOT NULL,
    `user_id` INT NOT NULL,
    `comment_text` TEXT NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 28. Demand Forecast (ERD #8 / SRS Section 7.5 for FR6.6)
CREATE TABLE IF NOT EXISTS `demand_forecast` (
    `forecast_id` INT AUTO_INCREMENT PRIMARY KEY,
    `origin_port_id` INT NOT NULL,
    `dest_port_id` INT NOT NULL,
    `container_type` ENUM('DRY', 'REEFER', 'OPEN_TOP', 'TANK') NOT NULL,
    `forecast_month` DATE NOT NULL,
    `predicted_bookings` INT NOT NULL DEFAULT 0,
    `confidence_pct` DECIMAL(5, 2) NOT NULL DEFAULT 0.00,
    `suggested_multiplier` DECIMAL(4, 2) NOT NULL DEFAULT 1.00,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT `fk_dummy_df_orig_port` FOREIGN KEY (`origin_port_id`) REFERENCES `ports`(`port_id`) ON DELETE CASCADE,
    CONSTRAINT `fk_dummy_df_dest_port` FOREIGN KEY (`dest_port_id`) REFERENCES `ports`(`port_id`) ON DELETE CASCADE,
    CONSTRAINT `chk_dummy_df_confidence` CHECK (`confidence_pct` BETWEEN 0.00 AND 100.00),
    CONSTRAINT `chk_dummy_df_bookings` CHECK (`predicted_bookings` >= 0),
    CONSTRAINT `chk_dummy_df_mult` CHECK (`suggested_multiplier` > 0.00),
    UNIQUE KEY `uq_dummy_demand_forecast_route` (`origin_port_id`, `dest_port_id`, `container_type`, `forecast_month`),
    INDEX `idx_dummy_df_lookup` (`origin_port_id`, `dest_port_id`, `forecast_month`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- =============================================================================
-- STEP 2: REALISTIC DUMMY OPERATIONAL SEED DATA
-- =============================================================================

-- 1. Ports
INSERT INTO `ports` (`port_id`, `port_code`, `port_name`, `city`, `country`, `latitude`, `longitude`, `is_active`) VALUES
(1, 'INNSA', 'Jawaharlal Nehru Port (Nhava Sheva)', 'Navi Mumbai', 'India', 18.9499, 72.9511, 1),
(2, 'AEJEA', 'Jebel Ali Port', 'Dubai', 'United Arab Emirates', 25.0069, 55.0600, 1),
(3, 'SGSIN', 'Port of Singapore', 'Singapore', 'Singapore', 1.2644, 103.8398, 1),
(4, 'NLRTM', 'Port of Rotterdam', 'Rotterdam', 'Netherlands', 51.9054, 4.4666, 1),
(5, 'CNSHG', 'Port of Shanghai', 'Shanghai', 'China', 31.2304, 121.4737, 1)
ON DUPLICATE KEY UPDATE `port_name` = VALUES(`port_name`);

-- 2. Companies
INSERT INTO `companies` (`company_id`, `company_name`, `company_type`, `gst_number`, `iec_code`, `address`, `city`, `country`) VALUES
(1, 'Apex Global Logistics Ltd', 'SELLER', '27AAACA1234A1Z5', '0301002345', 'Plot 42, Port Industrial Estate', 'Navi Mumbai', 'India'),
(2, 'Maritime Blue Ocean Exporters', 'SELLER', '24AAACB5678B1Z6', '0402008765', 'Wharf Road, Kandla Port Area', 'Gandhidham', 'India'),
(3, 'EuroAsia Retail Imports BV', 'CONSUMER', 'NL894726190B01', 'NL12345678', 'Keizersgracht 450', 'Amsterdam', 'Netherlands'),
(4, 'Gulf Traders LLC', 'CONSUMER', 'AE1002938475001', 'AE98765432', 'Al Mina Street, Deira', 'Dubai', 'United Arab Emirates'),
(5, 'Pacific Horizon Consumer Goods', 'CONSUMER', 'SG201938472M', 'SG11223344', '10 Marina Boulevard', 'Singapore', 'Singapore')
ON DUPLICATE KEY UPDATE `company_name` = VALUES(`company_name`);

-- 3. Users
INSERT INTO `users` (`user_id`, `role`, `company_id`, `full_name`, `email`, `password_hash`, `phone`, `status`) VALUES
(1, 'ADMIN', NULL, 'System Administrator', 'admin@nlogistic.com', '$2a$10$abcdefghijklmnopqrstuv', '+919800000001', 'ACTIVE'),
(2, 'SELLER', 1, 'Rajesh Sharma (Apex Global)', 'rajesh@apexlogistics.com', '$2a$10$abcdefghijklmnopqrstuv', '+919800000002', 'ACTIVE'),
(3, 'SELLER', 2, 'Karan Patel (Maritime Blue)', 'karan@maritimeblue.com', '$2a$10$abcdefghijklmnopqrstuv', '+919800000003', 'ACTIVE'),
(4, 'CONSUMER', 3, 'Jan van Dijk (EuroAsia)', 'jan@euroasia.nl', '$2a$10$abcdefghijklmnopqrstuv', '+31201234567', 'ACTIVE'),
(5, 'CONSUMER', 4, 'Ahmed Al-Maktoum (Gulf Traders)', 'ahmed@gulftraders.ae', '$2a$10$abcdefghijklmnopqrstuv', '+97142345678', 'ACTIVE')
ON DUPLICATE KEY UPDATE `full_name` = VALUES(`full_name`);

-- 4. Customers
INSERT INTO `customers` (`customer_id`, `user_id`, `company_id`, `contact_person`, `billing_address`, `credit_limit`) VALUES
(1, 4, 3, 'Jan van Dijk', 'Keizersgracht 450, Amsterdam, Netherlands', 500000.00),
(2, 5, 4, 'Ahmed Al-Maktoum', 'Al Mina Street, Deira, Dubai, UAE', 750000.00)
ON DUPLICATE KEY UPDATE `contact_person` = VALUES(`contact_person`);

-- 5. Vessels
INSERT INTO `vessels` (`vessel_id`, `vessel_name`, `imo_number`, `owner_company_id`, `capacity_teu`, `status`) VALUES
(1, 'MV Ocean Pioneer', 'IMO9123456', 1, 4500, 'ACTIVE'),
(2, 'MV Northern Star', 'IMO9234567', 1, 6000, 'ACTIVE'),
(3, 'MV Arabian Express', 'IMO9345678', 2, 3800, 'ACTIVE')
ON DUPLICATE KEY UPDATE `vessel_name` = VALUES(`vessel_name`);

-- 6. Containers
INSERT INTO `containers` (`container_id`, `container_number`, `seller_id`, `container_type`, `size_ft`, `max_weight_kg`, `max_volume_cbm`, `current_port_id`, `status`) VALUES
(1, 'APXU1234567', 1, 'DRY', 20, 24000.00, 33.20, 1, 'IN_TRANSIT'),
(2, 'APXU2345678', 1, 'REEFER', 40, 30480.00, 67.50, 1, 'IN_TRANSIT'),
(3, 'APXU3456789', 1, 'DRY', 40, 30480.00, 67.70, 2, 'AVAILABLE'),
(4, 'MBLU4567890', 2, 'OPEN_TOP', 20, 24000.00, 32.00, 3, 'AVAILABLE'),
(5, 'MBLU5678901', 2, 'TANK', 20, 26000.00, 26.00, 4, 'AVAILABLE'),
(6, 'MBLU6789012', 2, 'DRY', 40, 30480.00, 67.70, 1, 'AVAILABLE')
ON DUPLICATE KEY UPDATE `status` = VALUES(`status`);

-- 7. Products (With actual unit_cost per Checklist Section 4.7)
INSERT INTO `products` (`product_id`, `sku`, `product_name`, `category`, `hs_code`, `unit`, `unit_weight_kg`, `unit_volume_cbm`, `unit_price`, `unit_cost`, `owner_company_id`, `is_active`) VALUES
(1, 'TEX-COT-001', 'Premium Cotton Textiles', 'Textiles', '5208.11', 'bale', 25.000, 0.4500, 12000.00, 7800.00, 1, 1),
(2, 'SPICE-PEP-002', 'Organic Black Pepper', 'Agricultural Spices', '0904.11', 'kg', 1.000, 0.0200, 850.00, 552.50, 1, 1),
(3, 'TEA-DAR-003', 'Darjeeling First Flush Tea', 'Beverages', '0902.10', 'box', 10.000, 0.1750, 5400.00, 3510.00, 1, 1),
(4, 'ENG-STL-004', 'Precision Steel Bearings', 'Industrial Machinery', '8482.10', 'crate', 15.000, 0.0933, 3200.00, 2080.00, 2, 1),
(5, 'MED-API-005', 'Active Pharma Ingredients', 'Pharmaceuticals', '2933.39', 'drum', 15.000, 0.1800, 45000.00, 29250.00, 2, 1),
(6, 'AUTO-RAD-006', 'Automotive Radiators', 'Automotive', '8708.91', 'unit', 10.000, 0.1200, 6500.00, 4225.00, 2, 1)
ON DUPLICATE KEY UPDATE `unit_price` = VALUES(`unit_price`), `unit_cost` = VALUES(`unit_cost`);

-- 8. Stock
INSERT INTO `stock` (`stock_id`, `product_id`, `shipment_id`, `container_id`, `quantity`, `damaged_qty`) VALUES
(1, 1, 1, 1, 500, 5),
(2, 2, 2, 2, 3000, 20),
(3, 3, 3, 3, 800, 0),
(4, 4, 4, 4, 1200, 10),
(5, 5, 5, 5, 400, 0),
(6, 6, 6, 6, 650, 2)
ON DUPLICATE KEY UPDATE `quantity` = VALUES(`quantity`);

-- 9. Inventory Ledger
INSERT INTO `inventory_ledger` (`ledger_id`, `stock_id`, `product_id`, `txn_type`, `quantity`, `balance_after`, `reference_type`, `reference_id`, `txn_time`) VALUES
(1, 1, 1, 'IN', 600, 600, 'UPLOAD', 101, '2026-08-01 09:00:00'),
(2, 1, 1, 'OUT', 100, 500, 'SHIPMENT', 1, '2026-08-15 14:00:00'),
(3, 2, 2, 'IN', 4000, 4000, 'UPLOAD', 102, '2026-08-01 09:30:00'),
(4, 2, 2, 'OUT', 1000, 3000, 'SHIPMENT', 2, '2026-09-02 11:00:00'),
(5, 3, 3, 'IN', 1000, 1000, 'UPLOAD', 103, '2026-09-01 10:00:00'),
(6, 3, 3, 'OUT', 200, 800, 'SHIPMENT', 3, '2026-09-18 16:30:00'),
(7, 4, 4, 'IN', 1500, 1500, 'UPLOAD', 104, '2026-09-15 09:00:00'),
(8, 4, 4, 'OUT', 300, 1200, 'SHIPMENT', 4, '2026-10-18 10:00:00'),
(9, 5, 5, 'IN', 500, 500, 'UPLOAD', 105, '2026-10-01 11:00:00'),
(10, 5, 5, 'OUT', 100, 400, 'SHIPMENT', 5, '2026-10-28 14:00:00'),
(11, 6, 6, 'IN', 650, 650, 'UPLOAD', 106, '2026-10-10 15:00:00'),
(12, 1, 1, 'OUT', 50, 450, 'SHIPMENT', 1, '2026-10-20 12:00:00')
ON DUPLICATE KEY UPDATE `quantity` = VALUES(`quantity`);

-- 10. Pricing Rules
INSERT INTO `pricing_rules` (`rule_id`, `seller_id`, `origin_port_id`, `dest_port_id`, `container_type`, `base_rate`, `rate_per_kg`, `rate_per_cbm`, `season_multiplier`, `demand_multiplier`, `valid_from`, `valid_to`, `is_active`) VALUES
(1, 1, 1, 2, 'DRY', 120000.00, 2.5000, 45.00, 1.05, 1.10, '2026-01-01', '2026-12-31', 1),
(2, 1, 1, 2, 'REEFER', 118000.00, 3.8000, 65.00, 1.10, 1.15, '2026-01-01', '2026-12-31', 1),
(3, 1, 1, 4, 'DRY', 280000.00, 3.0000, 55.00, 1.00, 1.05, '2026-01-01', '2026-12-31', 1),
(4, 2, 1, 2, 'OPEN_TOP', 118000.00, 4.0000, 70.00, 1.15, 1.20, '2026-01-01', '2026-12-31', 1),
(5, 2, 1, 3, 'TANK', 145000.00, 5.0000, 85.00, 1.00, 1.00, '2026-01-01', '2026-12-31', 1),
(6, 2, 1, 4, 'DRY', 275000.00, 3.2000, 58.00, 1.00, 1.00, '2026-01-01', '2026-12-31', 1)
ON DUPLICATE KEY UPDATE `base_rate` = VALUES(`base_rate`);

-- 11. Shipments
INSERT INTO `shipment` (`shipment_id`, `shipment_no`, `consumer_id`, `seller_id`, `container_id`, `vessel_id`, `origin_port_id`, `dest_port_id`, `cargo_description`, `cargo_weight_kg`, `cargo_volume_cbm`, `quoted_price`, `status`, `etd`, `eta`, `actual_arrival`) VALUES
(1, 'SHP-2026-0001', 2, 1, 1, 1, 1, 2, 'Cotton Textiles Export to Jebel Ali', 2500.00, 45.00, 165000.00, 'IN_TRANSIT', '2026-11-05', '2026-11-18', NULL),
(2, 'SHP-2026-0002', 2, 1, 2, 1, 1, 2, 'Organic Black Pepper to Dubai', 1000.00, 20.00, 140000.00, 'IN_TRANSIT', '2026-11-08', '2026-11-20', NULL),
(3, 'SHP-2026-0003', 1, 1, 3, 2, 1, 4, 'Premium Darjeeling Tea to Rotterdam', 2000.00, 35.00, 310000.00, 'ARRIVED', '2026-10-15', '2026-11-10', '2026-11-11'),
(4, 'SHP-2026-0004', 1, 1, 3, 2, 1, 4, 'Industrial Steel Bearings to EuroAsia', 4500.00, 28.00, 340000.00, 'DELIVERED', '2026-10-01', '2026-10-25', '2026-10-24'),
(5, 'SHP-2026-0005', 2, 2, 4, 3, 1, 2, 'Bulk Pharma Ingredients to UAE', 1500.00, 18.00, 195000.00, 'BOOKED', '2026-11-25', '2026-12-05', NULL),
(6, 'SHP-2026-0006', 2, 2, 5, 3, 1, 3, 'Automotive Radiators to Singapore', 1500.00, 18.00, 220000.00, 'LOADED', '2026-11-15', '2026-11-28', NULL)
ON DUPLICATE KEY UPDATE `status` = VALUES(`status`);

-- 12. Shipment Items
INSERT INTO `shipment_items` (`item_id`, `shipment_id`, `product_id`, `quantity`, `unit_price`, `weight_kg`, `volume_cbm`, `amount`) VALUES
(1, 1, 1, 100, 12000.00, 2500.00, 45.00, 1200000.00),
(2, 2, 2, 1000, 850.00, 1000.00, 20.00, 850000.00),
(3, 3, 3, 200, 5400.00, 2000.00, 35.00, 1080000.00),
(4, 4, 4, 300, 3200.00, 4500.00, 28.00, 960000.00),
(5, 5, 5, 100, 45000.00, 1500.00, 18.00, 4500000.00),
(6, 6, 6, 150, 6500.00, 1500.00, 18.00, 975000.00)
ON DUPLICATE KEY UPDATE `quantity` = VALUES(`quantity`);

-- 13. Shipment Costs (Checklist Query 7.10)
INSERT INTO `shipment_costs` (`shipment_id`, `cost_type`, `amount`, `description`, `cost_date`, `recorded_by`) VALUES
(1, 'FREIGHT', 119000.00, 'Ocean Freight Mumbai to Jebel Ali', '2026-11-05', 1),
(1, 'PORT', 5000.00, 'Port dues and terminal tariff', '2026-11-05', 1),
(1, 'HANDLING', 3500.00, 'Stevedoring and container handling', '2026-11-05', 1),
(2, 'FREIGHT', 119000.00, 'Ocean Freight Mumbai to Jebel Ali', '2026-11-08', 1),
(2, 'PORT', 5000.00, 'Port dues and terminal tariff', '2026-11-08', 1),
(2, 'HANDLING', 3500.00, 'Stevedoring and container handling', '2026-11-08', 1),
(3, 'FREIGHT', 280000.00, 'Ocean Freight Mumbai to Rotterdam', '2026-10-15', 1),
(3, 'PORT', 5000.00, 'Port dues and terminal tariff', '2026-10-15', 1),
(3, 'HANDLING', 3500.00, 'Stevedoring and container handling', '2026-10-15', 1),
(4, 'FREIGHT', 280000.00, 'Ocean Freight Mumbai to Rotterdam', '2026-10-01', 1),
(4, 'PORT', 5000.00, 'Port dues and terminal tariff', '2026-10-01', 1),
(4, 'HANDLING', 3500.00, 'Stevedoring and container handling', '2026-10-01', 1),
(5, 'FREIGHT', 119000.00, 'Ocean Freight Mumbai to Jebel Ali', '2026-11-25', 2),
(5, 'PORT', 5000.00, 'Port dues and terminal tariff', '2026-11-25', 2),
(5, 'HANDLING', 3500.00, 'Stevedoring and container handling', '2026-11-25', 2),
(6, 'FREIGHT', 145000.00, 'Ocean Freight Mumbai to Singapore', '2026-11-15', 2),
(6, 'PORT', 5000.00, 'Port dues and terminal tariff', '2026-11-15', 2),
(6, 'HANDLING', 3500.00, 'Stevedoring and container handling', '2026-11-15', 2)
ON DUPLICATE KEY UPDATE `amount` = VALUES(`amount`);

-- 14. Sales Transactions
INSERT INTO `sales_transactions` (`sale_id`, `product_id`, `customer_id`, `shipment_id`, `quantity`, `unit_price`, `total_amount`, `sale_date`) VALUES
(1, 1, 2, 1, 100, 12000.00, 1200000.00, '2026-08-10'),
(2, 2, 2, 2, 1000, 850.00, 850000.00, '2026-09-01'),
(3, 3, 1, 3, 200, 5400.00, 1080000.00, '2026-09-15'),
(4, 4, 1, 4, 300, 3200.00, 960000.00, '2026-10-15'),
(5, 5, 2, 5, 100, 45000.00, 4500000.00, '2026-10-25'),
(6, 6, 2, 6, 150, 6500.00, 975000.00, '2026-11-05'),
(7, 1, 1, 1, 50, 12000.00, 600000.00, '2026-10-10')
ON DUPLICATE KEY UPDATE `total_amount` = VALUES(`total_amount`);

-- 15. Billing Invoices
INSERT INTO `billing_invoices` (`invoice_id`, `invoice_no`, `shipment_id`, `consumer_id`, `seller_id`, `sub_total`, `tax_amount`, `total_amount`, `paid_amount`, `status`, `issue_date`, `due_date`) VALUES
(1, 'INV-2026-0001', 1, 2, 1, 165000.00, 29700.00, 194700.00, 194700.00, 'PAID', '2026-11-05', '2026-12-05'),
(2, 'INV-2026-0002', 2, 2, 1, 140000.00, 25200.00, 165200.00, 165200.00, 'PAID', '2026-11-08', '2026-12-08'),
(3, 'INV-2026-0003', 3, 1, 1, 310000.00, 55800.00, 365800.00, 200000.00, 'PARTIAL', '2026-10-15', '2026-11-15'),
(4, 'INV-2026-0004', 4, 1, 1, 340000.00, 61200.00, 401200.00, 365800.00, 'PARTIAL', '2026-10-01', '2026-11-01'),
(5, 'INV-2026-0005', 5, 2, 2, 195000.00, 35100.00, 230100.00, 0.00, 'UNPAID', '2026-11-25', '2026-12-25'),
(6, 'INV-2026-0006', 6, 2, 2, 220000.00, 39600.00, 259600.00, 0.00, 'UNPAID', '2026-11-15', '2026-12-15')
ON DUPLICATE KEY UPDATE `paid_amount` = VALUES(`paid_amount`), `status` = VALUES(`status`);

-- 16. Invoice Line Items
INSERT INTO `invoice_line_items` (`item_id`, `invoice_id`, `item_type`, `description`, `quantity`, `unit_price`, `amount`) VALUES
(1, 1, 'FREIGHT', 'Ocean Freight Mumbai to Jebel Ali', 1, 120000.00, 120000.00),
(2, 1, 'PORT', 'Origin & Destination Port Dues', 1, 25000.00, 25000.00),
(3, 1, 'HANDLING', 'Terminal Handling & Stevedoring Charges', 1, 20000.00, 20000.00),
(4, 2, 'FREIGHT', 'Ocean Freight Mumbai to Jebel Ali (Reefer)', 1, 100000.00, 100000.00),
(5, 3, 'FREIGHT', 'Ocean Freight Mumbai to Rotterdam', 1, 240000.00, 240000.00)
ON DUPLICATE KEY UPDATE `amount` = VALUES(`amount`);

-- 17. Payments
INSERT INTO `payments` (`payment_id`, `invoice_id`, `amount`, `payment_mode`, `reference_no`, `payment_date`, `recorded_by`) VALUES
(1, 1, 194700.00, 'LETTER_OF_CREDIT', 'LC-GULF-2026-001', '2026-11-06', 1),
(2, 2, 165200.00, 'BANK_TRANSFER', 'NEFT202611080012', '2026-11-09', 1),
(3, 3, 200000.00, 'BANK_TRANSFER', 'SWIFT20261016NL', '2026-10-16', 1),
(4, 4, 365800.00, 'BANK_TRANSFER', 'SWIFT20261002NL', '2026-10-02', 1)
ON DUPLICATE KEY UPDATE `amount` = VALUES(`amount`);

-- 18. Claims
INSERT INTO `claims` (`claim_id`, `claim_no`, `shipment_id`, `container_id`, `consumer_id`, `claim_type`, `description`, `claimed_amount`, `approved_amount`, `status`, `seller_remarks`, `raised_at`, `settled_at`) VALUES
(1, 'CLM-2026-0001', 1, 1, 2, 'DAMAGE', 'Water ingress damage to cotton textile bales', 45000.00, 45000.00, 'SETTLED', 'Surveyor confirmed seal integrity breach; approved for full settlement', '2026-11-10 10:30:00', '2026-11-12 16:00:00'),
(2, 'CLM-2026-0002', 3, 3, 1, 'DELAY', 'Perishable packaging damage due to 1-day port congestion delay', 20000.00, 20000.00, 'APPROVED', 'Delay verified via AIS carrier tracking; 100% claim approved', '2026-11-12 11:00:00', NULL),
(3, 'CLM-2026-0003', 2, 2, 2, 'SHORTAGE', '1 carton short upon deconsolidation at Jebel Ali CFS', 8500.00, 0.00, 'UNDER_REVIEW', 'Awaiting tally report from CFS operator', '2026-11-13 14:00:00', NULL)
ON DUPLICATE KEY UPDATE `status` = VALUES(`status`), `approved_amount` = VALUES(`approved_amount`);

-- 19. Claim Status History
INSERT INTO `claim_status_history` (`history_id`, `claim_id`, `old_status`, `new_status`, `changed_by`, `remarks`, `changed_at`) VALUES
(1, 1, 'SUBMITTED', 'UNDER_REVIEW', 1, 'Investigation initiated with surveyor', '2026-11-10 11:00:00'),
(2, 1, 'UNDER_REVIEW', 'APPROVED', 1, 'Survey report verified damage', '2026-11-11 15:00:00'),
(3, 1, 'APPROVED', 'SETTLED', 1, 'Settlement payment issued to consumer', '2026-11-12 16:00:00'),
(4, 2, 'SUBMITTED', 'APPROVED', 1, 'Carrier port delay confirmed', '2026-11-12 14:00:00')
ON DUPLICATE KEY UPDATE `remarks` = VALUES(`remarks`);

-- 20. Container Movements
INSERT INTO `container_movements` (`movement_id`, `shipment_id`, `container_id`, `status`, `port_id`, `location_text`, `event_time`, `remarks`, `updated_by`) VALUES
(1, 1, 1, 'BOOKED', 1, 'Nhava Sheva CFS Yard A', '2026-11-01 08:00:00', 'Container allocated and stuffed', 2),
(2, 1, 1, 'LOADED', 1, 'Nhava Sheva Terminal 2', '2026-11-04 18:00:00', 'Loaded onto MV Ocean Pioneer', 2),
(3, 1, 1, 'DEPARTED', 1, 'En route Arabian Sea', '2026-11-05 06:00:00', 'Vessel departed Nhava Sheva', 1),
(4, 1, 1, 'IN_TRANSIT', NULL, 'Arabian Sea - Lat 19.5, Lon 65.2', '2026-11-08 12:00:00', 'AIS satellite fix confirmed normal cruise', 1),
(5, 2, 2, 'DEPARTED', 1, 'Nhava Sheva', '2026-11-08 09:00:00', 'Departed on MV Ocean Pioneer', 2),
(6, 3, 3, 'ARRIVED', 4, 'Port of Rotterdam', '2026-11-11 10:00:00', 'Vessel berthed at ECT Delta Terminal', 1),
(7, 4, 3, 'DELIVERED', 4, 'EuroAsia Warehouse Amsterdam', '2026-10-24 16:00:00', 'Consignee signed Proof of Delivery', 1)
ON DUPLICATE KEY UPDATE `remarks` = VALUES(`remarks`);

-- 21. Demand Forecast Baseline
INSERT INTO `demand_forecast` (`origin_port_id`, `dest_port_id`, `container_type`, `forecast_month`, `predicted_bookings`, `confidence_pct`, `suggested_multiplier`) VALUES
(1, 2, 'DRY', '2026-12-01', 5, 88.00, 1.05),
(1, 4, 'REEFER', '2026-12-01', 3, 65.00, 0.98),
(1, 4, 'OPEN_TOP', '2026-12-01', 3, 65.00, 0.98),
(1, 3, 'REEFER', '2026-12-01', 3, 65.00, 0.98)
ON DUPLICATE KEY UPDATE `predicted_bookings` = VALUES(`predicted_bookings`);


-- =============================================================================
-- STEP 3: ANALYTICS SCHEMAS & TABLES (10 RESULT TABLES + SUPPORTING ENTITIES)
-- =============================================================================

-- 1. SALES TREND RESULT (ERD #10 / SRS 7.9 Table 5)
CREATE TABLE IF NOT EXISTS `sales_trend_result` (
    `result_id`       INT AUTO_INCREMENT PRIMARY KEY,
    `period_month`    DATE NOT NULL,
    `origin_port_id`  INT NOT NULL,
    `dest_port_id`    INT NOT NULL,
    `total_sales`     DECIMAL(14, 2) NOT NULL DEFAULT 0.00,
    `total_qty`       INT NOT NULL DEFAULT 0,
    `growth_pct`      DECIMAL(6, 2) NOT NULL DEFAULT 0.00,
    `created_at`      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT `fk_fr6_str_origin` FOREIGN KEY (`origin_port_id`) REFERENCES `ports`(`port_id`) ON DELETE CASCADE,
    CONSTRAINT `fk_fr6_str_dest` FOREIGN KEY (`dest_port_id`) REFERENCES `ports`(`port_id`) ON DELETE CASCADE,
    CONSTRAINT `chk_str_total_qty` CHECK (`total_qty` >= 0),
    CONSTRAINT `chk_str_total_sales` CHECK (`total_sales` >= 0.00),
    UNIQUE KEY `uq_sales_trend_route_month` (`period_month`, `origin_port_id`, `dest_port_id`),
    INDEX `idx_sales_trend_route_month` (`period_month`, `origin_port_id`, `dest_port_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 2. ABC CLASSIFICATION RESULT (ERD #26 / SRS 7.9 Table 2)
CREATE TABLE IF NOT EXISTS `abc_classification_result` (
    `result_id`       INT AUTO_INCREMENT PRIMARY KEY,
    `product_id`      INT NOT NULL,
    `annual_value`    DECIMAL(14, 2) NOT NULL DEFAULT 0.00,
    `cumulative_pct`  DECIMAL(5, 2) NOT NULL DEFAULT 0.00,
    `abc_class`       CHAR(1) NOT NULL,
    `calculated_on`   DATE NOT NULL,
    `created_at`      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT `fk_fr6_abc_prod` FOREIGN KEY (`product_id`) REFERENCES `products`(`product_id`) ON DELETE CASCADE,
    CONSTRAINT `chk_abc_class` CHECK (`abc_class` IN ('A', 'B', 'C')),
    CONSTRAINT `chk_abc_cum_pct` CHECK (`cumulative_pct` BETWEEN 0.00 AND 100.00),
    UNIQUE KEY `uq_abc_product_date` (`product_id`, `calculated_on`),
    INDEX `idx_abc_class` (`abc_class`),
    INDEX `idx_abc_product_lookup` (`product_id`, `calculated_on`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 3. INVENTORY TURNOVER RESULT (ERD #27 / SRS 7.9 Table 3)
CREATE TABLE IF NOT EXISTS `inventory_turnover_result` (
    `result_id`       INT AUTO_INCREMENT PRIMARY KEY,
    `product_id`      INT NOT NULL,
    `period_start`    DATE NOT NULL,
    `period_end`      DATE NOT NULL,
    `cogs`            DECIMAL(14, 2) NOT NULL DEFAULT 0.00,
    `avg_inventory`   DECIMAL(14, 2) NOT NULL DEFAULT 0.00,
    `turnover_ratio`  DECIMAL(8, 2) NOT NULL DEFAULT 0.00,
    `created_at`      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT `fk_fr6_turnover_prod` FOREIGN KEY (`product_id`) REFERENCES `products`(`product_id`) ON DELETE CASCADE,
    CONSTRAINT `chk_turnover_dates` CHECK (`period_start` <= `period_end`),
    CONSTRAINT `chk_turnover_cogs_nonneg` CHECK (`cogs` >= 0.00),
    CONSTRAINT `chk_turnover_avg_inv_nonneg` CHECK (`avg_inventory` >= 0.00),
    UNIQUE KEY `uq_turnover_product_period` (`product_id`, `period_start`, `period_end`),
    INDEX `idx_turnover_prod_dates` (`product_id`, `period_start`, `period_end`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 4. PROFITABILITY RESULT (ERD #28 / SRS 7.9 Table 4)
CREATE TABLE IF NOT EXISTS `profitability_result` (
    `result_id`       INT AUTO_INCREMENT PRIMARY KEY,
    `product_id`      INT NOT NULL,
    `period_month`    DATE NOT NULL,
    `revenue`         DECIMAL(14, 2) NOT NULL DEFAULT 0.00,
    `cost`            DECIMAL(14, 2) NOT NULL DEFAULT 0.00,
    `margin_pct`      DECIMAL(6, 2) NOT NULL DEFAULT 0.00,
    `created_at`      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT `fk_fr6_profit_prod` FOREIGN KEY (`product_id`) REFERENCES `products`(`product_id`) ON DELETE CASCADE,
    CONSTRAINT `chk_prof_revenue_nonneg` CHECK (`revenue` >= 0.00),
    CONSTRAINT `chk_prof_cost_nonneg` CHECK (`cost` >= 0.00),
    CONSTRAINT `chk_prof_margin_range` CHECK (`margin_pct` BETWEEN -100.00 AND 100.00),
    UNIQUE KEY `uq_profitability_product_month` (`product_id`, `period_month`),
    INDEX `idx_profitability_prod_month` (`product_id`, `period_month`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 5. PROFIT LOSS (ERD #11 / SRS 7.9 Table 1)
-- Rule: Implements net_profit as a STORED GENERATED column per Checklist Section 8.
CREATE TABLE IF NOT EXISTS `profit_loss` (
    `pl_id`           INT AUTO_INCREMENT PRIMARY KEY,
    `shipment_id`     INT NULL,
    `seller_id`       INT NOT NULL,
    `period_month`    DATE NOT NULL,
    `revenue`         DECIMAL(14, 2) NOT NULL DEFAULT 0.00,
    `freight_cost`    DECIMAL(14, 2) NOT NULL DEFAULT 0.00,
    `port_cost`       DECIMAL(14, 2) NOT NULL DEFAULT 0.00,
    `handling_cost`   DECIMAL(14, 2) NOT NULL DEFAULT 0.00,
    `claim_loss`      DECIMAL(14, 2) NOT NULL DEFAULT 0.00,
    `net_profit`      DECIMAL(14, 2) GENERATED ALWAYS AS (revenue - freight_cost - port_cost - handling_cost - claim_loss) STORED,
    `created_at`      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT `fk_fr6_pl_shipment` FOREIGN KEY (`shipment_id`) REFERENCES `shipment`(`shipment_id`) ON DELETE SET NULL,
    CONSTRAINT `fk_fr6_pl_seller` FOREIGN KEY (`seller_id`) REFERENCES `users`(`user_id`) ON DELETE CASCADE,
    UNIQUE KEY `uq_profit_loss_shipment_month` (`shipment_id`, `period_month`),
    INDEX `idx_pl_seller_month` (`seller_id`, `period_month`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 6. CUSTOMER ABC CLASSIFICATION RESULT (Checklist Table 1 / FR6.3)
CREATE TABLE IF NOT EXISTS `customer_abc_classification_result` (
    `result_id`       INT AUTO_INCREMENT PRIMARY KEY,
    `customer_id`     INT NOT NULL,
    `annual_value`    DECIMAL(14, 2) NOT NULL DEFAULT 0.00,
    `cumulative_pct`  DECIMAL(5, 2) NOT NULL DEFAULT 0.00,
    `abc_class`       CHAR(1) NOT NULL,
    `calculated_on`   DATE NOT NULL,
    `created_at`      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT `fk_fr6_cabc_customer` FOREIGN KEY (`customer_id`) REFERENCES `customers`(`customer_id`) ON DELETE CASCADE,
    CONSTRAINT `chk_cabc_class` CHECK (`abc_class` IN ('A', 'B', 'C')),
    CONSTRAINT `chk_cabc_cum_pct` CHECK (`cumulative_pct` BETWEEN 0.00 AND 100.00),
    UNIQUE KEY `uq_customer_abc_calc` (`customer_id`, `calculated_on`),
    INDEX `idx_customer_abc_class` (`abc_class`),
    INDEX `idx_customer_abc_calc_lookup` (`customer_id`, `calculated_on`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 7. SALES TREND PRODUCT RESULT (Checklist Table 2 / FR6.2)
CREATE TABLE IF NOT EXISTS `sales_trend_product_result` (
    `result_id`       INT AUTO_INCREMENT PRIMARY KEY,
    `product_id`      INT NOT NULL,
    `period_month`    DATE NOT NULL,
    `total_sales`     DECIMAL(14, 2) NOT NULL DEFAULT 0.00,
    `total_qty`       INT NOT NULL DEFAULT 0,
    `growth_pct`      DECIMAL(6, 2) NOT NULL DEFAULT 0.00,
    `created_at`      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT `fk_fr6_stpr_product` FOREIGN KEY (`product_id`) REFERENCES `products`(`product_id`) ON DELETE CASCADE,
    CONSTRAINT `chk_stpr_sales_nonneg` CHECK (`total_sales` >= 0.00),
    CONSTRAINT `chk_stpr_qty_nonneg` CHECK (`total_qty` >= 0),
    UNIQUE KEY `uq_prod_trend_month` (`product_id`, `period_month`),
    INDEX `idx_sales_trend_prod_month` (`period_month`, `product_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 8. SALES TREND CUSTOMER RESULT (Checklist Table 3 / FR6.2)
CREATE TABLE IF NOT EXISTS `sales_trend_customer_result` (
    `result_id`       INT AUTO_INCREMENT PRIMARY KEY,
    `customer_id`     INT NOT NULL,
    `period_month`    DATE NOT NULL,
    `total_sales`     DECIMAL(14, 2) NOT NULL DEFAULT 0.00,
    `total_qty`       INT NOT NULL DEFAULT 0,
    `growth_pct`      DECIMAL(6, 2) NOT NULL DEFAULT 0.00,
    `created_at`      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT `fk_fr6_stcr_customer` FOREIGN KEY (`customer_id`) REFERENCES `customers`(`customer_id`) ON DELETE CASCADE,
    CONSTRAINT `chk_stcr_sales_nonneg` CHECK (`total_sales` >= 0.00),
    CONSTRAINT `chk_stcr_qty_nonneg` CHECK (`total_qty` >= 0),
    UNIQUE KEY `uq_cust_trend_month` (`customer_id`, `period_month`),
    INDEX `idx_sales_trend_cust_month` (`period_month`, `customer_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 9. SHIPMENT PROFITABILITY RESULT (Checklist Table 4 / FR6.5)
CREATE TABLE IF NOT EXISTS `shipment_profitability_result` (
    `result_id`       INT AUTO_INCREMENT PRIMARY KEY,
    `shipment_id`     INT NOT NULL,
    `seller_id`       INT NOT NULL,
    `period_month`    DATE NOT NULL,
    `revenue`         DECIMAL(14, 2) NOT NULL DEFAULT 0.00,
    `cost`            DECIMAL(14, 2) NOT NULL DEFAULT 0.00,
    `margin_pct`      DECIMAL(6, 2) NOT NULL DEFAULT 0.00,
    `created_at`      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT `fk_fr6_spr_shipment` FOREIGN KEY (`shipment_id`) REFERENCES `shipment`(`shipment_id`) ON DELETE CASCADE,
    CONSTRAINT `fk_fr6_spr_seller` FOREIGN KEY (`seller_id`) REFERENCES `users`(`user_id`) ON DELETE CASCADE,
    CONSTRAINT `chk_spr_revenue_nonneg` CHECK (`revenue` >= 0.00),
    CONSTRAINT `chk_spr_cost_nonneg` CHECK (`cost` >= 0.00),
    UNIQUE KEY `uq_ship_profit_month` (`shipment_id`, `period_month`),
    INDEX `idx_ship_profit_month` (`shipment_id`, `period_month`),
    INDEX `idx_ship_profit_seller` (`seller_id`, `period_month`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 10. ANALYTICS STALENESS & LOGGING
CREATE TABLE IF NOT EXISTS `analytics_staleness` (
    `module_name`       VARCHAR(40) PRIMARY KEY,
    `is_stale`          TINYINT(1) NOT NULL DEFAULT 1,
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

-- Restore foreign keys
SET FOREIGN_KEY_CHECKS = @OLD_FOREIGN_KEY_CHECKS;


-- =============================================================================
-- STEP 4: REQUIRED COMPOUND INDEXES & CONSTRAINTS (CHECKLIST SECTION 8)
-- =============================================================================

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
-- STEP 5: LIVE DATABASE VIEWS (8 VIEWS - CHECKLIST SECTION 3)
-- =============================================================================

-- LIVE VIEW 1: vw_fr6_kpi_live (Checklist 3.1 & 7.1)
CREATE OR REPLACE VIEW `vw_fr6_kpi_live` AS
SELECT 
    (SELECT COUNT(*) FROM `shipment` WHERE `status` NOT IN ('CANCELLED', 'DELIVERED')) AS active_shipments,
    (SELECT COUNT(*) FROM `containers` WHERE `status` = 'AVAILABLE') AS available_containers,
    (SELECT COALESCE(SUM(`paid_amount`), 0.00) FROM `billing_invoices`) AS revenue,
    (SELECT COALESCE(SUM(`total_amount` - `paid_amount`), 0.00) FROM `billing_invoices` WHERE `status` <> 'PAID') AS pending_invoices,
    (SELECT COUNT(*) FROM `claims` WHERE `status` IN ('SUBMITTED', 'UNDER_REVIEW')) AS open_claims;

-- LIVE VIEW 2: vw_fr6_sales_route_live (Checklist 3.2 & 7.2)
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

-- LIVE VIEW 3: vw_fr6_sales_product_live (Checklist 3.3 & 7.3)
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

-- LIVE VIEW 4: vw_fr6_sales_customer_live (Checklist 3.4 & 7.4)
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

-- LIVE VIEW 5: vw_fr6_inventory_live (Checklist 3.5)
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

-- LIVE VIEW 6: vw_fr6_shipment_profitability_live (Checklist 3.6 & 7.10)
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

-- LIVE VIEW 7: vw_fr6_seller_pnl_live (Checklist 3.7 & 7.9)
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

-- LIVE VIEW 8: vw_fr6_demand_forecast_live (Checklist 3.8 & 7.11)
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
-- STEP 6: CACHED-RESULT VIEWS (8 VIEWS - CHECKLIST SECTION 3)
-- =============================================================================

-- CACHED VIEW 1: vw_fr6_abc_product (Checklist Cached 1 & 7.5)
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

-- CACHED VIEW 2: vw_fr6_abc_customer (Checklist Cached 2 & 7.6)
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

-- CACHED VIEW 3: vw_fr6_inventory_turnover (Checklist Cached 3 & 7.7)
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

-- CACHED VIEW 4: vw_fr6_product_profitability (Checklist Cached 4 & 7.8)
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

-- CACHED VIEW 5: vw_fr6_shipment_profitability (Checklist Cached 5)
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

-- CACHED VIEW 6: vw_fr6_sales_route_cached (Checklist Cached 6)
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

-- CACHED VIEW 7: vw_fr6_sales_product_cached (Checklist Cached 7)
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

-- CACHED VIEW 8: vw_fr6_sales_customer_cached (Checklist Cached 8)
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
-- STEP 7: STORED PROCEDURES (12 PROCEDURES - CHECKLIST SECTION 4)
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

-- PROCEDURE 1: sp_refresh_sales_trends (Checklist 4.1)
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

-- PROCEDURE 2: sp_calculate_product_sales_trends (Checklist 4.2)
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

-- PROCEDURE 3: sp_calculate_customer_sales_trends (Checklist 4.3)
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

-- PROCEDURE 4: sp_calculate_abc_classification (Checklist 4.4)
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

-- PROCEDURE 5: sp_calculate_customer_abc (Checklist 4.5)
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

-- PROCEDURE 6: sp_calculate_inventory_turnover (Checklist 4.6)
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

-- PROCEDURE 7: sp_calculate_profitability (Checklist 4.7)
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

-- PROCEDURE 8: sp_calculate_shipment_profitability (Checklist 4.8)
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

-- PROCEDURE 9: sp_calculate_profit_loss (Checklist 4.9)
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

-- PROCEDURE 10: sp_generate_demand_forecast (Checklist 4.10)
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

-- PROCEDURE 11: sp_apply_forecast_pricing (Checklist 4.11)
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

-- PROCEDURE 12: sp_refresh_all_fr6_analytics (Checklist 4.12 Master Orchestrator)
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

    UPDATE analytics_staleness 
    SET is_stale = 0, last_refreshed_at = NOW(), stale_reason = 'Refreshed successfully'
    WHERE is_stale = 1;

    COMMIT;
END //

-- PROCEDURE 13: sp_purge_historical_analytics_cache (Checklist Section 11)
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
-- STEP 8: OPERATIONAL & AUDITING TRIGGERS (7 TRIGGERS - CHECKLIST 5 & 9)
-- =============================================================================

DROP TRIGGER IF EXISTS `trg_after_payment_insert`;
DROP TRIGGER IF EXISTS `trg_after_stock_insert_ledger`;
DROP TRIGGER IF EXISTS `trg_after_stock_update_ledger`;
DROP TRIGGER IF EXISTS `trg_after_claim_status_change`;
DROP TRIGGER IF EXISTS `trg_after_pricing_rule_update`;
DROP TRIGGER IF EXISTS `trg_after_container_movement_insert`;
DROP TRIGGER IF EXISTS `trg_after_shipment_update_release`;

DELIMITER //

-- TRIGGER 1: trg_after_payment_insert (FR5.4)
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
    
    UPDATE analytics_staleness SET is_stale = 1, stale_reason = 'New payment posted' WHERE module_name = 'profit_loss';
END //

-- TRIGGER 2: trg_after_stock_insert_ledger (FR4.5)
CREATE TRIGGER `trg_after_stock_insert_ledger`
AFTER INSERT ON `stock`
FOR EACH ROW
BEGIN
    INSERT INTO inventory_ledger (stock_id, product_id, txn_type, quantity, balance_after, reference_type, reference_id, txn_time)
    VALUES (NEW.stock_id, NEW.product_id, 'IN', NEW.quantity, NEW.quantity, 'INITIAL_STOCK', NEW.stock_id, NOW());
END //

-- TRIGGER 3: trg_after_stock_update_ledger (FR4.5)
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

-- TRIGGER 4: trg_after_claim_status_change (FR7.5)
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

-- TRIGGER 5: trg_after_pricing_rule_update (FR3.6)
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

-- TRIGGER 6: trg_after_container_movement_insert (FR2.2 / FR2.3)
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

-- TRIGGER 7: trg_after_shipment_update_release (FR4.7)
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
        
        UPDATE containers SET status = 'AVAILABLE' WHERE container_id = NEW.container_id;
    END IF;
END //

DELIMITER ;


-- =============================================================================
-- STEP 9: CHECKLIST BASELINE REPORTING QUERIES (7.1 TO 7.11)
-- =============================================================================

-- 7.1 KPI Aggregation
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
-- STEP 10: PARAMETERIZED CRUD & MULTI-DIMENSIONAL FILTERS (FR6.8)
-- =============================================================================
/*
-- PreparedStatement references for Java AnalyticsDAO.java:
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
*/


-- =============================================================================
-- STEP 11: REFRESH SCHEDULER & COMPREHENSIVE VERIFICATION SUITE
-- =============================================================================

-- Daily background refresh event (Midnight)
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
-- EXECUTE MASTER CALCULATION & VERIFY ON DUMMY DATABASE
-- =============================================================================
CALL sp_refresh_all_fr6_analytics();

-- Display Verification Summary Table across all 10 Analytics Tables in n_logistic_dummy_db
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

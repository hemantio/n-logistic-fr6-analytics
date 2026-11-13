-- =============================================================================
-- Module: FR6 - Analytics Dashboard (Development Testing Fixture)
-- Script: dev_only/local_schema_all_28_tables.sql
-- Description: Complete 28-entity schema for local standalone development/testing.
-- Notice: This file is strictly for local dev/testing of FR6 in absence of the other modules.
-- It must NOT be executed as an integration script on production.
-- Target Database: n_logistic_db
-- =============================================================================

CREATE DATABASE IF NOT EXISTS `n_logistic_db` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE `n_logistic_db`;

-- 1. Companies (SRS 7.3 / ERD #3)
CREATE TABLE IF NOT EXISTS `companies` (
    `company_id` INT AUTO_INCREMENT PRIMARY KEY,
    `company_name` VARCHAR(150) NOT NULL,
    `company_type` ENUM('CONSUMER', 'SELLER') NOT NULL,
    `gst_number` VARCHAR(20) UNIQUE,
    `iec_code` VARCHAR(15) NULL COMMENT 'Import Export Code',
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
    CONSTRAINT `fk_users_company` FOREIGN KEY (`company_id`) REFERENCES `companies` (`company_id`) ON DELETE SET NULL
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
    CONSTRAINT `fk_customers_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE,
    CONSTRAINT `fk_customers_company` FOREIGN KEY (`company_id`) REFERENCES `companies` (`company_id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 4. Audit Log (SRS 7.3 / ERD #1)
CREATE TABLE IF NOT EXISTS `audit_log` (
    `log_id` BIGINT AUTO_INCREMENT PRIMARY KEY,
    `user_id` INT NULL,
    `action` VARCHAR(100) NOT NULL,
    `table_name` VARCHAR(60) NULL,
    `record_id` BIGINT NULL,
    `old_value` LONGTEXT NULL COMMENT 'JSON string',
    `new_value` LONGTEXT NULL COMMENT 'JSON string',
    `ip_address` VARCHAR(45) NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT `fk_audit_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE SET NULL
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
    CONSTRAINT `fk_vessels_company` FOREIGN KEY (`owner_company_id`) REFERENCES `companies` (`company_id`) ON DELETE SET NULL
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
    CONSTRAINT `fk_containers_seller` FOREIGN KEY (`seller_id`) REFERENCES `companies` (`company_id`) ON DELETE RESTRICT,
    CONSTRAINT `fk_containers_port` FOREIGN KEY (`current_port_id`) REFERENCES `ports` (`port_id`) ON DELETE SET NULL
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
    `etd` DATE NULL,
    `eta` DATE NULL,
    `actual_arrival` DATE NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT `fk_shipment_consumer` FOREIGN KEY (`consumer_id`) REFERENCES `customers` (`customer_id`) ON DELETE RESTRICT,
    CONSTRAINT `fk_shipment_seller` FOREIGN KEY (`seller_id`) REFERENCES `companies` (`company_id`) ON DELETE RESTRICT,
    CONSTRAINT `fk_shipment_container` FOREIGN KEY (`container_id`) REFERENCES `containers` (`container_id`) ON DELETE RESTRICT,
    CONSTRAINT `fk_shipment_vessel` FOREIGN KEY (`vessel_id`) REFERENCES `vessels` (`vessel_id`) ON DELETE SET NULL,
    CONSTRAINT `fk_shipment_origin` FOREIGN KEY (`origin_port_id`) REFERENCES `ports` (`port_id`) ON DELETE RESTRICT,
    CONSTRAINT `fk_shipment_dest` FOREIGN KEY (`dest_port_id`) REFERENCES `ports` (`port_id`) ON DELETE RESTRICT
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
    CONSTRAINT `fk_movement_shipment` FOREIGN KEY (`shipment_id`) REFERENCES `shipment` (`shipment_id`) ON DELETE CASCADE,
    CONSTRAINT `fk_movement_container` FOREIGN KEY (`container_id`) REFERENCES `containers` (`container_id`) ON DELETE CASCADE,
    CONSTRAINT `fk_movement_port` FOREIGN KEY (`port_id`) REFERENCES `ports` (`port_id`) ON DELETE SET NULL,
    CONSTRAINT `fk_movement_user` FOREIGN KEY (`updated_by`) REFERENCES `users` (`user_id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 10. Products (SRS 7.6 / ERD #24)
CREATE TABLE IF NOT EXISTS `products` (
    `product_id` INT AUTO_INCREMENT PRIMARY KEY,
    `sku` VARCHAR(40) NOT NULL UNIQUE,
    `product_name` VARCHAR(120) NOT NULL,
    `category` VARCHAR(60) NULL,
    `hs_code` VARCHAR(12) NULL,
    `unit` VARCHAR(10) NULL COMMENT 'kg, box, pcs',
    `unit_weight_kg` DECIMAL(8, 3) NULL,
    `unit_price` DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    `owner_company_id` INT NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT `fk_products_owner` FOREIGN KEY (`owner_company_id`) REFERENCES `companies` (`company_id`) ON DELETE RESTRICT
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
    CONSTRAINT `fk_items_shipment` FOREIGN KEY (`shipment_id`) REFERENCES `shipment` (`shipment_id`) ON DELETE CASCADE,
    CONSTRAINT `fk_items_product` FOREIGN KEY (`product_id`) REFERENCES `products` (`product_id`) ON DELETE RESTRICT
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
    `rate_per_cbm` DECIMAL(8, 2) NOT NULL DEFAULT 0.00,
    `season_multiplier` DECIMAL(4, 2) NOT NULL DEFAULT 1.00,
    `demand_multiplier` DECIMAL(4, 2) NOT NULL DEFAULT 1.00,
    `valid_from` DATE NULL,
    `valid_to` DATE NULL,
    `is_active` BOOLEAN NOT NULL DEFAULT TRUE,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT `fk_pricing_seller` FOREIGN KEY (`seller_id`) REFERENCES `companies` (`company_id`) ON DELETE RESTRICT,
    CONSTRAINT `fk_pricing_origin` FOREIGN KEY (`origin_port_id`) REFERENCES `ports` (`port_id`) ON DELETE RESTRICT,
    CONSTRAINT `fk_pricing_dest` FOREIGN KEY (`dest_port_id`) REFERENCES `ports` (`port_id`) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 13. Pricing Audit (SRS 7.5 / ERD #6)
CREATE TABLE IF NOT EXISTS `pricing_audit` (
    `audit_id` INT AUTO_INCREMENT PRIMARY KEY,
    `rule_id` INT NOT NULL,
    `old_rate` DECIMAL(12, 2) NULL,
    `new_rate` DECIMAL(12, 2) NULL,
    `old_multiplier` DECIMAL(4, 2) NULL,
    `new_multiplier` DECIMAL(4, 2) NULL,
    `changed_by` INT NULL,
    `changed_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT `fk_paudit_rule` FOREIGN KEY (`rule_id`) REFERENCES `pricing_rules` (`rule_id`) ON DELETE CASCADE,
    CONSTRAINT `fk_paudit_user` FOREIGN KEY (`changed_by`) REFERENCES `users` (`user_id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 14. Stock (SRS 7.6 / ERD #17)
CREATE TABLE IF NOT EXISTS `stock` (
    `stock_id` INT AUTO_INCREMENT PRIMARY KEY,
    `product_id` INT NOT NULL,
    `shipment_id` INT NULL,
    `container_id` INT NULL,
    `quantity` INT NOT NULL DEFAULT 0,
    `damaged_qty` INT NOT NULL DEFAULT 0,
    `last_updated` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT `fk_stock_product` FOREIGN KEY (`product_id`) REFERENCES `products` (`product_id`) ON DELETE RESTRICT,
    CONSTRAINT `fk_stock_shipment` FOREIGN KEY (`shipment_id`) REFERENCES `shipment` (`shipment_id`) ON DELETE SET NULL,
    CONSTRAINT `fk_stock_container` FOREIGN KEY (`container_id`) REFERENCES `containers` (`container_id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 15. Inventory Ledger (SRS 7.6 / ERD #23)
CREATE TABLE IF NOT EXISTS `inventory_ledger` (
    `ledger_id` BIGINT AUTO_INCREMENT PRIMARY KEY,
    `stock_id` INT NOT NULL,
    `product_id` INT NOT NULL,
    `txn_type` ENUM('IN', 'OUT', 'DAMAGE', 'ADJUST', 'CLAIM_LOSS') NOT NULL,
    `quantity` INT NOT NULL,
    `balance_after` INT NOT NULL,
    `reference_type` VARCHAR(30) NULL COMMENT 'SHIPMENT, CLAIM, UPLOAD',
    `reference_id` BIGINT NULL,
    `txn_time` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT `fk_ledger_stock` FOREIGN KEY (`stock_id`) REFERENCES `stock` (`stock_id`) ON DELETE CASCADE,
    CONSTRAINT `fk_ledger_product` FOREIGN KEY (`product_id`) REFERENCES `products` (`product_id`) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 16. Sales Transactions (SRS 7.6 / ERD #25)
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
    CONSTRAINT `fk_sales_product` FOREIGN KEY (`product_id`) REFERENCES `products` (`product_id`) ON DELETE RESTRICT,
    CONSTRAINT `fk_sales_customer` FOREIGN KEY (`customer_id`) REFERENCES `customers` (`customer_id`) ON DELETE RESTRICT,
    CONSTRAINT `fk_sales_shipment` FOREIGN KEY (`shipment_id`) REFERENCES `shipment` (`shipment_id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 17. Billing Invoices (SRS 7.7 / ERD #15)
CREATE TABLE IF NOT EXISTS `billing_invoices` (
    `invoice_id` INT AUTO_INCREMENT PRIMARY KEY,
    `invoice_no` VARCHAR(20) NOT NULL UNIQUE,
    `shipment_id` INT NOT NULL,
    `consumer_id` INT NOT NULL,
    `seller_id` INT NOT NULL,
    `sub_total` DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    `tax_amount` DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    `total_amount` DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    `paid_amount` DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    `status` ENUM('UNPAID', 'PARTIAL', 'PAID') NOT NULL DEFAULT 'UNPAID',
    `issue_date` DATE NOT NULL,
    `due_date` DATE NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT `fk_invoice_shipment` FOREIGN KEY (`shipment_id`) REFERENCES `shipment` (`shipment_id`) ON DELETE RESTRICT,
    CONSTRAINT `fk_invoice_consumer` FOREIGN KEY (`consumer_id`) REFERENCES `customers` (`customer_id`) ON DELETE RESTRICT,
    CONSTRAINT `fk_invoice_seller` FOREIGN KEY (`seller_id`) REFERENCES `companies` (`company_id`) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 18. Invoice Line Items (SRS 7.7 / ERD #19)
CREATE TABLE IF NOT EXISTS `invoice_line_items` (
    `item_id` INT AUTO_INCREMENT PRIMARY KEY,
    `invoice_id` INT NOT NULL,
    `item_type` ENUM('FREIGHT', 'HANDLING', 'CUSTOMS', 'TAX', 'INSURANCE', 'OTHER') NOT NULL,
    `description` VARCHAR(150) NULL,
    `quantity` DECIMAL(8, 2) NOT NULL DEFAULT 1.00,
    `unit_price` DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    `amount` DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT `fk_line_invoice` FOREIGN KEY (`invoice_id`) REFERENCES `billing_invoices` (`invoice_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 19. Payments (SRS 7.7 / ERD #20)
CREATE TABLE IF NOT EXISTS `payments` (
    `payment_id` INT AUTO_INCREMENT PRIMARY KEY,
    `invoice_id` INT NOT NULL,
    `amount` DECIMAL(12, 2) NOT NULL,
    `payment_mode` ENUM('BANK', 'UPI', 'CHEQUE', 'CASH') NOT NULL,
    `reference_no` VARCHAR(50) NULL,
    `payment_date` DATE NOT NULL,
    `recorded_by` INT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT `fk_payments_invoice` FOREIGN KEY (`invoice_id`) REFERENCES `billing_invoices` (`invoice_id`) ON DELETE RESTRICT,
    CONSTRAINT `fk_payments_user` FOREIGN KEY (`recorded_by`) REFERENCES `users` (`user_id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 20. Claims (SRS 7.8 / ERD #16)
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
    CONSTRAINT `fk_claims_shipment` FOREIGN KEY (`shipment_id`) REFERENCES `shipment` (`shipment_id`) ON DELETE RESTRICT,
    CONSTRAINT `fk_claims_container` FOREIGN KEY (`container_id`) REFERENCES `containers` (`container_id`) ON DELETE SET NULL,
    CONSTRAINT `fk_claims_consumer` FOREIGN KEY (`consumer_id`) REFERENCES `customers` (`customer_id`) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 21. Claim Documents (SRS 7.8 / ERD #21)
CREATE TABLE IF NOT EXISTS `claim_documents` (
    `cdoc_id` INT AUTO_INCREMENT PRIMARY KEY,
    `claim_id` INT NOT NULL,
    `file_name` VARCHAR(150) NOT NULL,
    `file_path` VARCHAR(255) NOT NULL,
    `file_type` VARCHAR(10) NULL COMMENT 'PDF, JPG, PNG',
    `uploaded_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT `fk_cdocs_claim` FOREIGN KEY (`claim_id`) REFERENCES `claims` (`claim_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 22. Claim Status History (SRS 7.8 / ERD #22)
CREATE TABLE IF NOT EXISTS `claim_status_history` (
    `history_id` BIGINT AUTO_INCREMENT PRIMARY KEY,
    `claim_id` INT NOT NULL,
    `old_status` VARCHAR(20) NULL,
    `new_status` VARCHAR(20) NULL,
    `changed_by` INT NULL,
    `remarks` VARCHAR(255) NULL,
    `changed_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT `fk_chistory_claim` FOREIGN KEY (`claim_id`) REFERENCES `claims` (`claim_id`) ON DELETE CASCADE,
    CONSTRAINT `fk_chistory_user` FOREIGN KEY (`changed_by`) REFERENCES `users` (`user_id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 23. Demand Forecast (SRS 7.5 / ERD #8)
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
    CONSTRAINT `fk_dforecast_origin` FOREIGN KEY (`origin_port_id`) REFERENCES `ports` (`port_id`) ON DELETE RESTRICT,
    CONSTRAINT `fk_dforecast_dest` FOREIGN KEY (`dest_port_id`) REFERENCES `ports` (`port_id`) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 24. Profit & Loss (SRS 7.9 / ERD #12)
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
    CONSTRAINT `fk_pl_shipment` FOREIGN KEY (`shipment_id`) REFERENCES `shipment` (`shipment_id`) ON DELETE SET NULL,
    CONSTRAINT `fk_pl_seller` FOREIGN KEY (`seller_id`) REFERENCES `companies` (`company_id`) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 25. ABC Classification Result (SRS 7.9 / ERD #26)
CREATE TABLE IF NOT EXISTS `abc_classification_result` (
    `result_id` INT AUTO_INCREMENT PRIMARY KEY,
    `product_id` INT NOT NULL,
    `annual_value` DECIMAL(14, 2) NOT NULL DEFAULT 0.00,
    `cumulative_pct` DECIMAL(5, 2) NOT NULL DEFAULT 0.00,
    `abc_class` CHAR(1) NOT NULL COMMENT 'A = top 70%, B = next 20%, C = last 10%',
    `calculated_on` DATE NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT `fk_abc_product` FOREIGN KEY (`product_id`) REFERENCES `products` (`product_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 26. Inventory Turnover Result (SRS 7.9 / ERD #27)
CREATE TABLE IF NOT EXISTS `inventory_turnover_result` (
    `result_id` INT AUTO_INCREMENT PRIMARY KEY,
    `product_id` INT NOT NULL,
    `period_start` DATE NOT NULL,
    `period_end` DATE NOT NULL,
    `cogs` DECIMAL(14, 2) NOT NULL DEFAULT 0.00 COMMENT 'Cost of goods sold',
    `avg_inventory` DECIMAL(14, 2) NOT NULL DEFAULT 0.00,
    `turnover_ratio` DECIMAL(8, 2) NOT NULL DEFAULT 0.00 COMMENT 'cogs / avg_inventory',
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT `fk_iturnover_product` FOREIGN KEY (`product_id`) REFERENCES `products` (`product_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 27. Profitability Result (SRS 7.9 / ERD #28)
CREATE TABLE IF NOT EXISTS `profitability_result` (
    `result_id` INT AUTO_INCREMENT PRIMARY KEY,
    `product_id` INT NOT NULL,
    `period_month` DATE NOT NULL,
    `revenue` DECIMAL(14, 2) NOT NULL DEFAULT 0.00,
    `cost` DECIMAL(14, 2) NOT NULL DEFAULT 0.00,
    `margin_pct` DECIMAL(6, 2) NOT NULL DEFAULT 0.00,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT `fk_profitability_product` FOREIGN KEY (`product_id`) REFERENCES `products` (`product_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 28. Sales Trend Result (SRS 7.9 / ERD #10)
CREATE TABLE IF NOT EXISTS `sales_trend_result` (
    `result_id` INT AUTO_INCREMENT PRIMARY KEY,
    `period_month` DATE NOT NULL,
    `origin_port_id` INT NULL,
    `dest_port_id` INT NULL,
    `total_sales` DECIMAL(14, 2) NOT NULL DEFAULT 0.00,
    `total_qty` INT NOT NULL DEFAULT 0,
    `growth_pct` DECIMAL(6, 2) NOT NULL DEFAULT 0.00,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT `fk_strend_origin` FOREIGN KEY (`origin_port_id`) REFERENCES `ports` (`port_id`) ON DELETE SET NULL,
    CONSTRAINT `fk_strend_dest` FOREIGN KEY (`dest_port_id`) REFERENCES `ports` (`port_id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

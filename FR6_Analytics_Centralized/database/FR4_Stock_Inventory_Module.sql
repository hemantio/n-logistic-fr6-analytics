-- =============================================================================
-- PROJECT: N Logistic Import & Export / Logistics Management Platform
-- MODULE:  FR4 - Stock & Inventory Management
-- FILE:    FR4_Stock_Inventory_Module.sql
-- PURPOSE: Standalone Database Implementation for Module FR4:
--          1. Table DDL (products, stock, inventory_ledger, sales_transactions)
--          2. Relational Foreign Keys & Negative Stock Constraints (FR4.6)
--          3. Performance Query Indexes
--          4. Multi-Table Operational Views (FR4.4)
--          5. Automated Ledger Audit Triggers (FR4.5)
--          6. Core Stored Procedures (Stock Reservation, Damage, CSV Intake)
--          7. Standard CRUD Query Templates (SELECT, INSERT, UPDATE, DEACTIVATE)
-- TARGET:  n_logistic_db (MySQL 8.0+ / MariaDB 10.4+ on XAMPP)
-- =============================================================================

USE `n_logistic_db`;

-- Temporarily disable FK checks to ensure safe idempotent DDL execution
SET @OLD_FOREIGN_KEY_CHECKS = @@FOREIGN_KEY_CHECKS;
SET FOREIGN_KEY_CHECKS = 0;

-- =============================================================================
-- 1. TABLE CREATION DDL (4 FR4 TABLES)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1.1 PRODUCTS (SRS 7.6 / ERD #24)
-- Purpose: Product catalog managed by the Seller (FR4.1).
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `products` (
    `product_id`        INT AUTO_INCREMENT PRIMARY KEY,
    `sku`               VARCHAR(40) NOT NULL UNIQUE COMMENT 'Stock Keeping Unit code',
    `product_name`      VARCHAR(120) NOT NULL,
    `category`          VARCHAR(60) NULL,
    `hs_code`           VARCHAR(12) NULL COMMENT 'Harmonized System customs tariff code',
    `unit`              VARCHAR(10) NULL COMMENT 'kg, box, pcs, pallet',
    `unit_weight_kg`    DECIMAL(8, 3) NOT NULL DEFAULT 1.000 COMMENT 'Used to calculate cargo weight',
    `unit_price`        DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    `owner_company_id`  INT NOT NULL COMMENT 'FK to companies (Seller)',
    `is_active`         BOOLEAN NOT NULL DEFAULT TRUE COMMENT 'Soft delete flag',
    `created_at`        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT `fk_products_owner_company`
        FOREIGN KEY (`owner_company_id`)
        REFERENCES `companies`(`company_id`)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,

    INDEX `idx_products_owner` (`owner_company_id`),
    INDEX `idx_products_sku` (`sku`),
    INDEX `idx_products_active` (`is_active`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Ensure is_active exists if table was previously created without it
ALTER TABLE `products` ADD COLUMN IF NOT EXISTS `is_active` BOOLEAN NOT NULL DEFAULT TRUE COMMENT 'Soft delete flag';



-- -----------------------------------------------------------------------------
-- 1.2 STOCK (SRS 7.6 / ERD #15)
-- Purpose: Physical inventory counts and shipment container allocations (FR4.3).
-- Constraint: FR4.6 forbids negative stock (quantity >= 0).
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `stock` (
    `stock_id`      INT AUTO_INCREMENT PRIMARY KEY,
    `product_id`    INT NOT NULL,
    `shipment_id`   INT NULL COMMENT 'NULL until linked to active shipment',
    `container_id`  INT NULL COMMENT 'Container allocated to this cargo',
    `quantity`      INT NOT NULL DEFAULT 0,
    `damaged_qty`   INT NOT NULL DEFAULT 0,
    `last_updated`  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    `created_at`    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT `chk_stock_quantity_non_negative` 
        CHECK (`quantity` >= 0),

    CONSTRAINT `chk_damaged_quantity_non_negative` 
        CHECK (`damaged_qty` >= 0),

    CONSTRAINT `fk_stock_product_ref`
        FOREIGN KEY (`product_id`)
        REFERENCES `products`(`product_id`)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    CONSTRAINT `fk_stock_shipment_ref`
        FOREIGN KEY (`shipment_id`)
        REFERENCES `shipment`(`shipment_id`)
        ON DELETE SET NULL
        ON UPDATE CASCADE,

    CONSTRAINT `fk_stock_container_ref`
        FOREIGN KEY (`container_id`)
        REFERENCES `containers`(`container_id`)
        ON DELETE SET NULL
        ON UPDATE CASCADE,

    INDEX `idx_stock_product_shipment` (`product_id`, `shipment_id`),
    INDEX `idx_stock_container` (`container_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- -----------------------------------------------------------------------------
-- 1.3 INVENTORY_LEDGER (SRS 7.6 / ERD #25)
-- Purpose: Immutable double-entry transaction journal for every stock change (FR4.5).
-- Types: IN (receipt), OUT (dispatch), DAMAGE, ADJUST, CLAIM_LOSS.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `inventory_ledger` (
    `ledger_id`       BIGINT AUTO_INCREMENT PRIMARY KEY,
    `stock_id`        INT NOT NULL,
    `product_id`      INT NOT NULL,
    `txn_type`        ENUM('IN', 'OUT', 'DAMAGE', 'ADJUST', 'CLAIM_LOSS') NOT NULL,
    `quantity`        INT NOT NULL COMMENT 'Change quantity (positive magnitude)',
    `balance_after`   INT NOT NULL COMMENT 'Running stock balance after transaction',
    `reference_type`  VARCHAR(30) NULL COMMENT 'SHIPMENT, CLAIM, UPLOAD, MANUAL',
    `reference_id`    BIGINT NULL COMMENT 'shipment_id, claim_id, or upload_batch_id',
    `txn_time`        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT `fk_ledger_stock_ref`
        FOREIGN KEY (`stock_id`)
        REFERENCES `stock`(`stock_id`)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    CONSTRAINT `fk_ledger_product_ref`
        FOREIGN KEY (`product_id`)
        REFERENCES `products`(`product_id`)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    INDEX `idx_ledger_product_time` (`product_id`, `txn_time`),
    INDEX `idx_ledger_stock` (`stock_id`),
    INDEX `idx_ledger_ref` (`reference_type`, `reference_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- -----------------------------------------------------------------------------
-- 1.4 SALES_TRANSACTIONS (SRS 7.6 / ERD #23)
-- Purpose: Records finalized customer product sales linked to shipments.
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

    CONSTRAINT `fk_sales_product_ref`
        FOREIGN KEY (`product_id`)
        REFERENCES `products`(`product_id`)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    CONSTRAINT `fk_sales_customer_ref`
        FOREIGN KEY (`customer_id`)
        REFERENCES `customers`(`customer_id`)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,

    CONSTRAINT `fk_sales_shipment_ref`
        FOREIGN KEY (`shipment_id`)
        REFERENCES `shipment`(`shipment_id`)
        ON DELETE SET NULL
        ON UPDATE CASCADE,

    INDEX `idx_sales_product_date` (`product_id`, `sale_date`),
    INDEX `idx_sales_customer` (`customer_id`),
    INDEX `idx_sales_shipment` (`shipment_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Re-enable foreign key constraints
SET FOREIGN_KEY_CHECKS = @OLD_FOREIGN_KEY_CHECKS;


-- =============================================================================
-- 2. OPERATIONAL & VALUATION VIEWS (FR4.4)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- VIEW 1: vw_fr4_inventory_summary
-- Purpose: High-level stock overview, available balance, damaged count, valuation.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW `vw_fr4_inventory_summary` AS
SELECT 
    p.product_id,
    p.sku,
    p.product_name,
    p.category,
    p.unit,
    p.unit_price,
    p.unit_weight_kg,
    comp.company_id AS seller_id,
    comp.company_name AS seller_name,
    COALESCE(SUM(stk.quantity), 0) AS total_on_hand_qty,
    COALESCE(SUM(CASE WHEN stk.shipment_id IS NOT NULL THEN stk.quantity ELSE 0 END), 0) AS reserved_qty,
    COALESCE(SUM(CASE WHEN stk.shipment_id IS NULL THEN stk.quantity ELSE 0 END), 0) AS unallocated_available_qty,
    COALESCE(SUM(stk.damaged_qty), 0) AS total_damaged_qty,
    ROUND(COALESCE(SUM(stk.quantity), 0) * p.unit_price, 2) AS total_inventory_valuation,
    MAX(stk.last_updated) AS latest_stock_activity
FROM products p
JOIN companies comp ON p.owner_company_id = comp.company_id
LEFT JOIN stock stk ON p.product_id = stk.product_id
WHERE p.is_active = TRUE
GROUP BY p.product_id, p.sku, p.product_name, p.category, p.unit, p.unit_price, p.unit_weight_kg, comp.company_id, comp.company_name;


-- -----------------------------------------------------------------------------
-- VIEW 2: vw_fr4_shipment_stock_reservation
-- Purpose: Shows stock reserved and linked to active shipments & containers (FR4.3).
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW `vw_fr4_shipment_stock_reservation` AS
SELECT 
    stk.stock_id,
    s.shipment_id,
    s.shipment_no,
    s.status AS shipment_status,
    p.product_id,
    p.sku,
    p.product_name,
    stk.quantity AS booked_reserved_qty,
    (stk.quantity * p.unit_weight_kg) AS total_weight_kg,
    ROUND(stk.quantity * p.unit_price, 2) AS total_cargo_value,
    c.container_id,
    c.container_number,
    c.container_type,
    seller.company_name AS seller_name,
    u.full_name AS consumer_name
FROM stock stk
JOIN shipment s ON stk.shipment_id = s.shipment_id
JOIN products p ON stk.product_id = p.product_id
JOIN companies seller ON s.seller_id = seller.company_id
JOIN customers cust ON s.consumer_id = cust.customer_id
JOIN users u ON cust.user_id = u.user_id
LEFT JOIN containers c ON stk.container_id = c.container_id;


-- -----------------------------------------------------------------------------
-- VIEW 3: vw_fr4_inventory_ledger_audit
-- Purpose: Full chronological movement history for audit trails (FR4.5).
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW `vw_fr4_inventory_ledger_audit` AS
SELECT 
    il.ledger_id,
    il.txn_time,
    p.sku,
    p.product_name,
    il.txn_type,
    il.quantity AS change_qty,
    il.balance_after,
    il.reference_type,
    il.reference_id,
    stk.stock_id,
    comp.company_name AS seller_name
FROM inventory_ledger il
JOIN products p ON il.product_id = p.product_id
JOIN stock stk ON il.stock_id = stk.stock_id
JOIN companies comp ON p.owner_company_id = comp.company_id
ORDER BY il.txn_time DESC;


-- =============================================================================
-- 3. STORED PROCEDURES FOR FR4 WORKFLOWS
-- =============================================================================

DROP PROCEDURE IF EXISTS `sp_fr4_receive_stock_upload`;
DROP PROCEDURE IF EXISTS `sp_fr4_reserve_stock_for_shipment`;
DROP PROCEDURE IF EXISTS `sp_fr4_record_damaged_stock`;

DELIMITER //

-- -----------------------------------------------------------------------------
-- PROCEDURE 1: sp_fr4_receive_stock_upload (FR4.1, FR4.5)
-- Adds stock via form or CSV upload and automatically writes to ledger
-- -----------------------------------------------------------------------------
CREATE PROCEDURE `sp_fr4_receive_stock_upload`(
    IN p_product_id INT,
    IN p_add_qty INT,
    IN p_batch_ref VARCHAR(50)
)
BEGIN
    DECLARE v_stock_id INT;
    DECLARE v_new_balance INT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    -- Check if unlinked on-hand stock row already exists for this product
    SELECT stock_id INTO v_stock_id
    FROM stock 
    WHERE product_id = p_product_id AND shipment_id IS NULL 
    LIMIT 1;

    IF v_stock_id IS NOT NULL THEN
        UPDATE stock 
        SET quantity = quantity + p_add_qty 
        WHERE stock_id = v_stock_id;
    ELSE
        INSERT INTO stock (product_id, shipment_id, container_id, quantity, damaged_qty)
        VALUES (p_product_id, NULL, NULL, p_add_qty, 0);
        SET v_stock_id = LAST_INSERT_ID();
    END IF;

    -- Calculate current total available balance
    SELECT SUM(quantity) INTO v_new_balance 
    FROM stock 
    WHERE product_id = p_product_id;

    -- Automatically log to immutable ledger (FR4.5)
    INSERT INTO inventory_ledger (stock_id, product_id, txn_type, quantity, balance_after, reference_type, reference_id, txn_time)
    VALUES (v_stock_id, p_product_id, 'IN', p_add_qty, v_new_balance, 'UPLOAD', NULL, CURRENT_TIMESTAMP);

    COMMIT;
END //


-- -----------------------------------------------------------------------------
-- PROCEDURE 2: sp_fr4_reserve_stock_for_shipment (FR4.3, FR4.7)
-- Atomically reserves available stock for a confirmed booking
-- -----------------------------------------------------------------------------
CREATE PROCEDURE `sp_fr4_reserve_stock_for_shipment`(
    IN p_shipment_id INT,
    IN p_container_id INT,
    IN p_product_id INT,
    IN p_reserve_qty INT
)
BEGIN
    DECLARE v_unallocated_stock_id INT;
    DECLARE v_available_qty INT DEFAULT 0;
    DECLARE v_new_total_balance INT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    -- Find unallocated warehouse stock
    SELECT stock_id, quantity 
    INTO v_unallocated_stock_id, v_available_qty
    FROM stock 
    WHERE product_id = p_product_id AND shipment_id IS NULL
    FOR UPDATE;

    IF v_available_qty < p_reserve_qty THEN
        SIGNAL SQLSTATE '45000' 
            SET MESSAGE_TEXT = 'Insufficient unallocated stock to reserve for shipment';
    END IF;

    -- Deduct from unallocated warehouse stock
    UPDATE stock 
    SET quantity = quantity - p_reserve_qty 
    WHERE stock_id = v_unallocated_stock_id;

    -- Create shipment-linked reservation row
    INSERT INTO stock (product_id, shipment_id, container_id, quantity, damaged_qty)
    VALUES (p_product_id, p_shipment_id, p_container_id, p_reserve_qty, 0);

    -- Compute balance after
    SELECT SUM(quantity) INTO v_new_total_balance 
    FROM stock 
    WHERE product_id = p_product_id;

    -- Record dispatch/reserve to ledger
    INSERT INTO inventory_ledger (stock_id, product_id, txn_type, quantity, balance_after, reference_type, reference_id, txn_time)
    VALUES (v_unallocated_stock_id, p_product_id, 'OUT', p_reserve_qty, v_new_total_balance, 'SHIPMENT', p_shipment_id, CURRENT_TIMESTAMP);

    COMMIT;
END //


-- -----------------------------------------------------------------------------
-- PROCEDURE 3: sp_fr4_record_damaged_stock (FR4.5)
-- Moves damaged quantity from available to damaged_qty and logs to ledger
-- -----------------------------------------------------------------------------
CREATE PROCEDURE `sp_fr4_record_damaged_stock`(
    IN p_stock_id INT,
    IN p_damaged_count INT,
    IN p_reason VARCHAR(30)
)
BEGIN
    DECLARE v_product_id INT;
    DECLARE v_current_qty INT;
    DECLARE v_new_balance INT;

    START TRANSACTION;

    SELECT product_id, quantity 
    INTO v_product_id, v_current_qty 
    FROM stock 
    WHERE stock_id = p_stock_id 
    FOR UPDATE;

    IF v_current_qty < p_damaged_count THEN
        SIGNAL SQLSTATE '45000' 
            SET MESSAGE_TEXT = 'Damage quantity exceeds available stock';
    END IF;

    UPDATE stock
    SET quantity = quantity - p_damaged_count,
        damaged_qty = damaged_qty + p_damaged_count
    WHERE stock_id = p_stock_id;

    SELECT SUM(quantity) INTO v_new_balance 
    FROM stock 
    WHERE product_id = v_product_id;

    INSERT INTO inventory_ledger (stock_id, product_id, txn_type, quantity, balance_after, reference_type, reference_id, txn_time)
    VALUES (p_stock_id, v_product_id, 'DAMAGE', p_damaged_count, v_new_balance, p_reason, NULL, CURRENT_TIMESTAMP);

    COMMIT;
END //

DELIMITER ;


-- =============================================================================
-- 4. STANDARD CRUD QUERY TEMPLATES (FOR YOUR EVALUATION / VIVA)
-- =============================================================================

/*
-- [CREATE] Add New Product:
INSERT INTO products (sku, product_name, category, hs_code, unit, unit_weight_kg, unit_price, owner_company_id)
VALUES ('SKU-ELEC-009', 'Smart Logistics Sensor', 'Electronics', '851762', 'pcs', 0.450, 4200.00, 1);

-- [READ / VIEW] Filter Stock by Category and Availability:
SELECT * FROM vw_fr4_inventory_summary 
WHERE category = 'Electronics' AND unallocated_available_qty > 0;

-- [UPDATE] Edit Product Metadata (FR4.1):
UPDATE products 
SET unit_price = 4500.00, category = 'Industrial Electronics' 
WHERE product_id = 1 AND owner_company_id = 1;

-- [UPDATE] Adjust Stock Quantity (FR4.7):
UPDATE stock 
SET quantity = 150 
WHERE stock_id = 1 AND shipment_id IS NULL;

-- [DELETE / DEACTIVATE] Soft Delete Product (FR4 Integrity Rule):
-- Products must never be hard deleted if stock or sales transactions reference them!
UPDATE products 
SET is_active = FALSE 
WHERE product_id = 1;
*/

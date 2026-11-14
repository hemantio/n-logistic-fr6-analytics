-- =============================================================================
-- PROJECT: N Logistic Import & Export Platform
-- MODULE:  FR4 - STOCK & INVENTORY DETAILS (SRS v1.0 Section 3.4 & 7.6)
-- FILE:    FR4_STOCK_DETAILS_FIXED.sql
-- TARGET:  MySQL 8.0+ / MariaDB 10.4+ on XAMPP (Database: n_logistic_db)
-- SCOPE:   FR4.1 (Product/Stock Entry), FR4.2 (CSV Upload & Validation),
--          FR4.3 (Stock Reservation), FR4.4 (Shipment Stock Report),
--          FR4.5 (Inventory Ledger Audit), FR4.6 (Non-Negative Stock Rule),
--          FR4.7 (Stock Search, View & Reservation Locking)
-- =============================================================================

CREATE DATABASE IF NOT EXISTS `n_logistic_db`
    DEFAULT CHARACTER SET utf8mb4
    DEFAULT COLLATE utf8mb4_unicode_ci;

USE `n_logistic_db`;

-- Preserve foreign key checks safety
SET @OLD_FOREIGN_KEY_CHECKS = @@FOREIGN_KEY_CHECKS;
SET FOREIGN_KEY_CHECKS = 1;

-- =============================================================================
-- SECTION 1: MASTER & BASE SCHEMA PREREQUISITES
-- =============================================================================

CREATE TABLE IF NOT EXISTS `companies` (
    `company_id`    INT AUTO_INCREMENT PRIMARY KEY,
    `company_name`  VARCHAR(150) NOT NULL,
    `company_type`  ENUM('SELLER','CONSUMER') NOT NULL,
    `gst_number`    VARCHAR(20) UNIQUE,
    `iec_code`      VARCHAR(15) NULL,
    `address`       TEXT NULL,
    `city`          VARCHAR(60) NULL,
    `country`       VARCHAR(60) NULL,
    `created_at`    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `containers` (
    `container_id`      INT AUTO_INCREMENT PRIMARY KEY,
    `container_number`  VARCHAR(15) NOT NULL UNIQUE,
    `seller_id`         INT NOT NULL,
    `container_type`    ENUM('DRY','REEFER','OPEN_TOP','TANK') NOT NULL,
    `size_ft`           TINYINT NULL,
    `status`            ENUM('AVAILABLE','ALLOCATED','IN_TRANSIT','MAINTENANCE') DEFAULT 'AVAILABLE',
    `created_at`        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT `fk_fr4_container_seller` FOREIGN KEY (`seller_id`) REFERENCES `companies`(`company_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `shipment` (
    `shipment_id`   INT AUTO_INCREMENT PRIMARY KEY,
    `shipment_no`   VARCHAR(20) NOT NULL UNIQUE,
    `consumer_id`   INT NOT NULL,
    `seller_id`     INT NOT NULL,
    `container_id`  INT NOT NULL,
    `status`        ENUM('BOOKED','LOADED','DEPARTED','IN_TRANSIT','ARRIVED','CUSTOMS_CLEARED','DELIVERED','CANCELLED') DEFAULT 'BOOKED',
    `created_at`    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT `fk_fr4_shipment_consumer` FOREIGN KEY (`consumer_id`) REFERENCES `companies`(`company_id`),
    CONSTRAINT `fk_fr4_shipment_seller`   FOREIGN KEY (`seller_id`)   REFERENCES `companies`(`company_id`),
    CONSTRAINT `fk_fr4_shipment_container`FOREIGN KEY (`container_id`)REFERENCES `containers`(`container_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================================
-- SECTION 2: FR4 OPERATIONAL TABLES
-- =============================================================================

-- TABLE 1: PRODUCTS (SRS 7.6 / FR4.1, FR4.2)
CREATE TABLE IF NOT EXISTS `products` (
    `product_id`        INT AUTO_INCREMENT PRIMARY KEY,
    `sku`               VARCHAR(40) NOT NULL UNIQUE COMMENT 'Stock Keeping Unit',
    `product_name`      VARCHAR(120) NOT NULL,
    `category`          VARCHAR(60) NULL,
    `hs_code`           VARCHAR(12) NOT NULL COMMENT 'Customs Tariff Code',
    `unit`              VARCHAR(20) NOT NULL COMMENT 'Piece, Box, kg, etc.',
    `unit_weight_kg`    DECIMAL(8,3) NOT NULL DEFAULT 1.000,
    `unit_price`        DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    `unit_cost`         DECIMAL(12,2) NOT NULL DEFAULT 0.00 COMMENT 'Cost of goods',
    `owner_company_id`  INT NOT NULL COMMENT 'Seller company',
    `created_at`        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT `fk_products_owner_company` FOREIGN KEY (`owner_company_id`) REFERENCES `companies`(`company_id`),
    CONSTRAINT `chk_products_weight` CHECK (`unit_weight_kg` >= 0),
    CONSTRAINT `chk_products_price` CHECK (`unit_price` >= 0),
    CONSTRAINT `chk_products_cost` CHECK (`unit_cost` >= 0),
    INDEX `idx_products_sku` (`sku`),
    INDEX `idx_products_owner` (`owner_company_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- TABLE 2: STOCK (SRS 7.6 / FR4.1, FR4.6, FR4.7)
CREATE TABLE IF NOT EXISTS `stock` (
    `stock_id`      INT AUTO_INCREMENT PRIMARY KEY,
    `product_id`    INT NOT NULL,
    `quantity`      INT NOT NULL DEFAULT 0,
    `damaged_qty`   INT NOT NULL DEFAULT 0,
    `last_updated`  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    `created_at`    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT `fk_stock_product` FOREIGN KEY (`product_id`) REFERENCES `products`(`product_id`) ON DELETE CASCADE,
    CONSTRAINT `chk_stock_qty_nonnegative` CHECK (`quantity` >= 0),
    CONSTRAINT `chk_stock_damaged_nonnegative` CHECK (`damaged_qty` >= 0),
    CONSTRAINT `chk_stock_damaged_lte_total` CHECK (`damaged_qty` <= `quantity`),
    INDEX `idx_stock_product` (`product_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- TABLE 3: SHIPMENT ITEMS (SRS 7.4 / FR4.3)
CREATE TABLE IF NOT EXISTS `shipment_items` (
    `item_id`       INT AUTO_INCREMENT PRIMARY KEY,
    `shipment_id`   INT NOT NULL,
    `product_id`    INT NOT NULL,
    `quantity`      INT NOT NULL,
    `unit_price`    DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    `weight_kg`     DECIMAL(10,2) NULL,
    `volume_cbm`    DECIMAL(8,2) NULL,
    `amount`        DECIMAL(14,2) NOT NULL DEFAULT 0.00,
    `created_at`    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT `fk_si_shipment` FOREIGN KEY (`shipment_id`) REFERENCES `shipment`(`shipment_id`) ON DELETE CASCADE,
    CONSTRAINT `fk_si_product`  FOREIGN KEY (`product_id`)  REFERENCES `products`(`product_id`),
    CONSTRAINT `chk_si_quantity` CHECK (`quantity` > 0),
    INDEX `idx_shipment_items_shipment` (`shipment_id`),
    INDEX `idx_shipment_items_product`  (`product_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- TABLE 4: INVENTORY LEDGER (SRS 7.6 / FR4.5)
CREATE TABLE IF NOT EXISTS `inventory_ledger` (
    `ledger_id`       BIGINT AUTO_INCREMENT PRIMARY KEY,
    `stock_id`        INT NOT NULL,
    `product_id`      INT NOT NULL,
    `txn_type`        ENUM('IN','OUT','DAMAGE','ADJUST','CLAIM_LOSS') NOT NULL,
    `quantity`        INT NOT NULL,
    `balance_after`   INT NOT NULL,
    `reference_type`  VARCHAR(30) NULL COMMENT 'INITIAL_STOCK, SHIPMENT, ADJUSTMENT, etc.',
    `reference_id`    BIGINT NULL,
    `txn_time`        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT `fk_ledger_stock`   FOREIGN KEY (`stock_id`)   REFERENCES `stock`(`stock_id`),
    CONSTRAINT `fk_ledger_product` FOREIGN KEY (`product_id`) REFERENCES `products`(`product_id`),
    CONSTRAINT `chk_ledger_qty`    CHECK (`quantity` > 0),
    CONSTRAINT `chk_ledger_bal`    CHECK (`balance_after` >= 0),
    INDEX `idx_ledger_product` (`product_id`),
    INDEX `idx_ledger_time` (`txn_time`),
    INDEX `idx_ledger_stock` (`stock_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- TABLE 5: STOCK UPLOAD STAGING (FR4.2 CSV/EXCEL BATCH INTAKE)
CREATE TABLE IF NOT EXISTS `stock_upload_staging` (
    `row_id`         INT AUTO_INCREMENT PRIMARY KEY,
    `sku`            VARCHAR(40) NULL,
    `product_name`   VARCHAR(120) NULL,
    `hs_code`        VARCHAR(12) NULL,
    `unit`           VARCHAR(20) NULL,
    `weight_text`    VARCHAR(30) NULL,
    `price_text`     VARCHAR(30) NULL,
    `quantity_text`  VARCHAR(30) NULL,
    `row_status`     ENUM('PENDING','VALID','ERROR','IMPORTED') NOT NULL DEFAULT 'PENDING',
    `error_message`  VARCHAR(255) NULL,
    `created_at`     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_upload_sku` (`sku`),
    INDEX `idx_upload_status` (`row_status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================================
-- SECTION 3: AUTOMATED INVENTORY LEDGER TRIGGERS (FR4.5)
-- =============================================================================

DROP TRIGGER IF EXISTS `trg_stock_before_update`;
DROP TRIGGER IF EXISTS `trg_stock_after_insert`;
DROP TRIGGER IF EXISTS `trg_stock_after_update`;

DELIMITER //

-- Enforce separate adjustments so damaged goods and total stock have distinct audit entries
CREATE TRIGGER `trg_stock_before_update`
BEFORE UPDATE ON `stock`
FOR EACH ROW
BEGIN
    IF NEW.quantity <> OLD.quantity AND NEW.damaged_qty <> OLD.damaged_qty THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Update stock total quantity and damaged quantity in separate transactions';
    END IF;
END//

-- Record initial stock in inventory ledger
CREATE TRIGGER `trg_stock_after_insert`
AFTER INSERT ON `stock`
FOR EACH ROW
BEGIN
    IF NEW.quantity > 0 THEN
        INSERT INTO `inventory_ledger`
            (`stock_id`, `product_id`, `txn_type`, `quantity`, `balance_after`, `reference_type`, `reference_id`)
        VALUES
            (NEW.stock_id, NEW.product_id, 'IN', NEW.quantity, NEW.quantity, 'INITIAL_STOCK', NEW.stock_id);
    END IF;

    IF NEW.damaged_qty > 0 THEN
        INSERT INTO `inventory_ledger`
            (`stock_id`, `product_id`, `txn_type`, `quantity`, `balance_after`, `reference_type`, `reference_id`)
        VALUES
            (NEW.stock_id, NEW.product_id, 'DAMAGE', NEW.damaged_qty, NEW.quantity - NEW.damaged_qty, 'INITIAL_DAMAGE', NEW.stock_id);
    END IF;
END//

-- Record all quantity adjustments, receipts, dispatches, and damage updates
CREATE TRIGGER `trg_stock_after_update`
AFTER UPDATE ON `stock`
FOR EACH ROW
BEGIN
    -- Handle total stock adjustments
    IF NEW.quantity <> OLD.quantity THEN
        INSERT INTO `inventory_ledger`
            (`stock_id`, `product_id`, `txn_type`, `quantity`, `balance_after`, `reference_type`, `reference_id`)
        VALUES
            (NEW.stock_id, NEW.product_id, COALESCE(@fr4_txn_type, 'ADJUST'),
             ABS(NEW.quantity - OLD.quantity), NEW.quantity - NEW.damaged_qty, 'STOCK_UPDATE', NEW.stock_id);
    END IF;

    -- Handle damaged stock adjustments
    IF NEW.damaged_qty <> OLD.damaged_qty THEN
        INSERT INTO `inventory_ledger`
            (`stock_id`, `product_id`, `txn_type`, `quantity`, `balance_after`, `reference_type`, `reference_id`)
        VALUES
            (NEW.stock_id, NEW.product_id, IF(NEW.damaged_qty > OLD.damaged_qty, 'DAMAGE', 'ADJUST'),
             ABS(NEW.damaged_qty - OLD.damaged_qty), NEW.quantity - NEW.damaged_qty, 'DAMAGE_UPDATE', NEW.stock_id);
    END IF;
END//

DELIMITER ;

-- =============================================================================
-- SECTION 4: FR4 STORED PROCEDURES
-- =============================================================================

DROP PROCEDURE IF EXISTS `sp_add_product`;
DROP PROCEDURE IF EXISTS `sp_add_stock`;
DROP PROCEDURE IF EXISTS `sp_update_stock`;
DROP PROCEDURE IF EXISTS `sp_damage_stock`;
DROP PROCEDURE IF EXISTS `sp_book_stock`;
DROP PROCEDURE IF EXISTS `sp_issue_stock`;
DROP PROCEDURE IF EXISTS `sp_shipment_stock_report`;
DROP PROCEDURE IF EXISTS `sp_show_stock`;
DROP PROCEDURE IF EXISTS `sp_search_stock`;
DROP PROCEDURE IF EXISTS `sp_view_inventory_ledger`;
DROP PROCEDURE IF EXISTS `sp_validate_stock_upload`;
DROP PROCEDURE IF EXISTS `sp_import_valid_upload`;

DELIMITER //

-- -----------------------------------------------------------------------------
-- 4.1 ADD PRODUCT (FR4.1)
-- -----------------------------------------------------------------------------
CREATE PROCEDURE `sp_add_product`(
    IN p_sku VARCHAR(40),
    IN p_product_name VARCHAR(120),
    IN p_category VARCHAR(60),
    IN p_hs_code VARCHAR(12),
    IN p_unit VARCHAR(20),
    IN p_weight DECIMAL(8,3),
    IN p_price DECIMAL(12,2),
    IN p_cost DECIMAL(12,2),
    IN p_owner_company_id INT
)
BEGIN
    IF p_sku IS NULL OR TRIM(p_sku) = ''
       OR p_product_name IS NULL OR TRIM(p_product_name) = ''
       OR p_hs_code IS NULL OR TRIM(p_hs_code) = ''
       OR p_unit IS NULL OR TRIM(p_unit) = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Mandatory product fields cannot be empty';
    END IF;

    IF p_weight IS NULL OR p_weight < 0 OR p_price IS NULL OR p_price < 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Weight and price must be non-negative';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM companies WHERE company_id = p_owner_company_id AND company_type = 'SELLER'
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Valid seller company not found';
    END IF;

    INSERT INTO `products`
        (`sku`, `product_name`, `category`, `hs_code`, `unit`, `unit_weight_kg`, `unit_price`, `unit_cost`, `owner_company_id`)
    VALUES
        (TRIM(p_sku), TRIM(p_product_name), TRIM(p_category), TRIM(p_hs_code), TRIM(p_unit),
         p_weight, p_price, COALESCE(p_cost, 0.00), p_owner_company_id);

    SELECT * FROM `products` WHERE `product_id` = LAST_INSERT_ID();
END//

-- -----------------------------------------------------------------------------
-- 4.2 ADD STOCK (FR4.1)
-- -----------------------------------------------------------------------------
CREATE PROCEDURE `sp_add_stock`(
    IN p_product_id INT,
    IN p_quantity INT
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SET @fr4_txn_type = NULL;
        RESIGNAL;
    END;

    IF p_quantity <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Stock quantity must be positive';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM `products` WHERE `product_id` = p_product_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Product not found in catalog';
    END IF;

    SET @fr4_txn_type = 'IN';

    IF EXISTS (SELECT 1 FROM `stock` WHERE `product_id` = p_product_id) THEN
        UPDATE `stock`
        SET `quantity` = `quantity` + p_quantity
        WHERE `product_id` = p_product_id;
    ELSE
        INSERT INTO `stock` (`product_id`, `quantity`, `damaged_qty`)
        VALUES (p_product_id, p_quantity, 0);
    END IF;

    SET @fr4_txn_type = NULL;
END//

-- -----------------------------------------------------------------------------
-- 4.3 UPDATE STOCK (FR4.6, FR4.7)
-- Enforces: Quantity cannot be reduced below damaged + reserved quantity
-- -----------------------------------------------------------------------------
CREATE PROCEDURE `sp_update_stock`(
    IN p_stock_id INT,
    IN p_quantity INT
)
BEGIN
    DECLARE v_product_id INT DEFAULT NULL;
    DECLARE v_damaged INT DEFAULT 0;
    DECLARE v_reserved INT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SET @fr4_txn_type = NULL;
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    IF p_quantity < 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Negative stock is not permitted (FR4.6)';
    END IF;

    SELECT `product_id`, `damaged_qty` INTO v_product_id, v_damaged
    FROM `stock` WHERE `stock_id` = p_stock_id FOR UPDATE;

    IF v_product_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Stock record not found';
    END IF;

    -- Calculate total booked/reserved quantity for this product in active shipments
    SELECT COALESCE(SUM(si.quantity), 0) INTO v_reserved
    FROM `shipment_items` si
    JOIN `shipment` sh ON sh.shipment_id = si.shipment_id
    WHERE si.product_id = v_product_id
      AND sh.status IN ('BOOKED','LOADED','DEPARTED','IN_TRANSIT');

    IF p_quantity < (v_damaged + v_reserved) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Cannot reduce stock below damaged plus already reserved quantity (FR4.7)';
    END IF;

    SET @fr4_txn_type = 'ADJUST';

    UPDATE `stock`
    SET `quantity` = p_quantity
    WHERE `stock_id` = p_stock_id;

    SET @fr4_txn_type = NULL;

    COMMIT;
END//

-- -----------------------------------------------------------------------------
-- 4.4 DAMAGE STOCK (FR4.5)
-- -----------------------------------------------------------------------------
CREATE PROCEDURE `sp_damage_stock`(
    IN p_stock_id INT,
    IN p_damage_qty INT
)
BEGIN
    DECLARE v_product_id INT DEFAULT NULL;
    DECLARE v_quantity INT DEFAULT 0;
    DECLARE v_damaged INT DEFAULT 0;
    DECLARE v_reserved INT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    IF p_damage_qty <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Damage quantity must be positive';
    END IF;

    SELECT `product_id`, `quantity`, `damaged_qty` INTO v_product_id, v_quantity, v_damaged
    FROM `stock` WHERE `stock_id` = p_stock_id FOR UPDATE;

    IF v_product_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Stock record not found';
    END IF;

    SELECT COALESCE(SUM(si.quantity), 0) INTO v_reserved
    FROM `shipment_items` si
    JOIN `shipment` sh ON sh.shipment_id = si.shipment_id
    WHERE si.product_id = v_product_id
      AND sh.status IN ('BOOKED','LOADED','DEPARTED','IN_TRANSIT');

    IF p_damage_qty > (v_quantity - v_damaged - v_reserved) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Insufficient unreserved stock to mark as damaged';
    END IF;

    UPDATE `stock`
    SET `damaged_qty` = `damaged_qty` + p_damage_qty
    WHERE `stock_id` = p_stock_id;

    COMMIT;
END//

-- -----------------------------------------------------------------------------
-- 4.5 BOOK STOCK FOR SHIPMENT (FR4.3)
-- -----------------------------------------------------------------------------
CREATE PROCEDURE `sp_book_stock`(
    IN p_shipment_id INT,
    IN p_stock_id INT,
    IN p_booked_quantity INT
)
BEGIN
    DECLARE v_product_id INT DEFAULT NULL;
    DECLARE v_quantity INT DEFAULT 0;
    DECLARE v_damaged INT DEFAULT 0;
    DECLARE v_reserved INT DEFAULT 0;
    DECLARE v_unit_price DECIMAL(12,2) DEFAULT 0.00;
    DECLARE v_weight_kg DECIMAL(8,3) DEFAULT 1.000;
    DECLARE v_shipment_seller INT DEFAULT NULL;
    DECLARE v_owner_seller INT DEFAULT NULL;
    DECLARE v_status VARCHAR(20) DEFAULT NULL;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    IF p_booked_quantity <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Booked quantity must be positive';
    END IF;

    SELECT `seller_id`, `status`
    INTO v_shipment_seller, v_status
    FROM `shipment` WHERE `shipment_id` = p_shipment_id FOR UPDATE;

    IF v_status IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Shipment not found';
    END IF;

    IF v_status <> 'BOOKED' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Shipment is not open for booking';
    END IF;

    SELECT s.product_id, s.quantity, s.damaged_qty, p.unit_price, p.unit_weight_kg, p.owner_company_id
    INTO v_product_id, v_quantity, v_damaged, v_unit_price, v_weight_kg, v_owner_seller
    FROM `stock` s
    JOIN `products` p ON p.product_id = s.product_id
    WHERE s.stock_id = p_stock_id FOR UPDATE;

    IF v_product_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Stock not found';
    END IF;

    IF v_owner_seller <> v_shipment_seller THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Product does not belong to the shipment seller';
    END IF;

    SELECT COALESCE(SUM(si.quantity), 0) INTO v_reserved
    FROM `shipment_items` si
    JOIN `shipment` sh ON sh.shipment_id = si.shipment_id
    WHERE si.product_id = v_product_id
      AND sh.status IN ('BOOKED','LOADED','DEPARTED','IN_TRANSIT');

    IF p_booked_quantity > (v_quantity - v_damaged - v_reserved) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Insufficient available stock to complete booking';
    END IF;

    -- SRS-compliant shipment item insertion (quantity, unit_price, weight, amount)
    INSERT INTO `shipment_items`
        (`shipment_id`, `product_id`, `quantity`, `unit_price`, `weight_kg`, `amount`)
    VALUES
        (p_shipment_id, v_product_id, p_booked_quantity, v_unit_price,
         p_booked_quantity * v_weight_kg, p_booked_quantity * v_unit_price);

    COMMIT;
END//

-- -----------------------------------------------------------------------------
-- 4.6 ISSUE / DISPATCH STOCK (FR4.5)
-- -----------------------------------------------------------------------------
CREATE PROCEDURE `sp_issue_stock`(
    IN p_stock_id INT,
    IN p_issue_qty INT
)
BEGIN
    DECLARE v_product_id INT DEFAULT NULL;
    DECLARE v_quantity INT DEFAULT 0;
    DECLARE v_damaged INT DEFAULT 0;
    DECLARE v_reserved INT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SET @fr4_txn_type = NULL;
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    IF p_issue_qty <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Issue quantity must be positive';
    END IF;

    SELECT `product_id`, `quantity`, `damaged_qty` INTO v_product_id, v_quantity, v_damaged
    FROM `stock` WHERE `stock_id` = p_stock_id FOR UPDATE;

    IF v_product_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Stock record not found';
    END IF;

    SELECT COALESCE(SUM(si.quantity), 0) INTO v_reserved
    FROM `shipment_items` si
    JOIN `shipment` sh ON sh.shipment_id = si.shipment_id
    WHERE si.product_id = v_product_id
      AND sh.status IN ('BOOKED','LOADED','DEPARTED','IN_TRANSIT');

    IF p_issue_qty > (v_quantity - v_damaged - v_reserved) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Insufficient unreserved stock for dispatch';
    END IF;

    SET @fr4_txn_type = 'OUT';

    UPDATE `stock`
    SET `quantity` = `quantity` - p_issue_qty
    WHERE `stock_id` = p_stock_id;

    SET @fr4_txn_type = NULL;

    COMMIT;
END//

-- -----------------------------------------------------------------------------
-- 4.7 SHIPMENT STOCK REPORT (FR4.4)
-- -----------------------------------------------------------------------------
CREATE PROCEDURE `sp_shipment_stock_report`(
    IN p_shipment_id INT
)
BEGIN
    -- Detailed item lines
    SELECT
        sh.shipment_id,
        sh.shipment_no,
        p.sku,
        p.product_name,
        p.unit,
        si.quantity,
        si.unit_price,
        si.amount AS shipment_stock_value
    FROM `shipment_items` si
    JOIN `shipment` sh ON sh.shipment_id = si.shipment_id
    JOIN `products` p ON p.product_id = si.product_id
    WHERE sh.shipment_id = p_shipment_id;

    -- Aggregate totals
    SELECT
        sh.shipment_id,
        sh.shipment_no,
        COALESCE(SUM(si.quantity), 0) AS total_shipment_quantity,
        COALESCE(SUM(si.amount), 0.00) AS total_shipment_value
    FROM `shipment` sh
    LEFT JOIN `shipment_items` si ON si.shipment_id = sh.shipment_id
    WHERE sh.shipment_id = p_shipment_id
    GROUP BY sh.shipment_id, sh.shipment_no;
END//

-- -----------------------------------------------------------------------------
-- 4.8 SHOW STOCK REPORT (FR4.7)
-- Available = Quantity - Damaged - Active Reservations
-- -----------------------------------------------------------------------------
CREATE PROCEDURE `sp_show_stock`()
BEGIN
    SELECT
        s.stock_id,
        p.sku,
        p.product_name,
        p.hs_code,
        p.unit,
        s.quantity AS total_quantity,
        s.damaged_qty,
        COALESCE(r.reserved_quantity, 0) AS reserved_quantity,
        (s.quantity - s.damaged_qty - COALESCE(r.reserved_quantity, 0)) AS available_quantity,
        p.unit_price,
        ((s.quantity - s.damaged_qty) * p.unit_price) AS stock_value,
        s.last_updated
    FROM `stock` s
    JOIN `products` p ON p.product_id = s.product_id
    LEFT JOIN (
        SELECT si.product_id, SUM(si.quantity) AS reserved_quantity
        FROM `shipment_items` si
        JOIN `shipment` sh ON sh.shipment_id = si.shipment_id
        WHERE sh.status IN ('BOOKED','LOADED','DEPARTED','IN_TRANSIT')
        GROUP BY si.product_id
    ) r ON r.product_id = s.product_id
    ORDER BY s.stock_id;
END//

-- -----------------------------------------------------------------------------
-- 4.9 SEARCH STOCK (FR4.7)
-- -----------------------------------------------------------------------------
CREATE PROCEDURE `sp_search_stock`(
    IN p_search VARCHAR(120)
)
BEGIN
    SELECT
        s.stock_id,
        p.sku,
        p.product_name,
        p.hs_code,
        p.unit,
        s.quantity AS total_quantity,
        s.damaged_qty,
        COALESCE(r.reserved_quantity, 0) AS reserved_quantity,
        (s.quantity - s.damaged_qty - COALESCE(r.reserved_quantity, 0)) AS available_quantity,
        p.unit_price
    FROM `stock` s
    JOIN `products` p ON p.product_id = s.product_id
    LEFT JOIN (
        SELECT si.product_id, SUM(si.quantity) AS reserved_quantity
        FROM `shipment_items` si
        JOIN `shipment` sh ON sh.shipment_id = si.shipment_id
        WHERE sh.status IN ('BOOKED','LOADED','DEPARTED','IN_TRANSIT')
        GROUP BY si.product_id
    ) r ON r.product_id = s.product_id
    WHERE p_search IS NOT NULL
      AND (
          p.sku LIKE CONCAT('%', p_search, '%')
          OR p.product_name LIKE CONCAT('%', p_search, '%')
          OR s.stock_id = CAST(p_search AS SIGNED)
      )
    ORDER BY s.stock_id;
END//

-- -----------------------------------------------------------------------------
-- 4.10 VIEW INVENTORY LEDGER (FR4.5)
-- -----------------------------------------------------------------------------
CREATE PROCEDURE `sp_view_inventory_ledger`(
    IN p_stock_id INT
)
BEGIN
    SELECT
        l.ledger_id,
        l.stock_id,
        p.sku,
        p.product_name,
        l.txn_type,
        l.quantity,
        l.balance_after,
        l.reference_type,
        l.reference_id,
        l.txn_time
    FROM `inventory_ledger` l
    JOIN `products` p ON p.product_id = l.product_id
    WHERE p_stock_id IS NULL OR l.stock_id = p_stock_id
    ORDER BY l.txn_time DESC, l.ledger_id DESC;
END//

-- -----------------------------------------------------------------------------
-- 4.11 CSV/EXCEL UPLOAD VALIDATION (FR4.2)
-- -----------------------------------------------------------------------------
CREATE PROCEDURE `sp_validate_stock_upload`()
BEGIN
    -- Reset pending validation results
    UPDATE `stock_upload_staging`
    SET `row_status` = 'VALID', `error_message` = NULL
    WHERE `row_status` <> 'IMPORTED';

    -- Mandatory fields check
    UPDATE `stock_upload_staging`
    SET `row_status` = 'ERROR',
        `error_message` = 'Mandatory fields are missing'
    WHERE `row_status` = 'VALID'
      AND (
        sku IS NULL OR TRIM(sku) = ''
        OR product_name IS NULL OR TRIM(product_name) = ''
        OR hs_code IS NULL OR TRIM(hs_code) = ''
        OR unit IS NULL OR TRIM(unit) = ''
        OR weight_text IS NULL OR TRIM(weight_text) = ''
        OR price_text IS NULL OR TRIM(price_text) = ''
        OR quantity_text IS NULL OR TRIM(quantity_text) = ''
      );

    -- Numeric format validation
    UPDATE `stock_upload_staging`
    SET `row_status` = 'ERROR',
        `error_message` = 'Invalid numeric format for weight, price, or quantity'
    WHERE `row_status` = 'VALID'
      AND (
        TRIM(weight_text) NOT REGEXP '^[0-9]+([.][0-9]+)?$'
        OR TRIM(price_text) NOT REGEXP '^[0-9]+([.][0-9]+)?$'
        OR TRIM(quantity_text) NOT REGEXP '^[0-9]+$'
      );

    -- Non-negative and limit validation
    UPDATE `stock_upload_staging`
    SET `row_status` = 'ERROR',
        `error_message` = 'Quantity must be positive; weight and price must be non-negative'
    WHERE `row_status` = 'VALID'
      AND (
        CAST(weight_text AS DECIMAL(12,3)) > 99999.999
        OR CAST(price_text AS DECIMAL(14,2)) > 9999999999.99
        OR CAST(quantity_text AS UNSIGNED) = 0
        OR CAST(quantity_text AS UNSIGNED) > 2147483647
      );

    -- Duplicate SKU check against existing product catalog
    UPDATE `stock_upload_staging` u
    JOIN `products` p ON p.sku = u.sku
    SET u.row_status = 'ERROR',
        u.error_message = 'SKU already exists in catalog'
    WHERE u.row_status = 'VALID';

    -- Duplicate SKU check inside staging file
    UPDATE `stock_upload_staging` u
    JOIN (
        SELECT sku FROM `stock_upload_staging`
        WHERE sku IS NOT NULL AND TRIM(sku) <> '' AND row_status <> 'IMPORTED'
        GROUP BY sku HAVING COUNT(*) > 1
    ) d ON d.sku = u.sku
    SET u.row_status = 'ERROR',
        u.error_message = 'Duplicate SKU inside uploaded file'
    WHERE u.row_status = 'VALID';

    -- Display row-level validation report (FR4.2)
    SELECT `row_id`, `sku`, `product_name`, `row_status`, `error_message`
    FROM `stock_upload_staging`
    ORDER BY `row_id`;
END//

-- -----------------------------------------------------------------------------
-- 4.12 IMPORT VALID CSV UPLOAD ROWS (FR4.2)
-- -----------------------------------------------------------------------------
CREATE PROCEDURE `sp_import_valid_upload`(
    IN p_owner_company_id INT
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    IF NOT EXISTS (
        SELECT 1 FROM `companies` WHERE `company_id` = p_owner_company_id AND `company_type` = 'SELLER'
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Valid seller company not found';
    END IF;

    -- Import new valid products
    INSERT INTO `products`
        (`sku`, `product_name`, `hs_code`, `unit`, `unit_weight_kg`, `unit_price`, `owner_company_id`)
    SELECT
        TRIM(sku), TRIM(product_name), TRIM(hs_code), TRIM(unit),
        CAST(weight_text AS DECIMAL(8,3)),
        CAST(price_text AS DECIMAL(12,2)),
        p_owner_company_id
    FROM `stock_upload_staging`
    WHERE `row_status` = 'VALID';

    -- Import corresponding stock
    INSERT INTO `stock` (`product_id`, `quantity`, `damaged_qty`)
    SELECT
        p.product_id,
        CAST(u.quantity_text AS UNSIGNED),
        0
    FROM `stock_upload_staging` u
    JOIN `products` p ON p.sku = u.sku
    WHERE u.row_status = 'VALID';

    -- Mark imported records
    UPDATE `stock_upload_staging`
    SET `row_status` = 'IMPORTED', `error_message` = NULL
    WHERE `row_status` = 'VALID';

    COMMIT;

    SELECT 'Import completed successfully' AS result, COUNT(*) AS imported_rows
    FROM `stock_upload_staging` WHERE `row_status` = 'IMPORTED';
END//

DELIMITER ;

-- Restore foreign key checks
SET FOREIGN_KEY_CHECKS = @OLD_FOREIGN_KEY_CHECKS;

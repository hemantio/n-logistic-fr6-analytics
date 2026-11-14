-- =============================================================================
-- PROJECT: N Logistic Import & Export Platform
-- MODULE:  FR4 - STOCK & INVENTORY MANAGEMENT (SRS v1.0 Section 7.6)
-- FILE:    FR4_STOCK_DETAILS_FIXED.sql
-- TARGET:  MySQL 8.0+ / MariaDB 10.4+ on XAMPP (Database: n_logistic_db)
-- SCOPE:   STRICTLY IMPLEMENTS THE 4 OFFICIAL ENTITIES OF SRS SECTION 7.6:
--            1. products (SRS Section 7.6 / ERD #14)
--            2. stock (SRS Section 7.6 / ERD #15)
--            3. inventory_ledger (SRS Section 7.6 / ERD #16)
--            4. sales_transactions (SRS Section 7.6 / ERD #17)
-- NOTE:    'companies', 'containers', and 'shipment' are referenced as foreign
--          keys but are OWNED by FR1 (Section 7.3) and FR2/FR3 (Section 7.4).
-- =============================================================================

USE `n_logistic_db`;

SET @OLD_FOREIGN_KEY_CHECKS = @@FOREIGN_KEY_CHECKS;
SET FOREIGN_KEY_CHECKS = 0;

-- =============================================================================
-- SECTION 1: THE 4 CORE TABLES OF SRS SECTION 7.6
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1.1 PRODUCTS (SRS Section 7.6 / ERD #24)
-- Catalog of goods managed by the Seller (FR4.1)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `products` (
    `product_id`        INT AUTO_INCREMENT PRIMARY KEY,
    `sku`               VARCHAR(40) NOT NULL UNIQUE COMMENT 'Stock Keeping Unit',
    `product_name`      VARCHAR(120) NOT NULL,
    `category`          VARCHAR(60) NULL,
    `hs_code`           VARCHAR(12) NOT NULL COMMENT 'Customs Tariff Code (HS Code)',
    `unit`              VARCHAR(20) NOT NULL COMMENT 'Piece, Box, kg, Pallet',
    `unit_weight_kg`    DECIMAL(8, 3) NOT NULL DEFAULT 1.000,
    `unit_price`        DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    `unit_cost`         DECIMAL(12, 2) NOT NULL DEFAULT 0.00 COMMENT 'Cost of goods',
    `owner_company_id`  INT NOT NULL COMMENT 'FK to companies (Seller)',
    `is_active`         BOOLEAN NOT NULL DEFAULT TRUE COMMENT 'Soft delete flag',
    `created_at`        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT `fk_products_owner_company`
        FOREIGN KEY (`owner_company_id`) REFERENCES `companies`(`company_id`)
        ON DELETE RESTRICT ON UPDATE CASCADE,

    CONSTRAINT `chk_products_weight` CHECK (`unit_weight_kg` >= 0),
    CONSTRAINT `chk_products_price`  CHECK (`unit_price` >= 0),
    CONSTRAINT `chk_products_cost`   CHECK (`unit_cost` >= 0),

    INDEX `idx_products_sku` (`sku`),
    INDEX `idx_products_owner` (`owner_company_id`),
    INDEX `idx_products_active` (`is_active`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- -----------------------------------------------------------------------------
-- 1.2 STOCK (SRS Section 7.6 / ERD #15)
-- Physical inventory quantity, allocations, and damaged stock (FR4.1, FR4.6)
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

    CONSTRAINT `fk_stock_product`
        FOREIGN KEY (`product_id`) REFERENCES `products`(`product_id`)
        ON DELETE CASCADE ON UPDATE CASCADE,

    CONSTRAINT `fk_stock_shipment`
        FOREIGN KEY (`shipment_id`) REFERENCES `shipment`(`shipment_id`)
        ON DELETE SET NULL ON UPDATE CASCADE,

    CONSTRAINT `fk_stock_container`
        FOREIGN KEY (`container_id`) REFERENCES `containers`(`container_id`)
        ON DELETE SET NULL ON UPDATE CASCADE,

    CONSTRAINT `chk_stock_qty_nonnegative`     CHECK (`quantity` >= 0),
    CONSTRAINT `chk_stock_damaged_nonnegative` CHECK (`damaged_qty` >= 0),
    CONSTRAINT `chk_stock_damaged_lte_total`   CHECK (`damaged_qty` <= `quantity`),

    INDEX `idx_stock_product` (`product_id`),
    INDEX `idx_stock_shipment` (`shipment_id`),
    INDEX `idx_stock_container` (`container_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- -----------------------------------------------------------------------------
-- 1.3 INVENTORY_LEDGER (SRS Section 7.6 / ERD #25)
-- Immutable double-entry audit journal for all stock movements (FR4.5)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `inventory_ledger` (
    `ledger_id`       BIGINT AUTO_INCREMENT PRIMARY KEY,
    `stock_id`        INT NOT NULL,
    `product_id`      INT NOT NULL,
    `txn_type`        ENUM('IN', 'OUT', 'DAMAGE', 'ADJUST', 'CLAIM_LOSS') NOT NULL,
    `quantity`        INT NOT NULL COMMENT 'Movement magnitude',
    `balance_after`   INT NOT NULL COMMENT 'Running physical balance',
    `reference_type`  VARCHAR(30) NULL COMMENT 'SHIPMENT, CLAIM, UPLOAD, MANUAL',
    `reference_id`    BIGINT NULL COMMENT 'shipment_id, claim_id, etc.',
    `txn_time`        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT `fk_ledger_stock`
        FOREIGN KEY (`stock_id`) REFERENCES `stock`(`stock_id`)
        ON DELETE CASCADE ON UPDATE CASCADE,

    CONSTRAINT `fk_ledger_product`
        FOREIGN KEY (`product_id`) REFERENCES `products`(`product_id`)
        ON DELETE CASCADE ON UPDATE CASCADE,

    CONSTRAINT `chk_ledger_qty` CHECK (`quantity` > 0),
    CONSTRAINT `chk_ledger_bal` CHECK (`balance_after` >= 0),

    INDEX `idx_ledger_product_time` (`product_id`, `txn_time`),
    INDEX `idx_ledger_stock` (`stock_id`),
    INDEX `idx_ledger_ref` (`reference_type`, `reference_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- -----------------------------------------------------------------------------
-- 1.4 SALES_TRANSACTIONS (SRS Section 7.6 / ERD #23)
-- Customer product purchases linked to confirmed shipments
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

    CONSTRAINT `fk_st_product`
        FOREIGN KEY (`product_id`) REFERENCES `products`(`product_id`)
        ON DELETE CASCADE ON UPDATE CASCADE,

    CONSTRAINT `fk_st_customer`
        FOREIGN KEY (`customer_id`) REFERENCES `customers`(`customer_id`)
        ON DELETE RESTRICT ON UPDATE CASCADE,

    CONSTRAINT `fk_st_shipment`
        FOREIGN KEY (`shipment_id`) REFERENCES `shipment`(`shipment_id`)
        ON DELETE SET NULL ON UPDATE CASCADE,

    CONSTRAINT `chk_st_quantity` CHECK (`quantity` > 0),
    CONSTRAINT `chk_st_amount`   CHECK (`total_amount` >= 0),

    INDEX `idx_sales_product` (`product_id`),
    INDEX `idx_sales_customer` (`customer_id`),
    INDEX `idx_sales_date` (`sale_date`),
    INDEX `idx_sales_shipment` (`shipment_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

SET FOREIGN_KEY_CHECKS = @OLD_FOREIGN_KEY_CHECKS;

-- =============================================================================
-- SECTION 2: AUTOMATED INVENTORY LEDGER TRIGGERS (FR4.5)
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

DELIMITER ;

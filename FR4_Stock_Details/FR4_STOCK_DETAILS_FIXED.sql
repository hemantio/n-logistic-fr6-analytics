-- =============================================================================
-- PROJECT: N Logistic Import & Export Platform
-- MODULE:  FR4 - STOCK & INVENTORY MANAGEMENT (SRS v1.0 Section 7.6)
-- FILE:    FR4_STOCK_DETAILS_FIXED.sql
-- TARGET:  MySQL 8.0+ / MariaDB 10.4+ on XAMPP (Database: n_logistic_db)
-- SCOPE:   COMPLETE & CONSOLIDATED IMPLEMENTATION OF SRS SECTION 7.6 (FR4.1–FR4.7):
--            1. products (SRS Section 7.6 / ERD #14)
--            2. stock (SRS Section 7.6 / ERD #15)
--            3. inventory_ledger (SRS Section 7.6 / ERD #16)
--            4. sales_transactions (SRS Section 7.6 / ERD #17)
--          Plus FR4.2 CSV/Excel Bulk Upload Staging: stock_upload_staging
--          Plus Single Authoritative Reservation Seam: shipment_stock_reservations
-- =============================================================================

USE `n_logistic_db`;

SET @OLD_FOREIGN_KEY_CHECKS = @@FOREIGN_KEY_CHECKS;
SET FOREIGN_KEY_CHECKS = 0;

-- =============================================================================
-- SECTION 1: THE 4 CORE ENTITIES OF SRS SECTION 7.6
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1.1 PRODUCTS (SRS Section 7.6 / ERD #14)
-- Catalog of goods managed by the Seller (FR4.1)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `products` (
    `product_id`        INT AUTO_INCREMENT PRIMARY KEY,
    `sku`               VARCHAR(40) NOT NULL UNIQUE COMMENT 'Stock Keeping Unit',
    `product_name`      VARCHAR(120) NOT NULL,
    `category`          VARCHAR(60) NULL,
    `hs_code`           VARCHAR(12) NOT NULL COMMENT 'Customs Tariff Code (HS Code)',
    `unit`              VARCHAR(10) NOT NULL COMMENT 'SRS Section 7.6: VARCHAR(10) (e.g. PCS, BOX, KG, PALLET)',
    `unit_weight_kg`    DECIMAL(8, 3) NOT NULL DEFAULT 1.000,
    `unit_price`        DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    -- Schema extensions aligned with FR6 Analytics and soft-delete:
    `unit_cost`         DECIMAL(12, 2) NOT NULL DEFAULT 0.00 COMMENT 'Cost of goods for FR6 profitability analysis',
    `owner_company_id`  INT NOT NULL COMMENT 'FK to companies (Seller)',
    `is_active`         BOOLEAN NOT NULL DEFAULT TRUE COMMENT 'Soft-delete flag',
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
-- RESTRICT on delete protects historical inventory audit records
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `stock` (
    `stock_id`      INT AUTO_INCREMENT PRIMARY KEY,
    `product_id`    INT NOT NULL,
    `shipment_id`   INT NULL COMMENT 'NULL until linked to active shipment',
    `container_id`  INT NULL COMMENT 'Container allocated to this cargo',
    `quantity`      INT NOT NULL DEFAULT 0,
    `damaged_qty`   INT NOT NULL DEFAULT 0,
    `reserved_qty`  INT NOT NULL DEFAULT 0 COMMENT 'Active reservation total for this specific stock row',
    `is_active`     BOOLEAN NOT NULL DEFAULT TRUE,
    `last_updated`  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    `created_at`    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT `fk_stock_product`
        FOREIGN KEY (`product_id`) REFERENCES `products`(`product_id`)
        ON DELETE RESTRICT ON UPDATE CASCADE,

    CONSTRAINT `fk_stock_shipment`
        FOREIGN KEY (`shipment_id`) REFERENCES `shipment`(`shipment_id`)
        ON DELETE SET NULL ON UPDATE CASCADE,

    CONSTRAINT `fk_stock_container`
        FOREIGN KEY (`container_id`) REFERENCES `containers`(`container_id`)
        ON DELETE SET NULL ON UPDATE CASCADE,

    CONSTRAINT `chk_stock_qty_nonnegative`      CHECK (`quantity` >= 0),
    CONSTRAINT `chk_stock_damaged_nonnegative`  CHECK (`damaged_qty` >= 0),
    CONSTRAINT `chk_stock_reserved_nonnegative` CHECK (`reserved_qty` >= 0),
    CONSTRAINT `chk_stock_damaged_lte_total`    CHECK (`damaged_qty` <= `quantity`),
    CONSTRAINT `chk_stock_reserved_available`   CHECK (`reserved_qty` <= (`quantity` - `damaged_qty`)),

    INDEX `idx_stock_product` (`product_id`),
    INDEX `idx_stock_shipment` (`shipment_id`),
    INDEX `idx_stock_container` (`container_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- -----------------------------------------------------------------------------
-- 1.3 INVENTORY_LEDGER (SRS Section 7.6 / ERD #16)
-- Immutable double-entry audit journal for all stock movements (FR4.5)
-- RESTRICT on delete prevents erasing financial & inventory history
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `inventory_ledger` (
    `ledger_id`       BIGINT AUTO_INCREMENT PRIMARY KEY,
    `stock_id`        INT NOT NULL,
    `product_id`      INT NOT NULL,
    `txn_type`        ENUM('IN', 'OUT', 'DAMAGE', 'ADJUST', 'CLAIM_LOSS') NOT NULL,
    `quantity`        INT NOT NULL COMMENT 'Movement magnitude',
    `balance_after`   INT NOT NULL COMMENT 'Running physical available balance (quantity - damaged_qty)',
    `reference_type`  VARCHAR(30) NULL COMMENT 'OPENING, SHIPMENT, CLAIM, UPLOAD, MANUAL, STOCK_UPDATE',
    `reference_id`    BIGINT NULL COMMENT 'shipment_id, claim_id, stock_id, etc.',
    `changed_by`      INT NULL COMMENT 'FK to users(user_id) for audit accountability',
    `txn_time`        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT `fk_ledger_stock`
        FOREIGN KEY (`stock_id`) REFERENCES `stock`(`stock_id`)
        ON DELETE RESTRICT ON UPDATE CASCADE,

    CONSTRAINT `fk_ledger_product`
        FOREIGN KEY (`product_id`) REFERENCES `products`(`product_id`)
        ON DELETE RESTRICT ON UPDATE CASCADE,

    CONSTRAINT `fk_ledger_user`
        FOREIGN KEY (`changed_by`) REFERENCES `users`(`user_id`)
        ON DELETE SET NULL ON UPDATE CASCADE,

    CONSTRAINT `chk_ledger_qty` CHECK (`quantity` > 0),
    CONSTRAINT `chk_ledger_bal` CHECK (`balance_after` >= 0),

    INDEX `idx_ledger_product_time` (`product_id`, `txn_time`),
    INDEX `idx_ledger_stock` (`stock_id`),
    INDEX `idx_ledger_ref` (`reference_type`, `reference_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- -----------------------------------------------------------------------------
-- 1.4 SALES_TRANSACTIONS (SRS Section 7.6 / ERD #17)
-- Customer product purchases linked to confirmed shipments
-- Consumed by FR6 Analytics for sales trends and profitability
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
        ON DELETE RESTRICT ON UPDATE CASCADE,

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


-- -----------------------------------------------------------------------------
-- 1.5 AUTHORITATIVE RESERVATION SEAM (FR3/FR4 Integration)
-- Single source of truth linking active shipments to exact stock rows
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `shipment_stock_reservations` (
    `reservation_id`    BIGINT AUTO_INCREMENT PRIMARY KEY,
    `shipment_id`       INT NOT NULL,
    `shipment_item_id`  INT NOT NULL,
    `stock_id`          INT NOT NULL,
    `quantity_reserved` INT NOT NULL,
    `status`            ENUM('RESERVED','CONSUMED','RELEASED') NOT NULL DEFAULT 'RESERVED',
    `created_at`        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at`        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT `chk_reservation_qty` CHECK (`quantity_reserved` > 0),

    CONSTRAINT `fk_res_shipment`
        FOREIGN KEY (`shipment_id`) REFERENCES `shipment`(`shipment_id`)
        ON DELETE RESTRICT ON UPDATE CASCADE,

    CONSTRAINT `fk_res_item`
        FOREIGN KEY (`shipment_item_id`) REFERENCES `shipment_items`(`item_id`)
        ON DELETE RESTRICT ON UPDATE CASCADE,

    CONSTRAINT `fk_res_stock`
        FOREIGN KEY (`stock_id`) REFERENCES `stock`(`stock_id`)
        ON DELETE RESTRICT ON UPDATE CASCADE,

    INDEX `idx_res_shipment_status` (`shipment_id`, `status`),
    INDEX `idx_res_stock_status` (`stock_id`, `status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- =============================================================================
-- SECTION 2: OPERATIONAL STAGING FOR FR4.2 CSV/EXCEL BULK UPLOAD
-- Note: Operational helper table for CSV intake (FR4.2). Not a core ERD entity.
-- =============================================================================
CREATE TABLE IF NOT EXISTS `stock_upload_staging` (
    `row_id`         INT AUTO_INCREMENT PRIMARY KEY,
    `sku`            VARCHAR(40) NULL,
    `product_name`   VARCHAR(120) NULL,
    `hs_code`        VARCHAR(12) NULL,
    `unit`           VARCHAR(10) NULL,
    `weight_text`    VARCHAR(30) NULL,
    `price_text`     VARCHAR(30) NULL,
    `quantity_text`  VARCHAR(30) NULL,
    `row_status`     ENUM('PENDING', 'VALID', 'ERROR', 'IMPORTED') NOT NULL DEFAULT 'PENDING',
    `error_message`  VARCHAR(255) NULL,
    `created_at`     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    INDEX `idx_upload_sku` (`sku`),
    INDEX `idx_upload_status` (`row_status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

SET FOREIGN_KEY_CHECKS = @OLD_FOREIGN_KEY_CHECKS;


-- =============================================================================
-- SECTION 3: AUTOMATED INVENTORY LEDGER TRIGGERS & IMMUTABILITY (FR4.5)
-- Consolidated trigger architecture: eliminates competing trigger sets
-- =============================================================================

-- Drop legacy competing trigger names to prevent duplicate ledger inserts
DROP TRIGGER IF EXISTS `trg_stock_before_update`;
DROP TRIGGER IF EXISTS `trg_stock_after_insert`;
DROP TRIGGER IF EXISTS `trg_stock_after_update`;
DROP TRIGGER IF EXISTS `trg_after_stock_insert_ledger`;
DROP TRIGGER IF EXISTS `trg_after_stock_update_ledger`;
DROP TRIGGER IF EXISTS `trg_ledger_prevent_update`;
DROP TRIGGER IF EXISTS `trg_ledger_prevent_delete`;

DELIMITER //

-- Enforce true immutability on inventory_ledger: Prohibit direct UPDATE
CREATE TRIGGER `trg_ledger_prevent_update`
BEFORE UPDATE ON `inventory_ledger`
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'inventory_ledger is an immutable audit journal: UPDATE is prohibited';
END//

-- Enforce true immutability on inventory_ledger: Prohibit direct DELETE
CREATE TRIGGER `trg_ledger_prevent_delete`
BEFORE DELETE ON `inventory_ledger`
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'inventory_ledger is an immutable audit journal: DELETE is prohibited';
END//

-- Consolidated trigger 1: Record initial stock row creation in inventory_ledger
CREATE TRIGGER `trg_after_stock_insert_ledger`
AFTER INSERT ON `stock`
FOR EACH ROW
BEGIN
    IF NEW.quantity > 0 THEN
        INSERT INTO `inventory_ledger`
            (`stock_id`, `product_id`, `txn_type`, `quantity`, `balance_after`,
             `reference_type`, `reference_id`, `changed_by`, `txn_time`)
        VALUES
            (NEW.stock_id, NEW.product_id, 'IN', NEW.quantity,
             NEW.quantity - NEW.damaged_qty,
             COALESCE(@app_reference_type, 'OPENING'), @app_reference_id,
             @app_user_id, CURRENT_TIMESTAMP);
    END IF;
END//

-- Consolidated trigger 2: Record all quantity changes and damage updates in inventory_ledger
CREATE TRIGGER `trg_after_stock_update_ledger`
AFTER UPDATE ON `stock`
FOR EACH ROW
BEGIN
    -- Handle physical stock increase (Receipt / Stock In)
    IF NEW.quantity > OLD.quantity THEN
        INSERT INTO `inventory_ledger`
            (`stock_id`, `product_id`, `txn_type`, `quantity`, `balance_after`,
             `reference_type`, `reference_id`, `changed_by`, `txn_time`)
        VALUES
            (NEW.stock_id, NEW.product_id, 'IN', NEW.quantity - OLD.quantity,
             NEW.quantity - NEW.damaged_qty,
             COALESCE(@app_reference_type, 'STOCK_UPDATE'), @app_reference_id,
             @app_user_id, CURRENT_TIMESTAMP);

    -- Handle physical stock decrease (Issue / Dispatch / Claim Loss)
    ELSEIF NEW.quantity < OLD.quantity THEN
        INSERT INTO `inventory_ledger`
            (`stock_id`, `product_id`, `txn_type`, `quantity`, `balance_after`,
             `reference_type`, `reference_id`, `changed_by`, `txn_time`)
        VALUES
            (NEW.stock_id, NEW.product_id,
             IF(@app_reference_type = 'CLAIM', 'CLAIM_LOSS', COALESCE(@app_txn_type, 'OUT')),
             OLD.quantity - NEW.quantity,
             NEW.quantity - NEW.damaged_qty,
             COALESCE(@app_reference_type, 'DISPATCH'), @app_reference_id,
             @app_user_id, CURRENT_TIMESTAMP);
    END IF;

    -- Handle damaged stock increase (FR4.5)
    IF NEW.damaged_qty > OLD.damaged_qty THEN
        INSERT INTO `inventory_ledger`
            (`stock_id`, `product_id`, `txn_type`, `quantity`, `balance_after`,
             `reference_type`, `reference_id`, `changed_by`, `txn_time`)
        VALUES
            (NEW.stock_id, NEW.product_id, 'DAMAGE', NEW.damaged_qty - OLD.damaged_qty,
             NEW.quantity - NEW.damaged_qty,
             COALESCE(@app_reference_type, 'DAMAGE_UPDATE'), @app_reference_id,
             @app_user_id, CURRENT_TIMESTAMP);
    END IF;
END//

DELIMITER ;


-- =============================================================================
-- SECTION 4: FR4 STORED PROCEDURES (FR4.1–FR4.7)
-- =============================================================================

DROP PROCEDURE IF EXISTS `sp_add_product`;
DROP PROCEDURE IF EXISTS `sp_add_stock`;
DROP PROCEDURE IF EXISTS `sp_update_stock`;
DROP PROCEDURE IF EXISTS `sp_damage_stock`;
DROP PROCEDURE IF EXISTS `sp_reserve_stock_for_shipment`;
DROP PROCEDURE IF EXISTS `sp_release_stock_reservation`;
DROP PROCEDURE IF EXISTS `sp_finalize_stock_dispatch`;
DROP PROCEDURE IF EXISTS `sp_record_sale`;
DROP PROCEDURE IF EXISTS `sp_shipment_stock_report`;
DROP PROCEDURE IF EXISTS `sp_show_stock`;
DROP PROCEDURE IF EXISTS `sp_search_stock`;
DROP PROCEDURE IF EXISTS `sp_view_inventory_ledger`;
DROP PROCEDURE IF EXISTS `sp_validate_stock_upload`;
DROP PROCEDURE IF EXISTS `sp_import_valid_upload`;

DELIMITER //

-- -----------------------------------------------------------------------------
-- 4.1 ADD PRODUCT (FR4.1)
-- Creates catalog entry for seller with validation
-- -----------------------------------------------------------------------------
CREATE PROCEDURE `sp_add_product`(
    IN p_sku VARCHAR(40),
    IN p_product_name VARCHAR(120),
    IN p_category VARCHAR(60),
    IN p_hs_code VARCHAR(12),
    IN p_unit VARCHAR(10),
    IN p_weight DECIMAL(8,3),
    IN p_price DECIMAL(12,2),
    IN p_cost DECIMAL(12,2),
    IN p_owner_company_id INT,
    OUT p_product_id INT
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
        SELECT 1 FROM `companies` WHERE `company_id` = p_owner_company_id AND `company_type` = 'SELLER'
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Valid seller company not found';
    END IF;

    IF EXISTS (SELECT 1 FROM `products` WHERE `sku` = TRIM(p_sku)) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'A product with this SKU already exists';
    END IF;

    INSERT INTO `products`
        (`sku`, `product_name`, `category`, `hs_code`, `unit`,
         `unit_weight_kg`, `unit_price`, `unit_cost`, `owner_company_id`, `is_active`)
    VALUES
        (TRIM(p_sku), TRIM(p_product_name), TRIM(p_category), TRIM(p_hs_code), TRIM(p_unit),
         p_weight, p_price, COALESCE(p_cost, 0.00), p_owner_company_id, TRUE);

    SET p_product_id = LAST_INSERT_ID();
END//


-- -----------------------------------------------------------------------------
-- 4.2 ADD STOCK (FR4.1) - FIX BUG A: PREVENTS MULTI-ROW INFLATION
-- If p_stock_id is provided, updates THAT specific stock record.
-- If p_stock_id is NULL, creates a new stock record for the product lot.
-- -----------------------------------------------------------------------------
CREATE PROCEDURE `sp_add_stock`(
    IN p_stock_id INT,
    IN p_product_id INT,
    IN p_quantity INT,
    IN p_shipment_id INT,
    IN p_container_id INT,
    OUT p_resulting_stock_id INT
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SET @app_reference_type = NULL;
        RESIGNAL;
    END;

    IF p_quantity <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Stock quantity must be positive';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM `products` WHERE `product_id` = p_product_id AND `is_active` = TRUE) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Active product not found in catalog';
    END IF;

    SET @app_reference_type = 'STOCK_RECEIPT';

    -- Target specific stock row if provided
    IF p_stock_id IS NOT NULL THEN
        IF NOT EXISTS (SELECT 1 FROM `stock` WHERE `stock_id` = p_stock_id AND `product_id` = p_product_id) THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Specified stock record does not match the product';
        END IF;

        UPDATE `stock`
        SET `quantity` = `quantity` + p_quantity
        WHERE `stock_id` = p_stock_id;

        SET p_resulting_stock_id = p_stock_id;
    ELSE
        -- Insert distinct new stock record (preserves multi-row traceability)
        INSERT INTO `stock`
            (`product_id`, `shipment_id`, `container_id`, `quantity`, `damaged_qty`, `reserved_qty`, `is_active`)
        VALUES
            (p_product_id, p_shipment_id, p_container_id, p_quantity, 0, 0, TRUE);

        SET p_resulting_stock_id = LAST_INSERT_ID();
    END IF;

    SET @app_reference_type = NULL;
END//


-- -----------------------------------------------------------------------------
-- 4.3 UPDATE STOCK (FR4.6, FR4.7) - FIX BUG B: ROW-LEVEL RESERVATIONS
-- Enforces: Quantity cannot be reduced below (damaged_qty + reserved_qty)
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
        SET @app_reference_type = NULL;
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    IF p_quantity < 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Negative stock is not permitted (FR4.6)';
    END IF;

    SELECT `product_id`, `damaged_qty`, `reserved_qty`
    INTO v_product_id, v_damaged, v_reserved
    FROM `stock` WHERE `stock_id` = p_stock_id FOR UPDATE;

    IF v_product_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Stock record not found';
    END IF;

    -- Row-level reservation validation
    IF p_quantity < (v_damaged + v_reserved) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Cannot reduce stock below damaged plus already reserved quantity for this stock record (FR4.7)';
    END IF;

    SET @app_reference_type = 'STOCK_ADJUST';

    UPDATE `stock`
    SET `quantity` = p_quantity
    WHERE `stock_id` = p_stock_id;

    SET @app_reference_type = NULL;

    COMMIT;
END//


-- -----------------------------------------------------------------------------
-- 4.4 DAMAGE STOCK (FR4.5) - FIX BUG B: ROW-LEVEL ACCURACY
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
        SET @app_reference_type = NULL;
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    IF p_damage_qty <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Damage quantity must be positive';
    END IF;

    SELECT `product_id`, `quantity`, `damaged_qty`, `reserved_qty`
    INTO v_product_id, v_quantity, v_damaged, v_reserved
    FROM `stock` WHERE `stock_id` = p_stock_id FOR UPDATE;

    IF v_product_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Stock record not found';
    END IF;

    -- Row-level check: cannot damage goods that are already reserved for dispatch
    IF p_damage_qty > (v_quantity - v_damaged - v_reserved) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Insufficient unreserved stock on this record to mark as damaged';
    END IF;

    SET @app_reference_type = 'DAMAGE_UPDATE';

    UPDATE `stock`
    SET `damaged_qty` = `damaged_qty` + p_damage_qty
    WHERE `stock_id` = p_stock_id;

    SET @app_reference_type = NULL;

    COMMIT;
END//


-- -----------------------------------------------------------------------------
-- 4.5 RESERVE STOCK FOR SHIPMENT (FR4.3) - FIX BUG D: SINGLE AUTHORITATIVE SEAM
-- Integrates directly with shipment_stock_reservations
-- -----------------------------------------------------------------------------
CREATE PROCEDURE `sp_reserve_stock_for_shipment`(
    IN p_shipment_id INT,
    IN p_shipment_item_id INT,
    IN p_stock_id INT,
    IN p_quantity INT,
    OUT p_reservation_id BIGINT
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

    IF p_quantity <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Reservation quantity must be positive';
    END IF;

    -- Lock stock row and verify row-level unreserved availability
    SELECT `product_id`, `quantity`, `damaged_qty`, `reserved_qty`
    INTO v_product_id, v_quantity, v_damaged, v_reserved
    FROM `stock` WHERE `stock_id` = p_stock_id FOR UPDATE;

    IF v_product_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Target stock record not found';
    END IF;

    IF p_quantity > (v_quantity - v_damaged - v_reserved) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Insufficient available unreserved stock on this record';
    END IF;

    -- Increase stock row reservation count
    UPDATE `stock`
    SET `reserved_qty` = `reserved_qty` + p_quantity
    WHERE `stock_id` = p_stock_id;

    -- Record in single authoritative reservation table
    INSERT INTO `shipment_stock_reservations`
        (`shipment_id`, `shipment_item_id`, `stock_id`, `quantity_reserved`, `status`)
    VALUES
        (p_shipment_id, p_shipment_item_id, p_stock_id, p_quantity, 'RESERVED');

    SET p_reservation_id = LAST_INSERT_ID();

    COMMIT;
END//


-- -----------------------------------------------------------------------------
-- 4.6 RELEASE STOCK RESERVATION (FR4.3)
-- Releases reservation without reducing inventory
-- -----------------------------------------------------------------------------
CREATE PROCEDURE `sp_release_stock_reservation`(
    IN p_reservation_id BIGINT
)
BEGIN
    DECLARE v_stock_id INT;
    DECLARE v_qty INT;
    DECLARE v_status VARCHAR(20);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    SELECT `stock_id`, `quantity_reserved`, `status`
    INTO v_stock_id, v_qty, v_status
    FROM `shipment_stock_reservations`
    WHERE `reservation_id` = p_reservation_id FOR UPDATE;

    IF v_status IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Reservation not found';
    END IF;

    IF v_status <> 'RESERVED' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Only active RESERVED status can be released';
    END IF;

    UPDATE `stock`
    SET `reserved_qty` = GREATEST(0, `reserved_qty` - v_qty)
    WHERE `stock_id` = v_stock_id;

    UPDATE `shipment_stock_reservations`
    SET `status` = 'RELEASED'
    WHERE `reservation_id` = p_reservation_id;

    COMMIT;
END//


-- -----------------------------------------------------------------------------
-- 4.7 FINALIZE STOCK DISPATCH (FR4.5) - FIX BUG D: PREVENTS DOUBLE CONSUMPTION
-- Consumes reservation, deducts physical stock, and triggers single ledger OUT
-- -----------------------------------------------------------------------------
CREATE PROCEDURE `sp_finalize_stock_dispatch`(
    IN p_reservation_id BIGINT
)
BEGIN
    DECLARE v_stock_id INT;
    DECLARE v_qty INT;
    DECLARE v_status VARCHAR(20);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SET @app_reference_type = NULL;
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    SELECT `stock_id`, `quantity_reserved`, `status`
    INTO v_stock_id, v_qty, v_status
    FROM `shipment_stock_reservations`
    WHERE `reservation_id` = p_reservation_id FOR UPDATE;

    IF v_status IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Reservation record not found';
    END IF;

    IF v_status <> 'RESERVED' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Reservation is not active for consumption';
    END IF;

    SET @app_reference_type = 'DISPATCH';
    SET @app_reference_id = p_reservation_id;

    -- Atomically reduce reservation AND physical stock
    UPDATE `stock`
    SET `quantity` = `quantity` - v_qty,
        `reserved_qty` = `reserved_qty` - v_qty
    WHERE `stock_id` = v_stock_id AND `quantity` >= v_qty AND `reserved_qty` >= v_qty;

    IF ROW_COUNT() = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Unable to consume reserved stock: insufficient stock balance';
    END IF;

    UPDATE `shipment_stock_reservations`
    SET `status` = 'CONSUMED'
    WHERE `reservation_id` = p_reservation_id;

    SET @app_reference_type = NULL;
    SET @app_reference_id = NULL;

    COMMIT;
END//


-- -----------------------------------------------------------------------------
-- 4.8 RECORD SALE (SRS Section 7.6 / ERD #17 / FR6 Analytics Feed)
-- Populates sales_transactions and connects sales to inventory history
-- -----------------------------------------------------------------------------
CREATE PROCEDURE `sp_record_sale`(
    IN p_product_id INT,
    IN p_customer_id INT,
    IN p_shipment_id INT,
    IN p_quantity INT,
    IN p_unit_price DECIMAL(12,2),
    IN p_sale_date DATE,
    OUT p_sale_id BIGINT
)
BEGIN
    DECLARE v_total DECIMAL(14,2);

    IF p_quantity <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Sale quantity must be positive';
    END IF;

    IF p_unit_price < 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Unit price cannot be negative';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM `products` WHERE `product_id` = p_product_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Product not found';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM `customers` WHERE `customer_id` = p_customer_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Customer not found';
    END IF;

    SET v_total = ROUND(p_quantity * p_unit_price, 2);

    INSERT INTO `sales_transactions`
        (`product_id`, `customer_id`, `shipment_id`, `quantity`, `unit_price`, `total_amount`, `sale_date`)
    VALUES
        (p_product_id, p_customer_id, p_shipment_id, p_quantity, p_unit_price, v_total, COALESCE(p_sale_date, CURDATE()));

    SET p_sale_id = LAST_INSERT_ID();
END//


-- -----------------------------------------------------------------------------
-- 4.9 SHIPMENT STOCK REPORT (FR4.4)
-- Line items & shipment totals
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
-- 4.10 SHOW STOCK REPORT (FR4.7) - FIX BUG B: ROW-LEVEL ACCURACY
-- Available = Quantity - Damaged - Active Reserved
-- -----------------------------------------------------------------------------
CREATE PROCEDURE `sp_show_stock`()
BEGIN
    SELECT
        s.stock_id,
        p.product_id,
        p.sku,
        p.product_name,
        p.hs_code,
        p.unit,
        s.quantity AS total_quantity,
        s.damaged_qty,
        s.reserved_qty,
        (s.quantity - s.damaged_qty - s.reserved_qty) AS available_quantity,
        p.unit_price,
        ((s.quantity - s.damaged_qty) * p.unit_price) AS stock_value,
        s.last_updated
    FROM `stock` s
    JOIN `products` p ON p.product_id = s.product_id
    WHERE s.is_active = TRUE
    ORDER BY s.stock_id;
END//


-- -----------------------------------------------------------------------------
-- 4.11 SEARCH STOCK (FR4.7) - FIX BUG B: ROW-LEVEL ACCURACY
-- -----------------------------------------------------------------------------
CREATE PROCEDURE `sp_search_stock`(
    IN p_search VARCHAR(120)
)
BEGIN
    SELECT
        s.stock_id,
        p.product_id,
        p.sku,
        p.product_name,
        p.hs_code,
        p.unit,
        s.quantity AS total_quantity,
        s.damaged_qty,
        s.reserved_qty,
        (s.quantity - s.damaged_qty - s.reserved_qty) AS available_quantity,
        p.unit_price
    FROM `stock` s
    JOIN `products` p ON p.product_id = s.product_id
    WHERE s.is_active = TRUE
      AND p_search IS NOT NULL
      AND (
          p.sku LIKE CONCAT('%', p_search, '%')
          OR p.product_name LIKE CONCAT('%', p_search, '%')
          OR s.stock_id = CAST(p_search AS SIGNED)
      )
    ORDER BY s.stock_id;
END//


-- -----------------------------------------------------------------------------
-- 4.12 VIEW INVENTORY LEDGER (FR4.5)
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
        l.changed_by,
        l.txn_time
    FROM `inventory_ledger` l
    JOIN `products` p ON p.product_id = l.product_id
    WHERE p_stock_id IS NULL OR l.stock_id = p_stock_id
    ORDER BY l.txn_time DESC, l.ledger_id DESC;
END//


-- -----------------------------------------------------------------------------
-- 4.13 CSV/EXCEL UPLOAD VALIDATION (FR4.2)
-- -----------------------------------------------------------------------------
CREATE PROCEDURE `sp_validate_stock_upload`()
BEGIN
    UPDATE `stock_upload_staging`
    SET `row_status` = 'VALID', `error_message` = NULL
    WHERE `row_status` <> 'IMPORTED';

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

    UPDATE `stock_upload_staging`
    SET `row_status` = 'ERROR',
        `error_message` = 'Invalid numeric format for weight, price, or quantity'
    WHERE `row_status` = 'VALID'
      AND (
        TRIM(weight_text) NOT REGEXP '^[0-9]+([.][0-9]+)?$'
        OR TRIM(price_text) NOT REGEXP '^[0-9]+([.][0-9]+)?$'
        OR TRIM(quantity_text) NOT REGEXP '^[0-9]+$'
      );

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

    UPDATE `stock_upload_staging` u
    JOIN `products` p ON p.sku = u.sku
    SET u.row_status = 'ERROR',
        u.error_message = 'SKU already exists in catalog'
    WHERE u.row_status = 'VALID';

    UPDATE `stock_upload_staging` u
    JOIN (
        SELECT sku FROM `stock_upload_staging`
        WHERE sku IS NOT NULL AND TRIM(sku) <> '' AND row_status <> 'IMPORTED'
        GROUP BY sku HAVING COUNT(*) > 1
    ) d ON d.sku = u.sku
    SET u.row_status = 'ERROR',
        u.error_message = 'Duplicate SKU inside uploaded file'
    WHERE u.row_status = 'VALID';

    SELECT `row_id`, `sku`, `product_name`, `row_status`, `error_message`
    FROM `stock_upload_staging`
    ORDER BY `row_id`;
END//


-- -----------------------------------------------------------------------------
-- 4.14 IMPORT VALID CSV UPLOAD ROWS (FR4.2)
-- -----------------------------------------------------------------------------
CREATE PROCEDURE `sp_import_valid_upload`(
    IN p_owner_company_id INT
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SET @app_reference_type = NULL;
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    IF NOT EXISTS (
        SELECT 1 FROM `companies` WHERE `company_id` = p_owner_company_id AND `company_type` = 'SELLER'
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Valid seller company not found';
    END IF;

    SET @app_reference_type = 'CSV_UPLOAD';

    INSERT INTO `products`
        (`sku`, `product_name`, `hs_code`, `unit`, `unit_weight_kg`, `unit_price`, `owner_company_id`)
    SELECT
        TRIM(sku), TRIM(product_name), TRIM(hs_code), TRIM(unit),
        CAST(weight_text AS DECIMAL(8,3)),
        CAST(price_text AS DECIMAL(12,2)),
        p_owner_company_id
    FROM `stock_upload_staging`
    WHERE `row_status` = 'VALID';

    INSERT INTO `stock` (`product_id`, `quantity`, `damaged_qty`, `reserved_qty`, `is_active`)
    SELECT
        p.product_id,
        CAST(u.quantity_text AS UNSIGNED),
        0,
        0,
        TRUE
    FROM `stock_upload_staging` u
    JOIN `products` p ON p.sku = u.sku
    WHERE u.row_status = 'VALID';

    UPDATE `stock_upload_staging`
    SET `row_status` = 'IMPORTED', `error_message` = NULL
    WHERE `row_status` = 'VALID';

    SET @app_reference_type = NULL;

    COMMIT;

    SELECT 'Import completed successfully' AS result, COUNT(*) AS imported_rows
    FROM `stock_upload_staging` WHERE `row_status` = 'IMPORTED';
END//

DELIMITER ;

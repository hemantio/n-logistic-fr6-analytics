/* ================================================================================================
 * N-LOGISTICS PLATFORM ARCHITECTURE: INVENTORY & DISPATCH SERVICE MODULE
 * ------------------------------------------------------------------------------------------------
 * RE-ENGINEERED DOMAIN IMPLEMENTATION: MODULE FR4 (STOCK DETAILS & INVENTORY GOVERNANCE)
 * COMPLIANCE SPECIFICATIONS: SRS v1.0 Sections 3.4, 7.6, 7.9, 7.10
 * OPERATIONAL RUNTIME: MySQL Community Server 8.0+ / InnoDB / utf8mb4_unicode_ci
 * ARCHITECTURAL DESIGN: Domain-Driven Modular Services with Layered Immutability & Audit Triggers
 * ================================================================================================ */

USE n_logistic_db;


-- ================================================================================================
-- SUBSYSTEM 1: INFRASTRUCTURE INITIALIZATION & INTEGRITY HARDENING
-- Pre-condition assertion, dynamic foreign key migration (ON DELETE RESTRICT), and reservation indexes.
-- ================================================================================================

CREATE TABLE IF NOT EXISTS stock_upload_batches (
    batch_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    seller_id INT NOT NULL,
    uploaded_by INT NULL,
    source_file_name VARCHAR(255) NULL,
    batch_status ENUM('PENDING','VALIDATED','PARTIAL','IMPORTED','FAILED')
        NOT NULL DEFAULT 'PENDING',
    valid_row_count INT NOT NULL DEFAULT 0,
    error_row_count INT NOT NULL DEFAULT 0,
    imported_row_count INT NOT NULL DEFAULT 0,
    validated_at DATETIME NULL,
    imported_at DATETIME NULL,
    CONSTRAINT fk_stock_upload_batch_seller
        FOREIGN KEY (seller_id) REFERENCES companies(company_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_stock_upload_batch_user
        FOREIGN KEY (uploaded_by) REFERENCES users(user_id)
        ON DELETE SET NULL ON UPDATE CASCADE,
    INDEX idx_stock_upload_batch_seller (seller_id),
    INDEX idx_stock_upload_batch_status (batch_status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


CREATE TABLE IF NOT EXISTS stock_upload_staging (
    row_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    batch_id BIGINT NOT NULL,
    sku VARCHAR(40) NULL,
    quantity_text VARCHAR(30) NULL,
    row_status ENUM('PENDING','VALID','ERROR','IMPORTED')
        NOT NULL DEFAULT 'PENDING',
    error_message VARCHAR(255) NULL,
    CONSTRAINT fk_stock_upload_stage_batch
        FOREIGN KEY (batch_id) REFERENCES stock_upload_batches(batch_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    INDEX idx_stock_upload_stage_batch_status (batch_id, row_status),
    INDEX idx_stock_upload_stage_sku (sku)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


DROP PROCEDURE IF EXISTS `sp_fr4_assert_prerequisites`;
DELIMITER $$
CREATE PROCEDURE sp_fr4_assert_prerequisites()
BEGIN
    DECLARE v_table_count INT DEFAULT 0;

    SELECT COUNT(*) INTO v_table_count
    FROM information_schema.tables
    WHERE table_schema = DATABASE()
      AND table_name IN (
          'companies','users','customers','audit_log','products','stock',
          'inventory_ledger','sales_transactions','shipment','containers',
          'shipment_items','shipment_stock_reservations'
      );

    IF v_table_count <> 12 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'FR4 prerequisite check failed: install the n_logistic_db master schema and operational extension first';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = DATABASE() AND table_name = 'products' AND column_name = 'unit_volume_cbm')
       OR NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = DATABASE() AND table_name = 'products' AND column_name = 'unit_cost')
       OR NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = DATABASE() AND table_name = 'products' AND column_name = 'is_active')
       OR NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = DATABASE() AND table_name = 'stock' AND column_name = 'reserved_qty')
       OR NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = DATABASE() AND table_name = 'stock' AND column_name = 'is_active')
       OR NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = DATABASE() AND table_name = 'inventory_ledger' AND column_name = 'changed_by')
       OR NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = DATABASE() AND table_name = 'shipment' AND column_name = 'booking_confirmed')
       OR NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = DATABASE() AND table_name = 'shipment_stock_reservations' AND column_name = 'shipment_item_id')
       OR NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = DATABASE() AND table_name = 'shipment_stock_reservations' AND column_name = 'quantity_reserved') THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'FR4 prerequisite check failed: required operational-extension columns are missing';
    END IF;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS `sp_fr4_upgrade_foreign_keys`;
DELIMITER $$
CREATE PROCEDURE sp_fr4_upgrade_foreign_keys()
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.referential_constraints WHERE constraint_schema = DATABASE() AND constraint_name = 'fk_products_owner') THEN
        ALTER TABLE products DROP FOREIGN KEY fk_products_owner;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.referential_constraints WHERE constraint_schema = DATABASE() AND constraint_name = 'fk_products_company' AND delete_rule <> 'RESTRICT') THEN
        ALTER TABLE products DROP FOREIGN KEY fk_products_company;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.referential_constraints WHERE constraint_schema = DATABASE() AND constraint_name = 'fk_products_company') THEN
        ALTER TABLE products ADD CONSTRAINT fk_products_company FOREIGN KEY (owner_company_id)
            REFERENCES companies(company_id) ON DELETE RESTRICT ON UPDATE CASCADE;
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.referential_constraints WHERE constraint_schema = DATABASE() AND constraint_name = 'fk_stock_product' AND delete_rule <> 'RESTRICT') THEN
        ALTER TABLE stock DROP FOREIGN KEY fk_stock_product;
        ALTER TABLE stock ADD CONSTRAINT fk_stock_product FOREIGN KEY (product_id)
            REFERENCES products(product_id) ON DELETE RESTRICT ON UPDATE CASCADE;
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.referential_constraints WHERE constraint_schema = DATABASE() AND constraint_name = 'fk_ledger_product' AND delete_rule <> 'RESTRICT') THEN
        ALTER TABLE inventory_ledger DROP FOREIGN KEY fk_ledger_product;
        ALTER TABLE inventory_ledger ADD CONSTRAINT fk_ledger_product FOREIGN KEY (product_id)
            REFERENCES products(product_id) ON DELETE RESTRICT ON UPDATE CASCADE;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.referential_constraints WHERE constraint_schema = DATABASE() AND constraint_name = 'fk_ledger_stock' AND delete_rule <> 'RESTRICT') THEN
        ALTER TABLE inventory_ledger DROP FOREIGN KEY fk_ledger_stock;
        ALTER TABLE inventory_ledger ADD CONSTRAINT fk_ledger_stock FOREIGN KEY (stock_id)
            REFERENCES stock(stock_id) ON DELETE RESTRICT ON UPDATE CASCADE;
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.referential_constraints WHERE constraint_schema = DATABASE() AND constraint_name = 'fk_sales_product' AND delete_rule <> 'RESTRICT') THEN
        ALTER TABLE sales_transactions DROP FOREIGN KEY fk_sales_product;
        ALTER TABLE sales_transactions ADD CONSTRAINT fk_sales_product FOREIGN KEY (product_id)
            REFERENCES products(product_id) ON DELETE RESTRICT ON UPDATE CASCADE;
    END IF;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS `sp_fr4_add_reservation_indexes`;
DELIMITER $$
CREATE PROCEDURE sp_fr4_add_reservation_indexes()
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.statistics
        WHERE table_schema = DATABASE()
          AND table_name = 'shipment_stock_reservations'
          AND index_name = 'idx_reservation_stock_status'
    ) THEN
        ALTER TABLE shipment_stock_reservations
            ADD INDEX idx_reservation_stock_status (stock_id, status);
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.statistics
        WHERE table_schema = DATABASE()
          AND table_name = 'shipment_stock_reservations'
          AND index_name = 'idx_reservation_item_status'
    ) THEN
        ALTER TABLE shipment_stock_reservations
            ADD INDEX idx_reservation_item_status (shipment_item_id, status);
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.statistics
        WHERE table_schema = DATABASE()
          AND table_name = 'sales_transactions'
          AND index_name = 'idx_sales_shipment_product_customer'
    ) THEN
        ALTER TABLE sales_transactions
            ADD INDEX idx_sales_shipment_product_customer (shipment_id, product_id, customer_id);
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.statistics
        WHERE table_schema = DATABASE()
          AND table_name = 'stock'
          AND index_name = 'idx_stock_product_active'
    ) THEN
        ALTER TABLE stock
            ADD INDEX idx_stock_product_active (product_id, is_active, stock_id);
    END IF;
END$$
DELIMITER ;

CALL sp_fr4_assert_prerequisites();
DROP PROCEDURE IF EXISTS sp_fr4_assert_prerequisites;

CALL sp_fr4_upgrade_foreign_keys();
DROP PROCEDURE IF EXISTS sp_fr4_upgrade_foreign_keys;

CALL sp_fr4_add_reservation_indexes();
DROP PROCEDURE IF EXISTS sp_fr4_add_reservation_indexes;



-- ================================================================================================
-- SUBSYSTEM 2: PRODUCT CATALOG MANAGEMENT (PRODUCTS DOMAIN)
-- Commercial goods catalog management, multi-tenant seller scoping, soft-delete lifecycles, and audit logging.
-- ================================================================================================

DROP TRIGGER IF EXISTS `trg_fr4_before_product_delete_guard`;
DELIMITER $$
CREATE TRIGGER trg_fr4_before_product_delete_guard
BEFORE DELETE ON products
FOR EACH ROW
BEGIN
    IF EXISTS (SELECT 1 FROM stock WHERE product_id = OLD.product_id)
       OR EXISTS (SELECT 1 FROM shipment_items WHERE product_id = OLD.product_id)
       OR EXISTS (SELECT 1 FROM sales_transactions WHERE product_id = OLD.product_id)
       OR EXISTS (SELECT 1 FROM inventory_ledger WHERE product_id = OLD.product_id) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Product with stock or transaction history cannot be deleted; deactivate it instead';
    END IF;
END$$
DELIMITER ;

DROP TRIGGER IF EXISTS `trg_fr4_after_product_insert_audit`;
DELIMITER $$
CREATE TRIGGER trg_fr4_after_product_insert_audit
AFTER INSERT ON products
FOR EACH ROW
BEGIN
    INSERT INTO audit_log
        (user_id, action, table_name, record_id, old_value, new_value)
    VALUES
        (@app_user_id, 'PRODUCT_CREATE', 'products', NEW.product_id, NULL,
         JSON_OBJECT('sku', NEW.sku, 'product_name', NEW.product_name,
                     'category', NEW.category, 'hs_code', NEW.hs_code,
                     'unit', NEW.unit, 'unit_weight_kg', NEW.unit_weight_kg,
                     'unit_volume_cbm', NEW.unit_volume_cbm,
                     'unit_price', NEW.unit_price, 'unit_cost', NEW.unit_cost,
                     'owner_company_id', NEW.owner_company_id, 'is_active', NEW.is_active));
END$$
DELIMITER ;

DROP TRIGGER IF EXISTS `trg_fr4_after_product_update_audit`;
DELIMITER $$
CREATE TRIGGER trg_fr4_after_product_update_audit
AFTER UPDATE ON products
FOR EACH ROW
BEGIN
    IF NOT (OLD.sku <=> NEW.sku)
       OR NOT (OLD.product_name <=> NEW.product_name)
       OR NOT (OLD.category <=> NEW.category)
       OR NOT (OLD.hs_code <=> NEW.hs_code)
       OR NOT (OLD.unit <=> NEW.unit)
       OR NOT (OLD.unit_weight_kg <=> NEW.unit_weight_kg)
       OR NOT (OLD.unit_volume_cbm <=> NEW.unit_volume_cbm)
       OR NOT (OLD.unit_price <=> NEW.unit_price)
       OR NOT (OLD.unit_cost <=> NEW.unit_cost)
       OR NOT (OLD.is_active <=> NEW.is_active) THEN
        INSERT INTO audit_log
            (user_id, action, table_name, record_id, old_value, new_value)
        VALUES
            (@app_user_id,
             CASE WHEN OLD.is_active <> NEW.is_active AND NEW.is_active = FALSE
                  THEN 'PRODUCT_DEACTIVATE'
                  WHEN OLD.is_active <> NEW.is_active AND NEW.is_active = TRUE
                  THEN 'PRODUCT_REACTIVATE'
                  ELSE 'PRODUCT_UPDATE' END,
             'products', NEW.product_id,
             JSON_OBJECT('sku', OLD.sku, 'product_name', OLD.product_name,
                         'category', OLD.category, 'hs_code', OLD.hs_code,
                         'unit', OLD.unit, 'unit_weight_kg', OLD.unit_weight_kg,
                         'unit_volume_cbm', OLD.unit_volume_cbm,
                         'unit_price', OLD.unit_price, 'unit_cost', OLD.unit_cost,
                         'is_active', OLD.is_active),
             JSON_OBJECT('sku', NEW.sku, 'product_name', NEW.product_name,
                         'category', NEW.category, 'hs_code', NEW.hs_code,
                         'unit', NEW.unit, 'unit_weight_kg', NEW.unit_weight_kg,
                         'unit_volume_cbm', NEW.unit_volume_cbm,
                         'unit_price', NEW.unit_price, 'unit_cost', NEW.unit_cost,
                         'is_active', NEW.is_active));
    END IF;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS `sp_add_product`;
DELIMITER $$
CREATE PROCEDURE sp_add_product(
    IN p_seller_id INT,
    IN p_user_id INT,
    IN p_sku VARCHAR(40),
    IN p_product_name VARCHAR(120),
    IN p_category VARCHAR(60),
    IN p_hs_code VARCHAR(12),
    IN p_unit VARCHAR(10),
    IN p_unit_weight_kg DECIMAL(8,3),
    IN p_unit_volume_cbm DECIMAL(10,4),
    IN p_unit_price DECIMAL(12,2),
    IN p_unit_cost DECIMAL(12,2)
)
BEGIN
    DECLARE _ctx_saved_user INT;
    DECLARE _auth_match_count INT DEFAULT 0;
    DECLARE _allocated_product_id INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SET @app_user_id = _ctx_saved_user;
        RESIGNAL;
    END;

    SET _ctx_saved_user = @app_user_id;

    IF p_sku IS NULL OR TRIM(p_sku) = ''
       OR p_product_name IS NULL OR TRIM(p_product_name) = ''
       OR p_hs_code IS NULL OR TRIM(p_hs_code) = ''
       OR p_unit IS NULL OR TRIM(p_unit) = '' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'SKU, product name, HS code and unit are mandatory';
    END IF;
    IF p_unit_weight_kg IS NULL OR p_unit_volume_cbm IS NULL
       OR p_unit_price IS NULL OR p_unit_cost IS NULL
       OR p_unit_weight_kg < 0 OR p_unit_volume_cbm < 0
       OR p_unit_price < 0 OR p_unit_cost < 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Weight, volume, price and cost must be non-negative values';
    END IF;

    SELECT COUNT(*) INTO _auth_match_count
    FROM companies c
    JOIN users u ON u.user_id = p_user_id AND u.status = 'ACTIVE'
    WHERE c.company_id = p_seller_id
      AND c.company_type = 'SELLER'
      AND ((u.role = 'SELLER' AND u.company_id = p_seller_id) OR u.role = 'ADMIN');

    IF _auth_match_count = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid seller or user is not authorized for this seller';
    END IF;

    SET @app_user_id = p_user_id;

    INSERT INTO products
        (sku, product_name, category, hs_code, unit, unit_weight_kg,
         unit_volume_cbm, unit_price, unit_cost, owner_company_id, is_active)
    VALUES
        (TRIM(p_sku), TRIM(p_product_name), p_category, p_hs_code, p_unit,
         p_unit_weight_kg, p_unit_volume_cbm, p_unit_price, p_unit_cost,
         p_seller_id, TRUE);
    SET _allocated_product_id = LAST_INSERT_ID();

    SET @app_user_id = _ctx_saved_user;
    SELECT _allocated_product_id AS product_id;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS `sp_update_product`;
DELIMITER $$
CREATE PROCEDURE sp_update_product(
    IN p_seller_id INT,
    IN p_user_id INT,
    IN p_product_id INT,
    IN p_sku VARCHAR(40),
    IN p_product_name VARCHAR(120),
    IN p_category VARCHAR(60),
    IN p_hs_code VARCHAR(12),
    IN p_unit VARCHAR(10),
    IN p_unit_weight_kg DECIMAL(8,3),
    IN p_unit_volume_cbm DECIMAL(10,4),
    IN p_unit_price DECIMAL(12,2),
    IN p_unit_cost DECIMAL(12,2)
)
BEGIN
    DECLARE _ctx_saved_user INT;
    DECLARE v_exists INT DEFAULT 0;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SET @app_user_id = _ctx_saved_user;
        ROLLBACK;
        RESIGNAL;
    END;

    SET _ctx_saved_user = @app_user_id;

    IF NOT EXISTS (SELECT 1 FROM companies c
                   WHERE c.company_id = p_seller_id AND c.company_type = 'SELLER') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Seller company not found';
    END IF;

    IF p_sku IS NULL OR TRIM(p_sku) = ''
       OR p_product_name IS NULL OR TRIM(p_product_name) = ''
       OR p_hs_code IS NULL OR TRIM(p_hs_code) = ''
       OR p_unit IS NULL OR TRIM(p_unit) = '' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'SKU, product name, HS code and unit are mandatory';
    END IF;
    IF p_unit_weight_kg IS NULL OR p_unit_volume_cbm IS NULL
       OR p_unit_price IS NULL OR p_unit_cost IS NULL
       OR p_unit_weight_kg < 0 OR p_unit_volume_cbm < 0
       OR p_unit_price < 0 OR p_unit_cost < 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Weight, volume, price and cost must be non-negative values';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM users u WHERE u.user_id = p_user_id AND u.status = 'ACTIVE'
                   AND ((u.role = 'SELLER' AND u.company_id = p_seller_id) OR u.role = 'ADMIN')) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'User is not authorized for this seller';
    END IF;

    START TRANSACTION;
    SELECT COUNT(*) INTO v_exists
    FROM products
    WHERE product_id = p_product_id AND owner_company_id = p_seller_id;
    IF v_exists = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Product not found for this seller';
    END IF;

    SET @app_user_id = p_user_id;

    UPDATE products
    SET sku = TRIM(p_sku), product_name = TRIM(p_product_name),
        category = p_category, hs_code = p_hs_code, unit = p_unit,
        unit_weight_kg = p_unit_weight_kg, unit_volume_cbm = p_unit_volume_cbm,
        unit_price = p_unit_price, unit_cost = p_unit_cost
    WHERE product_id = p_product_id AND owner_company_id = p_seller_id;

    UPDATE shipment_items si
    JOIN shipment sh ON sh.shipment_id = si.shipment_id
    SET si.weight_kg = si.quantity * p_unit_weight_kg,
        si.volume_cbm = si.quantity * p_unit_volume_cbm
    WHERE si.product_id = p_product_id
      AND sh.status = 'BOOKED'
      AND sh.booking_confirmed = FALSE;

    SET @app_user_id = _ctx_saved_user;
    COMMIT;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS `sp_deactivate_product`;
DELIMITER $$
CREATE PROCEDURE sp_deactivate_product(
    IN p_seller_id INT,
    IN p_user_id INT,
    IN p_product_id INT
)
BEGIN
    DECLARE _ctx_saved_user INT;
    DECLARE v_exists INT DEFAULT 0;
    DECLARE _existing_on_hand_units INT DEFAULT 0;
    DECLARE _existing_reserved_units INT DEFAULT 0;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SET @app_user_id = _ctx_saved_user;
        ROLLBACK;
        RESIGNAL;
    END;

    SET _ctx_saved_user = @app_user_id;

    IF NOT EXISTS (SELECT 1 FROM companies c
                   WHERE c.company_id = p_seller_id AND c.company_type = 'SELLER') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Seller company not found';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM users u WHERE u.user_id = p_user_id AND u.status = 'ACTIVE'
                   AND ((u.role = 'SELLER' AND u.company_id = p_seller_id) OR u.role = 'ADMIN')) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'User is not authorized for this seller';
    END IF;

    START TRANSACTION;
    SELECT COUNT(DISTINCT p.product_id), COALESCE(SUM(s.quantity),0),
           COALESCE(SUM(s.reserved_qty),0)
      INTO v_exists, _existing_on_hand_units, _existing_reserved_units
    FROM products p
    LEFT JOIN stock s ON s.product_id = p.product_id
    WHERE p.product_id = p_product_id AND p.owner_company_id = p_seller_id;

    IF v_exists = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Product not found for this seller';
    END IF;
    IF _existing_reserved_units > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Product has reserved stock and cannot be deactivated';
    END IF;
    IF _existing_on_hand_units > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Product has on-hand stock; clear or transfer stock before deactivation';
    END IF;

    SET @app_user_id = p_user_id;
    UPDATE products SET is_active = FALSE
    WHERE product_id = p_product_id AND owner_company_id = p_seller_id;
    SET @app_user_id = _ctx_saved_user;
    COMMIT;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS `sp_reactivate_product`;
DELIMITER $$
CREATE PROCEDURE sp_reactivate_product(
    IN p_seller_id INT,
    IN p_user_id INT,
    IN p_product_id INT
)
BEGIN
    DECLARE _ctx_saved_user INT;
    DECLARE v_exists INT DEFAULT 0;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SET @app_user_id = _ctx_saved_user;
        ROLLBACK;
        RESIGNAL;
    END;

    SET _ctx_saved_user = @app_user_id;

    IF NOT EXISTS (SELECT 1 FROM companies c
                   WHERE c.company_id = p_seller_id AND c.company_type = 'SELLER') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Seller company not found';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM users u WHERE u.user_id = p_user_id AND u.status = 'ACTIVE'
                   AND ((u.role = 'SELLER' AND u.company_id = p_seller_id) OR u.role = 'ADMIN')) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'User is not authorized for this seller';
    END IF;

    START TRANSACTION;
    SELECT COUNT(*) INTO v_exists
    FROM products
    WHERE product_id = p_product_id AND owner_company_id = p_seller_id;
    IF v_exists = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Product not found for this seller';
    END IF;

    SET @app_user_id = p_user_id;
    UPDATE products SET is_active = TRUE
    WHERE product_id = p_product_id AND owner_company_id = p_seller_id;
    SET @app_user_id = _ctx_saved_user;
    COMMIT;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS `sp_search_products`;
DELIMITER $$
CREATE PROCEDURE sp_search_products(
    IN p_user_id INT,
    IN p_seller_id INT,
    IN p_keyword VARCHAR(120),
    IN p_include_inactive BOOLEAN
)
BEGIN
    DECLARE _caller_system_role VARCHAR(20);
    DECLARE _caller_company_id INT;

    SELECT role, company_id INTO _caller_system_role, _caller_company_id
    FROM users
    WHERE user_id = p_user_id AND status = 'ACTIVE';

    IF _caller_system_role IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Active user not found';
    END IF;
    IF _caller_system_role = 'SELLER' AND (p_seller_id IS NULL OR p_seller_id <> _caller_company_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Seller can view only their own products';
    ELSEIF _caller_system_role <> 'ADMIN' AND _caller_system_role <> 'SELLER' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Only Admin or Seller can view product catalogue';
    END IF;

    SELECT *
    FROM vw_fr4_product_catalog p
    WHERE (p_seller_id IS NULL OR p.seller_id = p_seller_id)
      AND (COALESCE(p_include_inactive, FALSE) = TRUE OR p.is_active = TRUE)
      AND (p_keyword IS NULL OR TRIM(p_keyword) = ''
           OR p.sku LIKE CONCAT('%', TRIM(p_keyword), '%')
           OR p.product_name LIKE CONCAT('%', TRIM(p_keyword), '%')
           OR p.category LIKE CONCAT('%', TRIM(p_keyword), '%')
           OR p.hs_code LIKE CONCAT('%', TRIM(p_keyword), '%'))
    ORDER BY p.product_name, p.product_id;
END$$
DELIMITER ;


-- ================================================================================================
-- SUBSYSTEM 3: PHYSICAL WAREHOUSE INVENTORY & LOT CONTROL (STOCK DOMAIN)
-- Physical stock lot management, container/shipment allocation, damage segregation, and availability guards.
-- ================================================================================================

DROP TRIGGER IF EXISTS `trg_fr4_before_stock_insert_guard`;
DELIMITER $$
CREATE TRIGGER trg_fr4_before_stock_insert_guard
BEFORE INSERT ON stock
FOR EACH ROW
BEGIN
    IF NEW.quantity < 0 OR NEW.damaged_qty < 0 OR NEW.reserved_qty < 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Stock, damaged and reserved quantities cannot be negative';
    END IF;
    IF NEW.damaged_qty + NEW.reserved_qty > NEW.quantity THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Damaged plus reserved quantity cannot exceed on-hand quantity';
    END IF;
END$$
DELIMITER ;

DROP TRIGGER IF EXISTS `trg_fr4_before_stock_update_guard`;
DELIMITER $$
CREATE TRIGGER trg_fr4_before_stock_update_guard
BEFORE UPDATE ON stock
FOR EACH ROW
BEGIN
    IF NEW.quantity < 0 OR NEW.damaged_qty < 0 OR NEW.reserved_qty < 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Stock, damaged and reserved quantities cannot be negative';
    END IF;
    IF NEW.damaged_qty + NEW.reserved_qty > NEW.quantity THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'On-hand quantity cannot be less than damaged plus reserved quantity';
    END IF;
    IF NEW.product_id <> OLD.product_id THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'A stock lot cannot be reassigned to another product';
    END IF;
    IF NEW.quantity <> OLD.quantity AND NEW.damaged_qty <> OLD.damaged_qty THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Change physical quantity and damaged quantity in separate operations';
    END IF;
    IF NEW.is_active = FALSE AND NEW.reserved_qty > 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Stock with active reservations cannot be deactivated';
    END IF;
END$$
DELIMITER ;

DROP TRIGGER IF EXISTS `trg_fr4_before_stock_delete_guard`;
DELIMITER $$
CREATE TRIGGER trg_fr4_before_stock_delete_guard
BEFORE DELETE ON stock
FOR EACH ROW
BEGIN
    IF OLD.quantity > 0 OR OLD.damaged_qty > 0 OR OLD.reserved_qty > 0
       OR EXISTS (SELECT 1 FROM inventory_ledger WHERE stock_id = OLD.stock_id)
       OR EXISTS (SELECT 1 FROM shipment_stock_reservations WHERE stock_id = OLD.stock_id) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Stock with quantity, reservation or ledger history cannot be deleted; deactivate it instead';
    END IF;
END$$
DELIMITER ;

DROP TRIGGER IF EXISTS `trg_fr4_after_stock_status_audit`;
DELIMITER $$
CREATE TRIGGER trg_fr4_after_stock_status_audit
AFTER UPDATE ON stock
FOR EACH ROW
BEGIN
    IF OLD.is_active <> NEW.is_active THEN
        INSERT INTO audit_log
            (user_id, action, table_name, record_id, old_value, new_value)
        VALUES
            (@app_user_id,
             CASE WHEN NEW.is_active = FALSE THEN 'STOCK_DEACTIVATE' ELSE 'STOCK_REACTIVATE' END,
             'stock', NEW.stock_id,
             JSON_OBJECT('is_active', OLD.is_active, 'quantity', OLD.quantity,
                         'damaged_qty', OLD.damaged_qty, 'reserved_qty', OLD.reserved_qty),
             JSON_OBJECT('is_active', NEW.is_active, 'quantity', NEW.quantity,
                         'damaged_qty', NEW.damaged_qty, 'reserved_qty', NEW.reserved_qty));
    END IF;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS `sp_add_stock`;
DELIMITER $$
CREATE PROCEDURE sp_add_stock(
    IN p_seller_id INT,
    IN p_user_id INT,
    IN p_product_id INT,
    IN p_quantity INT
)
BEGIN
    DECLARE _ctx_saved_user INT;
    DECLARE _ctx_saved_ref_type VARCHAR(30);
    DECLARE _ctx_saved_ref_id BIGINT;
    DECLARE _resolved_owner_company_id INT;
    DECLARE _allocated_stock_id INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SET @app_user_id = _ctx_saved_user;
        SET @app_reference_type = _ctx_saved_ref_type;
        SET @app_reference_id = _ctx_saved_ref_id;
        ROLLBACK;
        RESIGNAL;
    END;

    SET _ctx_saved_user = @app_user_id;
    SET _ctx_saved_ref_type = @app_reference_type;
    SET _ctx_saved_ref_id = @app_reference_id;

    IF NOT EXISTS (SELECT 1 FROM companies c
                   WHERE c.company_id = p_seller_id AND c.company_type = 'SELLER') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Seller company not found';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM users u WHERE u.user_id = p_user_id AND u.status = 'ACTIVE'
                   AND ((u.role = 'SELLER' AND u.company_id = p_seller_id) OR u.role = 'ADMIN')) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'User is not authorized for this seller';
    END IF;

    IF p_seller_id IS NULL OR p_user_id IS NULL OR p_product_id IS NULL
       OR p_quantity IS NULL OR p_quantity <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Stock quantity must be positive';
    END IF;

    START TRANSACTION;
    IF NOT EXISTS (SELECT 1 FROM products WHERE product_id = p_product_id
                   AND owner_company_id = p_seller_id AND is_active = TRUE) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Active product not found for this seller';
    END IF;
    SELECT owner_company_id INTO _resolved_owner_company_id
    FROM products
    WHERE product_id = p_product_id AND is_active = TRUE
    FOR UPDATE;

    IF _resolved_owner_company_id <> p_seller_id THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Active product not found for this seller';
    END IF;

    SET @app_user_id = p_user_id;
    SET @app_reference_type = 'STOCK_RECEIPT';
    SET @app_reference_id = NULL;

    INSERT INTO stock
        (product_id, shipment_id, container_id, quantity,
         damaged_qty, reserved_qty, is_active)
    VALUES (p_product_id, NULL, NULL, p_quantity, 0, 0, TRUE);
    SET _allocated_stock_id = LAST_INSERT_ID();

    SET @app_user_id = _ctx_saved_user;
    SET @app_reference_type = _ctx_saved_ref_type;
    SET @app_reference_id = _ctx_saved_ref_id;
    COMMIT;
    SELECT _allocated_stock_id AS stock_id;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS `sp_update_stock`;
DELIMITER $$
CREATE PROCEDURE sp_update_stock(
    IN p_seller_id INT,
    IN p_user_id INT,
    IN p_stock_id INT,
    IN p_new_quantity INT,
    IN p_reason VARCHAR(255)
)
BEGIN
    DECLARE _ctx_saved_user INT;
    DECLARE _ctx_saved_ref_type VARCHAR(30);
    DECLARE _ctx_saved_ref_id BIGINT;
    DECLARE _resolved_owner_company_id INT;
    DECLARE v_old_qty INT;
    DECLARE _existing_damaged_units INT;
    DECLARE _existing_reserved_units INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SET @app_user_id = _ctx_saved_user;
        SET @app_reference_type = _ctx_saved_ref_type;
        SET @app_reference_id = _ctx_saved_ref_id;
        ROLLBACK;
        RESIGNAL;
    END;

    SET _ctx_saved_user = @app_user_id;
    SET _ctx_saved_ref_type = @app_reference_type;
    SET _ctx_saved_ref_id = @app_reference_id;

    IF NOT EXISTS (SELECT 1 FROM companies c
                   WHERE c.company_id = p_seller_id AND c.company_type = 'SELLER') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Seller company not found';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM users u WHERE u.user_id = p_user_id AND u.status = 'ACTIVE'
                   AND ((u.role = 'SELLER' AND u.company_id = p_seller_id) OR u.role = 'ADMIN')) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'User is not authorized for this seller';
    END IF;

    IF p_stock_id IS NULL OR p_new_quantity IS NULL OR p_new_quantity < 0
       OR p_reason IS NULL OR TRIM(p_reason) = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'A non-negative quantity and adjustment reason are required';
    END IF;

    START TRANSACTION;
    IF NOT EXISTS (SELECT 1 FROM stock s JOIN products p ON p.product_id = s.product_id
                   WHERE s.stock_id = p_stock_id AND s.is_active = TRUE
                     AND p.owner_company_id = p_seller_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Active stock record not found for this seller';
    END IF;
    SELECT p.owner_company_id, s.quantity, s.damaged_qty, s.reserved_qty
      INTO _resolved_owner_company_id, v_old_qty, _existing_damaged_units, _existing_reserved_units
    FROM stock s
    JOIN products p ON p.product_id = s.product_id
    WHERE s.stock_id = p_stock_id AND s.is_active = TRUE
    FOR UPDATE;

    IF _resolved_owner_company_id <> p_seller_id THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Active stock record not found for this seller';
    END IF;
    IF p_new_quantity < (_existing_damaged_units + _existing_reserved_units) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Quantity cannot be reduced below damaged plus reserved quantity';
    END IF;
    IF p_new_quantity = v_old_qty THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'New quantity is the same as current quantity';
    END IF;

    SET @app_user_id = p_user_id;
    SET @app_reference_type = 'ADJUST';
    SET @app_reference_id = p_stock_id;

    UPDATE stock SET quantity = p_new_quantity WHERE stock_id = p_stock_id;

    INSERT INTO audit_log (user_id, action, table_name, record_id, old_value, new_value)
    VALUES (p_user_id, 'STOCK_ADJUST', 'stock', p_stock_id,
            JSON_OBJECT('quantity', v_old_qty, 'damaged_qty', _existing_damaged_units, 'reserved_qty', _existing_reserved_units),
            JSON_OBJECT('quantity', p_new_quantity, 'reason', TRIM(p_reason)));

    SET @app_user_id = _ctx_saved_user;
    SET @app_reference_type = _ctx_saved_ref_type;
    SET @app_reference_id = _ctx_saved_ref_id;
    COMMIT;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS `sp_damage_stock`;
DELIMITER $$
CREATE PROCEDURE sp_damage_stock(
    IN p_seller_id INT,
    IN p_user_id INT,
    IN p_stock_id INT,
    IN p_damage_qty INT,
    IN p_reason VARCHAR(255)
)
BEGIN
    DECLARE _ctx_saved_user INT;
    DECLARE _ctx_saved_ref_type VARCHAR(30);
    DECLARE _ctx_saved_ref_id BIGINT;
    DECLARE _resolved_owner_company_id INT;
    DECLARE _allocation_lot_units INT;
    DECLARE _existing_damaged_units INT;
    DECLARE _existing_reserved_units INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SET @app_user_id = _ctx_saved_user;
        SET @app_reference_type = _ctx_saved_ref_type;
        SET @app_reference_id = _ctx_saved_ref_id;
        ROLLBACK;
        RESIGNAL;
    END;

    SET _ctx_saved_user = @app_user_id;
    SET _ctx_saved_ref_type = @app_reference_type;
    SET _ctx_saved_ref_id = @app_reference_id;

    IF NOT EXISTS (SELECT 1 FROM companies c
                   WHERE c.company_id = p_seller_id AND c.company_type = 'SELLER') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Seller company not found';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM users u WHERE u.user_id = p_user_id AND u.status = 'ACTIVE'
                   AND ((u.role = 'SELLER' AND u.company_id = p_seller_id) OR u.role = 'ADMIN')) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'User is not authorized for this seller';
    END IF;

    IF p_stock_id IS NULL OR p_damage_qty IS NULL OR p_damage_qty <= 0
       OR p_reason IS NULL OR TRIM(p_reason) = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Positive damage quantity and reason are required';
    END IF;

    START TRANSACTION;
    IF NOT EXISTS (SELECT 1 FROM stock s JOIN products p ON p.product_id = s.product_id
                   WHERE s.stock_id = p_stock_id AND s.is_active = TRUE
                     AND p.owner_company_id = p_seller_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Active stock record not found for this seller';
    END IF;
    SELECT p.owner_company_id, s.quantity, s.damaged_qty, s.reserved_qty
      INTO _resolved_owner_company_id, _allocation_lot_units, _existing_damaged_units, _existing_reserved_units
    FROM stock s
    JOIN products p ON p.product_id = s.product_id
    WHERE s.stock_id = p_stock_id AND s.is_active = TRUE
    FOR UPDATE;

    IF _resolved_owner_company_id <> p_seller_id THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Active stock record not found for this seller';
    END IF;
    IF p_damage_qty > (_allocation_lot_units - _existing_damaged_units - _existing_reserved_units) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Damage quantity exceeds unreserved usable stock';
    END IF;

    SET @app_user_id = p_user_id;
    SET @app_reference_type = CONCAT('DAMAGE:', LEFT(TRIM(p_reason), 23));
    SET @app_reference_id = p_stock_id;

    UPDATE stock SET damaged_qty = damaged_qty + p_damage_qty
    WHERE stock_id = p_stock_id;

    INSERT INTO audit_log (user_id, action, table_name, record_id, old_value, new_value)
    VALUES (p_user_id, 'STOCK_DAMAGE', 'stock', p_stock_id,
            JSON_OBJECT('quantity', _allocation_lot_units, 'damaged_qty', _existing_damaged_units, 'reserved_qty', _existing_reserved_units),
            JSON_OBJECT('quantity', _allocation_lot_units, 'damaged_qty', _existing_damaged_units + p_damage_qty,
                        'reason', TRIM(p_reason)));

    SET @app_user_id = _ctx_saved_user;
    SET @app_reference_type = _ctx_saved_ref_type;
    SET @app_reference_id = _ctx_saved_ref_id;
    COMMIT;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS `sp_adjust_damaged_stock`;
DELIMITER $$
CREATE PROCEDURE sp_adjust_damaged_stock(
    IN p_seller_id INT,
    IN p_user_id INT,
    IN p_stock_id INT,
    IN p_new_damaged_qty INT,
    IN p_reason VARCHAR(255)
)
BEGIN
    DECLARE _ctx_saved_user INT;
    DECLARE _ctx_saved_ref_type VARCHAR(30);
    DECLARE _ctx_saved_ref_id BIGINT;
    DECLARE _resolved_owner_company_id INT;
    DECLARE v_quantity INT;
    DECLARE v_old_damaged INT;
    DECLARE _existing_reserved_units INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SET @app_user_id = _ctx_saved_user;
        SET @app_reference_type = _ctx_saved_ref_type;
        SET @app_reference_id = _ctx_saved_ref_id;
        ROLLBACK;
        RESIGNAL;
    END;

    SET _ctx_saved_user = @app_user_id;
    SET _ctx_saved_ref_type = @app_reference_type;
    SET _ctx_saved_ref_id = @app_reference_id;

    IF NOT EXISTS (SELECT 1 FROM companies c
                   WHERE c.company_id = p_seller_id AND c.company_type = 'SELLER') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Seller company not found';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM users u WHERE u.user_id = p_user_id AND u.status = 'ACTIVE'
                   AND ((u.role = 'SELLER' AND u.company_id = p_seller_id) OR u.role = 'ADMIN')) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'User is not authorized for this seller';
    END IF;

    IF p_stock_id IS NULL OR p_new_damaged_qty IS NULL OR p_new_damaged_qty < 0
       OR p_reason IS NULL OR TRIM(p_reason) = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Non-negative damaged quantity and reason are required';
    END IF;

    START TRANSACTION;
    IF NOT EXISTS (SELECT 1 FROM stock s JOIN products p ON p.product_id = s.product_id
                   WHERE s.stock_id = p_stock_id AND s.is_active = TRUE
                     AND p.owner_company_id = p_seller_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Active stock record not found for this seller';
    END IF;
    SELECT p.owner_company_id, s.quantity, s.damaged_qty, s.reserved_qty
      INTO _resolved_owner_company_id, v_quantity, v_old_damaged, _existing_reserved_units
    FROM stock s
    JOIN products p ON p.product_id = s.product_id
    WHERE s.stock_id = p_stock_id AND s.is_active = TRUE
    FOR UPDATE;

    IF _resolved_owner_company_id <> p_seller_id THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Active stock record not found for this seller';
    END IF;
    IF p_new_damaged_qty >= v_old_damaged THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Use sp_damage_stock to record additional damage';
    END IF;

    SET @app_user_id = p_user_id;
    SET @app_reference_type = CONCAT('REPAIR:', LEFT(TRIM(p_reason), 23));
    SET @app_reference_id = p_stock_id;

    UPDATE stock SET damaged_qty = p_new_damaged_qty WHERE stock_id = p_stock_id;

    INSERT INTO audit_log (user_id, action, table_name, record_id, old_value, new_value)
    VALUES (p_user_id, 'STOCK_DAMAGE_ADJUST', 'stock', p_stock_id,
            JSON_OBJECT('damaged_qty', v_old_damaged),
            JSON_OBJECT('damaged_qty', p_new_damaged_qty, 'reason', TRIM(p_reason)));

    SET @app_user_id = _ctx_saved_user;
    SET @app_reference_type = _ctx_saved_ref_type;
    SET @app_reference_id = _ctx_saved_ref_id;
    COMMIT;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS `sp_deactivate_stock`;
DELIMITER $$
CREATE PROCEDURE sp_deactivate_stock(
    IN p_seller_id INT,
    IN p_user_id INT,
    IN p_stock_id INT
)
BEGIN
    DECLARE _ctx_saved_user INT;
    DECLARE _resolved_owner_company_id INT;
    DECLARE _allocation_lot_units INT;
    DECLARE _existing_damaged_units INT;
    DECLARE _existing_reserved_units INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SET @app_user_id = _ctx_saved_user;
        ROLLBACK;
        RESIGNAL;
    END;

    SET _ctx_saved_user = @app_user_id;

    IF NOT EXISTS (SELECT 1 FROM companies c
                   WHERE c.company_id = p_seller_id AND c.company_type = 'SELLER') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Seller company not found';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM users u WHERE u.user_id = p_user_id AND u.status = 'ACTIVE'
                   AND ((u.role = 'SELLER' AND u.company_id = p_seller_id) OR u.role = 'ADMIN')) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'User is not authorized for this seller';
    END IF;

    START TRANSACTION;
    IF NOT EXISTS (SELECT 1 FROM stock s JOIN products p ON p.product_id = s.product_id
                   WHERE s.stock_id = p_stock_id AND s.is_active = TRUE
                     AND p.owner_company_id = p_seller_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Active stock record not found for this seller';
    END IF;
    SELECT p.owner_company_id, s.quantity, s.damaged_qty, s.reserved_qty
      INTO _resolved_owner_company_id, _allocation_lot_units, _existing_damaged_units, _existing_reserved_units
    FROM stock s
    JOIN products p ON p.product_id = s.product_id
    WHERE s.stock_id = p_stock_id AND s.is_active = TRUE
    FOR UPDATE;

    IF _resolved_owner_company_id <> p_seller_id THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Active stock record not found for this seller';
    END IF;
    IF _existing_reserved_units > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Stock lot has active reservations and cannot be deactivated';
    END IF;
    IF _allocation_lot_units > 0 OR _existing_damaged_units > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Stock lot has on-hand or damaged quantity; adjust to zero before deactivation';
    END IF;

    SET @app_user_id = p_user_id;
    UPDATE stock SET is_active = FALSE WHERE stock_id = p_stock_id;
    SET @app_user_id = _ctx_saved_user;
    COMMIT;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS `sp_reactivate_stock`;
DELIMITER $$
CREATE PROCEDURE sp_reactivate_stock(
    IN p_seller_id INT,
    IN p_user_id INT,
    IN p_stock_id INT
)
BEGIN
    DECLARE _ctx_saved_user INT;
    DECLARE _resolved_owner_company_id INT;
    DECLARE v_product_active BOOLEAN;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SET @app_user_id = _ctx_saved_user;
        ROLLBACK;
        RESIGNAL;
    END;

    SET _ctx_saved_user = @app_user_id;

    IF NOT EXISTS (SELECT 1 FROM companies c
                   WHERE c.company_id = p_seller_id AND c.company_type = 'SELLER') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Seller company not found';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM users u WHERE u.user_id = p_user_id AND u.status = 'ACTIVE'
                   AND ((u.role = 'SELLER' AND u.company_id = p_seller_id) OR u.role = 'ADMIN')) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'User is not authorized for this seller';
    END IF;

    START TRANSACTION;
    IF NOT EXISTS (SELECT 1 FROM stock s JOIN products p ON p.product_id = s.product_id
                   WHERE s.stock_id = p_stock_id AND p.owner_company_id = p_seller_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Stock record not found for this seller';
    END IF;
    SELECT p.owner_company_id, p.is_active
      INTO _resolved_owner_company_id, v_product_active
    FROM stock s
    JOIN products p ON p.product_id = s.product_id
    WHERE s.stock_id = p_stock_id
    FOR UPDATE;

    IF _resolved_owner_company_id <> p_seller_id THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Stock record not found for this seller';
    END IF;
    IF v_product_active = FALSE THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cannot reactivate a stock lot for a deactivated product';
    END IF;

    SET @app_user_id = p_user_id;
    UPDATE stock SET is_active = TRUE WHERE stock_id = p_stock_id;
    SET @app_user_id = _ctx_saved_user;
    COMMIT;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS `sp_search_stock`;
DELIMITER $$
CREATE PROCEDURE sp_search_stock(
    IN p_user_id INT,
    IN p_seller_id INT,
    IN p_keyword VARCHAR(120),
    IN p_include_inactive BOOLEAN
)
BEGIN
    DECLARE _caller_system_role VARCHAR(20);
    DECLARE _caller_company_id INT;

    SELECT role, company_id INTO _caller_system_role, _caller_company_id
    FROM users
    WHERE user_id = p_user_id AND status = 'ACTIVE';

    IF _caller_system_role IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Active user not found';
    END IF;
    IF _caller_system_role = 'SELLER' AND (p_seller_id IS NULL OR p_seller_id <> _caller_company_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Seller can search only their own stock';
    ELSEIF _caller_system_role <> 'ADMIN' AND _caller_system_role <> 'SELLER' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Only Admin or Seller can search stock';
    END IF;

    SELECT *
    FROM vw_fr4_stock_live s
    WHERE (p_seller_id IS NULL OR s.seller_id = p_seller_id)
      AND (COALESCE(p_include_inactive, FALSE) = TRUE OR s.is_active = TRUE)
      AND (p_keyword IS NULL OR TRIM(p_keyword) = ''
           OR s.sku LIKE CONCAT('%', TRIM(p_keyword), '%')
           OR s.product_name LIKE CONCAT('%', TRIM(p_keyword), '%')
           OR s.category LIKE CONCAT('%', TRIM(p_keyword), '%')
           OR s.hs_code LIKE CONCAT('%', TRIM(p_keyword), '%')
           OR s.stock_id = CAST(p_keyword AS SIGNED))
    ORDER BY s.product_name, s.stock_id;
END$$
DELIMITER ;


-- ================================================================================================
-- SUBSYSTEM 4: FINANCIAL AUDIT JOURNAL & LEDGER IMMUTABILITY
-- Append-only inventory movement ledger, strict immutability guards, and transaction audit reporting.
-- ================================================================================================

DROP TRIGGER IF EXISTS `trg_inventory_ledger_before_update_immutable`;
DELIMITER $$
CREATE TRIGGER trg_inventory_ledger_before_update_immutable
BEFORE UPDATE ON inventory_ledger
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Inventory ledger entries are immutable; post a correcting transaction instead';
END$$
DELIMITER ;

DROP TRIGGER IF EXISTS `trg_inventory_ledger_before_delete_immutable`;
DELIMITER $$
CREATE TRIGGER trg_inventory_ledger_before_delete_immutable
BEFORE DELETE ON inventory_ledger
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Inventory ledger entries cannot be deleted';
END$$
DELIMITER ;

DROP TRIGGER IF EXISTS `trg_after_stock_insert_ledger`;
DELIMITER $$
CREATE TRIGGER trg_after_stock_insert_ledger
AFTER INSERT ON stock
FOR EACH ROW
BEGIN
    IF NEW.quantity > 0 THEN
        INSERT INTO inventory_ledger
            (stock_id, product_id, txn_type, quantity, balance_after,
             reference_type, reference_id, changed_by, txn_time)
        VALUES
            (NEW.stock_id, NEW.product_id, 'IN', NEW.quantity,
             NEW.quantity,
             COALESCE(@app_reference_type, 'OPENING'), @app_reference_id,
             @app_user_id, CURRENT_TIMESTAMP);
    END IF;

    IF NEW.damaged_qty > 0 THEN
        INSERT INTO inventory_ledger
            (stock_id, product_id, txn_type, quantity, balance_after,
             reference_type, reference_id, changed_by, txn_time)
        VALUES
            (NEW.stock_id, NEW.product_id, 'DAMAGE', NEW.damaged_qty,
             NEW.quantity - NEW.damaged_qty,
             COALESCE(@app_reference_type, 'OPENING_DAMAGE'), @app_reference_id,
             @app_user_id, CURRENT_TIMESTAMP);
    END IF;
END$$
DELIMITER ;

DROP TRIGGER IF EXISTS `trg_after_stock_update_ledger`;
DELIMITER $$
CREATE TRIGGER trg_after_stock_update_ledger
AFTER UPDATE ON stock
FOR EACH ROW
BEGIN
    DECLARE v_txn_type VARCHAR(20);

    IF NOT (OLD.quantity <=> NEW.quantity) THEN
        SET v_txn_type = CASE
            WHEN @app_reference_type = 'CLAIM' THEN 'CLAIM_LOSS'
            WHEN @app_reference_type = 'ADJUST' THEN 'ADJUST'
            WHEN NEW.quantity > OLD.quantity THEN 'IN'
            ELSE 'OUT'
        END;

        INSERT INTO inventory_ledger
            (stock_id, product_id, txn_type, quantity, balance_after,
             reference_type, reference_id, changed_by, txn_time)
        VALUES
            (NEW.stock_id, NEW.product_id, v_txn_type,
             ABS(NEW.quantity - OLD.quantity),
             NEW.quantity - NEW.damaged_qty,
             COALESCE(@app_reference_type, 'STOCK_UPDATE'),
             @app_reference_id, @app_user_id, CURRENT_TIMESTAMP);
    END IF;

    IF NEW.damaged_qty > OLD.damaged_qty THEN
        INSERT INTO inventory_ledger
            (stock_id, product_id, txn_type, quantity, balance_after,
             reference_type, reference_id, changed_by, txn_time)
        VALUES
            (NEW.stock_id, NEW.product_id, 'DAMAGE',
             NEW.damaged_qty - OLD.damaged_qty,
             NEW.quantity - NEW.damaged_qty,
             COALESCE(@app_reference_type, 'DAMAGE'),
             @app_reference_id, @app_user_id, CURRENT_TIMESTAMP);
    ELSEIF NEW.damaged_qty < OLD.damaged_qty THEN
        INSERT INTO inventory_ledger
            (stock_id, product_id, txn_type, quantity, balance_after,
             reference_type, reference_id, changed_by, txn_time)
        VALUES
            (NEW.stock_id, NEW.product_id, 'ADJUST',
             OLD.damaged_qty - NEW.damaged_qty,
             NEW.quantity - NEW.damaged_qty,
             COALESCE(@app_reference_type, 'DAMAGE_REVERSAL'),
             @app_reference_id, @app_user_id, CURRENT_TIMESTAMP);
    END IF;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS `sp_stock_ledger_report`;
DELIMITER $$
CREATE PROCEDURE sp_stock_ledger_report(
    IN p_user_id INT,
    IN p_seller_id INT,
    IN p_stock_id INT,
    IN p_product_id INT,
    IN p_from_date DATETIME,
    IN p_to_date DATETIME
)
BEGIN
    DECLARE _caller_system_role VARCHAR(20);
    DECLARE _caller_company_id INT;

    SELECT role, company_id INTO _caller_system_role, _caller_company_id
    FROM users
    WHERE user_id = p_user_id AND status = 'ACTIVE';

    IF _caller_system_role IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Active user not found';
    END IF;
    IF _caller_system_role = 'SELLER' AND (p_seller_id IS NULL OR p_seller_id <> _caller_company_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Seller can view only their own ledger history';
    ELSEIF _caller_system_role <> 'ADMIN' AND _caller_system_role <> 'SELLER' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Only Admin or Seller can view inventory ledger';
    END IF;

    SELECT *
    FROM vw_fr4_inventory_ledger_live l
    WHERE (p_seller_id IS NULL OR l.seller_id = p_seller_id)
      AND (p_stock_id IS NULL OR l.stock_id = p_stock_id)
      AND (p_product_id IS NULL OR l.product_id = p_product_id)
      AND (p_from_date IS NULL OR l.txn_time >= p_from_date)
      AND (p_to_date IS NULL OR l.txn_time <= p_to_date)
    ORDER BY l.txn_time DESC, l.ledger_id DESC;
END$$
DELIMITER ;


-- ================================================================================================
-- SUBSYSTEM 5: BATCH INGESTION, MULTI-TIER VALIDATION & ASYNC INTAKE
-- Feed staging structures, multi-stage data hygiene validation, error diagnosis reports, and atomic catalog import.
-- ================================================================================================

DROP PROCEDURE IF EXISTS `sp_create_stock_upload_batch`;
DELIMITER $$
CREATE PROCEDURE sp_create_stock_upload_batch(
    IN p_seller_id INT,
    IN p_user_id INT,
    IN p_file_name VARCHAR(255),
    OUT p_batch_id BIGINT
)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM companies c
                   WHERE c.company_id = p_seller_id AND c.company_type = 'SELLER') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Seller company not found';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM users u WHERE u.user_id = p_user_id AND u.status = 'ACTIVE'
                   AND ((u.role = 'SELLER' AND u.company_id = p_seller_id) OR u.role = 'ADMIN')) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'User is not authorized for this seller';
    END IF;

    INSERT INTO stock_upload_batches (seller_id, uploaded_by, source_file_name, batch_status)
    VALUES (p_seller_id, p_user_id, p_file_name, 'PENDING');
    SET p_batch_id = LAST_INSERT_ID();
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS `sp_validate_stock_upload`;
DELIMITER $$
CREATE PROCEDURE sp_validate_stock_upload(
    IN p_batch_id BIGINT
)
BEGIN
    DECLARE v_seller_id INT;
    DECLARE v_valid_count INT DEFAULT 0;
    DECLARE v_error_count INT DEFAULT 0;

    SELECT seller_id INTO v_seller_id
    FROM stock_upload_batches
    WHERE batch_id = p_batch_id;

    IF v_seller_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Upload batch not found';
    END IF;

    UPDATE stock_upload_staging
    SET row_status = 'VALID', error_message = NULL
    WHERE batch_id = p_batch_id AND row_status <> 'IMPORTED';

    UPDATE stock_upload_staging
    SET row_status = 'ERROR', error_message = 'SKU and quantity are mandatory'
    WHERE batch_id = p_batch_id AND row_status = 'VALID'
      AND (sku IS NULL OR TRIM(sku) = '' OR quantity_text IS NULL OR TRIM(quantity_text) = '');

    UPDATE stock_upload_staging
    SET row_status = 'ERROR', error_message = 'Quantity must be a positive whole number'
    WHERE batch_id = p_batch_id AND row_status = 'VALID'
      AND (TRIM(quantity_text) NOT REGEXP '^[0-9]+$' OR CAST(TRIM(quantity_text) AS UNSIGNED) = 0);

    UPDATE stock_upload_staging s
    LEFT JOIN products p ON p.sku = TRIM(s.sku) AND p.owner_company_id = v_seller_id AND p.is_active = TRUE
    SET s.row_status = 'ERROR',
        s.error_message = 'Active product not found in seller catalogue'
    WHERE s.batch_id = p_batch_id AND s.row_status = 'VALID' AND p.product_id IS NULL;

    UPDATE stock_upload_staging s
    JOIN (
        SELECT TRIM(sku) AS dup_sku
        FROM stock_upload_staging
        WHERE batch_id = p_batch_id AND sku IS NOT NULL AND TRIM(sku) <> ''
        GROUP BY TRIM(sku)
        HAVING COUNT(*) > 1
    ) d ON d.dup_sku = TRIM(s.sku)
    SET s.row_status = 'ERROR',
        s.error_message = 'Duplicate SKU inside uploaded file'
    WHERE s.batch_id = p_batch_id AND s.row_status = 'VALID';

    SELECT COUNT(CASE WHEN row_status = 'VALID' THEN 1 END),
           COUNT(CASE WHEN row_status = 'ERROR' THEN 1 END)
      INTO v_valid_count, v_error_count
    FROM stock_upload_staging
    WHERE batch_id = p_batch_id;

    UPDATE stock_upload_batches
    SET batch_status = CASE WHEN v_error_count = 0 THEN 'VALIDATED' ELSE 'PARTIAL' END,
        valid_row_count = v_valid_count,
        error_row_count = v_error_count,
        validated_at = CURRENT_TIMESTAMP
    WHERE batch_id = p_batch_id;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS `sp_stock_upload_validation_report`;
DELIMITER $$
CREATE PROCEDURE sp_stock_upload_validation_report(
    IN p_batch_id BIGINT
)
BEGIN
    SELECT b.batch_id, b.seller_id, c.company_name AS seller_name,
           b.source_file_name, b.batch_status,
           b.valid_row_count, b.error_row_count, b.imported_row_count,
           b.validated_at, b.imported_at
    FROM stock_upload_batches b
    JOIN companies c ON c.company_id = b.seller_id
    WHERE b.batch_id = p_batch_id;

    SELECT row_id, sku, quantity_text, row_status, error_message
    FROM stock_upload_staging
    WHERE batch_id = p_batch_id
    ORDER BY row_id;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS `sp_import_valid_stock_upload`;
DELIMITER $$
CREATE PROCEDURE sp_import_valid_stock_upload(
    IN p_batch_id BIGINT,
    IN p_user_id INT,
    OUT p_imported_rows INT
)
BEGIN
    DECLARE v_seller_id INT;
    DECLARE _allocation_status_code VARCHAR(20);
    DECLARE v_valid_count INT DEFAULT 0;
    DECLARE _imported_rows_tally INT DEFAULT 0;
    DECLARE _ctx_saved_user INT;
    DECLARE _ctx_saved_ref_type VARCHAR(30);
    DECLARE _ctx_saved_ref_id BIGINT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SET @app_user_id = _ctx_saved_user;
        SET @app_reference_type = _ctx_saved_ref_type;
        SET @app_reference_id = _ctx_saved_ref_id;
        ROLLBACK;
        RESIGNAL;
    END;

    SET _ctx_saved_user = @app_user_id;
    SET _ctx_saved_ref_type = @app_reference_type;
    SET _ctx_saved_ref_id = @app_reference_id;

    SELECT seller_id, batch_status INTO v_seller_id, _allocation_status_code
    FROM stock_upload_batches WHERE batch_id = p_batch_id;

    IF v_seller_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Upload batch not found';
    END IF;
    IF _allocation_status_code NOT IN ('VALIDATED','PARTIAL') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Batch must be validated before import';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM users u WHERE u.user_id = p_user_id AND u.status = 'ACTIVE'
                   AND ((u.role = 'SELLER' AND u.company_id = v_seller_id) OR u.role = 'ADMIN')) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'User is not authorized for this seller';
    END IF;

    SELECT COUNT(*) INTO v_valid_count
    FROM stock_upload_staging
    WHERE batch_id = p_batch_id AND row_status = 'VALID';

    IF v_valid_count = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No valid rows available to import';
    END IF;

    START TRANSACTION;
    SET @app_user_id = p_user_id;
    SET @app_reference_type = 'STOCK_UPLOAD';
    SET @app_reference_id = p_batch_id;

    INSERT INTO stock (product_id, shipment_id, container_id, quantity, damaged_qty, reserved_qty, is_active)
    SELECT p.product_id, NULL, NULL, CAST(TRIM(s.quantity_text) AS UNSIGNED), 0, 0, TRUE
    FROM stock_upload_staging s
    JOIN products p ON p.sku = TRIM(s.sku) AND p.owner_company_id = v_seller_id AND p.is_active = TRUE
    WHERE s.batch_id = p_batch_id AND s.row_status = 'VALID';

    SET _imported_rows_tally = ROW_COUNT();

    UPDATE stock_upload_staging
    SET row_status = 'IMPORTED'
    WHERE batch_id = p_batch_id AND row_status = 'VALID';

    UPDATE stock_upload_batches
    SET batch_status = 'IMPORTED',
        imported_row_count = _imported_rows_tally,
        imported_at = CURRENT_TIMESTAMP
    WHERE batch_id = p_batch_id;

    INSERT INTO audit_log (user_id, action, table_name, record_id, old_value, new_value)
    VALUES (p_user_id, 'STOCK_UPLOAD_IMPORT', 'stock_upload_batches', p_batch_id,
            JSON_OBJECT('status', _allocation_status_code),
            JSON_OBJECT('status', 'IMPORTED', 'imported_rows', _imported_rows_tally));

    SET @app_user_id = _ctx_saved_user;
    SET @app_reference_type = _ctx_saved_ref_type;
    SET @app_reference_id = _ctx_saved_ref_id;
    COMMIT;

    SET p_imported_rows = _imported_rows_tally;
END$$
DELIMITER ;


-- ================================================================================================
-- SUBSYSTEM 6: SHIPMENT FULFILLMENT & REVENUE RECOGNITION (SALES BRIDGE)
-- Shipment reservation allocation cursor, automatic sales transaction creation upon DELIVERED, and role-based sales queries.
-- ================================================================================================

DROP PROCEDURE IF EXISTS `sp_shipment_stock_report`;
DELIMITER $$
CREATE PROCEDURE sp_shipment_stock_report(
    IN p_shipment_id INT
)
BEGIN
    SELECT *
    FROM vw_fr4_shipment_stock_summary
    WHERE shipment_id = p_shipment_id;

    SELECT *
    FROM vw_fr4_shipment_stock_details
    WHERE shipment_id = p_shipment_id
    ORDER BY shipment_item_id;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS `sp_record_sales_transaction`;
DELIMITER $$
CREATE PROCEDURE sp_record_sales_transaction(
    IN p_user_id INT,
    IN p_product_id INT,
    IN p_customer_id INT,
    IN p_shipment_id INT,
    IN p_quantity INT,
    IN p_unit_price DECIMAL(12,2),
    IN p_sale_date DATE,
    OUT p_sale_id BIGINT
)
BEGIN
    DECLARE _batch_total_rows DECIMAL(14,2);

    IF p_quantity IS NULL OR p_quantity <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Sales quantity must be positive';
    END IF;
    IF p_unit_price IS NULL OR p_unit_price < 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Unit price cannot be negative';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM products WHERE product_id = p_product_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Product not found';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM customers WHERE customer_id = p_customer_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Customer not found';
    END IF;

    SET _batch_total_rows = ROUND(p_quantity * p_unit_price, 2);

    INSERT INTO sales_transactions
        (product_id, customer_id, shipment_id, quantity, unit_price, total_amount, sale_date)
    VALUES
        (p_product_id, p_customer_id, p_shipment_id, p_quantity, p_unit_price, _batch_total_rows,
         COALESCE(p_sale_date, CURDATE()));

    SET p_sale_id = LAST_INSERT_ID();
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS `sp_show_sales_transactions`;
DELIMITER $$
CREATE PROCEDURE sp_show_sales_transactions(
    IN p_user_id INT,
    IN p_seller_id INT,
    IN p_from_date DATE,
    IN p_to_date DATE
)
BEGIN
    DECLARE _caller_system_role VARCHAR(20);
    DECLARE _caller_company_id INT;

    SELECT role, company_id INTO _caller_system_role, _caller_company_id
    FROM users
    WHERE user_id = p_user_id AND status = 'ACTIVE';

    IF _caller_system_role IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Active user not found';
    END IF;
    IF _caller_system_role = 'SELLER' AND (p_seller_id IS NULL OR p_seller_id <> _caller_company_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Seller can view only their own sales transactions';
    ELSEIF _caller_system_role <> 'ADMIN' AND _caller_system_role <> 'SELLER' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Only Admin or Seller can view sales transactions';
    END IF;

    SELECT *
    FROM vw_fr4_sales_transactions_live st
    WHERE (p_seller_id IS NULL OR st.seller_id = p_seller_id)
      AND (p_from_date IS NULL OR st.sale_date >= p_from_date)
      AND (p_to_date IS NULL OR st.sale_date <= p_to_date)
    ORDER BY st.sale_date DESC, st.sale_id DESC;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS `sp_record_shipment_sales`;
DELIMITER $$
CREATE PROCEDURE sp_record_shipment_sales(
    IN p_shipment_id INT
)
BEGIN
    INSERT INTO sales_transactions 
        (product_id, customer_id, shipment_id, quantity, unit_price, total_amount, sale_date)
    SELECT 
        si.product_id, 
        sh.consumer_id, 
        sh.shipment_id, 
        si.quantity, 
        si.unit_price, 
        ROUND(si.quantity * si.unit_price, 2), 
        COALESCE(DATE(sh.actual_arrival), CURDATE())
    FROM shipment_items si
    JOIN shipment sh ON sh.shipment_id = si.shipment_id
    WHERE sh.shipment_id = p_shipment_id
      AND NOT EXISTS (
          SELECT 1 FROM sales_transactions st 
          WHERE st.shipment_id = sh.shipment_id 
            AND st.product_id = si.product_id
      );
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS `sp_finalize_shipment_stock`;
DELIMITER $$
CREATE PROCEDURE sp_finalize_shipment_stock(
    IN p_shipment_id INT,
    IN p_action VARCHAR(10)
)
BEGIN
    DECLARE _fetch_cursor_finished INT DEFAULT 0;
    DECLARE _current_reservation_id BIGINT;
    DECLARE _allocated_stock_id INT;
    DECLARE _allocation_lot_units INT;
    DECLARE _allocation_status_code VARCHAR(20);

    DECLARE cursor_active_allocations CURSOR FOR
        SELECT reservation_id, stock_id, quantity_reserved, status
        FROM shipment_stock_reservations
        WHERE shipment_id = p_shipment_id AND status = 'RESERVED'
        ORDER BY reservation_id
        FOR UPDATE;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET _fetch_cursor_finished = 1;

    IF p_action NOT IN ('CONSUME','RELEASE') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Action must be CONSUME or RELEASE';
    END IF;

    SET @app_reference_type = 'SHIPMENT';
    SET @app_reference_id = p_shipment_id;

    OPEN cursor_active_allocations;
    process_allocations_loop: LOOP
        FETCH cursor_active_allocations INTO _current_reservation_id, _allocated_stock_id, _allocation_lot_units, _allocation_status_code;
        IF _fetch_cursor_finished = 1 THEN LEAVE process_allocations_loop; END IF;

        IF p_action = 'CONSUME' THEN
            UPDATE stock
            SET reserved_qty = reserved_qty - _allocation_lot_units,
                quantity = quantity - _allocation_lot_units
            WHERE stock_id = _allocated_stock_id
              AND reserved_qty >= _allocation_lot_units
              AND quantity - _allocation_lot_units >= damaged_qty;
            IF ROW_COUNT() <> 1 THEN
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Unable to consume reserved stock';
            END IF;
            UPDATE shipment_stock_reservations
            SET status = 'CONSUMED' WHERE reservation_id = _current_reservation_id;
        ELSE
            UPDATE stock
            SET reserved_qty = reserved_qty - _allocation_lot_units
            WHERE stock_id = _allocated_stock_id AND reserved_qty >= _allocation_lot_units;
            IF ROW_COUNT() <> 1 THEN
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Unable to release reserved stock';
            END IF;
            UPDATE shipment_stock_reservations
            SET status = 'RELEASED' WHERE reservation_id = _current_reservation_id;
        END IF;
    END LOOP;
    CLOSE cursor_active_allocations;

    IF p_action = 'CONSUME' THEN
        CALL sp_record_shipment_sales(p_shipment_id);
    END IF;
END$$
DELIMITER ;


-- ================================================================================================
-- SUBSYSTEM 7: OPERATIONAL MONITORING & REAL-TIME ANALYTICAL FABRIC
-- Real-time aggregated views for catalog availability, stock lot tracking, shipment cargo metrics, ledger, and sales (excluding created_at).
-- ================================================================================================

CREATE OR REPLACE VIEW vw_fr4_product_catalog AS
SELECT
    p.product_id,
    p.sku,
    p.product_name,
    p.category,
    p.hs_code,
    p.unit,
    p.unit_weight_kg,
    p.unit_volume_cbm,
    p.unit_price,
    p.unit_cost,
    p.owner_company_id AS seller_id,
    co.company_name AS seller_name,
    p.is_active,
    COALESCE(st.total_stock_qty, 0) AS total_stock_qty,
    COALESCE(st.total_damaged_qty, 0) AS total_damaged_qty,
    COALESCE(st.total_reserved_qty, 0) AS total_reserved_qty,
    COALESCE(st.total_available_qty, 0) AS total_available_qty
FROM products p
JOIN companies co ON co.company_id = p.owner_company_id
LEFT JOIN (
    SELECT product_id,
           SUM(quantity) AS total_stock_qty,
           SUM(damaged_qty) AS total_damaged_qty,
           SUM(reserved_qty) AS total_reserved_qty,
           SUM(quantity - damaged_qty - reserved_qty) AS total_available_qty
    FROM stock
    WHERE is_active = TRUE
    GROUP BY product_id
) st ON st.product_id = p.product_id;


CREATE OR REPLACE VIEW vw_fr4_stock_live AS
SELECT
    st.stock_id,
    p.product_id,
    p.sku,
    p.product_name,
    p.category,
    p.hs_code,
    p.unit,
    p.unit_weight_kg,
    p.unit_volume_cbm,
    p.unit_price,
    p.unit_cost,
    p.owner_company_id AS seller_id,
    co.company_name AS seller_name,
    st.quantity AS on_hand_qty,
    st.damaged_qty,
    st.reserved_qty,
    (st.quantity - st.damaged_qty - st.reserved_qty) AS available_qty,
    ((st.quantity - st.damaged_qty) * p.unit_price) AS usable_stock_value,
    ((st.quantity - st.damaged_qty - st.reserved_qty) * p.unit_price) AS available_stock_value,
    ((st.quantity - st.damaged_qty - st.reserved_qty) * p.unit_cost) AS available_stock_cost_value,
    st.shipment_id,
    st.container_id,
    st.is_active,
    st.last_updated
FROM stock st
JOIN products p ON p.product_id = st.product_id
JOIN companies co ON co.company_id = p.owner_company_id;


CREATE OR REPLACE VIEW vw_fr4_shipment_stock_details AS
SELECT
    sh.shipment_id,
    sh.shipment_no,
    sh.seller_id,
    sh.consumer_id,
    sh.status AS shipment_status,
    sh.container_id,
    c.container_number,
    si.item_id AS shipment_item_id,
    p.product_id,
    p.sku,
    p.product_name,
    si.quantity AS shipment_quantity,
    si.unit_price,
    si.amount AS line_stock_value,
    si.weight_kg,
    si.volume_cbm,
    COALESCE(r.reserved_quantity, 0) AS reserved_quantity,
    COALESCE(r.consumed_quantity, 0) AS consumed_quantity,
    COALESCE(r.released_quantity, 0) AS released_quantity
FROM shipment_items si
JOIN shipment sh ON sh.shipment_id = si.shipment_id
JOIN products p ON p.product_id = si.product_id
LEFT JOIN containers c ON c.container_id = sh.container_id
LEFT JOIN (
    SELECT shipment_item_id,
           SUM(CASE WHEN status = 'RESERVED' THEN quantity_reserved ELSE 0 END) AS reserved_quantity,
           SUM(CASE WHEN status = 'CONSUMED' THEN quantity_reserved ELSE 0 END) AS consumed_quantity,
           SUM(CASE WHEN status = 'RELEASED' THEN quantity_reserved ELSE 0 END) AS released_quantity
    FROM shipment_stock_reservations
    GROUP BY shipment_item_id
) r ON r.shipment_item_id = si.item_id;


CREATE OR REPLACE VIEW vw_fr4_shipment_stock_summary AS
SELECT
    d.shipment_id,
    d.shipment_no,
    d.seller_id,
    d.consumer_id,
    d.shipment_status,
    d.container_id,
    d.container_number,
    COUNT(*) AS product_line_count,
    SUM(d.shipment_quantity) AS total_stock_quantity,
    SUM(d.line_stock_value) AS total_stock_value,
    SUM(d.weight_kg) AS total_weight_kg,
    SUM(d.volume_cbm) AS total_volume_cbm,
    SUM(d.reserved_quantity) AS total_reserved_quantity,
    SUM(d.consumed_quantity) AS total_consumed_quantity
FROM vw_fr4_shipment_stock_details d
GROUP BY d.shipment_id, d.shipment_no, d.seller_id, d.consumer_id,
         d.shipment_status, d.container_id, d.container_number;


CREATE OR REPLACE VIEW vw_fr4_inventory_ledger_live AS
SELECT
    il.ledger_id,
    il.stock_id,
    il.product_id,
    p.sku,
    p.product_name,
    p.owner_company_id AS seller_id,
    co.company_name AS seller_name,
    il.txn_type,
    il.quantity AS transaction_quantity,
    il.balance_after,
    il.reference_type,
    il.reference_id,
    il.changed_by,
    u.full_name AS changed_by_name,
    il.txn_time
FROM inventory_ledger il
JOIN products p ON p.product_id = il.product_id
JOIN companies co ON co.company_id = p.owner_company_id
LEFT JOIN users u ON u.user_id = il.changed_by;


CREATE OR REPLACE VIEW vw_fr4_sales_transactions_live AS
SELECT
    st.sale_id,
    st.sale_date,
    st.product_id,
    p.sku,
    p.product_name,
    p.category,
    p.owner_company_id AS seller_id,
    c_seller.company_name AS seller_name,
    st.customer_id,
    COALESCE(co_cust.company_name, u_cust.full_name, cust.contact_person) AS customer_name,
    st.shipment_id,
    sh.shipment_no,
    st.quantity,
    st.unit_price,
    st.total_amount,
    p.unit_cost,
    ROUND(st.quantity * COALESCE(p.unit_cost, 0), 2) AS total_cost,
    ROUND(st.total_amount - (st.quantity * COALESCE(p.unit_cost, 0)), 2) AS gross_profit
FROM sales_transactions st
JOIN products p ON p.product_id = st.product_id
JOIN companies c_seller ON c_seller.company_id = p.owner_company_id
JOIN customers cust ON cust.customer_id = st.customer_id
LEFT JOIN users u_cust ON u_cust.user_id = cust.user_id
LEFT JOIN companies co_cust ON co_cust.company_id = cust.company_id
LEFT JOIN shipment sh ON sh.shipment_id = st.shipment_id;


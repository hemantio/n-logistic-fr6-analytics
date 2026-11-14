-- =============================================================================
-- N LOGISTICS MANAGEMENT PLATFORM
-- DATABASE AUDIT / EVENT LOGGING CORRECTION PATCH
-- Purpose: Align master database logging triggers with the supplied SRS audit map.
-- Run order: 1) Master schema + operational extension
--            2) FR4 stock module patch (if used)
--            3) This patch
--            4) FR6_DATABASE_HANDOVER_FIXED.sql
-- Database: n_logistic_db
-- MySQL 8.0+ / MariaDB 10.4+
-- =============================================================================

USE `n_logistic_db`;

-- -----------------------------------------------------------------------------
-- 0. PREFLIGHT
-- -----------------------------------------------------------------------------
SELECT req.table_name,
       IF(t.table_name IS NULL, 'MISSING', 'OK') AS table_status
FROM (
    SELECT 'audit_log' AS table_name UNION ALL
    SELECT 'container_movements' UNION ALL
    SELECT 'pricing_rules' UNION ALL
    SELECT 'pricing_audit' UNION ALL
    SELECT 'stock' UNION ALL
    SELECT 'inventory_ledger' UNION ALL
    SELECT 'payments' UNION ALL
    SELECT 'claims' UNION ALL
    SELECT 'claim_status_history'
) req
LEFT JOIN information_schema.tables t
  ON t.table_schema = DATABASE()
 AND t.table_name = req.table_name;

-- -----------------------------------------------------------------------------
-- 1. ENSURE PRICING AUDIT CAPTURES EVERY PRICING INPUT
--    The master schema already has old_rate/new_rate and old_multiplier/new_multiplier.
--    This adds the detailed fields introduced by the operational extension, if absent.
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS `sp_ensure_pricing_audit_detail_columns`;
DELIMITER $$
CREATE PROCEDURE `sp_ensure_pricing_audit_detail_columns`()
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = DATABASE() AND table_name = 'pricing_audit'
          AND column_name = 'old_rate_per_kg'
    ) THEN
        ALTER TABLE `pricing_audit` ADD COLUMN `old_rate_per_kg` DECIMAL(8,4) NULL;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = DATABASE() AND table_name = 'pricing_audit'
          AND column_name = 'new_rate_per_kg'
    ) THEN
        ALTER TABLE `pricing_audit` ADD COLUMN `new_rate_per_kg` DECIMAL(8,4) NULL;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = DATABASE() AND table_name = 'pricing_audit'
          AND column_name = 'old_rate_per_cbm'
    ) THEN
        ALTER TABLE `pricing_audit` ADD COLUMN `old_rate_per_cbm` DECIMAL(8,2) NULL;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = DATABASE() AND table_name = 'pricing_audit'
          AND column_name = 'new_rate_per_cbm'
    ) THEN
        ALTER TABLE `pricing_audit` ADD COLUMN `new_rate_per_cbm` DECIMAL(8,2) NULL;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = DATABASE() AND table_name = 'pricing_audit'
          AND column_name = 'old_season_multiplier'
    ) THEN
        ALTER TABLE `pricing_audit` ADD COLUMN `old_season_multiplier` DECIMAL(4,2) NULL;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = DATABASE() AND table_name = 'pricing_audit'
          AND column_name = 'new_season_multiplier'
    ) THEN
        ALTER TABLE `pricing_audit` ADD COLUMN `new_season_multiplier` DECIMAL(4,2) NULL;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = DATABASE() AND table_name = 'pricing_audit'
          AND column_name = 'old_demand_multiplier'
    ) THEN
        ALTER TABLE `pricing_audit` ADD COLUMN `old_demand_multiplier` DECIMAL(4,2) NULL;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = DATABASE() AND table_name = 'pricing_audit'
          AND column_name = 'new_demand_multiplier'
    ) THEN
        ALTER TABLE `pricing_audit` ADD COLUMN `new_demand_multiplier` DECIMAL(4,2) NULL;
    END IF;
END$$
DELIMITER ;
CALL `sp_ensure_pricing_audit_detail_columns`();
DROP PROCEDURE IF EXISTS `sp_ensure_pricing_audit_detail_columns`;

-- Every price-driving field is audited, including automatic FR6 forecast updates.
-- The application should SET @app_user_id before a manual Admin/Seller update.
-- Automated refresh updates may have NULL changed_by because there is no human actor.
DROP TRIGGER IF EXISTS `trg_after_pricing_rule_update`;
DELIMITER $$
CREATE TRIGGER `trg_after_pricing_rule_update`
AFTER UPDATE ON `pricing_rules`
FOR EACH ROW
BEGIN
    IF NOT (OLD.base_rate <=> NEW.base_rate)
       OR NOT (OLD.rate_per_kg <=> NEW.rate_per_kg)
       OR NOT (OLD.rate_per_cbm <=> NEW.rate_per_cbm)
       OR NOT (OLD.season_multiplier <=> NEW.season_multiplier)
       OR NOT (OLD.demand_multiplier <=> NEW.demand_multiplier) THEN

        INSERT INTO `pricing_audit` (
            `rule_id`,
            `old_rate`, `new_rate`,
            `old_multiplier`, `new_multiplier`,
            `changed_by`, `changed_at`,
            `old_rate_per_kg`, `new_rate_per_kg`,
            `old_rate_per_cbm`, `new_rate_per_cbm`,
            `old_season_multiplier`, `new_season_multiplier`,
            `old_demand_multiplier`, `new_demand_multiplier`
        ) VALUES (
            NEW.rule_id,
            OLD.base_rate, NEW.base_rate,
            OLD.demand_multiplier, NEW.demand_multiplier,
            @app_user_id, CURRENT_TIMESTAMP,
            OLD.rate_per_kg, NEW.rate_per_kg,
            OLD.rate_per_cbm, NEW.rate_per_cbm,
            OLD.season_multiplier, NEW.season_multiplier,
            OLD.demand_multiplier, NEW.demand_multiplier
        );
    END IF;
END$$
DELIMITER ;

-- -----------------------------------------------------------------------------
-- 2. CLAIM STATUS HISTORY: RECORD THE ACTING USER
--    Set @app_user_id and optionally @app_audit_remarks on the same connection
--    before changing a claim status.
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS `trg_after_claim_status_change`;
DELIMITER $$
CREATE TRIGGER `trg_after_claim_status_change`
AFTER UPDATE ON `claims`
FOR EACH ROW
BEGIN
    IF NOT (OLD.status <=> NEW.status) THEN
        INSERT INTO `claim_status_history`
            (`claim_id`, `old_status`, `new_status`, `changed_by`, `remarks`, `changed_at`)
        VALUES
            (NEW.claim_id, OLD.status, NEW.status, @app_user_id,
             COALESCE(@app_audit_remarks, NEW.seller_remarks), CURRENT_TIMESTAMP);
    END IF;
END$$
DELIMITER ;

-- -----------------------------------------------------------------------------
-- 3. INVENTORY LEDGER: SUPPORT ADJUST AND CLAIM_LOSS TRANSACTION TYPES
--    Set @app_reference_type='ADJUST' for explicit stock corrections;
--    set it to 'CLAIM' for loss deductions. Keep @app_user_id and reference IDs
--    set on the same DB connection as the stock update.
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS `trg_after_stock_update_ledger`;
DELIMITER $$
CREATE TRIGGER `trg_after_stock_update_ledger`
AFTER UPDATE ON `stock`
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

        INSERT INTO `inventory_ledger`
            (`stock_id`, `product_id`, `txn_type`, `quantity`, `balance_after`,
             `reference_type`, `reference_id`, `changed_by`, `txn_time`)
        VALUES
            (NEW.stock_id, NEW.product_id, v_txn_type,
             ABS(NEW.quantity - OLD.quantity),
             NEW.quantity - OLD.damaged_qty,
             COALESCE(@app_reference_type, 'STOCK_UPDATE'),
             @app_reference_id, @app_user_id, CURRENT_TIMESTAMP);
    END IF;

    IF NEW.damaged_qty > OLD.damaged_qty THEN
        INSERT INTO `inventory_ledger`
            (`stock_id`, `product_id`, `txn_type`, `quantity`, `balance_after`,
             `reference_type`, `reference_id`, `changed_by`, `txn_time`)
        VALUES
            (NEW.stock_id, NEW.product_id, 'DAMAGE',
             NEW.damaged_qty - OLD.damaged_qty,
             NEW.quantity - NEW.damaged_qty,
             COALESCE(@app_reference_type, 'STOCK_UPDATE'),
             @app_reference_id, @app_user_id, CURRENT_TIMESTAMP);
    ELSEIF NEW.damaged_qty < OLD.damaged_qty THEN
        INSERT INTO `inventory_ledger`
            (`stock_id`, `product_id`, `txn_type`, `quantity`, `balance_after`,
             `reference_type`, `reference_id`, `changed_by`, `txn_time`)
        VALUES
            (NEW.stock_id, NEW.product_id, 'ADJUST',
             OLD.damaged_qty - NEW.damaged_qty,
             NEW.quantity - NEW.damaged_qty,
             COALESCE(@app_reference_type, 'DAMAGE_REVERSAL'),
             @app_reference_id, @app_user_id, CURRENT_TIMESTAMP);
    END IF;
END$$
DELIMITER ;

-- -----------------------------------------------------------------------------
-- 4. PREVENT PARENT DELETES FROM CASCADING AWAY REQUIRED HISTORY
--    MySQL foreign-key cascades do not fire child-table DELETE triggers. Change
--    these historical FKs from CASCADE to RESTRICT so the immutable child rows
--    actually protect their parent records too.
-- -----------------------------------------------------------------------------
ALTER TABLE `inventory_ledger`
    DROP FOREIGN KEY `fk_ledger_stock`,
    DROP FOREIGN KEY `fk_ledger_product`,
    ADD CONSTRAINT `fk_ledger_stock` FOREIGN KEY (`stock_id`)
        REFERENCES `stock`(`stock_id`) ON DELETE RESTRICT ON UPDATE CASCADE,
    ADD CONSTRAINT `fk_ledger_product` FOREIGN KEY (`product_id`)
        REFERENCES `products`(`product_id`) ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE `container_movements`
    DROP FOREIGN KEY `fk_movement_shipment`,
    DROP FOREIGN KEY `fk_movement_container`,
    ADD CONSTRAINT `fk_movement_shipment` FOREIGN KEY (`shipment_id`)
        REFERENCES `shipment`(`shipment_id`) ON DELETE RESTRICT ON UPDATE CASCADE,
    ADD CONSTRAINT `fk_movement_container` FOREIGN KEY (`container_id`)
        REFERENCES `containers`(`container_id`) ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE `claim_status_history`
    DROP FOREIGN KEY `fk_claim_history_claim`,
    ADD CONSTRAINT `fk_claim_history_claim` FOREIGN KEY (`claim_id`)
        REFERENCES `claims`(`claim_id`) ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE `pricing_audit`
    DROP FOREIGN KEY `fk_pricing_audit_rule`,
    ADD CONSTRAINT `fk_pricing_audit_rule` FOREIGN KEY (`rule_id`)
        REFERENCES `pricing_rules`(`rule_id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- -----------------------------------------------------------------------------
-- 5. APPEND-ONLY / IMMUTABLE EVENT RECORDS
--    Payment corrections must be handled through a separately recorded reversal
--    or adjustment workflow, not by editing/deleting the original payment row.
-- -----------------------------------------------------------------------------

DROP TRIGGER IF EXISTS `trg_payments_before_update_immutable`;
DROP TRIGGER IF EXISTS `trg_payments_before_delete_immutable`;
DELIMITER $$
CREATE TRIGGER `trg_payments_before_update_immutable`
BEFORE UPDATE ON `payments`
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Payment records are append-only; record a reversal/adjustment instead';
END$$
CREATE TRIGGER `trg_payments_before_delete_immutable`
BEFORE DELETE ON `payments`
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Payment records cannot be deleted';
END$$
DELIMITER ;

DROP TRIGGER IF EXISTS `trg_inventory_ledger_before_update_immutable`;
DROP TRIGGER IF EXISTS `trg_inventory_ledger_before_delete_immutable`;
DELIMITER $$
CREATE TRIGGER `trg_inventory_ledger_before_update_immutable`
BEFORE UPDATE ON `inventory_ledger`
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Inventory ledger is immutable; post a correcting transaction instead';
END$$
CREATE TRIGGER `trg_inventory_ledger_before_delete_immutable`
BEFORE DELETE ON `inventory_ledger`
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Inventory ledger entries cannot be deleted';
END$$
DELIMITER ;

DROP TRIGGER IF EXISTS `trg_container_movements_before_update_immutable`;
DROP TRIGGER IF EXISTS `trg_container_movements_before_delete_immutable`;
DELIMITER $$
CREATE TRIGGER `trg_container_movements_before_update_immutable`
BEFORE UPDATE ON `container_movements`
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Container movement events are immutable; insert a new movement event';
END$$
CREATE TRIGGER `trg_container_movements_before_delete_immutable`
BEFORE DELETE ON `container_movements`
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Container movement events cannot be deleted';
END$$
DELIMITER ;

DROP TRIGGER IF EXISTS `trg_claim_history_before_update_immutable`;
DROP TRIGGER IF EXISTS `trg_claim_history_before_delete_immutable`;
DELIMITER $$
CREATE TRIGGER `trg_claim_history_before_update_immutable`
BEFORE UPDATE ON `claim_status_history`
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Claim status history is immutable';
END$$
CREATE TRIGGER `trg_claim_history_before_delete_immutable`
BEFORE DELETE ON `claim_status_history`
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Claim status history cannot be deleted';
END$$
DELIMITER ;

DROP TRIGGER IF EXISTS `trg_pricing_audit_before_update_immutable`;
DROP TRIGGER IF EXISTS `trg_pricing_audit_before_delete_immutable`;
DELIMITER $$
CREATE TRIGGER `trg_pricing_audit_before_update_immutable`
BEFORE UPDATE ON `pricing_audit`
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Pricing audit records are immutable';
END$$
CREATE TRIGGER `trg_pricing_audit_before_delete_immutable`
BEFORE DELETE ON `pricing_audit`
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Pricing audit records cannot be deleted';
END$$
DELIMITER ;

DROP TRIGGER IF EXISTS `trg_audit_log_before_update_immutable`;
DROP TRIGGER IF EXISTS `trg_audit_log_before_delete_immutable`;
DELIMITER $$
CREATE TRIGGER `trg_audit_log_before_update_immutable`
BEFORE UPDATE ON `audit_log`
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Audit log records are immutable';
END$$
CREATE TRIGGER `trg_audit_log_before_delete_immutable`
BEFORE DELETE ON `audit_log`
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Audit log records cannot be deleted';
END$$
DELIMITER ;

-- -----------------------------------------------------------------------------
-- 6. VERIFICATION
-- -----------------------------------------------------------------------------
SELECT trigger_name, event_object_table, event_manipulation, action_timing
FROM information_schema.triggers
WHERE trigger_schema = DATABASE()
  AND trigger_name IN (
      'trg_after_pricing_rule_update',
      'trg_after_claim_status_change',
      'trg_after_stock_update_ledger',
      'trg_payments_before_update_immutable',
      'trg_payments_before_delete_immutable',
      'trg_inventory_ledger_before_update_immutable',
      'trg_inventory_ledger_before_delete_immutable',
      'trg_container_movements_before_update_immutable',
      'trg_container_movements_before_delete_immutable',
      'trg_claim_history_before_update_immutable',
      'trg_claim_history_before_delete_immutable',
      'trg_pricing_audit_before_update_immutable',
      'trg_pricing_audit_before_delete_immutable',
      'trg_audit_log_before_update_immutable',
      'trg_audit_log_before_delete_immutable'
  )
ORDER BY event_object_table, trigger_name;

-- Application-owned audit actions are NOT generated by this patch.
-- The Java service/DAO must INSERT into audit_log for user lifecycle, login/
-- failed login, port and vessel administrative actions, providing @app_user_id
-- as the user_id and old/new JSON values where applicable.
-- For tracking, INSERT container_movements with updated_by; the existing master
-- trg_after_container_movement_insert synchronizes shipment/container status.
-- For all manual database writes, set @app_user_id on that same connection.

-- End of audit logging correction patch.

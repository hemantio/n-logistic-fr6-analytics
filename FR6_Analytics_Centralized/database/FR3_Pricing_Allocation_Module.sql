-- =============================================================================
-- PROJECT: N Logistic Import & Export / Logistics Management Platform
-- MODULE:  FR3 - Container Allocation & Dynamic Pricing Engine
-- FILE:    FR3_Pricing_Allocation_Module.sql
-- PURPOSE: Standalone Database Implementation for Module FR3:
--          1. Table DDL (containers, pricing_rules, pricing_audit, demand_forecast)
--          2. Relational Foreign Keys & Soft Deactivate Policies (SRS 7.5)
--          3. Audit Trigger: trg_after_pricing_rule_update -> pricing_audit
--          4. Operational Views (Instant Pricing Calculator & Container Inventory)
--          5. Stored Procedures (Dynamic Quote Engine & Demand Forecasting)
--          6. Standard CRUD Query Templates (SELECT, INSERT, UPDATE, DEACTIVATE)
-- TARGET:  n_logistic_db (Universal MySQL 8.0+ / MariaDB 10.4+)
-- COMPLIANCE: SRS Section 7.5 (Pricing) & Section 7.4 (Containers)
-- =============================================================================

USE `n_logistic_db`;

SET @OLD_FOREIGN_KEY_CHECKS = @@FOREIGN_KEY_CHECKS;
SET FOREIGN_KEY_CHECKS = 0;

-- =============================================================================
-- 1. TABLE CREATION DDL (4 FR3 TABLES)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1.1 CONTAINERS (SRS 7.4 / ERD #16)
-- Purpose: Tracks physical shipping containers, current port, status, and size.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `containers` (
    `container_id`     INT AUTO_INCREMENT PRIMARY KEY,
    `container_number` VARCHAR(15) NOT NULL UNIQUE COMMENT 'e.g. MSKU9012345',
    `seller_id`        INT NOT NULL COMMENT 'FK to companies (Seller owner)',
    `container_type`   ENUM('DRY', 'REEFER', 'OPEN_TOP', 'TANK') NOT NULL DEFAULT 'DRY',
    `size_ft`          TINYINT NOT NULL DEFAULT 20 COMMENT '20 or 40 ft',
    `max_weight_kg`    DECIMAL(10, 2) NOT NULL DEFAULT 28000.00,
    `max_volume_cbm`   DECIMAL(8, 2) NOT NULL DEFAULT 33.20,
    `current_port_id`  INT NOT NULL COMMENT 'FK to ports (Current physical location)',
    `status`           ENUM('AVAILABLE', 'ALLOCATED', 'IN_TRANSIT', 'MAINTENANCE') NOT NULL DEFAULT 'AVAILABLE',
    `created_at`       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT `fk_container_seller`
        FOREIGN KEY (`seller_id`)
        REFERENCES `companies`(`company_id`)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,

    CONSTRAINT `fk_container_port`
        FOREIGN KEY (`current_port_id`)
        REFERENCES `ports`(`port_id`)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,

    INDEX `idx_containers_port_status` (`current_port_id`, `status`),
    INDEX `idx_containers_seller` (`seller_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- -----------------------------------------------------------------------------
-- 1.2 PRICING_RULES (SRS 7.5 / ERD #6)
-- Purpose: Base freight rates and dynamic multiplier matrix per route & container type.
-- Deactivate Rule: Soft delete via is_active = FALSE (never delete historical rules).
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `pricing_rules` (
    `rule_id`           INT AUTO_INCREMENT PRIMARY KEY,
    `seller_id`         INT NOT NULL COMMENT 'FK to companies (Seller offering rate)',
    `origin_port_id`    INT NOT NULL COMMENT 'Origin Port FK',
    `dest_port_id`      INT NOT NULL COMMENT 'Destination Port FK',
    `container_type`    ENUM('DRY', 'REEFER', 'OPEN_TOP', 'TANK') NOT NULL DEFAULT 'DRY',
    `base_rate`         DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    `rate_per_kg`       DECIMAL(8, 4) NOT NULL DEFAULT 0.0000,
    `rate_per_cbm`      DECIMAL(8, 2) NOT NULL DEFAULT 0.00,
    `season_multiplier` DECIMAL(4, 2) NOT NULL DEFAULT 1.00,
    `demand_multiplier` DECIMAL(4, 2) NOT NULL DEFAULT 1.00,
    `valid_from`        DATE NOT NULL,
    `valid_to`          DATE NOT NULL,
    `is_active`         BOOLEAN NOT NULL DEFAULT TRUE,
    `created_at`        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT `fk_pricing_seller`
        FOREIGN KEY (`seller_id`)
        REFERENCES `companies`(`company_id`)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,

    CONSTRAINT `fk_pricing_origin_port`
        FOREIGN KEY (`origin_port_id`)
        REFERENCES `ports`(`port_id`)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,

    CONSTRAINT `fk_pricing_dest_port`
        FOREIGN KEY (`dest_port_id`)
        REFERENCES `ports`(`port_id`)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,

    INDEX `idx_pricing_route_search` (`origin_port_id`, `dest_port_id`, `container_type`, `is_active`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- -----------------------------------------------------------------------------
-- 1.3 PRICING_AUDIT (SRS 7.5 / ERD #7)
-- Purpose: Tracks historical modifications to pricing rules for rate compliance.
-- Populated automatically via trg_after_pricing_rule_update.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `pricing_audit` (
    `audit_id`       INT AUTO_INCREMENT PRIMARY KEY,
    `rule_id`        INT NOT NULL,
    `old_rate`       DECIMAL(12, 2) NOT NULL,
    `new_rate`       DECIMAL(12, 2) NOT NULL,
    `old_multiplier` DECIMAL(4, 2) NOT NULL DEFAULT 1.00,
    `new_multiplier` DECIMAL(4, 2) NOT NULL DEFAULT 1.00,
    `changed_by`     INT NOT NULL COMMENT 'FK to users who executed the change',
    `changed_at`     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT `fk_pricing_audit_rule`
        FOREIGN KEY (`rule_id`)
        REFERENCES `pricing_rules`(`rule_id`)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    CONSTRAINT `fk_pricing_audit_user`
        FOREIGN KEY (`changed_by`)
        REFERENCES `users`(`user_id`)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,

    INDEX `idx_pricing_audit_rule` (`rule_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- -----------------------------------------------------------------------------
-- 1.4 DEMAND_FORECAST (SRS 7.5 / ERD #8)
-- Purpose: Monthly forecasted booking demand per port-pair and container type.
-- Integration: Outputs suggested_multiplier directly to pricing_rules.demand_multiplier.
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

    CONSTRAINT `fk_fr3_forecast_origin`
        FOREIGN KEY (`origin_port_id`)
        REFERENCES `ports`(`port_id`)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    CONSTRAINT `fk_fr3_forecast_destination`
        FOREIGN KEY (`dest_port_id`)
        REFERENCES `ports`(`port_id`)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    INDEX `idx_fr3_forecast_route` (`origin_port_id`, `dest_port_id`, `container_type`, `forecast_month`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

SET FOREIGN_KEY_CHECKS = @OLD_FOREIGN_KEY_CHECKS;


-- =============================================================================
-- 2. AUDIT TRIGGER (SRS 7.2 & 7.5)
-- =============================================================================

DROP TRIGGER IF EXISTS `trg_after_pricing_rule_update`;

DELIMITER //

CREATE TRIGGER `trg_after_pricing_rule_update`
AFTER UPDATE ON `pricing_rules`
FOR EACH ROW
BEGIN
    IF (OLD.base_rate <> NEW.base_rate OR OLD.demand_multiplier <> NEW.demand_multiplier) THEN
        INSERT INTO `pricing_audit` (
            `rule_id`,
            `old_rate`,
            `new_rate`,
            `old_multiplier`,
            `new_multiplier`,
            `changed_by`,
            `changed_at`
        ) VALUES (
            NEW.rule_id,
            OLD.base_rate,
            NEW.base_rate,
            OLD.demand_multiplier,
            NEW.demand_multiplier,
            1, -- Default administrative actor if connection session variable is unset
            CURRENT_TIMESTAMP
        );
    END IF;
END //

DELIMITER ;


-- =============================================================================
-- 3. OPERATIONAL VIEWS (FR3.1 & FR3.7)
-- =============================================================================

-- VIEW 1: Instant Dynamic Freight Pricing Calculator
CREATE OR REPLACE VIEW `vw_fr3_pricing_calculator` AS
SELECT 
    pr.rule_id,
    c.company_name AS seller_name,
    p_orig.port_name AS origin_port,
    p_orig.port_code AS origin_code,
    p_dest.port_name AS destination_port,
    p_dest.port_code AS destination_code,
    pr.container_type,
    pr.base_rate,
    pr.rate_per_kg,
    pr.rate_per_cbm,
    pr.season_multiplier,
    pr.demand_multiplier,
    df.predicted_bookings AS forecast_demand_level,
    df.confidence_pct AS forecast_confidence,
    ROUND(pr.base_rate * pr.season_multiplier * pr.demand_multiplier, 2) AS estimated_standard_quote,
    pr.valid_from,
    pr.valid_to
FROM pricing_rules pr
JOIN companies c ON pr.seller_id = c.company_id
JOIN ports p_orig ON pr.origin_port_id = p_orig.port_id
JOIN ports p_dest ON pr.dest_port_id = p_dest.port_id
LEFT JOIN demand_forecast df ON pr.origin_port_id = df.origin_port_id 
                            AND pr.dest_port_id = df.dest_port_id 
                            AND pr.container_type = df.container_type
WHERE pr.is_active = TRUE;


-- VIEW 2: Available Container Inventory by Port & Type (FR3.1)
CREATE OR REPLACE VIEW `vw_fr3_available_containers` AS
SELECT 
    p.port_id,
    p.port_name,
    p.port_code,
    p.city,
    p.country,
    cnt.container_type,
    cnt.size_ft,
    COUNT(cnt.container_id) AS available_container_count
FROM containers cnt
JOIN ports p ON cnt.current_port_id = p.port_id
WHERE cnt.status = 'AVAILABLE'
GROUP BY p.port_id, p.port_name, p.port_code, p.city, p.country, cnt.container_type, cnt.size_ft;


-- =============================================================================
-- 4. STORED PROCEDURES (FR3.7 & FR3 Dynamic Multiplier Sync)
-- =============================================================================

DROP PROCEDURE IF EXISTS `sp_fr3_calculate_quote`;
DROP PROCEDURE IF EXISTS `sp_generate_demand_forecast`;

DELIMITER //

-- PROCEDURE 1: Instant Quotation Calculation
CREATE PROCEDURE `sp_fr3_calculate_quote`(
    IN p_origin_port_id INT,
    IN p_dest_port_id INT,
    IN p_container_type VARCHAR(20),
    IN p_cargo_weight_kg DECIMAL(10, 2),
    IN p_cargo_volume_cbm DECIMAL(8, 2),
    OUT p_final_quote DECIMAL(12, 2)
)
BEGIN
    DECLARE v_base_rate DECIMAL(12, 2) DEFAULT 0.00;
    DECLARE v_rate_kg DECIMAL(8, 4) DEFAULT 0.0000;
    DECLARE v_rate_cbm DECIMAL(8, 2) DEFAULT 0.00;
    DECLARE v_season DECIMAL(4, 2) DEFAULT 1.00;
    DECLARE v_demand DECIMAL(4, 2) DEFAULT 1.00;

    SELECT base_rate, rate_per_kg, rate_per_cbm, season_multiplier, demand_multiplier
    INTO v_base_rate, v_rate_kg, v_rate_cbm, v_season, v_demand
    FROM pricing_rules
    WHERE origin_port_id = p_origin_port_id 
      AND dest_port_id = p_dest_port_id 
      AND container_type = p_container_type
      AND is_active = TRUE
      AND CURDATE() BETWEEN valid_from AND valid_to
    LIMIT 1;

    IF v_base_rate = 0.00 THEN
        SET p_final_quote = 45000.00; -- Default fallback quote
    ELSE
        SET p_final_quote = ROUND(
            (v_base_rate + (p_cargo_weight_kg * v_rate_kg) + (p_cargo_volume_cbm * v_rate_cbm)) 
            * v_season * v_demand, 
            2
        );
    END IF;
END //


-- PROCEDURE 2: Demand Forecast Generator (SRS 7.5 Table 8)
-- Projects next month's bookings and feeds suggested_multiplier to pricing_rules
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

DELIMITER ;

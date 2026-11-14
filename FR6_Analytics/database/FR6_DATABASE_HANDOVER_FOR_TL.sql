-- =============================================================================
-- PROJECT: N Logistic Management Platform
-- MODULE:  FR6 - Analytics Dashboard & P&L (SRS Section 7.9)
-- FILE:    FR6_DATABASE_HANDOVER_FOR_TL.sql
-- PURPOSE: Master Integration SQL: Table DDL, Foreign Keys & Stored Procedures
-- TARGET:  n_logistic_db (Universal MySQL 8.0+ / MariaDB 10.4+)
-- COMPLIANCE: Strict SRS Section 7.9 (5 Analytics & P&L Result Tables)
-- NOTE:    demand_forecast (ERD #8) is owned by Module FR3 (Pricing - Section 7.5)
--          and is excluded here to maintain strict Section 7.9 ownership.
-- =============================================================================

USE `n_logistic_db`;

-- Temporarily disable FK checks to ensure safe idempotent execution
SET @OLD_FOREIGN_KEY_CHECKS = @@FOREIGN_KEY_CHECKS;
SET FOREIGN_KEY_CHECKS = 0;

-- =============================================================================
-- SECTION 1: INITIAL TABLE CREATION (5 ANALYTICS & P&L TABLES WITH FOREIGN KEYS)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. SALES TREND RESULT (ERD #10 / SRS Section 7.9)
-- Purpose: Caches aggregated historical route and port-pair sales trends (FR6.2).
-- Foreign Keys: origin_port_id -> ports(port_id), dest_port_id -> ports(port_id)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `sales_trend_result` (
    `result_id`       INT AUTO_INCREMENT PRIMARY KEY,
    `period_month`    DATE NOT NULL COMMENT 'First day of month (YYYY-MM-01)',
    `origin_port_id`  INT NULL,
    `dest_port_id`    INT NULL,
    `total_sales`     DECIMAL(14, 2) NOT NULL DEFAULT 0.00 COMMENT 'Total realized route revenue',
    `total_qty`       INT NOT NULL DEFAULT 0 COMMENT 'Total container volume or unit quantity',
    `growth_pct`      DECIMAL(6, 2) NOT NULL DEFAULT 0.00 COMMENT 'Month-over-month growth rate %',
    `created_at`      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT `fk_fr6_sales_origin`
        FOREIGN KEY (`origin_port_id`)
        REFERENCES `ports`(`port_id`)
        ON DELETE SET NULL
        ON UPDATE CASCADE,

    CONSTRAINT `fk_fr6_sales_destination`
        FOREIGN KEY (`dest_port_id`)
        REFERENCES `ports`(`port_id`)
        ON DELETE SET NULL
        ON UPDATE CASCADE,

    INDEX `idx_fr6_sales_trend_lookup` (`period_month`, `origin_port_id`, `dest_port_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- -----------------------------------------------------------------------------
-- 2. ABC CLASSIFICATION RESULT (ERD #26 / SRS Section 7.9)
-- Purpose: Caches Pareto inventory analysis per product (FR6.3).
-- Policy:  A = Top 70% revenue, B = Next 20% (up to 90%), C = Last 10%.
-- Foreign Key: product_id -> products(product_id)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `abc_classification_result` (
    `result_id`       INT AUTO_INCREMENT PRIMARY KEY,
    `product_id`      INT NOT NULL,
    `annual_value`    DECIMAL(14, 2) NOT NULL DEFAULT 0.00 COMMENT 'Annualized product sales value',
    `cumulative_pct`  DECIMAL(5, 2) NOT NULL DEFAULT 0.00 COMMENT 'Running cumulative revenue % (0-100)',
    `abc_class`       CHAR(1) NOT NULL COMMENT 'Category: A = top 70%, B = next 20%, C = last 10%',
    `calculated_on`   DATE NOT NULL COMMENT 'Date of Pareto classification run',
    `created_at`      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT `fk_fr6_abc_product`
        FOREIGN KEY (`product_id`)
        REFERENCES `products`(`product_id`)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    INDEX `idx_fr6_abc_class` (`product_id`, `abc_class`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- -----------------------------------------------------------------------------
-- 3. INVENTORY TURNOVER RESULT (ERD #27 / SRS Section 7.9)
-- Purpose: Caches inventory velocity and turnover metrics (FR6.4).
-- Formula: turnover_ratio = COGS / Average Inventory Value.
-- Foreign Key: product_id -> products(product_id)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `inventory_turnover_result` (
    `result_id`       INT AUTO_INCREMENT PRIMARY KEY,
    `product_id`      INT NOT NULL,
    `period_start`    DATE NOT NULL,
    `period_end`      DATE NOT NULL,
    `cogs`            DECIMAL(14, 2) NOT NULL DEFAULT 0.00 COMMENT 'Cost of Goods Sold (inventory ledger OUT)',
    `avg_inventory`   DECIMAL(14, 2) NOT NULL DEFAULT 0.00 COMMENT 'Average stock valuation over period',
    `turnover_ratio`  DECIMAL(8, 2) NOT NULL DEFAULT 0.00 COMMENT 'turnover_ratio = cogs / avg_inventory',
    `created_at`      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT `fk_fr6_turnover_product`
        FOREIGN KEY (`product_id`)
        REFERENCES `products`(`product_id`)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    INDEX `idx_fr6_turnover_ratio` (`product_id`, `turnover_ratio`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- -----------------------------------------------------------------------------
-- 4. PROFITABILITY RESULT (ERD #28 / SRS Section 7.9)
-- Purpose: Caches monthly gross profitability margins per product (FR6.5).
-- Formula: margin_pct = ((revenue - cost) / revenue) * 100.
-- Foreign Key: product_id -> products(product_id)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `profitability_result` (
    `result_id`       INT AUTO_INCREMENT PRIMARY KEY,
    `product_id`      INT NOT NULL,
    `period_month`    DATE NOT NULL,
    `revenue`         DECIMAL(14, 2) NOT NULL DEFAULT 0.00 COMMENT 'Gross revenue realized for product',
    `cost`            DECIMAL(14, 2) NOT NULL DEFAULT 0.00 COMMENT 'COGS + direct handling cost',
    `margin_pct`      DECIMAL(6, 2) NOT NULL DEFAULT 0.00 COMMENT 'Gross profit margin %',
    `created_at`      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT `fk_fr6_profitability_product`
        FOREIGN KEY (`product_id`)
        REFERENCES `products`(`product_id`)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    INDEX `idx_fr6_profitability_lookup` (`product_id`, `period_month`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- -----------------------------------------------------------------------------
-- 5. PROFIT LOSS (ERD #11 / SRS Section 7.9)
-- Purpose: Shipment-level P&L tracking (FR6.5 & FR2.8).
-- Formula: net_profit = revenue - freight_cost - port_cost - handling_cost - claim_loss.
-- Foreign Keys: shipment_id -> shipment(shipment_id), seller_id -> companies(company_id)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `profit_loss` (
    `pl_id`           INT AUTO_INCREMENT PRIMARY KEY,
    `shipment_id`     INT NULL COMMENT 'Nullable if multi-shipment consolidated P&L',
    `seller_id`       INT NOT NULL COMMENT 'Seller company owning the shipment',
    `period_month`    DATE NOT NULL COMMENT 'First day of month (YYYY-MM-01)',
    `revenue`         DECIMAL(14, 2) NOT NULL DEFAULT 0.00 COMMENT 'Invoiced revenue',
    `freight_cost`    DECIMAL(14, 2) NOT NULL DEFAULT 0.00 COMMENT 'Ocean freight operating expense',
    `port_cost`       DECIMAL(14, 2) NOT NULL DEFAULT 0.00 COMMENT 'Port & terminal dues',
    `handling_cost`   DECIMAL(14, 2) NOT NULL DEFAULT 0.00 COMMENT 'Stevedoring & container handling',
    `claim_loss`      DECIMAL(14, 2) NOT NULL DEFAULT 0.00 COMMENT 'Settled cargo damage/loss payouts',
    `net_profit`      DECIMAL(14, 2) NOT NULL DEFAULT 0.00 COMMENT 'Net profit = revenue - all costs - claim_loss',
    `created_at`      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT `fk_fr6_profit_shipment`
        FOREIGN KEY (`shipment_id`)
        REFERENCES `shipment`(`shipment_id`)
        ON DELETE SET NULL
        ON UPDATE CASCADE,

    CONSTRAINT `fk_fr6_profit_seller`
        FOREIGN KEY (`seller_id`)
        REFERENCES `companies`(`company_id`)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    INDEX `idx_fr6_pl_lookup` (`seller_id`, `period_month`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Restore original foreign key check state
SET FOREIGN_KEY_CHECKS = @OLD_FOREIGN_KEY_CHECKS;


-- =============================================================================
-- SECTION 2: SUPPORTING STORED PROCEDURES FOR THE 5 TABLES
-- =============================================================================

DROP PROCEDURE IF EXISTS `sp_refresh_sales_trends`;
DROP PROCEDURE IF EXISTS `sp_calculate_abc_classification`;
DROP PROCEDURE IF EXISTS `sp_calculate_inventory_turnover`;
DROP PROCEDURE IF EXISTS `sp_calculate_profitability`;
DROP PROCEDURE IF EXISTS `sp_calculate_profit_loss`;
DROP PROCEDURE IF EXISTS `sp_refresh_all_fr6_analytics`;

DELIMITER //

-- -----------------------------------------------------------------------------
-- PROCEDURE 1: sp_refresh_sales_trends
-- Target Table: sales_trend_result (Table 1)
-- Purpose: Aggregates historical monthly sales and container volume by route.
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
-- PROCEDURE 2: sp_calculate_abc_classification
-- Target Table: abc_classification_result (Table 2)
-- Purpose: Computes Pareto classification (A = top 70%, B = next 20%, C = last 10%).
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
-- PROCEDURE 3: sp_calculate_inventory_turnover
-- Target Table: inventory_turnover_result (Table 3)
-- Purpose: Computes COGS and turnover ratio (turnover_ratio = cogs / avg_inventory).
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
-- PROCEDURE 4: sp_calculate_profitability
-- Target Table: profitability_result (Table 4)
-- Purpose: Computes monthly gross revenue, cost, and margin % per product.
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
-- PROCEDURE 5: sp_calculate_profit_loss
-- Target Table: profit_loss (Table 5)
-- Purpose: Computes shipment-level net profit and operating expense breakdown (FR2.8).
-- -----------------------------------------------------------------------------
CREATE PROCEDURE `sp_calculate_profit_loss`()
BEGIN
    DELETE FROM profit_loss;

    INSERT INTO profit_loss (shipment_id, seller_id, period_month, revenue, freight_cost, port_cost, handling_cost, claim_loss, net_profit)
    SELECT 
        s.shipment_id,
        s.seller_id,
        DATE_FORMAT(s.created_at, '%Y-%m-01') AS period_month,
        COALESCE(MAX(bi.total_amount), s.quoted_price, 0.00) AS revenue,
        COALESCE(AVG(pr.base_rate), 45000.00) AS freight_cost,
        5000.00 AS port_cost,
        3500.00 AS handling_cost,
        COALESCE((SELECT SUM(CASE WHEN c.approved_amount > 0 THEN c.approved_amount ELSE c.claimed_amount END) FROM claims c WHERE c.shipment_id = s.shipment_id AND c.status IN ('APPROVED', 'SETTLED')), 0.00) AS claim_loss,
        (COALESCE(MAX(bi.total_amount), s.quoted_price, 0.00) 
         - COALESCE(AVG(pr.base_rate), 45000.00) 
         - 5000.00 
         - 3500.00 
         - COALESCE((SELECT SUM(CASE WHEN c.approved_amount > 0 THEN c.approved_amount ELSE c.claimed_amount END) FROM claims c WHERE c.shipment_id = s.shipment_id AND c.status IN ('APPROVED', 'SETTLED')), 0.00)
        ) AS net_profit
    FROM shipment s
    LEFT JOIN billing_invoices bi ON s.shipment_id = bi.shipment_id
    LEFT JOIN pricing_rules pr ON s.origin_port_id = pr.origin_port_id AND s.dest_port_id = pr.dest_port_id
    WHERE s.status != 'CANCELLED'
    GROUP BY s.shipment_id, s.seller_id, DATE_FORMAT(s.created_at, '%Y-%m-01');
END //


-- -----------------------------------------------------------------------------
-- PROCEDURE 6: sp_refresh_all_fr6_analytics (Master Orchestrator)
-- Purpose: Executes all 5 recalculation procedures in a single atomic transaction.
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
    CALL sp_calculate_profit_loss();

    COMMIT;
END //

DELIMITER ;


-- =============================================================================
-- SECTION 3: MULTI-DIMENSIONAL ANALYTICAL VIEWS (FR6.1 - FR6.8)
-- Purpose: Pre-aggregated reporting views for dashboard visualization & viva demo.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- VIEW 1: vw_fr6_executive_kpis (FR6.1)
-- Purpose: Unified real-time dashboard header metrics across all active modules.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW `vw_fr6_executive_kpis` AS
SELECT 
    (SELECT COUNT(*) FROM shipment WHERE status NOT IN ('CANCELLED', 'DELIVERED')) AS active_shipments_count,
    (SELECT COUNT(*) FROM containers WHERE status = 'AVAILABLE') AS available_containers_count,
    (SELECT COALESCE(SUM(paid_amount), 0.00) FROM billing_invoices) AS total_revenue_collected,
    (SELECT COALESCE(SUM(total_amount - paid_amount), 0.00) FROM billing_invoices WHERE status != 'PAID') AS pending_invoices_amount,
    (SELECT COUNT(*) FROM claims WHERE status IN ('SUBMITTED', 'UNDER_REVIEW')) AS open_claims_count;


-- -----------------------------------------------------------------------------
-- VIEW 2: vw_fr6_seller_pl_summary (FR6.5 & FR2.8)
-- Purpose: Consolidated monthly P&L overview per seller company.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW `vw_fr6_seller_pl_summary` AS
SELECT 
    pl.period_month,
    c.company_id AS seller_id,
    c.company_name AS seller_name,
    COUNT(pl.shipment_id) AS total_shipments_billed,
    SUM(pl.revenue) AS total_gross_revenue,
    SUM(pl.freight_cost) AS total_freight_cost,
    SUM(pl.port_cost) AS total_port_cost,
    SUM(pl.handling_cost) AS total_handling_cost,
    SUM(pl.claim_loss) AS total_claim_deductions,
    SUM(pl.net_profit) AS net_operating_profit,
    CASE 
        WHEN SUM(pl.revenue) > 0 THEN 
            ROUND((SUM(pl.net_profit) / SUM(pl.revenue)) * 100, 2)
        ELSE 0.00 
    END AS profit_margin_pct
FROM profit_loss pl
JOIN companies c ON pl.seller_id = c.company_id
GROUP BY pl.period_month, c.company_id, c.company_name
ORDER BY pl.period_month DESC, net_operating_profit DESC;


-- -----------------------------------------------------------------------------
-- VIEW 3: vw_fr6_abc_inventory_analysis (FR6.3)
-- Purpose: Joins Pareto classification with product & seller details.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW `vw_fr6_abc_inventory_analysis` AS
SELECT 
    abc.result_id,
    p.product_id,
    p.sku,
    p.product_name,
    p.category,
    c.company_name AS seller_name,
    abc.annual_value,
    abc.cumulative_pct,
    abc.abc_class,
    CASE 
        WHEN abc.abc_class = 'A' THEN 'High Value (Top 70% Revenue - Strict Control)'
        WHEN abc.abc_class = 'B' THEN 'Moderate Value (Next 20% Revenue - Moderate Control)'
        ELSE 'Low Value (Final 10% Revenue - Bulk/Simple Control)'
    END AS control_category,
    abc.calculated_on
FROM abc_classification_result abc
JOIN products p ON abc.product_id = p.product_id
JOIN companies c ON p.owner_company_id = c.company_id
ORDER BY abc.annual_value DESC;


-- -----------------------------------------------------------------------------
-- VIEW 4: vw_fr6_route_performance (FR6.2)
-- Purpose: Joins historical route sales trends with human-readable port names.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW `vw_fr6_route_performance` AS
SELECT 
    st.result_id,
    st.period_month,
    COALESCE(p_orig.port_name, 'Consolidated') AS origin_port,
    COALESCE(p_orig.port_code, 'N/A') AS origin_code,
    COALESCE(p_dest.port_name, 'Consolidated') AS destination_port,
    COALESCE(p_dest.port_code, 'N/A') AS destination_code,
    st.total_sales,
    st.total_qty AS container_volume_units,
    st.growth_pct,
    CASE 
        WHEN st.growth_pct > 0 THEN 'EXPANDING'
        WHEN st.growth_pct < 0 THEN 'DECLINING'
        ELSE 'STABLE'
    END AS trend_direction
FROM sales_trend_result st
LEFT JOIN ports p_orig ON st.origin_port_id = p_orig.port_id
LEFT JOIN ports p_dest ON st.dest_port_id = p_dest.port_id
ORDER BY st.period_month DESC, st.total_sales DESC;


-- =============================================================================

-- =============================================================================
-- SECTION 4: SRS ROLE-BASED ACCESS & MODULE-SPECIFIC LIFECYCLE STANDARDS
-- =============================================================================
/*
===============================================================================
1. ROLE-BASED TASK & ACCESS CONTROL MATRIX (SRS Section 2.3 & FR6)
-------------------------------------------------------------------------------
ROLE        ALLOWED ANALYTICAL OPERATIONS & TASKS                RESTRICTIONS
----------  ---------------------------------------------------  --------------
ADMIN       - View system-wide Executive KPIs (vw_fr6_executive_kpis) Cannot alter
            - View cross-company route performance & trade lanes historical sales
            - Run system-wide analytics refresh (sp_refresh_all) without audit log
            - Purge aged analytics cache (> 24 months retention)
            - Manage ports (is_active) and vessels (status='MAINTENANCE')

SELLER      - View own company monthly & shipment P&L (FR2.7)     CANNOT view other
(Exporter)  - Export own company P&L records to CSV (FR2.9)      competing sellers'
            - View ABC Pareto inventory classification for own    P&L or profit
              catalog products (FR6.3)                            margins.
            - View product-level profit margins & COGS (FR6.5)
            - Run on-demand P&L recalculation for own company

CONSUMER    - View own shipment tracking timeline & delay flags  STRICTLY RESTRICTED
            - View billing invoices & record payments (FR5.3)    from all seller P&L,
            - File loss/damage claims within 30 days (FR7.1)     operating margins,
                                                                 and cost breakdowns.

-------------------------------------------------------------------------------
2. CROSS-MODULE LIFECYCLE & 'DELETE VS. DEACTIVATE' MAPPING INTO FR6
-------------------------------------------------------------------------------
ENTITY/MODULE  SRS ACTION               LIFECYCLE & DEACTIVATE POLICY      EFFECT ON FR6 ANALYTICS
-------------  -----------------------  ---------------------------------  -----------------------------------
Users (FR1)    Admin manages users      Soft Deactivate:                   Deactivated users disappear from active
               (FR1.4)                  UPDATE users SET status='INACTIVE' counts but their historical bookings,
                                        ❌ No hard delete allowed           payments, and audit logs remain intact.

Ports (FR1)    Admin manages ports      Soft Deactivate:                   Deactivated ports cannot receive new
               (FR1.6)                  UPDATE ports SET is_active=FALSE   bookings; historical route sales trends
                                        ❌ No hard delete allowed           (sales_trend_result) are preserved.

Vessels (FR1)  Admin manages ships      Status Maintenance:               Vessels undergoing maintenance cannot be
               (FR1.7)                  UPDATE vessels SET status='MAINT'  assigned to new voyages; historical
                                        ❌ No hard delete allowed           freight cost records are preserved.

Shipment (FR2) Seller updates sequence  Soft Cancel before departure:      CANCELLED shipments are strictly excluded
               (FR2.2)                  UPDATE shipment SET                from revenue & P&L calculations
                                        status='CANCELLED'                 (s.status != 'CANCELLED'). DELIVERED
                                        ❌ No hard delete allowed           shipments release containers & close KPIs.

Pricing (FR3)  Seller updates rates     Soft Deactivate:                   Deactivated rules cannot generate new
               (FR3.6)                  UPDATE pricing_rules SET           quotes; pricing_audit preserves historical
                                        is_active=FALSE                    rates for past P&L freight cost audits.

Stock (FR4)    Seller manages goods     Soft Delete & Ledger Adjustment:   Zeroed stock with 'ADJUST' ledger entries
               (FR4.1, FR4.5, FR4.6)    UPDATE products SET is_active=FALSE feeds inventory turnover (COGS/avg stock).
                                        CHECK(quantity >= 0) non-negative  Negative stock is blocked by DB constraints.

Billing (FR5)  Consumer records payment Strict Financial Lock:             Payment inserts automatically update paid
               (FR5.3, FR5.4)           ❌ Never delete invoices/payments  amount; instantly reflected in collected
                                        Adjust via credit notes/claims     revenue KPI and recognized P&L revenue.

Claims (FR7)   Seller reviews & settles Status Settlement:                 SETTLED claims automatically post approved
               (FR7.4, FR7.6)           status='APPROVED' / 'SETTLED'      amounts to profit_loss.claim_loss and
                                        ❌ No hard delete allowed           directly reduce net_profit (FR2.8/FR7.6).

Analytics      System/Admin refresh     Materialized Cache Invalidation:   Analytical result tables do NOT use soft
Results (FR6)  (FR6.7)                  Truncate/Refresh via procedures    delete; they are atomically refreshed or
                                        Purge via retention window         purged after the retention threshold.
===============================================================================
*/


-- =============================================================================
-- SECTION 5: PARAMETERIZED CRUD & DAO QUERIES FOR MODULE FR6 (JAVA PREPAREDSTATEMENT)
-- =============================================================================
/*
The following SQL queries map directly to the Java DAO layer (AnalyticsDAO.java,
ProfitLossDAO.java) for implementation in the MVC2 architecture.

-- -----------------------------------------------------------------------------
-- [C - CREATE / CALCULATE]
-- Generate/Materialize analytical snapshots across all 5 tables from live OLTP data:
-- -----------------------------------------------------------------------------
-- 1. Master Atomic Recalculation (Executes all 5 analytical algorithms in 1 transaction)
CALL sp_refresh_all_fr6_analytics();

-- 2. Modular Procedure Recalculation
CALL sp_refresh_sales_trends();
CALL sp_calculate_abc_classification();
CALL sp_calculate_inventory_turnover('2026-01-01', '2026-12-31');
CALL sp_calculate_profitability();
CALL sp_calculate_profit_loss();

-- 3. Direct Target / Budget Baseline Insertion
-- INSERT INTO profit_loss (shipment_id, seller_id, period_month, revenue, freight_cost, port_cost, handling_cost, claim_loss, net_profit)
-- VALUES (NULL, ?, ?, ?, ?, ?, ?, 0.00, ?);


-- -----------------------------------------------------------------------------
-- [R - READ / VIEW]
-- Role-scoped multi-dimensional queries (Admin vs Seller):
-- -----------------------------------------------------------------------------
-- 1. ADMIN: View System-wide Executive KPI Dashboard (FR6.1)
-- SELECT active_shipments_count, available_containers_count, total_revenue_collected,
--        pending_invoices_amount, open_claims_count
-- FROM vw_fr6_executive_kpis;

-- 2. SELLER: View Own Monthly P&L Breakdown with Date Range Filter (FR2.7, FR2.9, FR6.5)
-- SELECT period_month, seller_id, seller_name, total_shipments_billed, total_gross_revenue,
--        total_freight_cost, total_port_cost, total_handling_cost, total_claim_deductions,
--        net_operating_profit, profit_margin_pct
-- FROM vw_fr6_seller_pl_summary
-- WHERE seller_id = ? AND period_month BETWEEN ? AND ?
-- ORDER BY period_month DESC;

-- 3. SELLER: View Own Product Pareto ABC Classification (FR6.3)
-- SELECT p.sku, p.product_name, p.category, abc.annual_value, abc.cumulative_pct,
--        abc.abc_class, abc.calculated_on
-- FROM abc_classification_result abc
-- JOIN products p ON abc.product_id = p.product_id
-- WHERE p.owner_company_id = ? AND abc.abc_class = ?
-- ORDER BY abc.annual_value DESC;

-- 4. SELLER / ADMIN: View Trade Route Performance & Growth Trends (FR6.2)
-- SELECT period_month, origin_port, origin_code, destination_port, destination_code,
--        total_sales, container_volume_units, growth_pct, trend_direction
-- FROM vw_fr6_route_performance
-- WHERE trend_direction = 'EXPANDING'
-- ORDER BY total_sales DESC;

-- 5. SELLER: View Underperforming Loss-Making Shipments (Investigation Screen)
-- SELECT pl.pl_id, s.shipment_no, pl.period_month, pl.revenue, pl.freight_cost,
--        pl.port_cost, pl.handling_cost, pl.claim_loss, pl.net_profit
-- FROM profit_loss pl
-- JOIN shipment s ON pl.shipment_id = s.shipment_id
-- WHERE pl.seller_id = ? AND pl.net_profit < 0
-- ORDER BY pl.net_profit ASC;


-- -----------------------------------------------------------------------------
-- [U - UPDATE / RECALCULATE]
-- Dynamic parameterized adjustments and snapshot refreshing:
-- -----------------------------------------------------------------------------
-- 1. Parameterized Inventory Turnover Recalculation (Custom Quarter / Fiscal Window)
-- CALL sp_calculate_inventory_turnover(?, ?);

-- 2. Complete Atomic Refresh (Pulls latest payments, shipments, and claims into P&L)
-- CALL sp_refresh_all_fr6_analytics();

-- 3. Manual P&L Expense Adjustment (Surcharge or Tariff Override by Authorized Seller)
-- UPDATE profit_loss
-- SET port_cost = port_cost + ?,
--     net_profit = revenue - freight_cost - (port_cost + ?) - handling_cost - claim_loss
-- WHERE pl_id = ? AND seller_id = ?;


-- -----------------------------------------------------------------------------
-- [D - DELETE / PURGE / CACHE INVALIDATION]
-- Analytics Result Cache Management:
-- -----------------------------------------------------------------------------
-- 1. Purge Aged Analytical Records Older Than Retention Policy (Default 24 Months)
-- CALL sp_purge_historical_analytics_cache(?);

-- 2. Complete Cache Flush prior to full data re-ingestion:
-- DELETE FROM profit_loss;
-- DELETE FROM abc_classification_result;
-- DELETE FROM inventory_turnover_result;
-- DELETE FROM profitability_result;
-- DELETE FROM sales_trend_result;
*/

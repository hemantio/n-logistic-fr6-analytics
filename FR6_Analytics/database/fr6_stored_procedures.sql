-- =============================================================================
-- PROJECT: N Logistic Management Platform
-- MODULE:  FR6 - Analytics Dashboard
-- FILE:    fr6_stored_procedures.sql
-- PURPOSE: Stored Procedures for Analytical Calculations & Table Maintenance
-- TARGET:  n_logistic_db (Universal MySQL 8.0+ / MariaDB 10.4+)
-- =============================================================================

USE `n_logistic_db`;

DROP PROCEDURE IF EXISTS `sp_refresh_sales_trends`;
DROP PROCEDURE IF EXISTS `sp_calculate_abc_classification`;
DROP PROCEDURE IF EXISTS `sp_calculate_inventory_turnover`;
DROP PROCEDURE IF EXISTS `sp_calculate_profitability`;
DROP PROCEDURE IF EXISTS `sp_calculate_profit_loss`;
DROP PROCEDURE IF EXISTS `sp_refresh_all_fr6_analytics`;

DELIMITER //

-- =============================================================================
-- PROCEDURE 1: sp_refresh_sales_trends
-- Table: sales_trend_result (ERD #10)
-- Purpose: Aggregates historical monthly sales and container volume by route.
-- =============================================================================
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


-- =============================================================================
-- PROCEDURE 2: sp_calculate_abc_classification
-- Table: abc_classification_result (ERD #26)
-- Purpose: Calculates Pareto distribution (A = top 70%, B = next 20%, C = last 10%).
-- =============================================================================
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


-- =============================================================================
-- PROCEDURE 3: sp_calculate_inventory_turnover
-- Table: inventory_turnover_result (ERD #27)
-- Purpose: Computes COGS and turnover ratio (turnover_ratio = cogs / avg_inventory).
-- =============================================================================
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


-- =============================================================================
-- PROCEDURE 4: sp_calculate_profitability
-- Table: profitability_result (ERD #28)
-- Purpose: Computes monthly gross revenue, cost, and margin % per product.
-- =============================================================================
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


-- =============================================================================
-- PROCEDURE 5: sp_calculate_profit_loss
-- Table: profit_loss (SRS Section 7.9 / ERD #11)
-- Purpose: Computes shipment-level net profit and operating expense breakdown (FR2.8).
-- =============================================================================
CREATE PROCEDURE `sp_calculate_profit_loss`()
BEGIN
    DELETE FROM profit_loss;

    INSERT INTO profit_loss (shipment_id, seller_id, period_month, revenue, freight_cost, port_cost, handling_cost, claim_loss, net_profit)
    SELECT 
        s.shipment_id,
        s.seller_id,
        DATE_FORMAT(s.created_at, '%Y-%m-01') AS period_month,
        COALESCE(bi.total_amount, s.quoted_price) AS revenue,
        COALESCE(pr.base_rate, 45000.00) AS freight_cost,
        5000.00 AS port_cost,
        3500.00 AS handling_cost,
        COALESCE((SELECT SUM(c.claimed_amount) FROM claims c WHERE c.shipment_id = s.shipment_id AND c.status = 'APPROVED'), 0.00) AS claim_loss,
        (COALESCE(bi.total_amount, s.quoted_price) - COALESCE(pr.base_rate, 45000.00) - 5000.00 - 3500.00 
         - COALESCE((SELECT SUM(c.claimed_amount) FROM claims c WHERE c.shipment_id = s.shipment_id AND c.status = 'APPROVED'), 0.00)
        ) AS net_profit
    FROM shipment s
    LEFT JOIN billing_invoices bi ON s.shipment_id = bi.shipment_id
    LEFT JOIN pricing_rules pr ON s.origin_port_id = pr.origin_port_id AND s.dest_port_id = pr.dest_port_id
    WHERE s.status != 'CANCELLED'
    GROUP BY s.shipment_id, s.seller_id, DATE_FORMAT(s.created_at, '%Y-%m-01'), bi.total_amount, s.quoted_price, pr.base_rate;
END //


-- =============================================================================
-- PROCEDURE 6: sp_refresh_all_fr6_analytics (Master Orchestrator)
-- Purpose: Executes all 5 recalculation procedures in a single atomic transaction.
-- =============================================================================
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

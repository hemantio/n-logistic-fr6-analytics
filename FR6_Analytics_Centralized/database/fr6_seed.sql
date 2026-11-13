-- =============================================================================
-- Module: FR6 - Analytics Dashboard
-- Script: fr6_dev_seed.sql
-- Description: Local/test seed data for FR6 cached analytics result entities.
-- Notice: Development/testing fixture only. Mark as test data, never production.
-- =============================================================================

USE `n_logistic_db`;

-- 1. Sales Trend Result Seed Data
INSERT INTO `sales_trend_result` (`result_id`, `period_month`, `origin_port_id`, `dest_port_id`, `total_sales`, `total_qty`, `growth_pct`) VALUES
(1, '2026-08-01', 1, 2, 1200000.00, 100, 0.00),
(2, '2026-09-01', 1, 2, 850000.00, 1000, -29.17),
(3, '2026-09-01', 1, 4, 1080000.00, 200, 0.00),
(4, '2026-10-01', 1, 4, 960000.00, 300, -11.11),
(5, '2026-10-01', 1, 2, 5100000.00, 150, 500.00),
(6, '2026-11-01', 1, 3, 975000.00, 150, 0.00)
ON DUPLICATE KEY UPDATE `total_sales` = VALUES(`total_sales`), `growth_pct` = VALUES(`growth_pct`);

-- 2. ABC Classification Result Seed Data (A = top 70%, B = next 20%, C = last 10%)
INSERT INTO `abc_classification_result` (`result_id`, `product_id`, `annual_value`, `cumulative_pct`, `abc_class`, `calculated_on`) VALUES
(1, 5, 4500000.00, 43.84, 'A', '2026-11-01'),
(2, 1, 1800000.00, 61.37, 'A', '2026-11-01'),
(3, 3, 1080000.00, 71.89, 'B', '2026-11-01'),
(4, 6, 975000.00, 81.39, 'B', '2026-11-01'),
(5, 4, 960000.00, 90.75, 'B', '2026-11-01'),
(6, 2, 850000.00, 100.00, 'C', '2026-11-01')
ON DUPLICATE KEY UPDATE `annual_value` = VALUES(`annual_value`), `abc_class` = VALUES(`abc_class`);

-- 3. Inventory Turnover Result Seed Data
INSERT INTO `inventory_turnover_result` (`result_id`, `product_id`, `period_start`, `period_end`, `cogs`, `avg_inventory`, `turnover_ratio`) VALUES
(1, 1, '2026-08-01', '2026-10-31', 1200000.00, 4800000.00, 0.25),
(2, 2, '2026-08-01', '2026-10-31', 850000.00, 2975000.00, 0.29),
(3, 3, '2026-08-01', '2026-10-31', 1080000.00, 4860000.00, 0.22),
(4, 4, '2026-08-01', '2026-10-31', 960000.00, 4320000.00, 0.22),
(5, 5, '2026-08-01', '2026-10-31', 4500000.00, 20250000.00, 0.22),
(6, 6, '2026-08-01', '2026-10-31', 975000.00, 4225000.00, 0.23)
ON DUPLICATE KEY UPDATE `turnover_ratio` = VALUES(`turnover_ratio`);

-- 4. Profitability Result Seed Data
INSERT INTO `profitability_result` (`result_id`, `product_id`, `period_month`, `revenue`, `cost`, `margin_pct`) VALUES
(1, 1, '2026-08-01', 1200000.00, 780000.00, 35.00),
(2, 2, '2026-09-01', 850000.00, 552500.00, 35.00),
(3, 3, '2026-09-01', 1080000.00, 723600.00, 33.00),
(4, 4, '2026-10-01', 960000.00, 652800.00, 32.00),
(5, 5, '2026-10-01', 4500000.00, 2700000.00, 40.00),
(6, 6, '2026-11-01', 975000.00, 682500.00, 30.00)
ON DUPLICATE KEY UPDATE `margin_pct` = VALUES(`margin_pct`);

-- 5. Demand Forecast Seed Data
INSERT INTO `demand_forecast` (`forecast_id`, `origin_port_id`, `dest_port_id`, `container_type`, `forecast_month`, `predicted_bookings`, `confidence_pct`, `suggested_multiplier`) VALUES
(1, 1, 2, 'DRY', '2026-12-01', 15, 88.50, 1.15),
(2, 1, 3, 'DRY', '2026-12-01', 8, 82.00, 1.05),
(3, 1, 4, 'REEFER', '2026-12-01', 12, 91.20, 1.25),
(4, 1, 2, 'REEFER', '2026-12-01', 6, 79.50, 1.10),
(5, 1, 5, 'DRY', '2026-12-01', 10, 85.00, 1.12)
ON DUPLICATE KEY UPDATE `predicted_bookings` = VALUES(`predicted_bookings`), `suggested_multiplier` = VALUES(`suggested_multiplier`);

-- 6. Profit and Loss Seed Data (Shipment / Seller level)
INSERT INTO `profit_loss` (`pl_id`, `shipment_id`, `seller_id`, `period_month`, `revenue`, `freight_cost`, `port_cost`, `handling_cost`, `claim_loss`, `net_profit`) VALUES
(1, 1, 1, '2026-08-01', 194700.00, 85000.00, 22000.00, 15000.00, 45000.00, 27700.00),
(2, 2, 1, '2026-09-01', 165200.00, 78000.00, 20000.00, 12000.00, 0.00, 55200.00),
(3, 3, 1, '2026-09-01', 365800.00, 160000.00, 38000.00, 25000.00, 0.00, 142800.00),
(4, 4, 1, '2026-10-01', 200000.00, 175000.00, 42000.00, 28000.00, 0.00, -45000.00)
ON DUPLICATE KEY UPDATE `revenue` = VALUES(`revenue`), `net_profit` = VALUES(`net_profit`);

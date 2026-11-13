-- =============================================================================
-- Module: FR6 - Analytics Dashboard
-- Script: fr6_indexes.sql
-- Description: Performance optimization indexes for FR6 analytics result entities
-- Target Database: n_logistic_db
-- =============================================================================

USE `n_logistic_db`;

-- Indexes for Sales Trend queries and month/route filtering
CREATE INDEX IF NOT EXISTS `idx_sales_trend_period_route` 
ON `sales_trend_result` (`period_month`, `origin_port_id`, `dest_port_id`);

-- Indexes for ABC Classification queries by product and class
CREATE INDEX IF NOT EXISTS `idx_abc_product_calc` 
ON `abc_classification_result` (`product_id`, `calculated_on`);

CREATE INDEX IF NOT EXISTS `idx_abc_class` 
ON `abc_classification_result` (`abc_class`);

-- Indexes for Inventory Turnover queries by product and period
CREATE INDEX IF NOT EXISTS `idx_inv_turnover_prod_period` 
ON `inventory_turnover_result` (`product_id`, `period_start`, `period_end`);

-- Indexes for Product Profitability queries by product and month
CREATE INDEX IF NOT EXISTS `idx_profitability_prod_period` 
ON `profitability_result` (`product_id`, `period_month`);

-- Indexes for Demand Forecasting lookups by route and container type
CREATE INDEX IF NOT EXISTS `idx_forecast_route_month` 
ON `demand_forecast` (`origin_port_id`, `dest_port_id`, `container_type`, `forecast_month`);

-- Indexes for Profit & Loss queries by seller and month
CREATE INDEX IF NOT EXISTS `idx_pl_seller_period` 
ON `profit_loss` (`seller_id`, `period_month`);

CREATE INDEX IF NOT EXISTS `idx_pl_shipment` 
ON `profit_loss` (`shipment_id`);

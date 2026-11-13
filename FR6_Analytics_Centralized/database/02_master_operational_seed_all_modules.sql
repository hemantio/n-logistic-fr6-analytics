-- =============================================================================
-- Module: FR6 - Analytics Dashboard (Local Testing Fixture)
-- Script: dev_only/local_operational_seed.sql
-- Description: Realistic operational test data for testing FR6 analytics against
-- real operational records (Shipments, Containers, Products, Billing, Claims, etc.)
-- Notice: Development/testing fixture only. Do NOT execute on production.
-- =============================================================================

USE `n_logistic_db`;

-- 1. Ports (Point A / Point B)
INSERT INTO `ports` (`port_id`, `port_code`, `port_name`, `city`, `country`, `latitude`, `longitude`) VALUES
(1, 'INNSA', 'Jawaharlal Nehru Port (Nhava Sheva)', 'Navi Mumbai', 'India', 18.9499, 72.9511),
(2, 'AEJEA', 'Jebel Ali Port', 'Dubai', 'United Arab Emirates', 25.0069, 55.0600),
(3, 'SGSIN', 'Port of Singapore', 'Singapore', 'Singapore', 1.2644, 103.8398),
(4, 'NLRTM', 'Port of Rotterdam', 'Rotterdam', 'Netherlands', 51.9054, 4.4666),
(5, 'CNSHG', 'Port of Shanghai', 'Shanghai', 'China', 31.2304, 121.4737)
ON DUPLICATE KEY UPDATE `port_name` = VALUES(`port_name`);

-- 2. Companies (Sellers & Consumers)
INSERT INTO `companies` (`company_id`, `company_name`, `company_type`, `gst_number`, `iec_code`, `address`, `city`, `country`) VALUES
(1, 'Apex Global Logistics Ltd', 'SELLER', '27AAACA1234A1Z5', '0301002345', 'Plot 42, Port Industrial Estate', 'Navi Mumbai', 'India'),
(2, 'Maritime Blue Ocean Exporters', 'SELLER', '24AAACB5678B1Z6', '0402008765', 'Wharf Road, Kandla Port Area', 'Gandhidham', 'India'),
(3, 'EuroAsia Retail Imports BV', 'CONSUMER', 'NL894726190B01', 'NL12345678', 'Keizersgracht 450', 'Amsterdam', 'Netherlands'),
(4, 'Gulf Traders LLC', 'CONSUMER', 'AE1002938475001', 'AE98765432', 'Al Mina Street, Deira', 'Dubai', 'United Arab Emirates'),
(5, 'Pacific Horizon Consumer Goods', 'CONSUMER', 'SG201938472M', 'SG11223344', '10 Marina Boulevard', 'Singapore', 'Singapore')
ON DUPLICATE KEY UPDATE `company_name` = VALUES(`company_name`);

-- 3. Users (Admin, Sellers, Consumers)
INSERT INTO `users` (`user_id`, `role`, `company_id`, `full_name`, `email`, `password_hash`, `phone`, `status`) VALUES
(1, 'ADMIN', NULL, 'System Administrator', 'admin@nlogistic.com', '$2a$10$abcdefghijklmnopqrstuv', '+919800000001', 'ACTIVE'),
(2, 'SELLER', 1, 'Rajesh Sharma (Apex Global)', 'rajesh@apexlogistics.com', '$2a$10$abcdefghijklmnopqrstuv', '+919800000002', 'ACTIVE'),
(3, 'SELLER', 2, 'Karan Patel (Maritime Blue)', 'karan@maritimeblue.com', '$2a$10$abcdefghijklmnopqrstuv', '+919800000003', 'ACTIVE'),
(4, 'CONSUMER', 3, 'Jan van Dijk (EuroAsia)', 'jan@euroasia.nl', '$2a$10$abcdefghijklmnopqrstuv', '+31201234567', 'ACTIVE'),
(5, 'CONSUMER', 4, 'Ahmed Al-Maktoum (Gulf Traders)', 'ahmed@gulftraders.ae', '$2a$10$abcdefghijklmnopqrstuv', '+97142345678', 'ACTIVE')
ON DUPLICATE KEY UPDATE `full_name` = VALUES(`full_name`);

-- 4. Customers
INSERT INTO `customers` (`customer_id`, `user_id`, `company_id`, `contact_person`, `billing_address`, `credit_limit`) VALUES
(1, 4, 3, 'Jan van Dijk', 'Keizersgracht 450, Amsterdam, Netherlands', 500000.00),
(2, 5, 4, 'Ahmed Al-Maktoum', 'Al Mina Street, Deira, Dubai, UAE', 750000.00)
ON DUPLICATE KEY UPDATE `contact_person` = VALUES(`contact_person`);

-- 5. Vessels
INSERT INTO `vessels` (`vessel_id`, `vessel_name`, `imo_number`, `owner_company_id`, `capacity_teu`, `status`) VALUES
(1, 'MV Ocean Pioneer', 'IMO9123456', 1, 4500, 'ACTIVE'),
(2, 'MV Northern Star', 'IMO9234567', 1, 6000, 'ACTIVE'),
(3, 'MV Arabian Express', 'IMO9345678', 2, 3800, 'ACTIVE')
ON DUPLICATE KEY UPDATE `vessel_name` = VALUES(`vessel_name`);

-- 6. Containers
INSERT INTO `containers` (`container_id`, `container_number`, `seller_id`, `container_type`, `size_ft`, `max_weight_kg`, `max_volume_cbm`, `current_port_id`, `status`) VALUES
(1, 'NLCU1000010', 1, 'DRY', 40, 28000.00, 67.70, 1, 'AVAILABLE'),
(2, 'NLCU1000025', 1, 'DRY', 20, 21500.00, 33.20, 1, 'AVAILABLE'),
(3, 'NLCU2000031', 1, 'REEFER', 40, 29000.00, 60.00, 1, 'ALLOCATED'),
(4, 'NLCU3000047', 1, 'OPEN_TOP', 40, 28000.00, 65.00, 2, 'IN_TRANSIT'),
(5, 'NLCU4000052', 1, 'TANK', 20, 24000.00, 26.00, 1, 'MAINTENANCE'),
(6, 'NLCU5000068', 2, 'DRY', 40, 28000.00, 67.70, 1, 'AVAILABLE'),
(7, 'NLCU6000073', 2, 'REEFER', 20, 22000.00, 28.50, 3, 'AVAILABLE'),
(8, 'NLCU7000089', 2, 'DRY', 40, 28000.00, 67.70, 2, 'IN_TRANSIT')
ON DUPLICATE KEY UPDATE `status` = VALUES(`status`);

-- 7. Products
INSERT INTO `products` (`product_id`, `sku`, `product_name`, `category`, `hs_code`, `unit`, `unit_weight_kg`, `unit_price`, `owner_company_id`) VALUES
(1, 'SKU-TEX-001', 'Premium Cotton Textiles', 'Textiles', '5208.11', 'box', 25.000, 12000.00, 1),
(2, 'SKU-SPICE-002', 'Organic Black Pepper', 'Spices', '0904.11', 'kg', 1.000, 850.00, 1),
(3, 'SKU-TEA-003', 'Darjeeling First Flush Tea', 'Beverages', '0902.10', 'box', 10.000, 5400.00, 1),
(4, 'SKU-ENG-004', 'Precision Steel Bearings', 'Engineering', '8482.10', 'pcs', 2.500, 3200.00, 1),
(5, 'SKU-PHARM-005', 'Active Pharma Ingredients', 'Pharmaceuticals', '2933.39', 'box', 15.000, 45000.00, 2),
(6, 'SKU-AUTO-006', 'Automotive Radiators', 'Automotive', '8708.91', 'pcs', 8.000, 6500.00, 2)
ON DUPLICATE KEY UPDATE `product_name` = VALUES(`product_name`);

-- 8. Stock
INSERT INTO `stock` (`stock_id`, `product_id`, `shipment_id`, `container_id`, `quantity`, `damaged_qty`) VALUES
(1, 1, NULL, NULL, 500, 5),
(2, 2, NULL, NULL, 3000, 20),
(3, 3, NULL, NULL, 800, 0),
(4, 4, NULL, NULL, 1200, 15),
(5, 5, NULL, NULL, 400, 2),
(6, 6, NULL, NULL, 650, 8)
ON DUPLICATE KEY UPDATE `quantity` = VALUES(`quantity`);

-- 9. Inventory Ledger
INSERT INTO `inventory_ledger` (`stock_id`, `product_id`, `txn_type`, `quantity`, `balance_after`, `reference_type`, `reference_id`, `txn_time`) VALUES
(1, 1, 'IN', 600, 600, 'UPLOAD', 101, '2026-08-01 09:00:00'),
(1, 1, 'OUT', 100, 500, 'SHIPMENT', 1, '2026-08-15 14:00:00'),
(2, 2, 'IN', 4000, 4000, 'UPLOAD', 102, '2026-08-01 09:30:00'),
(2, 2, 'OUT', 1000, 3000, 'SHIPMENT', 2, '2026-09-02 11:00:00'),
(3, 3, 'IN', 1000, 1000, 'UPLOAD', 103, '2026-09-01 10:00:00'),
(3, 3, 'OUT', 200, 800, 'SHIPMENT', 3, '2026-09-20 15:30:00'),
(4, 4, 'IN', 1500, 1500, 'UPLOAD', 104, '2026-09-01 10:30:00'),
(4, 4, 'OUT', 300, 1200, 'SHIPMENT', 4, '2026-10-10 16:00:00'),
(5, 5, 'IN', 500, 500, 'UPLOAD', 105, '2026-10-01 11:00:00'),
(5, 5, 'OUT', 100, 400, 'SHIPMENT', 5, '2026-10-25 12:00:00');

-- 10. Pricing Rules
INSERT INTO `pricing_rules` (`rule_id`, `seller_id`, `origin_port_id`, `dest_port_id`, `container_type`, `base_rate`, `rate_per_kg`, `rate_per_cbm`, `season_multiplier`, `demand_multiplier`, `valid_from`, `valid_to`, `is_active`) VALUES
(1, 1, 1, 2, 'DRY', 120000.00, 5.0000, 800.00, 1.05, 1.10, '2026-01-01', '2026-12-31', TRUE),
(2, 1, 1, 3, 'DRY', 145000.00, 6.0000, 950.00, 1.00, 1.00, '2026-01-01', '2026-12-31', TRUE),
(3, 1, 1, 4, 'REEFER', 280000.00, 9.5000, 1600.00, 1.15, 1.20, '2026-01-01', '2026-12-31', TRUE),
(4, 2, 1, 2, 'DRY', 118000.00, 4.8000, 780.00, 1.00, 1.05, '2026-01-01', '2026-12-31', TRUE),
(5, 2, 1, 5, 'REEFER', 260000.00, 8.5000, 1500.00, 1.10, 1.15, '2026-01-01', '2026-12-31', TRUE)
ON DUPLICATE KEY UPDATE `base_rate` = VALUES(`base_rate`);

-- 11. Shipments
INSERT INTO `shipment` (`shipment_id`, `shipment_no`, `consumer_id`, `seller_id`, `container_id`, `vessel_id`, `origin_port_id`, `dest_port_id`, `cargo_description`, `cargo_weight_kg`, `cargo_volume_cbm`, `quoted_price`, `status`, `etd`, `eta`, `actual_arrival`) VALUES
(1, 'SHP-2026-0001', 2, 1, 1, 1, 1, 2, 'Cotton garments consignment', 2500.00, 45.00, 165000.00, 'DELIVERED', '2026-08-10', '2026-08-20', '2026-08-21'),
(2, 'SHP-2026-0002', 2, 1, 2, 1, 1, 2, 'Kerala organic black pepper export', 1000.00, 20.00, 140000.00, 'DELIVERED', '2026-09-01', '2026-09-12', '2026-09-12'),
(3, 'SHP-2026-0003', 1, 1, 3, 2, 1, 4, 'Assorted Darjeeling tea boxes', 2000.00, 35.00, 310000.00, 'DELIVERED', '2026-09-15', '2026-10-05', '2026-10-06'),
(4, 'SHP-2026-0004', 1, 1, 4, 2, 1, 4, 'Heavy industrial bearings', 4500.00, 28.00, 340000.00, 'IN_TRANSIT', '2026-10-15', '2026-11-18', NULL),
(5, 'SHP-2026-0005', 2, 2, 8, 3, 1, 2, 'Specialized pharma materials', 1500.00, 18.00, 195000.00, 'IN_TRANSIT', '2026-10-25', '2026-11-15', NULL),
(6, 'SHP-2026-0006', 1, 2, 7, 3, 1, 3, 'Automotive radiators shipment', 3200.00, 40.00, 220000.00, 'BOOKED', '2026-11-20', '2026-12-05', NULL)
ON DUPLICATE KEY UPDATE `status` = VALUES(`status`);

-- 12. Shipment Items
INSERT INTO `shipment_items` (`item_id`, `shipment_id`, `product_id`, `quantity`, `unit_price`, `weight_kg`, `volume_cbm`, `amount`) VALUES
(1, 1, 1, 100, 12000.00, 2500.00, 45.00, 1200000.00),
(2, 2, 2, 1000, 850.00, 1000.00, 20.00, 850000.00),
(3, 3, 3, 200, 5400.00, 2000.00, 35.00, 1080000.00),
(4, 4, 4, 300, 3200.00, 4500.00, 28.00, 960000.00),
(5, 5, 5, 100, 45000.00, 1500.00, 18.00, 4500000.00),
(6, 6, 6, 150, 6500.00, 3200.00, 40.00, 975000.00);

-- 13. Sales Transactions
INSERT INTO `sales_transactions` (`sale_id`, `product_id`, `customer_id`, `shipment_id`, `quantity`, `unit_price`, `total_amount`, `sale_date`) VALUES
(1, 1, 2, 1, 100, 12000.00, 1200000.00, '2026-08-10'),
(2, 2, 2, 2, 1000, 850.00, 850000.00, '2026-09-01'),
(3, 3, 1, 3, 200, 5400.00, 1080000.00, '2026-09-15'),
(4, 4, 1, 4, 300, 3200.00, 960000.00, '2026-10-15'),
(5, 5, 2, 5, 100, 45000.00, 4500000.00, '2026-10-25'),
(6, 1, 2, NULL, 50, 12000.00, 600000.00, '2026-10-28'),
(7, 6, 1, 6, 150, 6500.00, 975000.00, '2026-11-05');

-- 14. Billing Invoices
INSERT INTO `billing_invoices` (`invoice_id`, `invoice_no`, `shipment_id`, `consumer_id`, `seller_id`, `sub_total`, `tax_amount`, `total_amount`, `paid_amount`, `status`, `issue_date`, `due_date`) VALUES
(1, 'INV-2026-0001', 1, 2, 1, 165000.00, 29700.00, 194700.00, 194700.00, 'PAID', '2026-08-10', '2026-08-25'),
(2, 'INV-2026-0002', 2, 2, 1, 140000.00, 25200.00, 165200.00, 165200.00, 'PAID', '2026-09-01', '2026-09-16'),
(3, 'INV-2026-0003', 3, 1, 1, 310000.00, 55800.00, 365800.00, 365800.00, 'PAID', '2026-09-15', '2026-09-30'),
(4, 'INV-2026-0004', 4, 1, 1, 340000.00, 61200.00, 401200.00, 200000.00, 'PARTIAL', '2026-10-15', '2026-10-30'),
(5, 'INV-2026-0005', 5, 2, 2, 195000.00, 35100.00, 230100.00, 0.00, 'UNPAID', '2026-10-25', '2026-11-10'),
(6, 'INV-2026-0006', 6, 1, 2, 220000.00, 39600.00, 259600.00, 0.00, 'UNPAID', '2026-11-05', '2026-11-20')
ON DUPLICATE KEY UPDATE `status` = VALUES(`status`), `paid_amount` = VALUES(`paid_amount`);

-- 15. Invoice Line Items
INSERT INTO `invoice_line_items` (`item_id`, `invoice_id`, `item_type`, `description`, `quantity`, `unit_price`, `amount`) VALUES
(1, 1, 'FREIGHT', 'Ocean freight charges (INNSA to AEJEA)', 1.00, 120000.00, 120000.00),
(2, 1, 'HANDLING', 'Port terminal handling charges', 1.00, 45000.00, 45000.00),
(3, 1, 'TAX', 'GST @ 18%', 1.00, 29700.00, 29700.00),
(4, 2, 'FREIGHT', 'Ocean freight charges (INNSA to AEJEA)', 1.00, 110000.00, 110000.00),
(5, 2, 'HANDLING', 'Terminal handling', 1.00, 30000.00, 30000.00),
(6, 2, 'TAX', 'GST @ 18%', 1.00, 25200.00, 25200.00),
(7, 3, 'FREIGHT', 'Ocean freight reefer (INNSA to NLRTM)', 1.00, 240000.00, 240000.00),
(8, 3, 'INSURANCE', 'Marine cargo transit insurance', 1.00, 70000.00, 70000.00),
(9, 3, 'TAX', 'GST @ 18%', 1.00, 55800.00, 55800.00);

-- 16. Payments
INSERT INTO `payments` (`payment_id`, `invoice_id`, `amount`, `payment_mode`, `reference_no`, `payment_date`, `recorded_by`) VALUES
(1, 1, 194700.00, 'BANK', 'TXN-HDFC-991823', '2026-08-20', 2),
(2, 2, 165200.00, 'UPI', 'UPI-AXIS-882736', '2026-09-10', 2),
(3, 3, 365800.00, 'BANK', 'TXN-CITI-443210', '2026-09-28', 2),
(4, 4, 200000.00, 'BANK', 'TXN-HSBC-112233', '2026-10-28', 2);

-- 17. Claims
INSERT INTO `claims` (`claim_id`, `claim_no`, `shipment_id`, `container_id`, `consumer_id`, `claim_type`, `description`, `claimed_amount`, `approved_amount`, `status`, `seller_remarks`, `raised_at`, `settled_at`) VALUES
(1, 'CLM-2026-001', 1, 1, 2, 'DAMAGE', '5 boxes torn due to rough handling during unloading', 60000.00, 45000.00, 'SETTLED', 'Agreed for partial settlement after survey verification', '2026-08-22 10:00:00', '2026-08-28 16:00:00'),
(2, 'CLM-2026-002', 3, 3, 1, 'DELAY', 'Reefer temperature fluctuations caused 1 day delay review', 35000.00, 20000.00, 'APPROVED', 'Approved compensation as per service level agreement', '2026-10-10 11:30:00', NULL),
(3, 'CLM-2026-003', 4, 4, 1, 'SHORTAGE', 'Initial inspection notes 2 crates shortage', 40000.00, 0.00, 'UNDER_REVIEW', 'Investigation ongoing with port security', '2026-11-02 09:15:00', NULL)
ON DUPLICATE KEY UPDATE `status` = VALUES(`status`), `approved_amount` = VALUES(`approved_amount`);

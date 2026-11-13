# FR6 Analytics Dashboard - Database Documentation

This document describes the database architecture, table relationships, read/write boundaries, and transaction management for FR6.

Target database: `n_logistic_db` (MySQL on XAMPP / MariaDB 10.4+, InnoDB, utf8mb4).

---

## 1. Table Ownership Boundary

| Table Name | Owner Module | FR6 Access Level | Purpose in FR6 |
|---|---|---|---|
| `companies` | FR1 (Users & Auth) | READ ONLY | Company names, types, and company-level filtering |
| `users` | FR1 (Users & Auth) | READ ONLY | User identity & audit log FK references |
| `customers` | FR1 (Users & Auth) | READ ONLY | Customer profiles & customer ABC analysis |
| `ports` | FR2 (Movement) | READ ONLY | Point A / Point B route origins & destinations |
| `vessels` | FR2 (Movement) | READ ONLY | Vessel identification for shipments |
| `containers` | FR3 (Allocation) | READ ONLY | Container availability KPI & container types |
| `shipment` | FR2 (Movement) | READ ONLY | Active shipments KPI, route volume calculations |
| `container_movements` | FR2 (Movement) | READ ONLY | Movement history & event tracking |
| `shipment_items` | FR2 (Movement) | READ ONLY | Cargo quantity, weight, and volume aggregation |
| `pricing_rules` | FR3 (Pricing) | READ / WRITE | Active pricing rules; updated via FR6.6 multiplier sync |
| `pricing_audit` | FR3 (Pricing) | WRITE ONLY | Audit logging of multiplier changes |
| `products` | FR4 (Stock) | READ ONLY | Product master (SKU, name, category, price) |
| `stock` | FR4 (Stock) | READ ONLY | Stock levels for average inventory calculations |
| `inventory_ledger` | FR4 (Stock) | READ ONLY | Outgoing inventory movement for COGS calculations |
| `sales_transactions` | FR4 (Stock) | READ ONLY | Historical sales value for trends and ABC Pareto |
| `billing_invoices` | FR5 (Billing) | READ ONLY | Revenue KPI and pending invoices KPI |
| `invoice_line_items` | FR5 (Billing) | READ ONLY | Cost breakdowns (freight, port, handling) for P&L |
| `payments` | FR5 (Billing) | READ ONLY | Recorded customer payments |
| `claims` | FR7 (Claims) | READ ONLY | Open claims KPI & settled claim loss for P&L |
| `claim_documents` | FR7 (Claims) | READ ONLY | Claim evidence records |
| `claim_status_history`| FR7 (Claims) | READ ONLY | Claim status change logs |
| **`sales_trend_result`** | **FR6 (Analytics)** | **FULL OWNERSHIP** | Cached route-level monthly sales & growth % |
| **`abc_classification_result`** | **FR6 (Analytics)** | **FULL OWNERSHIP** | Cached product ABC Pareto classification |
| **`inventory_turnover_result`** | **FR6 (Analytics)** | **FULL OWNERSHIP** | Cached product inventory turnover ratio |
| **`profitability_result`** | **FR6 (Analytics)** | **FULL OWNERSHIP** | Cached product-level margins |
| **`demand_forecast`** | **FR6 (Analytics)** | **FULL OWNERSHIP** | Cached route/container demand forecasts |
| **`profit_loss`** | **FR6 / FR2 (Shared)** | **FULL OWNERSHIP** | Shipment & seller-level P&L records |

---

## 2. FR6-Owned Table Schemas

### 2.1 `sales_trend_result` (ERD #10 / SRS 7.9)
```sql
CREATE TABLE IF NOT EXISTS `sales_trend_result` (
    `result_id` INT AUTO_INCREMENT PRIMARY KEY,
    `period_month` DATE NOT NULL,
    `origin_port_id` INT NULL,
    `dest_port_id` INT NULL,
    `total_sales` DECIMAL(14, 2) NOT NULL DEFAULT 0.00,
    `total_qty` INT NOT NULL DEFAULT 0,
    `growth_pct` DECIMAL(6, 2) NOT NULL DEFAULT 0.00,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT `fk_strend_origin` FOREIGN KEY (`origin_port_id`) REFERENCES `ports` (`port_id`) ON DELETE SET NULL,
    CONSTRAINT `fk_strend_dest` FOREIGN KEY (`dest_port_id`) REFERENCES `ports` (`port_id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

### 2.2 `abc_classification_result` (ERD #26 / SRS 7.9)
```sql
CREATE TABLE IF NOT EXISTS `abc_classification_result` (
    `result_id` INT AUTO_INCREMENT PRIMARY KEY,
    `product_id` INT NOT NULL,
    `annual_value` DECIMAL(14, 2) NOT NULL DEFAULT 0.00,
    `cumulative_pct` DECIMAL(5, 2) NOT NULL DEFAULT 0.00,
    `abc_class` CHAR(1) NOT NULL COMMENT 'A = top 70%, B = next 20%, C = last 10%',
    `calculated_on` DATE NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT `fk_abc_product` FOREIGN KEY (`product_id`) REFERENCES `products` (`product_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

### 2.3 `inventory_turnover_result` (ERD #27 / SRS 7.9)
```sql
CREATE TABLE IF NOT EXISTS `inventory_turnover_result` (
    `result_id` INT AUTO_INCREMENT PRIMARY KEY,
    `product_id` INT NOT NULL,
    `period_start` DATE NOT NULL,
    `period_end` DATE NOT NULL,
    `cogs` DECIMAL(14, 2) NOT NULL DEFAULT 0.00 COMMENT 'Cost of goods sold',
    `avg_inventory` DECIMAL(14, 2) NOT NULL DEFAULT 0.00,
    `turnover_ratio` DECIMAL(8, 2) NOT NULL DEFAULT 0.00 COMMENT 'cogs / avg_inventory',
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT `fk_iturnover_product` FOREIGN KEY (`product_id`) REFERENCES `products` (`product_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

### 2.4 `profitability_result` (ERD #28 / SRS 7.9)
```sql
CREATE TABLE IF NOT EXISTS `profitability_result` (
    `result_id` INT AUTO_INCREMENT PRIMARY KEY,
    `product_id` INT NOT NULL,
    `period_month` DATE NOT NULL,
    `revenue` DECIMAL(14, 2) NOT NULL DEFAULT 0.00,
    `cost` DECIMAL(14, 2) NOT NULL DEFAULT 0.00,
    `margin_pct` DECIMAL(6, 2) NOT NULL DEFAULT 0.00,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT `fk_profitability_product` FOREIGN KEY (`product_id`) REFERENCES `products` (`product_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

### 2.5 `demand_forecast` (ERD #8 / SRS 7.5)
```sql
CREATE TABLE IF NOT EXISTS `demand_forecast` (
    `forecast_id` INT AUTO_INCREMENT PRIMARY KEY,
    `origin_port_id` INT NOT NULL,
    `dest_port_id` INT NOT NULL,
    `container_type` ENUM('DRY', 'REEFER', 'OPEN_TOP', 'TANK') NOT NULL,
    `forecast_month` DATE NOT NULL,
    `predicted_bookings` INT NOT NULL DEFAULT 0,
    `confidence_pct` DECIMAL(5, 2) NOT NULL DEFAULT 0.00,
    `suggested_multiplier` DECIMAL(4, 2) NOT NULL DEFAULT 1.00,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT `fk_dforecast_origin` FOREIGN KEY (`origin_port_id`) REFERENCES `ports` (`port_id`) ON DELETE RESTRICT,
    CONSTRAINT `fk_dforecast_dest` FOREIGN KEY (`dest_port_id`) REFERENCES `ports` (`port_id`) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

### 2.6 `profit_loss` (ERD #12 / SRS 7.9)
```sql
CREATE TABLE IF NOT EXISTS `profit_loss` (
    `pl_id` INT AUTO_INCREMENT PRIMARY KEY,
    `shipment_id` INT NULL,
    `seller_id` INT NOT NULL,
    `period_month` DATE NOT NULL COMMENT 'First day of month',
    `revenue` DECIMAL(14, 2) NOT NULL DEFAULT 0.00,
    `freight_cost` DECIMAL(14, 2) NOT NULL DEFAULT 0.00,
    `port_cost` DECIMAL(14, 2) NOT NULL DEFAULT 0.00,
    `handling_cost` DECIMAL(14, 2) NOT NULL DEFAULT 0.00,
    `claim_loss` DECIMAL(14, 2) NOT NULL DEFAULT 0.00 COMMENT 'Added when claim is settled',
    `net_profit` DECIMAL(14, 2) NOT NULL DEFAULT 0.00 COMMENT 'revenue - all costs - claim_loss',
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT `fk_pl_shipment` FOREIGN KEY (`shipment_id`) REFERENCES `shipment` (`shipment_id`) ON DELETE SET NULL,
    CONSTRAINT `fk_pl_seller` FOREIGN KEY (`seller_id`) REFERENCES `companies` (`company_id`) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

---

## 3. Transaction Management & Atomicity

In `AnalyticsRefreshService`:
- Recalculation across all 5 cached analytics tables runs inside a single JDBC transaction boundary:
  ```java
  conn.setAutoCommit(false);
  try {
      salesTrendDAO.refreshRouteSalesTrends(conn);
      abcDAO.refreshAbcClassification(conn);
      turnoverDAO.refreshInventoryTurnover(conn, null, null);
      profitabilityDAO.refreshProfitability(conn);
      forecastDAO.refreshDemandForecasts(conn);
      conn.commit();
  } catch (SQLException e) {
      conn.rollback();
      throw e;
  }
  ```
- This prevents half-refreshed or corrupted state if any single step fails.

# N Logistic Platform - FR6 Analytics Module

Comprehensive implementation and integration repository for **Module FR6 (Analytics Dashboard)** of the **N Logistic Import & Export / Logistics Management Platform**.

This repository contains two production-grade backend implementations, complete SQL schemas for all 28 tables, stored procedures, seed data, and a verification test suite.

---

## Repository Structure

```text
.
├── FR6_Analytics/                      # Implementation A: Granular MVC2 Architecture
│   ├── src/com/nlogistic/fr6/          # 7 Servlets, 7 Services, 6 DAOs
│   ├── WebContent/                     # JSPs, CSS, JS, WEB-INF (with JSTL & MySQL JDBC)
│   ├── database/                       # FR6 database scripts
│   ├── docs/                           # Integration and architecture guides
│   └── tests/                          # Automated unit & smoke tests
│
├── FR6_Analytics_Centralized/          # Implementation B: Centralized MVC2 Architecture (Recommended for TL)
│   ├── src/com/nlogistic/fr6/
│   │   ├── controller/AnalyticsServlet.java       # Centralized HTTP request controller & router
│   │   ├── service/AnalyticsService.java          # All FR6.1 - FR6.8 business calculations
│   │   ├── dao/AnalyticsDAO.java                  # All FR6 SQL queries & transactions
│   │   ├── model/                                 # 7 POJO entity models
│   │   ├── config/AnalyticsConnectionProvider.java # DB connection interface seam
│   │   └── util/AnalyticsUtil.java                # JSON and query parsing helpers
│   ├── WebContent/                                # Unified dashboard view & assets
│   ├── database/                                  # Full 28-table schema, seed, SPs, verification
│   │   ├── 01_master_schema_all_28_tables.sql
│   │   ├── 02_master_operational_seed_all_modules.sql
│   │   ├── 03_fr6_stored_procedures.sql
│   │   ├── 04_verify_all_modules_db.sql
│   │   └── FR6_DATABASE_HANDOVER_FOR_TL.sql       # Master DDL handover file for the Team Lead
│   ├── tests/FR6CentralizedTestRunner.java        # 9/9 Automated test suite
│   └── docs/FR6_INTEGRATION_GUIDE.md
│
└── README.md
```

---

## Architectural Comparison

| Dimension | Implementation A (`FR6_Analytics`) | Implementation B (`FR6_Analytics_Centralized`) |
| :--- | :--- | :--- |
| **Servlet Namespace** | 7 discrete Servlets (`/fr6/analytics/*`) | 1 central Controller (`AnalyticsServlet` mapped to `/fr6/analytics/*`) |
| **Business Logic** | 7 dedicated Service classes | 1 cohesive Service (`AnalyticsService`) |
| **Data Access** | 6 dedicated DAO classes | 1 unified DAO (`AnalyticsDAO`) with atomic transactions |
| **Model Layer** | Distinct POJO result models | Distinct POJO result models |
| **Integration Complexity** | Higher (multiple wiring points for TL) | **Minimal (1 Servlet, 1 Service, 1 DAO, 1 DB seam)** |
| **Recommended Use** | Micro-modular projects | **Core Team Lead Handover & Integration** |

---

## FR6 Feature Mapping (FR6.1 - FR6.8)

1. **FR6.1 - Executive KPIs:** Container volume, active shipments, gross revenue, claim rate.
2. **FR6.2 - Sales Trend Analysis:** Route, product, and customer historical trends and growth %.
3. **FR6.3 - ABC (Pareto) Classification:** 70% (Class A), 20% (Class B), 10% (Class C) volume analysis.
4. **FR6.4 - Inventory Turnover:** COGS / Average inventory ratio and stock movement tracking.
5. **FR6.5 - Product & Shipment Profitability (P&L):** Net profit calculation per SRS FR2.8:
   $$\text{Net Profit} = \text{Revenue} - \text{Freight Cost} - \text{Port Cost} - \text{Handling Cost} - \text{Claim Loss}$$
6. **FR6.6 - Demand Forecasting:** Next-month booking projections and dynamic pricing multipliers.
7. **FR6.7 - Analytics Cache & Refresh:** On-demand recalculation via `sp_refresh_all_fr6_analytics`.
8. **FR6.8 - Multi-Dimensional Filtering:** Date range, origin/destination port, product, customer filtering.

---

## Database Setup

1. Start Apache & MySQL in **XAMPP** (or standalone MariaDB 10.4+ / MySQL 8.0+).
2. Run the SQL scripts in order:
   ```bash
   # 1. Create all 28 project tables with foreign keys
   mysql -u root n_logistic_db < FR6_Analytics_Centralized/database/01_master_schema_all_28_tables.sql

   # 2. Populate operational seed data across all 7 modules
   mysql -u root n_logistic_db < FR6_Analytics_Centralized/database/02_master_operational_seed_all_modules.sql

   # 3. Create all 7 stored procedures
   mysql -u root n_logistic_db < FR6_Analytics_Centralized/database/03_fr6_stored_procedures.sql

   # 4. Verify cross-module integrity
   mysql -u root n_logistic_db < FR6_Analytics_Centralized/database/04_verify_all_modules_db.sql
   ```

---

## Running the Automated Test Suite

To verify the database and backend calculations without starting Tomcat:
```powershell
cd "FR6_Analytics_Centralized"
java -cp "build/classes;WebContent/WEB-INF/lib/*" tests.FR6CentralizedTestRunner
```
**Test Results:** `9/9 Tests Passed (100% Success)`

---

## Technology Stack

* **Language:** Java 21 / 11 compatibility (Pure MVC2 architecture)
* **Web Container:** Apache Tomcat 9.0.x (`javax.servlet.*`)
* **Database:** MySQL 8.0+ / MariaDB 10.4+ on XAMPP (`n_logistic_db`)
* **Libraries:** JSTL 1.2, MySQL Connector/J 9.1.0, Chart.js 4.4, Bootstrap 5.3
* **No external frameworks:** Built without Spring, Hibernate, or Node.js to adhere strictly to the project SRS.

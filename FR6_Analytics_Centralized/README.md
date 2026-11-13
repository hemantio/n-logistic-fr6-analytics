# FR6 Analytics Module (Centralized MVC2 Architecture)

Independent, integration-ready Java MVC2 implementation of **Functional Requirement 6 (FR6 - Analytics Dashboard)** for the *N Logistic Import & Export / Logistics Management Platform*.

---

## Architecture Summary

This implementation uses a **centralized MVC2 design** grouping all analytical responsibilities into 3 primary backend classes:

```
FR6_Analytics_Centralized/
│
├── src/
│   ├── fr6_db.properties
│   └── com/nlogistic/fr6/
│       ├── controller/
│       │   └── AnalyticsServlet.java         <-- Single Central Controller
│       ├── service/
│       │   └── AnalyticsService.java         <-- Single Central Business Logic & Algorithms
│       ├── dao/
│       │   └── AnalyticsDAO.java             <-- Single Central Database Access
│       ├── model/                            <-- 7 POJO Models (ERD Entities + KPI)
│       │   ├── AnalyticsKPI.java
│       │   ├── SalesTrendResult.java
│       │   ├── AbcClassificationResult.java
│       │   ├── InventoryTurnoverResult.java
│       │   ├── ProfitabilityResult.java
│       │   ├── ProfitLoss.java
│       │   └── DemandForecast.java
│       ├── config/
│       │   └── AnalyticsConnectionProvider.java
│       └── util/
│           └── AnalyticsUtil.java
│
├── database/
│   ├── fr6_schema.sql
│   ├── fr6_seed.sql
│   └── fr6_indexes.sql
│
├── tests/
│   └── FR6CentralizedTestRunner.java         <-- Automated CLI Test Suite (9 tests)
│
├── docs/
│   └── FR6_INTEGRATION_GUIDE.md
│
├── WebContent/
│   ├── index.jsp
│   ├── assets/
│   │   ├── css/fr6/
│   │   └── js/fr6/
│   └── WEB-INF/
│       ├── web.xml
│       ├── lib/
│       └── views/analytics/
│
└── README.md
```

---

## Responsibility Mapping

| Requirement | `AnalyticsService` | `AnalyticsDAO` |
| :--- | :--- | :--- |
| **FR6.1 KPI** | KPI calculations & summaries | Fetch KPI source data (shipments, containers, paid invoices, claims) |
| **FR6.2 Sales** | Trend aggregation (Route, Product, Customer) | Sales queries on `shipment`, `sales_transactions`, `products` |
| **FR6.3 ABC** | Classification algorithm (70% Class A, 20% Class B, 10% Class C) | Product and customer sales aggregations |
| **FR6.4 Inventory** | Turnover ratio (`COGS / Avg Inventory`) & velocity categorization | Stock movements from `inventory_ledger` and `stock` |
| **FR6.5 Profitability** | Product margin % and shipment net profit calculations | Revenue and cost queries |
| **FR6.6 Forecast** | Demand prediction & multiplier recommendations | Historical booking queries + FR3 dynamic pricing sync & audit |
| **FR6.7 Cache** | Refresh coordination across all 6 models | Atomic transactional refresh with commit/rollback |
| **FR6.8 Filtering** | Date range parsing and security isolation | Filtered SQL queries honoring tenant boundaries |

---

## How to Test via Console (Headless)

Run the automated test runner in PowerShell:

```powershell
& "C:\Program Files\Java\jdk-21.0.12\bin\java.exe" `
  -cp "c:\Users\HEMANT\Desktop\srs erd\FR6_Analytics_Centralized\build\classes;c:\Users\HEMANT\Desktop\srs erd\FR6_Analytics_Centralized\WebContent\WEB-INF\lib\mysql-connector-j-9.1.0.jar;c:\Users\HEMANT\Desktop\srs erd\FR6_Analytics_Centralized\WebContent\WEB-INF\lib\jstl-1.2.jar" `
  com.nlogistic.fr6.tests.FR6CentralizedTestRunner
```

Expected output:
```text
===============================================================
   FR6 Centralized MVC2 - Full Automated Test Suite            
===============================================================
[TEST 1] Testing JDBC Connection to n_logistic_db... PASSED
[TEST 2] Testing FR6.1 Centralized Dashboard KPIs... PASSED
[TEST 3] Testing FR6.2 Sales Trend Aggregations (Route/Product/Customer)... PASSED
[TEST 4] Testing FR6.3 ABC Pareto Classification (70/20/10 Policy)... PASSED
[TEST 5] Testing FR6.4 Inventory Turnover Ratio & Velocity... PASSED
[TEST 6] Testing FR6.5 Product Profitability & Shipment P&L... PASSED
[TEST 7] Testing FR6.6 Demand Forecasting & FR3 Pricing Sync... PASSED
[TEST 8] Testing FR6.7 Atomic Transactional Analytics Refresh... PASSED
[TEST 9] Testing FR6.8 Multi-Tenant Isolation & Role Enforcement... PASSED
===============================================================
   CENTRALIZED TEST SUMMARY: 9 PASSED, 0 FAILED
===============================================================
```

---

## How to Deploy to Apache Tomcat 9

1. Copy `FR6_Analytics_Centralized/WebContent` to Tomcat's `webapps/FR6_Analytics_Centralized`.
2. Start Tomcat.
3. Access in browser: `http://localhost:8080/FR6_Analytics_Centralized/fr6/analytics/dashboard`

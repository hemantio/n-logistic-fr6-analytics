# FR6 - Analytics Dashboard Module

**Project:** N Logistic Import & Export / Logistics Management Platform  
**Module:** FR6 - Analytics Dashboard  
**Architecture:** Java MVC2 (Servlets, JSP + JSTL, DAO + JDBC, POJO, Bootstrap 5, Chart.js)  
**Database:** `n_logistic_db`  
**Target Server:** Apache Tomcat 9+  

---

## 1. Module Overview

FR6 is the dedicated Analytics Dashboard module for the N Logistic platform. Built strictly in accordance with the project Software Requirements Specification (SRS) and the 28-Entity Chen ER Diagram, it provides real-time, cached, and interactive business intelligence across all platform operations:

- **FR6.1 - Analytics Dashboard KPIs:** Real-time metrics for Active Shipments, Containers Available, Realized Revenue (Paid Invoices per FR2.8), Pending Invoices (Count and Outstanding Amount), and Open Claims (Count and Claimed Value).
- **FR6.2 - Sales Trend Analysis:** Time-series analysis for revenue and volume over time broken down by Route, Product, or Customer, with percentage growth calculation against previous periods.
- **FR6.3 - ABC (Pareto) Classification:** Product and customer contribution classification using the strict SRS Section 7.9 policy: Class A = Top 70%, Class B = Next 20%, Class C = Last 10%.
- **FR6.4 - Inventory Turnover Ratio:** Product-level turnover velocity calculated using `turnover_ratio = cogs / avg_inventory` from ledger out-movements and warehouse stock valuations.
- **FR6.5 - Product Profitability & Shipment P&L:** Product margin analysis and shipment/seller financial performance per SRS FR2.8 (`revenue - freight_cost - port_cost - handling_cost - claim_loss`).
- **FR6.6 - Demand Forecasting & FR3 Pricing Sync:** Predictive route/container booking demand with model confidence scores and suggested pricing multipliers, complete with atomic updates to FR3 `pricing_rules` and audit trail logging in `pricing_audit`.
- **FR6.7 - Cached Analytics Results & Refresh:** Transactional recalculation across all 5 cached analytics tables (`sales_trend_result`, `abc_classification_result`, `inventory_turnover_result`, `profitability_result`, `demand_forecast`, and `profit_loss`).
- **FR6.8 - Interactive Visualizations & Filters:** Chart.js visualizations (Line, Bar, and Pie/Donut charts) with server-side filters for Date range, Origin/Destination Port routes, and Company-level access control.

---

## 2. Project Directory Structure

```text
FR6_Analytics/
├── .classpath
├── .project
├── .settings/
│   ├── org.eclipse.jdt.core.prefs
│   ├── org.eclipse.wst.common.component
│   └── org.eclipse.wst.common.project.facet.core.xml
├── build/
│   └── classes/
├── src/
│   ├── fr6_db.properties
│   └── com/nlogistic/fr6/
│       ├── config/
│       │   ├── AnalyticsAccessContext.java
│       │   ├── AnalyticsConnectionProvider.java
│       │   └── LocalAnalyticsConnectionProvider.java
│       ├── controller/
│       │   ├── AbcClassificationServlet.java
│       │   ├── AnalyticsDashboardServlet.java
│       │   ├── AnalyticsRefreshServlet.java
│       │   ├── DemandForecastServlet.java
│       │   ├── InventoryTurnoverServlet.java
│       │   ├── ProfitabilityServlet.java
│       │   └── SalesTrendServlet.java
│       ├── dao/
│       │   ├── AbcClassificationDAO.java
│       │   ├── AnalyticsDashboardDAO.java
│       │   ├── DemandForecastDAO.java
│       │   ├── InventoryTurnoverDAO.java
│       │   ├── ProfitabilityDAO.java
│       │   └── SalesTrendDAO.java
│       ├── dto/
│       │   ├── AnalyticsDashboardDTO.java
│       │   ├── AnalyticsFilterDTO.java
│       │   ├── ForecastDTO.java
│       │   ├── ProfitabilityDTO.java
│       │   └── SalesTrendDTO.java
│       ├── exception/
│       │   ├── AnalyticsDataException.java
│       │   └── AnalyticsException.java
│       ├── model/
│       │   ├── AbcClassificationResult.java
│       │   ├── AnalyticsKPI.java
│       │   ├── DemandForecast.java
│       │   ├── InventoryTurnoverResult.java
│       │   ├── ProfitLoss.java
│       │   ├── ProfitabilityResult.java
│       │   └── SalesTrendResult.java
│       ├── service/
│       │   ├── AbcClassificationService.java
│       │   ├── AnalyticsDashboardService.java
│       │   ├── AnalyticsRefreshService.java
│       │   ├── DemandForecastService.java
│       │   ├── InventoryTurnoverService.java
│       │   ├── ProfitabilityService.java
│       │   └── SalesTrendService.java
│       ├── test/
│       │   └── FR6StandaloneTestRunner.java
│       └── util/
│           ├── AnalyticsDateUtil.java
│           └── AnalyticsValidationUtil.java
├── WebContent/
│   ├── index.jsp
│   ├── assets/
│   │   ├── css/fr6/
│   │   │   ├── analytics.css
│   │   │   └── bootstrap.min.css
│   │   └── js/fr6/
│   │       ├── abc-classification.js
│   │       ├── analytics-dashboard.js
│   │       ├── bootstrap.bundle.min.js
│   │       ├── chart.umd.min.js
│   │       ├── demand-forecast.js
│   │       ├── inventory-turnover.js
│   │       ├── profitability.js
│   │       └── sales-trends.js
│   └── WEB-INF/
│       ├── web.xml
│       ├── lib/
│       │   ├── jstl-1.2.jar
│       │   └── mysql-connector-j-9.1.0.jar
│       └── views/analytics/
│           ├── abc-classification.jsp
│           ├── dashboard.jsp
│           ├── demand-forecast.jsp
│           ├── footer.jspf
│           ├── inventory-turnover.jsp
│           ├── navbar.jspf
│           ├── profitability.jsp
│           └── sales-trends.jsp
├── database/
│   ├── fr6_dev_seed.sql
│   ├── fr6_indexes.sql
│   ├── fr6_schema.sql
│   └── dev_only/
│       ├── local_operational_seed.sql
│       └── local_schema_all_28_tables.sql
└── docs/
    ├── FR6_API_DOCUMENTATION.md
    ├── FR6_DATABASE_DOCUMENTATION.md
    ├── FR6_DEPENDENCIES.md
    └── FR6_INTEGRATION_GUIDE.md
```

---

## 3. How to Open and Run in Eclipse IDE

1. **Launch Eclipse IDE for Enterprise Java and Web Developers.**
2. Go to **File -> Open Projects from File System...** (or **File -> Import... -> General -> Existing Projects into Workspace**).
3. Select the folder `c:\Users\HEMANT\Desktop\srs erd\FR6_Analytics`.
4. Click **Finish**.
5. Eclipse will automatically recognize the project facets (Java 21, Dynamic Web Module 4.0).
6. Right-click `FR6_Analytics` -> **Run As -> Run on Server** -> Select **Apache Tomcat v9.0 Server at localhost**.
7. Access the application in your browser at:
   `http://localhost:8080/FR6_Analytics/` (redirects automatically to `/fr6/analytics/dashboard`).

---

## 4. Running the Standalone Verification Test Suite

You can execute the automated test suite directly from the command line:
```powershell
& "C:\Program Files\Java\jdk-21.0.12\bin\java.exe" `
  -cp "FR6_Analytics\build\classes;FR6_Analytics\WebContent\WEB-INF\lib\mysql-connector-j-9.1.0.jar;FR6_Analytics\WebContent\WEB-INF\lib\jstl-1.2.jar" `
  com.nlogistic.fr6.test.FR6StandaloneTestRunner
```

### Test Suite Execution Output:
```
===============================================================
   FR6 Analytics Dashboard - Full Verification Test Suite   
===============================================================
[TEST 1] Testing JDBC Connection to n_logistic_db... PASSED
[TEST 2] Testing FR6.1 Dashboard KPIs... PASSED
         -> Active Shipments: 3
         -> Containers Available: 4
         -> Total Revenue: INR 725,700.00
         -> Pending Invoices: 3 (INR 690,900.00)
         -> Open Claims: 2 (INR 75,000.00)
[TEST 3] Testing FR6.2 Sales Trend Analysis (Route, Product, Customer)... PASSED
[TEST 4] Testing FR6.3 ABC Pareto Classification (SRS 70/20/10 Policy)... PASSED
         -> Class A count: 2 (Sum: INR 6,300,000.00)
         -> Class B count: 3 (Sum: INR 3,015,000.00)
         -> Class C count: 1 (Sum: INR 850,000.00)
[TEST 5] Testing FR6.4 Inventory Turnover Ratio... PASSED
         -> Evaluated Products: 6, Average Turnover Ratio: 0.24x
[TEST 6] Testing FR6.5 Product Profitability & Shipment P&L... PASSED
[TEST 7] Testing FR6.6 Demand Forecasting & FR3 Multiplier Application... PASSED
         -> Applied Multiplier: 1.15 to FR3 Pricing Rules
         -> Pricing Audit Log Verified: YES
[TEST 8] Testing FR6.7 Atomic Transactional Analytics Refresh... PASSED
         -> Total Rows Refreshed: 35 in 51ms
[TEST 9] Testing Multi-Tenant Company Isolation and Role Enforcement... PASSED
===============================================================
   VERIFICATION SUMMARY: 9 PASSED, 0 FAILED
===============================================================
```

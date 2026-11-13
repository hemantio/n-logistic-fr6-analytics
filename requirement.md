# FR6 Analytics Dashboard - Build Requirements

**Document type:** Implementation requirements for an independent, integration-ready FR6 module  
**Project:** N Logistic Import & Export / Logistics Management Platform  
**Functional module:** FR6 - Analytics Dashboard  
**Database:** `n_logistic_db`  
**Document status:** Build specification  

---

## 0. Primary instruction to the AI developer

Build **only FR6 - Analytics Dashboard**, from the ground up, as an independent Java MVC2 module that can later be integrated into the main Logistics Management Platform by another developer.

The supplied Software Requirements Specification (SRS) and the supplied 28-entity Chen ER diagram are the source of truth. Follow their terminology, functional scope, technology stack, table/entity names, and architectural constraints. The user is responsible for FR6 only; do not build the other functional modules.

### Non-negotiable rules

1. **Do not invent requirements, business rules, data, formulas, thresholds, statuses, database fields, tables, roles, or integrations.** If the SRS or ERD does not define something needed for implementation, record it in the `Open Questions / Specification Gaps` section and isolate the affected logic. Do not silently decide it.
2. Do not replace, rename, pluralize, singularize, or redesign an ERD entity or attribute. Preserve the names from the supplied ERD/database script.
3. Do not introduce a different technology stack. Use only the technologies specified in this document and the SRS. Do not add Spring, Spring Boot, Hibernate, JPA, MyBatis, Python, Node.js, FastAPI, Django, Redis, Celery, Quartz, or another framework/service.
4. Do not implement FR1, FR2, FR3, FR4, FR5, or FR7. FR6 may read the data those modules own. FR6 may integrate with FR3 for the FR6.6 pricing-multiplier requirement, but must not create a second pricing subsystem or bypass FR3's pricing rules/audit flow.
5. Do not place SQL or business logic in JSP files.
6. All database access must use JDBC. Use `PreparedStatement` for parameterized SQL. Use JDBC `CallableStatement` only when an approved stored procedure must be called.
7. Enforce role-based access on every Servlet/controller, in accordance with the main application's FR1 authentication/authorization contract. Do not invent session attribute names or new roles.
8. FR6 must be independently testable, but its packages, URL mappings, assets, SQL scripts, and integration points must be isolated and clearly documented.
9. Do not hardcode sample data into production calculations or dashboard pages. Development seed data must be explicitly marked as local/test data.
10. Do not mark a requirement complete unless it is implemented and verified. Do not use mock values as if they were real analytics.

When this document and the SRS/ERD appear to conflict, the SRS/ERD take priority. Document the conflict and request a decision rather than altering the source specification.

---

## 1. Project context and scope

The SRS describes a standalone, browser-based, multi-role web application using a single MySQL database. The business application uses MVC2: Java Servlets are controllers, JSP pages are views, and POJO/DAO classes form the model/data-access layer. Business rules belong in the service/DAO layer and are supported by database views and stored procedures where defined by the project.

FR6 is the Analytics Dashboard module. It consumes approved operational data from the other modules and presents business analytics through the dashboard. It must remain a distinct module so that the integration developer can merge it into the main application without rewriting the FR6 implementation.

### 1.1 Included in this FR6 module

- FR6.1 - Analytics dashboard KPIs.
- FR6.2 - Sales trend analysis.
- FR6.3 - ABC (Pareto) classification.
- FR6.4 - Inventory turnover ratio.
- FR6.5 - Product profitability.
- FR6.6 - Demand forecasting and pricing-multiplier integration.
- FR6.7 - Cached analytics results and refresh.
- FR6.8 - Chart.js visualizations and the specified filters.
- FR6-specific database objects, Java classes, Servlets, JSP views, CSS/JavaScript assets, tests, and integration documentation.

### 1.2 Outside the FR6 implementation scope

- Building or replacing the authentication/user-management module (FR1).
- Building shipment booking or container movement management (FR2).
- Building container allocation or the core pricing engine (FR3).
- Building product/stock management (FR4).
- Building invoice/payment management or processing payments (FR5).
- Building claims management (FR7).
- Physical GPS hardware.
- Online payment gateway processing. The SRS says payments are recorded, not processed.
- Any AI assistant feature under FR3.8 or ML feature under FR3.9, except the demand prediction explicitly required by FR6.6.

FR6 can read the approved data of the above modules. It must not duplicate their ownership of operational records.

---

## 2. Fixed technology stack and runtime

Use this stack. Do not substitute another framework or architecture.

| Layer | Required technology |
|---|---|
| IDE | Eclipse IDE for Enterprise Java and Web Developers |
| Java runtime | JDK 21 in the user's development environment |
| Java compatibility | Follow the SRS requirement of JDK 11 or later; avoid unnecessary language features that would make integration harder |
| Backend | Java Servlets |
| Architecture | MVC2 |
| Database | MySQL on XAMPP |
| Database name | `n_logistic_db` |
| Database access | JDBC |
| Data access pattern | DAO classes |
| Data objects | POJO classes |
| View | JSP and JSTL |
| UI framework | Bootstrap 5 |
| Charts | Chart.js |
| Application server | Apache Tomcat 9 or later; the user's current target is Tomcat 9 |
| Servlet namespace for the current target | `javax.servlet.*` for Tomcat 9; do not use `jakarta.servlet.*` in this Tomcat 9 build |
| SQL access | JDBC `PreparedStatement`; use database views/stored procedures only where supported by the approved database design |

### 2.1 Prohibited technology substitutions

Do not use Spring/Spring Boot, Hibernate, JPA, MyBatis, ORM frameworks, Python services, Node.js services, REST frameworks, Redis, Celery, Quartz, or a separate analytics database. Do not introduce Maven/Gradle or additional third-party libraries unless the project owner explicitly approves them or the existing integrated project already requires them.

The application must run in the user's stated environment: Eclipse, JDK 21, Tomcat 9, and XAMPP. Verify the actual database engine/version bundled with the installed XAMPP before selecting the JDBC driver. Do not assume that every XAMPP installation is running Oracle MySQL rather than MariaDB.

### 2.2 SRS implementation constraints

- Follow MVC2.
- Servlets are controllers.
- JSP/JSTL are views.
- POJO/DAO classes are part of the model/data-access layer.
- No business logic or SQL in JSP.
- All database access through JDBC using `PreparedStatement` for parameterized SQL.
- Business rules must be enforced in the service/DAO layer, not in the view.
- Apply role-based access on every controller/Servlet.

---

## 3. Integration-first project identity and naming

The module is developed separately but will be integrated by another developer. Use the following integration naming conventions consistently.

### 3.1 Project identity

| Item | Required value |
|---|---|
| Eclipse project name | `FR6_Analytics` |
| Java root package | `com.nlogistic.fr6` |
| Database | `n_logistic_db` |
| URL namespace | `/fr6/` |
| JSP view namespace | `/WEB-INF/views/analytics/` |
| CSS namespace | `/assets/css/fr6/` |
| JavaScript namespace | `/assets/js/fr6/` |
| SQL script prefix | `fr6_` |
| Documentation prefix | `FR6_` |

The root package and URL prefix are **module-integration conventions**, not additional business requirements in the SRS. They are chosen to prevent class and Servlet mapping collisions with FR1-FR7.

### 3.2 Java package names

Use these exact packages under `com.nlogistic.fr6`:

- `com.nlogistic.fr6.controller` - Servlet controllers.
- `com.nlogistic.fr6.service` - FR6 business logic and calculations.
- `com.nlogistic.fr6.dao` - JDBC data-access classes.
- `com.nlogistic.fr6.model` - POJO/entity-shaped data objects.
- `com.nlogistic.fr6.dto` - Data-transfer objects for dashboard/view responses and filter inputs.
- `com.nlogistic.fr6.config` - Module configuration and integration interfaces.
- `com.nlogistic.fr6.util` - Shared FR6 utility classes.
- `com.nlogistic.fr6.exception` - FR6-specific exceptions.

Do not place FR6 classes in the default package or in generic packages shared with other modules.

### 3.3 Java class and method naming

Use standard Java naming:

- Classes: `PascalCase`, e.g. `SalesTrendServlet`, `SalesTrendService`, `SalesTrendDAO`, `SalesTrendResult`.
- Methods and variables: `camelCase`, e.g. `getSalesTrendResults()`.
- Constants: `UPPER_SNAKE_CASE`.
- Packages: lowercase.

Use descriptive names. Avoid generic class names such as `Data`, `Process`, `Helper`, or `Manager` unless the responsibility is genuinely general and module-local.

### 3.4 Database naming

Preserve the entity/table and attribute names shown in the ERD and in the final approved database script. Do not rename an ERD entity to a new name merely to match Java naming conventions.

The ERD labels use names such as `Sales_trend_result`, `Abc_classification_result`, and `Inventory_turnover_result`. In SQL, use the spelling/casing established by the approved database script. Java POJO class names may use PascalCase while retaining the exact database column mappings.

### 3.5 Servlet URL namespace

All FR6 Servlet mappings must be under `/fr6/` to avoid collisions. Use clear feature names. Proposed page routes:

- `/fr6/analytics/dashboard`
- `/fr6/analytics/sales-trends`
- `/fr6/analytics/abc-classification`
- `/fr6/analytics/inventory-turnover`
- `/fr6/analytics/profitability`
- `/fr6/analytics/demand-forecast`
- `/fr6/analytics/refresh`

These are module routing conventions. They do not add new business features. If the integrator has a conflicting established route contract, agree the route change before implementation and document it.

---

## 4. Required Eclipse Dynamic Web Project structure

Use the classic Eclipse Dynamic Web Project structure compatible with Tomcat 9. Keep the project self-contained and avoid changing files outside the FR6 namespace.

```text
FR6_Analytics/
│
├── Java Resources/
│   └── src/
│       └── com/nlogistic/fr6/
│           ├── controller/
│           │   ├── AnalyticsDashboardServlet.java
│           │   ├── SalesTrendServlet.java
│           │   ├── AbcClassificationServlet.java
│           │   ├── InventoryTurnoverServlet.java
│           │   ├── ProfitabilityServlet.java
│           │   ├── DemandForecastServlet.java
│           │   └── AnalyticsRefreshServlet.java
│           │
│           ├── service/
│           │   ├── AnalyticsDashboardService.java
│           │   ├── SalesTrendService.java
│           │   ├── AbcClassificationService.java
│           │   ├── InventoryTurnoverService.java
│           │   ├── ProfitabilityService.java
│           │   ├── DemandForecastService.java
│           │   └── AnalyticsRefreshService.java
│           │
│           ├── dao/
│           │   ├── AnalyticsDashboardDAO.java
│           │   ├── SalesTrendDAO.java
│           │   ├── AbcClassificationDAO.java
│           │   ├── InventoryTurnoverDAO.java
│           │   ├── ProfitabilityDAO.java
│           │   └── DemandForecastDAO.java
│           │
│           ├── model/
│           │   ├── AnalyticsKPI.java
│           │   ├── SalesTrendResult.java
│           │   ├── AbcClassificationResult.java
│           │   ├── InventoryTurnoverResult.java
│           │   ├── ProfitabilityResult.java
│           │   └── DemandForecast.java
│           │
│           ├── dto/
│           │   ├── AnalyticsFilterDTO.java
│           │   ├── AnalyticsDashboardDTO.java
│           │   ├── SalesTrendDTO.java
│           │   ├── ProfitabilityDTO.java
│           │   └── ForecastDTO.java
│           │
│           ├── config/
│           │   ├── AnalyticsConnectionProvider.java
│           │   ├── LocalAnalyticsConnectionProvider.java
│           │   └── AnalyticsAccessContext.java
│           │
│           ├── util/
│           │   ├── AnalyticsDateUtil.java
│           │   └── AnalyticsValidationUtil.java
│           │
│           └── exception/
│               ├── AnalyticsException.java
│               └── AnalyticsDataException.java
│
├── WebContent/
│   ├── assets/
│   │   ├── css/fr6/analytics.css
│   │   └── js/fr6/
│   │       ├── analytics-dashboard.js
│   │       ├── sales-trends.js
│   │       ├── abc-classification.js
│   │       ├── inventory-turnover.js
│   │       ├── profitability.js
│   │       └── demand-forecast.js
│   │
│   └── WEB-INF/
│       ├── web.xml
│       ├── lib/                         # Required JDBC driver only
│       └── views/analytics/
│           ├── dashboard.jsp
│           ├── sales-trends.jsp
│           ├── abc-classification.jsp
│           ├── inventory-turnover.jsp
│           ├── profitability.jsp
│           └── demand-forecast.jsp
│
├── database/
│   ├── fr6_schema.sql
│   ├── fr6_indexes.sql
│   └── fr6_dev_seed.sql                # Local/test data only
│
├── docs/
│   ├── FR6_API_DOCUMENTATION.md
│   ├── FR6_DATABASE_DOCUMENTATION.md
│   ├── FR6_INTEGRATION_GUIDE.md
│   └── FR6_DEPENDENCIES.md
│
└── README.md
```

If the Eclipse version generates a different standard web root, such as `src/main/webapp`, use one layout consistently. Do not create both `WebContent` and `src/main/webapp` in the same project.

### 4.1 Responsibilities by layer

**Controller / Servlet**
- Receive and validate HTTP request parameters.
- Obtain the authenticated user's approved access context.
- Check role/company authorization on every controller.
- Call the appropriate service.
- Set request attributes or return the data required by Chart.js.
- Forward to a JSP view or return a response for the chart data request.
- Do not contain SQL or substantial business calculations.

**Service**
- Enforce FR6 business rules.
- Coordinate DAOs.
- Perform approved calculations.
- Apply the required date/route/company filters.
- Handle refresh orchestration.
- Keep formula/threshold/forecast policies in a single clear location.

**DAO**
- Contain JDBC SQL and stored-procedure calls approved for the project.
- Use `PreparedStatement` for parameterized queries.
- Map result sets to POJOs/DTOs.
- Do not put SQL in JSPs or Servlets.
- Use the shared connection provider contract; do not create unrelated connection implementations in every DAO.

**Model / POJO**
- Represent data using clear fields, constructors, getters and setters.
- Map the actual ERD/database column names.
- Do not contain Servlet or JSP dependencies.

**DTO**
- Carry filtered dashboard data from service/controller to the view.
- Do not silently change source database values or business meaning.

**JSP/JSTL**
- Render the data supplied by the controller.
- Use Bootstrap 5 and Chart.js.
- Contain presentation logic only; no JDBC, SQL, or business calculations.

---

## 5. FR6 functional requirements

Implement the requirements below without expanding their business scope. The IDs must remain identifiable in class comments, documentation, and tests.

### FR6.1 - Analytics Dashboard KPIs

The dashboard shall show the KPIs specified by the SRS:

- Active shipments.
- Containers available.
- Revenue.
- Pending invoices.
- Open claims.

Data must be obtained from the corresponding operational records in the shared database. Use existing shipment, container, invoice/payment, and claim data. Do not add hardcoded KPI values.

**Definitions that must not be guessed:** The SRS does not fully define the exact status mapping for “active shipment” or “open claim”, whether “pending invoices” is shown as a count or monetary balance, or the exact meaning of “containers available” beyond the FR3 availability rule. Reuse the project's approved statuses and confirm any missing display/calculation semantics with the integrator/project owner.

### FR6.2 - Sales Trend Analysis

Provide sales trend analysis showing revenue and volume over time by:

- Route.
- Product.
- Customer.

Use the operational sales/shipment/invoice data and the `Sales_trend_result` analytics entity shown in the ERD where applicable. The ERD's `Sales_trend_result` currently shows route/month fields: `result_id`, `period_month`, `origin_port_id`, `dest_port_id`, `total_sales`, `total_qty`, and `growth_pct`.

Do not change this table to add product/customer dimensions without explicit approval. If the required product/customer breakdown can be calculated from existing operational data without changing the ERD, do so. If persistence of those additional dimensions requires a schema change, document the gap and request approval first.

### FR6.3 - ABC (Pareto) Classification

Classify products/customers into A, B, and C categories by contribution, as stated in the SRS.

The ERD currently shows `Abc_classification_result` with these attributes:

- `result_id`
- `product_id`
- `annual_value`
- `cumulative_pct`
- `abc_class`
- `calculated_on`

**Specification gap:** The ERD only shows `product_id`; it does not show a customer identifier or entity-type field for customer ABC results. Do not add a customer column, generic entity column, or a second table without approval. Record this discrepancy and ask whether customer classification is required in the database design or can be calculated without persisting it.

**Threshold gap:** The SRS/ERD supplied here do not specify the A/B/C percentage thresholds. Do not assume standard 80/15/5 thresholds. Obtain the approved thresholds and classification policy before implementing final classification results. Keep that policy isolated in one service/configuration point.

### FR6.4 - Inventory Turnover Ratio

Calculate and present the inventory turnover ratio per product and period.

The ERD shows `Inventory_turnover_result` with:

- `result_id`
- `product_id`
- `period_start`
- `period_end`
- `cogs`
- `avg_inventory`
- `turnover_ratio`

Use the approved inventory/stock ledger records as the source of calculation. The ERD's fields indicate that cost of goods sold and average inventory are stored, but do not invent additional fields or alternate definitions. Confirm the approved treatment of average inventory, stock adjustments, damaged stock, and periods if not defined in the complete database script/SRS.

### FR6.5 - Product Profitability

Provide product profitability/margin analysis per product/shipment as specified by the SRS.

The ERD contains two relevant entities:

1. `Profitability_result`, with `result_id`, `product_id`, `period_month`, `revenue`, `cost`, and `margin_pct`.
2. `Profit_loss`, with shipment/seller and cost fields, including `shipment_id`, `seller_id`, `period_month`, `revenue`, `freight_cost`, `port_cost`, `handling_cost`, `claim_loss`, and `net_profit`.

Keep these entities distinct. Do not rename one to the other or create a duplicate table.

The SRS's FR2.8 financial rule states that revenue comes from paid invoices; costs come from freight, port, handling and settled claims; claim payouts reduce profit (see FR7.6). Apply this source rule when calculating the relevant P&L values.

**Formula/allocation gap:** The SRS/ERD supplied here do not fully define product-level cost allocation or every margin calculation rule. Do not invent a weight-, volume-, revenue-, or equal-allocation method. Obtain the approved method. Keep calculations centralized in the service layer and document the exact source fields used.

Coordinate with the FR2 developer so the Seller P&L graph under FR2.7 is not reimplemented as a conflicting second business feature. Reuse agreed P&L data where appropriate.

### FR6.6 - Demand Forecasting

Predict demand for routes/container types and update the pricing multiplier as specified by FR6.6.

The ERD shows `Demand_forecast` with:

- `forecast_id`
- `origin_port_id`
- `dest_port_id`
- `container_type`
- `forecast_month`
- `predicted_bookings`
- `confidence_pct`
- `suggested_multiplier`

Use the existing route/port, container, shipment/booking, and pricing data. Preserve the `Demand_forecast` entity and its ERD attributes.

**Forecast-policy gap:** The SRS/ERD supplied here do not specify a forecasting algorithm, history window, forecast horizon, confidence calculation, or model-accuracy acceptance threshold. Do not silently select a moving average, exponential smoothing, regression, machine-learning model, or arbitrary confidence percentage. Ask for the approved method. Keep the forecasting algorithm behind a clearly named service/strategy boundary so it can be implemented when the method is confirmed.

**Pricing integration:** FR6 must not create a second pricing engine or write around FR3's pricing rules and audit process. Integrate through the FR3-approved pricing mechanism. The ERD contains `Pricing_rules` and `Pricing_audit`; preserve their ownership and structure. Coordinate with the FR3 developer on how the approved `suggested_multiplier` becomes the active demand multiplier and how the pricing audit is recorded. Do not invent an approval workflow if the full SRS/FR3 contract does not require one.

### FR6.7 - Cached Analytics Results

Results shall be stored in cached analytics tables and refreshed on demand or on schedule, as specified by the SRS.

Use the analytics result entities already shown in the ERD where they correspond to calculated results:

- `Sales_trend_result`
- `Abc_classification_result`
- `Inventory_turnover_result`
- `Profitability_result`
- `Demand_forecast`
- `Profit_loss` (where this is the agreed shared P&L result entity)

Do not add tables such as `analytics_kpi_cache`, `analytics_refresh_log`, or other cache entities unless the project owner approves the schema extension. The supplied ERD does not show a dedicated KPI-cache or refresh-history entity. Document any requirement that cannot be satisfied by the existing structures and request approval before changing the ERD.

Implement refresh orchestration in the FR6 service layer. Support on-demand refresh. Support scheduled refresh only with an approved schedule/interval; do not invent a refresh frequency. Refresh must not create duplicate result rows for the same logical result/period. Use transactions and the approved uniqueness rules once the final schema is confirmed.

### FR6.8 - Charts and Filters

Render analytics charts using **Chart.js**. The SRS specifies:

- Line charts.
- Bar charts.
- Pie charts.

The data shall be filterable by:

- Date.
- Route.
- Company.

Apply the filters on the server/database side; do not merely alter chart labels in JavaScript. Preserve company-level access restrictions on every request. Use Bootstrap 5 for the module UI.

Do not introduce another charting library.

---

## 6. ERD entity reference and FR6 data dependencies

The supplied ERD is titled `n_logistic_db - Unified Chen Entity-Relationship Diagram (28 Entities)`. It shows the following 28 entities. Preserve their names and existing relationships from the approved database script:

1. `Audit_log`
2. `Users`
3. `Companies`
4. `Vessels`
5. `Customers`
6. `Pricing_audit`
7. `Pricing_rules`
8. `Demand_forecast`
9. `Ports`
10. `Sales_trend_result`
11. `Containers`
12. `Profit_loss`
13. `Container_movements`
14. `Shipments`
15. `Billing_invoices`
16. `Claims`
17. `Stock`
18. `Shipment_items`
19. `Invoice_line_items`
20. `Payments`
21. `Claim_documents`
22. `Claim_status_history`
23. `Inventory_ledger`
24. `Products`
25. `Sales_transactions`
26. `Abc_classification_result`
27. `Inventory_turnover_result`
28. `Profitability_result`

### 6.1 FR6 analytical entities and visible attributes in the ERD

Use the actual supplied ERD/database script as the authoritative definition. The following are the attributes legible in the supplied ERD image and are included here as a mapping aid, not as permission to modify them.

**`Sales_trend_result`**
- `result_id` (PK)
- `period_month`
- `origin_port_id` (FK)
- `dest_port_id` (FK)
- `total_sales`
- `total_qty`
- `growth_pct`

**`Abc_classification_result`**
- `result_id` (PK)
- `product_id` (FK)
- `annual_value`
- `cumulative_pct`
- `abc_class`
- `calculated_on`

**`Inventory_turnover_result`**
- `result_id` (PK)
- `product_id` (FK)
- `period_start`
- `period_end`
- `cogs`
- `avg_inventory`
- `turnover_ratio`

**`Profitability_result`**
- `result_id` (PK)
- `product_id` (FK)
- `period_month`
- `revenue`
- `cost`
- `margin_pct`

**`Demand_forecast`**
- `forecast_id` (PK)
- `origin_port_id` (FK)
- `dest_port_id` (FK)
- `container_type`
- `forecast_month`
- `predicted_bookings`
- `confidence_pct`
- `suggested_multiplier`

**`Profit_loss`**
- `pl_id` (PK)
- `shipment_id` (FK)
- `seller_id` (FK)
- `period_month`
- `revenue`
- `freight_cost`
- `port_cost`
- `handling_cost`
- `claim_loss`
- `net_profit`

### 6.2 Operational source entities

Likely source entities for FR6 include:

- `Shipments`, `Container_movements`, `Containers`, and `Ports` for shipment activity, route and container availability.
- `Billing_invoices`, `Invoice_line_items`, and `Payments` for invoice/payment-derived revenue and pending invoice information.
- `Products`, `Sales_transactions`, `Shipment_items`, `Stock`, and `Inventory_ledger` for product, sales and inventory analysis.
- `Claims` and claim settlement information for settled claim costs and open claim KPIs.
- `Companies`, `Users`, and the main application's authorization context for company isolation and role enforcement.
- `Pricing_rules` and `Pricing_audit` for the FR6.6 pricing-multiplier integration.

These source entities are owned by their respective functional modules. FR6 must read them and must not take over their CRUD responsibilities.

---

## 7. Database ownership and SQL deliverables

The main project uses one shared database: `n_logistic_db`.

### 7.1 Ownership boundary

- FR6 owns its analytics calculations, FR6 Java classes, FR6 JSP/assets, FR6-specific SQL changes, and FR6 documentation.
- Other modules own their operational tables and business workflows.
- The integration developer owns the final combined database build script and final shared application configuration.
- FR6 must not drop, rename, truncate, or change the structure of another module's operational tables.

### 7.2 SQL files to deliver

Create only additive, FR6-specific scripts:

- `database/fr6_schema.sql` - creates the FR6-owned analytics result entities only if they do not already exist in the approved shared schema.
- `database/fr6_indexes.sql` - contains only approved FR6-related indexes and must not duplicate existing indexes.
- `database/fr6_dev_seed.sql` - local/test records only; never used as production data.

Do not recreate all 28 entities inside the FR6 integration script. Do not issue `DROP DATABASE`, `DROP TABLE`, destructive migrations, or destructive seed scripts.

If the full shared database is not yet available for independent development, a separate local test fixture may be created under a clearly named `database/dev_only/` directory. It must use the exact approved ERD table/column names, be clearly marked as local-only, and must never be included in the FR6 integration migration. Do not present fixture tables as FR6-owned production tables.

### 7.3 Database implementation constraints

- Use JDBC.
- Use `PreparedStatement` for parameterized SQL.
- Use transactions when a refresh or multi-step write must succeed/fail as one operation.
- Close `Connection`, `PreparedStatement`, and `ResultSet` reliably (prefer try-with-resources).
- Do not concatenate user input into SQL.
- Do not use ORM/JPA/Hibernate.
- Preserve ERD primary keys, foreign keys, nullability and unique constraints from the approved schema.
- Do not infer missing column types, lengths, precision, defaults, or foreign keys from the diagram alone; use the actual database script or seek confirmation.

---

## 8. Connection and authentication integration boundaries

FR6 is developed independently, so it needs explicit seams for the main application's shared services.

### 8.1 Database connection provider

Create a small FR6 connection-provider interface so DAO classes do not depend on hardcoded local credentials. For local development, provide a local implementation that reads its settings from external local configuration. The integration developer must be able to substitute the main application's shared DB connection provider without rewriting FR6 DAOs.

Do not commit real database passwords or use an assumed blank root password. Do not create an independent connection manager in every DAO.

### 8.2 Authentication and company context

FR1 owns authentication and user/access management. FR6 must integrate with the main application's authenticated session/authorization context.

Create a clearly documented FR6 access-context adapter/interface if necessary. Do not invent the names of session attributes, role codes, user identifiers, or company identifiers. Obtain those names and semantics from the FR1/integration developer.

During local-only development, any mock access context must be explicitly marked as development-only and must be impossible to enable accidentally in the integrated/production deployment.

### 8.3 Role-based access

Every FR6 Servlet/controller must enforce the approved role permissions. Do not assume that hiding a link in JSP is sufficient. Consumers, Sellers, and Admins are the user classes named by the SRS; do not create additional roles. The specific FR6 permissions must match the agreed main-application authorization matrix.

### 8.4 Company-level access

The FR6.8 company filter must not allow a user to read another company's analytics by changing a query parameter. The server must derive or validate company access from the authenticated context supplied by FR1. A company filter may narrow the permitted data only; it must never widen a user's authorization.

---

## 9. Frontend and Chart.js integration

The UI must use JSP/JSTL, Bootstrap 5, and Chart.js only, as specified in the SRS.

Create the following FR6 pages:

- `dashboard.jsp` - FR6.1 KPI overview and dashboard entry point.
- `sales-trends.jsp` - FR6.2 sales trend analysis.
- `abc-classification.jsp` - FR6.3 ABC classification.
- `inventory-turnover.jsp` - FR6.4 turnover analysis.
- `profitability.jsp` - FR6.5 profitability.
- `demand-forecast.jsp` - FR6.6 demand forecast.

All JSP pages must be under `WEB-INF/views/analytics/` and must be reached through a Servlet/controller. Do not expose JSPs as direct public entry points.

### 9.1 Chart requirements

Use Chart.js for the SRS chart types:

- Line chart.
- Bar chart.
- Pie chart.

Do not create extra chart categories as mandatory requirements unless approved. Use server-calculated values and the filters defined by FR6.8. Keep chart configuration/data-building code in the FR6 JavaScript files, not in DAO classes.

### 9.2 Filters

Implement the FR6.8 filters:

- Date.
- Route.
- Company.

Validate filters server-side. Use date formats and route/company identifiers consistent with the shared schema. Do not assume date-period rules that are not defined by the SRS.

FR6.2 must support the analysis dimensions (route, product, customer) stated in its requirement. Do not create extra global filters unless required by the approved design.

### 9.3 JSP rules

- No SQL in JSP.
- No JDBC connections in JSP.
- No business calculations in JSP.
- Use JSTL/EL to render controller-provided data.
- Escape displayed data appropriately.
- Keep assets under the FR6-specific asset directories.

---

## 10. Refresh and cache implementation

FR6.7 requires cached analytics results and refresh on demand or on schedule.

- Reuse the ERD's analytics result entities where applicable.
- Put refresh orchestration in `AnalyticsRefreshService`.
- Expose a Servlet/controller under the `/fr6/` namespace for authorized on-demand refresh.
- Ensure one refresh does not leave partly updated analytics results.
- Use transaction boundaries for related writes.
- Prevent duplicate logical results for the same entity/period according to the approved keys/constraints.
- Record refresh errors in application logs using standard Java logging unless the main project already provides an approved logging mechanism.
- Scheduled refresh may be enabled only after the project owner/integrator defines its schedule. Do not invent a frequency or introduce an external scheduling technology.
- Do not add cache/refresh tables that are absent from the ERD without approval.

---

## 11. Open Questions / Specification Gaps - do not guess

The AI developer must maintain this section as a checklist. Resolve each point with the SRS owner, project guide, or relevant module developer before implementing the affected final business behavior.

| ID | Gap or potential mismatch | Required action |
|---|---|---|
| GAP-01 | The SRS describes ABC classification for products/customers, but the ERD's `Abc_classification_result` shows only `product_id`. | Ask whether customer ABC must be persisted and whether the ERD/schema should be extended. Do not add fields/tables without approval. |
| GAP-02 | ABC A/B/C contribution thresholds are not stated in the supplied SRS/ERD. | Obtain the agreed thresholds and classification policy. Do not assume 80/15/5. |
| GAP-03 | The exact calculation basis for ABC contribution is not fully defined. | Confirm whether the approved basis is revenue, annual value, profit, or another specified measure. The ERD includes `annual_value`, but do not infer additional semantics beyond approval. |
| GAP-04 | The exact KPI definitions for active shipments, available containers, pending invoices, and open claims are not completely specified. | Confirm status mapping and whether invoice/claim KPIs are counts, balances, or another representation. |
| GAP-05 | The forecast algorithm, historical lookback, forecast horizon, confidence calculation and validation target are not specified. | Obtain the approved forecasting method and parameters. Do not invent a model or confidence score. |
| GAP-06 | The route/container forecast's suggested multiplier must interact with FR3 pricing. | Obtain the FR3 service/API/DAO integration contract and confirm how `Pricing_rules` and `Pricing_audit` are updated. Do not bypass FR3. |
| GAP-07 | Product-level cost allocation for profitability is not specified. | Obtain the approved cost allocation method. Do not invent a weight, volume, revenue, or equal allocation. |
| GAP-08 | The precise definition of `margin_pct` is not explicitly stated in the supplied extract. | Confirm the formula and treatment of zero revenue, refunds, reversals, taxes and claim loss where applicable. |
| GAP-09 | The FR6.5 wording refers to product/shipment profitability, while `Profitability_result` is product-linked and `Profit_loss` is shipment-linked. | Use the two ERD entities for their corresponding levels and confirm the expected display/ownership with the integrator. Do not merge or rename them. |
| GAP-10 | `Sales_trend_result` in the ERD stores month and route identifiers but has no product/customer dimension columns. | Calculate product/customer trends from approved operational source data if possible; request approval before changing the result table schema. |
| GAP-11 | The ERD does not show a dedicated KPI cache or refresh-history table. | Determine whether existing analytics result tables satisfy FR6.7 or whether an approved schema extension is needed. Do not create unapproved tables. |
| GAP-12 | The scheduled cache refresh interval is not specified. | Ask for the intended schedule. Do not select an arbitrary daily/hourly interval. |
| GAP-13 | FR1 session attribute names, role codes, and company access contract are not included in the supplied extract. | Obtain the integration contract from the FR1/integration developer. Do not invent session keys or role strings. |
| GAP-14 | Exact MySQL/MariaDB engine version, JDBC driver version, and local credentials depend on the installed XAMPP environment. | Verify on the user's machine and configure externally; do not assume root has a blank password. |
| GAP-15 | The full database SQL script is referenced in the SRS, but only the ER diagram is supplied here. | Inspect the approved database script before finalizing SQL column types, nullability, lengths, defaults, constraints and indexes. |

The AI developer may continue with unaffected foundation work while these items are pending. For a feature blocked by a gap, implement the data-access scaffolding and clearly marked TODO/strategy boundary, but do not return fabricated business results or claim the requirement is complete.

---

## 12. Development sequence

Build in this order. Do not jump straight to charts or forecasting.

### Phase 1 - Environment and project foundation

1. Verify JDK 21 in Windows and Eclipse.
2. Configure Tomcat 9 in Eclipse.
3. Start XAMPP's database service and verify the actual engine/version/port.
4. Confirm `n_logistic_db` exists or create it only if it does not exist; never drop/recreate an existing database.
5. Create the Eclipse Dynamic Web Project `FR6_Analytics`.
6. Set up the `com.nlogistic.fr6` packages and isolated web folders.
7. Add the compatible JDBC driver under `WEB-INF/lib`.
8. Implement a temporary JDBC connection verification and a temporary Servlet test.
9. Verify the application deploys and the Servlet can connect to `n_logistic_db`.
10. Remove or restrict temporary diagnostics before handover.

**Phase 1 exit condition:** Eclipse, JDK 21, Tomcat 9, XAMPP database, FR6 web project, and JDBC connection are verified.

### Phase 2 - Database mapping and FR6 schema

1. Inspect the full approved ERD and database script.
2. Map every FR6 calculation to exact source entities/columns.
3. Confirm FR6-owned analytics entities and their exact attributes.
4. Confirm the open questions that affect schema/calculations.
5. Create only approved additive FR6 SQL scripts.
6. Create local-only fixture records as necessary for independent testing.

**Phase 2 exit condition:** Exact source-to-analytics mapping and non-destructive FR6 SQL scripts are documented and verified.

### Phase 3 - Java MVC2 foundation

1. Create POJOs from the approved FR6 entities.
2. Create the connection-provider interface and local implementation.
3. Create DAO classes with JDBC `PreparedStatement`.
4. Create Service classes for FR6 calculations.
5. Create DTOs for dashboard/view output.
6. Create Servlet controllers and `/fr6/` route mappings.
7. Add the FR1 authentication/access-context integration boundary.
8. Verify role checking on each controller.

**Phase 3 exit condition:** The module has a working MVC2 foundation and can retrieve authorized source records.

### Phase 4 - Analytics calculations

Implement and test, in order:

1. FR6.1 KPIs.
2. FR6.2 Sales trend analysis.
3. FR6.3 ABC classification after the threshold/customer scope is confirmed.
4. FR6.4 Inventory turnover.
5. FR6.5 Product and shipment profitability after the required formula/allocation rules are confirmed.
6. FR6.6 Demand forecasting and FR3 multiplier integration after the forecast/integration rules are confirmed.

**Phase 4 exit condition:** Each calculation uses real database data, follows an approved definition, and has reproducible tests.

### Phase 5 - Cached results and refresh

1. Reuse the approved analytics result tables.
2. Implement on-demand refresh.
3. Implement scheduled refresh only after the schedule is specified.
4. Make refresh transactional and safe against duplicate logical result rows.
5. Verify cached results match direct calculations.

**Phase 5 exit condition:** FR6.7 refresh behavior works and can be verified without destructive updates.

### Phase 6 - JSP, Bootstrap 5 and Chart.js

1. Create the JSP pages under `WEB-INF/views/analytics/`.
2. Create FR6-specific Bootstrap 5 styling.
3. Render the five dashboard KPIs.
4. Implement line, bar and pie charts as appropriate to the specified analytics.
5. Implement date, route and company filters.
6. Connect all views to real Servlet/service data.
7. Verify chart data changes when server-side filters change.

**Phase 6 exit condition:** All required dashboard views and charts display real, filtered FR6 data.

### Phase 7 - Final validation and integration handover

1. Run all FR6 tests.
2. Verify the business calculations against independently calculated expected values.
3. Verify role and company isolation.
4. Verify all SQL uses JDBC parameterization.
5. Verify JSPs contain no SQL/business logic.
6. Verify Tomcat 9 deployment.
7. Verify no FR6 route/package/asset collisions.
8. Prepare the integration guide and FR6-specific SQL scripts.
9. Export the module source/project archive for the integrator.

**Final exit condition:** The FR6 module runs independently, has no unapproved business assumptions, and is accompanied by enough SQL, documentation, and integration information for another developer to merge it.

---

## 13. Testing and acceptance requirements

Do not use hardcoded dashboard data as a substitute for database integration. Development fixtures may be used only for repeatable local tests and must be clearly marked.

### 13.1 Required verification

- Java project compiles using the configured JDK.
- Project deploys on Tomcat 9.
- JDBC connection works against `n_logistic_db`.
- Every DAO uses parameterized JDBC access.
- Each Service calculation is independently testable.
- Each Servlet enforces the approved role/company authorization.
- Date, route, and company filters are validated on the server.
- The dashboard KPIs are derived from the approved operational data.
- Sales trends use the correct period and dimensions.
- ABC classifications use the approved thresholds and contribution basis.
- Inventory turnover uses the approved COGS/average inventory data and period.
- Profitability applies the approved revenue, cost, and allocation rules.
- Demand forecasts use the approved forecasting method and integrate with FR3 through its approved pricing flow.
- Cached results can be refreshed and match their underlying calculation results.
- Chart.js displays the required line, bar, and pie chart types.
- No SQL or business logic is present in JSP files.
- No unauthorized new operational tables, fields, roles, URLs, or dependencies are introduced.

### 13.2 Error handling

- Do not expose database credentials, SQL statements, stack traces, or internal exception details to browser users.
- Log technical details on the server.
- Return or render a clear user-facing error state when analytics cannot be loaded.
- Do not convert failed queries into zero-valued analytics unless zero is a valid result from the data.
- Handle empty data periods explicitly; do not display invented values.

### 13.3 Local development data

If sample records are needed, create them in a clearly marked local/test SQL script. Use the ERD names and relationships. Never mix sample records into production or integration scripts. The dashboard must clearly distinguish a local test environment from real operational data.

---

## 14. Integration handover package

At completion, deliver the following to the main-project integrator:

1. **FR6 Java source** - all packages under `com.nlogistic.fr6`.
2. **FR6 JSP views** - under `WEB-INF/views/analytics/`.
3. **FR6 assets** - CSS/JavaScript under the FR6 asset folders.
4. **FR6 SQL scripts** - additive, non-destructive and clearly marked.
5. **JDBC driver details** - exact tested driver name/version and database engine tested.
6. **API/Servlet route documentation** - every FR6 route, method, role requirement, inputs, outputs and view/JSON behavior.
7. **Database dependency map** - each source table/column read and each FR6-owned table written.
8. **Authentication integration contract** - required session/access-context values supplied by FR1; no invented names.
9. **FR3 pricing integration contract** - exact approved mechanism used for multiplier updates and audit.
10. **Setup README** - Eclipse, JDK, Tomcat, XAMPP, JDBC driver and run instructions.
11. **Test guide** - test data, steps, expected results and unresolved specification gaps.
12. **Open questions list** - all unresolved items and the decisions required before final production behavior.

### 14.1 Integration rules

- Do not replace the main application's `web.xml`; provide only the FR6 Servlet mappings or annotation-based configuration to be merged.
- Do not replace the main application's database connection utility; use the agreed connection-provider integration point.
- Do not add global CSS names that can affect other modules. Prefix FR6-specific selectors with `fr6-` or scope them under an FR6 root container.
- Do not add generic JavaScript global variables that can collide with other modules. Keep FR6 scripts namespaced or module-scoped.
- Do not use generic Servlet URL paths. Keep the `/fr6/` prefix.
- Do not create duplicate copies of operational tables owned by other modules.
- Do not modify another module's classes or SQL scripts.
- Document any shared dependency before integration.

---

## 15. Required final response from the AI developer

When the implementation is complete, provide a factual completion report containing:

1. What was built for each FR6.1-FR6.8 requirement.
2. Exact files/packages created.
3. Exact SQL tables/scripts created or modified.
4. Exact Servlet routes implemented.
5. Exact external/shared module dependencies.
6. Build and deployment commands/steps for Eclipse and Tomcat 9.
7. Test cases executed and their actual outcomes.
8. Known limitations and unresolved specification gaps.
9. Integration instructions for the main-project developer.

Do not say “complete”, “working”, or “tested” for functionality that has only been scaffolded or mocked.

---

## 16. Source-of-truth summary

Use these supplied project materials as the authority:

- SRS: Section 1.3 - Definitions, Acronyms and Abbreviations.
- SRS: Section 1.5 - Document Overview.
- SRS: Section 2.1 - Product Perspective.
- SRS: Section 2.4 - Operating Environment.
- SRS: Section 2.5 - Design and Implementation Constraints.
- SRS: Section 2.6 - Technology Stack.
- SRS: Section 3.6 - Analytics Dashboard (FR6.1-FR6.8).
- Related SRS requirements where FR6 depends on them, especially FR2.8, FR3 pricing requirements, FR4 inventory records, FR5 invoices/payments, and FR7 claim settlement.
- Supplied `n_logistic_db` Unified Chen ERD showing 28 entities.

The SRS and ERD define the required product. This document organizes those requirements into an integration-ready build plan; it does not authorize the AI developer to invent additional business functionality or alter the source design.

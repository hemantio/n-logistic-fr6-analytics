# FR6 Analytics Dashboard - Integration Guide

**Module:** FR6 - Analytics Dashboard  
**Host Platform:** N Logistic Import & Export / Logistics Management Platform  
**Target Database:** `n_logistic_db`  
**Architecture:** Java MVC2 (Servlets, JSP/JSTL, DAO/JDBC, Bootstrap 5, Chart.js)  

---

## 1. Overview for the Platform Integrator

FR6 was designed from the ground up for seamless, drop-in integration into the main Logistics Management Platform. All classes, servlets, views, assets, and database scripts strictly adhere to the project conventions:

- Root Package: `com.nlogistic.fr6.*`
- Web Views: `WEB-INF/views/analytics/*`
- URL Namespace: `/fr6/analytics/*`
- CSS Namespace: `/assets/css/fr6/*` with all custom selectors prefixed `.fr6-`
- JavaScript Namespace: `/assets/js/fr6/*` with global objects scoped to `FR6Analytics`, `FR6SalesTrends`, etc.
- SQL Scripts: Additive, non-destructive scripts prefixed `fr6_`

---

## 2. Step-by-Step Integration Procedure

### Step 1: Copy Java Packages
Copy the `com.nlogistic.fr6` package hierarchy into your main project's `src/` or `src/main/java/` directory:
```
src/
└── com/nlogistic/fr6/
    ├── config/
    ├── controller/
    ├── dao/
    ├── dto/
    ├── exception/
    ├── model/
    ├── service/
    └── util/
```

### Step 2: Copy JSP Views & Static Assets
1. Copy `WebContent/WEB-INF/views/analytics/` into your main webapp directory under `WEB-INF/views/analytics/`.
2. Copy `WebContent/assets/css/fr6/` to `assets/css/fr6/`.
3. Copy `WebContent/assets/js/fr6/` to `assets/js/fr6/`.

### Step 3: Execute Additive SQL Scripts
Run the two additive FR6 SQL scripts on your shared `n_logistic_db` database:
1. `database/fr6_schema.sql` - Creates the 6 FR6 analytics tables if they do not already exist.
2. `database/fr6_indexes.sql` - Adds performance indexes on period, product, and route fields.

*(Note: Do NOT execute `database/dev_only/*` scripts on production. Those are strictly standalone test fixtures).*

### Step 4: Merge `web.xml` Servlet Mappings
Append the FR6 Servlet declarations and mappings from `FR6_Analytics/WebContent/WEB-INF/web.xml` into your main application's `web.xml`:
```xml
<!-- FR6.1 Dashboard -->
<servlet>
    <servlet-name>AnalyticsDashboardServlet</servlet-name>
    <servlet-class>com.nlogistic.fr6.controller.AnalyticsDashboardServlet</servlet-class>
</servlet>
<servlet-mapping>
    <servlet-name>AnalyticsDashboardServlet</servlet-name>
    <url-pattern>/fr6/analytics/dashboard</url-pattern>
</servlet-mapping>

<!-- FR6.2 Sales Trends -->
<servlet>
    <servlet-name>SalesTrendServlet</servlet-name>
    <servlet-class>com.nlogistic.fr6.controller.SalesTrendServlet</servlet-class>
</servlet>
<servlet-mapping>
    <servlet-name>SalesTrendServlet</servlet-name>
    <url-pattern>/fr6/analytics/sales-trends</url-pattern>
</servlet-mapping>

<!-- FR6.3 ABC Classification -->
<servlet>
    <servlet-name>AbcClassificationServlet</servlet-name>
    <servlet-class>com.nlogistic.fr6.controller.AbcClassificationServlet</servlet-class>
</servlet>
<servlet-mapping>
    <servlet-name>AbcClassificationServlet</servlet-name>
    <url-pattern>/fr6/analytics/abc-classification</url-pattern>
</servlet-mapping>

<!-- FR6.4 Inventory Turnover -->
<servlet>
    <servlet-name>InventoryTurnoverServlet</servlet-name>
    <servlet-class>com.nlogistic.fr6.controller.InventoryTurnoverServlet</servlet-class>
</servlet>
<servlet-mapping>
    <servlet-name>InventoryTurnoverServlet</servlet-name>
    <url-pattern>/fr6/analytics/inventory-turnover</url-pattern>
</servlet-mapping>

<!-- FR6.5 Profitability -->
<servlet>
    <servlet-name>ProfitabilityServlet</servlet-name>
    <servlet-class>com.nlogistic.fr6.controller.ProfitabilityServlet</servlet-class>
</servlet>
<servlet-mapping>
    <servlet-name>ProfitabilityServlet</servlet-name>
    <url-pattern>/fr6/analytics/profitability</url-pattern>
</servlet-mapping>

<!-- FR6.6 Demand Forecasting -->
<servlet>
    <servlet-name>DemandForecastServlet</servlet-name>
    <servlet-class>com.nlogistic.fr6.controller.DemandForecastServlet</servlet-class>
</servlet>
<servlet-mapping>
    <servlet-name>DemandForecastServlet</servlet-name>
    <url-pattern>/fr6/analytics/demand-forecast</url-pattern>
</servlet-mapping>

<!-- FR6.7 Refresh Cache -->
<servlet>
    <servlet-name>AnalyticsRefreshServlet</servlet-name>
    <servlet-class>com.nlogistic.fr6.controller.AnalyticsRefreshServlet</servlet-class>
</servlet>
<servlet-mapping>
    <servlet-name>AnalyticsRefreshServlet</servlet-name>
    <url-pattern>/fr6/analytics/refresh</url-pattern>
</servlet-mapping>
```

---

## 3. Connecting to the Platform's Shared Connection Pool

FR6 provides an explicit seam via `AnalyticsConnectionProvider`. If your main application manages a connection pool (e.g., Apache Commons DBCP, HikariCP, or a JNDI DataSource), plug it in with a single line during application startup (e.g. in a `ServletContextListener`):

```java
import com.nlogistic.fr6.config.AnalyticsConnectionProvider;
import java.sql.Connection;
import java.sql.SQLException;

public class AppStartupListener implements ServletContextListener {
    @Override
    public void contextInitialized(ServletContextEvent sce) {
        AnalyticsConnectionProvider.setInstance(new AnalyticsConnectionProvider() {
            @Override
            public Connection getConnection() throws SQLException {
                return MainPlatformDataSource.getConnection();
            }
        });
    }
}
```

No changes to any FR6 DAO or Service classes are needed.

---

## 4. FR1 Authentication & Session Context Contract

FR6 controllers read the user's authenticated context via `AnalyticsAccessContext.fromRequest(request)`. The following session attributes are read:

| Session Attribute Key | Type | Description |
|---|---|---|
| `userRole` (or `role`) | `String` | Role code: `ADMIN`, `SELLER`, or `CONSUMER` |
| `userId` (or `user_id`) | `Integer` | Primary key in `users` table |
| `companyId` (or `company_id`) | `Integer` | Assigned company in `companies` table |
| `userName` | `String` | Display name of the user |

### Company-Level Isolation Enforcement:
- If `userRole == "ADMIN"`, the user may view all data or filter by any specific `companyId`.
- If `userRole == "SELLER"` or `"CONSUMER"`, FR6 strictly restricts all queries to their authenticated `companyId`, completely ignoring any `companyId` passed in HTTP query parameters.

---

## 5. FR3 Pricing Integration Seam

In FR6.6, applying a suggested demand multiplier modifies `pricing_rules.demand_multiplier` and creates an entry in `pricing_audit`:
- **Table modified:** `pricing_rules` (`UPDATE pricing_rules SET demand_multiplier = ? WHERE rule_id = ?`)
- **Audit logged:** `pricing_audit` (`INSERT INTO pricing_audit (rule_id, old_rate, new_rate, old_multiplier, new_multiplier, changed_by)`)
- **Constraint adherence:** Operates entirely within FR3's approved database entities without bypassing business rules.

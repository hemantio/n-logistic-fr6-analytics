# FR6 Centralized Architecture Integration Guide

This guide describes how to integrate the **FR6 Analytics Dashboard** into the unified *N Logistic Management Platform* using the centralized MVC2 architecture.

---

## 1. Centralized Architecture Overview

Instead of multiple fragmented controllers, services, and DAOs, FR6 consolidates responsibilities into **three primary backend classes**:

| Layer | Class | Responsibility |
| :--- | :--- | :--- |
| **Controller** | `com.nlogistic.fr6.controller.AnalyticsServlet` | Request routing under `/fr6/analytics/*`, parameter sanitization, multi-tenant isolation, format dispatching (HTML/JSON). |
| **Service** | `com.nlogistic.fr6.service.AnalyticsService` | All analytical calculations, Pareto 70/20/10 algorithm, inventory velocity classification, and cache refresh coordination. |
| **DAO** | `com.nlogistic.fr6.dao.AnalyticsDAO` | All JDBC `PreparedStatement` operations, transactional cache updates, and FR3 dynamic pricing synchronization. |

---

## 2. Integration Seam: Database Connection

To connect FR6 to the host application's connection pool (e.g., HikariCP, Apache DBCP, or Tomcat JNDI DataSource), provide an `AnalyticsConnectionProvider` implementation in a startup listener:

```java
import com.nlogistic.fr6.config.AnalyticsConnectionProvider;

// In your application startup / ServletContextListener:
AnalyticsConnectionProvider.setCustomProvider(() -> platformDataSource.getConnection());
```

If no custom provider is configured, FR6 automatically falls back to `fr6_db.properties` on the classpath.

---

## 3. Web Servlet Registration

Only a single servlet mapping is required in `web.xml` (or via `@WebServlet`):

```xml
<servlet>
    <servlet-name>AnalyticsServlet</servlet-name>
    <servlet-class>com.nlogistic.fr6.controller.AnalyticsServlet</servlet-class>
</servlet>
<servlet-mapping>
    <servlet-name>AnalyticsServlet</servlet-name>
    <url-pattern>/fr6/analytics/*</url-pattern>
</servlet-mapping>
```

### Registered Endpoints:
- `GET /fr6/analytics/dashboard` (or `/kpis`): FR6.1 Dashboard Overview & KPIs
- `GET /fr6/analytics/sales-trends`: FR6.2 Sales Trends (Route, Product, Customer)
- `GET /fr6/analytics/abc-classification` (or `/abc`): FR6.3 ABC Pareto Analysis
- `GET /fr6/analytics/inventory-turnover`: FR6.4 Inventory Turnover & Velocity
- `GET /fr6/analytics/profitability`: FR6.5 Product Margins & Shipment P&L
- `GET /fr6/analytics/demand-forecast` (or `/forecast`): FR6.6 Demand Forecasting
- `POST /fr6/analytics/demand-forecast`: FR6.6 Sync suggested multiplier to FR3 `pricing_rules`
- `POST /fr6/analytics/refresh`: FR6.7 Atomic Transactional Cache Refresh

---

## 4. Multi-Tenant Isolation & Role-Based Access Control (FR6.8)

FR6 uses `AnalyticsUtil.extractSecurityContext(request)` to enforce multi-tenancy:
- **ADMIN**: Can view all company metrics and filter by specific company IDs.
- **SELLER / CONSUMER**: Strictly locked to their own session `company_id`. Any query parameters requesting foreign companies are discarded.

# FR6 Analytics Dashboard - API & Route Documentation

This document describes all Servlet routes, methods, access controls, query parameters, and response formats implemented in the FR6 Analytics module.

All routes are scoped under the `/fr6/` namespace to prevent URL collisions during platform integration.

---

## Route Overview

| Route | Servlet Class | Supported Methods | Roles Permitted | Purpose |
|---|---|---|---|---|
| `/fr6/analytics/dashboard` | `AnalyticsDashboardServlet` | GET | `ADMIN`, `SELLER`, `CONSUMER` | Main overview showing 5 mandatory KPIs & preview widgets |
| `/fr6/analytics/sales-trends` | `SalesTrendServlet` | GET | `ADMIN`, `SELLER`, `CONSUMER` | Revenue & volume trends over time by Route, Product, or Customer |
| `/fr6/analytics/abc-classification` | `AbcClassificationServlet` | GET | `ADMIN`, `SELLER`, `CONSUMER` | Pareto classification (A: 70%, B: 20%, C: 10%) |
| `/fr6/analytics/inventory-turnover` | `InventoryTurnoverServlet` | GET | `ADMIN`, `SELLER` | Inventory turnover ratios (`cogs / avg_inventory`) |
| `/fr6/analytics/profitability` | `ProfitabilityServlet` | GET | `ADMIN`, `SELLER` | Product profitability margins & shipment P&L breakdown |
| `/fr6/analytics/demand-forecast` | `DemandForecastServlet` | GET, POST | GET: All, POST: `ADMIN`, `SELLER` | Demand predictions & FR3 pricing multiplier updates |
| `/fr6/analytics/refresh` | `AnalyticsRefreshServlet` | GET, POST | `ADMIN`, `SELLER` | On-demand transactional cache recalculation |

---

## 1. Dashboard Overview (`/fr6/analytics/dashboard`)

- **Method:** `GET`
- **Controller:** `com.nlogistic.fr6.controller.AnalyticsDashboardServlet`
- **View:** `/WEB-INF/views/analytics/dashboard.jsp`
- **Parameters:**
  - `startDate` (optional, `yyyy-MM-dd`): Beginning of evaluation window (default: 6 months prior).
  - `endDate` (optional, `yyyy-MM-dd`): End of evaluation window (default: today).
  - `companyId` (optional, integer): Company ID filter. *Note:* If user role is `SELLER` or `CONSUMER`, this parameter is ignored and the user's authenticated `companyId` is strictly enforced.
- **Output:**
  - `dashboardData`: `AnalyticsDashboardDTO` containing:
    - `activeShipments` (int): Count of shipments with status not in `DELIVERED`, `CANCELLED`.
    - `containersAvailable` (int): Count of containers with status `AVAILABLE`.
    - `revenue` (BigDecimal): Sum of paid invoices.
    - `pendingInvoicesCount` (int) & `pendingInvoicesAmount` (BigDecimal): Unpaid/partial invoices.
    - `openClaimsCount` (int) & `openClaimsAmount` (BigDecimal): Active claims.

---

## 2. Sales Trend Analysis (`/fr6/analytics/sales-trends`)

- **Method:** `GET`
- **Controller:** `com.nlogistic.fr6.controller.SalesTrendServlet`
- **View:** `/WEB-INF/views/analytics/sales-trends.jsp`
- **Parameters:**
  - `dimension` (optional, `route` | `product` | `customer`): Breakdown dimension (default: `route`).
  - `originPortId` (optional, integer): Filter by Point A port.
  - `destPortId` (optional, integer): Filter by Point B port.
  - `startDate` / `endDate` (optional, `yyyy-MM-dd`): Date range.
  - `companyId` (optional, integer): Company isolation filter.
  - `format` (optional, `json`): Returns raw JSON payload for Chart.js AJAX rendering.
- **JSON Response Format (`format=json`):**
  ```json
  {
    "labels": ["Route (1 -> 2) (2026-08-01)", "Route (1 -> 2) (2026-09-01)"],
    "sales": [1200000.00, 850000.00],
    "quantities": [100, 1000]
  }
  ```

---

## 3. ABC Classification (`/fr6/analytics/abc-classification`)

- **Method:** `GET`
- **Controller:** `com.nlogistic.fr6.controller.AbcClassificationServlet`
- **View:** `/WEB-INF/views/analytics/abc-classification.jsp`
- **Parameters:**
  - `category` (optional, string): Filter by product category.
  - `companyId` (optional, integer): Filter by seller company.
  - `format` (optional, `json`): Returns JSON distribution summary.
- **JSON Response Format (`format=json`):**
  ```json
  {
    "countA": 2,
    "countB": 3,
    "countC": 1,
    "sumA": 6300000.00,
    "sumB": 3015000.00,
    "sumC": 850000.00
  }
  ```

---

## 4. Inventory Turnover Ratio (`/fr6/analytics/inventory-turnover`)

- **Method:** `GET`
- **Controller:** `com.nlogistic.fr6.controller.InventoryTurnoverServlet`
- **View:** `/WEB-INF/views/analytics/inventory-turnover.jsp`
- **Parameters:**
  - `productId` (optional, integer): Specific product.
  - `companyId` (optional, integer): Owner company.
  - `format` (optional, `json`): Returns JSON dataset for bar charts.
- **JSON Response Format (`format=json`):**
  ```json
  {
    "labels": ["Premium Cotton Textiles", "Organic Black Pepper"],
    "ratios": [0.25, 0.29],
    "cogs": [1200000.00, 850000.00],
    "averageRatio": 0.24
  }
  ```

---

## 5. Profitability & P&L (`/fr6/analytics/profitability`)

- **Method:** `GET`
- **Controller:** `com.nlogistic.fr6.controller.ProfitabilityServlet`
- **View:** `/WEB-INF/views/analytics/profitability.jsp`
- **Parameters:**
  - `startDate` / `endDate` (optional, `yyyy-MM-dd`): Date range.
  - `productId` (optional, integer): Specific product.
  - `companyId` (optional, integer): Filter by seller company.
  - `format` (optional, `json`): Returns JSON datasets for combo chart.
- **JSON Response Format (`format=json`):**
  ```json
  {
    "labels": ["Premium Cotton Textiles (2026-08-01)"],
    "revenues": [1200000.00],
    "costs": [780000.00],
    "margins": [35.00]
  }
  ```

---

## 6. Demand Forecast & Pricing Multiplier (`/fr6/analytics/demand-forecast`)

- **Method:** `GET`, `POST`
- **Controller:** `com.nlogistic.fr6.controller.DemandForecastServlet`
- **View:** `/WEB-INF/views/analytics/demand-forecast.jsp`
- **GET Parameters:**
  - `originPortId` / `destPortId` (optional, integer): Route ports.
  - `containerType` (optional, enum: `DRY`, `REEFER`, `OPEN_TOP`, `TANK`).
  - `format` (optional, `json`): Returns Chart.js forecast arrays.
- **POST Action (Apply Multiplier to FR3):**
  - **URL:** `/fr6/analytics/demand-forecast`
  - **Body Parameter:** `forecastId` (integer, required).
  - **Behavior:** Reads `demand_forecast.suggested_multiplier`, updates `pricing_rules.demand_multiplier` for matching active route/container, and inserts audit record into `pricing_audit`.

---

## 7. Analytics Cache Refresh (`/fr6/analytics/refresh`)

- **Method:** `POST` (or `GET` fallback)
- **Controller:** `com.nlogistic.fr6.controller.AnalyticsRefreshServlet`
- **Roles:** `ADMIN`, `SELLER`
- **Parameters:**
  - `format` (optional, `json`): Returns execution metrics JSON.
- **JSON Response Format (`format=json`):**
  ```json
  {
    "success": true,
    "durationMillis": 33,
    "totalRowsRefreshed": 35,
    "salesTrends": 6,
    "abcProducts": 6,
    "turnoverRows": 6,
    "profitabilityRows": 13,
    "forecasts": 4
  }
  ```

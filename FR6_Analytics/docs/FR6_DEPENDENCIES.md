# FR6 Analytics Dashboard - Dependencies & Runtime Environment

This document lists the exact software versions, runtime requirements, libraries, and asset dependencies used in the FR6 Analytics module.

---

## 1. Runtime Environment Tested

| Component | Target Version | Tested Development Environment | Notes |
|---|---|---|---|
| Operating System | Windows 11 / Windows Server | Windows 11 (64-bit) | Compatible with Linux/UNIX production environments |
| Java Runtime | JDK 11 or higher | JDK 21.0.12 LTS (`C:\Program Files\Java\jdk-21.0.12`) | Complies with Java SE 11+ specification |
| Application Server | Apache Tomcat 9+ | Apache Tomcat 9.0.123 (`javax.servlet.*` namespace) | Dynamic Web Module 4.0 |
| Database Engine | MySQL 8.0+ / MariaDB 10.4+ | MariaDB 10.4.32 (XAMPP on port 3306) | InnoDB storage engine, `utf8mb4` encoding |
| Database Name | `n_logistic_db` | `n_logistic_db` | Single unified schema |

---

## 2. Java Libraries (`WEB-INF/lib/`)

Only strictly permitted runtime libraries are placed in `WEB-INF/lib/`:

| JAR File | Version | Scope | SHA-256 / Location | Purpose |
|---|---|---|---|---|
| `mysql-connector-j-9.1.0.jar` | 9.1.0 | Runtime | `WebContent/WEB-INF/lib/` | Official MySQL/MariaDB JDBC Driver |
| `jstl-1.2.jar` | 1.2 | Runtime | `WebContent/WEB-INF/lib/` | Standard JavaServer Pages Tag Library (Core & Fmt tags) |

*Prohibited technologies avoided:* No Spring, Spring Boot, Hibernate, JPA, MyBatis, Python, Node.js, Redis, Celery, or Quartz.

---

## 3. Frontend Libraries & Assets

Assets are provided both locally under `WebContent/assets/` and with CDN fallback support:

| Asset | Version | Path | Purpose |
|---|---|---|---|
| `bootstrap.min.css` | 5.3.3 | `assets/css/fr6/bootstrap.min.css` | Corporate responsive layout, cards, badges |
| `bootstrap.bundle.min.js` | 5.3.3 | `assets/js/fr6/bootstrap.bundle.min.js` | Dropdown, collapse, and alert interactions |
| `chart.umd.min.js` | 4.4.4 | `assets/js/fr6/chart.umd.min.js` | Line, bar, and pie charts (UMD standalone bundle) |
| `analytics.css` | 1.0.0 | `assets/css/fr6/analytics.css` | Module-specific styles scoped under `.fr6-*` |
| `analytics-dashboard.js` | 1.0.0 | `assets/js/fr6/analytics-dashboard.js` | Dashboard overview helper module |
| `sales-trends.js` | 1.0.0 | `assets/js/fr6/sales-trends.js` | Sales trend Chart.js wrapper |
| `abc-classification.js` | 1.0.0 | `assets/js/fr6/abc-classification.js` | Pareto chart wrapper |
| `inventory-turnover.js` | 1.0.0 | `assets/js/fr6/inventory-turnover.js` | Turnover bar chart wrapper |
| `profitability.js` | 1.0.0 | `assets/js/fr6/profitability.js` | Profitability combo chart wrapper |
| `demand-forecast.js` | 1.0.0 | `assets/js/fr6/demand-forecast.js` | Forecast combo chart wrapper |

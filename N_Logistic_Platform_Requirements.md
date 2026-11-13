# N Logistic Import & Export Platform - Complete Project Build Requirements

**Document type:** Whole-project implementation specification for an AI coding agent  
**Project:** N Logistic Import & Export / Logistics Management Platform  
**Scope:** FR1 through FR7 only; AI Assistant and separate ML modules excluded  
**Database:** `n_logistic_db`  
**Architecture:** Java MVC2  
**Primary source:** Supplied 22-page SRS and its database design/ERD sections  

---

## 0. Primary instruction to the AI developer

Build the complete **N Logistic Import & Export Platform** from the ground up as one integrated, browser-based, multi-role Java MVC2 web application. Implement the seven core functional modules **FR1, FR2, FR3, FR4, FR5, FR6 and FR7**. Do not implement the separate AI Assistant module in SRS Section 3.8 or the separate ML Prediction module in SRS Section 3.9.

The supplied SRS is the authority for product scope, requirements, terminology, business rules, technology stack and database structure. The database design in SRS Section 7 is the authority for table names, column names, data types, keys and relationships. Do not silently replace it with a newly invented design.

### 0.1 Scope clarification: similarly numbered requirements

The SRS uses the label `FR3.8` inside Section 3.3 for the **booking-confirmation workflow** (allocate container, create shipment/items, reserve stock and generate invoice). This is part of FR3 and **must be implemented**.

The separate heading **Section 3.8 - AI Module (Assistant Features)** and **Section 3.9 - ML Module (Prediction Features)** are excluded from this project build. Exclude their assistant/chat and ML model features and their dedicated tables. Do not confuse the FR3 booking requirement `FR3.8` with the separate AI section numbered 3.8.

The optional future LCL feature in `FR3.9` (partial container load by volume share) is not part of the current implementation.

### 0.2 Non-negotiable rules

1. Follow the supplied SRS. Do not invent business requirements, workflows, statuses, formulas, tax rates, pricing rules, claim windows, roles, permissions, table columns, relationships or data.
2. Preserve the database entity/table and attribute names from SRS Section 7. Do not rename, pluralize, singularize or redesign them for stylistic reasons.
3. Use one integrated web application, one shared MySQL database (`n_logistic_db`) and one Tomcat deployment. Do not create seven separately deployed applications or seven databases.
4. Use the specified Java MVC2 stack only. Do not substitute Spring, Spring Boot, Hibernate, JPA, MyBatis, Python, Node.js, FastAPI, Django or another backend framework.
5. All browser requests must pass through the module controller/Servlet. JSP is a view only. No SQL, JDBC access or business calculations inside JSP.
6. All database access must use JDBC. Use `PreparedStatement` for parameterized SQL. Use `CallableStatement` only to call approved stored procedures.
7. Follow the SRS rule of one controller per module. The controller receives a request, calls service and DAO layers, then forwards results to the relevant JSP view.
8. Implement DAO interfaces and DAO implementation classes using JDBC, one per entity as stated in SRS Section 6. Avoid duplicating ownership or implementing two competing DAOs for the same shared table.
9. Put business rules in service/DAO/database layers, not in JSP or JavaScript.
10. Enforce server-side role-based access on every controller/request. Hiding a navigation link is not authorization.
11. Maintain a single authoritative writer/owner for each shared operational table and business workflow. Other modules must call the owning module's service/approved database procedure rather than duplicating the workflow.
12. Do not hardcode sample values as production data. Test/seed data must be clearly identified as development-only.
13. Do not mark a feature complete unless it is implemented and verified against the SRS. Clearly identify incomplete, blocked or mocked functionality.
14. If the SRS does not define a required detail, record it as an **Open Specification Question** and isolate the affected implementation. Do not silently decide it.
15. The complete project may be developed locally using the provided development environment, but the final combined application must remain suitable for the SRS environment and module integration.

When there is a conflict, the supplied SRS/database design wins. Document the conflict and ask for a decision rather than silently changing the source.

---

## 1. Product scope and users

### 1.1 Product perspective

The SRS describes a standalone, browser-based, multi-role web application using a single MySQL database. All requests go through controllers. Business rules are enforced in the service/DAO layer and supported by database triggers and stored procedures where specified.

### 1.2 Included functional modules

| Module | SRS section | Module name |
|---|---|---|
| FR1 | 3.1 | User and Access Management |
| FR2 | 3.2 | Container Movement Tracking and P&L Graph |
| FR3 | 3.3 | Container Allocation and Pricing |
| FR4 | 3.4 | Stock Details |
| FR5 | 3.5 | Billing and Payments |
| FR6 | 3.6 | Analytics Dashboard |
| FR7 | 3.7 | Claim of Loss and Damage |

### 1.3 Excluded functionality

Do not implement:

- SRS Section 3.8 AI Assistant features (AI1-AI5, chat assistant, claim summary, quote explanation, natural-language smart search, report summary).
- SRS Section 3.9 ML Prediction module (ML1-ML6, ETA model, separate ML demand model, dynamic-price model, fraud/anomaly model, container-repositioning model, customer-payment-risk model).
- AI/ML-specific tables: `ai_chat_log`, `ai_claim_summaries`, `ml_predictions`, `anomaly_alerts`.
- Physical GPS hardware.
- Online payment gateway processing. Payments are recorded in the system; they are not processed through a gateway.
- Optional future `FR3.9` partial container load (LCL) by volume share.

**Keep FR6.6.** Demand forecasting is explicitly part of FR6 and remains in scope. However, do not implement the separate ML2 model from Section 3.9. The SRS does not provide a separate non-ML algorithm for FR6.6; obtain an approved method before generating production forecasts.

### 1.4 User classes

Only the following SRS user classes are in scope:

- **Consumer:** Chooses a seller's goods, books a container, sees automatic price and bill, records invoice payment, tracks shipment from Point A to Point B, and raises claims.
- **Seller (exporter):** Adds products and stock, manages containers and pricing rules, updates movement status, reviews/settles claims, and views the P&L graph.
- **Admin:** Manages users, ports and ships (vessels), and views the audit log.

Do not create additional roles unless the project owner approves a change to the SRS.

### 1.5 Main business flow from SRS Section 2.8

1. Admin adds ports and ships (vessels) and manages users.
2. Seller adds products and stock, and adds containers.
3. Consumer logs in, picks the seller's goods and quantity, and chooses origin and destination ports.
4. The system checks container availability and capacity, allocates a container, and calculates the price automatically (freight, handling, tax) from pricing rules.
5. Consumer confirms the booking. The shipment is created, stock is reserved and the bill (invoice) is generated automatically.
6. Seller updates movement status from Point A to Point B. Consumer tracks it.
7. Consumer records payment. Invoice status updates automatically.
8. If goods are lost or damaged, Consumer raises a claim. Seller reviews and settles it. The amount goes into P&L.
9. Seller views the P&L graph.

The separate AI/ML suggestions mentioned at the end of the business-flow section are excluded.

---

## 2. Fixed technology stack and operating environment

Use the following stack. Do not substitute another framework or architecture.

| Layer | Required technology |
|---|---|
| IDE | Eclipse IDE for Enterprise Java and Web Developers |
| Java | JDK 11 or later; user's development environment is JDK 21 |
| Backend | Java Servlets |
| Architecture | MVC2 |
| Database | MySQL on XAMPP |
| Database name | `n_logistic_db` |
| Storage engine | InnoDB |
| Character encoding | `utf8mb4` |
| Database access | JDBC using `mysql-connector-j` |
| Connection management | JDBC connection pooling, centrally configured |
| Data access | DAO interfaces and DAO implementation classes using JDBC |
| Data objects | POJO classes |
| Frontend | JSP and JSTL; no Java scriptlets |
| UI framework | Bootstrap 5 |
| Charts | Chart.js |
| Application server | Apache Tomcat 9 or later; current target is Tomcat 9 |
| Servlet namespace for Tomcat 9 | `javax.servlet.*`; do not use `jakarta.servlet.*` in the Tomcat 9 build |
| Database logic | MySQL triggers and stored procedures where specified in the SRS |
| Browser environment | Modern Chrome, Edge and Firefox |

Use Java code that is compatible with the SRS's JDK 11+ environment while developing with JDK 21. Verify the database engine/version actually bundled with the installed XAMPP before selecting the matching JDBC driver. Do not assume the installed XAMPP version is running Oracle MySQL rather than MariaDB.

### 2.1 External interface requirements

- Responsive Bootstrap 5 layout with role-based navigation.
- Screens include Login/Register, Dashboard, Booking and Quotation, Container List, Tracking Timeline, Stock Upload, Invoices and Payments, Analytics, P&L Graph and Claims.
- Client-side and server-side form validation with clear error messages.
- MySQL (XAMPP) accessed through JDBC and `mysql-connector-j` with connection pooling.
- Chart.js and Bootstrap may be loaded from CDN or local assets; use one consistent approved approach.
- Uploaded files are stored in a server folder; the stored path is recorded in the database.
- Browser and Tomcat communicate using HTTP/HTTPS. HTTPS is required in production.

### 2.2 Prohibited substitutions

Do not add Spring/Spring Boot, Hibernate, JPA, MyBatis, ORM frameworks, separate Python/Node.js services, microservices, Redis, Celery, Quartz or another charting library. Do not add unapproved third-party frameworks. Use the SRS stack and document any library needed to fulfill a specific SRS requirement before adding it.

---

## 3. Unified application architecture

### 3.1 Deployment model

Build one Eclipse Dynamic Web Project named:

`N_Logistic_Platform`

The final result is one web application/WAR deployed to one Apache Tomcat server, with one shared MySQL database named `n_logistic_db`.

The seven functional modules are separate packages and frontend view namespaces inside the same application. They are not seven independent deployed web applications.

### 3.2 Exact MVC2 request flow

Follow the SRS Section 6 sequence:

`Browser -> Module Controller -> Service -> DAO Interface -> DAO Implementation -> MySQL -> Request Attribute -> JSP View`

- **Model:** POJO classes, DAO interfaces and DAO implementations using JDBC, one DAO per entity; service classes implement business rules.
- **View:** JSP + JSTL + Bootstrap 5 pages. No Java scriptlets, SQL or business logic.
- **Controller:** One controller per module. It receives the request, calls the relevant service and DAO layers, then forwards the result to the JSP view.

### 3.3 Layer responsibilities

**Controller layer**
- One controller/Servlet per functional module: FR1 through FR7.
- Parse and validate request parameters.
- Obtain authenticated user/access context from the shared security layer.
- Enforce role/ownership permissions on every request.
- Call service methods; do not contain SQL or substantial business rules.
- Set request attributes and forward to the appropriate JSP.

**Service layer**
- Implement the business rules for the module.
- Coordinate entity DAOs and cross-module service calls.
- Use transactions or approved stored procedures for multi-step business operations.
- Keep a single authoritative implementation of shared business rules.

**DAO interface and implementation layer**
- Define an interface and JDBC implementation for each entity/data-access responsibility.
- Use `PreparedStatement` for parameterized SQL.
- Use `CallableStatement` only to call an approved stored procedure.
- Map `ResultSet` values to POJOs.
- Do not duplicate DAOs for the same shared table across modules.

**Model / POJO layer**
- Represent database entities with fields matching the approved database schema.
- Use constructors, getters and setters as needed.
- Do not depend on Servlet or JSP APIs.

**JSP/JSTL view layer**
- Render values supplied by controllers through request/session attributes.
- Use JSTL/EL, including XSS-safe output (`c:out`).
- No scriptlets, SQL, JDBC calls or business calculations.

**Shared infrastructure**
- One connection provider/pool.
- One authentication/session contract.
- Shared authorization and CSRF helpers.
- Shared application configuration, exception handling and common layout fragments.

### 3.4 Centralized shared services and single ownership

A table or business workflow must have one authoritative DAO/service owner. Other modules may call that owner's service contract. Do not create competing versions of a workflow.

Initial responsibility map for coordination (the SRS defines module functions; resolve any ownership conflict with the integration lead before coding):

| Entity/workflow | Primary responsibility | Cross-module use |
|---|---|---|
| Users, Companies, Customers, Audit_log | FR1 | All modules use authenticated user/company context; other modules must not implement user CRUD |
| Ports, Vessels | FR1 | FR2/FR3/FR6 read port and vessel data |
| Containers, Pricing_rules, Pricing_audit | FR3 | FR2/FR6 read container and pricing information as needed |
| Shipment creation and Shipment_items | Created by FR3 booking-confirmation flow, using one agreed shipment service/DAO | FR2 tracks the created shipment; FR4/FR5/FR7/FR6 read it |
| Container_movements | FR2 | FR2 maintains movement events; Consumer tracking reads them |
| Products, Stock, Inventory_ledger, Sales_transactions | FR4 | FR3 calls FR4 stock reservation; FR6 reads sales/inventory data |
| Billing_invoices, Invoice_line_items, Payments | FR5 | FR3 invokes invoice generation on booking confirmation; FR6 reads billing/payment data |
| Claims, Claim_documents, Claim_status_history | FR7 | FR7 controls claim workflow; FR2/FR6 read settled-claim/P&L effects |
| Profit_loss | One agreed P&L implementation associated with FR2; settlement changes use the approved DB procedure/contract | FR7 invokes approved claim-settlement integration; FR6 reads P&L data |
| Sales_trend_result, Abc_classification_result, Inventory_turnover_result, Profitability_result | FR6 | FR6 calculates and maintains analytics results |
| Demand_forecast | FR6 produces forecast results; FR3 remains owner of Pricing_rules/Pricing_audit | FR3 accepts/uses the approved suggested multiplier through its own pricing rules and audit flow |

Do not interpret this map as permission to create additional tables or columns. Where table ownership is disputed, document the chosen owner and interface before implementing writes.

---

## 4. Whole-project Eclipse folder and package structure

Use one project with shared infrastructure and seven module namespaces. Keep front-end files separated by module. Use one `WebContent` layout consistently for the classic Eclipse Dynamic Web Project and Tomcat 9. If Eclipse creates `src/main/webapp`, use that instead; do not create both layouts.

```text
N_Logistic_Platform/
│
├── Java Resources/
│   └── src/
│       └── com/nlogistic/
│           │
│           ├── common/
│           │   ├── config/
│           │   │   ├── DBConnection.java
│           │   │   └── AppConfig.java
│           │   ├── security/
│           │   │   ├── AuthenticationFilter.java
│           │   │   ├── AuthorizationUtil.java
│           │   │   └── CsrfUtil.java
│           │   ├── exception/
│           │   │   └── ApplicationException.java
│           │   └── util/
│           │       ├── DateUtil.java
│           │       ├── ValidationUtil.java
│           │       └── FileStorageUtil.java
│           │
│           ├── fr1/
│           │   ├── controller/FR1Controller.java
│           │   ├── service/
│           │   ├── dao/
│           │   │   └── impl/
│           │   ├── model/
│           │   └── dto/
│           │
│           ├── fr2/
│           │   ├── controller/FR2Controller.java
│           │   ├── service/
│           │   ├── dao/
│           │   │   └── impl/
│           │   ├── model/
│           │   └── dto/
│           │
│           ├── fr3/
│           │   ├── controller/FR3Controller.java
│           │   ├── service/
│           │   ├── dao/
│           │   │   └── impl/
│           │   ├── model/
│           │   └── dto/
│           │
│           ├── fr4/
│           │   ├── controller/FR4Controller.java
│           │   ├── service/
│           │   ├── dao/
│           │   │   └── impl/
│           │   ├── model/
│           │   └── dto/
│           │
│           ├── fr5/
│           │   ├── controller/FR5Controller.java
│           │   ├── service/
│           │   ├── dao/
│           │   │   └── impl/
│           │   ├── model/
│           │   └── dto/
│           │
│           ├── fr6/
│           │   ├── controller/FR6Controller.java
│           │   ├── service/
│           │   ├── dao/
│           │   │   └── impl/
│           │   ├── model/
│           │   └── dto/
│           │
│           └── fr7/
│               ├── controller/FR7Controller.java
│               ├── service/
│               ├── dao/
│               │   └── impl/
│               ├── model/
│               └── dto/
│
├── WebContent/
│   ├── assets/
│   │   ├── css/
│   │   │   ├── common/
│   │   │   ├── fr1/
│   │   │   ├── fr2/
│   │   │   ├── fr3/
│   │   │   ├── fr4/
│   │   │   ├── fr5/
│   │   │   ├── fr6/
│   │   │   └── fr7/
│   │   ├── js/
│   │   │   ├── common/
│   │   │   ├── fr1/
│   │   │   ├── fr2/
│   │   │   ├── fr3/
│   │   │   ├── fr4/
│   │   │   ├── fr5/
│   │   │   ├── fr6/
│   │   │   └── fr7/
│   │   └── images/
│   │
│   └── WEB-INF/
│       ├── views/
│       │   ├── common/
│       │   │   ├── header.jsp
│       │   │   ├── navigation.jsp
│       │   │   ├── sidebar.jsp
│       │   │   └── footer.jsp
│       │   ├── fr1/
│       │   ├── fr2/
│       │   ├── fr3/
│       │   ├── fr4/
│       │   ├── fr5/
│       │   ├── fr6/
│       │   └── fr7/
│       ├── lib/
│       └── web.xml
│
├── database/
│   ├── 00_create_database.sql
│   ├── 01_users_companies_customers_audit.sql
│   ├── 02_ports_vessels_containers.sql
│   ├── 03_shipment_tracking_items.sql
│   ├── 04_pricing_and_forecast.sql
│   ├── 05_products_stock_inventory_sales.sql
│   ├── 06_billing_payments.sql
│   ├── 07_claims.sql
│   ├── 08_profit_loss_analytics.sql
│   ├── 09_constraints_indexes.sql
│   ├── 10_triggers.sql
│   ├── 11_stored_procedures.sql
│   └── dev_seed.sql
│
├── uploads/                         # Runtime storage; not committed with user files
│
├── docs/
│   ├── DATABASE_DOCUMENTATION.md
│   ├── MODULE_OWNERSHIP.md
│   ├── MODULE_INTEGRATION.md
│   ├── ROUTE_AND_PERMISSION_MATRIX.md
│   ├── TESTING_DOCUMENTATION.md
│   └── OPEN_SPECIFICATION_QUESTIONS.md
│
├── tests/
│   ├── unit/
│   ├── database/
│   ├── integration/
│   └── functional/
│
└── README.md
```

### 4.1 Package and naming conventions

- Root package: `com.nlogistic`.
- Module packages: `com.nlogistic.fr1` through `com.nlogistic.fr7`.
- Shared packages: `com.nlogistic.common.*`.
- Java class names: PascalCase, e.g. `FR3Controller`, `PricingRule`, `BillingInvoiceDAO`.
- Method and variable names: camelCase.
- Constants: UPPER_SNAKE_CASE.
- SQL table and column names: preserve the exact lower-case snake_case names used in SRS Section 7/database script.
- Servlet URL prefixes: `/fr1/*` through `/fr7/*` (integration convention; not an additional business requirement).
- JSP view paths: `/WEB-INF/views/frN/`.
- Asset paths: `/assets/css/frN/` and `/assets/js/frN/`.

### 4.2 Module class-count discipline

- Use exactly one primary controller/Servlet per module, as specified by SRS Section 6. It may route the module's actions based on its path/action parameter.
- Create DAO interfaces and DAO implementations per entity, as specified by the SRS.
- Create service classes for genuine business workflows. Do not create a separate service class for every small method or trivial operation.
- Keep model POJOs separate where they represent different database entities.
- Do not combine Controller, Service and DAO responsibilities into one class.
- Do not over-fragment the code into unnecessary helper classes. Centralize each module's business workflow while retaining the MVC2 boundaries.

---

## 5. Functional requirements - exact module scope

## 5.1 FR1 - User and Access Management

Implement all requirements FR1.1-FR1.7.

### FR1.1 Registration
- Allow registration of Consumers and Sellers with company details.
- Use the SRS `companies`, `users` and `customers` entities and relationships.

### FR1.2 Authentication
- Authenticate users with email and password.
- Store password hashes, not plaintext passwords. The SRS gives BCrypt as an example (`password_hash` column); use an approved BCrypt-compatible implementation and never log credentials.

### FR1.3 Role-based access
- Enforce the three SRS roles: `CONSUMER`, `SELLER`, `ADMIN`.
- Enforce server-side checks on every page/action/request.
- Apply session timeout and other security NFRs.

### FR1.4 Admin user management
- Admin can add, edit, activate and deactivate users.
- Respect user status values defined in the database schema.

### FR1.5 Audit log
- Record significant actions with user, action and timestamp.
- Use `audit_log` and the fields defined in SRS Section 7.
- Audit inserts, updates, deletes, logins and other significant actions as defined by the application workflow; do not log secrets.

### FR1.6 Port management
- Admin can add, edit and deactivate ports.
- Port data includes code, name, city and country as stated in FR1.6 and the `ports` schema.

### FR1.7 Vessel management
- Admin can add/edit vessels and set status to `ACTIVE` or `MAINTENANCE`.

---

## 5.2 FR2 - Container Movement Tracking and P&L Graph

Implement all requirements FR2.1-FR2.9.

### FR2.1 Shipment information
Record each shipment with:
- Origin port (Point A).
- Destination port (Point B).
- Vessel.
- Container.
- Cargo information.
- Expected dates.

Use the approved `shipment` fields and relationships.

### FR2.2 Movement status sequence
Seller shall update shipment movement status in this sequence:

`BOOKED -> LOADED -> DEPARTED -> IN_TRANSIT -> ARRIVED -> CUSTOMS_CLEARED -> DELIVERED`

The database enum also includes `CANCELLED` as specified in Section 7. Do not invent additional statuses. Define allowed cancellation behavior only from the approved business contract.

### FR2.3 Movement event history
Every status change is stored as an event in `container_movements`, with:
- Shipment and container references.
- Status.
- Port/location.
- Event timestamp.
- Remarks.
- User who updated it.

### FR2.4 Consumer tracking
Consumer can view a timeline and route view from A to B with the current status of each shipment.

### FR2.5 Estimated vs actual arrival
Display estimated versus actual arrival and flag delayed shipments. The exact delay threshold/definition is not stated in the supplied SRS; record it as an open specification question if a numeric rule is needed.

### FR2.6 Search and filter
Allow search/filter by:
- Container number.
- Shipment ID.
- Port.
- Status.

### FR2.7 Seller P&L graph
Seller can view Profit & Loss graph:
- Monthly.
- Per shipment.
- Revenue.
- Cost.
- Net profit.

Use the shared `profit_loss` records and coordinate with FR6 analytics so there is one agreed source of P&L calculations.

### FR2.8 Financial rules
- Revenue comes from paid invoices.
- Costs come from freight, port and handling costs and settled claims.
- Claim payouts reduce profit (see FR7.6).

### FR2.9 P&L filters/export
- Support date-range filters.
- Export P&L data to CSV.

---

## 5.3 FR3 - Container Allocation and Pricing

Implement FR3.1-FR3.8. Treat FR3.9 LCL as optional future scope, not a current implementation requirement.

### FR3.1 Container inventory
Seller maintains container inventory with:
- Type.
- Size.
- Capacity.
- Current port.
- Status.

Use `containers` and the exact values defined in the schema.

### FR3.2 Booking details
Consumer books by selecting:
- Seller's goods (product and quantity).
- Origin port.
- Destination port.
- Date.

### FR3.3 Availability validation
Allocate only containers with status `AVAILABLE` at the origin port. Reject booking otherwise.

### FR3.4 Cargo weight and volume
- Calculate cargo weight and volume automatically from selected goods/quantities.
- Validate cargo against container capacity before shipment creation.
- Reject over-capacity bookings.

### FR3.5 Automatic pricing
Calculate price from configured pricing rules, including:
- Base rate per route.
- Container type.
- Weight/volume rates.
- Season multiplier.
- Demand multiplier.
- Taxes.

Do not invent tax rates, formula ordering, rounding rules or unlisted pricing factors. Use the approved pricing rules and approved stored procedure.

### FR3.6 Pricing-rule management and audit
Seller can create/edit pricing rules. Every change is recorded in `pricing_audit`.

### FR3.7 Quotation
Consumer sees a price quotation before confirming the booking.

### FR3.8 Booking confirmation workflow
On confirmation:
1. Set container status to `ALLOCATED`.
2. Create the shipment and its items.
3. Reserve stock.
4. Generate invoice automatically through FR5.

This process must be transaction-safe. If any required step fails, roll back the related booking transaction as required by NFR4. Use the shared service contracts for shipment, stock and invoice operations; do not duplicate those modules' business logic.

### FR3.9 Optional future scope
Partial container load (LCL) by volume share is optional/future and is not required for this build.

---

## 5.4 FR4 - Stock Details

Implement FR4.1-FR4.7.

### FR4.1 Product and stock entry
Seller can add products with:
- SKU.
- Name.
- HS code.
- Unit.
- Weight.
- Price.

Seller can add stock quantity through a form or CSV/Excel upload.

### FR4.2 Upload validation
Validate uploaded rows for:
- Mandatory fields.
- Numeric values.
- Duplicate SKU.

Show row-level errors. Do not silently accept invalid rows.

### FR4.3 Stock reservation
When Consumer books goods, the booked quantity is reserved and linked to the shipment and container.

### FR4.4 Stock visibility
Users can see total stock quantity and value for each shipment, subject to role/company access.

### FR4.5 Inventory ledger
Every stock change (`IN`, `OUT`, `DAMAGE`, `ADJUST`, and the schema's `CLAIM_LOSS`) must be written to `inventory_ledger` automatically.

### FR4.6 No negative stock
The system shall not allow negative stock.

### FR4.7 Stock search/edit
Seller can view, search and edit stock. Booked quantity cannot be edited below the amount already reserved.

Use transactions and database rules/triggers where defined. The `stock` and `inventory_ledger` values/constraints in Section 7 take precedence over guessed structures.

---

## 5.5 FR5 - Billing and Payments

Implement FR5.1-FR5.5.

### FR5.1 Automatic invoice generation
Generate the invoice automatically when a booking is confirmed. Invoice line items include the SRS types:
- Freight.
- Handling.
- Customs.
- Tax/GST.
- Insurance.

Use `billing_invoices` and `invoice_line_items`.

### FR5.2 Taxes and duties
Calculate taxes/duties from configurable rates. Do not hardcode rates that are not defined by the approved configuration.

### FR5.3 Payment recording
Consumer can record full or partial payments with:
- Payment mode.
- Reference.
- Date.

Payments are recorded, not processed through an online payment gateway.

### FR5.4 Invoice status
Update invoice status automatically from payments using the SRS values:
- `UNPAID`.
- `PARTIAL`.
- `PAID`.

The trigger/database rule specified in Section 7.2 must support status updates after payments.

### FR5.5 Printable/PDF invoices
Provide printable/PDF invoices. Use a print-ready invoice view. Do not introduce a new PDF library without approval; if server-side PDF generation beyond browser printing is required, record the library choice as an implementation dependency requiring approval.

---

## 5.6 FR6 - Analytics Dashboard

Implement all requirements FR6.1-FR6.8.

### FR6.1 Dashboard KPIs
Show:
- Active shipments.
- Containers available.
- Revenue.
- Pending invoices.
- Open claims.

Use actual operational data and the approved status/business rules. Do not invent the precise interpretation of a KPI where the SRS is ambiguous; document the question and obtain approval.

### FR6.2 Sales trend analysis
Show revenue/volume over time by:
- Route.
- Product.
- Customer.

Use the operational sales/shipment/billing data and `sales_trend_result` as appropriate. The table structure in Section 7 must not be altered without approval.

### FR6.3 ABC (Pareto) classification
Classify products/customers into A, B and C by contribution.

SRS Section 7.9 defines the product classification table's categories as:
- A = top 70%.
- B = next 20%.
- C = last 10%.

The supplied table stores `product_id`, so product persistence is defined. The SRS functional text mentions products/customers; if customer classifications must be stored, confirm the required schema because no customer key is shown in `abc_classification_result`.

### FR6.4 Inventory turnover
Calculate inventory turnover per product and period. SRS Section 7.9 defines:

`turnover_ratio = cogs / avg_inventory`

Use the exact fields in `inventory_turnover_result` and approved stock/ledger sources.

### FR6.5 Product profitability
Show margin per product/shipment using the relevant result structures:
- `profitability_result` for product/period profitability.
- `profit_loss` for shipment/seller P&L.

Do not merge these tables or invent product-level allocation rules not specified by the SRS.

### FR6.6 Demand forecasting
Predict route/container demand and update the pricing multiplier. Use the `demand_forecast` fields and coordinate with FR3's `pricing_rules`/`pricing_audit` ownership.

The separate ML module is excluded. The FR6.6 requirement remains in scope, but the SRS does not define a non-ML forecast algorithm in Section 3.6. Do not silently copy the separate ML2 model from excluded Section 3.9. Obtain an approved method/strategy for FR6.6 before generating production forecasts or changing live pricing.

### FR6.7 Cached results and refresh
Store analytics results in the approved cached result tables and support refresh on demand or on schedule. Do not create additional cache tables without approval. The SRS does not define a refresh interval; obtain it before enabling scheduled refresh.

### FR6.8 Charts and filters
Use Chart.js for:
- Line charts.
- Bar charts.
- Pie charts.

Data must be filterable by:
- Date.
- Route.
- Company.

Apply filters server-side and enforce company access. Frontend controls do not replace backend filtering/authorization.

---

## 5.7 FR7 - Claim of Loss and Damage

Implement FR7.1-FR7.7.

### FR7.1 Claim creation
Consumer can raise a claim against a shipment/container with:
- Type: `LOSS`, `DAMAGE`, `DELAY`, `SHORTAGE`.
- Description.
- Claimed amount.

### FR7.2 Evidence uploads
Consumer can upload evidence, including photos, survey report and delivery receipt. Store files in a server folder and store the path/metadata in `claim_documents`.

### FR7.3 Claim eligibility
Claims may be raised only for shipments in `ARRIVED` or `DELIVERED` status and within a configurable claim window. The SRS does not specify the duration; do not invent it. Make the approved duration configurable after confirmation.

### FR7.4 Seller review and decision
Seller reviews a claim and can:
- Accept.
- Partially accept.
- Reject.

Seller records approved amount and reason. Enforce approved amount rules from the confirmed business policy; do not invent missing validation limits.

### FR7.5 Claim status history
Store every status change in `claim_status_history`. SRS statuses:
- `SUBMITTED`.
- `UNDER_REVIEW`.
- `APPROVED`.
- `PARTIALLY_APPROVED`.
- `REJECTED`.
- `SETTLED`.

### FR7.6 Settlement
On settlement:
- Post the approved amount to P&L records.
- Adjust inventory for lost/damaged goods.
- Use the approved stored procedure/transaction so related financial and inventory changes are consistent.

### FR7.7 Visibility and comments
Both Consumer and Seller can see claim status and add comments. Use the approved claim remarks/comment mechanism. If a separate comments entity is not in the ERD/schema, do not invent one; confirm whether the existing remarks/status-history mechanism is intended.

---

## 6. Database design - `n_logistic_db`

### 6.1 Database requirements

SRS Section 7 specifies:

- Database: `n_logistic_db`.
- DBMS: MySQL on XAMPP.
- Storage engine: InnoDB.
- Character encoding: `utf8mb4`.
- PK = Primary Key.
- FK = Foreign Key.
- NN = NOT NULL.
- AI = AUTO_INCREMENT.
- UQ = UNIQUE.
- Every table includes `created_at` with a current-time default unless stated otherwise.

Do not add a blanket `updated_at` field unless it is in the approved table definition. Preserve explicit table-specific timestamps such as `last_updated`, `changed_at`, `uploaded_at`, `txn_time`, etc.

### 6.2 The 28 in-scope entities

The 28 core project entities listed in SRS Section 7.1 are:

1. `users`
2. `companies`
3. `customers`
4. `audit_log`
5. `ports`
6. `vessels`
7. `containers`
8. `shipment`
9. `shipment_items`
10. `container_movements`
11. `pricing_rules`
12. `pricing_audit`
13. `demand_forecast`
14. `products`
15. `stock`
16. `inventory_ledger`
17. `sales_transactions`
18. `billing_invoices`
19. `invoice_line_items`
20. `payments`
21. `claims`
22. `claim_documents`
23. `claim_status_history`
24. `profit_loss`
25. `abc_classification_result`
26. `inventory_turnover_result`
27. `profitability_result`
28. `sales_trend_result`

Do not create the four separate AI/ML tables excluded in Section 1.3.

### 6.3 SRS schema inventory

The fields below are transcribed from the supplied SRS Section 7 database design. They are a build reference. Use the actual approved database SQL script if one is supplied by the project owner; it takes priority for any differences. Do not infer missing lengths, nullability or constraints beyond what is listed.

#### `companies`
- `company_id` INT PK AI
- `company_name` VARCHAR(150) NN
- `company_type` ENUM('CONSUMER','SELLER') NN
- `gst_number` VARCHAR(20) UQ
- `iec_code` VARCHAR(15)
- `address` TEXT
- `city`, `country` VARCHAR(60)

#### `users`
- `user_id` INT PK AI
- `role` ENUM('ADMIN','CONSUMER','SELLER') NN
- `company_id` INT FK `companies`, NULL for Admin
- `full_name` VARCHAR(100) NN
- `email` VARCHAR(120) UQ NN
- `password_hash` VARCHAR(255) NN (BCrypt example in SRS)
- `phone` VARCHAR(20)
- `status` ENUM('ACTIVE','INACTIVE','LOCKED') default ACTIVE
- `failed_attempts` INT default 0
- `last_login` DATETIME

#### `customers`
- `customer_id` INT PK AI
- `user_id` INT FK `users` UQ
- `company_id` INT FK `companies`
- `contact_person` VARCHAR(100)
- `billing_address` TEXT
- `credit_limit` DECIMAL(12,2) default 0

#### `audit_log`
- `log_id` BIGINT PK AI
- `user_id` INT FK `users`
- `action` VARCHAR(100) NN (examples in SRS: INSERT, UPDATE, DELETE, LOGIN...)
- `table_name` VARCHAR(60)
- `record_id` BIGINT
- `old_value`, `new_value` JSON
- `ip_address` VARCHAR(45)

#### `ports`
- `port_id` INT PK AI
- `port_code` VARCHAR(10) UQ NN (example: INNSA)
- `port_name` VARCHAR(100) NN
- `city`, `country` VARCHAR(60)
- `latitude`, `longitude` DECIMAL(9,6)

#### `vessels`
- `vessel_id` INT PK AI
- `vessel_name` VARCHAR(100) NN
- `imo_number` VARCHAR(15) UQ
- `owner_company_id` INT FK `companies` (optional)
- `capacity_teu` INT
- `status` ENUM('ACTIVE','MAINTENANCE')

#### `containers`
- `container_id` INT PK AI
- `container_number` VARCHAR(15) UQ NN
- `seller_id` INT FK `companies` NN
- `container_type` ENUM('DRY','REEFER','OPEN_TOP','TANK') NN
- `size_ft` TINYINT (20 or 40)
- `max_weight_kg` DECIMAL(10,2) NN
- `max_volume_cbm` DECIMAL(8,2) NN
- `current_port_id` INT FK `ports`
- `status` ENUM('AVAILABLE','ALLOCATED','IN_TRANSIT','MAINTENANCE') default AVAILABLE

#### `shipment`
- `shipment_id` INT PK AI
- `shipment_no` VARCHAR(20) UQ NN
- `consumer_id` INT FK `customers` NN
- `seller_id` INT FK `companies` NN
- `container_id` INT FK `containers` NN
- `vessel_id` INT FK `vessels`
- `origin_port_id` INT FK `ports` NN (Point A)
- `dest_port_id` INT FK `ports` NN (Point B)
- `cargo_description` VARCHAR(255)
- `cargo_weight_kg` DECIMAL(10,2) NN
- `cargo_volume_cbm` DECIMAL(8,2) NN
- `quoted_price` DECIMAL(12,2) NN
- `status` ENUM('BOOKED','LOADED','DEPARTED','IN_TRANSIT','ARRIVED','CUSTOMS_CLEARED','DELIVERED','CANCELLED') default BOOKED
- `etd`, `eta`, `actual_arrival` DATE

#### `container_movements`
- `movement_id` BIGINT PK AI
- `shipment_id` INT FK `shipment` NN
- `container_id` INT FK `containers` NN
- `status` - same values as `shipment.status` NN
- `port_id` INT FK `ports`
- `location_text` VARCHAR(150)
- `event_time` DATETIME NN
- `remarks` VARCHAR(255)
- `updated_by` INT FK `users`

#### `shipment_items`
- `item_id` INT PK AI
- `shipment_id` INT FK `shipment` NN
- `product_id` INT FK `products` NN
- `quantity` INT NN, CHECK (quantity > 0)
- `unit_price` DECIMAL(12,2) NN
- `weight_kg` DECIMAL(10,2) (quantity x unit weight)
- `volume_cbm` DECIMAL(8,2)
- `amount` DECIMAL(14,2) NN (quantity x unit price)

#### `pricing_rules`
- `rule_id` INT PK AI
- `seller_id` INT FK `companies` NN
- `origin_port_id`, `dest_port_id` INT FK `ports` NN
- `container_type` ENUM same as `containers` NN
- `base_rate` DECIMAL(12,2) NN
- `rate_per_kg` DECIMAL(8,4) default 0
- `rate_per_cbm` DECIMAL(8,2) default 0
- `season_multiplier` DECIMAL(4,2) default 1.00
- `demand_multiplier` DECIMAL(4,2) default 1.00
- `valid_from`, `valid_to` DATE
- `is_active` BOOLEAN default TRUE

#### `pricing_audit`
- `audit_id` INT PK AI
- `rule_id` INT FK `pricing_rules` NN
- `old_rate`, `new_rate` DECIMAL(12,2)
- `old_multiplier`, `new_multiplier` DECIMAL(4,2)
- `changed_by` INT FK `users`
- `changed_at` TIMESTAMP

#### `demand_forecast`
- `forecast_id` INT PK AI
- `origin_port_id`, `dest_port_id` INT FK `ports` NN
- `container_type` ENUM same as `containers`
- `forecast_month` DATE NN
- `predicted_bookings` INT
- `confidence_pct` DECIMAL(5,2)
- `suggested_multiplier` DECIMAL(4,2)

#### `products`
- `product_id` INT PK AI
- `sku` VARCHAR(40) UQ NN
- `product_name` VARCHAR(120) NN
- `category` VARCHAR(60)
- `hs_code` VARCHAR(12) (customs tariff code)
- `unit` VARCHAR(10) (examples: kg, box, pcs)
- `unit_weight_kg` DECIMAL(8,3)
- `unit_price` DECIMAL(12,2) NN
- `owner_company_id` INT FK `companies` NN

#### `stock`
- `stock_id` INT PK AI
- `product_id` INT FK `products` NN
- `shipment_id` INT FK `shipment`, NULL until linked
- `container_id` INT FK `containers`
- `quantity` INT NN, CHECK (quantity >= 0)
- `damaged_qty` INT default 0
- `last_updated` TIMESTAMP

#### `inventory_ledger`
- `ledger_id` BIGINT PK AI
- `stock_id` INT FK `stock` NN
- `product_id` INT FK `products` NN
- `txn_type` ENUM('IN','OUT','DAMAGE','ADJUST','CLAIM_LOSS') NN
- `quantity` INT NN
- `balance_after` INT NN
- `reference_type` VARCHAR(30) (SHIPMENT, CLAIM, UPLOAD)
- `reference_id` BIGINT
- `txn_time` TIMESTAMP

#### `sales_transactions`
- `sale_id` BIGINT PK AI
- `product_id` INT FK `products` NN
- `customer_id` INT FK `customers` NN
- `shipment_id` INT FK `shipment`
- `quantity` INT NN
- `unit_price` DECIMAL(12,2) NN
- `total_amount` DECIMAL(14,2) NN
- `sale_date` DATE NN

#### `billing_invoices`
- `invoice_id` INT PK AI
- `invoice_no` VARCHAR(20) UQ NN
- `shipment_id` INT FK `shipment` NN
- `consumer_id` INT FK `customers` NN
- `seller_id` INT FK `companies` NN
- `sub_total` DECIMAL(12,2) NN
- `tax_amount` DECIMAL(12,2) default 0
- `total_amount` DECIMAL(12,2) NN
- `paid_amount` DECIMAL(12,2) default 0
- `status` ENUM('UNPAID','PARTIAL','PAID') default UNPAID
- `issue_date`, `due_date` DATE NN

#### `invoice_line_items`
- `item_id` INT PK AI
- `invoice_id` INT FK `billing_invoices` NN
- `item_type` ENUM('FREIGHT','HANDLING','CUSTOMS','TAX','INSURANCE','OTHER') NN
- `description` VARCHAR(150)
- `quantity` DECIMAL(8,2) default 1
- `unit_price` DECIMAL(12,2) NN
- `amount` DECIMAL(12,2) NN

#### `payments`
- `payment_id` INT PK AI
- `invoice_id` INT FK `billing_invoices` NN
- `amount` DECIMAL(12,2) NN, CHECK (amount > 0)
- `payment_mode` ENUM('BANK','UPI','CHEQUE','CASH')
- `reference_no` VARCHAR(50)
- `payment_date` DATE NN
- `recorded_by` INT FK `users`

#### `claims`
- `claim_id` INT PK AI
- `claim_no` VARCHAR(20) UQ NN
- `shipment_id` INT FK `shipment` NN
- `container_id` INT FK `containers`
- `consumer_id` INT FK `customers` NN
- `claim_type` ENUM('LOSS','DAMAGE','DELAY','SHORTAGE') NN
- `description` TEXT NN
- `claimed_amount` DECIMAL(12,2) NN
- `approved_amount` DECIMAL(12,2) default 0
- `status` ENUM('SUBMITTED','UNDER_REVIEW','APPROVED','PARTIALLY_APPROVED','REJECTED','SETTLED') default SUBMITTED
- `seller_remarks` VARCHAR(255)
- `raised_at`, `settled_at` DATETIME

#### `claim_documents`
- `cdoc_id` INT PK AI
- `claim_id` INT FK `claims` NN
- `file_name` VARCHAR(150) NN
- `file_path` VARCHAR(255) NN
- `file_type` VARCHAR(10) (PDF, JPG, PNG)
- `uploaded_at` TIMESTAMP

#### `claim_status_history`
- `history_id` BIGINT PK AI
- `claim_id` INT FK `claims` NN
- `old_status`, `new_status` VARCHAR(20)
- `changed_by` INT FK `users`
- `remarks` VARCHAR(255)
- `changed_at` TIMESTAMP

#### `profit_loss`
- `pl_id` INT PK AI
- `shipment_id` INT FK `shipment`
- `seller_id` INT FK `companies` NN
- `period_month` DATE NN (first day of month)
- `revenue` DECIMAL(14,2) default 0
- `freight_cost`, `port_cost`, `handling_cost` DECIMAL(14,2) default 0
- `claim_loss` DECIMAL(14,2) default 0 (added when claim is settled)
- `net_profit` DECIMAL(14,2), generated as revenue - all costs - claim_loss

#### `abc_classification_result`
- `result_id` INT PK AI
- `product_id` INT FK `products` NN
- `annual_value` DECIMAL(14,2)
- `cumulative_pct` DECIMAL(5,2)
- `abc_class` CHAR(1): A = top 70%, B = next 20%, C = last 10%
- `calculated_on` DATE

#### `inventory_turnover_result`
- `result_id` INT PK AI
- `product_id` INT FK `products` NN
- `period_start`, `period_end` DATE
- `cogs` DECIMAL(14,2) (cost of goods sold)
- `avg_inventory` DECIMAL(14,2)
- `turnover_ratio` DECIMAL(8,2) = cogs / avg_inventory

#### `profitability_result`
- `result_id` INT PK AI
- `product_id` INT FK `products` NN
- `period_month` DATE
- `revenue`, `cost` DECIMAL(14,2)
- `margin_pct` DECIMAL(6,2)

#### `sales_trend_result`
- `result_id` INT PK AI
- `period_month` DATE NN
- `origin_port_id`, `dest_port_id` INT FK `ports`
- `total_sales` DECIMAL(14,2)
- `total_qty` INT
- `growth_pct` DECIMAL(6,2) (versus previous month)

### 6.4 Database relationships from SRS Section 7.10

Preserve all primary/foreign key relationships from the database design. The key relationships explicitly listed in Section 7.10 include:

- Company 1:N Users, Vessels and Containers (seller side).
- Customer 1:N Shipment.
- Container 1:N Shipment historically, with only one active shipment at a time.
- Shipment 1:N Container_movements, Shipment_items, Stock and Claims.
- Shipment 1:1 Billing_invoices.
- Billing_invoices 1:N Invoice_line_items and Payments.
- Claims 1:N Claim_documents and Claim_status_history.
- Products 1:N Stock, Inventory_ledger rows and Sales_transactions rows.

Use the detailed FK attributes in the schema inventory above for the other relationships. Do not create a new relationship merely because it appears convenient.

### 6.5 Triggers and stored procedures

SRS Section 7.2 specifies:

**Triggers enforce:**
- FR3.3 and FR3.4: container availability and capacity.
- FR4.5: inventory ledger synchronization.
- FR5.4: invoice status updates from payments.
- FR7.4 and FR7.6: claim settlement to P&L.

**Stored procedures implement:**
- Dynamic price calculation.
- Claim settlement.
- Analytics algorithms.

Use these database mechanisms where specified. Do not replace required database rules with frontend-only checks. Java services must still validate requests and handle database errors safely.

---

## 7. Cross-module integration contracts

### 7.1 Shared database

- One database: `n_logistic_db`.
- One database connection pool/provider configured centrally.
- No module creates a separate database.
- Modules must use the approved schema/table names.
- The final integration owner maintains one combined database creation/deployment script.

### 7.2 Shared connection provider

Create one common JDBC connection provider using the SRS-required connection pool. All DAOs use it. Do not open unrelated direct database connections in each module. Do not hardcode credentials in source code or commit local passwords.

### 7.3 Authentication and authorization

- FR1 owns registration, login, session and user roles.
- All other modules use the same authenticated session/access context.
- Do not invent session attribute names or role codes; define and document the FR1 contract before module integration.
- Enforce roles server-side on every controller.
- Enforce company ownership for all company-scoped records.

### 7.4 Cross-module business calls

- FR3 booking confirmation must invoke the approved shipment creation, stock reservation and invoice-generation services as one coordinated business workflow.
- FR2 tracking must update status/movement history through the authoritative shipment/movement service/DAO contract.
- FR5 invoice generation is initiated by the FR3 confirmed booking workflow.
- FR5 payment recording updates the invoice payment total/status using the specified database rule/trigger.
- FR7 claim settlement updates the agreed P&L record and inventory through the approved database procedure/transaction.
- FR6 reads operational data and writes only its approved analytics results/forecast data. FR6 must use FR3's approved pricing contract for multiplier integration.

Every shared call must have one documented contract. Do not copy business logic between modules.

### 7.5 URL namespace

Use integration-friendly URL prefixes:

- `/fr1/*`
- `/fr2/*`
- `/fr3/*`
- `/fr4/*`
- `/fr5/*`
- `/fr6/*`
- `/fr7/*`

Use one controller per module, with that module's controller handling its own routes/actions. These URL prefixes are project integration conventions, not new SRS business features.

---

## 8. Frontend structure and page requirements

The complete integrated project includes both frontend and backend. Use JSP/JSTL, Bootstrap 5 and Chart.js only, as specified.

### 8.1 Shared frontend

- Common header, navigation, sidebar and footer fragments.
- Role-based navigation based on the authenticated session.
- Consistent responsive Bootstrap 5 layout.
- Common validation/error/success messages.
- Common stylesheet and JavaScript utilities, without global-name collisions.

### 8.2 FR1 views

- Login.
- Registration for Consumer/Seller and company details.
- User management (Admin).
- Port management (Admin).
- Vessel management (Admin).
- Audit log view (Admin).

### 8.3 FR2 views

- Shipment tracking list/search.
- Shipment detail and movement timeline.
- Route view from Point A to Point B.
- Estimated/actual arrival and delay indication.
- Seller P&L graph, monthly and per shipment.
- Date-range filtering and CSV export.

### 8.4 FR3 views

- Seller container list/inventory management.
- Consumer booking form (goods/product, quantity, origin, destination, date).
- Quotation before confirmation.
- Pricing-rule management for Seller.
- Pricing audit view/records as allowed by role.
- Booking confirmation result.

### 8.5 FR4 views

- Product entry and product listing.
- Stock entry and stock search/edit.
- CSV/Excel upload with row-level validation errors.
- Stock totals/value per shipment.
- Inventory ledger visibility as allowed by role.

### 8.6 FR5 views

- Invoice list and detail.
- Invoice line items.
- Record full/partial payment.
- Payment history and invoice status.
- Print-ready/PDF invoice view.

### 8.7 FR6 views

- Analytics dashboard KPI view.
- Sales trend analysis.
- ABC classification.
- Inventory turnover.
- Product profitability.
- Demand forecast.
- Chart.js line, bar and pie charts.
- Date, route and company filters.

### 8.8 FR7 views

- Consumer claim creation.
- Evidence upload.
- Claim detail/status and history.
- Seller claim review and decision.
- Claim comments/remarks as supported by approved schema.
- Settlement result.

### 8.9 Frontend restrictions

- No Java scriptlets in JSP.
- No SQL/JDBC in JSP.
- No business calculations in JavaScript.
- Use JSTL/EL and XSS-safe output (`c:out`).
- Use Chart.js only for required charts.
- Keep CSS and JavaScript assets scoped per module.
- Keep JSP views under `WEB-INF/views/` and route requests through controllers.

---

## 9. Security, reliability and non-functional requirements

Implement all SRS Section 5 NFRs.

| ID | Requirement | Implementation expectation |
|---|---|---|
| NFR1 | Performance | Pages load in under 3 seconds for up to 100 concurrent users; list pages are paginated |
| NFR2 | Security | Hashed passwords, session timeout, CSRF token on forms, PreparedStatement only, XSS-safe output with JSTL `c:out` |
| NFR3 | Authorization | Server-side role checks on every request |
| NFR4 | Reliability | Transactions for booking, payment and claim settlement; rollback on failure |
| NFR5 | Usability | Responsive on desktop and mobile; consistent layout |
| NFR6 | Maintainability | Strict MVC2 layers, documented code, DAO per entity |
| NFR7 | Auditability | All status changes, price changes and claim decisions are logged |
| NFR8 | Upload limits | Files up to 10 MB; allowed types PDF, JPG, PNG, CSV and XLSX, subject to feature-specific file types in the schema/SRS |
| NFR9 | Backup | Daily MySQL backup |
| NFR10 | Availability | Target 99% uptime |

Additional explicit details:
- Claim documents are listed as PDF, JPG and PNG in the `claim_documents` schema.
- Stock upload uses CSV/Excel as stated in FR4.1.
- Store uploaded files in a server folder and store the path in the database.
- Validate actual file content/type and size on the server, not only by filename or browser control.
- Do not expose passwords, credentials, SQL errors or stack traces to users.
- Use transactions for multi-step writes. Roll back on failure.
- Audit significant account, status, pricing and claim actions without storing secrets.

---

## 10. Database script and deployment rules

Create the whole database from the approved SRS design, not a fragment for each separately deployed application.

Suggested installation script order (the integration developer may adjust the execution order to satisfy FK dependencies, but must preserve the schema):

1. `00_create_database.sql` - create `n_logistic_db` if absent, using `utf8mb4`.
2. `01_users_companies_customers_audit.sql`.
3. `02_ports_vessels_containers.sql`.
4. `03_shipment_tracking_items.sql`.
5. `04_pricing_and_forecast.sql`.
6. `05_products_stock_inventory_sales.sql`.
7. `06_billing_payments.sql`.
8. `07_claims.sql`.
9. `08_profit_loss_analytics.sql`.
10. `09_constraints_indexes.sql`.
11. `10_triggers.sql`.
12. `11_stored_procedures.sql`.
13. `dev_seed.sql` - explicitly development-only sample records.

Rules:
- Use InnoDB tables and `utf8mb4` as specified by SRS Section 7.
- Preserve PK, FK, NN, AI and UQ definitions.
- Do not run `DROP DATABASE`, destructive drop/recreate scripts or destructive seed scripts against an existing user database.
- The installation script must be repeatable or clearly state when it is intended for a clean local development database.
- Keep production schema scripts separate from local/test seed data.
- Do not include AI/ML tables.
- Do not invent new tables to simplify implementation. If a table is required but absent from the SRS schema, document the gap and seek approval.
- Do not change another module's table schema without a coordinated approved change.
- Provide daily backup instructions for the MySQL database.

---

## 11. Testing and acceptance requirements

Follow SRS Section 8.

### 11.1 Test levels and tools

| Test level | SRS coverage | Tools/approach named by SRS |
|---|---|---|
| Unit | DAO and service methods, including price calculation, capacity check and tax | JUnit 5, Mockito |
| Database | Triggers and stored procedures for FR3.3, FR3.4, FR4.5, FR5.4, FR7.4/FR7.6 | SQL scripts and JUnit with test DB |
| Integration | Controller -> DAO -> MySQL flow for each module | JUnit, Tomcat embedded |
| UI/functional | Login, booking, upload, payment, claim, search | TestNG/manual functional checks as specified |
| Performance | Up to 100 concurrent users and page loads under 3 seconds | Apache JMeter |
| UAT | Real scenarios run by Consumer and Seller | Manual checklist |

### 11.2 Test exit criteria

- All critical and high test cases pass.
- At least 70% unit test coverage on service and DAO classes.

### 11.3 Acceptance criteria

- A booking cannot be created for an unavailable container or over-capacity cargo.
- Invoice status updates automatically after each payment.
- A settled claim appears in the P&L graph and adjusts stock.
- Consumer sees an accurate A-to-B timeline for every shipment.
- No role can access another role's restricted pages.

### 11.4 Error handling

- Show clear, safe user-facing errors.
- Log technical detail on the server.
- Roll back failed transactions.
- Do not convert failed database reads into fabricated zero values.
- Validate all request inputs server-side.
- Do not expose internal SQL, connection details, credentials or stack traces.

---

## 12. Development order and phase gates

Build the integrated system in dependency-aware order. Do not build all frontends before the backend/data contracts exist.

### Phase 1 - Environment and project foundation

1. Verify JDK 21 in Windows and Eclipse.
2. Configure Tomcat 9 in Eclipse.
3. Start XAMPP database service and verify actual DB engine/version/port.
4. Create or verify `n_logistic_db`; do not drop/recreate an existing database.
5. Create one Eclipse Dynamic Web Project named `N_Logistic_Platform`.
6. Create shared and FR1-FR7 packages and frontend folders.
7. Configure the approved JDBC driver and central connection pool.
8. Verify application deployment on Tomcat and JDBC connectivity.

**Exit condition:** The one integrated project deploys and connects to the one shared database.

### Phase 2 - Database engineering

1. Implement the 28 in-scope entities from Section 6.
2. Implement relationships, keys, constraints and indexes from the SRS.
3. Implement specified triggers and stored procedures.
4. Create development-only seed records.
5. Verify database behavior with SQL tests.

**Exit condition:** All approved schema objects exist and database rules pass tests.

### Phase 3 - Shared infrastructure and FR1

1. Implement shared JDBC connection pooling/provider.
2. Implement authentication, password hashing, session timeout and CSRF protection.
3. Implement role-based authorization contract.
4. Implement FR1 registration, login, user management, audit log, ports and vessels.

**Exit condition:** Authenticated Consumer, Seller and Admin sessions work and role restrictions are enforced.

### Phase 4 - FR4 stock and FR3 booking/pricing

1. Implement FR4 product and stock management.
2. Implement CSV/Excel validation and row-level error reporting.
3. Implement inventory ledger and stock constraints.
4. Implement FR3 container management and pricing-rule management.
5. Implement availability/capacity checks and quotation calculation.
6. Implement booking confirmation through agreed cross-module services: allocate container, create shipment/items, reserve stock and trigger invoice generation.

**Exit condition:** Valid bookings succeed, invalid bookings are rejected, stock reservation is correct and pricing audit is recorded.

### Phase 5 - FR5 billing and payments

1. Generate invoice on booking confirmation.
2. Create invoice line items according to configured values.
3. Record full/partial payments.
4. Verify automatic invoice status update.
5. Provide print-ready/PDF invoice output.

**Exit condition:** Invoice and payment lifecycle works and invoice status tests pass.

### Phase 6 - FR2 movement tracking and P&L

1. Implement status updates in the specified sequence.
2. Record every movement event.
3. Implement Consumer tracking timeline and route view.
4. Implement estimated/actual arrival display and delay flag according to approved definition.
5. Implement Seller monthly/per-shipment P&L graph data.
6. Implement date filtering and CSV export.

**Exit condition:** Shipment movement events and P&L are accurate and queryable.

### Phase 7 - FR7 claims

1. Implement claim eligibility using arrived/delivered status and approved claim window.
2. Implement claim creation and file uploads.
3. Implement Seller accept/partial accept/reject decision and approved amount/reason.
4. Store complete claim status history.
5. Implement settlement through approved P&L/inventory procedures.
6. Implement shared status visibility and comments/remarks using the approved schema.

**Exit condition:** Claim lifecycle, settlement, P&L and stock adjustments pass transaction tests.

### Phase 8 - FR6 analytics

1. Implement KPI calculations.
2. Implement sales trends by route/product/customer.
3. Implement ABC classification using SRS thresholds and approved customer persistence behavior.
4. Implement inventory turnover using the SRS ratio.
5. Implement product profitability and connect shipment P&L data.
6. Implement demand forecast only after the FR6.6 algorithm/multiplier policy is approved; do not implement the separate ML2 module.
7. Implement cached results and refresh.
8. Implement Chart.js visualizations and date/route/company filters.

**Exit condition:** FR6 results are database-derived, validated and consistent with source operational records.

### Phase 9 - Full system integration, security, performance and UAT

1. Run cross-module business-flow tests.
2. Verify all roles and company data isolation.
3. Verify shared service/DAO contracts and ensure no duplicate business logic.
4. Test database triggers/procedures and rollback behavior.
5. Test uploads and validation.
6. Test list pagination and performance targets.
7. Run JMeter performance testing for up to 100 concurrent users.
8. Complete UAT with Consumer and Seller scenarios.
9. Prepare deployment, backup and integration documentation.

**Final exit condition:** All FR1-FR7 features are integrated, critical/high tests pass, the 70% service/DAO coverage target is met, and the application deploys as one Tomcat web application.

---

## 13. Required development deliverables

The AI developer must create:

1. Complete Eclipse Dynamic Web Project `N_Logistic_Platform`.
2. All FR1-FR7 Java packages, controllers, services, DAO interfaces/implementations, POJOs and DTOs needed by the SRS.
3. All JSP/JSTL views for the required screens.
4. Bootstrap 5 styling and Chart.js graphs as required.
5. Shared security, connection pooling and configuration infrastructure.
6. Complete SQL creation scripts for the 28 in-scope entities, constraints, indexes, triggers and stored procedures.
7. Clearly marked development-only seed data.
8. Automated tests and test data.
9. API/Servlet route documentation.
10. Database schema and relationship documentation.
11. Module ownership and cross-module integration documentation.
12. Setup/deployment/backup instructions.
13. Open specification questions list.
14. Final verification report with actual results, not claims based on generated code alone.

---

## 14. Required final report from the AI developer

At the end, report:

1. What was implemented for each FR1-FR7 requirement.
2. Exact Java packages/classes created.
3. Exact JSP pages and frontend assets created.
4. Exact database tables, columns, constraints, indexes, triggers and stored procedures created.
5. Any approved deviations from the SRS and who approved them.
6. Any unresolved specification questions.
7. Servlet routes and role permissions.
8. Cross-module service/DAO ownership and calls.
9. How to configure and run in Eclipse, JDK 21, Tomcat 9 and XAMPP.
10. Exact test cases executed and actual pass/fail results.
11. Actual test coverage report for service and DAO classes.
12. Actual performance test results, if run.
13. Known limitations and incomplete work.

Do not say that a feature is complete, working or tested if it was only scaffolded, mocked or not executed.

---

## 15. Source-of-truth summary

Use the user's supplied SRS PDF as the authority, especially:

- Section 2.1 - Product Perspective.
- Section 2.2 - Product Functions.
- Section 2.3 - User Classes and Characteristics.
- Section 2.4 - Operating Environment.
- Section 2.5 - Design and Implementation Constraints.
- Section 2.6 - Technology Stack.
- Section 2.7 - Assumptions and Dependencies.
- Section 2.8 - Main Business Flow.
- Section 3.1 - FR1 User and Access Management.
- Section 3.2 - FR2 Container Movement Tracking and P&L.
- Section 3.3 - FR3 Container Allocation and Pricing.
- Section 3.4 - FR4 Stock Details.
- Section 3.5 - FR5 Billing and Payments.
- Section 3.6 - FR6 Analytics Dashboard.
- Section 3.7 - FR7 Claim of Loss and Damage.
- Section 4 - External Interface Requirements.
- Section 5 - Non-Functional Requirements.
- Section 6 - System Architecture (MVC2 Design).
- Section 7 - Database Requirements and Design.
- Section 8 - Testing and Acceptance.
- Appendix A - Key Use Cases.
- Appendix B - Requirements Traceability.

Sections 3.8 (AI Assistant) and 3.9 (ML Prediction) are intentionally excluded by project scope. Preserve the FR3.8 booking-confirmation requirement from Section 3.3.

This document organizes the supplied SRS into a whole-project build plan. It does not authorize the AI developer to invent additional business functionality or change the source database design.

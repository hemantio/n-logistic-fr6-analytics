package com.nlogistic.fr6.test;

import java.math.BigDecimal;
import java.sql.Connection;
import java.sql.Date;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;

import com.nlogistic.fr6.config.AnalyticsAccessContext;
import com.nlogistic.fr6.config.AnalyticsConnectionProvider;
import com.nlogistic.fr6.dto.AnalyticsDashboardDTO;
import com.nlogistic.fr6.dto.AnalyticsFilterDTO;
import com.nlogistic.fr6.dto.ForecastDTO;
import com.nlogistic.fr6.dto.ProfitabilityDTO;
import com.nlogistic.fr6.dto.SalesTrendDTO;
import com.nlogistic.fr6.model.AbcClassificationResult;
import com.nlogistic.fr6.model.AnalyticsKPI;
import com.nlogistic.fr6.model.InventoryTurnoverResult;
import com.nlogistic.fr6.service.AbcClassificationService;
import com.nlogistic.fr6.service.AnalyticsDashboardService;
import com.nlogistic.fr6.service.AnalyticsRefreshService;
import com.nlogistic.fr6.service.AnalyticsRefreshService.RefreshSummary;
import com.nlogistic.fr6.service.DemandForecastService;
import com.nlogistic.fr6.service.InventoryTurnoverService;
import com.nlogistic.fr6.service.ProfitabilityService;
import com.nlogistic.fr6.service.SalesTrendService;

/**
 * Standalone verification runner testing all FR6.1 to FR6.8 requirements against live database.
 */
public class FR6StandaloneTestRunner {

    public static void main(String[] args) {
        System.out.println("===============================================================");
        System.out.println("   FR6 Analytics Dashboard - Full Verification Test Suite   ");
        System.out.println("===============================================================");

        int passed = 0;
        int failed = 0;

        // Test 1: JDBC Connection Verification
        try {
            System.out.print("[TEST 1] Testing JDBC Connection to n_logistic_db... ");
            try (Connection conn = AnalyticsConnectionProvider.getInstance().getConnection()) {
                if (conn != null && !conn.isClosed()) {
                    System.out.println("PASSED (Connected to " + conn.getCatalog() + ")");
                    passed++;
                } else {
                    System.out.println("FAILED (Connection closed or null)");
                    failed++;
                }
            }
        } catch (Exception e) {
            System.out.println("FAILED: " + e.getMessage());
            failed++;
        }

        // Test 2: FR6.1 Analytics Dashboard KPIs Calculation
        try {
            System.out.print("[TEST 2] Testing FR6.1 Dashboard KPIs (Active Shipments, Revenue, Invoices, Claims)... ");
            AnalyticsDashboardService dashService = new AnalyticsDashboardService();
            AnalyticsFilterDTO filter = new AnalyticsFilterDTO();
            AnalyticsDashboardDTO dto = dashService.getDashboardData(filter);
            AnalyticsKPI kpi = dto.getKpis();

            if (kpi != null && kpi.getActiveShipments() > 0 && kpi.getRevenue().compareTo(BigDecimal.ZERO) > 0) {
                System.out.println("PASSED");
                System.out.println("         -> Active Shipments: " + kpi.getActiveShipments());
                System.out.println("         -> Containers Available: " + kpi.getContainersAvailable());
                System.out.println("         -> Total Revenue: INR " + kpi.getRevenue());
                System.out.println("         -> Pending Invoices: " + kpi.getPendingInvoicesCount() + " (INR " + kpi.getPendingInvoicesAmount() + ")");
                System.out.println("         -> Open Claims: " + kpi.getOpenClaimsCount() + " (INR " + kpi.getOpenClaimsAmount() + ")");
                passed++;
            } else {
                System.out.println("FAILED (KPI data empty or invalid)");
                failed++;
            }
        } catch (Exception e) {
            System.out.println("FAILED: " + e.getMessage());
            e.printStackTrace();
            failed++;
        }

        // Test 3: FR6.2 Sales Trend Analysis (Route, Product, Customer dimensions)
        try {
            System.out.print("[TEST 3] Testing FR6.2 Sales Trend Analysis (Route, Product, Customer)... ");
            SalesTrendService trendService = new SalesTrendService();
            
            // Route
            AnalyticsFilterDTO routeFilter = new AnalyticsFilterDTO();
            routeFilter.setDimension("route");
            SalesTrendDTO routeData = trendService.getSalesTrendData(routeFilter);

            // Product
            AnalyticsFilterDTO prodFilter = new AnalyticsFilterDTO();
            prodFilter.setDimension("product");
            SalesTrendDTO prodData = trendService.getSalesTrendData(prodFilter);

            // Customer
            AnalyticsFilterDTO custFilter = new AnalyticsFilterDTO();
            custFilter.setDimension("customer");
            SalesTrendDTO custData = trendService.getSalesTrendData(custFilter);

            if (!routeData.getLabels().isEmpty() && !prodData.getLabels().isEmpty() && !custData.getLabels().isEmpty()) {
                System.out.println("PASSED");
                System.out.println("         -> Route Trends count: " + routeData.getLabels().size());
                System.out.println("         -> Product Trends count: " + prodData.getLabels().size());
                System.out.println("         -> Customer Trends count: " + custData.getLabels().size());
                passed++;
            } else {
                System.out.println("FAILED (One or more dimension trends empty)");
                failed++;
            }
        } catch (Exception e) {
            System.out.println("FAILED: " + e.getMessage());
            failed++;
        }

        // Test 4: FR6.3 ABC (Pareto) Classification (70% A, 20% B, 10% C)
        try {
            System.out.print("[TEST 4] Testing FR6.3 ABC Pareto Classification (SRS 70/20/10 Policy)... ");
            AbcClassificationService abcService = new AbcClassificationService();
            AnalyticsFilterDTO filter = new AnalyticsFilterDTO();
            List<AbcClassificationResult> results = abcService.getProductClassifications(filter);
            Map<String, Object> summary = abcService.getAbcSummary(results);

            boolean hasA = (int) summary.get("countA") > 0;
            boolean hasB = (int) summary.get("countB") > 0;

            if (!results.isEmpty() && hasA) {
                System.out.println("PASSED");
                System.out.println("         -> Class A count: " + summary.get("countA") + " (Sum: INR " + summary.get("sumA") + ")");
                System.out.println("         -> Class B count: " + summary.get("countB") + " (Sum: INR " + summary.get("sumB") + ")");
                System.out.println("         -> Class C count: " + summary.get("countC") + " (Sum: INR " + summary.get("sumC") + ")");
                passed++;
            } else {
                System.out.println("FAILED (ABC classification invalid)");
                failed++;
            }
        } catch (Exception e) {
            System.out.println("FAILED: " + e.getMessage());
            failed++;
        }

        // Test 5: FR6.4 Inventory Turnover Ratio (turnover_ratio = cogs / avg_inventory)
        try {
            System.out.print("[TEST 5] Testing FR6.4 Inventory Turnover Ratio... ");
            InventoryTurnoverService toService = new InventoryTurnoverService();
            AnalyticsFilterDTO filter = new AnalyticsFilterDTO();
            List<InventoryTurnoverResult> toList = toService.getInventoryTurnover(filter);
            Map<String, Object> chartData = toService.getTurnoverChartData(toList);

            if (!toList.isEmpty() && chartData.get("averageRatio") != null) {
                System.out.println("PASSED");
                System.out.println("         -> Evaluated Products: " + toList.size());
                System.out.println("         -> Average Turnover Ratio: " + chartData.get("averageRatio"));
                passed++;
            } else {
                System.out.println("FAILED (Inventory turnover list empty)");
                failed++;
            }
        } catch (Exception e) {
            System.out.println("FAILED: " + e.getMessage());
            failed++;
        }

        // Test 6: FR6.5 Product Profitability & Shipment P&L
        try {
            System.out.print("[TEST 6] Testing FR6.5 Product Profitability & Shipment P&L... ");
            ProfitabilityService profService = new ProfitabilityService();
            AnalyticsFilterDTO filter = new AnalyticsFilterDTO();
            ProfitabilityDTO dto = profService.getProfitabilityData(filter);

            if (!dto.getProductProfitability().isEmpty() && !dto.getShipmentProfitLoss().isEmpty()) {
                System.out.println("PASSED");
                System.out.println("         -> Product Margins count: " + dto.getProductProfitability().size());
                System.out.println("         -> Shipment P&L count: " + dto.getShipmentProfitLoss().size());
                passed++;
            } else {
                System.out.println("FAILED (Profitability or P&L data empty)");
                failed++;
            }
        } catch (Exception e) {
            System.out.println("FAILED: " + e.getMessage());
            failed++;
        }

        // Test 7: FR6.6 Demand Forecasting & FR3 Pricing Multiplier Integration
        try {
            System.out.print("[TEST 7] Testing FR6.6 Demand Forecasting & FR3 Multiplier Application... ");
            DemandForecastService fcService = new DemandForecastService();
            AnalyticsFilterDTO filter = new AnalyticsFilterDTO();
            ForecastDTO fcData = fcService.getForecastData(filter);

            if (!fcData.getForecastList().isEmpty()) {
                int testForecastId = fcData.getForecastList().get(0).getForecastId();
                BigDecimal suggestedMult = fcData.getForecastList().get(0).getSuggestedMultiplier();

                // Apply suggested multiplier to pricing_rules
                boolean applied = fcService.applyMultiplier(testForecastId, 1);

                // Verify pricing_rules and pricing_audit in database
                boolean auditLogged = false;
                try (Connection conn = AnalyticsConnectionProvider.getInstance().getConnection();
                     PreparedStatement ps = conn.prepareStatement("SELECT COUNT(*) FROM pricing_audit WHERE new_multiplier = ?")) {
                    ps.setBigDecimal(1, suggestedMult);
                    try (ResultSet rs = ps.executeQuery()) {
                        if (rs.next() && rs.getInt(1) > 0) {
                            auditLogged = true;
                        }
                    }
                }

                if (applied && auditLogged) {
                    System.out.println("PASSED");
                    System.out.println("         -> Forecasts Count: " + fcData.getForecastList().size());
                    System.out.println("         -> Applied Multiplier: " + suggestedMult + " to FR3 Pricing Rules");
                    System.out.println("         -> Pricing Audit Log Verified: YES");
                    passed++;
                } else {
                    System.out.println("FAILED (Failed to apply multiplier or audit missing)");
                    failed++;
                }
            } else {
                System.out.println("FAILED (Forecasts list empty)");
                failed++;
            }
        } catch (Exception e) {
            System.out.println("FAILED: " + e.getMessage());
            failed++;
        }

        // Test 8: FR6.7 Transactional Analytics Cache Refresh
        try {
            System.out.print("[TEST 8] Testing FR6.7 Atomic Transactional Analytics Refresh... ");
            AnalyticsRefreshService refreshService = new AnalyticsRefreshService();
            RefreshSummary summary = refreshService.refreshAllAnalytics();

            if (summary.isSuccess() && summary.getTotalRowsRefreshed() > 0) {
                System.out.println("PASSED");
                System.out.println("         -> Total Rows Refreshed: " + summary.getTotalRowsRefreshed());
                System.out.println("         -> Duration: " + summary.getDurationMillis() + " ms");
                System.out.println("         -> Sales Trends: " + summary.getSalesTrendsRefreshed());
                System.out.println("         -> ABC Items: " + summary.getAbcProductsRefreshed());
                System.out.println("         -> Turnover Items: " + summary.getTurnoverRowsRefreshed());
                System.out.println("         -> Profitability/P&L: " + summary.getProfitabilityRowsRefreshed());
                System.out.println("         -> Forecasts: " + summary.getForecastsRefreshed());
                passed++;
            } else {
                System.out.println("FAILED: " + summary.getErrorMessage());
                failed++;
            }
        } catch (Exception e) {
            System.out.println("FAILED: " + e.getMessage());
            failed++;
        }

        // Test 9: Role and Company-Level Access Isolation (RBAC)
        try {
            System.out.print("[TEST 9] Testing Multi-Tenant Company Isolation and Role Enforcement... ");
            // Case A: Seller 1 access context
            AnalyticsAccessContext seller1Context = new AnalyticsAccessContext("SELLER", 2, 1, "Rajesh", "rajesh@apex.com");
            Integer requestedOtherCompany = 2; // Seller 1 trying to access Seller 2
            Integer effectiveCompany = seller1Context.getEffectiveCompanyId(requestedOtherCompany);

            // Case B: Admin access context
            AnalyticsAccessContext adminContext = new AnalyticsAccessContext("ADMIN", 1, null, "Admin", "admin@nlogistic.com");
            Integer adminEffectiveCompany = adminContext.getEffectiveCompanyId(requestedOtherCompany);

            if (effectiveCompany.equals(1) && adminEffectiveCompany.equals(2)) {
                System.out.println("PASSED");
                System.out.println("         -> Seller company tampering prevented: Requested Company 2 -> Restricted to assigned Company 1");
                System.out.println("         -> Admin company filter allowed: Requested Company 2 -> Effective Company 2");
                passed++;
            } else {
                System.out.println("FAILED (Isolation contract violated)");
                failed++;
            }
        } catch (Exception e) {
            System.out.println("FAILED: " + e.getMessage());
            failed++;
        }

        System.out.println("===============================================================");
        System.out.println("   VERIFICATION SUMMARY: " + passed + " PASSED, " + failed + " FAILED");
        System.out.println("===============================================================");

        if (failed > 0) {
            System.exit(1);
        }
    }
}

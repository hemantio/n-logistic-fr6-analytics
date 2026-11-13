package com.nlogistic.fr6.tests;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.util.Date;
import java.util.List;

import com.nlogistic.fr6.config.AnalyticsConnectionProvider;
import com.nlogistic.fr6.dao.AnalyticsDAO;
import com.nlogistic.fr6.model.*;
import com.nlogistic.fr6.service.AnalyticsService;
import com.nlogistic.fr6.util.AnalyticsUtil;
import com.nlogistic.fr6.util.AnalyticsUtil.SecurityContext;

/**
 * FR6 Centralized Architecture Automated Verification Suite.
 * Executes all 9 test scenarios verifying pure MVC2 centralized separation of concerns.
 */
public class FR6CentralizedTestRunner {

    private static int passed = 0;
    private static int failed = 0;

    public static void main(String[] args) {
        System.out.println("===============================================================");
        System.out.println("   FR6 Centralized MVC2 - Full Automated Test Suite            ");
        System.out.println("===============================================================");

        AnalyticsDAO dao = new AnalyticsDAO();
        AnalyticsService service = new AnalyticsService(dao);

        Date start = AnalyticsUtil.getDefaultStartDate();
        Date end = AnalyticsUtil.getDefaultEndDate();

        // 1. Database Connection
        testConnection();

        // 2. FR6.1 Dashboard KPIs
        testFR61DashboardKPIs(service, start, end);

        // 3. FR6.2 Sales Trends
        testFR62SalesTrends(service, start, end);

        // 4. FR6.3 ABC Pareto Classification (70/20/10)
        testFR63AbcPareto(service, start, end);

        // 5. FR6.4 Inventory Turnover
        testFR64InventoryTurnover(service, start, end);

        // 6. FR6.5 Profitability & P&L
        testFR65Profitability(service, start, end);

        // 7. FR6.6 Demand Forecasting & FR3 Dynamic Pricing Sync
        testFR66DemandForecastAndPricing(service);

        // 8. FR6.7 Atomic Transactional Refresh
        testFR67AtomicRefresh(service);

        // 9. FR6.8 Multi-Tenant Isolation & RBAC
        testFR68SecurityIsolation();

        System.out.println("===============================================================");
        System.out.printf("   CENTRALIZED TEST SUMMARY: %d PASSED, %d FAILED\n", passed, failed);
        System.out.println("===============================================================");

        if (failed > 0) {
            System.exit(1);
        }
    }

    private static void testConnection() {
        System.out.print("[TEST 1] Testing JDBC Connection to n_logistic_db... ");
        try (Connection conn = AnalyticsConnectionProvider.getConnection()) {
            if (conn != null && !conn.isClosed()) {
                System.out.println("PASSED (Connected successfully)");
                passed++;
            } else {
                System.out.println("FAILED (Connection is null or closed)");
                failed++;
            }
        } catch (Exception e) {
            System.out.println("FAILED: " + e.getMessage());
            failed++;
        }
    }

    private static void testFR61DashboardKPIs(AnalyticsService service, Date start, Date end) {
        System.out.print("[TEST 2] Testing FR6.1 Centralized Dashboard KPIs... ");
        try {
            AnalyticsKPI kpi = service.getDashboardKPIs(start, end, null);
            if (kpi.getActiveShipments() >= 0 && kpi.getContainersAvailable() >= 0) {
                System.out.println("PASSED");
                System.out.printf("         -> Active Shipments: %d, Available Containers: %d, Revenue: INR %.2f\n",
                    kpi.getActiveShipments(), kpi.getContainersAvailable(), kpi.getTotalRevenue());
                passed++;
            } else {
                System.out.println("FAILED (Invalid KPI values)");
                failed++;
            }
        } catch (Exception e) {
            System.out.println("FAILED: " + e.getMessage());
            failed++;
        }
    }

    private static void testFR62SalesTrends(AnalyticsService service, Date start, Date end) {
        System.out.print("[TEST 3] Testing FR6.2 Sales Trend Aggregations (Route/Product/Customer)... ");
        try {
            List<SalesTrendResult> routeTrends = service.getSalesTrends("ROUTE", start, end, null);
            List<SalesTrendResult> productTrends = service.getSalesTrends("PRODUCT", start, end, null);
            List<SalesTrendResult> custTrends = service.getSalesTrends("CUSTOMER", start, end, null);

            if (!routeTrends.isEmpty() && !productTrends.isEmpty() && !custTrends.isEmpty()) {
                System.out.println("PASSED");
                System.out.printf("         -> Routes: %d, Products: %d, Customers: %d\n",
                    routeTrends.size(), productTrends.size(), custTrends.size());
                passed++;
            } else {
                System.out.println("FAILED (Empty trend list)");
                failed++;
            }
        } catch (Exception e) {
            System.out.println("FAILED: " + e.getMessage());
            failed++;
        }
    }

    private static void testFR63AbcPareto(AnalyticsService service, Date start, Date end) {
        System.out.print("[TEST 4] Testing FR6.3 ABC Pareto Classification (70/20/10 Policy)... ");
        try {
            List<AbcClassificationResult> abc = service.calculateProductAbcClassification(start, end, null);
            if (abc != null && !abc.isEmpty()) {
                long countA = abc.stream().filter(a -> "A".equals(a.getAbcClass())).count();
                long countB = abc.stream().filter(a -> "B".equals(a.getAbcClass())).count();
                long countC = abc.stream().filter(a -> "C".equals(a.getAbcClass())).count();

                if (countA > 0 && (countB > 0 || countC > 0)) {
                    System.out.println("PASSED");
                    System.out.printf("         -> Class A: %d, Class B: %d, Class C: %d\n", countA, countB, countC);
                    passed++;
                } else {
                    System.out.println("FAILED (Classification distribution invalid)");
                    failed++;
                }
            } else {
                System.out.println("FAILED (Empty ABC list)");
                failed++;
            }
        } catch (Exception e) {
            System.out.println("FAILED: " + e.getMessage());
            failed++;
        }
    }

    private static void testFR64InventoryTurnover(AnalyticsService service, Date start, Date end) {
        System.out.print("[TEST 5] Testing FR6.4 Inventory Turnover Ratio & Velocity... ");
        try {
            List<InventoryTurnoverResult> turnover = service.calculateInventoryTurnover(start, end, null);
            if (!turnover.isEmpty()) {
                double avgRatio = turnover.stream().mapToDouble(InventoryTurnoverResult::getTurnoverRatio).average().orElse(0.0);
                System.out.println("PASSED");
                System.out.printf("         -> Products Evaluated: %d, Avg Ratio: %.2f\n", turnover.size(), avgRatio);
                passed++;
            } else {
                System.out.println("FAILED (Empty turnover results)");
                failed++;
            }
        } catch (Exception e) {
            System.out.println("FAILED: " + e.getMessage());
            failed++;
        }
    }

    private static void testFR65Profitability(AnalyticsService service, Date start, Date end) {
        System.out.print("[TEST 6] Testing FR6.5 Product Profitability & Shipment P&L... ");
        try {
            List<ProfitabilityResult> margins = service.getProductProfitability(start, end, null);
            List<ProfitLoss> pl = service.getShipmentProfitLoss(start, end, null);
            if (!margins.isEmpty() && !pl.isEmpty()) {
                System.out.println("PASSED");
                System.out.printf("         -> Product Margins: %d, Shipment P&L: %d\n", margins.size(), pl.size());
                passed++;
            } else {
                System.out.println("FAILED (Margins or P&L empty)");
                failed++;
            }
        } catch (Exception e) {
            System.out.println("FAILED: " + e.getMessage());
            failed++;
        }
    }

    private static void testFR66DemandForecastAndPricing(AnalyticsService service) {
        System.out.print("[TEST 7] Testing FR6.6 Demand Forecasting & FR3 Pricing Sync... ");
        try {
            List<DemandForecast> forecasts = service.getDemandForecasts(null, null, null);
            if (!forecasts.isEmpty()) {
                int testId = forecasts.get(0).getForecastId();
                boolean applied = service.applyForecastMultiplier(testId, 1);
                if (applied) {
                    // Check pricing_audit
                    try (Connection conn = AnalyticsConnectionProvider.getConnection();
                         PreparedStatement ps = conn.prepareStatement("SELECT COUNT(*) FROM pricing_audit WHERE rule_id IS NOT NULL");
                         ResultSet rs = ps.executeQuery()) {
                        if (rs.next() && rs.getInt(1) > 0) {
                            System.out.println("PASSED (Multiplier applied & audit verified)");
                            passed++;
                        } else {
                            System.out.println("FAILED (Audit entry missing)");
                            failed++;
                        }
                    }
                } else {
                    System.out.println("FAILED (Could not apply multiplier)");
                    failed++;
                }
            } else {
                System.out.println("FAILED (No forecasts available)");
                failed++;
            }
        } catch (Exception e) {
            System.out.println("FAILED: " + e.getMessage());
            failed++;
        }
    }

    private static void testFR67AtomicRefresh(AnalyticsService service) {
        System.out.print("[TEST 8] Testing FR6.7 Atomic Transactional Analytics Refresh... ");
        try {
            long t0 = System.currentTimeMillis();
            int refreshed = service.refreshAllAnalytics();
            long elapsed = System.currentTimeMillis() - t0;
            if (refreshed > 0) {
                System.out.println("PASSED");
                System.out.printf("         -> Total Rows Refreshed: %d in %d ms\n", refreshed, elapsed);
                passed++;
            } else {
                System.out.println("FAILED (No rows refreshed)");
                failed++;
            }
        } catch (Exception e) {
            System.out.println("FAILED: " + e.getMessage());
            failed++;
        }
    }

    private static void testFR68SecurityIsolation() {
        System.out.print("[TEST 9] Testing FR6.8 Multi-Tenant Isolation & Role Enforcement... ");
        try {
            SecurityContext seller = new SecurityContext(2, "SELLER", 1);
            Integer effectiveForSeller = seller.getEffectiveCompanyId(999);
            if (effectiveForSeller == 1) { // Seller locked to company 1
                SecurityContext admin = new SecurityContext(1, "ADMIN", null);
                Integer effectiveForAdmin = admin.getEffectiveCompanyId(999);
                if (effectiveForAdmin == 999) { // Admin can inspect requested company
                    System.out.println("PASSED");
                    System.out.println("         -> Seller locked to assigned Company 1; Admin allowed filter Company 999");
                    passed++;
                    return;
                }
            }
            System.out.println("FAILED (Isolation logic mismatch)");
            failed++;
        } catch (Exception e) {
            System.out.println("FAILED: " + e.getMessage());
            failed++;
        }
    }
}

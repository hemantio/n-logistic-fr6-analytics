package com.nlogistic.fr6.service;

import java.math.BigDecimal;
import java.sql.SQLException;
import java.util.*;
import java.util.logging.Level;
import java.util.logging.Logger;

import com.nlogistic.fr6.dao.AnalyticsDAO;
import com.nlogistic.fr6.model.*;

/**
 * FR6 Centralized Service Layer.
 * Consolidates all analytical business logic, algorithms, and orchestration for FR6.1 to FR6.8.
 */
public class AnalyticsService {

    private static final Logger LOGGER = Logger.getLogger(AnalyticsService.class.getName());
    private final AnalyticsDAO dao;

    public AnalyticsService() {
        this.dao = new AnalyticsDAO();
    }

    public AnalyticsService(AnalyticsDAO dao) {
        this.dao = dao;
    }

    // ==========================================
    // FR6.1: DASHBOARD KPIS & REFERENCE DATA
    // ==========================================

    public AnalyticsKPI getDashboardKPIs(Date start, Date end, Integer companyId) {
        return getDashboardKPIs(start, end, companyId, "ADMIN");
    }

    public AnalyticsKPI getDashboardKPIs(Date start, Date end, Integer companyId, String role) {
        try {
            return dao.calculateKPIs(start, end, companyId, role);
        } catch (SQLException e) {
            LOGGER.log(Level.SEVERE, "Error calculating dashboard KPIs", e);
            AnalyticsKPI fallback = new AnalyticsKPI();
            fallback.setCalculatedAt(new java.sql.Timestamp(System.currentTimeMillis()));
            return fallback;
        }
    }

    public List<Map<String, Object>> getAvailablePorts() {
        return dao.getAvailablePorts();
    }

    public List<Map<String, Object>> getAvailableCompanies() {
        return dao.getAvailableCompanies();
    }

    // ==========================================
    // FR6.2: SALES TREND AGGREGATION
    // ==========================================

    public List<SalesTrendResult> getSalesTrends(String dimension, Date start, Date end, Integer companyId) {
        if ("PRODUCT".equalsIgnoreCase(dimension)) {
            return dao.getProductSalesTrends(start, end, companyId);
        } else if ("CUSTOMER".equalsIgnoreCase(dimension)) {
            return dao.getCustomerSalesTrends(start, end, companyId);
        } else {
            return dao.getRouteSalesTrends(start, end, null, null);
        }
    }

    // ==========================================
    // FR6.3: ABC PARETO CLASSIFICATION (70 / 20 / 10)
    // ==========================================

    public List<AbcClassificationResult> calculateProductAbcClassification(Date start, Date end, Integer companyId) {
        return dao.getAbcClassifications(start, end, companyId, null);
    }

    public List<AbcClassificationResult> calculateCustomerAbcClassification(Date start, Date end, Integer companyId) {
        return dao.getCustomerAbcAnalysis(start, end, companyId);
    }

    // ==========================================
    // FR6.4: INVENTORY TURNOVER
    // ==========================================

    public List<InventoryTurnoverResult> calculateInventoryTurnover(Date start, Date end, Integer companyId) {
        return dao.getInventoryTurnover(start, end, companyId, null);
    }

    // ==========================================
    // FR6.5: PROFITABILITY & P&L
    // ==========================================

    public List<ProfitabilityResult> getProductProfitability(Date start, Date end, Integer companyId) {
        return dao.getProductProfitability(start, end, companyId, null);
    }

    public List<ProfitLoss> getShipmentProfitLoss(Date start, Date end, Integer companyId) {
        return dao.getShipmentProfitLoss(start, end, companyId);
    }

    // ==========================================
    // FR6.6: DEMAND FORECASTING & FR3 PRICING SYNC
    // ==========================================

    public List<DemandForecast> getDemandForecasts(Integer originPortId, Integer destPortId, String containerType) {
        return dao.getDemandForecasts(originPortId, destPortId, containerType);
    }

    public boolean applyForecastMultiplier(int forecastId, int userId) {
        try {
            return dao.applyForecastMultiplierToPricing(forecastId, null, userId, null);
        } catch (SQLException e) {
            LOGGER.log(Level.SEVERE, "Error applying forecast multiplier to pricing", e);
            return false;
        }
    }

    // ==========================================
    // FR6.7: ATOMIC TRANSACTIONAL REFRESH
    // ==========================================

    public int refreshAllAnalytics() throws SQLException {
        LOGGER.info("Starting centralized atomic refresh across all 6 analytical tables...");
        long t0 = System.currentTimeMillis();
        int affected = dao.refreshAllAnalyticsTransaction();
        long elapsed = System.currentTimeMillis() - t0;
        LOGGER.info("Centralized atomic refresh completed in " + elapsed + " ms. Rows refreshed: " + affected);
        return affected;
    }
}

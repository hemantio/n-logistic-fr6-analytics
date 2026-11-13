package com.nlogistic.fr6.service;

import java.util.List;
import java.util.Map;

import com.nlogistic.fr6.dao.AbcClassificationDAO;
import com.nlogistic.fr6.dao.AnalyticsDashboardDAO;
import com.nlogistic.fr6.dao.DemandForecastDAO;
import com.nlogistic.fr6.dao.InventoryTurnoverDAO;
import com.nlogistic.fr6.dao.ProfitabilityDAO;
import com.nlogistic.fr6.dao.SalesTrendDAO;
import com.nlogistic.fr6.dto.AnalyticsDashboardDTO;
import com.nlogistic.fr6.dto.AnalyticsFilterDTO;
import com.nlogistic.fr6.model.AnalyticsKPI;

/**
 * Service class for FR6.1 Analytics Dashboard overview.
 */
public class AnalyticsDashboardService {

    private final AnalyticsDashboardDAO dashboardDAO;
    private final SalesTrendDAO salesTrendDAO;
    private final AbcClassificationDAO abcDAO;
    private final InventoryTurnoverDAO turnoverDAO;
    private final ProfitabilityDAO profitabilityDAO;
    private final DemandForecastDAO forecastDAO;

    public AnalyticsDashboardService() {
        this.dashboardDAO = new AnalyticsDashboardDAO();
        this.salesTrendDAO = new SalesTrendDAO();
        this.abcDAO = new AbcClassificationDAO();
        this.turnoverDAO = new InventoryTurnoverDAO();
        this.profitabilityDAO = new ProfitabilityDAO();
        this.forecastDAO = new DemandForecastDAO();
    }

    public AnalyticsDashboardService(AnalyticsDashboardDAO dashboardDAO, SalesTrendDAO salesTrendDAO,
                                   AbcClassificationDAO abcDAO, InventoryTurnoverDAO turnoverDAO,
                                   ProfitabilityDAO profitabilityDAO, DemandForecastDAO forecastDAO) {
        this.dashboardDAO = dashboardDAO;
        this.salesTrendDAO = salesTrendDAO;
        this.abcDAO = abcDAO;
        this.turnoverDAO = turnoverDAO;
        this.profitabilityDAO = profitabilityDAO;
        this.forecastDAO = forecastDAO;
    }

    /**
     * Assembles the composite dashboard overview DTO with all 5 mandatory KPIs and key highlights.
     */
    public AnalyticsDashboardDTO getDashboardData(AnalyticsFilterDTO filter) {
        AnalyticsDashboardDTO dto = new AnalyticsDashboardDTO();

        // 1. Mandatory 5 KPIs
        AnalyticsKPI kpis = dashboardDAO.calculateKPIs(filter);
        dto.setKpis(kpis);

        // 2. Highlights for overview widgets
        dto.setRecentTrends(salesTrendDAO.getRouteSalesTrends(filter));
        dto.setTopAbcProducts(abcDAO.getAbcClassifications(filter));
        dto.setTopTurnover(turnoverDAO.getInventoryTurnover(filter));
        dto.setTopProfitable(profitabilityDAO.getProductProfitability(filter));
        dto.setActiveForecasts(forecastDAO.getDemandForecasts(filter));
        dto.setRecentProfitLoss(profitabilityDAO.getShipmentProfitLoss(filter));

        return dto;
    }

    public List<Map<String, Object>> getAvailablePorts() {
        return dashboardDAO.getAvailablePorts();
    }

    public List<Map<String, Object>> getAvailableCompanies() {
        return dashboardDAO.getAvailableCompanies();
    }
}

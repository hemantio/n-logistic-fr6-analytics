package com.nlogistic.fr6.service;

import java.io.Serializable;
import java.sql.Connection;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.util.logging.Level;
import java.util.logging.Logger;

import com.nlogistic.fr6.config.AnalyticsConnectionProvider;
import com.nlogistic.fr6.dao.AbcClassificationDAO;
import com.nlogistic.fr6.dao.DemandForecastDAO;
import com.nlogistic.fr6.dao.InventoryTurnoverDAO;
import com.nlogistic.fr6.dao.ProfitabilityDAO;
import com.nlogistic.fr6.dao.SalesTrendDAO;
import com.nlogistic.fr6.exception.AnalyticsDataException;

/**
 * Service orchestrating transactional recalculation and caching of analytics results (FR6.7).
 */
public class AnalyticsRefreshService {

    private static final Logger LOGGER = Logger.getLogger(AnalyticsRefreshService.class.getName());

    private final AnalyticsConnectionProvider connectionProvider;
    private final SalesTrendDAO salesTrendDAO;
    private final AbcClassificationDAO abcDAO;
    private final InventoryTurnoverDAO turnoverDAO;
    private final ProfitabilityDAO profitabilityDAO;
    private final DemandForecastDAO forecastDAO;

    public AnalyticsRefreshService() {
        this.connectionProvider = AnalyticsConnectionProvider.getInstance();
        this.salesTrendDAO = new SalesTrendDAO(this.connectionProvider);
        this.abcDAO = new AbcClassificationDAO(this.connectionProvider);
        this.turnoverDAO = new InventoryTurnoverDAO(this.connectionProvider);
        this.profitabilityDAO = new ProfitabilityDAO(this.connectionProvider);
        this.forecastDAO = new DemandForecastDAO(this.connectionProvider);
    }

    public static class RefreshSummary implements Serializable {
        private static final long serialVersionUID = 1L;

        private boolean success;
        private int salesTrendsRefreshed;
        private int abcProductsRefreshed;
        private int turnoverRowsRefreshed;
        private int profitabilityRowsRefreshed;
        private int forecastsRefreshed;
        private long durationMillis;
        private Timestamp refreshedAt;
        private String errorMessage;

        public boolean isSuccess() {
            return success;
        }

        public void setSuccess(boolean success) {
            this.success = success;
        }

        public int getSalesTrendsRefreshed() {
            return salesTrendsRefreshed;
        }

        public void setSalesTrendsRefreshed(int salesTrendsRefreshed) {
            this.salesTrendsRefreshed = salesTrendsRefreshed;
        }

        public int getAbcProductsRefreshed() {
            return abcProductsRefreshed;
        }

        public void setAbcProductsRefreshed(int abcProductsRefreshed) {
            this.abcProductsRefreshed = abcProductsRefreshed;
        }

        public int getTurnoverRowsRefreshed() {
            return turnoverRowsRefreshed;
        }

        public void setTurnoverRowsRefreshed(int turnoverRowsRefreshed) {
            this.turnoverRowsRefreshed = turnoverRowsRefreshed;
        }

        public int getProfitabilityRowsRefreshed() {
            return profitabilityRowsRefreshed;
        }

        public void setProfitabilityRowsRefreshed(int profitabilityRowsRefreshed) {
            this.profitabilityRowsRefreshed = profitabilityRowsRefreshed;
        }

        public int getForecastsRefreshed() {
            return forecastsRefreshed;
        }

        public void setForecastsRefreshed(int forecastsRefreshed) {
            this.forecastsRefreshed = forecastsRefreshed;
        }

        public long getDurationMillis() {
            return durationMillis;
        }

        public void setDurationMillis(long durationMillis) {
            this.durationMillis = durationMillis;
        }

        public Timestamp getRefreshedAt() {
            return refreshedAt;
        }

        public void setRefreshedAt(Timestamp refreshedAt) {
            this.refreshedAt = refreshedAt;
        }

        public String getErrorMessage() {
            return errorMessage;
        }

        public void setErrorMessage(String errorMessage) {
            this.errorMessage = errorMessage;
        }

        public int getTotalRowsRefreshed() {
            return salesTrendsRefreshed + abcProductsRefreshed + turnoverRowsRefreshed +
                   profitabilityRowsRefreshed + forecastsRefreshed;
        }
    }

    /**
     * Executes atomic, transactional recalculation across all FR6 cached analytics tables.
     */
    public RefreshSummary refreshAllAnalytics() {
        RefreshSummary summary = new RefreshSummary();
        summary.setRefreshedAt(new Timestamp(System.currentTimeMillis()));
        long start = System.currentTimeMillis();

        try (Connection conn = connectionProvider.getConnection()) {
            conn.setAutoCommit(false);
            try {
                // 1. Refresh Sales Trends
                int stCount = salesTrendDAO.refreshRouteSalesTrends(conn);
                summary.setSalesTrendsRefreshed(stCount);

                // 2. Refresh ABC Classification
                int abcCount = abcDAO.refreshAbcClassification(conn);
                summary.setAbcProductsRefreshed(abcCount);

                // 3. Refresh Inventory Turnover
                int toCount = turnoverDAO.refreshInventoryTurnover(conn, null, null);
                summary.setTurnoverRowsRefreshed(toCount);

                // 4. Refresh Profitability and P&L
                int profCount = profitabilityDAO.refreshProfitability(conn);
                summary.setProfitabilityRowsRefreshed(profCount);

                // 5. Refresh Demand Forecasts
                int fcCount = forecastDAO.refreshDemandForecasts(conn);
                summary.setForecastsRefreshed(fcCount);

                conn.commit();
                summary.setSuccess(true);
                LOGGER.info("Successfully refreshed all analytics cache tables in " + (System.currentTimeMillis() - start) + "ms");
            } catch (SQLException e) {
                conn.rollback();
                summary.setSuccess(false);
                summary.setErrorMessage(e.getMessage());
                LOGGER.log(Level.SEVERE, "Rollback executed during analytics refresh", e);
                throw new AnalyticsDataException("Analytics refresh transaction failed", e);
            } finally {
                conn.setAutoCommit(true);
            }
        } catch (SQLException e) {
            summary.setSuccess(false);
            summary.setErrorMessage(e.getMessage());
            LOGGER.log(Level.SEVERE, "Failed to establish connection for analytics refresh", e);
            throw new AnalyticsDataException("Failed to connect for analytics refresh", e);
        } finally {
            summary.setDurationMillis(System.currentTimeMillis() - start);
        }

        return summary;
    }
}

package com.nlogistic.fr6.dto;

import java.io.Serializable;
import java.util.ArrayList;
import java.util.List;
import com.nlogistic.fr6.model.AbcClassificationResult;
import com.nlogistic.fr6.model.AnalyticsKPI;
import com.nlogistic.fr6.model.DemandForecast;
import com.nlogistic.fr6.model.InventoryTurnoverResult;
import com.nlogistic.fr6.model.ProfitLoss;
import com.nlogistic.fr6.model.ProfitabilityResult;
import com.nlogistic.fr6.model.SalesTrendResult;

/**
 * Composite DTO carrying aggregated data for the main FR6.1 Dashboard overview.
 */
public class AnalyticsDashboardDTO implements Serializable {
    private static final long serialVersionUID = 1L;

    private AnalyticsKPI kpis = new AnalyticsKPI();
    private List<SalesTrendResult> recentTrends = new ArrayList<>();
    private List<AbcClassificationResult> topAbcProducts = new ArrayList<>();
    private List<InventoryTurnoverResult> topTurnover = new ArrayList<>();
    private List<ProfitabilityResult> topProfitable = new ArrayList<>();
    private List<DemandForecast> activeForecasts = new ArrayList<>();
    private List<ProfitLoss> recentProfitLoss = new ArrayList<>();

    public AnalyticsDashboardDTO() {}

    public AnalyticsKPI getKpis() {
        return kpis;
    }

    public void setKpis(AnalyticsKPI kpis) {
        this.kpis = kpis;
    }

    public List<SalesTrendResult> getRecentTrends() {
        return recentTrends;
    }

    public void setRecentTrends(List<SalesTrendResult> recentTrends) {
        this.recentTrends = recentTrends;
    }

    public List<AbcClassificationResult> getTopAbcProducts() {
        return topAbcProducts;
    }

    public void setTopAbcProducts(List<AbcClassificationResult> topAbcProducts) {
        this.topAbcProducts = topAbcProducts;
    }

    public List<InventoryTurnoverResult> getTopTurnover() {
        return topTurnover;
    }

    public void setTopTurnover(List<InventoryTurnoverResult> topTurnover) {
        this.topTurnover = topTurnover;
    }

    public List<ProfitabilityResult> getTopProfitable() {
        return topProfitable;
    }

    public void setTopProfitable(List<ProfitabilityResult> topProfitable) {
        this.topProfitable = topProfitable;
    }

    public List<DemandForecast> getActiveForecasts() {
        return activeForecasts;
    }

    public void setActiveForecasts(List<DemandForecast> activeForecasts) {
        this.activeForecasts = activeForecasts;
    }

    public List<ProfitLoss> getRecentProfitLoss() {
        return recentProfitLoss;
    }

    public void setRecentProfitLoss(List<ProfitLoss> recentProfitLoss) {
        this.recentProfitLoss = recentProfitLoss;
    }
}

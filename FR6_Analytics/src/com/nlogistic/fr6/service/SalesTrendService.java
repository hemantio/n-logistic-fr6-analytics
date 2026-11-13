package com.nlogistic.fr6.service;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

import com.nlogistic.fr6.dao.SalesTrendDAO;
import com.nlogistic.fr6.dto.AnalyticsFilterDTO;
import com.nlogistic.fr6.dto.SalesTrendDTO;
import com.nlogistic.fr6.model.SalesTrendResult;

/**
 * Service class for FR6.2 Sales Trend Analysis.
 * Formats data for Chart.js line charts and supports dimensions (Route, Product, Customer).
 */
public class SalesTrendService {

    private final SalesTrendDAO salesTrendDAO;

    public SalesTrendService() {
        this.salesTrendDAO = new SalesTrendDAO();
    }

    public SalesTrendService(SalesTrendDAO salesTrendDAO) {
        this.salesTrendDAO = salesTrendDAO;
    }

    /**
     * Builds SalesTrendDTO for the requested dimension ("route", "product", or "customer").
     */
    public SalesTrendDTO getSalesTrendData(AnalyticsFilterDTO filter) {
        SalesTrendDTO dto = new SalesTrendDTO();
        String dimension = (filter.getDimension() != null) ? filter.getDimension().toLowerCase() : "route";

        if ("product".equals(dimension)) {
            List<Map<String, Object>> prodTrends = salesTrendDAO.getProductSalesTrends(filter);
            List<String> labels = new ArrayList<>();
            List<BigDecimal> sales = new ArrayList<>();
            List<Integer> quantities = new ArrayList<>();

            for (Map<String, Object> map : prodTrends) {
                String label = map.get("productName") + " (" + map.get("periodMonth") + ")";
                labels.add(label);
                sales.add((BigDecimal) map.get("totalSales"));
                quantities.add((Integer) map.get("totalQty"));
            }
            dto.setLabels(labels);
            dto.setSalesValues(sales);
            dto.setQtyValues(quantities);

        } else if ("customer".equals(dimension)) {
            List<Map<String, Object>> custTrends = salesTrendDAO.getCustomerSalesTrends(filter);
            List<String> labels = new ArrayList<>();
            List<BigDecimal> sales = new ArrayList<>();
            List<Integer> quantities = new ArrayList<>();

            for (Map<String, Object> map : custTrends) {
                String label = map.get("contactPerson") + " (" + map.get("periodMonth") + ")";
                labels.add(label);
                sales.add((BigDecimal) map.get("totalSales"));
                quantities.add((Integer) map.get("totalQty"));
            }
            dto.setLabels(labels);
            dto.setSalesValues(sales);
            dto.setQtyValues(quantities);

        } else {
            // Default: Route-based sales trends (FR6.2 / sales_trend_result table)
            List<SalesTrendResult> rows = salesTrendDAO.getRouteSalesTrends(filter);
            List<String> labels = new ArrayList<>();
            List<BigDecimal> sales = new ArrayList<>();
            List<Integer> quantities = new ArrayList<>();
            List<BigDecimal> growth = new ArrayList<>();

            for (SalesTrendResult r : rows) {
                String label = r.getRouteLabel() + " (" + r.getPeriodMonth() + ")";
                labels.add(label);
                sales.add(r.getTotalSales());
                quantities.add(r.getTotalQty());
                growth.add(r.getGrowthPct());
            }
            dto.setLabels(labels);
            dto.setSalesValues(sales);
            dto.setQtyValues(quantities);
            dto.setGrowthValues(growth);
            dto.setTableRows(rows);
        }

        return dto;
    }

    public List<SalesTrendResult> getRawRouteTrends(AnalyticsFilterDTO filter) {
        return salesTrendDAO.getRouteSalesTrends(filter);
    }
}

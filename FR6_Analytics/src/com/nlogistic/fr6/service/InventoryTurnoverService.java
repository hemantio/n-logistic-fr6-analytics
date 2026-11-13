package com.nlogistic.fr6.service;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import com.nlogistic.fr6.dao.InventoryTurnoverDAO;
import com.nlogistic.fr6.dto.AnalyticsFilterDTO;
import com.nlogistic.fr6.model.InventoryTurnoverResult;

/**
 * Service class for FR6.4 Inventory Turnover Ratio.
 */
public class InventoryTurnoverService {

    private final InventoryTurnoverDAO turnoverDAO;

    public InventoryTurnoverService() {
        this.turnoverDAO = new InventoryTurnoverDAO();
    }

    public InventoryTurnoverService(InventoryTurnoverDAO turnoverDAO) {
        this.turnoverDAO = turnoverDAO;
    }

    public List<InventoryTurnoverResult> getInventoryTurnover(AnalyticsFilterDTO filter) {
        return turnoverDAO.getInventoryTurnover(filter);
    }

    /**
     * Builds summary metrics and Chart.js datasets for inventory turnover.
     */
    public Map<String, Object> getTurnoverChartData(List<InventoryTurnoverResult> list) {
        List<String> labels = new ArrayList<>();
        List<BigDecimal> ratios = new ArrayList<>();
        List<BigDecimal> cogsList = new ArrayList<>();

        BigDecimal sumRatio = BigDecimal.ZERO;
        for (InventoryTurnoverResult r : list) {
            String label = (r.getProductName() != null) ? r.getProductName() : ("Product #" + r.getProductId());
            labels.add(label);
            ratios.add(r.getTurnoverRatio());
            cogsList.add(r.getCogs());
            sumRatio = sumRatio.add(r.getTurnoverRatio());
        }

        BigDecimal avgRatio = BigDecimal.ZERO;
        if (!list.isEmpty()) {
            avgRatio = sumRatio.divide(BigDecimal.valueOf(list.size()), 2, RoundingMode.HALF_UP);
        }

        Map<String, Object> data = new HashMap<>();
        data.put("labels", labels);
        data.put("ratios", ratios);
        data.put("cogs", cogsList);
        data.put("averageRatio", avgRatio);
        return data;
    }
}

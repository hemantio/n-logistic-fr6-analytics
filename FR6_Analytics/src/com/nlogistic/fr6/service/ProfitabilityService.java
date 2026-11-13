package com.nlogistic.fr6.service;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;

import com.nlogistic.fr6.dao.ProfitabilityDAO;
import com.nlogistic.fr6.dto.AnalyticsFilterDTO;
import com.nlogistic.fr6.dto.ProfitabilityDTO;
import com.nlogistic.fr6.model.ProfitLoss;
import com.nlogistic.fr6.model.ProfitabilityResult;

/**
 * Service class for FR6.5 Product and Shipment Profitability.
 */
public class ProfitabilityService {

    private final ProfitabilityDAO profitabilityDAO;

    public ProfitabilityService() {
        this.profitabilityDAO = new ProfitabilityDAO();
    }

    public ProfitabilityService(ProfitabilityDAO profitabilityDAO) {
        this.profitabilityDAO = profitabilityDAO;
    }

    /**
     * Builds structured DTO containing product profitability and shipment P&L with chart datasets.
     */
    public ProfitabilityDTO getProfitabilityData(AnalyticsFilterDTO filter) {
        ProfitabilityDTO dto = new ProfitabilityDTO();

        List<ProfitabilityResult> prodResults = profitabilityDAO.getProductProfitability(filter);
        List<ProfitLoss> plResults = profitabilityDAO.getShipmentProfitLoss(filter);

        dto.setProductProfitability(prodResults);
        dto.setShipmentProfitLoss(plResults);

        List<String> labels = new ArrayList<>();
        List<BigDecimal> revenues = new ArrayList<>();
        List<BigDecimal> costs = new ArrayList<>();
        List<BigDecimal> margins = new ArrayList<>();

        for (ProfitabilityResult r : prodResults) {
            String label = (r.getProductName() != null ? r.getProductName() : ("Prod #" + r.getProductId())) +
                           " (" + r.getPeriodMonth() + ")";
            labels.add(label);
            revenues.add(r.getRevenue());
            costs.add(r.getCost());
            margins.add(r.getMarginPct());
        }

        dto.setLabels(labels);
        dto.setRevenueValues(revenues);
        dto.setCostValues(costs);
        dto.setMarginValues(margins);

        return dto;
    }
}

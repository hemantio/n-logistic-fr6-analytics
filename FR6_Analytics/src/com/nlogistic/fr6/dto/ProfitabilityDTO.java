package com.nlogistic.fr6.dto;

import java.io.Serializable;
import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;
import com.nlogistic.fr6.model.ProfitLoss;
import com.nlogistic.fr6.model.ProfitabilityResult;

/**
 * DTO carrying structured data for FR6.5 Profitability charts and views.
 */
public class ProfitabilityDTO implements Serializable {
    private static final long serialVersionUID = 1L;

    private List<String> labels = new ArrayList<>();
    private List<BigDecimal> revenueValues = new ArrayList<>();
    private List<BigDecimal> costValues = new ArrayList<>();
    private List<BigDecimal> marginValues = new ArrayList<>();
    private List<ProfitabilityResult> productProfitability = new ArrayList<>();
    private List<ProfitLoss> shipmentProfitLoss = new ArrayList<>();

    public ProfitabilityDTO() {}

    public List<String> getLabels() {
        return labels;
    }

    public void setLabels(List<String> labels) {
        this.labels = labels;
    }

    public List<BigDecimal> getRevenueValues() {
        return revenueValues;
    }

    public void setRevenueValues(List<BigDecimal> revenueValues) {
        this.revenueValues = revenueValues;
    }

    public List<BigDecimal> getCostValues() {
        return costValues;
    }

    public void setCostValues(List<BigDecimal> costValues) {
        this.costValues = costValues;
    }

    public List<BigDecimal> getMarginValues() {
        return marginValues;
    }

    public void setMarginValues(List<BigDecimal> marginValues) {
        this.marginValues = marginValues;
    }

    public List<ProfitabilityResult> getProductProfitability() {
        return productProfitability;
    }

    public void setProductProfitability(List<ProfitabilityResult> productProfitability) {
        this.productProfitability = productProfitability;
    }

    public List<ProfitLoss> getShipmentProfitLoss() {
        return shipmentProfitLoss;
    }

    public void setShipmentProfitLoss(List<ProfitLoss> shipmentProfitLoss) {
        this.shipmentProfitLoss = shipmentProfitLoss;
    }
}

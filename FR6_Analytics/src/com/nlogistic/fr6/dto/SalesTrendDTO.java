package com.nlogistic.fr6.dto;

import java.io.Serializable;
import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;
import com.nlogistic.fr6.model.SalesTrendResult;

/**
 * DTO carrying structured data for FR6.2 Sales Trend charts and tabular views.
 */
public class SalesTrendDTO implements Serializable {
    private static final long serialVersionUID = 1L;

    private List<String> labels = new ArrayList<>();
    private List<BigDecimal> salesValues = new ArrayList<>();
    private List<Integer> qtyValues = new ArrayList<>();
    private List<BigDecimal> growthValues = new ArrayList<>();
    private List<SalesTrendResult> tableRows = new ArrayList<>();

    public SalesTrendDTO() {}

    public List<String> getLabels() {
        return labels;
    }

    public void setLabels(List<String> labels) {
        this.labels = labels;
    }

    public List<BigDecimal> getSalesValues() {
        return salesValues;
    }

    public void setSalesValues(List<BigDecimal> salesValues) {
        this.salesValues = salesValues;
    }

    public List<Integer> getQtyValues() {
        return qtyValues;
    }

    public void setQtyValues(List<Integer> qtyValues) {
        this.qtyValues = qtyValues;
    }

    public List<BigDecimal> getGrowthValues() {
        return growthValues;
    }

    public void setGrowthValues(List<BigDecimal> growthValues) {
        this.growthValues = growthValues;
    }

    public List<SalesTrendResult> getTableRows() {
        return tableRows;
    }

    public void setTableRows(List<SalesTrendResult> tableRows) {
        this.tableRows = tableRows;
    }
}

package com.nlogistic.fr6.model;

import java.io.Serializable;
import java.math.BigDecimal;
import java.sql.Date;
import java.sql.Timestamp;

/**
 * POJO representing Sales_trend_result (ERD #10 / SRS 7.9).
 */
public class SalesTrendResult implements Serializable {
    private static final long serialVersionUID = 1L;

    private Integer resultId;
    private Date periodMonth;
    private Integer originPortId;
    private Integer destPortId;
    private BigDecimal totalSales = BigDecimal.ZERO;
    private Integer totalQty = 0;
    private BigDecimal growthPct = BigDecimal.ZERO;
    private Timestamp createdAt;

    // View & Business Logic helper fields
    private String period;
    private String dimension = "ROUTE";
    private String dimensionKey;
    private String dimensionLabel;
    private Integer shipmentCount = 0;
    private Integer companyId;
    private String originPortName;
    private String destPortName;

    public SalesTrendResult() {}

    public Integer getResultId() { return resultId; }
    public void setResultId(Integer resultId) { this.resultId = resultId; }

    public Date getPeriodMonth() { return periodMonth; }
    public void setPeriodMonth(Date periodMonth) { this.periodMonth = periodMonth; }

    public String getPeriod() { 
        return (period != null) ? period : (periodMonth != null ? periodMonth.toString() : ""); 
    }
    public void setPeriod(String period) { this.period = period; }

    public String getDimension() { return dimension; }
    public void setDimension(String dimension) { this.dimension = dimension; }

    public String getDimensionKey() { return dimensionKey; }
    public void setDimensionKey(String dimensionKey) { this.dimensionKey = dimensionKey; }

    public String getDimensionLabel() { return dimensionLabel; }
    public void setDimensionLabel(String dimensionLabel) { this.dimensionLabel = dimensionLabel; }

    public Integer getOriginPortId() { return originPortId; }
    public void setOriginPortId(Integer originPortId) { this.originPortId = originPortId; }

    public Integer getDestPortId() { return destPortId; }
    public void setDestPortId(Integer destPortId) { this.destPortId = destPortId; }

    public BigDecimal getTotalSalesAmount() { return totalSales; }
    public double getTotalSales() { return totalSales.doubleValue(); }
    public void setTotalSales(BigDecimal totalSales) { this.totalSales = (totalSales != null) ? totalSales : BigDecimal.ZERO; }
    public void setTotalSales(double totalSales) { this.totalSales = BigDecimal.valueOf(totalSales); }

    public Integer getTotalQty() { return totalQty; }
    public int getTotalQuantity() { return (totalQty != null) ? totalQty : 0; }
    public void setTotalQty(Integer totalQty) { this.totalQty = (totalQty != null) ? totalQty : 0; }
    public void setTotalQuantity(int qty) { this.totalQty = qty; }

    public Integer getShipmentCount() { return shipmentCount; }
    public void setShipmentCount(Integer shipmentCount) { this.shipmentCount = shipmentCount; }

    public Integer getCompanyId() { return companyId; }
    public void setCompanyId(Integer companyId) { this.companyId = companyId; }

    public BigDecimal getGrowthPct() { return growthPct; }
    public void setGrowthPct(BigDecimal growthPct) { this.growthPct = (growthPct != null) ? growthPct : BigDecimal.ZERO; }

    public Timestamp getCreatedAt() { return createdAt; }
    public void setCreatedAt(Timestamp createdAt) { this.createdAt = createdAt; }

    public String getOriginPortName() { return originPortName; }
    public void setOriginPortName(String originPortName) { this.originPortName = originPortName; }

    public String getDestPortName() { return destPortName; }
    public void setDestPortName(String destPortName) { this.destPortName = destPortName; }

    public String getRouteLabel() {
        if (originPortName != null && destPortName != null) {
            return originPortName + " -> " + destPortName;
        }
        return (dimensionLabel != null) ? dimensionLabel : "Route (" + originPortId + " -> " + destPortId + ")";
    }
}

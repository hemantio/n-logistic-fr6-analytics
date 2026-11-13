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

    // View helper fields
    private String originPortName;
    private String destPortName;

    public SalesTrendResult() {}

    public Integer getResultId() {
        return resultId;
    }

    public void setResultId(Integer resultId) {
        this.resultId = resultId;
    }

    public Date getPeriodMonth() {
        return periodMonth;
    }

    public void setPeriodMonth(Date periodMonth) {
        this.periodMonth = periodMonth;
    }

    public Integer getOriginPortId() {
        return originPortId;
    }

    public void setOriginPortId(Integer originPortId) {
        this.originPortId = originPortId;
    }

    public Integer getDestPortId() {
        return destPortId;
    }

    public void setDestPortId(Integer destPortId) {
        this.destPortId = destPortId;
    }

    public BigDecimal getTotalSales() {
        return totalSales;
    }

    public void setTotalSales(BigDecimal totalSales) {
        this.totalSales = (totalSales != null) ? totalSales : BigDecimal.ZERO;
    }

    public Integer getTotalQty() {
        return totalQty;
    }

    public void setTotalQty(Integer totalQty) {
        this.totalQty = (totalQty != null) ? totalQty : 0;
    }

    public BigDecimal getGrowthPct() {
        return growthPct;
    }

    public void setGrowthPct(BigDecimal growthPct) {
        this.growthPct = (growthPct != null) ? growthPct : BigDecimal.ZERO;
    }

    public Timestamp getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(Timestamp createdAt) {
        this.createdAt = createdAt;
    }

    public String getOriginPortName() {
        return originPortName;
    }

    public void setOriginPortName(String originPortName) {
        this.originPortName = originPortName;
    }

    public String getDestPortName() {
        return destPortName;
    }

    public void setDestPortName(String destPortName) {
        this.destPortName = destPortName;
    }

    public String getRouteLabel() {
        if (originPortName != null && destPortName != null) {
            return originPortName + " -> " + destPortName;
        }
        return "Route (" + originPortId + " -> " + destPortId + ")";
    }
}

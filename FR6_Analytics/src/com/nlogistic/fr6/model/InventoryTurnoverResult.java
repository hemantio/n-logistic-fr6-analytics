package com.nlogistic.fr6.model;

import java.io.Serializable;
import java.math.BigDecimal;
import java.sql.Date;
import java.sql.Timestamp;

/**
 * POJO representing Inventory_turnover_result (ERD #27 / SRS 7.9).
 * Formula per SRS: turnover_ratio = cogs / avg_inventory.
 */
public class InventoryTurnoverResult implements Serializable {
    private static final long serialVersionUID = 1L;

    private Integer resultId;
    private Integer productId;
    private Date periodStart;
    private Date periodEnd;
    private BigDecimal cogs = BigDecimal.ZERO;
    private BigDecimal avgInventory = BigDecimal.ZERO;
    private BigDecimal turnoverRatio = BigDecimal.ZERO;
    private Timestamp createdAt;

    // View helper fields
    private String productName;
    private String sku;

    public InventoryTurnoverResult() {}

    public Integer getResultId() {
        return resultId;
    }

    public void setResultId(Integer resultId) {
        this.resultId = resultId;
    }

    public Integer getProductId() {
        return productId;
    }

    public void setProductId(Integer productId) {
        this.productId = productId;
    }

    public Date getPeriodStart() {
        return periodStart;
    }

    public void setPeriodStart(Date periodStart) {
        this.periodStart = periodStart;
    }

    public Date getPeriodEnd() {
        return periodEnd;
    }

    public void setPeriodEnd(Date periodEnd) {
        this.periodEnd = periodEnd;
    }

    public BigDecimal getCogs() {
        return cogs;
    }

    public void setCogs(BigDecimal cogs) {
        this.cogs = (cogs != null) ? cogs : BigDecimal.ZERO;
    }

    public BigDecimal getAvgInventory() {
        return avgInventory;
    }

    public void setAvgInventory(BigDecimal avgInventory) {
        this.avgInventory = (avgInventory != null) ? avgInventory : BigDecimal.ZERO;
    }

    public BigDecimal getTurnoverRatio() {
        return turnoverRatio;
    }

    public void setTurnoverRatio(BigDecimal turnoverRatio) {
        this.turnoverRatio = (turnoverRatio != null) ? turnoverRatio : BigDecimal.ZERO;
    }

    public Timestamp getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(Timestamp createdAt) {
        this.createdAt = createdAt;
    }

    public String getProductName() {
        return productName;
    }

    public void setProductName(String productName) {
        this.productName = productName;
    }

    public String getSku() {
        return sku;
    }

    public void setSku(String sku) {
        this.sku = sku;
    }
}

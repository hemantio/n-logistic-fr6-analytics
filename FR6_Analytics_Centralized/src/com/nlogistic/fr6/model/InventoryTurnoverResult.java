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

    // View & Business Logic helper fields
    private String productSku;
    private String productName;
    private String sku;
    private String velocityCategory = "MEDIUM";
    private Integer companyId;
    private java.util.Date evaluatedAt = new java.util.Date();

    public InventoryTurnoverResult() {}

    public Integer getResultId() { return resultId; }
    public void setResultId(Integer resultId) { this.resultId = resultId; }

    public Integer getProductId() { return productId; }
    public void setProductId(Integer productId) { this.productId = productId; }

    public Date getPeriodStart() { return periodStart; }
    public void setPeriodStart(Date periodStart) { this.periodStart = periodStart; }

    public Date getPeriodEnd() { return periodEnd; }
    public void setPeriodEnd(Date periodEnd) { this.periodEnd = periodEnd; }

    public BigDecimal getCogsAmount() { return cogs; }
    public double getCogs() { return cogs.doubleValue(); }
    public void setCogs(BigDecimal cogs) { this.cogs = (cogs != null) ? cogs : BigDecimal.ZERO; }
    public void setCogs(double cogs) { this.cogs = BigDecimal.valueOf(cogs); }

    public BigDecimal getAvgInventory() { return avgInventory; }
    public double getAvgInventoryValue() { return avgInventory.doubleValue(); }
    public void setAvgInventory(BigDecimal avgInventory) { this.avgInventory = (avgInventory != null) ? avgInventory : BigDecimal.ZERO; }
    public void setAvgInventoryValue(double val) { this.avgInventory = BigDecimal.valueOf(val); }

    public BigDecimal getTurnoverRatioAmount() { return turnoverRatio; }
    public double getTurnoverRatio() { return turnoverRatio.doubleValue(); }
    public void setTurnoverRatio(BigDecimal turnoverRatio) { this.turnoverRatio = (turnoverRatio != null) ? turnoverRatio : BigDecimal.ZERO; }
    public void setTurnoverRatio(double ratio) { this.turnoverRatio = BigDecimal.valueOf(ratio); }

    public String getProductSku() { return (productSku != null) ? productSku : sku; }
    public void setProductSku(String productSku) { this.productSku = productSku; this.sku = productSku; }

    public String getProductName() { return productName; }
    public void setProductName(String productName) { this.productName = productName; }

    public String getSku() { return (sku != null) ? sku : productSku; }
    public void setSku(String sku) { this.sku = sku; this.productSku = sku; }

    public String getVelocityCategory() { return velocityCategory; }
    public void setVelocityCategory(String velocityCategory) { this.velocityCategory = velocityCategory; }

    public Integer getCompanyId() { return companyId; }
    public void setCompanyId(Integer companyId) { this.companyId = companyId; }

    public java.util.Date getEvaluatedAt() { return evaluatedAt; }
    public void setEvaluatedAt(java.util.Date evaluatedAt) { this.evaluatedAt = evaluatedAt; }

    public Timestamp getCreatedAt() { return createdAt; }
    public void setCreatedAt(Timestamp createdAt) { this.createdAt = createdAt; }
}

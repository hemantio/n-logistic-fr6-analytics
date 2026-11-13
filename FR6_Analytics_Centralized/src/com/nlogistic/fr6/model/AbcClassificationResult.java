package com.nlogistic.fr6.model;

import java.io.Serializable;
import java.math.BigDecimal;
import java.sql.Date;
import java.sql.Timestamp;

/**
 * POJO representing Abc_classification_result (ERD #26 / SRS 7.9).
 * Classification policy per SRS: A = top 70%, B = next 20%, C = last 10%.
 */
public class AbcClassificationResult implements Serializable {
    private static final long serialVersionUID = 1L;

    private Integer resultId;
    private Integer productId;
    private BigDecimal annualValue = BigDecimal.ZERO;
    private BigDecimal cumulativePct = BigDecimal.ZERO;
    private BigDecimal revenuePct = BigDecimal.ZERO;
    private String abcClass;
    private Date calculatedOn;
    private Date periodStart;
    private Date periodEnd;
    private Timestamp createdAt;

    // View & Business Logic helper fields
    private Integer itemId;
    private String itemCode;
    private String itemName;
    private String productName;
    private String sku;
    private String category;
    private int totalQuantity;
    private Integer companyId;

    public AbcClassificationResult() {}

    public Integer getResultId() { return resultId; }
    public void setResultId(Integer resultId) { this.resultId = resultId; }

    public Integer getProductId() { return (productId != null) ? productId : itemId; }
    public void setProductId(Integer productId) { this.productId = productId; this.itemId = productId; }

    public Integer getItemId() { return (itemId != null) ? itemId : productId; }
    public void setItemId(Integer itemId) { this.itemId = itemId; this.productId = itemId; }

    public String getItemCode() { return (itemCode != null) ? itemCode : sku; }
    public void setItemCode(String itemCode) { this.itemCode = itemCode; this.sku = itemCode; }

    public String getItemName() { return (itemName != null) ? itemName : productName; }
    public void setItemName(String itemName) { this.itemName = itemName; this.productName = itemName; }

    public String getProductName() { return (productName != null) ? productName : itemName; }
    public void setProductName(String productName) { this.productName = productName; this.itemName = productName; }

    public String getSku() { return (sku != null) ? sku : itemCode; }
    public void setSku(String sku) { this.sku = sku; this.itemCode = sku; }

    public String getCategory() { return category; }
    public void setCategory(String category) { this.category = category; }

    public BigDecimal getAnnualValue() { return annualValue; }
    public void setAnnualValue(BigDecimal annualValue) { this.annualValue = (annualValue != null) ? annualValue : BigDecimal.ZERO; }

    public double getTotalRevenue() { return annualValue.doubleValue(); }
    public void setTotalRevenue(double totalRevenue) { this.annualValue = BigDecimal.valueOf(totalRevenue); }

    public BigDecimal getCumulativePct() { return cumulativePct; }
    public void setCumulativePct(BigDecimal cumulativePct) { this.cumulativePct = (cumulativePct != null) ? cumulativePct : BigDecimal.ZERO; }

    public double getCumulativePercentage() { return cumulativePct.doubleValue(); }
    public void setCumulativePercentage(double pct) { this.cumulativePct = BigDecimal.valueOf(pct); }

    public double getRevenuePercentage() { return revenuePct.doubleValue(); }
    public void setRevenuePercentage(double pct) { this.revenuePct = BigDecimal.valueOf(pct); }

    public String getAbcClass() { return abcClass; }
    public void setAbcClass(String abcClass) { this.abcClass = abcClass; }

    public Date getCalculatedOn() { return calculatedOn; }
    public void setCalculatedOn(Date calculatedOn) { this.calculatedOn = calculatedOn; }

    public java.util.Date getPeriodStart() { return periodStart; }
    public void setPeriodStart(java.util.Date periodStart) { 
        this.periodStart = (periodStart != null) ? new Date(periodStart.getTime()) : null; 
    }

    public java.util.Date getPeriodEnd() { return periodEnd; }
    public void setPeriodEnd(java.util.Date periodEnd) { 
        this.periodEnd = (periodEnd != null) ? new Date(periodEnd.getTime()) : null; 
    }

    public int getTotalQuantity() { return totalQuantity; }
    public void setTotalQuantity(int totalQuantity) { this.totalQuantity = totalQuantity; }

    public Integer getCompanyId() { return companyId; }
    public void setCompanyId(Integer companyId) { this.companyId = companyId; }

    public Timestamp getCreatedAt() { return createdAt; }
    public void setCreatedAt(Timestamp createdAt) { this.createdAt = createdAt; }
}

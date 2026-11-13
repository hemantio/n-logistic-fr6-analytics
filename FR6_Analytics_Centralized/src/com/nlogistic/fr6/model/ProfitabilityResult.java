package com.nlogistic.fr6.model;

import java.io.Serializable;
import java.math.BigDecimal;
import java.sql.Date;
import java.sql.Timestamp;

/**
 * POJO representing Profitability_result (ERD #28 / SRS 7.9).
 */
public class ProfitabilityResult implements Serializable {
    private static final long serialVersionUID = 1L;

    private Integer resultId;
    private Integer productId;
    private Date periodMonth;
    private BigDecimal revenue = BigDecimal.ZERO;
    private BigDecimal cost = BigDecimal.ZERO;
    private BigDecimal marginPct = BigDecimal.ZERO;
    private Timestamp createdAt;

    // View & Business Logic helper fields
    private String productSku;
    private String productName;
    private String sku;
    private String category;
    private BigDecimal grossProfit = BigDecimal.ZERO;
    private java.util.Date periodStart;
    private java.util.Date periodEnd;
    private Integer companyId;

    public ProfitabilityResult() {}

    public Integer getResultId() { return resultId; }
    public void setResultId(Integer resultId) { this.resultId = resultId; }

    public Integer getProductId() { return productId; }
    public void setProductId(Integer productId) { this.productId = productId; }

    public Date getPeriodMonth() { return periodMonth; }
    public void setPeriodMonth(Date periodMonth) { this.periodMonth = periodMonth; }

    public java.util.Date getPeriodStart() { return periodStart; }
    public void setPeriodStart(java.util.Date periodStart) { this.periodStart = periodStart; }

    public java.util.Date getPeriodEnd() { return periodEnd; }
    public void setPeriodEnd(java.util.Date periodEnd) { this.periodEnd = periodEnd; }

    public BigDecimal getRevenueAmount() { return revenue; }
    public double getTotalRevenue() { return revenue.doubleValue(); }
    public void setRevenue(BigDecimal revenue) { this.revenue = (revenue != null) ? revenue : BigDecimal.ZERO; }
    public void setTotalRevenue(double revenue) { this.revenue = BigDecimal.valueOf(revenue); }

    public BigDecimal getCostAmount() { return cost; }
    public double getTotalCost() { return cost.doubleValue(); }
    public void setCost(BigDecimal cost) { this.cost = (cost != null) ? cost : BigDecimal.ZERO; }
    public void setTotalCost(double cost) { this.cost = BigDecimal.valueOf(cost); }

    public BigDecimal getGrossProfitAmount() { return grossProfit; }
    public double getGrossProfit() { return (grossProfit != null) ? grossProfit.doubleValue() : (getTotalRevenue() - getTotalCost()); }
    public void setGrossProfit(BigDecimal grossProfit) { this.grossProfit = grossProfit; }
    public void setGrossProfit(double grossProfit) { this.grossProfit = BigDecimal.valueOf(grossProfit); }

    public BigDecimal getMarginPct() { return marginPct; }
    public double getGrossMarginPct() { return marginPct.doubleValue(); }
    public void setMarginPct(BigDecimal marginPct) { this.marginPct = (marginPct != null) ? marginPct : BigDecimal.ZERO; }
    public void setGrossMarginPct(double pct) { this.marginPct = BigDecimal.valueOf(pct); }

    public String getProductSku() { return (productSku != null) ? productSku : sku; }
    public void setProductSku(String productSku) { this.productSku = productSku; this.sku = productSku; }

    public String getProductName() { return productName; }
    public void setProductName(String productName) { this.productName = productName; }

    public String getSku() { return (sku != null) ? sku : productSku; }
    public void setSku(String sku) { this.sku = sku; this.productSku = sku; }

    public String getCategory() { return category; }
    public void setCategory(String category) { this.category = category; }

    public Integer getCompanyId() { return companyId; }
    public void setCompanyId(Integer companyId) { this.companyId = companyId; }

    public Timestamp getCreatedAt() { return createdAt; }
    public void setCreatedAt(Timestamp createdAt) { this.createdAt = createdAt; }
}

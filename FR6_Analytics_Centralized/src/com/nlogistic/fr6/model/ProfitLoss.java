package com.nlogistic.fr6.model;

import java.io.Serializable;
import java.math.BigDecimal;
import java.sql.Date;
import java.sql.Timestamp;

/**
 * POJO representing Profit_loss (ERD #12 / SRS 7.9).
 */
public class ProfitLoss implements Serializable {
    private static final long serialVersionUID = 1L;

    private Integer plId;
    private Integer shipmentId;
    private Integer sellerId;
    private Date periodMonth;
    private BigDecimal revenue = BigDecimal.ZERO;
    private BigDecimal freightCost = BigDecimal.ZERO;
    private BigDecimal portCost = BigDecimal.ZERO;
    private BigDecimal handlingCost = BigDecimal.ZERO;
    private BigDecimal claimLoss = BigDecimal.ZERO;
    private BigDecimal netProfit = BigDecimal.ZERO;
    private Timestamp createdAt;

    // View & Business Logic helper fields
    private String sellerName;
    private String shipmentNo;
    private String trackingNumber;
    private String customerName;
    private BigDecimal operatingCost = BigDecimal.ZERO;
    private BigDecimal netMarginPct = BigDecimal.ZERO;
    private Integer companyId;

    public ProfitLoss() {}

    public Integer getPlId() { return plId; }
    public void setPlId(Integer plId) { this.plId = plId; }

    public Integer getShipmentId() { return shipmentId; }
    public void setShipmentId(Integer shipmentId) { this.shipmentId = shipmentId; }

    public Integer getSellerId() { return sellerId; }
    public void setSellerId(Integer sellerId) { this.sellerId = sellerId; }

    public Date getPeriodMonth() { return periodMonth; }
    public void setPeriodMonth(Date periodMonth) { this.periodMonth = periodMonth; }

    public BigDecimal getRevenueAmount() { return revenue; }
    public double getTotalRevenue() { return revenue.doubleValue(); }
    public void setRevenue(BigDecimal revenue) { this.revenue = (revenue != null) ? revenue : BigDecimal.ZERO; }
    public void setTotalRevenue(double revenue) { this.revenue = BigDecimal.valueOf(revenue); }

    public BigDecimal getFreightCost() { return freightCost; }
    public void setFreightCost(BigDecimal freightCost) { this.freightCost = (freightCost != null) ? freightCost : BigDecimal.ZERO; }

    public BigDecimal getPortCost() { return portCost; }
    public void setPortCost(BigDecimal portCost) { this.portCost = (portCost != null) ? portCost : BigDecimal.ZERO; }

    public BigDecimal getHandlingCost() { return handlingCost; }
    public void setHandlingCost(BigDecimal handlingCost) { this.handlingCost = (handlingCost != null) ? handlingCost : BigDecimal.ZERO; }

    public BigDecimal getClaimLoss() { return claimLoss; }
    public void setClaimLoss(BigDecimal claimLoss) { this.claimLoss = (claimLoss != null) ? claimLoss : BigDecimal.ZERO; }

    public BigDecimal getOperatingCostAmount() { return operatingCost; }
    public double getOperatingCost() { return operatingCost.doubleValue(); }
    public void setOperatingCost(BigDecimal operatingCost) { this.operatingCost = operatingCost; }
    public void setOperatingCost(double cost) { this.operatingCost = BigDecimal.valueOf(cost); }

    public BigDecimal getNetProfitAmount() { return netProfit; }
    public double getNetProfit() { return netProfit.doubleValue(); }
    public void setNetProfit(BigDecimal netProfit) { this.netProfit = (netProfit != null) ? netProfit : BigDecimal.ZERO; }
    public void setNetProfit(double netProfit) { this.netProfit = BigDecimal.valueOf(netProfit); }

    public BigDecimal getNetMarginPctAmount() { return netMarginPct; }
    public double getNetMarginPct() { return netMarginPct.doubleValue(); }
    public void setNetMarginPct(BigDecimal netMarginPct) { this.netMarginPct = netMarginPct; }
    public void setNetMarginPct(double pct) { this.netMarginPct = BigDecimal.valueOf(pct); }

    public String getSellerName() { return sellerName; }
    public void setSellerName(String sellerName) { this.sellerName = sellerName; }

    public String getShipmentNo() { return (shipmentNo != null) ? shipmentNo : trackingNumber; }
    public void setShipmentNo(String shipmentNo) { this.shipmentNo = shipmentNo; this.trackingNumber = shipmentNo; }

    public String getTrackingNumber() { return (trackingNumber != null) ? trackingNumber : shipmentNo; }
    public void setTrackingNumber(String trackingNumber) { this.trackingNumber = trackingNumber; this.shipmentNo = trackingNumber; }

    public String getCustomerName() { return customerName; }
    public void setCustomerName(String customerName) { this.customerName = customerName; }

    public Integer getCompanyId() { return companyId; }
    public void setCompanyId(Integer companyId) { this.companyId = companyId; }

    public Timestamp getCreatedAt() { return createdAt; }
    public void setCreatedAt(Timestamp createdAt) { this.createdAt = createdAt; }
}

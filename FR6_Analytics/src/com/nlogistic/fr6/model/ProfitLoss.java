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

    // View helper fields
    private String sellerName;
    private String shipmentNo;

    public ProfitLoss() {}

    public Integer getPlId() {
        return plId;
    }

    public void setPlId(Integer plId) {
        this.plId = plId;
    }

    public Integer getShipmentId() {
        return shipmentId;
    }

    public void setShipmentId(Integer shipmentId) {
        this.shipmentId = shipmentId;
    }

    public Integer getSellerId() {
        return sellerId;
    }

    public void setSellerId(Integer sellerId) {
        this.sellerId = sellerId;
    }

    public Date getPeriodMonth() {
        return periodMonth;
    }

    public void setPeriodMonth(Date periodMonth) {
        this.periodMonth = periodMonth;
    }

    public BigDecimal getRevenue() {
        return revenue;
    }

    public void setRevenue(BigDecimal revenue) {
        this.revenue = (revenue != null) ? revenue : BigDecimal.ZERO;
    }

    public BigDecimal getFreightCost() {
        return freightCost;
    }

    public void setFreightCost(BigDecimal freightCost) {
        this.freightCost = (freightCost != null) ? freightCost : BigDecimal.ZERO;
    }

    public BigDecimal getPortCost() {
        return portCost;
    }

    public void setPortCost(BigDecimal portCost) {
        this.portCost = (portCost != null) ? portCost : BigDecimal.ZERO;
    }

    public BigDecimal getHandlingCost() {
        return handlingCost;
    }

    public void setHandlingCost(BigDecimal handlingCost) {
        this.handlingCost = (handlingCost != null) ? handlingCost : BigDecimal.ZERO;
    }

    public BigDecimal getClaimLoss() {
        return claimLoss;
    }

    public void setClaimLoss(BigDecimal claimLoss) {
        this.claimLoss = (claimLoss != null) ? claimLoss : BigDecimal.ZERO;
    }

    public BigDecimal getNetProfit() {
        return netProfit;
    }

    public void setNetProfit(BigDecimal netProfit) {
        this.netProfit = (netProfit != null) ? netProfit : BigDecimal.ZERO;
    }

    public Timestamp getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(Timestamp createdAt) {
        this.createdAt = createdAt;
    }

    public String getSellerName() {
        return sellerName;
    }

    public void setSellerName(String sellerName) {
        this.sellerName = sellerName;
    }

    public String getShipmentNo() {
        return shipmentNo;
    }

    public void setShipmentNo(String shipmentNo) {
        this.shipmentNo = shipmentNo;
    }
}

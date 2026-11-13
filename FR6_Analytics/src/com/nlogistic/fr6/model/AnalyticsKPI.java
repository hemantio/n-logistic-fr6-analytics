package com.nlogistic.fr6.model;

import java.io.Serializable;
import java.math.BigDecimal;
import java.sql.Timestamp;

/**
 * POJO representing the 5 mandatory KPIs for FR6.1 Analytics Dashboard.
 */
public class AnalyticsKPI implements Serializable {
    private static final long serialVersionUID = 1L;

    private int activeShipments;
    private int containersAvailable;
    private BigDecimal revenue = BigDecimal.ZERO;
    private int pendingInvoicesCount;
    private BigDecimal pendingInvoicesAmount = BigDecimal.ZERO;
    private int openClaimsCount;
    private BigDecimal openClaimsAmount = BigDecimal.ZERO;
    private Timestamp calculatedAt;

    public AnalyticsKPI() {
        this.calculatedAt = new Timestamp(System.currentTimeMillis());
    }

    public int getActiveShipments() {
        return activeShipments;
    }

    public void setActiveShipments(int activeShipments) {
        this.activeShipments = activeShipments;
    }

    public int getContainersAvailable() {
        return containersAvailable;
    }

    public void setContainersAvailable(int containersAvailable) {
        this.containersAvailable = containersAvailable;
    }

    public BigDecimal getRevenue() {
        return revenue;
    }

    public void setRevenue(BigDecimal revenue) {
        this.revenue = (revenue != null) ? revenue : BigDecimal.ZERO;
    }

    public int getPendingInvoicesCount() {
        return pendingInvoicesCount;
    }

    public void setPendingInvoicesCount(int pendingInvoicesCount) {
        this.pendingInvoicesCount = pendingInvoicesCount;
    }

    public BigDecimal getPendingInvoicesAmount() {
        return pendingInvoicesAmount;
    }

    public void setPendingInvoicesAmount(BigDecimal pendingInvoicesAmount) {
        this.pendingInvoicesAmount = (pendingInvoicesAmount != null) ? pendingInvoicesAmount : BigDecimal.ZERO;
    }

    public int getOpenClaimsCount() {
        return openClaimsCount;
    }

    public void setOpenClaimsCount(int openClaimsCount) {
        this.openClaimsCount = openClaimsCount;
    }

    public BigDecimal getOpenClaimsAmount() {
        return openClaimsAmount;
    }

    public void setOpenClaimsAmount(BigDecimal openClaimsAmount) {
        this.openClaimsAmount = (openClaimsAmount != null) ? openClaimsAmount : BigDecimal.ZERO;
    }

    public Timestamp getCalculatedAt() {
        return calculatedAt;
    }

    public void setCalculatedAt(Timestamp calculatedAt) {
        this.calculatedAt = calculatedAt;
    }
}

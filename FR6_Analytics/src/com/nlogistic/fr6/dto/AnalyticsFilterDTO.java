package com.nlogistic.fr6.dto;

import java.io.Serializable;
import java.sql.Date;

/**
 * DTO carrying filter criteria for analytics requests (Date, Route, Company, etc.).
 */
public class AnalyticsFilterDTO implements Serializable {
    private static final long serialVersionUID = 1L;

    private Date startDate;
    private Date endDate;
    private Date periodMonth;
    private Integer originPortId;
    private Integer destPortId;
    private Integer companyId;
    private String userRole;
    private String containerType;
    private Integer productId;
    private Integer customerId;
    private String category;
    private String dimension = "route"; // "route", "product", "customer"

    public AnalyticsFilterDTO() {}

    public Date getStartDate() {
        return startDate;
    }

    public void setStartDate(Date startDate) {
        this.startDate = startDate;
    }

    public Date getEndDate() {
        return endDate;
    }

    public void setEndDate(Date endDate) {
        this.endDate = endDate;
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

    public Integer getCompanyId() {
        return companyId;
    }

    public void setCompanyId(Integer companyId) {
        this.companyId = companyId;
    }

    public String getUserRole() {
        return userRole;
    }

    public void setUserRole(String userRole) {
        this.userRole = userRole;
    }

    public String getContainerType() {
        return containerType;
    }

    public void setContainerType(String containerType) {
        this.containerType = containerType;
    }

    public Integer getProductId() {
        return productId;
    }

    public void setProductId(Integer productId) {
        this.productId = productId;
    }

    public Integer getCustomerId() {
        return customerId;
    }

    public void setCustomerId(Integer customerId) {
        this.customerId = customerId;
    }

    public String getCategory() {
        return category;
    }

    public void setCategory(String category) {
        this.category = category;
    }

    public String getDimension() {
        return dimension;
    }

    public void setDimension(String dimension) {
        this.dimension = (dimension != null) ? dimension : "route";
    }
}

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
    private String abcClass;
    private Date calculatedOn;
    private Timestamp createdAt;

    // View helper fields
    private String productName;
    private String sku;
    private String category;

    public AbcClassificationResult() {}

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

    public BigDecimal getAnnualValue() {
        return annualValue;
    }

    public void setAnnualValue(BigDecimal annualValue) {
        this.annualValue = (annualValue != null) ? annualValue : BigDecimal.ZERO;
    }

    public BigDecimal getCumulativePct() {
        return cumulativePct;
    }

    public void setCumulativePct(BigDecimal cumulativePct) {
        this.cumulativePct = (cumulativePct != null) ? cumulativePct : BigDecimal.ZERO;
    }

    public String getAbcClass() {
        return abcClass;
    }

    public void setAbcClass(String abcClass) {
        this.abcClass = abcClass;
    }

    public Date getCalculatedOn() {
        return calculatedOn;
    }

    public void setCalculatedOn(Date calculatedOn) {
        this.calculatedOn = calculatedOn;
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

    public String getCategory() {
        return category;
    }

    public void setCategory(String category) {
        this.category = category;
    }
}

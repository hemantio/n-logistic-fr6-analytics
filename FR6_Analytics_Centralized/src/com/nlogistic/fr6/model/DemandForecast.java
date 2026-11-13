package com.nlogistic.fr6.model;

import java.io.Serializable;
import java.math.BigDecimal;
import java.sql.Date;
import java.sql.Timestamp;

/**
 * POJO representing Demand_forecast (ERD #8 / SRS 7.5).
 */
public class DemandForecast implements Serializable {
    private static final long serialVersionUID = 1L;

    private Integer forecastId;
    private Integer originPortId;
    private Integer destPortId;
    private String containerType;
    private Date forecastMonth;
    private Integer predictedBookings = 0;
    private BigDecimal confidencePct = BigDecimal.ZERO;
    private BigDecimal suggestedMultiplier = BigDecimal.ONE;
    private Timestamp createdAt;

    // View helper fields
    private String originPortName;
    private String destPortName;

    public DemandForecast() {}

    public Integer getForecastId() { return forecastId; }
    public void setForecastId(Integer forecastId) { this.forecastId = forecastId; }

    public Integer getOriginPortId() { return originPortId; }
    public void setOriginPortId(Integer originPortId) { this.originPortId = originPortId; }

    public Integer getDestPortId() { return destPortId; }
    public void setDestPortId(Integer destPortId) { this.destPortId = destPortId; }

    public String getContainerType() { return containerType; }
    public void setContainerType(String containerType) { this.containerType = containerType; }

    public Date getForecastMonth() { return forecastMonth; }
    public void setForecastMonth(Date forecastMonth) { this.forecastMonth = forecastMonth; }
    public void setForecastMonth(java.util.Date month) { 
        this.forecastMonth = (month != null) ? new Date(month.getTime()) : null; 
    }

    public Integer getPredictedBookings() { return predictedBookings; }
    public void setPredictedBookings(Integer predictedBookings) { 
        this.predictedBookings = (predictedBookings != null) ? predictedBookings : 0; 
    }

    public BigDecimal getConfidencePctAmount() { return confidencePct; }
    public double getConfidencePct() { return (confidencePct != null) ? confidencePct.doubleValue() : 0.0; }
    public void setConfidencePct(BigDecimal confidencePct) { 
        this.confidencePct = (confidencePct != null) ? confidencePct : BigDecimal.ZERO; 
    }
    public void setConfidencePct(double pct) { 
        this.confidencePct = BigDecimal.valueOf(pct); 
    }

    public BigDecimal getSuggestedMultiplierAmount() { return suggestedMultiplier; }
    public double getSuggestedMultiplier() { return (suggestedMultiplier != null) ? suggestedMultiplier.doubleValue() : 1.0; }
    public void setSuggestedMultiplier(BigDecimal suggestedMultiplier) { 
        this.suggestedMultiplier = (suggestedMultiplier != null) ? suggestedMultiplier : BigDecimal.ONE; 
    }
    public void setSuggestedMultiplier(double mult) { 
        this.suggestedMultiplier = BigDecimal.valueOf(mult); 
    }

    public Timestamp getCreatedAt() { return createdAt; }
    public void setCreatedAt(Timestamp createdAt) { this.createdAt = createdAt; }
    public void setCreatedAt(java.util.Date date) { 
        this.createdAt = (date != null) ? new Timestamp(date.getTime()) : null; 
    }

    public String getOriginPortName() { return originPortName; }
    public void setOriginPortName(String originPortName) { this.originPortName = originPortName; }

    public String getDestPortName() { return destPortName; }
    public void setDestPortName(String destPortName) { this.destPortName = destPortName; }

    public String getRouteLabel() {
        if (originPortName != null && destPortName != null) {
            return originPortName + " -> " + destPortName;
        }
        return "Route (" + originPortId + " -> " + destPortId + ")";
    }
}

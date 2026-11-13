package com.nlogistic.fr6.dto;

import java.io.Serializable;
import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;
import com.nlogistic.fr6.model.DemandForecast;

/**
 * DTO carrying data for FR6.6 Demand Forecasting and pricing integration.
 */
public class ForecastDTO implements Serializable {
    private static final long serialVersionUID = 1L;

    private List<String> labels = new ArrayList<>();
    private List<Integer> predictedValues = new ArrayList<>();
    private List<BigDecimal> multiplierValues = new ArrayList<>();
    private List<BigDecimal> confidenceValues = new ArrayList<>();
    private List<DemandForecast> forecastList = new ArrayList<>();
    private String multiplierUpdateMessage;
    private boolean updateSuccess;

    public ForecastDTO() {}

    public List<String> getLabels() {
        return labels;
    }

    public void setLabels(List<String> labels) {
        this.labels = labels;
    }

    public List<Integer> getPredictedValues() {
        return predictedValues;
    }

    public void setPredictedValues(List<Integer> predictedValues) {
        this.predictedValues = predictedValues;
    }

    public List<BigDecimal> getMultiplierValues() {
        return multiplierValues;
    }

    public void setMultiplierValues(List<BigDecimal> multiplierValues) {
        this.multiplierValues = multiplierValues;
    }

    public List<BigDecimal> getConfidenceValues() {
        return confidenceValues;
    }

    public void setConfidenceValues(List<BigDecimal> confidenceValues) {
        this.confidenceValues = confidenceValues;
    }

    public List<DemandForecast> getForecastList() {
        return forecastList;
    }

    public void setForecastList(List<DemandForecast> forecastList) {
        this.forecastList = forecastList;
    }

    public String getMultiplierUpdateMessage() {
        return multiplierUpdateMessage;
    }

    public void setMultiplierUpdateMessage(String multiplierUpdateMessage) {
        this.multiplierUpdateMessage = multiplierUpdateMessage;
    }

    public boolean isUpdateSuccess() {
        return updateSuccess;
    }

    public void setUpdateSuccess(boolean updateSuccess) {
        this.updateSuccess = updateSuccess;
    }
}

package com.nlogistic.fr6.service;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;

import com.nlogistic.fr6.dao.DemandForecastDAO;
import com.nlogistic.fr6.dto.AnalyticsFilterDTO;
import com.nlogistic.fr6.dto.ForecastDTO;
import com.nlogistic.fr6.model.DemandForecast;

/**
 * Service class for FR6.6 Demand Forecasting & FR3 Pricing Multiplier Integration.
 */
public class DemandForecastService {

    private final DemandForecastDAO forecastDAO;

    public DemandForecastService() {
        this.forecastDAO = new DemandForecastDAO();
    }

    public DemandForecastService(DemandForecastDAO forecastDAO) {
        this.forecastDAO = forecastDAO;
    }

    /**
     * Builds ForecastDTO with datasets for Chart.js bar and line charts.
     */
    public ForecastDTO getForecastData(AnalyticsFilterDTO filter) {
        ForecastDTO dto = new ForecastDTO();
        List<DemandForecast> list = forecastDAO.getDemandForecasts(filter);
        dto.setForecastList(list);

        List<String> labels = new ArrayList<>();
        List<Integer> predictions = new ArrayList<>();
        List<BigDecimal> multipliers = new ArrayList<>();
        List<BigDecimal> confidences = new ArrayList<>();

        for (DemandForecast df : list) {
            String label = df.getRouteLabel() + " [" + df.getContainerType() + "]";
            labels.add(label);
            predictions.add(df.getPredictedBookings());
            multipliers.add(df.getSuggestedMultiplier());
            confidences.add(df.getConfidencePct());
        }

        dto.setLabels(labels);
        dto.setPredictedValues(predictions);
        dto.setMultiplierValues(multipliers);
        dto.setConfidenceValues(confidences);

        return dto;
    }

    /**
     * Applies the suggested forecast multiplier to the active FR3 pricing rule and records audit trail.
     */
    public boolean applyMultiplier(int forecastId, Integer updatedByUserId) {
        return forecastDAO.applyForecastMultiplierToPricing(forecastId, updatedByUserId);
    }
}

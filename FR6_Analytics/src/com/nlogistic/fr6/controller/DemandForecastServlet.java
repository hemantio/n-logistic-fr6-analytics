package com.nlogistic.fr6.controller;

import java.io.IOException;
import java.io.PrintWriter;
import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import com.nlogistic.fr6.config.AnalyticsAccessContext;
import com.nlogistic.fr6.dto.AnalyticsFilterDTO;
import com.nlogistic.fr6.dto.ForecastDTO;
import com.nlogistic.fr6.service.AnalyticsDashboardService;
import com.nlogistic.fr6.service.DemandForecastService;
import com.nlogistic.fr6.util.AnalyticsValidationUtil;

/**
 * Controller for FR6.6 Demand Forecasting & Pricing Multiplier Integration.
 * URL Mapping: /fr6/analytics/demand-forecast
 */
@WebServlet(name = "DemandForecastServlet", urlPatterns = {"/fr6/analytics/demand-forecast"})
public class DemandForecastServlet extends HttpServlet {
    private static final long serialVersionUID = 1L;

    private DemandForecastService forecastService;
    private AnalyticsDashboardService dashboardService;

    @Override
    public void init() throws ServletException {
        super.init();
        this.forecastService = new DemandForecastService();
        this.dashboardService = new AnalyticsDashboardService();
    }

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response) 
            throws ServletException, IOException {

        AnalyticsAccessContext accessContext = AnalyticsAccessContext.fromRequest(request);

        AnalyticsFilterDTO filter = new AnalyticsFilterDTO();
        filter.setUserRole(accessContext.getRole());
        filter.setOriginPortId(AnalyticsValidationUtil.parseInteger(request.getParameter("originPortId"), null));
        filter.setDestPortId(AnalyticsValidationUtil.parseInteger(request.getParameter("destPortId"), null));
        filter.setContainerType(AnalyticsValidationUtil.sanitize(request.getParameter("containerType")));

        ForecastDTO forecastData = forecastService.getForecastData(filter);

        String format = request.getParameter("format");
        if ("json".equalsIgnoreCase(format)) {
            response.setContentType("application/json;charset=UTF-8");
            try (PrintWriter out = response.getWriter()) {
                StringBuilder sb = new StringBuilder("{");
                sb.append("\"labels\":[");
                for (int i = 0; i < forecastData.getLabels().size(); i++) {
                    if (i > 0) sb.append(",");
                    sb.append("\"").append(forecastData.getLabels().get(i).replace("\"", "\\\"")).append("\"");
                }
                sb.append("],\"predicted\":[");
                for (int i = 0; i < forecastData.getPredictedValues().size(); i++) {
                    if (i > 0) sb.append(",");
                    sb.append(forecastData.getPredictedValues().get(i));
                }
                sb.append("],\"multipliers\":[");
                for (int i = 0; i < forecastData.getMultiplierValues().size(); i++) {
                    if (i > 0) sb.append(",");
                    sb.append(forecastData.getMultiplierValues().get(i));
                }
                sb.append("],\"confidences\":[");
                for (int i = 0; i < forecastData.getConfidenceValues().size(); i++) {
                    if (i > 0) sb.append(",");
                    sb.append(forecastData.getConfidenceValues().get(i));
                }
                sb.append("]}");
                out.print(sb.toString());
            }
            return;
        }

        request.setAttribute("forecastData", forecastData);
        request.setAttribute("filter", filter);
        request.setAttribute("accessContext", accessContext);
        request.setAttribute("portsList", dashboardService.getAvailablePorts());
        request.setAttribute("activeNav", "demand-forecast");

        request.getRequestDispatcher("/WEB-INF/views/analytics/demand-forecast.jsp").forward(request, response);
    }

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response) 
            throws ServletException, IOException {

        AnalyticsAccessContext accessContext = AnalyticsAccessContext.fromRequest(request);

        // Security check: Only Admin or Seller can update pricing multipliers
        if (accessContext.isConsumer()) {
            response.sendError(HttpServletResponse.SC_FORBIDDEN, "Consumers cannot update pricing multipliers");
            return;
        }

        Integer forecastId = AnalyticsValidationUtil.parseInteger(request.getParameter("forecastId"), null);
        if (forecastId == null) {
            response.sendRedirect(request.getContextPath() + "/fr6/analytics/demand-forecast?error=invalid_id");
            return;
        }

        boolean updated = forecastService.applyMultiplier(forecastId, accessContext.getUserId());
        if (updated) {
            response.sendRedirect(request.getContextPath() + "/fr6/analytics/demand-forecast?success=applied");
        } else {
            response.sendRedirect(request.getContextPath() + "/fr6/analytics/demand-forecast?error=not_found");
        }
    }
}

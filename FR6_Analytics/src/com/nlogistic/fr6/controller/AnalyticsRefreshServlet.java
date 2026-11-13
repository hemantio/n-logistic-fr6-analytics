package com.nlogistic.fr6.controller;

import java.io.IOException;
import java.io.PrintWriter;
import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import com.nlogistic.fr6.config.AnalyticsAccessContext;
import com.nlogistic.fr6.service.AnalyticsRefreshService;
import com.nlogistic.fr6.service.AnalyticsRefreshService.RefreshSummary;

/**
 * Controller for FR6.7 Cached Analytics Results Refresh.
 * URL Mapping: /fr6/analytics/refresh
 */
@WebServlet(name = "AnalyticsRefreshServlet", urlPatterns = {"/fr6/analytics/refresh"})
public class AnalyticsRefreshServlet extends HttpServlet {
    private static final long serialVersionUID = 1L;

    private AnalyticsRefreshService refreshService;

    @Override
    public void init() throws ServletException {
        super.init();
        this.refreshService = new AnalyticsRefreshService();
    }

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response) 
            throws ServletException, IOException {
        doPost(request, response);
    }

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response) 
            throws ServletException, IOException {

        AnalyticsAccessContext accessContext = AnalyticsAccessContext.fromRequest(request);

        // Security check: Only Admin or Seller can trigger analytics cache recalculation
        if (accessContext.isConsumer()) {
            response.sendError(HttpServletResponse.SC_FORBIDDEN, "Consumers cannot trigger analytics cache refresh");
            return;
        }

        try {
            RefreshSummary summary = refreshService.refreshAllAnalytics();

            String format = request.getParameter("format");
            if ("json".equalsIgnoreCase(format)) {
                response.setContentType("application/json;charset=UTF-8");
                try (PrintWriter out = response.getWriter()) {
                    out.print("{" +
                        "\"success\":" + summary.isSuccess() + "," +
                        "\"durationMillis\":" + summary.getDurationMillis() + "," +
                        "\"totalRowsRefreshed\":" + summary.getTotalRowsRefreshed() + "," +
                        "\"salesTrends\":" + summary.getSalesTrendsRefreshed() + "," +
                        "\"abcProducts\":" + summary.getAbcProductsRefreshed() + "," +
                        "\"turnoverRows\":" + summary.getTurnoverRowsRefreshed() + "," +
                        "\"profitabilityRows\":" + summary.getProfitabilityRowsRefreshed() + "," +
                        "\"forecasts\":" + summary.getForecastsRefreshed() +
                    "}");
                }
                return;
            }

            // Otherwise, redirect back to referer or dashboard with status
            String referer = request.getHeader("Referer");
            if (referer != null && referer.contains("/fr6/analytics/")) {
                String sep = referer.contains("?") ? "&" : "?";
                response.sendRedirect(referer + sep + "refresh=success&rows=" + summary.getTotalRowsRefreshed());
            } else {
                response.sendRedirect(request.getContextPath() + "/fr6/analytics/dashboard?refresh=success&rows=" + summary.getTotalRowsRefreshed());
            }

        } catch (Exception e) {
            String format = request.getParameter("format");
            if ("json".equalsIgnoreCase(format)) {
                response.setStatus(HttpServletResponse.SC_INTERNAL_SERVER_ERROR);
                response.setContentType("application/json;charset=UTF-8");
                try (PrintWriter out = response.getWriter()) {
                    out.print("{\"success\":false,\"error\":\"" + e.getMessage().replace("\"", "\\\"") + "\"}");
                }
            } else {
                response.sendRedirect(request.getContextPath() + "/fr6/analytics/dashboard?refresh=error");
            }
        }
    }
}

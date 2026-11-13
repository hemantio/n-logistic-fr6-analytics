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
import com.nlogistic.fr6.dto.SalesTrendDTO;
import com.nlogistic.fr6.service.AnalyticsDashboardService;
import com.nlogistic.fr6.service.SalesTrendService;
import com.nlogistic.fr6.util.AnalyticsDateUtil;
import com.nlogistic.fr6.util.AnalyticsValidationUtil;

/**
 * Controller for FR6.2 Sales Trend Analysis.
 * URL Mapping: /fr6/analytics/sales-trends
 */
@WebServlet(name = "SalesTrendServlet", urlPatterns = {"/fr6/analytics/sales-trends"})
public class SalesTrendServlet extends HttpServlet {
    private static final long serialVersionUID = 1L;

    private SalesTrendService salesTrendService;
    private AnalyticsDashboardService dashboardService;

    @Override
    public void init() throws ServletException {
        super.init();
        this.salesTrendService = new SalesTrendService();
        this.dashboardService = new AnalyticsDashboardService();
    }

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response) 
            throws ServletException, IOException {

        AnalyticsAccessContext accessContext = AnalyticsAccessContext.fromRequest(request);

        AnalyticsFilterDTO filter = new AnalyticsFilterDTO();
        filter.setUserRole(accessContext.getRole());

        Integer requestedCompanyId = AnalyticsValidationUtil.parseInteger(request.getParameter("companyId"), null);
        filter.setCompanyId(accessContext.getEffectiveCompanyId(requestedCompanyId));

        String startParam = AnalyticsValidationUtil.sanitize(request.getParameter("startDate"));
        String endParam = AnalyticsValidationUtil.sanitize(request.getParameter("endDate"));
        filter.setStartDate(startParam != null ? AnalyticsDateUtil.parseDate(startParam) : AnalyticsDateUtil.getDefaultStartDate());
        filter.setEndDate(endParam != null ? AnalyticsDateUtil.parseDate(endParam) : AnalyticsDateUtil.getDefaultEndDate());

        filter.setOriginPortId(AnalyticsValidationUtil.parseInteger(request.getParameter("originPortId"), null));
        filter.setDestPortId(AnalyticsValidationUtil.parseInteger(request.getParameter("destPortId"), null));

        String dimParam = AnalyticsValidationUtil.sanitize(request.getParameter("dimension"));
        if (dimParam != null && !dimParam.isEmpty()) {
            filter.setDimension(dimParam);
        }

        SalesTrendDTO trendData = salesTrendService.getSalesTrendData(filter);

        String format = request.getParameter("format");
        if ("json".equalsIgnoreCase(format)) {
            response.setContentType("application/json;charset=UTF-8");
            try (PrintWriter out = response.getWriter()) {
                StringBuilder sb = new StringBuilder();
                sb.append("{");
                sb.append("\"labels\":[");
                for (int i = 0; i < trendData.getLabels().size(); i++) {
                    if (i > 0) sb.append(",");
                    sb.append("\"").append(escapeJson(trendData.getLabels().get(i))).append("\"");
                }
                sb.append("],\"sales\":[");
                for (int i = 0; i < trendData.getSalesValues().size(); i++) {
                    if (i > 0) sb.append(",");
                    sb.append(trendData.getSalesValues().get(i));
                }
                sb.append("],\"quantities\":[");
                for (int i = 0; i < trendData.getQtyValues().size(); i++) {
                    if (i > 0) sb.append(",");
                    sb.append(trendData.getQtyValues().get(i));
                }
                sb.append("]}");
                out.print(sb.toString());
            }
            return;
        }

        request.setAttribute("trendData", trendData);
        request.setAttribute("filter", filter);
        request.setAttribute("accessContext", accessContext);
        request.setAttribute("portsList", dashboardService.getAvailablePorts());
        request.setAttribute("companiesList", dashboardService.getAvailableCompanies());
        request.setAttribute("activeNav", "sales-trends");

        request.getRequestDispatcher("/WEB-INF/views/analytics/sales-trends.jsp").forward(request, response);
    }

    private String escapeJson(String s) {
        if (s == null) return "";
        return s.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", " ").replace("\r", "");
    }
}

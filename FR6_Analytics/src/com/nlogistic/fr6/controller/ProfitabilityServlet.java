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
import com.nlogistic.fr6.dto.ProfitabilityDTO;
import com.nlogistic.fr6.service.AnalyticsDashboardService;
import com.nlogistic.fr6.service.ProfitabilityService;
import com.nlogistic.fr6.util.AnalyticsDateUtil;
import com.nlogistic.fr6.util.AnalyticsValidationUtil;

/**
 * Controller for FR6.5 Product Profitability & Shipment P&L.
 * URL Mapping: /fr6/analytics/profitability
 */
@WebServlet(name = "ProfitabilityServlet", urlPatterns = {"/fr6/analytics/profitability"})
public class ProfitabilityServlet extends HttpServlet {
    private static final long serialVersionUID = 1L;

    private ProfitabilityService profitabilityService;
    private AnalyticsDashboardService dashboardService;

    @Override
    public void init() throws ServletException {
        super.init();
        this.profitabilityService = new ProfitabilityService();
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

        filter.setProductId(AnalyticsValidationUtil.parseInteger(request.getParameter("productId"), null));

        ProfitabilityDTO dto = profitabilityService.getProfitabilityData(filter);

        String format = request.getParameter("format");
        if ("json".equalsIgnoreCase(format)) {
            response.setContentType("application/json;charset=UTF-8");
            try (PrintWriter out = response.getWriter()) {
                StringBuilder sb = new StringBuilder("{");
                sb.append("\"labels\":[");
                for (int i = 0; i < dto.getLabels().size(); i++) {
                    if (i > 0) sb.append(",");
                    sb.append("\"").append(dto.getLabels().get(i).replace("\"", "\\\"")).append("\"");
                }
                sb.append("],\"revenues\":[");
                for (int i = 0; i < dto.getRevenueValues().size(); i++) {
                    if (i > 0) sb.append(",");
                    sb.append(dto.getRevenueValues().get(i));
                }
                sb.append("],\"costs\":[");
                for (int i = 0; i < dto.getCostValues().size(); i++) {
                    if (i > 0) sb.append(",");
                    sb.append(dto.getCostValues().get(i));
                }
                sb.append("],\"margins\":[");
                for (int i = 0; i < dto.getMarginValues().size(); i++) {
                    if (i > 0) sb.append(",");
                    sb.append(dto.getMarginValues().get(i));
                }
                sb.append("]}");
                out.print(sb.toString());
            }
            return;
        }

        request.setAttribute("profitabilityData", dto);
        request.setAttribute("filter", filter);
        request.setAttribute("accessContext", accessContext);
        request.setAttribute("companiesList", dashboardService.getAvailableCompanies());
        request.setAttribute("activeNav", "profitability");

        request.getRequestDispatcher("/WEB-INF/views/analytics/profitability.jsp").forward(request, response);
    }
}

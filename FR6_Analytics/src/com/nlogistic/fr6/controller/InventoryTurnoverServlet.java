package com.nlogistic.fr6.controller;

import java.io.IOException;
import java.io.PrintWriter;
import java.math.BigDecimal;
import java.util.List;
import java.util.Map;
import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import com.nlogistic.fr6.config.AnalyticsAccessContext;
import com.nlogistic.fr6.dto.AnalyticsFilterDTO;
import com.nlogistic.fr6.model.InventoryTurnoverResult;
import com.nlogistic.fr6.service.AnalyticsDashboardService;
import com.nlogistic.fr6.service.InventoryTurnoverService;
import com.nlogistic.fr6.util.AnalyticsValidationUtil;

/**
 * Controller for FR6.4 Inventory Turnover Ratio.
 * URL Mapping: /fr6/analytics/inventory-turnover
 */
@WebServlet(name = "InventoryTurnoverServlet", urlPatterns = {"/fr6/analytics/inventory-turnover"})
public class InventoryTurnoverServlet extends HttpServlet {
    private static final long serialVersionUID = 1L;

    private InventoryTurnoverService turnoverService;
    private AnalyticsDashboardService dashboardService;

    @Override
    public void init() throws ServletException {
        super.init();
        this.turnoverService = new InventoryTurnoverService();
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
        filter.setProductId(AnalyticsValidationUtil.parseInteger(request.getParameter("productId"), null));

        List<InventoryTurnoverResult> turnoverList = turnoverService.getInventoryTurnover(filter);
        Map<String, Object> chartData = turnoverService.getTurnoverChartData(turnoverList);

        String format = request.getParameter("format");
        if ("json".equalsIgnoreCase(format)) {
            response.setContentType("application/json;charset=UTF-8");
            try (PrintWriter out = response.getWriter()) {
                @SuppressWarnings("unchecked")
                List<String> labels = (List<String>) chartData.get("labels");
                @SuppressWarnings("unchecked")
                List<BigDecimal> ratios = (List<BigDecimal>) chartData.get("ratios");
                @SuppressWarnings("unchecked")
                List<BigDecimal> cogs = (List<BigDecimal>) chartData.get("cogs");

                StringBuilder sb = new StringBuilder("{");
                sb.append("\"labels\":[");
                for (int i = 0; i < labels.size(); i++) {
                    if (i > 0) sb.append(",");
                    sb.append("\"").append(labels.get(i).replace("\"", "\\\"")).append("\"");
                }
                sb.append("],\"ratios\":[");
                for (int i = 0; i < ratios.size(); i++) {
                    if (i > 0) sb.append(",");
                    sb.append(ratios.get(i));
                }
                sb.append("],\"cogs\":[");
                for (int i = 0; i < cogs.size(); i++) {
                    if (i > 0) sb.append(",");
                    sb.append(cogs.get(i));
                }
                sb.append("],\"averageRatio\":").append(chartData.get("averageRatio")).append("}");
                out.print(sb.toString());
            }
            return;
        }

        request.setAttribute("turnoverList", turnoverList);
        request.setAttribute("chartData", chartData);
        request.setAttribute("filter", filter);
        request.setAttribute("accessContext", accessContext);
        request.setAttribute("companiesList", dashboardService.getAvailableCompanies());
        request.setAttribute("activeNav", "inventory-turnover");

        request.getRequestDispatcher("/WEB-INF/views/analytics/inventory-turnover.jsp").forward(request, response);
    }
}

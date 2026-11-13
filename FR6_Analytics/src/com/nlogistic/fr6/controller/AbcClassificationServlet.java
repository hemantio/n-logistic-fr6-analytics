package com.nlogistic.fr6.controller;

import java.io.IOException;
import java.io.PrintWriter;
import java.util.List;
import java.util.Map;
import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import com.nlogistic.fr6.config.AnalyticsAccessContext;
import com.nlogistic.fr6.dto.AnalyticsFilterDTO;
import com.nlogistic.fr6.model.AbcClassificationResult;
import com.nlogistic.fr6.service.AbcClassificationService;
import com.nlogistic.fr6.service.AnalyticsDashboardService;
import com.nlogistic.fr6.util.AnalyticsValidationUtil;

/**
 * Controller for FR6.3 ABC (Pareto) Classification.
 * URL Mapping: /fr6/analytics/abc-classification
 */
@WebServlet(name = "AbcClassificationServlet", urlPatterns = {"/fr6/analytics/abc-classification"})
public class AbcClassificationServlet extends HttpServlet {
    private static final long serialVersionUID = 1L;

    private AbcClassificationService abcService;
    private AnalyticsDashboardService dashboardService;

    @Override
    public void init() throws ServletException {
        super.init();
        this.abcService = new AbcClassificationService();
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
        filter.setCategory(AnalyticsValidationUtil.sanitize(request.getParameter("category")));

        List<AbcClassificationResult> productResults = abcService.getProductClassifications(filter);
        List<Map<String, Object>> customerResults = abcService.getCustomerAbcAnalysis(filter);
        Map<String, Object> abcSummary = abcService.getAbcSummary(productResults);

        String format = request.getParameter("format");
        if ("json".equalsIgnoreCase(format)) {
            response.setContentType("application/json;charset=UTF-8");
            try (PrintWriter out = response.getWriter()) {
                out.print("{" +
                    "\"countA\":" + abcSummary.get("countA") + "," +
                    "\"countB\":" + abcSummary.get("countB") + "," +
                    "\"countC\":" + abcSummary.get("countC") + "," +
                    "\"sumA\":" + abcSummary.get("sumA") + "," +
                    "\"sumB\":" + abcSummary.get("sumB") + "," +
                    "\"sumC\":" + abcSummary.get("sumC") +
                "}");
            }
            return;
        }

        request.setAttribute("productResults", productResults);
        request.setAttribute("customerResults", customerResults);
        request.setAttribute("abcSummary", abcSummary);
        request.setAttribute("filter", filter);
        request.setAttribute("accessContext", accessContext);
        request.setAttribute("companiesList", dashboardService.getAvailableCompanies());
        request.setAttribute("activeNav", "abc-classification");

        request.getRequestDispatcher("/WEB-INF/views/analytics/abc-classification.jsp").forward(request, response);
    }
}

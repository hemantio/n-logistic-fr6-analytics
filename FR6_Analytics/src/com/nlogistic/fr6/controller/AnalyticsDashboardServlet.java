package com.nlogistic.fr6.controller;

import java.io.IOException;
import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import com.nlogistic.fr6.config.AnalyticsAccessContext;
import com.nlogistic.fr6.dto.AnalyticsDashboardDTO;
import com.nlogistic.fr6.dto.AnalyticsFilterDTO;
import com.nlogistic.fr6.service.AnalyticsDashboardService;
import com.nlogistic.fr6.util.AnalyticsDateUtil;
import com.nlogistic.fr6.util.AnalyticsValidationUtil;

/**
 * Controller for FR6.1 Analytics Dashboard overview.
 * URL Mapping: /fr6/analytics/dashboard
 */
@WebServlet(name = "AnalyticsDashboardServlet", urlPatterns = {"/fr6/analytics/dashboard"})
public class AnalyticsDashboardServlet extends HttpServlet {
    private static final long serialVersionUID = 1L;

    private AnalyticsDashboardService dashboardService;

    @Override
    public void init() throws ServletException {
        super.init();
        this.dashboardService = new AnalyticsDashboardService();
    }

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response) 
            throws ServletException, IOException {

        // 1. Role-based Access & Security Context Enforcement
        AnalyticsAccessContext accessContext = AnalyticsAccessContext.fromRequest(request);

        // 2. Extract and sanitize filters
        AnalyticsFilterDTO filter = new AnalyticsFilterDTO();
        filter.setUserRole(accessContext.getRole());

        // Company filter: non-admin can ONLY view their own company
        Integer requestedCompanyId = AnalyticsValidationUtil.parseInteger(request.getParameter("companyId"), null);
        filter.setCompanyId(accessContext.getEffectiveCompanyId(requestedCompanyId));

        // Date filters
        String startParam = AnalyticsValidationUtil.sanitize(request.getParameter("startDate"));
        String endParam = AnalyticsValidationUtil.sanitize(request.getParameter("endDate"));
        filter.setStartDate(startParam != null ? AnalyticsDateUtil.parseDate(startParam) : AnalyticsDateUtil.getDefaultStartDate());
        filter.setEndDate(endParam != null ? AnalyticsDateUtil.parseDate(endParam) : AnalyticsDateUtil.getDefaultEndDate());

        // 3. Delegate to service layer
        AnalyticsDashboardDTO dashboardData = dashboardService.getDashboardData(filter);

        // 4. Bind to request attributes
        request.setAttribute("dashboardData", dashboardData);
        request.setAttribute("filter", filter);
        request.setAttribute("accessContext", accessContext);
        request.setAttribute("portsList", dashboardService.getAvailablePorts());
        request.setAttribute("companiesList", dashboardService.getAvailableCompanies());
        request.setAttribute("activeNav", "dashboard");

        // 5. Forward to JSP View
        request.getRequestDispatcher("/WEB-INF/views/analytics/dashboard.jsp").forward(request, response);
    }
}

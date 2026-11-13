package com.nlogistic.fr6.controller;

import java.io.IOException;
import java.io.PrintWriter;
import java.sql.SQLException;
import java.util.*;
import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import com.nlogistic.fr6.model.*;
import com.nlogistic.fr6.service.AnalyticsService;
import com.nlogistic.fr6.util.AnalyticsUtil;
import com.nlogistic.fr6.util.AnalyticsUtil.SecurityContext;

/**
 * FR6 Centralized Controller Servlet.
 * Consolidates all FR6 HTTP request handling, security filtering, and endpoint dispatching.
 * URL Mapping: /fr6/analytics/*
 */
@WebServlet(name = "AnalyticsServlet", urlPatterns = {"/fr6/analytics/*"})
public class AnalyticsServlet extends HttpServlet {

    private static final long serialVersionUID = 1L;

    private AnalyticsService service;

    @Override
    public void init() throws ServletException {
        super.init();
        this.service = new AnalyticsService();
    }

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response) 
            throws ServletException, IOException {

        // 1. Security Context & Multi-Tenant Company Isolation (FR6.8)
        SecurityContext security = AnalyticsUtil.extractSecurityContext(request);
        Integer requestedCompanyId = AnalyticsUtil.parseInteger(request.getParameter("companyId"), null);
        Integer effectiveCompanyId = security.getEffectiveCompanyId(requestedCompanyId);

        // 2. Date Filtering (FR6.8)
        String startParam = AnalyticsUtil.sanitize(request.getParameter("startDate"));
        String endParam = AnalyticsUtil.sanitize(request.getParameter("endDate"));
        Date startDate = (startParam != null) ? AnalyticsUtil.parseDate(startParam) : AnalyticsUtil.getDefaultStartDate();
        Date endDate = (endParam != null) ? AnalyticsUtil.parseDate(endParam) : AnalyticsUtil.getDefaultEndDate();

        // 3. Common View Attributes
        request.setAttribute("startDate", AnalyticsUtil.formatDate(startDate));
        request.setAttribute("endDate", AnalyticsUtil.formatDate(endDate));
        request.setAttribute("effectiveCompanyId", effectiveCompanyId);
        request.setAttribute("securityContext", security);
        request.setAttribute("companiesList", service.getAvailableCompanies());
        request.setAttribute("portsList", service.getAvailablePorts());

        // 4. Path Routing
        String path = request.getPathInfo();
        if (path == null || path.isEmpty() || "/".equals(path) || "/dashboard".equalsIgnoreCase(path) || "/kpis".equalsIgnoreCase(path)) {
            handleDashboard(request, response, startDate, endDate, effectiveCompanyId);
        } else if ("/sales-trends".equalsIgnoreCase(path)) {
            handleSalesTrends(request, response, startDate, endDate, effectiveCompanyId);
        } else if ("/abc".equalsIgnoreCase(path) || "/abc-classification".equalsIgnoreCase(path)) {
            handleAbc(request, response, startDate, endDate, effectiveCompanyId);
        } else if ("/inventory-turnover".equalsIgnoreCase(path)) {
            handleTurnover(request, response, startDate, endDate, effectiveCompanyId);
        } else if ("/profitability".equalsIgnoreCase(path)) {
            handleProfitability(request, response, startDate, endDate, effectiveCompanyId);
        } else if ("/forecast".equalsIgnoreCase(path) || "/demand-forecast".equalsIgnoreCase(path)) {
            handleForecast(request, response);
        } else if ("/refresh".equalsIgnoreCase(path)) {
            response.sendRedirect(request.getContextPath() + "/fr6/analytics/dashboard");
        } else {
            response.sendError(HttpServletResponse.SC_NOT_FOUND, "Resource not found under /fr6/analytics" + path);
        }
    }

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response) 
            throws ServletException, IOException {

        SecurityContext security = AnalyticsUtil.extractSecurityContext(request);
        String path = request.getPathInfo();

        if ("/refresh".equalsIgnoreCase(path)) {
            // Atomic Transactional Refresh (FR6.7)
            try {
                int count = service.refreshAllAnalytics();
                String format = request.getParameter("format");
                if ("json".equalsIgnoreCase(format)) {
                    response.setContentType("application/json;charset=UTF-8");
                    response.getWriter().write("{\"status\":\"success\",\"refreshed_rows\":" + count + "}");
                } else {
                    response.sendRedirect(request.getContextPath() + "/fr6/analytics/dashboard?refresh=success&count=" + count);
                }
            } catch (SQLException e) {
                response.sendError(HttpServletResponse.SC_INTERNAL_SERVER_ERROR, "Cache refresh failed: " + e.getMessage());
            }
        } else if ("/forecast".equalsIgnoreCase(path) || "/demand-forecast".equalsIgnoreCase(path)) {
            // FR6.6 -> FR3 Dynamic Pricing Multiplier Sync
            Integer forecastId = AnalyticsUtil.parseInteger(request.getParameter("forecastId"), null);
            if (forecastId == null) {
                response.sendRedirect(request.getContextPath() + "/fr6/analytics/demand-forecast?error=invalid_id");
                return;
            }
            boolean success = service.applyForecastMultiplier(forecastId, security.getUserId());
            if (success) {
                response.sendRedirect(request.getContextPath() + "/fr6/analytics/demand-forecast?success=applied");
            } else {
                response.sendRedirect(request.getContextPath() + "/fr6/analytics/demand-forecast?error=not_found");
            }
        } else {
            response.sendError(HttpServletResponse.SC_METHOD_NOT_ALLOWED);
        }
    }

    // ==========================================
    // ROUTE HANDLERS
    // ==========================================

    private void handleDashboard(HttpServletRequest req, HttpServletResponse resp, Date start, Date end, Integer compId) 
            throws ServletException, IOException {

        AnalyticsKPI kpis = service.getDashboardKPIs(start, end, compId);
        List<SalesTrendResult> previewTrends = service.getSalesTrends("ROUTE", start, end, compId);
        List<AbcClassificationResult> previewAbc = service.calculateProductAbcClassification(start, end, compId);

        req.setAttribute("kpi", kpis);
        req.setAttribute("salesTrends", previewTrends);
        req.setAttribute("abcItems", previewAbc);
        req.setAttribute("activeNav", "dashboard");

        if (isJsonRequested(req)) {
            resp.setContentType("application/json;charset=UTF-8");
            try (PrintWriter out = resp.getWriter()) {
                out.printf("{\"activeShipments\":%d,\"availableContainers\":%d,\"totalRevenue\":%.2f,\"pendingInvoicesCount\":%d,\"pendingInvoicesAmount\":%.2f,\"openClaimsCount\":%d,\"openClaimsAmount\":%.2f}",
                    kpis.getActiveShipments(), kpis.getAvailableContainers(), kpis.getTotalRevenue(),
                    kpis.getPendingInvoicesCount(), kpis.getPendingInvoicesAmount(),
                    kpis.getOpenClaimsCount(), kpis.getOpenClaimsAmount());
            }
            return;
        }

        req.getRequestDispatcher("/WEB-INF/views/analytics/dashboard.jsp").forward(req, resp);
    }

    private void handleSalesTrends(HttpServletRequest req, HttpServletResponse resp, Date start, Date end, Integer compId) 
            throws ServletException, IOException {

        String dimension = AnalyticsUtil.sanitize(req.getParameter("dimension"));
        if (dimension == null) dimension = "ROUTE";

        List<SalesTrendResult> trends = service.getSalesTrends(dimension, start, end, compId);
        req.setAttribute("trends", trends);
        req.setAttribute("dimension", dimension);
        req.setAttribute("activeNav", "sales-trends");

        if (isJsonRequested(req)) {
            resp.setContentType("application/json;charset=UTF-8");
            try (PrintWriter out = resp.getWriter()) {
                StringBuilder sb = new StringBuilder("{");
                sb.append("\"labels\":[");
                for (int i = 0; i < trends.size(); i++) {
                    sb.append("\"").append(escapeJson(trends.get(i).getDimensionLabel())).append("\"");
                    if (i < trends.size() - 1) sb.append(",");
                }
                sb.append("],\"sales\":[");
                for (int i = 0; i < trends.size(); i++) {
                    sb.append(String.format(Locale.US, "%.2f", trends.get(i).getTotalSales()));
                    if (i < trends.size() - 1) sb.append(",");
                }
                sb.append("],\"quantities\":[");
                for (int i = 0; i < trends.size(); i++) {
                    sb.append(trends.get(i).getTotalQuantity());
                    if (i < trends.size() - 1) sb.append(",");
                }
                sb.append("]}");
                out.write(sb.toString());
            }
            return;
        }

        req.getRequestDispatcher("/WEB-INF/views/analytics/sales-trends.jsp").forward(req, resp);
    }

    private void handleAbc(HttpServletRequest req, HttpServletResponse resp, Date start, Date end, Integer compId) 
            throws ServletException, IOException {

        String type = AnalyticsUtil.sanitize(req.getParameter("type"));
        if (type == null) type = "PRODUCT";

        List<AbcClassificationResult> productAbc = service.calculateProductAbcClassification(start, end, compId);
        List<AbcClassificationResult> customerAbc = service.calculateCustomerAbcClassification(start, end, compId);

        List<AbcClassificationResult> activeList = "CUSTOMER".equalsIgnoreCase(type) ? customerAbc : productAbc;

        req.setAttribute("abcItems", activeList);
        req.setAttribute("productAbc", productAbc);
        req.setAttribute("customerAbc", customerAbc);
        req.setAttribute("type", type);
        req.setAttribute("activeNav", "abc-classification");

        if (isJsonRequested(req)) {
            resp.setContentType("application/json;charset=UTF-8");
            try (PrintWriter out = resp.getWriter()) {
                long countA = activeList.stream().filter(a -> "A".equals(a.getAbcClass())).count();
                long countB = activeList.stream().filter(a -> "B".equals(a.getAbcClass())).count();
                long countC = activeList.stream().filter(a -> "C".equals(a.getAbcClass())).count();
                out.printf("{\"classA\":%d,\"classB\":%d,\"classC\":%d,\"totalItems\":%d}",
                    countA, countB, countC, activeList.size());
            }
            return;
        }

        req.getRequestDispatcher("/WEB-INF/views/analytics/abc-classification.jsp").forward(req, resp);
    }

    private void handleTurnover(HttpServletRequest req, HttpServletResponse resp, Date start, Date end, Integer compId) 
            throws ServletException, IOException {

        List<InventoryTurnoverResult> turnoverList = service.calculateInventoryTurnover(start, end, compId);
        req.setAttribute("turnoverList", turnoverList);
        req.setAttribute("activeNav", "inventory-turnover");

        if (isJsonRequested(req)) {
            resp.setContentType("application/json;charset=UTF-8");
            try (PrintWriter out = resp.getWriter()) {
                StringBuilder sb = new StringBuilder("{");
                sb.append("\"labels\":[");
                for (int i = 0; i < turnoverList.size(); i++) {
                    sb.append("\"").append(escapeJson(turnoverList.get(i).getProductName())).append("\"");
                    if (i < turnoverList.size() - 1) sb.append(",");
                }
                sb.append("],\"ratios\":[");
                for (int i = 0; i < turnoverList.size(); i++) {
                    sb.append(String.format(Locale.US, "%.2f", turnoverList.get(i).getTurnoverRatio()));
                    if (i < turnoverList.size() - 1) sb.append(",");
                }
                sb.append("]}");
                out.write(sb.toString());
            }
            return;
        }

        req.getRequestDispatcher("/WEB-INF/views/analytics/inventory-turnover.jsp").forward(req, resp);
    }

    private void handleProfitability(HttpServletRequest req, HttpServletResponse resp, Date start, Date end, Integer compId) 
            throws ServletException, IOException {

        List<ProfitabilityResult> productMargins = service.getProductProfitability(start, end, compId);
        List<ProfitLoss> shipmentPL = service.getShipmentProfitLoss(start, end, compId);

        req.setAttribute("productMargins", productMargins);
        req.setAttribute("shipmentPL", shipmentPL);
        req.setAttribute("activeNav", "profitability");

        if (isJsonRequested(req)) {
            resp.setContentType("application/json;charset=UTF-8");
            try (PrintWriter out = resp.getWriter()) {
                StringBuilder sb = new StringBuilder("{");
                sb.append("\"productCount\":").append(productMargins.size());
                sb.append(",\"shipmentCount\":").append(shipmentPL.size());
                sb.append(",\"topProductMargin\":");
                if (!productMargins.isEmpty()) {
                    sb.append(String.format(Locale.US, "%.2f", productMargins.get(0).getGrossMarginPct()));
                } else {
                    sb.append("0.0");
                }
                sb.append("}");
                out.write(sb.toString());
            }
            return;
        }

        req.getRequestDispatcher("/WEB-INF/views/analytics/profitability.jsp").forward(req, resp);
    }

    private void handleForecast(HttpServletRequest req, HttpServletResponse resp) 
            throws ServletException, IOException {

        Integer originPortId = AnalyticsUtil.parseInteger(req.getParameter("originPortId"), null);
        Integer destPortId = AnalyticsUtil.parseInteger(req.getParameter("destPortId"), null);
        String containerType = AnalyticsUtil.sanitize(req.getParameter("containerType"));

        List<DemandForecast> forecasts = service.getDemandForecasts(originPortId, destPortId, containerType);
        req.setAttribute("forecasts", forecasts);
        req.setAttribute("originPortId", originPortId);
        req.setAttribute("destPortId", destPortId);
        req.setAttribute("containerType", containerType);
        req.setAttribute("activeNav", "demand-forecast");

        if (isJsonRequested(req)) {
            resp.setContentType("application/json;charset=UTF-8");
            try (PrintWriter out = resp.getWriter()) {
                StringBuilder sb = new StringBuilder("{");
                sb.append("\"labels\":[");
                for (int i = 0; i < forecasts.size(); i++) {
                    DemandForecast f = forecasts.get(i);
                    sb.append("\"").append(escapeJson(f.getOriginPortName() + " -> " + f.getDestPortName() + " [" + f.getContainerType() + "]")).append("\"");
                    if (i < forecasts.size() - 1) sb.append(",");
                }
                sb.append("],\"predicted\":[");
                for (int i = 0; i < forecasts.size(); i++) {
                    sb.append(forecasts.get(i).getPredictedBookings());
                    if (i < forecasts.size() - 1) sb.append(",");
                }
                sb.append("],\"multipliers\":[");
                for (int i = 0; i < forecasts.size(); i++) {
                    sb.append(String.format(Locale.US, "%.2f", forecasts.get(i).getSuggestedMultiplier()));
                    if (i < forecasts.size() - 1) sb.append(",");
                }
                sb.append("],\"confidences\":[");
                for (int i = 0; i < forecasts.size(); i++) {
                    sb.append(String.format(Locale.US, "%.2f", forecasts.get(i).getConfidencePct()));
                    if (i < forecasts.size() - 1) sb.append(",");
                }
                sb.append("]}");
                out.write(sb.toString());
            }
            return;
        }

        req.getRequestDispatcher("/WEB-INF/views/analytics/demand-forecast.jsp").forward(req, resp);
    }

    private boolean isJsonRequested(HttpServletRequest req) {
        String format = req.getParameter("format");
        if ("json".equalsIgnoreCase(format)) return true;
        String accept = req.getHeader("Accept");
        return accept != null && accept.contains("application/json");
    }

    private String escapeJson(String s) {
        if (s == null) return "";
        return s.replace("\"", "\\\"").replace("\n", " ").replace("\r", "");
    }
}

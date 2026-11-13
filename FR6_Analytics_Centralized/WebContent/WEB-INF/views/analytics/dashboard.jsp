<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%@ taglib uri="http://java.sun.com/jsp/jstl/core" prefix="c" %>
<%@ taglib uri="http://java.sun.com/jsp/jstl/fmt" prefix="fmt" %>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>FR6 Analytics Dashboard - Overview</title>
    <link rel="stylesheet" href="${pageContext.request.contextPath}/assets/css/fr6/bootstrap.min.css">
    <link rel="stylesheet" href="${pageContext.request.contextPath}/assets/css/fr6/analytics.css">
</head>
<body class="fr6-body">

    <%@ include file="navbar.jspf" %>

    <div class="container-fluid px-4 fr6-main-container">

        <!-- Flash messages -->
        <c:if test="${param.refresh == 'success'}">
            <div class="alert alert-success alert-dismissible fade show" role="alert">
                <strong>Cache Refreshed!</strong> Successfully recalculated and cached analytics results (${param.rows} rows updated).
                <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>
            </div>
        </c:if>

        <!-- Page Header & Filter Bar -->
        <div class="fr6-filter-card">
            <form method="GET" action="${pageContext.request.contextPath}/fr6/analytics/dashboard" class="row g-3 align-items-end">
                <div class="col-md-3">
                    <label class="form-label small fw-semibold text-muted">Start Date</label>
                    <input type="date" name="startDate" class="form-control form-control-sm" value="<c:out value="${filter.startDate}"/>">
                </div>
                <div class="col-md-3">
                    <label class="form-label small fw-semibold text-muted">End Date</label>
                    <input type="date" name="endDate" class="form-control form-control-sm" value="<c:out value="${filter.endDate}"/>">
                </div>
                <c:if test="${accessContext.admin}">
                    <div class="col-md-3">
                        <label class="form-label small fw-semibold text-muted">Filter by Company (Admin Only)</label>
                        <select name="companyId" class="form-select form-select-sm">
                            <option value="">-- All Companies --</option>
                            <c:forEach var="c" items="${companiesList}">
                                <option value="${c.companyId}" ${filter.companyId == c.companyId ? 'selected' : ''}>
                                    <c:out value="${c.companyName}"/> (<c:out value="${c.companyType}"/>)
                                </option>
                            </c:forEach>
                        </select>
                    </div>
                </c:if>
                <div class="col-md-3 d-flex gap-2">
                    <button type="submit" class="btn btn-sm btn-primary flex-fill">Apply Filters</button>
                    <a href="${pageContext.request.contextPath}/fr6/analytics/dashboard" class="btn btn-sm btn-outline-secondary">Reset</a>
                </div>
            </form>
        </div>

        <!-- 5 Mandatory FR6.1 Dashboard KPIs -->
        <div class="row g-4 mb-4">
            <!-- KPI 1: Active Shipments -->
            <div class="col-xl col-md-6">
                <div class="fr6-kpi-card">
                    <div class="d-flex justify-content-between align-items-center">
                        <div>
                            <div class="fr6-kpi-title">Active Shipments</div>
                            <div class="fr6-kpi-value"><c:out value="${dashboardData.kpis.activeShipments}"/></div>
                            <div class="fr6-kpi-sub">In-transit &amp; booked shipments</div>
                        </div>
                        <div class="fr6-kpi-icon fr6-icon-blue">
                            &#x1F6A2;
                        </div>
                    </div>
                </div>
            </div>

            <!-- KPI 2: Containers Available -->
            <div class="col-xl col-md-6">
                <div class="fr6-kpi-card">
                    <div class="d-flex justify-content-between align-items-center">
                        <div>
                            <div class="fr6-kpi-title">Containers Available</div>
                            <div class="fr6-kpi-value"><c:out value="${dashboardData.kpis.containersAvailable}"/></div>
                            <div class="fr6-kpi-sub">Ready for immediate booking</div>
                        </div>
                        <div class="fr6-kpi-icon fr6-icon-green">
                            &#x1F4E6;
                        </div>
                    </div>
                </div>
            </div>

            <!-- KPI 3: Revenue (Paid Invoices) -->
            <div class="col-xl col-md-6">
                <div class="fr6-kpi-card">
                    <div class="d-flex justify-content-between align-items-center">
                        <div>
                            <div class="fr6-kpi-title">Total Revenue</div>
                            <div class="fr6-kpi-value">
                                INR <fmt:formatNumber value="${dashboardData.kpis.revenue}" pattern="#,##0.00"/>
                            </div>
                            <div class="fr6-kpi-sub">Realized from paid invoices</div>
                        </div>
                        <div class="fr6-kpi-icon fr6-icon-yellow">
                            &#x20B9;
                        </div>
                    </div>
                </div>
            </div>

            <!-- KPI 4: Pending Invoices -->
            <div class="col-xl col-md-6">
                <div class="fr6-kpi-card">
                    <div class="d-flex justify-content-between align-items-center">
                        <div>
                            <div class="fr6-kpi-title">Pending Invoices</div>
                            <div class="fr6-kpi-value"><c:out value="${dashboardData.kpis.pendingInvoicesCount}"/></div>
                            <div class="fr6-kpi-sub">
                                Outstanding: INR <fmt:formatNumber value="${dashboardData.kpis.pendingInvoicesAmount}" pattern="#,##0.00"/>
                            </div>
                        </div>
                        <div class="fr6-kpi-icon fr6-icon-purple">
                            &#x1F4C4;
                        </div>
                    </div>
                </div>
            </div>

            <!-- KPI 5: Open Claims -->
            <div class="col-xl col-md-6">
                <div class="fr6-kpi-card">
                    <div class="d-flex justify-content-between align-items-center">
                        <div>
                            <div class="fr6-kpi-title">Open Claims</div>
                            <div class="fr6-kpi-value"><c:out value="${dashboardData.kpis.openClaimsCount}"/></div>
                            <div class="fr6-kpi-sub">
                                Claimed: INR <fmt:formatNumber value="${dashboardData.kpis.openClaimsAmount}" pattern="#,##0.00"/>
                            </div>
                        </div>
                        <div class="fr6-kpi-icon fr6-icon-red">
                            &#x26A0;
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <!-- Analytics Overview Sections (Charts & Quick Tables) -->
        <div class="row g-4">
            <!-- Left Column: Sales Trend Overview -->
            <div class="col-lg-8">
                <div class="fr6-card">
                    <div class="fr6-card-header">
                        <span>&#x1F4C8; Sales Trends by Route (Cached Operational Data)</span>
                        <a href="${pageContext.request.contextPath}/fr6/analytics/sales-trends" class="btn btn-sm btn-outline-primary">View Full Trends &rarr;</a>
                    </div>
                    <div class="fr6-card-body">
                        <canvas id="overviewSalesChart" height="110"></canvas>
                    </div>
                </div>

                <!-- Product Profitability & P&L Summary -->
                <div class="fr6-card">
                    <div class="fr6-card-header">
                        <span>&#x1F4B0; Shipment Profit &amp; Loss Breakdown (FR2.8)</span>
                        <a href="${pageContext.request.contextPath}/fr6/analytics/profitability" class="btn btn-sm btn-outline-primary">View Full P&amp;L &rarr;</a>
                    </div>
                    <div class="table-responsive">
                        <table class="table fr6-table table-hover align-middle">
                            <thead>
                                <tr>
                                    <th>Shipment</th>
                                    <th>Seller</th>
                                    <th>Period</th>
                                    <th>Revenue</th>
                                    <th>Costs (Freight+Port+Handling)</th>
                                    <th>Claim Loss</th>
                                    <th>Net Profit</th>
                                </tr>
                            </thead>
                            <tbody>
                                <c:forEach var="pl" items="${dashboardData.recentProfitLoss}">
                                    <tr>
                                        <td class="fw-semibold"><c:out value="${pl.shipmentNo != null ? pl.shipmentNo : ('SHP #' + pl.shipmentId)}"/></td>
                                        <td><c:out value="${pl.sellerName}"/></td>
                                        <td><c:out value="${pl.periodMonth}"/></td>
                                        <td>INR <fmt:formatNumber value="${pl.revenue}" pattern="#,##0.00"/></td>
                                        <td>INR <fmt:formatNumber value="${pl.freightCost + pl.portCost + pl.handlingCost}" pattern="#,##0.00"/></td>
                                        <td class="text-danger">INR <fmt:formatNumber value="${pl.claimLoss}" pattern="#,##0.00"/></td>
                                        <td class="${pl.netProfit >= 0 ? 'text-success fw-bold' : 'text-danger fw-bold'}">
                                            INR <fmt:formatNumber value="${pl.netProfit}" pattern="#,##0.00"/>
                                        </td>
                                    </tr>
                                </c:forEach>
                                <c:if test="${empty dashboardData.recentProfitLoss}">
                                    <tr><td colspan="7" class="text-center text-muted py-3">No shipment profit &amp; loss records found for the selected period.</td></tr>
                                </c:if>
                            </tbody>
                        </table>
                    </div>
                </div>
            </div>

            <!-- Right Column: ABC Distribution & Demand Forecasts -->
            <div class="col-lg-4">
                <!-- ABC Distribution -->
                <div class="fr6-card">
                    <div class="fr6-card-header">
                        <span>&#x1F3AF; ABC Pareto Distribution</span>
                        <a href="${pageContext.request.contextPath}/fr6/analytics/abc-classification" class="btn btn-sm btn-outline-primary">Details</a>
                    </div>
                    <div class="fr6-card-body">
                        <canvas id="overviewAbcChart" height="180"></canvas>
                    </div>
                </div>

                <!-- Active Demand Forecast Highlights -->
                <div class="fr6-card">
                    <div class="fr6-card-header">
                        <span>&#x1F4C9; Predicted Demand &amp; Multipliers</span>
                        <a href="${pageContext.request.contextPath}/fr6/analytics/demand-forecast" class="btn btn-sm btn-outline-primary">Forecasts</a>
                    </div>
                    <div class="list-group list-group-flush">
                        <c:forEach var="df" items="${dashboardData.activeForecasts}" varStatus="status">
                            <c:if test="${status.index < 4}">
                                <div class="list-group-item d-flex justify-content-between align-items-center">
                                    <div>
                                        <div class="fw-semibold small"><c:out value="${df.routeLabel}"/></div>
                                        <span class="badge bg-light text-dark border"><c:out value="${df.containerType}"/></span>
                                        <small class="text-muted">Month: <c:out value="${df.forecastMonth}"/></small>
                                    </div>
                                    <div class="text-end">
                                        <div class="badge bg-primary fs-6"><c:out value="${df.predictedBookings}"/> bookings</div>
                                        <div class="small text-muted">Mult: <strong>${df.suggestedMultiplier}x</strong></div>
                                    </div>
                                </div>
                            </c:if>
                        </c:forEach>
                        <c:if test="${empty dashboardData.activeForecasts}">
                            <div class="list-group-item text-center text-muted py-3">No active forecasts found.</div>
                        </c:if>
                    </div>
                </div>
            </div>
        </div>

    </div>

    <%@ include file="footer.jspf" %>

    <script src="${pageContext.request.contextPath}/assets/js/fr6/bootstrap.bundle.min.js"></script>
    <script src="${pageContext.request.contextPath}/assets/js/fr6/chart.umd.min.js"></script>
    <script>
        // Overview Charts initialization using server data safely via JSON
        document.addEventListener('DOMContentLoaded', function () {
            // 1. Overview Sales Line Chart
            const salesCtx = document.getElementById('overviewSalesChart');
            if (salesCtx) {
                const labels = [
                    <c:forEach var="item" items="${dashboardData.recentTrends}" varStatus="loop">
                        "<c:out value="${item.routeLabel}"/> (<c:out value="${item.periodMonth}"/>)"${!loop.last ? ',' : ''}
                    </c:forEach>
                ];
                const salesData = [
                    <c:forEach var="item" items="${dashboardData.recentTrends}" varStatus="loop">
                        ${item.totalSales}${!loop.last ? ',' : ''}
                    </c:forEach>
                ];

                new Chart(salesCtx, {
                    type: 'line',
                    data: {
                        labels: labels,
                        datasets: [{
                            label: 'Total Sales (INR)',
                            data: salesData,
                            borderColor: '#1a56db',
                            backgroundColor: 'rgba(26, 86, 219, 0.1)',
                            fill: true,
                            tension: 0.3,
                            borderWidth: 2
                        }]
                    },
                    options: {
                        responsive: true,
                        plugins: { legend: { display: false } },
                        scales: {
                            y: {
                                beginAtZero: true,
                                ticks: {
                                    callback: function(v) { return 'INR ' + v.toLocaleString(); }
                                }
                            }
                        }
                    }
                });
            }

            // 2. Overview ABC Donut Chart
            const abcCtx = document.getElementById('overviewAbcChart');
            if (abcCtx) {
                let countA = 0, countB = 0, countC = 0;
                <c:forEach var="abc" items="${dashboardData.topAbcProducts}">
                    if ('${abc.abcClass}' === 'A') countA++;
                    else if ('${abc.abcClass}' === 'B') countB++;
                    else countC++;
                </c:forEach>

                new Chart(abcCtx, {
                    type: 'doughnut',
                    data: {
                        labels: ['Class A (Top 70%)', 'Class B (Next 20%)', 'Class C (Last 10%)'],
                        datasets: [{
                            data: [countA, countB, countC],
                            backgroundColor: ['#16a34a', '#eab308', '#dc2626'],
                            borderWidth: 2
                        }]
                    },
                    options: {
                        responsive: true,
                        plugins: {
                            legend: { position: 'bottom' }
                        }
                    }
                });
            }
        });
    </script>
</body>
</html>

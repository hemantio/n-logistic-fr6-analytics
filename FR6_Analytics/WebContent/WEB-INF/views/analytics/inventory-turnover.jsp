<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%@ taglib uri="http://java.sun.com/jsp/jstl/core" prefix="c" %>
<%@ taglib uri="http://java.sun.com/jsp/jstl/fmt" prefix="fmt" %>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>FR6 Analytics - Inventory Turnover Ratio</title>
    <link rel="stylesheet" href="${pageContext.request.contextPath}/assets/css/fr6/bootstrap.min.css">
    <link rel="stylesheet" href="${pageContext.request.contextPath}/assets/css/fr6/analytics.css">
</head>
<body class="fr6-body">

    <%@ include file="navbar.jspf" %>

    <div class="container-fluid px-4 fr6-main-container">

        <!-- Filter Card -->
        <div class="fr6-filter-card">
            <form method="GET" action="${pageContext.request.contextPath}/fr6/analytics/inventory-turnover" class="row g-3 align-items-end">
                <c:if test="${accessContext.admin}">
                    <div class="col-md-4">
                        <label class="form-label small fw-semibold text-muted">Company (Admin Only)</label>
                        <select name="companyId" class="form-select form-select-sm">
                            <option value="">-- All Companies --</option>
                            <c:forEach var="c" items="${companiesList}">
                                <option value="${c.companyId}" ${filter.companyId == c.companyId ? 'selected' : ''}>
                                    <c:out value="${c.companyName}"/>
                                </option>
                            </c:forEach>
                        </select>
                    </div>
                </c:if>
                <div class="col-md-4 d-flex gap-2">
                    <button type="submit" class="btn btn-sm btn-primary flex-fill">Apply Filters</button>
                    <a href="${pageContext.request.contextPath}/fr6/analytics/inventory-turnover" class="btn btn-sm btn-outline-secondary">Reset</a>
                </div>
            </form>
        </div>

        <!-- Metric Highlight Card -->
        <div class="row g-4 mb-4">
            <div class="col-md-6">
                <div class="fr6-kpi-card">
                    <div class="fr6-kpi-title">Average Inventory Turnover Ratio</div>
                    <div class="fr6-kpi-value text-primary">${chartData.averageRatio}x</div>
                    <div class="fr6-kpi-sub">Formula per SRS Section 7.9: <code>turnover_ratio = cogs / avg_inventory</code></div>
                </div>
            </div>
            <div class="col-md-6">
                <div class="fr6-kpi-card">
                    <div class="fr6-kpi-title">Monitored Inventory Items</div>
                    <div class="fr6-kpi-value">${turnoverList.size()} Products</div>
                    <div class="fr6-kpi-sub">Calculated across warehouse stock and movement ledgers</div>
                </div>
            </div>
        </div>

        <!-- Chart Section -->
        <div class="fr6-card">
            <div class="fr6-card-header">
                <span>&#x1F4CA; Product Inventory Turnover Ratios</span>
            </div>
            <div class="fr6-card-body">
                <canvas id="turnoverBarChart" height="90"></canvas>
            </div>
        </div>

        <!-- Detailed Table -->
        <div class="fr6-card">
            <div class="fr6-card-header">
                <span>Detailed Inventory Turnover Ledger Records</span>
            </div>
            <div class="table-responsive">
                <table class="table fr6-table table-hover align-middle">
                    <thead>
                        <tr>
                            <th>Product Name</th>
                            <th>SKU</th>
                            <th>Period Start</th>
                            <th>Period End</th>
                            <th class="text-end">COGS (INR)</th>
                            <th class="text-end">Avg Inventory (INR)</th>
                            <th class="text-end">Turnover Ratio</th>
                            <th>Efficiency Velocity</th>
                        </tr>
                    </thead>
                    <tbody>
                        <c:forEach var="row" items="${turnoverList}">
                            <tr>
                                <td class="fw-semibold"><c:out value="${row.productName}"/></td>
                                <td><code><c:out value="${row.sku}"/></code></td>
                                <td><c:out value="${row.periodStart}"/></td>
                                <td><c:out value="${row.periodEnd}"/></td>
                                <td class="text-end">INR <fmt:formatNumber value="${row.cogs}" pattern="#,##0.00"/></td>
                                <td class="text-end">INR <fmt:formatNumber value="${row.avgInventory}" pattern="#,##0.00"/></td>
                                <td class="text-end fw-bold fs-6"><fmt:formatNumber value="${row.turnoverRatio}" pattern="0.00"/>x</td>
                                <td>
                                    <c:choose>
                                        <c:when test="${row.turnoverRatio >= 0.25}">
                                            <span class="badge bg-success">Fast Velocity</span>
                                        </c:when>
                                        <c:otherwise>
                                            <span class="badge bg-secondary">Moderate Velocity</span>
                                        </c:otherwise>
                                    </c:choose>
                                </td>
                            </tr>
                        </c:forEach>
                        <c:if test="${empty turnoverList}">
                            <tr><td colspan="8" class="text-center text-muted py-3">No inventory turnover records found.</td></tr>
                        </c:if>
                    </tbody>
                </table>
            </div>
        </div>

    </div>

    <%@ include file="footer.jspf" %>

    <script src="${pageContext.request.contextPath}/assets/js/fr6/bootstrap.bundle.min.js"></script>
    <script src="${pageContext.request.contextPath}/assets/js/fr6/chart.umd.min.js"></script>
    <script>
        document.addEventListener('DOMContentLoaded', function () {
            const ctx = document.getElementById('turnoverBarChart');
            if (ctx) {
                const labels = [
                    <c:forEach var="lbl" items="${chartData.labels}" varStatus="loop">
                        "<c:out value="${lbl}"/>"${!loop.last ? ',' : ''}
                    </c:forEach>
                ];
                const ratios = [
                    <c:forEach var="r" items="${chartData.ratios}" varStatus="loop">
                        ${r}${!loop.last ? ',' : ''}
                    </c:forEach>
                ];

                new Chart(ctx, {
                    type: 'bar',
                    data: {
                        labels: labels,
                        datasets: [{
                            label: 'Turnover Ratio (cogs / avg_inventory)',
                            data: ratios,
                            backgroundColor: '#1a56db',
                            borderRadius: 4
                        }]
                    },
                    options: {
                        responsive: true,
                        scales: {
                            y: {
                                beginAtZero: true,
                                title: { display: true, text: 'Turnover Ratio (x)' }
                            }
                        }
                    }
                });
            }
        });
    </script>
</body>
</html>

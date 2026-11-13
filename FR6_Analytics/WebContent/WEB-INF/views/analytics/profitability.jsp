<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%@ taglib uri="http://java.sun.com/jsp/jstl/core" prefix="c" %>
<%@ taglib uri="http://java.sun.com/jsp/jstl/fmt" prefix="fmt" %>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>FR6 Analytics - Product &amp; Shipment Profitability</title>
    <link rel="stylesheet" href="${pageContext.request.contextPath}/assets/css/fr6/bootstrap.min.css">
    <link rel="stylesheet" href="${pageContext.request.contextPath}/assets/css/fr6/analytics.css">
</head>
<body class="fr6-body">

    <%@ include file="navbar.jspf" %>

    <div class="container-fluid px-4 fr6-main-container">

        <!-- Filter Card -->
        <div class="fr6-filter-card">
            <form method="GET" action="${pageContext.request.contextPath}/fr6/analytics/profitability" class="row g-3 align-items-end">
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
                <div class="col-md-3 d-flex gap-2">
                    <button type="submit" class="btn btn-sm btn-primary flex-fill">Apply Filters</button>
                    <a href="${pageContext.request.contextPath}/fr6/analytics/profitability" class="btn btn-sm btn-outline-secondary">Reset</a>
                </div>
            </form>
        </div>

        <!-- Profitability Chart -->
        <div class="fr6-card">
            <div class="fr6-card-header">
                <span>&#x1F4C8; Product Profitability Margins (Revenue vs Cost vs Margin %)</span>
            </div>
            <div class="fr6-card-body">
                <canvas id="profitabilityChart" height="95"></canvas>
            </div>
        </div>

        <!-- Table 1: Product Profitability Results -->
        <div class="fr6-card mb-4">
            <div class="fr6-card-header">
                <span>&#x1F4E6; Product-Level Margins (<code>profitability_result</code> Entity)</span>
            </div>
            <div class="table-responsive">
                <table class="table fr6-table table-hover align-middle">
                    <thead>
                        <tr>
                            <th>Period Month</th>
                            <th>Product Name</th>
                            <th>SKU</th>
                            <th>Category</th>
                            <th class="text-end">Revenue</th>
                            <th class="text-end">Cost</th>
                            <th class="text-end">Margin %</th>
                        </tr>
                    </thead>
                    <tbody>
                        <c:forEach var="p" items="${profitabilityData.productProfitability}">
                            <tr>
                                <td class="fw-semibold"><c:out value="${p.periodMonth}"/></td>
                                <td><c:out value="${p.productName}"/></td>
                                <td><code><c:out value="${p.sku}"/></code></td>
                                <td><span class="badge bg-light text-dark border"><c:out value="${p.category}"/></span></td>
                                <td class="text-end">INR <fmt:formatNumber value="${p.revenue}" pattern="#,##0.00"/></td>
                                <td class="text-end">INR <fmt:formatNumber value="${p.cost}" pattern="#,##0.00"/></td>
                                <td class="text-end fw-bold ${p.marginPct >= 30 ? 'text-success' : 'text-primary'}">
                                    <fmt:formatNumber value="${p.marginPct}" pattern="0.00"/>%
                                </td>
                            </tr>
                        </c:forEach>
                        <c:if test="${empty profitabilityData.productProfitability}">
                            <tr><td colspan="7" class="text-center text-muted py-3">No product profitability records found.</td></tr>
                        </c:if>
                    </tbody>
                </table>
            </div>
        </div>

        <!-- Table 2: Shipment & Seller Profit and Loss Breakdown -->
        <div class="fr6-card">
            <div class="fr6-card-header">
                <span>&#x1F6A2; Shipment &amp; Seller Profit and Loss (<code>profit_loss</code> Entity per SRS FR2.8)</span>
            </div>
            <div class="table-responsive">
                <table class="table fr6-table table-hover align-middle">
                    <thead>
                        <tr>
                            <th>Period</th>
                            <th>Shipment</th>
                            <th>Seller</th>
                            <th class="text-end">Revenue (Paid Inv)</th>
                            <th class="text-end">Freight Cost</th>
                            <th class="text-end">Port Cost</th>
                            <th class="text-end">Handling Cost</th>
                            <th class="text-end text-danger">Claim Loss</th>
                            <th class="text-end">Net Profit</th>
                        </tr>
                    </thead>
                    <tbody>
                        <c:forEach var="pl" items="${profitabilityData.shipmentProfitLoss}">
                            <tr>
                                <td class="fw-semibold"><c:out value="${pl.periodMonth}"/></td>
                                <td><c:out value="${pl.shipmentNo != null ? pl.shipmentNo : ('SHP #' + pl.shipmentId)}"/></td>
                                <td><c:out value="${pl.sellerName}"/></td>
                                <td class="text-end">INR <fmt:formatNumber value="${pl.revenue}" pattern="#,##0.00"/></td>
                                <td class="text-end">INR <fmt:formatNumber value="${pl.freightCost}" pattern="#,##0.00"/></td>
                                <td class="text-end">INR <fmt:formatNumber value="${pl.portCost}" pattern="#,##0.00"/></td>
                                <td class="text-end">INR <fmt:formatNumber value="${pl.handlingCost}" pattern="#,##0.00"/></td>
                                <td class="text-end text-danger">INR <fmt:formatNumber value="${pl.claimLoss}" pattern="#,##0.00"/></td>
                                <td class="text-end fw-bold ${pl.netProfit >= 0 ? 'text-success' : 'text-danger'}">
                                    INR <fmt:formatNumber value="${pl.netProfit}" pattern="#,##0.00"/>
                                </td>
                            </tr>
                        </c:forEach>
                        <c:if test="${empty profitabilityData.shipmentProfitLoss}">
                            <tr><td colspan="9" class="text-center text-muted py-3">No shipment profit and loss records found.</td></tr>
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
            const ctx = document.getElementById('profitabilityChart');
            if (ctx) {
                const labels = [
                    <c:forEach var="lbl" items="${profitabilityData.labels}" varStatus="loop">
                        "<c:out value="${lbl}"/>"${!loop.last ? ',' : ''}
                    </c:forEach>
                ];
                const rev = [
                    <c:forEach var="v" items="${profitabilityData.revenueValues}" varStatus="loop">
                        ${v}${!loop.last ? ',' : ''}
                    </c:forEach>
                ];
                const costs = [
                    <c:forEach var="c" items="${profitabilityData.costValues}" varStatus="loop">
                        ${c}${!loop.last ? ',' : ''}
                    </c:forEach>
                ];
                const margins = [
                    <c:forEach var="m" items="${profitabilityData.marginValues}" varStatus="loop">
                        ${m}${!loop.last ? ',' : ''}
                    </c:forEach>
                ];

                new Chart(ctx, {
                    type: 'bar',
                    data: {
                        labels: labels,
                        datasets: [
                            {
                                label: 'Revenue (INR)',
                                data: rev,
                                backgroundColor: '#1a56db',
                                yAxisID: 'y'
                            },
                            {
                                label: 'Cost (INR)',
                                data: costs,
                                backgroundColor: '#94a3b8',
                                yAxisID: 'y'
                            },
                            {
                                label: 'Margin %',
                                data: margins,
                                borderColor: '#16a34a',
                                backgroundColor: '#16a34a',
                                type: 'line',
                                borderWidth: 3,
                                yAxisID: 'y1'
                            }
                        ]
                    },
                    options: {
                        responsive: true,
                        interaction: { mode: 'index', intersect: false },
                        scales: {
                            y: {
                                beginAtZero: true,
                                title: { display: true, text: 'Amount (INR)' }
                            },
                            y1: {
                                beginAtZero: true,
                                position: 'right',
                                grid: { drawOnChartArea: false },
                                title: { display: true, text: 'Margin (%)' },
                                ticks: {
                                    callback: function(v) { return v + '%'; }
                                }
                            }
                        }
                    }
                });
            }
        });
    </script>
</body>
</html>

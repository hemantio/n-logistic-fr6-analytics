<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%@ taglib uri="http://java.sun.com/jsp/jstl/core" prefix="c" %>
<%@ taglib uri="http://java.sun.com/jsp/jstl/fmt" prefix="fmt" %>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>FR6 Analytics - Sales Trend Analysis</title>
    <link rel="stylesheet" href="${pageContext.request.contextPath}/assets/css/fr6/bootstrap.min.css">
    <link rel="stylesheet" href="${pageContext.request.contextPath}/assets/css/fr6/analytics.css">
</head>
<body class="fr6-body">

    <%@ include file="navbar.jspf" %>

    <div class="container-fluid px-4 fr6-main-container">

        <!-- Filter & Dimension Selector Bar -->
        <div class="fr6-filter-card">
            <form method="GET" action="${pageContext.request.contextPath}/fr6/analytics/sales-trends" class="row g-3 align-items-end">
                <div class="col-md-2">
                    <label class="form-label small fw-semibold text-muted">Analysis Dimension</label>
                    <select name="dimension" class="form-select form-select-sm">
                        <option value="route" ${filter.dimension == 'route' ? 'selected' : ''}>By Route</option>
                        <option value="product" ${filter.dimension == 'product' ? 'selected' : ''}>By Product</option>
                        <option value="customer" ${filter.dimension == 'customer' ? 'selected' : ''}>By Customer</option>
                    </select>
                </div>
                <div class="col-md-2">
                    <label class="form-label small fw-semibold text-muted">Start Date</label>
                    <input type="date" name="startDate" class="form-control form-control-sm" value="<c:out value="${filter.startDate}"/>">
                </div>
                <div class="col-md-2">
                    <label class="form-label small fw-semibold text-muted">End Date</label>
                    <input type="date" name="endDate" class="form-control form-control-sm" value="<c:out value="${filter.endDate}"/>">
                </div>
                <div class="col-md-2">
                    <label class="form-label small fw-semibold text-muted">Origin Port</label>
                    <select name="originPortId" class="form-select form-select-sm">
                        <option value="">-- All Origins --</option>
                        <c:forEach var="p" items="${portsList}">
                            <option value="${p.portId}" ${filter.originPortId == p.portId ? 'selected' : ''}>
                                <c:out value="${p.portName}"/> (<c:out value="${p.portCode}"/>)
                            </option>
                        </c:forEach>
                    </select>
                </div>
                <div class="col-md-2">
                    <label class="form-label small fw-semibold text-muted">Destination Port</label>
                    <select name="destPortId" class="form-select form-select-sm">
                        <option value="">-- All Destinations --</option>
                        <c:forEach var="p" items="${portsList}">
                            <option value="${p.portId}" ${filter.destPortId == p.portId ? 'selected' : ''}>
                                <c:out value="${p.portName}"/> (<c:out value="${p.portCode}"/>)
                            </option>
                        </c:forEach>
                    </select>
                </div>
                <div class="col-md-2 d-flex gap-2">
                    <button type="submit" class="btn btn-sm btn-primary flex-fill">Filter</button>
                    <a href="${pageContext.request.contextPath}/fr6/analytics/sales-trends" class="btn btn-sm btn-outline-secondary">Reset</a>
                </div>
            </form>
        </div>

        <!-- Chart Section -->
        <div class="fr6-card">
            <div class="fr6-card-header">
                <span>&#x1F4CA; Revenue &amp; Volume Over Time (${filter.dimension.toUpperCase()})</span>
            </div>
            <div class="fr6-card-body">
                <canvas id="salesTrendsChart" height="90"></canvas>
            </div>
        </div>

        <!-- Data Table Section -->
        <div class="fr6-card">
            <div class="fr6-card-header">
                <span>Detailed Sales Trends Log</span>
            </div>
            <div class="table-responsive">
                <table class="table fr6-table table-hover align-middle">
                    <thead>
                        <tr>
                            <th>Period Month</th>
                            <c:choose>
                                <c:when test="${filter.dimension == 'product'}">
                                    <th>Product / SKU</th>
                                </c:when>
                                <c:when test="${filter.dimension == 'customer'}">
                                    <th>Customer / Company</th>
                                </c:when>
                                <c:otherwise>
                                    <th>Route (Origin &rarr; Destination)</th>
                                </c:otherwise>
                            </c:choose>
                            <th class="text-end">Total Revenue</th>
                            <th class="text-end">Volume / Quantity</th>
                            <c:if test="${filter.dimension == 'route'}">
                                <th class="text-end">Growth vs Prev Month</th>
                            </c:if>
                        </tr>
                    </thead>
                    <tbody>
                        <c:choose>
                            <c:when test="${filter.dimension == 'route'}">
                                <c:forEach var="row" items="${trendData.tableRows}">
                                    <tr>
                                        <td class="fw-semibold"><c:out value="${row.periodMonth}"/></td>
                                        <td><c:out value="${row.routeLabel}"/></td>
                                        <td class="text-end">INR <fmt:formatNumber value="${row.totalSales}" pattern="#,##0.00"/></td>
                                        <td class="text-end"><fmt:formatNumber value="${row.totalQty}" pattern="#,##0"/></td>
                                        <td class="text-end">
                                            <span class="badge ${row.growthPct >= 0 ? 'bg-success' : 'bg-danger'}">
                                                <fmt:formatNumber value="${row.growthPct}" pattern="+0.00;-0.00"/>%
                                            </span>
                                        </td>
                                    </tr>
                                </c:forEach>
                                <c:if test="${empty trendData.tableRows}">
                                    <tr><td colspan="5" class="text-center text-muted py-3">No sales trend records found.</td></tr>
                                </c:if>
                            </c:when>
                            <c:otherwise>
                                <c:forEach var="i" begin="0" end="${trendData.labels.size() - 1}">
                                    <tr>
                                        <td class="fw-semibold">${trendData.labels[i]}</td>
                                        <td>-</td>
                                        <td class="text-end">INR <fmt:formatNumber value="${trendData.salesValues[i]}" pattern="#,##0.00"/></td>
                                        <td class="text-end"><fmt:formatNumber value="${trendData.qtyValues[i]}" pattern="#,##0"/></td>
                                    </tr>
                                </c:forEach>
                                <c:if test="${empty trendData.labels}">
                                    <tr><td colspan="4" class="text-center text-muted py-3">No trend data available.</td></tr>
                                </c:if>
                            </c:otherwise>
                        </c:choose>
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
            const ctx = document.getElementById('salesTrendsChart');
            if (ctx) {
                const labels = [
                    <c:forEach var="lbl" items="${trendData.labels}" varStatus="loop">
                        "<c:out value="${lbl}"/>"${!loop.last ? ',' : ''}
                    </c:forEach>
                ];
                const sales = [
                    <c:forEach var="s" items="${trendData.salesValues}" varStatus="loop">
                        ${s}${!loop.last ? ',' : ''}
                    </c:forEach>
                ];
                const quantities = [
                    <c:forEach var="q" items="${trendData.qtyValues}" varStatus="loop">
                        ${q}${!loop.last ? ',' : ''}
                    </c:forEach>
                ];

                new Chart(ctx, {
                    type: 'line',
                    data: {
                        labels: labels,
                        datasets: [
                            {
                                label: 'Total Revenue (INR)',
                                data: sales,
                                borderColor: '#1a56db',
                                backgroundColor: 'rgba(26, 86, 219, 0.08)',
                                fill: true,
                                yAxisID: 'y'
                            },
                            {
                                label: 'Volume (Units/Bookings)',
                                data: quantities,
                                borderColor: '#0e9f6e',
                                backgroundColor: '#0e9f6e',
                                type: 'bar',
                                yAxisID: 'y1'
                            }
                        ]
                    },
                    options: {
                        responsive: true,
                        interaction: { mode: 'index', intersect: false },
                        scales: {
                            y: {
                                type: 'linear',
                                display: true,
                                position: 'left',
                                title: { display: true, text: 'Revenue (INR)' },
                                ticks: {
                                    callback: function(v) { return 'INR ' + v.toLocaleString(); }
                                }
                            },
                            y1: {
                                type: 'linear',
                                display: true,
                                position: 'right',
                                grid: { drawOnChartArea: false },
                                title: { display: true, text: 'Volume' }
                            }
                        }
                    }
                });
            }
        });
    </script>
</body>
</html>

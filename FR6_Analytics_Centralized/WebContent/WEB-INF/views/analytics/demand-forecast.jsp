<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%@ taglib uri="http://java.sun.com/jsp/jstl/core" prefix="c" %>
<%@ taglib uri="http://java.sun.com/jsp/jstl/fmt" prefix="fmt" %>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>FR6 Analytics - Demand Forecasting &amp; Pricing Integration</title>
    <link rel="stylesheet" href="${pageContext.request.contextPath}/assets/css/fr6/bootstrap.min.css">
    <link rel="stylesheet" href="${pageContext.request.contextPath}/assets/css/fr6/analytics.css">
</head>
<body class="fr6-body">

    <%@ include file="navbar.jspf" %>

    <div class="container-fluid px-4 fr6-main-container">

        <!-- Flash messages -->
        <c:if test="${param.success == 'applied'}">
            <div class="alert alert-success alert-dismissible fade show" role="alert">
                <strong>Multiplier Applied!</strong> The forecast suggested multiplier was successfully synced with FR3 Pricing Rules and logged in <code>pricing_audit</code>.
                <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>
            </div>
        </c:if>
        <c:if test="${param.error != null}">
            <div class="alert alert-danger alert-dismissible fade show" role="alert">
                <strong>Error:</strong> Failed to apply multiplier (No matching active pricing rule found for this route/container).
                <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>
            </div>
        </c:if>

        <!-- Filter Card -->
        <div class="fr6-filter-card">
            <form method="GET" action="${pageContext.request.contextPath}/fr6/analytics/demand-forecast" class="row g-3 align-items-end">
                <div class="col-md-3">
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
                <div class="col-md-3">
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
                <div class="col-md-3">
                    <label class="form-label small fw-semibold text-muted">Container Type</label>
                    <select name="containerType" class="form-select form-select-sm">
                        <option value="">-- All Container Types --</option>
                        <option value="DRY" ${filter.containerType == 'DRY' ? 'selected' : ''}>DRY</option>
                        <option value="REEFER" ${filter.containerType == 'REEFER' ? 'selected' : ''}>REEFER</option>
                        <option value="OPEN_TOP" ${filter.containerType == 'OPEN_TOP' ? 'selected' : ''}>OPEN_TOP</option>
                        <option value="TANK" ${filter.containerType == 'TANK' ? 'selected' : ''}>TANK</option>
                    </select>
                </div>
                <div class="col-md-3 d-flex gap-2">
                    <button type="submit" class="btn btn-sm btn-primary flex-fill">Apply Filters</button>
                    <a href="${pageContext.request.contextPath}/fr6/analytics/demand-forecast" class="btn btn-sm btn-outline-secondary">Reset</a>
                </div>
            </form>
        </div>

        <!-- Demand Forecast Chart -->
        <div class="fr6-card">
            <div class="fr6-card-header">
                <span>&#x1F4C9; Predicted Route Bookings &amp; Demand Multipliers (FR6.6)</span>
            </div>
            <div class="fr6-card-body">
                <canvas id="forecastChart" height="95"></canvas>
            </div>
        </div>

        <!-- Detailed Forecast & Pricing Sync Table -->
        <div class="fr6-card">
            <div class="fr6-card-header d-flex justify-content-between align-items-center">
                <span>&#x1F4CB; Active Demand Forecasts (<code>demand_forecast</code> Entity)</span>
                <span class="badge bg-primary">FR3 Pricing Integration Seam</span>
            </div>
            <div class="table-responsive">
                <table class="table fr6-table table-hover align-middle">
                    <thead>
                        <tr>
                            <th>Route</th>
                            <th>Container Type</th>
                            <th>Forecast Month</th>
                            <th class="text-end">Predicted Bookings</th>
                            <th class="text-end">Confidence %</th>
                            <th class="text-end">Suggested Multiplier</th>
                            <th class="text-center">FR3 Pricing Sync Action</th>
                        </tr>
                    </thead>
                    <tbody>
                        <c:forEach var="f" items="${forecastData.forecastList}">
                            <tr>
                                <td class="fw-semibold"><c:out value="${f.routeLabel}"/></td>
                                <td><span class="badge bg-light text-dark border"><c:out value="${f.containerType}"/></span></td>
                                <td><c:out value="${f.forecastMonth}"/></td>
                                <td class="text-end fw-bold fs-6"><c:out value="${f.predictedBookings}"/></td>
                                <td class="text-end">
                                    <span class="badge bg-info text-dark">
                                        <fmt:formatNumber value="${f.confidencePct}" pattern="0.0"/>%
                                    </span>
                                </td>
                                <td class="text-end fw-bold text-primary fs-6">
                                    <fmt:formatNumber value="${f.suggestedMultiplier}" pattern="0.00"/>x
                                </td>
                                <td class="text-center">
                                    <c:choose>
                                        <c:when test="${accessContext.admin or accessContext.seller}">
                                            <form method="POST" action="${pageContext.request.contextPath}/fr6/analytics/demand-forecast" class="d-inline">
                                                <input type="hidden" name="forecastId" value="${f.forecastId}">
                                                <button type="submit" class="btn btn-sm btn-outline-success" onclick="return confirm('Apply this suggested multiplier to active FR3 pricing rules?');">
                                                    Apply to Pricing &rarr;
                                                </button>
                                            </form>
                                        </c:when>
                                        <c:otherwise>
                                            <span class="text-muted small">View Only</span>
                                        </c:otherwise>
                                    </c:choose>
                                </td>
                            </tr>
                        </c:forEach>
                        <c:if test="${empty forecastData.forecastList}">
                            <tr><td colspan="7" class="text-center text-muted py-3">No demand forecast records found.</td></tr>
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
            const ctx = document.getElementById('forecastChart');
            if (ctx) {
                const labels = [
                    <c:forEach var="lbl" items="${forecastData.labels}" varStatus="loop">
                        "<c:out value="${lbl}"/>"${!loop.last ? ',' : ''}
                    </c:forEach>
                ];
                const predicted = [
                    <c:forEach var="p" items="${forecastData.predictedValues}" varStatus="loop">
                        ${p}${!loop.last ? ',' : ''}
                    </c:forEach>
                ];
                const multipliers = [
                    <c:forEach var="m" items="${forecastData.multiplierValues}" varStatus="loop">
                        ${m}${!loop.last ? ',' : ''}
                    </c:forEach>
                ];
                const confidences = [
                    <c:forEach var="cf" items="${forecastData.confidenceValues}" varStatus="loop">
                        ${cf}${!loop.last ? ',' : ''}
                    </c:forEach>
                ];

                new Chart(ctx, {
                    type: 'bar',
                    data: {
                        labels: labels,
                        datasets: [
                            {
                                label: 'Predicted Bookings',
                                data: predicted,
                                backgroundColor: '#1a56db',
                                yAxisID: 'y'
                            },
                            {
                                label: 'Suggested Multiplier (x)',
                                data: multipliers,
                                borderColor: '#eab308',
                                backgroundColor: '#eab308',
                                type: 'line',
                                borderWidth: 3,
                                yAxisID: 'y1'
                            },
                            {
                                label: 'Model Confidence (%)',
                                data: confidences,
                                borderColor: '#16a34a',
                                backgroundColor: '#16a34a',
                                type: 'line',
                                borderDash: [5, 5],
                                borderWidth: 2,
                                yAxisID: 'y2'
                            }
                        ]
                    },
                    options: {
                        responsive: true,
                        interaction: { mode: 'index', intersect: false },
                        scales: {
                            y: {
                                beginAtZero: true,
                                title: { display: true, text: 'Bookings' }
                            },
                            y1: {
                                beginAtZero: false,
                                min: 0.8,
                                max: 1.5,
                                position: 'right',
                                grid: { drawOnChartArea: false },
                                title: { display: true, text: 'Pricing Multiplier' }
                            },
                            y2: {
                                beginAtZero: true,
                                max: 100,
                                position: 'right',
                                grid: { drawOnChartArea: false },
                                display: false
                            }
                        }
                    }
                });
            }
        });
    </script>
</body>
</html>

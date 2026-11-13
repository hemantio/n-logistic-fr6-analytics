<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%@ taglib uri="http://java.sun.com/jsp/jstl/core" prefix="c" %>
<%@ taglib uri="http://java.sun.com/jsp/jstl/fmt" prefix="fmt" %>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>FR6 Analytics - ABC (Pareto) Classification</title>
    <link rel="stylesheet" href="${pageContext.request.contextPath}/assets/css/fr6/bootstrap.min.css">
    <link rel="stylesheet" href="${pageContext.request.contextPath}/assets/css/fr6/analytics.css">
</head>
<body class="fr6-body">

    <%@ include file="navbar.jspf" %>

    <div class="container-fluid px-4 fr6-main-container">

        <!-- Filter Card -->
        <div class="fr6-filter-card">
            <form method="GET" action="${pageContext.request.contextPath}/fr6/analytics/abc-classification" class="row g-3 align-items-end">
                <div class="col-md-4">
                    <label class="form-label small fw-semibold text-muted">Filter by Category</label>
                    <input type="text" name="category" class="form-control form-control-sm" placeholder="e.g. Textiles, Spices, Engineering" value="<c:out value="${filter.category}"/>">
                </div>
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
                    <a href="${pageContext.request.contextPath}/fr6/analytics/abc-classification" class="btn btn-sm btn-outline-secondary">Reset</a>
                </div>
            </form>
        </div>

        <!-- Pareto Summary Cards -->
        <div class="row g-4 mb-4">
            <div class="col-md-4">
                <div class="fr6-kpi-card border-success">
                    <div class="d-flex justify-content-between align-items-center">
                        <div>
                            <div class="fr6-kpi-title text-success">Class A (Top 70% Contribution)</div>
                            <div class="fr6-kpi-value text-success">${abcSummary.countA} Products</div>
                            <div class="fr6-kpi-sub">
                                Total Value: INR <fmt:formatNumber value="${abcSummary.sumA}" pattern="#,##0.00"/>
                            </div>
                        </div>
                        <span class="badge fr6-badge-a fs-5 px-3 py-2">Class A</span>
                    </div>
                </div>
            </div>
            <div class="col-md-4">
                <div class="fr6-kpi-card border-warning">
                    <div class="d-flex justify-content-between align-items-center">
                        <div>
                            <div class="fr6-kpi-title text-warning">Class B (Next 20% Contribution)</div>
                            <div class="fr6-kpi-value text-warning">${abcSummary.countB} Products</div>
                            <div class="fr6-kpi-sub">
                                Total Value: INR <fmt:formatNumber value="${abcSummary.sumB}" pattern="#,##0.00"/>
                            </div>
                        </div>
                        <span class="badge fr6-badge-b fs-5 px-3 py-2">Class B</span>
                    </div>
                </div>
            </div>
            <div class="col-md-4">
                <div class="fr6-kpi-card border-danger">
                    <div class="d-flex justify-content-between align-items-center">
                        <div>
                            <div class="fr6-kpi-title text-danger">Class C (Last 10% Contribution)</div>
                            <div class="fr6-kpi-value text-danger">${abcSummary.countC} Products</div>
                            <div class="fr6-kpi-sub">
                                Total Value: INR <fmt:formatNumber value="${abcSummary.sumC}" pattern="#,##0.00"/>
                            </div>
                        </div>
                        <span class="badge fr6-badge-c fs-5 px-3 py-2">Class C</span>
                    </div>
                </div>
            </div>
        </div>

        <div class="row g-4 mb-4">
            <!-- Left Chart -->
            <div class="col-lg-4">
                <div class="fr6-card h-100">
                    <div class="fr6-card-header">
                        <span>&#x1F967; Pareto Classification Ratio</span>
                    </div>
                    <div class="fr6-card-body d-flex align-items-center justify-content-center">
                        <canvas id="abcDonutChart" height="230"></canvas>
                    </div>
                </div>
            </div>

            <!-- Right: Product ABC Table -->
            <div class="col-lg-8">
                <div class="fr6-card h-100">
                    <div class="fr6-card-header">
                        <span>&#x1F4CB; Product ABC Pareto Classification (SRS Section 7.9)</span>
                    </div>
                    <div class="table-responsive">
                        <table class="table fr6-table table-hover align-middle">
                            <thead>
                                <tr>
                                    <th>Class</th>
                                    <th>Product Name</th>
                                    <th>SKU</th>
                                    <th>Category</th>
                                    <th class="text-end">Annual Sales Value</th>
                                    <th class="text-end">Cumulative %</th>
                                    <th>Calculated On</th>
                                </tr>
                            </thead>
                            <tbody>
                                <c:forEach var="item" items="${productResults}">
                                    <tr>
                                        <td>
                                            <span class="badge ${item.abcClass == 'A' ? 'fr6-badge-a' : (item.abcClass == 'B' ? 'fr6-badge-b' : 'fr6-badge-c')} fs-6">
                                                <c:out value="${item.abcClass}"/>
                                            </span>
                                        </td>
                                        <td class="fw-semibold"><c:out value="${item.productName}"/></td>
                                        <td><code><c:out value="${item.sku}"/></code></td>
                                        <td><span class="badge bg-light text-dark border"><c:out value="${item.category}"/></span></td>
                                        <td class="text-end fw-bold">INR <fmt:formatNumber value="${item.annualValue}" pattern="#,##0.00"/></td>
                                        <td class="text-end"><fmt:formatNumber value="${item.cumulativePct}" pattern="0.00"/>%</td>
                                        <td class="text-muted small"><c:out value="${item.calculatedOn}"/></td>
                                    </tr>
                                </c:forEach>
                                <c:if test="${empty productResults}">
                                    <tr><td colspan="7" class="text-center text-muted py-3">No ABC classification records found.</td></tr>
                                </c:if>
                            </tbody>
                        </table>
                    </div>
                </div>
            </div>
        </div>

        <!-- Customer Pareto Table (FR6.3 Customer Scope) -->
        <div class="fr6-card">
            <div class="fr6-card-header">
                <span>&#x1F465; Customer Contribution Pareto Analysis</span>
            </div>
            <div class="table-responsive">
                <table class="table fr6-table table-hover align-middle">
                    <thead>
                        <tr>
                            <th>Class</th>
                            <th>Contact Person</th>
                            <th>Company</th>
                            <th class="text-end">Total Contribution</th>
                            <th class="text-end">Cumulative %</th>
                        </tr>
                    </thead>
                    <tbody>
                        <c:forEach var="cust" items="${customerResults}">
                            <tr>
                                <td>
                                    <span class="badge ${cust.abcClass == 'A' ? 'fr6-badge-a' : (cust.abcClass == 'B' ? 'fr6-badge-b' : 'fr6-badge-c')} fs-6">
                                        <c:out value="${cust.abcClass}"/>
                                    </span>
                                </td>
                                <td class="fw-semibold"><c:out value="${cust.contactPerson}"/></td>
                                <td><c:out value="${cust.customerCompany}"/></td>
                                <td class="text-end fw-bold">INR <fmt:formatNumber value="${cust.totalContribution}" pattern="#,##0.00"/></td>
                                <td class="text-end"><fmt:formatNumber value="${cust.cumulativePct}" pattern="0.00"/>%</td>
                            </tr>
                        </c:forEach>
                        <c:if test="${empty customerResults}">
                            <tr><td colspan="5" class="text-center text-muted py-3">No customer contribution records found.</td></tr>
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
            const ctx = document.getElementById('abcDonutChart');
            if (ctx) {
                new Chart(ctx, {
                    type: 'pie',
                    data: {
                        labels: [
                            'Class A (Top 70%) - ${abcSummary.countA} Products',
                            'Class B (Next 20%) - ${abcSummary.countB} Products',
                            'Class C (Last 10%) - ${abcSummary.countC} Products'
                        ],
                        datasets: [{
                            data: [${abcSummary.sumA}, ${abcSummary.sumB}, ${abcSummary.sumC}],
                            backgroundColor: ['#16a34a', '#eab308', '#dc2626'],
                            borderWidth: 2
                        }]
                    },
                    options: {
                        responsive: true,
                        plugins: {
                            legend: { position: 'bottom' },
                            tooltip: {
                                callbacks: {
                                    label: function(c) {
                                        return c.label + ': INR ' + c.raw.toLocaleString();
                                    }
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

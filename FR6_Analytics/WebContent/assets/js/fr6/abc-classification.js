/**
 * FR6 ABC Pareto Classification Visualization Module
 */
const FR6AbcClassification = (function () {
    'use strict';

    function renderPieChart(canvasId, countA, countB, countC, sumA, sumB, sumC) {
        const ctx = document.getElementById(canvasId);
        if (!ctx || typeof Chart === 'undefined') return null;

        return new Chart(ctx, {
            type: 'pie',
            data: {
                labels: [
                    'Class A (Top 70%) - ' + countA + ' Products',
                    'Class B (Next 20%) - ' + countB + ' Products',
                    'Class C (Last 10%) - ' + countC + ' Products'
                ],
                datasets: [{
                    data: [sumA, sumB, sumC],
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

    return {
        renderPieChart: renderPieChart
    };
})();

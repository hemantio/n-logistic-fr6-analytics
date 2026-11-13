/**
 * FR6 Inventory Turnover Visualization Module
 */
const FR6InventoryTurnover = (function () {
    'use strict';

    function renderBarChart(canvasId, labels, ratios) {
        const ctx = document.getElementById(canvasId);
        if (!ctx || typeof Chart === 'undefined') return null;

        return new Chart(ctx, {
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

    return {
        renderBarChart: renderBarChart
    };
})();

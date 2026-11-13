/**
 * FR6 Sales Trends Visualization Module
 */
const FR6SalesTrends = (function () {
    'use strict';

    function renderLineChart(canvasId, labels, sales, quantities) {
        const ctx = document.getElementById(canvasId);
        if (!ctx || typeof Chart === 'undefined') return null;

        return new Chart(ctx, {
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
                        title: { display: true, text: 'Revenue (INR)' }
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

    return {
        renderLineChart: renderLineChart
    };
})();

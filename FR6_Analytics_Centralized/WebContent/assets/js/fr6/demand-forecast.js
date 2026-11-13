/**
 * FR6 Demand Forecasting Visualization Module
 */
const FR6DemandForecast = (function () {
    'use strict';

    function renderForecastChart(canvasId, labels, predicted, multipliers) {
        const ctx = document.getElementById(canvasId);
        if (!ctx || typeof Chart === 'undefined') return null;

        return new Chart(ctx, {
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
                    }
                ]
            },
            options: {
                responsive: true,
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
                        title: { display: true, text: 'Multiplier' }
                    }
                }
            }
        });
    }

    return {
        renderForecastChart: renderForecastChart
    };
})();

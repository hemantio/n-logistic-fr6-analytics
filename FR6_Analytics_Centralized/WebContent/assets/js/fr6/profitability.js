/**
 * FR6 Profitability Visualization Module
 */
const FR6Profitability = (function () {
    'use strict';

    function renderComboChart(canvasId, labels, revenues, costs, margins) {
        const ctx = document.getElementById(canvasId);
        if (!ctx || typeof Chart === 'undefined') return null;

        return new Chart(ctx, {
            type: 'bar',
            data: {
                labels: labels,
                datasets: [
                    {
                        label: 'Revenue (INR)',
                        data: revenues,
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
                scales: {
                    y: {
                        beginAtZero: true,
                        title: { display: true, text: 'Amount (INR)' }
                    },
                    y1: {
                        beginAtZero: true,
                        position: 'right',
                        grid: { drawOnChartArea: false },
                        title: { display: true, text: 'Margin (%)' }
                    }
                }
            }
        });
    }

    return {
        renderComboChart: renderComboChart
    };
})();

/**
 * FR6 Analytics Dashboard JavaScript Helpers
 * Scoped under FR6Analytics to prevent global namespace pollution
 */
const FR6Analytics = (function () {
    'use strict';

    function formatCurrency(amount) {
        if (amount === undefined || amount === null) return 'INR 0.00';
        return 'INR ' + Number(amount).toLocaleString('en-IN', {
            minimumFractionDigits: 2,
            maximumFractionDigits: 2
        });
    }

    function initChart(canvasId, config) {
        const el = document.getElementById(canvasId);
        if (el && typeof Chart !== 'undefined') {
            return new Chart(el, config);
        }
        return null;
    }

    return {
        formatCurrency: formatCurrency,
        initChart: initChart
    };
})();

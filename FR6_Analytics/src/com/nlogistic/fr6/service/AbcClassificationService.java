package com.nlogistic.fr6.service;

import java.math.BigDecimal;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import com.nlogistic.fr6.dao.AbcClassificationDAO;
import com.nlogistic.fr6.dto.AnalyticsFilterDTO;
import com.nlogistic.fr6.model.AbcClassificationResult;

/**
 * Service class for FR6.3 ABC (Pareto) Classification.
 */
public class AbcClassificationService {

    private final AbcClassificationDAO abcDAO;

    public AbcClassificationService() {
        this.abcDAO = new AbcClassificationDAO();
    }

    public AbcClassificationService(AbcClassificationDAO abcDAO) {
        this.abcDAO = abcDAO;
    }

    public List<AbcClassificationResult> getProductClassifications(AnalyticsFilterDTO filter) {
        return abcDAO.getAbcClassifications(filter);
    }

    public List<Map<String, Object>> getCustomerAbcAnalysis(AnalyticsFilterDTO filter) {
        return abcDAO.getCustomerAbcAnalysis(filter);
    }

    /**
     * Calculates summary counts and total contribution amounts per class for Chart.js pie/donut charts.
     */
    public Map<String, Object> getAbcSummary(List<AbcClassificationResult> list) {
        int countA = 0;
        int countB = 0;
        int countC = 0;
        BigDecimal sumA = BigDecimal.ZERO;
        BigDecimal sumB = BigDecimal.ZERO;
        BigDecimal sumC = BigDecimal.ZERO;

        for (AbcClassificationResult r : list) {
            if ("A".equalsIgnoreCase(r.getAbcClass())) {
                countA++;
                sumA = sumA.add(r.getAnnualValue());
            } else if ("B".equalsIgnoreCase(r.getAbcClass())) {
                countB++;
                sumB = sumB.add(r.getAnnualValue());
            } else {
                countC++;
                sumC = sumC.add(r.getAnnualValue());
            }
        }

        Map<String, Object> summary = new HashMap<>();
        summary.put("countA", countA);
        summary.put("countB", countB);
        summary.put("countC", countC);
        summary.put("sumA", sumA);
        summary.put("sumB", sumB);
        summary.put("sumC", sumC);
        return summary;
    }
}

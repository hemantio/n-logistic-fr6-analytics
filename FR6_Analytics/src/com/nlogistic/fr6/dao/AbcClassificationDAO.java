package com.nlogistic.fr6.dao;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.sql.Connection;
import java.sql.Date;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.logging.Level;
import java.util.logging.Logger;

import com.nlogistic.fr6.config.AnalyticsConnectionProvider;
import com.nlogistic.fr6.dto.AnalyticsFilterDTO;
import com.nlogistic.fr6.exception.AnalyticsDataException;
import com.nlogistic.fr6.model.AbcClassificationResult;

/**
 * JDBC Data Access Object for FR6.3 ABC (Pareto) Classification.
 * Thresholds per SRS Section 7.9: A = top 70%, B = next 20%, C = last 10%.
 */
public class AbcClassificationDAO {

    private static final Logger LOGGER = Logger.getLogger(AbcClassificationDAO.class.getName());

    private final AnalyticsConnectionProvider connectionProvider;

    public AbcClassificationDAO() {
        this(AnalyticsConnectionProvider.getInstance());
    }

    public AbcClassificationDAO(AnalyticsConnectionProvider connectionProvider) {
        this.connectionProvider = connectionProvider;
    }

    /**
     * Reads cached ABC classification results joined with products table.
     */
    public List<AbcClassificationResult> getAbcClassifications(AnalyticsFilterDTO filter) {
        List<AbcClassificationResult> list = new ArrayList<>();
        StringBuilder sql = new StringBuilder(
            "SELECT abc.result_id, abc.product_id, abc.annual_value, abc.cumulative_pct, " +
            "abc.abc_class, abc.calculated_on, abc.created_at, " +
            "p.product_name, p.sku, p.category " +
            "FROM abc_classification_result abc " +
            "JOIN products p ON abc.product_id = p.product_id " +
            "WHERE 1=1 "
        );

        if (filter.getCompanyId() != null && !"CONSUMER".equalsIgnoreCase(filter.getUserRole())) {
            sql.append("AND p.owner_company_id = ? ");
        }
        if (filter.getCategory() != null && !filter.getCategory().trim().isEmpty()) {
            sql.append("AND p.category = ? ");
        }
        sql.append("ORDER BY abc.annual_value DESC, abc.cumulative_pct ASC");

        try (Connection conn = connectionProvider.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql.toString())) {
            int idx = 1;
            if (filter.getCompanyId() != null && !"CONSUMER".equalsIgnoreCase(filter.getUserRole())) {
                ps.setInt(idx++, filter.getCompanyId());
            }
            if (filter.getCategory() != null && !filter.getCategory().trim().isEmpty()) {
                ps.setString(idx++, filter.getCategory().trim());
            }

            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    AbcClassificationResult row = new AbcClassificationResult();
                    row.setResultId(rs.getInt("result_id"));
                    row.setProductId(rs.getInt("product_id"));
                    row.setAnnualValue(rs.getBigDecimal("annual_value"));
                    row.setCumulativePct(rs.getBigDecimal("cumulative_pct"));
                    row.setAbcClass(rs.getString("abc_class"));
                    row.setCalculatedOn(rs.getDate("calculated_on"));
                    row.setCreatedAt(rs.getTimestamp("created_at"));
                    row.setProductName(rs.getString("product_name"));
                    row.setSku(rs.getString("sku"));
                    row.setCategory(rs.getString("category"));
                    list.add(row);
                }
            }
        } catch (SQLException e) {
            LOGGER.log(Level.SEVERE, "Error fetching ABC classification results", e);
            throw new AnalyticsDataException("Failed to retrieve ABC classifications", e);
        }
        return list;
    }

    /**
     * Calculates customer ABC contribution dynamically from sales transactions (SRS FR6.3).
     * Solves GAP-01 by providing customer Pareto analysis in-memory without altering ERD schema.
     */
    public List<Map<String, Object>> getCustomerAbcAnalysis(AnalyticsFilterDTO filter) {
        List<Map<String, Object>> list = new ArrayList<>();
        StringBuilder sql = new StringBuilder(
            "SELECT c.customer_id, c.contact_person, comp.company_name AS customer_company, " +
            "COALESCE(SUM(st.total_amount), 0.00) AS total_contribution " +
            "FROM customers c " +
            "LEFT JOIN companies comp ON c.company_id = comp.company_id " +
            "LEFT JOIN sales_transactions st ON c.customer_id = st.customer_id " +
            "WHERE 1=1 "
        );

        if (filter.getCompanyId() != null && "CONSUMER".equalsIgnoreCase(filter.getUserRole())) {
            sql.append("AND c.company_id = ? ");
        }
        sql.append("GROUP BY c.customer_id, c.contact_person, customer_company ");
        sql.append("ORDER BY total_contribution DESC");

        try (Connection conn = connectionProvider.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql.toString())) {
            if (filter.getCompanyId() != null && "CONSUMER".equalsIgnoreCase(filter.getUserRole())) {
                ps.setInt(1, filter.getCompanyId());
            }

            List<Map<String, Object>> rawRows = new ArrayList<>();
            BigDecimal grandTotal = BigDecimal.ZERO;

            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    Map<String, Object> map = new HashMap<>();
                    map.put("customerId", rs.getInt("customer_id"));
                    map.put("contactPerson", rs.getString("contact_person"));
                    map.put("customerCompany", rs.getString("customer_company"));
                    BigDecimal val = rs.getBigDecimal("total_contribution");
                    map.put("totalContribution", val);
                    grandTotal = grandTotal.add(val);
                    rawRows.add(map);
                }
            }

            // Calculate cumulative % and Pareto class
            BigDecimal runningSum = BigDecimal.ZERO;
            for (Map<String, Object> row : rawRows) {
                BigDecimal val = (BigDecimal) row.get("totalContribution");
                runningSum = runningSum.add(val);
                BigDecimal cumulativePct = BigDecimal.ZERO;
                if (grandTotal.compareTo(BigDecimal.ZERO) > 0) {
                    cumulativePct = runningSum.divide(grandTotal, 4, RoundingMode.HALF_UP)
                                              .multiply(BigDecimal.valueOf(100))
                                              .setScale(2, RoundingMode.HALF_UP);
                }
                String abcClass;
                if (cumulativePct.compareTo(BigDecimal.valueOf(70.00)) <= 0) {
                    abcClass = "A";
                } else if (cumulativePct.compareTo(BigDecimal.valueOf(90.00)) <= 0) {
                    abcClass = "B";
                } else {
                    abcClass = "C";
                }
                row.put("cumulativePct", cumulativePct);
                row.put("abcClass", abcClass);
                list.add(row);
            }

        } catch (SQLException e) {
            LOGGER.log(Level.SEVERE, "Error calculating customer ABC analysis", e);
            throw new AnalyticsDataException("Failed to calculate customer ABC analysis", e);
        }
        return list;
    }

    /**
     * Recalculates product ABC Pareto classification from sales transactions and refreshes abc_classification_result.
     * Uses A = top 70%, B = next 20%, C = last 10% per SRS Section 7.9.
     */
    public int refreshAbcClassification(Connection conn) throws SQLException {
        // Step 1: Query annual sales value per product
        String sql = 
            "SELECT p.product_id, COALESCE(SUM(st.total_amount), 0.00) AS annual_sales " +
            "FROM products p " +
            "LEFT JOIN sales_transactions st ON p.product_id = st.product_id " +
            "GROUP BY p.product_id " +
            "ORDER BY annual_sales DESC";

        List<AbcClassificationResult> results = new ArrayList<>();
        BigDecimal totalPortfolioValue = BigDecimal.ZERO;

        try (PreparedStatement ps = conn.prepareStatement(sql);
             ResultSet rs = ps.executeQuery()) {
            while (rs.next()) {
                AbcClassificationResult row = new AbcClassificationResult();
                row.setProductId(rs.getInt("product_id"));
                BigDecimal sales = rs.getBigDecimal("annual_sales");
                row.setAnnualValue(sales);
                totalPortfolioValue = totalPortfolioValue.add(sales);
                results.add(row);
            }
        }

        // Step 2: Calculate cumulative percentage and assign A, B, or C
        BigDecimal runningTotal = BigDecimal.ZERO;
        Date today = Date.valueOf(LocalDate.now());

        for (AbcClassificationResult item : results) {
            runningTotal = runningTotal.add(item.getAnnualValue());
            BigDecimal cumulativePct = BigDecimal.ZERO;
            if (totalPortfolioValue.compareTo(BigDecimal.ZERO) > 0) {
                cumulativePct = runningTotal.divide(totalPortfolioValue, 4, RoundingMode.HALF_UP)
                                            .multiply(BigDecimal.valueOf(100))
                                            .setScale(2, RoundingMode.HALF_UP);
            }
            item.setCumulativePct(cumulativePct);
            item.setCalculatedOn(today);

            if (cumulativePct.compareTo(BigDecimal.valueOf(70.00)) <= 0) {
                item.setAbcClass("A");
            } else if (cumulativePct.compareTo(BigDecimal.valueOf(90.00)) <= 0) {
                item.setAbcClass("B");
            } else {
                item.setAbcClass("C");
            }
        }

        // Step 3: Transactional replace
        try (PreparedStatement delPs = conn.prepareStatement("DELETE FROM abc_classification_result")) {
            delPs.executeUpdate();
        }

        String insertSql = 
            "INSERT INTO abc_classification_result (product_id, annual_value, cumulative_pct, abc_class, calculated_on) " +
            "VALUES (?, ?, ?, ?, ?)";
        int inserted = 0;
        try (PreparedStatement insPs = conn.prepareStatement(insertSql)) {
            for (AbcClassificationResult item : results) {
                insPs.setInt(1, item.getProductId());
                insPs.setBigDecimal(2, item.getAnnualValue());
                insPs.setBigDecimal(3, item.getCumulativePct());
                insPs.setString(4, item.getAbcClass());
                insPs.setDate(5, item.getCalculatedOn());
                insPs.addBatch();
                inserted++;
            }
            insPs.executeBatch();
        }
        return inserted;
    }
}

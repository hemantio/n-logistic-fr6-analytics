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
import java.util.List;
import java.util.logging.Level;
import java.util.logging.Logger;

import com.nlogistic.fr6.config.AnalyticsConnectionProvider;
import com.nlogistic.fr6.dto.AnalyticsFilterDTO;
import com.nlogistic.fr6.exception.AnalyticsDataException;
import com.nlogistic.fr6.model.InventoryTurnoverResult;

/**
 * JDBC Data Access Object for FR6.4 Inventory Turnover Ratio.
 * Formula per SRS Section 7.9: turnover_ratio = cogs / avg_inventory.
 */
public class InventoryTurnoverDAO {

    private static final Logger LOGGER = Logger.getLogger(InventoryTurnoverDAO.class.getName());

    private final AnalyticsConnectionProvider connectionProvider;

    public InventoryTurnoverDAO() {
        this(AnalyticsConnectionProvider.getInstance());
    }

    public InventoryTurnoverDAO(AnalyticsConnectionProvider connectionProvider) {
        this.connectionProvider = connectionProvider;
    }

    /**
     * Reads cached inventory turnover results joined with products table.
     */
    public List<InventoryTurnoverResult> getInventoryTurnover(AnalyticsFilterDTO filter) {
        List<InventoryTurnoverResult> list = new ArrayList<>();
        StringBuilder sql = new StringBuilder(
            "SELECT itr.result_id, itr.product_id, itr.period_start, itr.period_end, " +
            "itr.cogs, itr.avg_inventory, itr.turnover_ratio, itr.created_at, " +
            "p.product_name, p.sku " +
            "FROM inventory_turnover_result itr " +
            "JOIN products p ON itr.product_id = p.product_id " +
            "WHERE 1=1 "
        );

        if (filter.getCompanyId() != null && !"CONSUMER".equalsIgnoreCase(filter.getUserRole())) {
            sql.append("AND p.owner_company_id = ? ");
        }
        if (filter.getProductId() != null) {
            sql.append("AND p.product_id = ? ");
        }
        sql.append("ORDER BY itr.turnover_ratio DESC, itr.cogs DESC");

        try (Connection conn = connectionProvider.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql.toString())) {
            int idx = 1;
            if (filter.getCompanyId() != null && !"CONSUMER".equalsIgnoreCase(filter.getUserRole())) {
                ps.setInt(idx++, filter.getCompanyId());
            }
            if (filter.getProductId() != null) {
                ps.setInt(idx++, filter.getProductId());
            }

            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    InventoryTurnoverResult row = new InventoryTurnoverResult();
                    row.setResultId(rs.getInt("result_id"));
                    row.setProductId(rs.getInt("product_id"));
                    row.setPeriodStart(rs.getDate("period_start"));
                    row.setPeriodEnd(rs.getDate("period_end"));
                    row.setCogs(rs.getBigDecimal("cogs"));
                    row.setAvgInventory(rs.getBigDecimal("avg_inventory"));
                    row.setTurnoverRatio(rs.getBigDecimal("turnover_ratio"));
                    row.setCreatedAt(rs.getTimestamp("created_at"));
                    row.setProductName(rs.getString("product_name"));
                    row.setSku(rs.getString("sku"));
                    list.add(row);
                }
            }
        } catch (SQLException e) {
            LOGGER.log(Level.SEVERE, "Error fetching inventory turnover results", e);
            throw new AnalyticsDataException("Failed to retrieve inventory turnover", e);
        }
        return list;
    }

    /**
     * Recalculates inventory turnover ratio per product from inventory_ledger and stock.
     */
    public int refreshInventoryTurnover(Connection conn, Date periodStart, Date periodEnd) throws SQLException {
        if (periodStart == null) {
            periodStart = Date.valueOf(LocalDate.now().minusMonths(3).withDayOfMonth(1));
        }
        if (periodEnd == null) {
            periodEnd = Date.valueOf(LocalDate.now());
        }

        // Query COGS (cost of goods sold from OUT transactions x unit_price) and current stock value
        String sql = 
            "SELECT p.product_id, p.unit_price, " +
            "COALESCE(SUM(CASE WHEN il.txn_type = 'OUT' THEN il.quantity * p.unit_price ELSE 0 END), 0.00) AS total_cogs, " +
            "COALESCE(s.quantity, 0) AS current_stock_qty " +
            "FROM products p " +
            "LEFT JOIN stock s ON p.product_id = s.product_id " +
            "LEFT JOIN inventory_ledger il ON p.product_id = il.product_id AND DATE(il.txn_time) BETWEEN ? AND ? " +
            "GROUP BY p.product_id, p.unit_price, s.quantity";

        List<InventoryTurnoverResult> results = new ArrayList<>();

        try (PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setDate(1, periodStart);
            ps.setDate(2, periodEnd);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    int productId = rs.getInt("product_id");
                    BigDecimal unitPrice = rs.getBigDecimal("unit_price");
                    BigDecimal cogs = rs.getBigDecimal("total_cogs");
                    int stockQty = rs.getInt("current_stock_qty");

                    // Average inventory value: estimated based on current stock value and outgoing volume
                    BigDecimal avgInventoryValue = unitPrice.multiply(BigDecimal.valueOf(stockQty));
                    if (avgInventoryValue.compareTo(BigDecimal.ZERO) == 0 && cogs.compareTo(BigDecimal.ZERO) > 0) {
                        // Fallback proxy: at least half of the sold goods
                        avgInventoryValue = cogs.multiply(BigDecimal.valueOf(0.5));
                    }
                    if (avgInventoryValue.compareTo(BigDecimal.ZERO) <= 0) {
                        avgInventoryValue = BigDecimal.valueOf(1.00); // Prevent divide by zero
                    }

                    BigDecimal ratio = cogs.divide(avgInventoryValue, 4, RoundingMode.HALF_UP)
                                           .setScale(2, RoundingMode.HALF_UP);

                    InventoryTurnoverResult item = new InventoryTurnoverResult();
                    item.setProductId(productId);
                    item.setPeriodStart(periodStart);
                    item.setPeriodEnd(periodEnd);
                    item.setCogs(cogs);
                    item.setAvgInventory(avgInventoryValue);
                    item.setTurnoverRatio(ratio);
                    results.add(item);
                }
            }
        }

        // Transactionally clear and insert
        try (PreparedStatement delPs = conn.prepareStatement("DELETE FROM inventory_turnover_result")) {
            delPs.executeUpdate();
        }

        String insertSql = 
            "INSERT INTO inventory_turnover_result (product_id, period_start, period_end, cogs, avg_inventory, turnover_ratio) " +
            "VALUES (?, ?, ?, ?, ?, ?)";
        int inserted = 0;
        try (PreparedStatement insPs = conn.prepareStatement(insertSql)) {
            for (InventoryTurnoverResult item : results) {
                insPs.setInt(1, item.getProductId());
                insPs.setDate(2, item.getPeriodStart());
                insPs.setDate(3, item.getPeriodEnd());
                insPs.setBigDecimal(4, item.getCogs());
                insPs.setBigDecimal(5, item.getAvgInventory());
                insPs.setBigDecimal(6, item.getTurnoverRatio());
                insPs.addBatch();
                inserted++;
            }
            insPs.executeBatch();
        }
        return inserted;
    }
}

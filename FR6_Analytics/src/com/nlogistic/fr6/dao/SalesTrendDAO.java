package com.nlogistic.fr6.dao;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.sql.Connection;
import java.sql.Date;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.logging.Level;
import java.util.logging.Logger;

import com.nlogistic.fr6.config.AnalyticsConnectionProvider;
import com.nlogistic.fr6.dto.AnalyticsFilterDTO;
import com.nlogistic.fr6.exception.AnalyticsDataException;
import com.nlogistic.fr6.model.SalesTrendResult;

/**
 * JDBC Data Access Object for FR6.2 Sales Trend Analysis.
 * Reads and maintains sales_trend_result and calculates live dimensions (Route, Product, Customer).
 */
public class SalesTrendDAO {

    private static final Logger LOGGER = Logger.getLogger(SalesTrendDAO.class.getName());

    private final AnalyticsConnectionProvider connectionProvider;

    public SalesTrendDAO() {
        this(AnalyticsConnectionProvider.getInstance());
    }

    public SalesTrendDAO(AnalyticsConnectionProvider connectionProvider) {
        this.connectionProvider = connectionProvider;
    }

    /**
     * Reads cached route sales trends from sales_trend_result with port names.
     */
    public List<SalesTrendResult> getRouteSalesTrends(AnalyticsFilterDTO filter) {
        List<SalesTrendResult> list = new ArrayList<>();
        StringBuilder sql = new StringBuilder(
            "SELECT str.result_id, str.period_month, str.origin_port_id, str.dest_port_id, " +
            "str.total_sales, str.total_qty, str.growth_pct, str.created_at, " +
            "p1.port_name AS origin_port_name, p2.port_name AS dest_port_name " +
            "FROM sales_trend_result str " +
            "LEFT JOIN ports p1 ON str.origin_port_id = p1.port_id " +
            "LEFT JOIN ports p2 ON str.dest_port_id = p2.port_id " +
            "WHERE 1=1 "
        );

        if (filter.getStartDate() != null && filter.getEndDate() != null) {
            sql.append("AND str.period_month BETWEEN ? AND ? ");
        }
        if (filter.getOriginPortId() != null) {
            sql.append("AND str.origin_port_id = ? ");
        }
        if (filter.getDestPortId() != null) {
            sql.append("AND str.dest_port_id = ? ");
        }
        sql.append("ORDER BY str.period_month ASC, str.total_sales DESC");

        try (Connection conn = connectionProvider.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql.toString())) {
            int idx = 1;
            if (filter.getStartDate() != null && filter.getEndDate() != null) {
                ps.setDate(idx++, filter.getStartDate());
                ps.setDate(idx++, filter.getEndDate());
            }
            if (filter.getOriginPortId() != null) {
                ps.setInt(idx++, filter.getOriginPortId());
            }
            if (filter.getDestPortId() != null) {
                ps.setInt(idx++, filter.getDestPortId());
            }

            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    SalesTrendResult row = new SalesTrendResult();
                    row.setResultId(rs.getInt("result_id"));
                    row.setPeriodMonth(rs.getDate("period_month"));
                    row.setOriginPortId(rs.getInt("origin_port_id"));
                    row.setDestPortId(rs.getInt("dest_port_id"));
                    row.setTotalSales(rs.getBigDecimal("total_sales"));
                    row.setTotalQty(rs.getInt("total_qty"));
                    row.setGrowthPct(rs.getBigDecimal("growth_pct"));
                    row.setCreatedAt(rs.getTimestamp("created_at"));
                    row.setOriginPortName(rs.getString("origin_port_name"));
                    row.setDestPortName(rs.getString("dest_port_name"));
                    list.add(row);
                }
            }
        } catch (SQLException e) {
            LOGGER.log(Level.SEVERE, "Error fetching route sales trends", e);
            throw new AnalyticsDataException("Failed to retrieve route sales trends", e);
        }
        return list;
    }

    /**
     * Calculates product sales trends from operational sales_transactions.
     */
    public List<Map<String, Object>> getProductSalesTrends(AnalyticsFilterDTO filter) {
        List<Map<String, Object>> list = new ArrayList<>();
        StringBuilder sql = new StringBuilder(
            "SELECT DATE_FORMAT(st.sale_date, '%Y-%m-01') AS period_month, " +
            "p.product_id, p.product_name, p.sku, p.category, " +
            "SUM(st.total_amount) AS total_sales, SUM(st.quantity) AS total_qty " +
            "FROM sales_transactions st " +
            "JOIN products p ON st.product_id = p.product_id " +
            "WHERE 1=1 "
        );

        if (filter.getCompanyId() != null && !"CONSUMER".equalsIgnoreCase(filter.getUserRole())) {
            sql.append("AND p.owner_company_id = ? ");
        }
        if (filter.getProductId() != null) {
            sql.append("AND p.product_id = ? ");
        }
        if (filter.getStartDate() != null && filter.getEndDate() != null) {
            sql.append("AND st.sale_date BETWEEN ? AND ? ");
        }
        sql.append("GROUP BY period_month, p.product_id, p.product_name, p.sku, p.category ");
        sql.append("ORDER BY period_month ASC, total_sales DESC");

        try (Connection conn = connectionProvider.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql.toString())) {
            int idx = 1;
            if (filter.getCompanyId() != null && !"CONSUMER".equalsIgnoreCase(filter.getUserRole())) {
                ps.setInt(idx++, filter.getCompanyId());
            }
            if (filter.getProductId() != null) {
                ps.setInt(idx++, filter.getProductId());
            }
            if (filter.getStartDate() != null && filter.getEndDate() != null) {
                ps.setDate(idx++, filter.getStartDate());
                ps.setDate(idx++, filter.getEndDate());
            }

            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    Map<String, Object> map = new HashMap<>();
                    map.put("periodMonth", rs.getString("period_month"));
                    map.put("productId", rs.getInt("product_id"));
                    map.put("productName", rs.getString("product_name"));
                    map.put("sku", rs.getString("sku"));
                    map.put("category", rs.getString("category"));
                    map.put("totalSales", rs.getBigDecimal("total_sales"));
                    map.put("totalQty", rs.getInt("total_qty"));
                    list.add(map);
                }
            }
        } catch (SQLException e) {
            LOGGER.log(Level.SEVERE, "Error fetching product sales trends", e);
            throw new AnalyticsDataException("Failed to retrieve product sales trends", e);
        }
        return list;
    }

    /**
     * Calculates customer sales trends from operational sales_transactions.
     */
    public List<Map<String, Object>> getCustomerSalesTrends(AnalyticsFilterDTO filter) {
        List<Map<String, Object>> list = new ArrayList<>();
        StringBuilder sql = new StringBuilder(
            "SELECT DATE_FORMAT(st.sale_date, '%Y-%m-01') AS period_month, " +
            "c.customer_id, c.contact_person, comp.company_name AS customer_company, " +
            "SUM(st.total_amount) AS total_sales, SUM(st.quantity) AS total_qty " +
            "FROM sales_transactions st " +
            "JOIN customers c ON st.customer_id = c.customer_id " +
            "LEFT JOIN companies comp ON c.company_id = comp.company_id " +
            "JOIN products p ON st.product_id = p.product_id " +
            "WHERE 1=1 "
        );

        if (filter.getCompanyId() != null) {
            if ("CONSUMER".equalsIgnoreCase(filter.getUserRole())) {
                sql.append("AND c.company_id = ? ");
            } else {
                sql.append("AND p.owner_company_id = ? ");
            }
        }
        if (filter.getCustomerId() != null) {
            sql.append("AND c.customer_id = ? ");
        }
        if (filter.getStartDate() != null && filter.getEndDate() != null) {
            sql.append("AND st.sale_date BETWEEN ? AND ? ");
        }
        sql.append("GROUP BY period_month, c.customer_id, c.contact_person, customer_company ");
        sql.append("ORDER BY period_month ASC, total_sales DESC");

        try (Connection conn = connectionProvider.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql.toString())) {
            int idx = 1;
            if (filter.getCompanyId() != null) {
                ps.setInt(idx++, filter.getCompanyId());
            }
            if (filter.getCustomerId() != null) {
                ps.setInt(idx++, filter.getCustomerId());
            }
            if (filter.getStartDate() != null && filter.getEndDate() != null) {
                ps.setDate(idx++, filter.getStartDate());
                ps.setDate(idx++, filter.getEndDate());
            }

            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    Map<String, Object> map = new HashMap<>();
                    map.put("periodMonth", rs.getString("period_month"));
                    map.put("customerId", rs.getInt("customer_id"));
                    map.put("contactPerson", rs.getString("contact_person"));
                    map.put("customerCompany", rs.getString("customer_company"));
                    map.put("totalSales", rs.getBigDecimal("total_sales"));
                    map.put("totalQty", rs.getInt("total_qty"));
                    list.add(map);
                }
            }
        } catch (SQLException e) {
            LOGGER.log(Level.SEVERE, "Error fetching customer sales trends", e);
            throw new AnalyticsDataException("Failed to retrieve customer sales trends", e);
        }
        return list;
    }

    /**
     * Recalculates route sales trends from operational records and refreshes sales_trend_result table.
     */
    public int refreshRouteSalesTrends(Connection conn) throws SQLException {
        // Step 1: Query aggregated monthly sales by route from operational sales & shipments
        String calcSql = 
            "SELECT DATE_FORMAT(COALESCE(st.sale_date, s.created_at), '%Y-%m-01') AS period_month, " +
            "s.origin_port_id, s.dest_port_id, " +
            "SUM(COALESCE(st.total_amount, s.quoted_price)) AS total_sales, " +
            "SUM(COALESCE(st.quantity, 1)) AS total_qty " +
            "FROM shipment s " +
            "LEFT JOIN sales_transactions st ON s.shipment_id = st.shipment_id " +
            "WHERE s.status != 'CANCELLED' " +
            "GROUP BY period_month, s.origin_port_id, s.dest_port_id " +
            "ORDER BY s.origin_port_id, s.dest_port_id, period_month ASC";

        List<SalesTrendResult> calculatedList = new ArrayList<>();
        try (PreparedStatement ps = conn.prepareStatement(calcSql);
             ResultSet rs = ps.executeQuery()) {
            Map<String, BigDecimal> lastMonthSalesMap = new HashMap<>();

            while (rs.next()) {
                Date periodMonth = Date.valueOf(rs.getString("period_month"));
                int originPort = rs.getInt("origin_port_id");
                int destPort = rs.getInt("dest_port_id");
                BigDecimal sales = rs.getBigDecimal("total_sales");
                int qty = rs.getInt("total_qty");

                String routeKey = originPort + "->" + destPort;
                BigDecimal lastSales = lastMonthSalesMap.get(routeKey);
                BigDecimal growth = BigDecimal.ZERO;
                if (lastSales != null && lastSales.compareTo(BigDecimal.ZERO) > 0) {
                    growth = sales.subtract(lastSales)
                                  .divide(lastSales, 4, RoundingMode.HALF_UP)
                                  .multiply(BigDecimal.valueOf(100))
                                  .setScale(2, RoundingMode.HALF_UP);
                }
                lastMonthSalesMap.put(routeKey, sales);

                SalesTrendResult item = new SalesTrendResult();
                item.setPeriodMonth(periodMonth);
                item.setOriginPortId(originPort);
                item.setDestPortId(destPort);
                item.setTotalSales(sales);
                item.setTotalQty(qty);
                item.setGrowthPct(growth);
                calculatedList.add(item);
            }
        }

        // Step 2: Clear old cached trends and insert newly calculated ones within the transaction
        try (PreparedStatement deletePs = conn.prepareStatement("DELETE FROM sales_trend_result")) {
            deletePs.executeUpdate();
        }

        String insertSql = 
            "INSERT INTO sales_trend_result (period_month, origin_port_id, dest_port_id, total_sales, total_qty, growth_pct) " +
            "VALUES (?, ?, ?, ?, ?, ?)";
        int inserted = 0;
        try (PreparedStatement insertPs = conn.prepareStatement(insertSql)) {
            for (SalesTrendResult item : calculatedList) {
                insertPs.setDate(1, item.getPeriodMonth());
                insertPs.setInt(2, item.getOriginPortId());
                insertPs.setInt(3, item.getDestPortId());
                insertPs.setBigDecimal(4, item.getTotalSales());
                insertPs.setInt(5, item.getTotalQty());
                insertPs.setBigDecimal(6, item.getGrowthPct());
                insertPs.addBatch();
                inserted++;
            }
            insertPs.executeBatch();
        }
        return inserted;
    }
}

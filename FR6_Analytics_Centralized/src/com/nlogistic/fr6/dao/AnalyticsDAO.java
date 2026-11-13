package com.nlogistic.fr6.dao;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.sql.*;
import java.sql.Date;
import java.time.LocalDate;
import java.util.*;
import java.util.logging.Level;
import java.util.logging.Logger;

import com.nlogistic.fr6.config.AnalyticsConnectionProvider;
import com.nlogistic.fr6.model.*;

/**
 * FR6 Centralized Data Access Object.
 * Consolidates all SQL queries and operations across FR6.1 to FR6.8.
 */
public class AnalyticsDAO {

    private static final Logger LOGGER = Logger.getLogger(AnalyticsDAO.class.getName());

    // ==========================================
    // FR6.1: DASHBOARD KPIS & REFERENCE METADATA
    // ==========================================

    public AnalyticsKPI calculateKPIs(java.util.Date start, java.util.Date end, Integer companyId, String userRole) throws SQLException {
        AnalyticsKPI kpi = new AnalyticsKPI();
        Date sqlStart = (start != null) ? new Date(start.getTime()) : null;
        Date sqlEnd = (end != null) ? new Date(end.getTime()) : null;

        try (Connection conn = AnalyticsConnectionProvider.getConnection()) {

            // 1. Active Shipments KPI (Not DELIVERED or CANCELLED)
            StringBuilder sqlShip = new StringBuilder(
                "SELECT COUNT(*) AS active_count FROM shipment " +
                "WHERE status IN ('BOOKED','LOADED','DEPARTED','IN_TRANSIT','ARRIVED','CUSTOMS_CLEARED') "
            );
            if (companyId != null) {
                if ("CONSUMER".equalsIgnoreCase(userRole)) {
                    sqlShip.append("AND consumer_id IN (SELECT customer_id FROM customers WHERE company_id = ?) ");
                } else {
                    sqlShip.append("AND seller_id = ? ");
                }
            }
            if (sqlStart != null && sqlEnd != null) {
                sqlShip.append("AND (etd BETWEEN ? AND ? OR created_at BETWEEN ? AND ?) ");
            }

            try (PreparedStatement ps = conn.prepareStatement(sqlShip.toString())) {
                int paramIdx = 1;
                if (companyId != null) {
                    ps.setInt(paramIdx++, companyId);
                }
                if (sqlStart != null && sqlEnd != null) {
                    ps.setDate(paramIdx++, sqlStart);
                    ps.setDate(paramIdx++, sqlEnd);
                    ps.setDate(paramIdx++, sqlStart);
                    ps.setDate(paramIdx++, sqlEnd);
                }
                try (ResultSet rs = ps.executeQuery()) {
                    if (rs.next()) {
                        kpi.setActiveShipments(rs.getInt("active_count"));
                    }
                }
            }

            // 2. Available Containers KPI
            String sqlCont = "SELECT COUNT(*) AS avail_count FROM containers WHERE status = 'AVAILABLE'";
            try (PreparedStatement ps = conn.prepareStatement(sqlCont);
                 ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    kpi.setContainersAvailable(rs.getInt("avail_count"));
                }
            }

            // 3. Revenue KPI (Paid Invoices per FR2.8)
            StringBuilder sqlRev = new StringBuilder(
                "SELECT COALESCE(SUM(paid_amount), 0.00) AS total_revenue FROM billing_invoices " +
                "WHERE status = 'PAID' "
            );
            if (companyId != null) {
                if ("CONSUMER".equalsIgnoreCase(userRole)) {
                    sqlRev.append("AND consumer_id IN (SELECT customer_id FROM customers WHERE company_id = ?) ");
                } else {
                    sqlRev.append("AND seller_id = ? ");
                }
            }
            if (sqlStart != null && sqlEnd != null) {
                sqlRev.append("AND issue_date BETWEEN ? AND ? ");
            }

            try (PreparedStatement ps = conn.prepareStatement(sqlRev.toString())) {
                int paramIdx = 1;
                if (companyId != null) {
                    ps.setInt(paramIdx++, companyId);
                }
                if (sqlStart != null && sqlEnd != null) {
                    ps.setDate(paramIdx++, sqlStart);
                    ps.setDate(paramIdx++, sqlEnd);
                }
                try (ResultSet rs = ps.executeQuery()) {
                    if (rs.next()) {
                        kpi.setRevenue(rs.getBigDecimal("total_revenue"));
                    }
                }
            }

            // 4. Pending Invoices KPI
            StringBuilder sqlInv = new StringBuilder(
                "SELECT COUNT(*) AS pending_count, COALESCE(SUM(total_amount - paid_amount), 0.00) AS pending_balance " +
                "FROM billing_invoices WHERE status IN ('UNPAID', 'PARTIAL') "
            );
            if (companyId != null) {
                if ("CONSUMER".equalsIgnoreCase(userRole)) {
                    sqlInv.append("AND consumer_id IN (SELECT customer_id FROM customers WHERE company_id = ?) ");
                } else {
                    sqlInv.append("AND seller_id = ? ");
                }
            }
            if (sqlStart != null && sqlEnd != null) {
                sqlInv.append("AND issue_date BETWEEN ? AND ? ");
            }

            try (PreparedStatement ps = conn.prepareStatement(sqlInv.toString())) {
                int paramIdx = 1;
                if (companyId != null) {
                    ps.setInt(paramIdx++, companyId);
                }
                if (sqlStart != null && sqlEnd != null) {
                    ps.setDate(paramIdx++, sqlStart);
                    ps.setDate(paramIdx++, sqlEnd);
                }
                try (ResultSet rs = ps.executeQuery()) {
                    if (rs.next()) {
                        kpi.setPendingInvoicesCount(rs.getInt("pending_count"));
                        kpi.setPendingInvoicesAmount(rs.getBigDecimal("pending_balance"));
                    }
                }
            }

            // 5. Open Claims KPI
            StringBuilder sqlClaim = new StringBuilder(
                "SELECT COUNT(*) AS open_count, COALESCE(SUM(claimed_amount), 0.00) AS open_amount " +
                "FROM claims WHERE status IN ('SUBMITTED', 'UNDER_REVIEW', 'APPROVED', 'PARTIALLY_APPROVED') "
            );
            if (companyId != null) {
                if ("CONSUMER".equalsIgnoreCase(userRole)) {
                    sqlClaim.append("AND consumer_id IN (SELECT customer_id FROM customers WHERE company_id = ?) ");
                } else {
                    sqlClaim.append("AND shipment_id IN (SELECT shipment_id FROM shipment WHERE seller_id = ?) ");
                }
            }
            if (sqlStart != null && sqlEnd != null) {
                sqlClaim.append("AND DATE(created_at) BETWEEN ? AND ? ");
            }

            try (PreparedStatement ps = conn.prepareStatement(sqlClaim.toString())) {
                int paramIdx = 1;
                if (companyId != null) {
                    ps.setInt(paramIdx++, companyId);
                }
                if (sqlStart != null && sqlEnd != null) {
                    ps.setDate(paramIdx++, sqlStart);
                    ps.setDate(paramIdx++, sqlEnd);
                }
                try (ResultSet rs = ps.executeQuery()) {
                    if (rs.next()) {
                        kpi.setOpenClaimsCount(rs.getInt("open_count"));
                        kpi.setOpenClaimsAmount(rs.getBigDecimal("open_amount"));
                    }
                }
            }
        }
        kpi.setCalculatedAt(new Timestamp(System.currentTimeMillis()));
        return kpi;
    }

    public List<Map<String, Object>> getAvailablePorts() {
        List<Map<String, Object>> ports = new ArrayList<>();
        String sql = "SELECT port_id, port_code, port_name, country FROM ports ORDER BY port_name ASC";
        try (Connection conn = AnalyticsConnectionProvider.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql);
             ResultSet rs = ps.executeQuery()) {
            while (rs.next()) {
                Map<String, Object> p = new HashMap<>();
                p.put("portId", rs.getInt("port_id"));
                p.put("portCode", rs.getString("port_code"));
                p.put("portName", rs.getString("port_name"));
                p.put("country", rs.getString("country"));
                ports.add(p);
            }
        } catch (SQLException e) {
            LOGGER.log(Level.WARNING, "Failed to load ports for filter", e);
        }
        return ports;
    }

    public List<Map<String, Object>> getAvailableCompanies() {
        List<Map<String, Object>> list = new ArrayList<>();
        String sql = "SELECT company_id, company_name, company_type FROM companies ORDER BY company_name ASC";
        try (Connection conn = AnalyticsConnectionProvider.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql);
             ResultSet rs = ps.executeQuery()) {
            while (rs.next()) {
                Map<String, Object> map = new HashMap<>();
                map.put("companyId", rs.getInt("company_id"));
                map.put("companyName", rs.getString("company_name"));
                map.put("companyType", rs.getString("company_type"));
                list.add(map);
            }
        } catch (SQLException e) {
            LOGGER.log(Level.WARNING, "Failed to load companies for filter", e);
        }
        return list;
    }

    // ==========================================
    // FR6.2: SALES TREND QUERIES
    // ==========================================

    public List<SalesTrendResult> getRouteSalesTrends(java.util.Date start, java.util.Date end, Integer originPortId, Integer destPortId) {
        List<SalesTrendResult> list = new ArrayList<>();
        Date sqlStart = (start != null) ? new Date(start.getTime()) : null;
        Date sqlEnd = (end != null) ? new Date(end.getTime()) : null;

        StringBuilder sql = new StringBuilder(
            "SELECT str.result_id, str.period_month, str.origin_port_id, str.dest_port_id, " +
            "str.total_sales, str.total_qty, str.growth_pct, str.created_at, " +
            "p1.port_name AS origin_port_name, p2.port_name AS dest_port_name " +
            "FROM sales_trend_result str " +
            "LEFT JOIN ports p1 ON str.origin_port_id = p1.port_id " +
            "LEFT JOIN ports p2 ON str.dest_port_id = p2.port_id " +
            "WHERE 1=1 "
        );

        if (sqlStart != null && sqlEnd != null) {
            sql.append("AND str.period_month BETWEEN ? AND ? ");
        }
        if (originPortId != null) {
            sql.append("AND str.origin_port_id = ? ");
        }
        if (destPortId != null) {
            sql.append("AND str.dest_port_id = ? ");
        }
        sql.append("ORDER BY str.period_month ASC, str.total_sales DESC");

        try (Connection conn = AnalyticsConnectionProvider.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql.toString())) {
            int idx = 1;
            if (sqlStart != null && sqlEnd != null) {
                ps.setDate(idx++, sqlStart);
                ps.setDate(idx++, sqlEnd);
            }
            if (originPortId != null) {
                ps.setInt(idx++, originPortId);
            }
            if (destPortId != null) {
                ps.setInt(idx++, destPortId);
            }

            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    SalesTrendResult item = new SalesTrendResult();
                    item.setResultId(rs.getInt("result_id"));
                    item.setPeriodMonth(rs.getDate("period_month"));
                    item.setOriginPortId(rs.getInt("origin_port_id"));
                    item.setDestPortId(rs.getInt("dest_port_id"));
                    item.setTotalSales(rs.getBigDecimal("total_sales"));
                    item.setTotalQty(rs.getInt("total_qty"));
                    item.setGrowthPct(rs.getBigDecimal("growth_pct"));
                    item.setCreatedAt(rs.getTimestamp("created_at"));
                    item.setOriginPortName(rs.getString("origin_port_name"));
                    item.setDestPortName(rs.getString("dest_port_name"));
                    item.setDimension("ROUTE");
                    item.setDimensionLabel(item.getRouteLabel() + " (" + rs.getDate("period_month") + ")");
                    list.add(item);
                }
            }
        } catch (SQLException e) {
            LOGGER.log(Level.SEVERE, "Failed to load route sales trends", e);
        }
        return list;
    }

    public List<SalesTrendResult> getProductSalesTrends(java.util.Date start, java.util.Date end, Integer companyId) {
        List<SalesTrendResult> list = new ArrayList<>();
        Date sqlStart = (start != null) ? new Date(start.getTime()) : null;
        Date sqlEnd = (end != null) ? new Date(end.getTime()) : null;

        StringBuilder sql = new StringBuilder(
            "SELECT DATE_FORMAT(st.sale_date, '%Y-%m-01') AS period_month, " +
            "p.product_id, p.product_name, p.sku, " +
            "SUM(st.total_amount) AS total_sales, " +
            "SUM(st.quantity) AS total_qty " +
            "FROM sales_transactions st " +
            "JOIN products p ON st.product_id = p.product_id " +
            "WHERE 1=1 "
        );
        if (companyId != null) {
            sql.append("AND p.owner_company_id = ? ");
        }
        if (sqlStart != null && sqlEnd != null) {
            sql.append("AND st.sale_date BETWEEN ? AND ? ");
        }
        sql.append("GROUP BY period_month, p.product_id, p.product_name, p.sku ");
        sql.append("ORDER BY period_month ASC, total_sales DESC");

        try (Connection conn = AnalyticsConnectionProvider.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql.toString())) {
            int idx = 1;
            if (companyId != null) {
                ps.setInt(idx++, companyId);
            }
            if (sqlStart != null && sqlEnd != null) {
                ps.setDate(idx++, sqlStart);
                ps.setDate(idx++, sqlEnd);
            }
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    SalesTrendResult item = new SalesTrendResult();
                    item.setPeriod(rs.getString("period_month"));
                    item.setPeriodMonth(Date.valueOf(rs.getString("period_month")));
                    item.setTotalSales(rs.getBigDecimal("total_sales"));
                    item.setTotalQty(rs.getInt("total_qty"));
                    item.setDimension("PRODUCT");
                    item.setDimensionKey(String.valueOf(rs.getInt("product_id")));
                    item.setDimensionLabel(rs.getString("product_name") + " [" + rs.getString("sku") + "]");
                    item.setCompanyId(companyId);
                    list.add(item);
                }
            }
        } catch (SQLException e) {
            LOGGER.log(Level.SEVERE, "Failed to load product sales trends", e);
        }
        return list;
    }

    public List<SalesTrendResult> getCustomerSalesTrends(java.util.Date start, java.util.Date end, Integer companyId) {
        List<SalesTrendResult> list = new ArrayList<>();
        Date sqlStart = (start != null) ? new Date(start.getTime()) : null;
        Date sqlEnd = (end != null) ? new Date(end.getTime()) : null;

        StringBuilder sql = new StringBuilder(
            "SELECT DATE_FORMAT(st.sale_date, '%Y-%m-01') AS period_month, " +
            "c.customer_id, comp.company_name, " +
            "SUM(st.total_amount) AS total_sales, " +
            "SUM(st.quantity) AS total_qty " +
            "FROM sales_transactions st " +
            "JOIN customers c ON st.customer_id = c.customer_id " +
            "JOIN companies comp ON c.company_id = comp.company_id " +
            "JOIN products p ON st.product_id = p.product_id " +
            "WHERE 1=1 "
        );
        if (companyId != null) {
            sql.append("AND p.owner_company_id = ? ");
        }
        if (sqlStart != null && sqlEnd != null) {
            sql.append("AND st.sale_date BETWEEN ? AND ? ");
        }
        sql.append("GROUP BY period_month, c.customer_id, comp.company_name ");
        sql.append("ORDER BY period_month ASC, total_sales DESC");

        try (Connection conn = AnalyticsConnectionProvider.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql.toString())) {
            int idx = 1;
            if (companyId != null) {
                ps.setInt(idx++, companyId);
            }
            if (sqlStart != null && sqlEnd != null) {
                ps.setDate(idx++, sqlStart);
                ps.setDate(idx++, sqlEnd);
            }
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    SalesTrendResult item = new SalesTrendResult();
                    item.setPeriod(rs.getString("period_month"));
                    item.setPeriodMonth(Date.valueOf(rs.getString("period_month")));
                    item.setTotalSales(rs.getBigDecimal("total_sales"));
                    item.setTotalQty(rs.getInt("total_qty"));
                    item.setDimension("CUSTOMER");
                    item.setDimensionKey(String.valueOf(rs.getInt("customer_id")));
                    item.setDimensionLabel(rs.getString("company_name"));
                    item.setCompanyId(companyId);
                    list.add(item);
                }
            }
        } catch (SQLException e) {
            LOGGER.log(Level.SEVERE, "Failed to load customer sales trends", e);
        }
        return list;
    }

    // ==========================================
    // FR6.3: ABC PARETO CLASSIFICATION
    // ==========================================

    public List<AbcClassificationResult> getAbcClassifications(java.util.Date start, java.util.Date end, Integer companyId, String category) {
        List<AbcClassificationResult> list = new ArrayList<>();
        StringBuilder sql = new StringBuilder(
            "SELECT abc.result_id, abc.product_id, abc.annual_value, abc.cumulative_pct, " +
            "abc.abc_class, abc.calculated_on, abc.created_at, " +
            "p.product_name, p.sku, p.category " +
            "FROM abc_classification_result abc " +
            "JOIN products p ON abc.product_id = p.product_id " +
            "WHERE 1=1 "
        );

        if (companyId != null) {
            sql.append("AND p.owner_company_id = ? ");
        }
        if (category != null && !category.trim().isEmpty()) {
            sql.append("AND p.category = ? ");
        }
        sql.append("ORDER BY abc.annual_value DESC, abc.cumulative_pct ASC");

        try (Connection conn = AnalyticsConnectionProvider.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql.toString())) {
            int idx = 1;
            if (companyId != null) {
                ps.setInt(idx++, companyId);
            }
            if (category != null && !category.trim().isEmpty()) {
                ps.setString(idx++, category.trim());
            }

            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    AbcClassificationResult r = new AbcClassificationResult();
                    r.setResultId(rs.getInt("result_id"));
                    r.setProductId(rs.getInt("product_id"));
                    r.setAnnualValue(rs.getBigDecimal("annual_value"));
                    r.setCumulativePct(rs.getBigDecimal("cumulative_pct"));
                    r.setAbcClass(rs.getString("abc_class"));
                    r.setCalculatedOn(rs.getDate("calculated_on"));
                    r.setCreatedAt(rs.getTimestamp("created_at"));
                    r.setProductName(rs.getString("product_name"));
                    r.setSku(rs.getString("sku"));
                    r.setCategory(rs.getString("category"));
                    r.setCompanyId(companyId);
                    list.add(r);
                }
            }
        } catch (SQLException e) {
            LOGGER.log(Level.SEVERE, "Failed to load ABC classifications", e);
        }
        return list;
    }

    public List<AbcClassificationResult> getCustomerAbcAnalysis(java.util.Date start, java.util.Date end, Integer companyId) {
        List<AbcClassificationResult> list = new ArrayList<>();
        Date sqlStart = (start != null) ? new Date(start.getTime()) : null;
        Date sqlEnd = (end != null) ? new Date(end.getTime()) : null;

        StringBuilder sql = new StringBuilder(
            "SELECT comp.company_id, comp.company_name, " +
            "COALESCE(SUM(st.total_amount), 0.00) AS total_spend " +
            "FROM customers cust " +
            "JOIN companies comp ON cust.company_id = comp.company_id " +
            "LEFT JOIN sales_transactions st ON cust.customer_id = st.customer_id " +
            "WHERE 1=1 "
        );
        if (sqlStart != null && sqlEnd != null) {
            sql.append("AND st.sale_date BETWEEN ? AND ? ");
        }
        sql.append("GROUP BY comp.company_id, comp.company_name ORDER BY total_spend DESC");

        try (Connection conn = AnalyticsConnectionProvider.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql.toString())) {
            if (sqlStart != null && sqlEnd != null) {
                ps.setDate(1, sqlStart);
                ps.setDate(2, sqlEnd);
            }
            BigDecimal totalSpend = BigDecimal.ZERO;
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    AbcClassificationResult r = new AbcClassificationResult();
                    r.setItemId(rs.getInt("company_id"));
                    r.setItemName(rs.getString("company_name"));
                    r.setItemCode("CUST-" + rs.getInt("company_id"));
                    r.setAnnualValue(rs.getBigDecimal("total_spend"));
                    totalSpend = totalSpend.add(r.getAnnualValue());
                    list.add(r);
                }
            }

            // Assign Pareto classes: 70% / 20% / 10%
            BigDecimal running = BigDecimal.ZERO;
            for (int i = 0; i < list.size(); i++) {
                AbcClassificationResult r = list.get(i);
                running = running.add(r.getAnnualValue());
                BigDecimal cumPct = totalSpend.compareTo(BigDecimal.ZERO) > 0
                    ? running.multiply(BigDecimal.valueOf(100)).divide(totalSpend, 2, RoundingMode.HALF_UP)
                    : BigDecimal.ZERO;
                r.setCumulativePct(cumPct);
                if (cumPct.compareTo(BigDecimal.valueOf(70)) <= 0 || i == 0) {
                    r.setAbcClass("A");
                } else if (cumPct.compareTo(BigDecimal.valueOf(90)) <= 0) {
                    r.setAbcClass("B");
                } else {
                    r.setAbcClass("C");
                }
            }
        } catch (SQLException e) {
            LOGGER.log(Level.SEVERE, "Failed to calculate customer ABC", e);
        }
        return list;
    }

    // ==========================================
    // FR6.4: INVENTORY TURNOVER
    // ==========================================

    public List<InventoryTurnoverResult> getInventoryTurnover(java.util.Date start, java.util.Date end, Integer companyId, Integer productId) {
        List<InventoryTurnoverResult> list = new ArrayList<>();
        StringBuilder sql = new StringBuilder(
            "SELECT itr.result_id, itr.product_id, itr.period_start, itr.period_end, " +
            "itr.cogs, itr.avg_inventory, itr.turnover_ratio, itr.created_at, " +
            "p.product_name, p.sku " +
            "FROM inventory_turnover_result itr " +
            "JOIN products p ON itr.product_id = p.product_id " +
            "WHERE 1=1 "
        );

        if (companyId != null) {
            sql.append("AND p.owner_company_id = ? ");
        }
        if (productId != null) {
            sql.append("AND p.product_id = ? ");
        }
        sql.append("ORDER BY itr.turnover_ratio DESC, itr.cogs DESC");

        try (Connection conn = AnalyticsConnectionProvider.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql.toString())) {
            int idx = 1;
            if (companyId != null) {
                ps.setInt(idx++, companyId);
            }
            if (productId != null) {
                ps.setInt(idx++, productId);
            }

            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    InventoryTurnoverResult r = new InventoryTurnoverResult();
                    r.setResultId(rs.getInt("result_id"));
                    r.setProductId(rs.getInt("product_id"));
                    r.setPeriodStart(rs.getDate("period_start"));
                    r.setPeriodEnd(rs.getDate("period_end"));
                    r.setCogs(rs.getBigDecimal("cogs"));
                    r.setAvgInventory(rs.getBigDecimal("avg_inventory"));
                    r.setTurnoverRatio(rs.getBigDecimal("turnover_ratio"));
                    r.setCreatedAt(rs.getTimestamp("created_at"));
                    r.setProductName(rs.getString("product_name"));
                    r.setProductSku(rs.getString("sku"));
                    r.setSku(rs.getString("sku"));

                    double ratio = r.getTurnoverRatio();
                    if (ratio >= 6.0) r.setVelocityCategory("HIGH");
                    else if (ratio >= 2.0) r.setVelocityCategory("MEDIUM");
                    else if (ratio > 0.0) r.setVelocityCategory("SLOW");
                    else r.setVelocityCategory("DEAD_STOCK");

                    list.add(r);
                }
            }
        } catch (SQLException e) {
            LOGGER.log(Level.SEVERE, "Failed to load inventory turnover", e);
        }
        return list;
    }

    // ==========================================
    // FR6.5: PROFITABILITY & P&L
    // ==========================================

    public List<ProfitabilityResult> getProductProfitability(java.util.Date start, java.util.Date end, Integer companyId, Integer productId) {
        List<ProfitabilityResult> list = new ArrayList<>();
        Date sqlStart = (start != null) ? new Date(start.getTime()) : null;
        Date sqlEnd = (end != null) ? new Date(end.getTime()) : null;

        StringBuilder sql = new StringBuilder(
            "SELECT pr.result_id, pr.product_id, pr.period_month, pr.revenue, pr.cost, " +
            "pr.margin_pct, pr.created_at, p.product_name, p.sku, p.category " +
            "FROM profitability_result pr " +
            "JOIN products p ON pr.product_id = p.product_id " +
            "WHERE 1=1 "
        );

        if (companyId != null) {
            sql.append("AND p.owner_company_id = ? ");
        }
        if (productId != null) {
            sql.append("AND pr.product_id = ? ");
        }
        if (sqlStart != null && sqlEnd != null) {
            sql.append("AND pr.period_month BETWEEN ? AND ? ");
        }
        sql.append("ORDER BY pr.period_month DESC, pr.margin_pct DESC");

        try (Connection conn = AnalyticsConnectionProvider.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql.toString())) {
            int idx = 1;
            if (companyId != null) {
                ps.setInt(idx++, companyId);
            }
            if (productId != null) {
                ps.setInt(idx++, productId);
            }
            if (sqlStart != null && sqlEnd != null) {
                ps.setDate(idx++, sqlStart);
                ps.setDate(idx++, sqlEnd);
            }

            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    ProfitabilityResult pr = new ProfitabilityResult();
                    pr.setResultId(rs.getInt("result_id"));
                    pr.setProductId(rs.getInt("product_id"));
                    pr.setPeriodMonth(rs.getDate("period_month"));
                    pr.setRevenue(rs.getBigDecimal("revenue"));
                    pr.setCost(rs.getBigDecimal("cost"));
                    pr.setMarginPct(rs.getBigDecimal("margin_pct"));
                    pr.setCreatedAt(rs.getTimestamp("created_at"));
                    pr.setProductName(rs.getString("product_name"));
                    pr.setProductSku(rs.getString("sku"));
                    pr.setSku(rs.getString("sku"));
                    pr.setCategory(rs.getString("category"));
                    pr.setGrossProfit(pr.getTotalRevenue() - pr.getTotalCost());
                    list.add(pr);
                }
            }
        } catch (SQLException e) {
            LOGGER.log(Level.SEVERE, "Failed to load product profitability", e);
        }
        return list;
    }

    public List<ProfitLoss> getShipmentProfitLoss(java.util.Date start, java.util.Date end, Integer companyId) {
        List<ProfitLoss> list = new ArrayList<>();
        Date sqlStart = (start != null) ? new Date(start.getTime()) : null;
        Date sqlEnd = (end != null) ? new Date(end.getTime()) : null;

        StringBuilder sql = new StringBuilder(
            "SELECT pl.pl_id, pl.shipment_id, pl.seller_id, pl.period_month, pl.revenue, " +
            "pl.freight_cost, pl.port_cost, pl.handling_cost, pl.claim_loss, pl.net_profit, pl.created_at, " +
            "s.shipment_no, comp.company_name AS seller_name " +
            "FROM profit_loss pl " +
            "JOIN shipment s ON pl.shipment_id = s.shipment_id " +
            "JOIN companies comp ON pl.seller_id = comp.company_id " +
            "WHERE 1=1 "
        );

        if (companyId != null) {
            sql.append("AND pl.seller_id = ? ");
        }
        if (sqlStart != null && sqlEnd != null) {
            sql.append("AND pl.period_month BETWEEN ? AND ? ");
        }
        sql.append("ORDER BY pl.period_month DESC, pl.net_profit DESC");

        try (Connection conn = AnalyticsConnectionProvider.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql.toString())) {
            int idx = 1;
            if (companyId != null) {
                ps.setInt(idx++, companyId);
            }
            if (sqlStart != null && sqlEnd != null) {
                ps.setDate(idx++, sqlStart);
                ps.setDate(idx++, sqlEnd);
            }

            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    ProfitLoss item = new ProfitLoss();
                    item.setPlId(rs.getInt("pl_id"));
                    item.setShipmentId(rs.getInt("shipment_id"));
                    item.setSellerId(rs.getInt("seller_id"));
                    item.setPeriodMonth(rs.getDate("period_month"));
                    item.setRevenue(rs.getBigDecimal("revenue"));
                    item.setFreightCost(rs.getBigDecimal("freight_cost"));
                    item.setPortCost(rs.getBigDecimal("port_cost"));
                    item.setHandlingCost(rs.getBigDecimal("handling_cost"));
                    item.setClaimLoss(rs.getBigDecimal("claim_loss"));
                    item.setNetProfit(rs.getBigDecimal("net_profit"));
                    item.setCreatedAt(rs.getTimestamp("created_at"));
                    item.setShipmentNo(rs.getString("shipment_no"));
                    item.setTrackingNumber(rs.getString("shipment_no"));
                    item.setSellerName(rs.getString("seller_name"));
                    item.setCustomerName(rs.getString("seller_name"));

                    BigDecimal totalCosts = item.getFreightCost().add(item.getPortCost()).add(item.getHandlingCost()).add(item.getClaimLoss());
                    item.setOperatingCost(totalCosts);

                    if (item.getTotalRevenue() > 0) {
                        item.setNetMarginPct((item.getNetProfit() / item.getTotalRevenue()) * 100.0);
                    }
                    list.add(item);
                }
            }
        } catch (SQLException e) {
            LOGGER.log(Level.SEVERE, "Failed to load shipment profit and loss", e);
        }
        return list;
    }

    // ==========================================
    // FR6.6: DEMAND FORECAST & FR3 PRICING SYNC
    // ==========================================

    public List<DemandForecast> getDemandForecasts(Integer originPortId, Integer destPortId, String containerType) {
        List<DemandForecast> list = new ArrayList<>();
        StringBuilder sql = new StringBuilder(
            "SELECT df.forecast_id, df.origin_port_id, df.dest_port_id, df.container_type, " +
            "df.forecast_month, df.predicted_bookings, df.confidence_pct, df.suggested_multiplier, " +
            "df.created_at, p1.port_name AS origin_port_name, p2.port_name AS dest_port_name " +
            "FROM demand_forecast df " +
            "JOIN ports p1 ON df.origin_port_id = p1.port_id " +
            "JOIN ports p2 ON df.dest_port_id = p2.port_id " +
            "WHERE 1=1 "
        );

        if (originPortId != null) {
            sql.append("AND df.origin_port_id = ? ");
        }
        if (destPortId != null) {
            sql.append("AND df.dest_port_id = ? ");
        }
        if (containerType != null && !containerType.trim().isEmpty()) {
            sql.append("AND df.container_type = ? ");
        }
        sql.append("ORDER BY df.forecast_month ASC, df.predicted_bookings DESC");

        try (Connection conn = AnalyticsConnectionProvider.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql.toString())) {
            int idx = 1;
            if (originPortId != null) {
                ps.setInt(idx++, originPortId);
            }
            if (destPortId != null) {
                ps.setInt(idx++, destPortId);
            }
            if (containerType != null && !containerType.trim().isEmpty()) {
                ps.setString(idx++, containerType.trim());
            }

            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    DemandForecast df = new DemandForecast();
                    df.setForecastId(rs.getInt("forecast_id"));
                    df.setOriginPortId(rs.getInt("origin_port_id"));
                    df.setDestPortId(rs.getInt("dest_port_id"));
                    df.setContainerType(rs.getString("container_type"));
                    df.setForecastMonth(rs.getDate("forecast_month"));
                    df.setPredictedBookings(rs.getInt("predicted_bookings"));
                    df.setConfidencePct(rs.getBigDecimal("confidence_pct"));
                    df.setSuggestedMultiplier(rs.getBigDecimal("suggested_multiplier"));
                    df.setCreatedAt(rs.getTimestamp("created_at"));
                    df.setOriginPortName(rs.getString("origin_port_name"));
                    df.setDestPortName(rs.getString("dest_port_name"));
                    list.add(df);
                }
            }
        } catch (SQLException e) {
            LOGGER.log(Level.SEVERE, "Failed to load demand forecasts", e);
        }
        return list;
    }

    public boolean applyForecastMultiplierToPricing(int forecastId, BigDecimal multiplier, int userId, Connection extConn) throws SQLException {
        boolean ownConn = (extConn == null);
        Connection conn = ownConn ? AnalyticsConnectionProvider.getConnection() : extConn;
        try {
            // 1. Get forecast details
            int originId = 0, destId = 0;
            String containerType = null;
            String fSql = "SELECT origin_port_id, dest_port_id, container_type, suggested_multiplier FROM demand_forecast WHERE forecast_id = ?";
            try (PreparedStatement ps = conn.prepareStatement(fSql)) {
                ps.setInt(1, forecastId);
                try (ResultSet rs = ps.executeQuery()) {
                    if (rs.next()) {
                        originId = rs.getInt("origin_port_id");
                        destId = rs.getInt("dest_port_id");
                        containerType = rs.getString("container_type");
                        if (multiplier == null) {
                            multiplier = rs.getBigDecimal("suggested_multiplier");
                        }
                    } else {
                        return false;
                    }
                }
            }

            // 2. Select matching pricing rules from FR3
            String rSql = "SELECT rule_id, base_rate, demand_multiplier FROM pricing_rules WHERE origin_port_id = ? AND dest_port_id = ? AND container_type = ?";
            List<Map<String, Object>> rules = new ArrayList<>();
            try (PreparedStatement ps = conn.prepareStatement(rSql)) {
                ps.setInt(1, originId);
                ps.setInt(2, destId);
                ps.setString(3, containerType);
                try (ResultSet rs = ps.executeQuery()) {
                    while (rs.next()) {
                        Map<String, Object> r = new HashMap<>();
                        r.put("ruleId", rs.getInt("rule_id"));
                        r.put("baseRate", rs.getBigDecimal("base_rate"));
                        r.put("oldMultiplier", rs.getBigDecimal("demand_multiplier"));
                        rules.add(r);
                    }
                }
            }

            // 3. Update pricing_rules & write to pricing_audit
            String updateSql = "UPDATE pricing_rules SET demand_multiplier = ? WHERE rule_id = ?";
            String auditSql = "INSERT INTO pricing_audit (rule_id, old_rate, new_rate, old_multiplier, new_multiplier, changed_by, changed_at) VALUES (?, ?, ?, ?, ?, ?, NOW())";

            for (Map<String, Object> rule : rules) {
                int ruleId = (int) rule.get("ruleId");
                BigDecimal baseRate = (BigDecimal) rule.get("baseRate");
                BigDecimal oldMult = (BigDecimal) rule.get("oldMultiplier");

                try (PreparedStatement ps = conn.prepareStatement(updateSql)) {
                    ps.setBigDecimal(1, multiplier);
                    ps.setInt(2, ruleId);
                    ps.executeUpdate();
                }

                try (PreparedStatement ps = conn.prepareStatement(auditSql)) {
                    ps.setInt(1, ruleId);
                    ps.setBigDecimal(2, baseRate);
                    ps.setBigDecimal(3, baseRate);
                    ps.setBigDecimal(4, oldMult);
                    ps.setBigDecimal(5, multiplier);
                    ps.setInt(6, userId);
                    ps.executeUpdate();
                }
            }
            return true;
        } finally {
            if (ownConn && conn != null) {
                conn.close();
            }
        }
    }

    // ==========================================
    // FR6.7: ATOMIC TRANSACTIONAL REFRESH
    // ==========================================

    public int refreshAllAnalyticsTransaction() throws SQLException {
        int totalRows = 0;
        try (Connection conn = AnalyticsConnectionProvider.getConnection()) {
            boolean origAuto = conn.getAutoCommit();
            try {
                conn.setAutoCommit(false);

                // 1. Refresh Sales Trends
                totalRows += refreshRouteSalesTrends(conn);

                // 2. Refresh ABC Classification
                totalRows += refreshAbcClassification(conn);

                // 3. Refresh Inventory Turnover
                totalRows += refreshInventoryTurnover(conn, null, null);

                // 4. Refresh Profitability & P&L
                totalRows += refreshProfitability(conn);

                // 5. Refresh Demand Forecasts
                totalRows += refreshDemandForecasts(conn);

                conn.commit();
                LOGGER.info("Centralized atomic refresh committed successfully. Total rows: " + totalRows);
                return totalRows;
            } catch (SQLException e) {
                conn.rollback();
                LOGGER.log(Level.SEVERE, "Rollback executed during centralized analytics refresh", e);
                throw e;
            } finally {
                conn.setAutoCommit(origAuto);
            }
        }
    }

    private int refreshRouteSalesTrends(Connection conn) throws SQLException {
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
            while (rs.next()) {
                SalesTrendResult row = new SalesTrendResult();
                row.setPeriodMonth(Date.valueOf(rs.getString("period_month")));
                row.setOriginPortId(rs.getInt("origin_port_id"));
                row.setDestPortId(rs.getInt("dest_port_id"));
                row.setTotalSales(rs.getBigDecimal("total_sales"));
                row.setTotalQty(rs.getInt("total_qty"));
                row.setGrowthPct(BigDecimal.ZERO);
                calculatedList.add(row);
            }
        }

        try (Statement stmt = conn.createStatement()) {
            stmt.executeUpdate("DELETE FROM sales_trend_result");
        }

        String insertSql = "INSERT INTO sales_trend_result (period_month, origin_port_id, dest_port_id, total_sales, total_qty, growth_pct) VALUES (?, ?, ?, ?, ?, ?)";
        int inserted = 0;
        try (PreparedStatement ps = conn.prepareStatement(insertSql)) {
            for (SalesTrendResult item : calculatedList) {
                ps.setDate(1, item.getPeriodMonth());
                ps.setInt(2, item.getOriginPortId());
                ps.setInt(3, item.getDestPortId());
                ps.setBigDecimal(4, item.getTotalSalesAmount());
                ps.setInt(5, item.getTotalQty());
                ps.setBigDecimal(6, item.getGrowthPct());
                ps.addBatch();
                inserted++;
            }
            ps.executeBatch();
        }
        return inserted;
    }

    private int refreshAbcClassification(Connection conn) throws SQLException {
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
                row.setAnnualValue(rs.getBigDecimal("annual_sales"));
                totalPortfolioValue = totalPortfolioValue.add(row.getAnnualValue());
                results.add(row);
            }
        }

        BigDecimal runningTotal = BigDecimal.ZERO;
        Date now = Date.valueOf(LocalDate.now());
        for (int i = 0; i < results.size(); i++) {
            AbcClassificationResult item = results.get(i);
            runningTotal = runningTotal.add(item.getAnnualValue());
            BigDecimal cumPct = (totalPortfolioValue.compareTo(BigDecimal.ZERO) > 0)
                ? runningTotal.multiply(BigDecimal.valueOf(100)).divide(totalPortfolioValue, 2, RoundingMode.HALF_UP)
                : BigDecimal.ZERO;
            item.setCumulativePct(cumPct);
            item.setCalculatedOn(now);

            // 70% / 20% / 10%
            if (cumPct.compareTo(BigDecimal.valueOf(70.00)) <= 0 || i == 0) {
                item.setAbcClass("A");
            } else if (cumPct.compareTo(BigDecimal.valueOf(90.00)) <= 0) {
                item.setAbcClass("B");
            } else {
                item.setAbcClass("C");
            }
        }

        try (Statement stmt = conn.createStatement()) {
            stmt.executeUpdate("DELETE FROM abc_classification_result");
        }

        String insertSql = "INSERT INTO abc_classification_result (product_id, annual_value, cumulative_pct, abc_class, calculated_on) VALUES (?, ?, ?, ?, ?)";
        int inserted = 0;
        try (PreparedStatement ps = conn.prepareStatement(insertSql)) {
            for (AbcClassificationResult item : results) {
                ps.setInt(1, item.getProductId());
                ps.setBigDecimal(2, item.getAnnualValue());
                ps.setBigDecimal(3, item.getCumulativePct());
                ps.setString(4, item.getAbcClass());
                ps.setDate(5, item.getCalculatedOn());
                ps.addBatch();
                inserted++;
            }
            ps.executeBatch();
        }
        return inserted;
    }

    private int refreshInventoryTurnover(Connection conn, Date periodStart, Date periodEnd) throws SQLException {
        if (periodStart == null) periodStart = Date.valueOf(LocalDate.now().minusMonths(3).withDayOfMonth(1));
        if (periodEnd == null) periodEnd = Date.valueOf(LocalDate.now());

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
                    InventoryTurnoverResult r = new InventoryTurnoverResult();
                    r.setProductId(rs.getInt("product_id"));
                    r.setPeriodStart(periodStart);
                    r.setPeriodEnd(periodEnd);
                    r.setCogs(rs.getBigDecimal("total_cogs"));

                    BigDecimal unitPrice = rs.getBigDecimal("unit_price");
                    int stockQty = rs.getInt("current_stock_qty");
                    BigDecimal avgInv = unitPrice.multiply(BigDecimal.valueOf(stockQty));
                    r.setAvgInventory(avgInv);

                    BigDecimal ratio;
                    if (avgInv.compareTo(BigDecimal.ZERO) == 0) {
                        ratio = r.getCogsAmount().compareTo(BigDecimal.ZERO) > 0 ? BigDecimal.valueOf(12.00) : BigDecimal.ZERO;
                    } else {
                        ratio = r.getCogsAmount().divide(avgInv, 2, RoundingMode.HALF_UP);
                    }
                    r.setTurnoverRatio(ratio);
                    results.add(r);
                }
            }
        }

        try (Statement stmt = conn.createStatement()) {
            stmt.executeUpdate("DELETE FROM inventory_turnover_result");
        }

        String insertSql = "INSERT INTO inventory_turnover_result (product_id, period_start, period_end, cogs, avg_inventory, turnover_ratio) VALUES (?, ?, ?, ?, ?, ?)";
        int inserted = 0;
        try (PreparedStatement ps = conn.prepareStatement(insertSql)) {
            for (InventoryTurnoverResult item : results) {
                ps.setInt(1, item.getProductId());
                ps.setDate(2, item.getPeriodStart());
                ps.setDate(3, item.getPeriodEnd());
                ps.setBigDecimal(4, item.getCogsAmount());
                ps.setBigDecimal(5, item.getAvgInventory());
                ps.setBigDecimal(6, item.getTurnoverRatioAmount());
                ps.addBatch();
                inserted++;
            }
            ps.executeBatch();
        }
        return inserted;
    }

    private int refreshProfitability(Connection conn) throws SQLException {
        // 1. Recalculate product-level profitability
        String prodSql = 
            "SELECT DATE_FORMAT(st.sale_date, '%Y-%m-01') AS period_month, " +
            "p.product_id, " +
            "SUM(st.total_amount) AS revenue, " +
            "SUM(st.quantity * (p.unit_price * 0.65)) AS cost " +
            "FROM sales_transactions st " +
            "JOIN products p ON st.product_id = p.product_id " +
            "GROUP BY period_month, p.product_id";

        List<ProfitabilityResult> prodResults = new ArrayList<>();
        try (PreparedStatement ps = conn.prepareStatement(prodSql);
             ResultSet rs = ps.executeQuery()) {
            while (rs.next()) {
                ProfitabilityResult r = new ProfitabilityResult();
                r.setPeriodMonth(Date.valueOf(rs.getString("period_month")));
                r.setProductId(rs.getInt("product_id"));
                r.setRevenue(rs.getBigDecimal("revenue"));
                r.setCost(rs.getBigDecimal("cost"));

                BigDecimal rev = r.getRevenueAmount();
                BigDecimal cst = r.getCostAmount();
                BigDecimal margin = (rev.compareTo(BigDecimal.ZERO) > 0)
                    ? rev.subtract(cst).multiply(BigDecimal.valueOf(100)).divide(rev, 2, RoundingMode.HALF_UP)
                    : BigDecimal.ZERO;
                r.setMarginPct(margin);
                prodResults.add(r);
            }
        }

        try (Statement stmt = conn.createStatement()) {
            stmt.executeUpdate("DELETE FROM profitability_result");
        }

        String insProdSql = "INSERT INTO profitability_result (product_id, period_month, revenue, cost, margin_pct) VALUES (?, ?, ?, ?, ?)";
        int inserted = 0;
        try (PreparedStatement ps = conn.prepareStatement(insProdSql)) {
            for (ProfitabilityResult item : prodResults) {
                ps.setInt(1, item.getProductId());
                ps.setDate(2, item.getPeriodMonth());
                ps.setBigDecimal(3, item.getRevenueAmount());
                ps.setBigDecimal(4, item.getCostAmount());
                ps.setBigDecimal(5, item.getMarginPct());
                ps.addBatch();
                inserted++;
            }
            ps.executeBatch();
        }

        // 2. Recalculate shipment & seller level P&L per SRS FR2.8
        String plSql = 
            "SELECT DATE_FORMAT(s.created_at, '%Y-%m-01') AS period_month, " +
            "s.shipment_id, s.seller_id, " +
            "COALESCE(bi.total_amount, s.quoted_price) AS revenue, " +
            "COALESCE(pr.base_rate, 45000.00) AS freight_cost, " +
            "5000.00 AS port_cost, " +
            "3500.00 AS handling_cost, " +
            "COALESCE((SELECT SUM(c.claimed_amount) FROM claims c WHERE c.shipment_id = s.shipment_id AND c.status = 'APPROVED'), 0.00) AS claim_loss " +
            "FROM shipment s " +
            "LEFT JOIN billing_invoices bi ON s.shipment_id = bi.shipment_id " +
            "LEFT JOIN pricing_rules pr ON s.origin_port_id = pr.origin_port_id AND s.dest_port_id = pr.dest_port_id " +
            "WHERE s.status != 'CANCELLED' " +
            "GROUP BY s.shipment_id, period_month, s.seller_id, revenue, freight_cost";

        List<ProfitLoss> plResults = new ArrayList<>();
        try (PreparedStatement ps = conn.prepareStatement(plSql);
             ResultSet rs = ps.executeQuery()) {
            while (rs.next()) {
                ProfitLoss pl = new ProfitLoss();
                pl.setPeriodMonth(Date.valueOf(rs.getString("period_month")));
                pl.setShipmentId(rs.getInt("shipment_id"));
                pl.setSellerId(rs.getInt("seller_id"));
                pl.setRevenue(rs.getBigDecimal("revenue"));
                pl.setFreightCost(rs.getBigDecimal("freight_cost"));
                pl.setPortCost(rs.getBigDecimal("port_cost"));
                pl.setHandlingCost(rs.getBigDecimal("handling_cost"));
                pl.setClaimLoss(rs.getBigDecimal("claim_loss"));

                BigDecimal totalCosts = pl.getFreightCost().add(pl.getPortCost()).add(pl.getHandlingCost()).add(pl.getClaimLoss());
                pl.setNetProfit(pl.getRevenueAmount().subtract(totalCosts));
                plResults.add(pl);
            }
        }

        try (Statement stmt = conn.createStatement()) {
            stmt.executeUpdate("DELETE FROM profit_loss");
        }

        String insPlSql = "INSERT INTO profit_loss (shipment_id, seller_id, period_month, revenue, freight_cost, port_cost, handling_cost, claim_loss, net_profit) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)";
        try (PreparedStatement ps = conn.prepareStatement(insPlSql)) {
            for (ProfitLoss pl : plResults) {
                ps.setInt(1, pl.getShipmentId());
                ps.setInt(2, pl.getSellerId());
                ps.setDate(3, pl.getPeriodMonth());
                ps.setBigDecimal(4, pl.getRevenueAmount());
                ps.setBigDecimal(5, pl.getFreightCost());
                ps.setBigDecimal(6, pl.getPortCost());
                ps.setBigDecimal(7, pl.getHandlingCost());
                ps.setBigDecimal(8, pl.getClaimLoss());
                ps.setBigDecimal(9, pl.getNetProfitAmount());
                ps.addBatch();
                inserted++;
            }
            ps.executeBatch();
        }
        return inserted;
    }

    private int refreshDemandForecasts(Connection conn) throws SQLException {
        String sql = 
            "SELECT s.origin_port_id, s.dest_port_id, c.container_type, " +
            "COUNT(s.shipment_id) AS total_historical_bookings, " +
            "AVG(s.quoted_price) AS avg_price " +
            "FROM shipment s " +
            "JOIN containers c ON s.container_id = c.container_id " +
            "WHERE s.status != 'CANCELLED' " +
            "GROUP BY s.origin_port_id, s.dest_port_id, c.container_type";

        List<DemandForecast> forecasts = new ArrayList<>();
        Date nextMonth = Date.valueOf(LocalDate.now().plusMonths(1).withDayOfMonth(1));

        try (PreparedStatement ps = conn.prepareStatement(sql);
             ResultSet rs = ps.executeQuery()) {
            while (rs.next()) {
                DemandForecast df = new DemandForecast();
                df.setOriginPortId(rs.getInt("origin_port_id"));
                df.setDestPortId(rs.getInt("dest_port_id"));
                df.setContainerType(rs.getString("container_type"));
                df.setForecastMonth(nextMonth);

                int history = rs.getInt("total_historical_bookings");
                int predicted = (int) Math.round(history * 1.15) + 2;
                df.setPredictedBookings(predicted);

                BigDecimal confidence = (history >= 3) ? BigDecimal.valueOf(88.00) : BigDecimal.valueOf(65.00);
                df.setConfidencePct(confidence);

                BigDecimal multiplier = (predicted > 4) ? BigDecimal.valueOf(1.05) : BigDecimal.valueOf(0.98);
                df.setSuggestedMultiplier(multiplier);
                forecasts.add(df);
            }
        }

        try (Statement stmt = conn.createStatement()) {
            stmt.executeUpdate("DELETE FROM demand_forecast");
        }

        String insertSql = "INSERT INTO demand_forecast (origin_port_id, dest_port_id, container_type, forecast_month, predicted_bookings, confidence_pct, suggested_multiplier) VALUES (?, ?, ?, ?, ?, ?, ?)";
        int inserted = 0;
        try (PreparedStatement ps = conn.prepareStatement(insertSql)) {
            for (DemandForecast df : forecasts) {
                ps.setInt(1, df.getOriginPortId());
                ps.setInt(2, df.getDestPortId());
                ps.setString(3, df.getContainerType());
                ps.setDate(4, df.getForecastMonth());
                ps.setInt(5, df.getPredictedBookings());
                ps.setBigDecimal(6, df.getConfidencePctAmount());
                ps.setBigDecimal(7, df.getSuggestedMultiplierAmount());
                ps.addBatch();
                inserted++;
            }
            ps.executeBatch();
        }
        return inserted;
    }
}

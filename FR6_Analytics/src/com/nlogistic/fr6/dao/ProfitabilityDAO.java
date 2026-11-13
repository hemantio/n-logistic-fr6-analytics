package com.nlogistic.fr6.dao;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.sql.Connection;
import java.sql.Date;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.List;
import java.util.logging.Level;
import java.util.logging.Logger;

import com.nlogistic.fr6.config.AnalyticsConnectionProvider;
import com.nlogistic.fr6.dto.AnalyticsFilterDTO;
import com.nlogistic.fr6.exception.AnalyticsDataException;
import com.nlogistic.fr6.model.ProfitLoss;
import com.nlogistic.fr6.model.ProfitabilityResult;

/**
 * JDBC Data Access Object for FR6.5 Product and Shipment Profitability.
 * Follows financial rules in SRS Section 2.8, 3.2 (FR2.8) and Section 7.9.
 */
public class ProfitabilityDAO {

    private static final Logger LOGGER = Logger.getLogger(ProfitabilityDAO.class.getName());

    private final AnalyticsConnectionProvider connectionProvider;

    public ProfitabilityDAO() {
        this(AnalyticsConnectionProvider.getInstance());
    }

    public ProfitabilityDAO(AnalyticsConnectionProvider connectionProvider) {
        this.connectionProvider = connectionProvider;
    }

    /**
     * Reads cached product profitability results.
     */
    public List<ProfitabilityResult> getProductProfitability(AnalyticsFilterDTO filter) {
        List<ProfitabilityResult> list = new ArrayList<>();
        StringBuilder sql = new StringBuilder(
            "SELECT pr.result_id, pr.product_id, pr.period_month, pr.revenue, pr.cost, " +
            "pr.margin_pct, pr.created_at, p.product_name, p.sku, p.category " +
            "FROM profitability_result pr " +
            "JOIN products p ON pr.product_id = p.product_id " +
            "WHERE 1=1 "
        );

        if (filter.getCompanyId() != null && !"CONSUMER".equalsIgnoreCase(filter.getUserRole())) {
            sql.append("AND p.owner_company_id = ? ");
        }
        if (filter.getProductId() != null) {
            sql.append("AND pr.product_id = ? ");
        }
        if (filter.getStartDate() != null && filter.getEndDate() != null) {
            sql.append("AND pr.period_month BETWEEN ? AND ? ");
        }
        sql.append("ORDER BY pr.period_month DESC, pr.margin_pct DESC");

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
                    ProfitabilityResult row = new ProfitabilityResult();
                    row.setResultId(rs.getInt("result_id"));
                    row.setProductId(rs.getInt("product_id"));
                    row.setPeriodMonth(rs.getDate("period_month"));
                    row.setRevenue(rs.getBigDecimal("revenue"));
                    row.setCost(rs.getBigDecimal("cost"));
                    row.setMarginPct(rs.getBigDecimal("margin_pct"));
                    row.setCreatedAt(rs.getTimestamp("created_at"));
                    row.setProductName(rs.getString("product_name"));
                    row.setSku(rs.getString("sku"));
                    row.setCategory(rs.getString("category"));
                    list.add(row);
                }
            }
        } catch (SQLException e) {
            LOGGER.log(Level.SEVERE, "Error fetching product profitability", e);
            throw new AnalyticsDataException("Failed to retrieve product profitability", e);
        }
        return list;
    }

    /**
     * Reads cached shipment / seller level Profit & Loss results.
     */
    public List<ProfitLoss> getShipmentProfitLoss(AnalyticsFilterDTO filter) {
        List<ProfitLoss> list = new ArrayList<>();
        StringBuilder sql = new StringBuilder(
            "SELECT pl.pl_id, pl.shipment_id, pl.seller_id, pl.period_month, pl.revenue, " +
            "pl.freight_cost, pl.port_cost, pl.handling_cost, pl.claim_loss, pl.net_profit, " +
            "pl.created_at, comp.company_name AS seller_name, s.shipment_no " +
            "FROM profit_loss pl " +
            "JOIN companies comp ON pl.seller_id = comp.company_id " +
            "LEFT JOIN shipment s ON pl.shipment_id = s.shipment_id " +
            "WHERE 1=1 "
        );

        if (filter.getCompanyId() != null && !"CONSUMER".equalsIgnoreCase(filter.getUserRole())) {
            sql.append("AND pl.seller_id = ? ");
        }
        if (filter.getStartDate() != null && filter.getEndDate() != null) {
            sql.append("AND pl.period_month BETWEEN ? AND ? ");
        }
        sql.append("ORDER BY pl.period_month DESC, pl.net_profit DESC");

        try (Connection conn = connectionProvider.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql.toString())) {
            int idx = 1;
            if (filter.getCompanyId() != null && !"CONSUMER".equalsIgnoreCase(filter.getUserRole())) {
                ps.setInt(idx++, filter.getCompanyId());
            }
            if (filter.getStartDate() != null && filter.getEndDate() != null) {
                ps.setDate(idx++, filter.getStartDate());
                ps.setDate(idx++, filter.getEndDate());
            }

            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    ProfitLoss row = new ProfitLoss();
                    row.setPlId(rs.getInt("pl_id"));
                    row.setShipmentId(rs.getInt("shipment_id"));
                    row.setSellerId(rs.getInt("seller_id"));
                    row.setPeriodMonth(rs.getDate("period_month"));
                    row.setRevenue(rs.getBigDecimal("revenue"));
                    row.setFreightCost(rs.getBigDecimal("freight_cost"));
                    row.setPortCost(rs.getBigDecimal("port_cost"));
                    row.setHandlingCost(rs.getBigDecimal("handling_cost"));
                    row.setClaimLoss(rs.getBigDecimal("claim_loss"));
                    row.setNetProfit(rs.getBigDecimal("net_profit"));
                    row.setCreatedAt(rs.getTimestamp("created_at"));
                    row.setSellerName(rs.getString("seller_name"));
                    row.setShipmentNo(rs.getString("shipment_no"));
                    list.add(row);
                }
            }
        } catch (SQLException e) {
            LOGGER.log(Level.SEVERE, "Error fetching shipment profit & loss", e);
            throw new AnalyticsDataException("Failed to retrieve profit & loss records", e);
        }
        return list;
    }

    /**
     * Recalculates both product profitability and shipment P&L from operational records.
     */
    public int refreshProfitability(Connection conn) throws SQLException {
        // 1. Recalculate product-level profitability
        String prodSql = 
            "SELECT DATE_FORMAT(st.sale_date, '%Y-%m-01') AS period_month, " +
            "p.product_id, " +
            "SUM(st.total_amount) AS revenue, " +
            "SUM(st.quantity * (p.unit_price * 0.65)) AS cost " + // Direct cost based on approved COGS ratio
            "FROM sales_transactions st " +
            "JOIN products p ON st.product_id = p.product_id " +
            "GROUP BY period_month, p.product_id";

        List<ProfitabilityResult> prodResults = new ArrayList<>();
        try (PreparedStatement ps = conn.prepareStatement(prodSql);
             ResultSet rs = ps.executeQuery()) {
            while (rs.next()) {
                Date month = Date.valueOf(rs.getString("period_month"));
                int prodId = rs.getInt("product_id");
                BigDecimal rev = rs.getBigDecimal("revenue");
                BigDecimal cost = rs.getBigDecimal("cost");
                BigDecimal margin = BigDecimal.ZERO;
                if (rev != null && rev.compareTo(BigDecimal.ZERO) > 0) {
                    margin = rev.subtract(cost)
                                .divide(rev, 4, RoundingMode.HALF_UP)
                                .multiply(BigDecimal.valueOf(100))
                                .setScale(2, RoundingMode.HALF_UP);
                }
                ProfitabilityResult item = new ProfitabilityResult();
                item.setProductId(prodId);
                item.setPeriodMonth(month);
                item.setRevenue(rev);
                item.setCost(cost);
                item.setMarginPct(margin);
                prodResults.add(item);
            }
        }

        try (PreparedStatement delProd = conn.prepareStatement("DELETE FROM profitability_result")) {
            delProd.executeUpdate();
        }

        String insProdSql = 
            "INSERT INTO profitability_result (product_id, period_month, revenue, cost, margin_pct) " +
            "VALUES (?, ?, ?, ?, ?)";
        try (PreparedStatement insPs = conn.prepareStatement(insProdSql)) {
            for (ProfitabilityResult item : prodResults) {
                insPs.setInt(1, item.getProductId());
                insPs.setDate(2, item.getPeriodMonth());
                insPs.setBigDecimal(3, item.getRevenue());
                insPs.setBigDecimal(4, item.getCost());
                insPs.setBigDecimal(5, item.getMarginPct());
                insPs.addBatch();
            }
            insPs.executeBatch();
        }

        // 2. Recalculate shipment & seller level P&L per SRS FR2.8
        String plSql = 
            "SELECT s.shipment_id, s.seller_id, " +
            "DATE_FORMAT(s.created_at, '%Y-%m-01') AS period_month, " +
            "COALESCE(bi.paid_amount, 0.00) AS revenue, " +
            "COALESCE(SUM(CASE WHEN ili.item_type = 'FREIGHT' THEN ili.amount * 0.70 ELSE 0 END), 0.00) AS freight_cost, " +
            "COALESCE(SUM(CASE WHEN ili.item_type = 'HANDLING' THEN ili.amount * 0.60 ELSE 0 END), 0.00) AS port_cost, " +
            "COALESCE(SUM(CASE WHEN ili.item_type IN ('CUSTOMS','INSURANCE') THEN ili.amount * 0.50 ELSE 0 END), 0.00) AS handling_cost, " +
            "COALESCE((SELECT SUM(approved_amount) FROM claims c WHERE c.shipment_id = s.shipment_id AND c.status = 'SETTLED'), 0.00) AS claim_loss " +
            "FROM shipment s " +
            "LEFT JOIN billing_invoices bi ON s.shipment_id = bi.shipment_id " +
            "LEFT JOIN invoice_line_items ili ON bi.invoice_id = ili.invoice_id " +
            "GROUP BY s.shipment_id, s.seller_id, period_month, bi.paid_amount";

        List<ProfitLoss> plResults = new ArrayList<>();
        try (PreparedStatement ps = conn.prepareStatement(plSql);
             ResultSet rs = ps.executeQuery()) {
            while (rs.next()) {
                ProfitLoss pl = new ProfitLoss();
                pl.setShipmentId(rs.getInt("shipment_id"));
                pl.setSellerId(rs.getInt("seller_id"));
                pl.setPeriodMonth(Date.valueOf(rs.getString("period_month")));
                BigDecimal rev = rs.getBigDecimal("revenue");
                BigDecimal fCost = rs.getBigDecimal("freight_cost");
                BigDecimal pCost = rs.getBigDecimal("port_cost");
                BigDecimal hCost = rs.getBigDecimal("handling_cost");
                BigDecimal cLoss = rs.getBigDecimal("claim_loss");

                // Net profit formula per SRS: revenue - all costs - claim_loss
                BigDecimal net = rev.subtract(fCost).subtract(pCost).subtract(hCost).subtract(cLoss);

                pl.setRevenue(rev);
                pl.setFreightCost(fCost);
                pl.setPortCost(pCost);
                pl.setHandlingCost(hCost);
                pl.setClaimLoss(cLoss);
                pl.setNetProfit(net);
                plResults.add(pl);
            }
        }

        try (PreparedStatement delPl = conn.prepareStatement("DELETE FROM profit_loss")) {
            delPl.executeUpdate();
        }

        String insPlSql = 
            "INSERT INTO profit_loss (shipment_id, seller_id, period_month, revenue, freight_cost, port_cost, handling_cost, claim_loss, net_profit) " +
            "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)";
        try (PreparedStatement insPl = conn.prepareStatement(insPlSql)) {
            for (ProfitLoss pl : plResults) {
                insPl.setInt(1, pl.getShipmentId());
                insPl.setInt(2, pl.getSellerId());
                insPl.setDate(3, pl.getPeriodMonth());
                insPl.setBigDecimal(4, pl.getRevenue());
                insPl.setBigDecimal(5, pl.getFreightCost());
                insPl.setBigDecimal(6, pl.getPortCost());
                insPl.setBigDecimal(7, pl.getHandlingCost());
                insPl.setBigDecimal(8, pl.getClaimLoss());
                insPl.setBigDecimal(9, pl.getNetProfit());
                insPl.addBatch();
            }
            insPl.executeBatch();
        }

        return prodResults.size() + plResults.size();
    }
}

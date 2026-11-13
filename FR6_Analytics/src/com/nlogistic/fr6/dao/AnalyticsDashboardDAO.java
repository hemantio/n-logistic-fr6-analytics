package com.nlogistic.fr6.dao;

import java.math.BigDecimal;
import java.sql.Connection;
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
import com.nlogistic.fr6.model.AnalyticsKPI;

/**
 * JDBC Data Access Object for FR6.1 Dashboard KPIs and operational reference filters.
 */
public class AnalyticsDashboardDAO {

    private static final Logger LOGGER = Logger.getLogger(AnalyticsDashboardDAO.class.getName());

    private final AnalyticsConnectionProvider connectionProvider;

    public AnalyticsDashboardDAO() {
        this(AnalyticsConnectionProvider.getInstance());
    }

    public AnalyticsDashboardDAO(AnalyticsConnectionProvider connectionProvider) {
        this.connectionProvider = connectionProvider;
    }

    /**
     * Calculates the 5 mandatory FR6.1 KPIs directly from operational tables.
     */
    public AnalyticsKPI calculateKPIs(AnalyticsFilterDTO filter) {
        AnalyticsKPI kpi = new AnalyticsKPI();

        try (Connection conn = connectionProvider.getConnection()) {
            // 1. Active Shipments KPI (Not DELIVERED or CANCELLED)
            StringBuilder sqlShip = new StringBuilder(
                "SELECT COUNT(*) AS active_count FROM shipment " +
                "WHERE status IN ('BOOKED','LOADED','DEPARTED','IN_TRANSIT','ARRIVED','CUSTOMS_CLEARED') "
            );
            if (filter.getCompanyId() != null) {
                if ("CONSUMER".equalsIgnoreCase(filter.getUserRole())) {
                    sqlShip.append("AND consumer_id IN (SELECT customer_id FROM customers WHERE company_id = ?) ");
                } else {
                    sqlShip.append("AND seller_id = ? ");
                }
            }
            if (filter.getStartDate() != null && filter.getEndDate() != null) {
                sqlShip.append("AND (etd BETWEEN ? AND ? OR created_at BETWEEN ? AND ?) ");
            }

            try (PreparedStatement ps = conn.prepareStatement(sqlShip.toString())) {
                int paramIdx = 1;
                if (filter.getCompanyId() != null) {
                    ps.setInt(paramIdx++, filter.getCompanyId());
                }
                if (filter.getStartDate() != null && filter.getEndDate() != null) {
                    ps.setDate(paramIdx++, filter.getStartDate());
                    ps.setDate(paramIdx++, filter.getEndDate());
                    ps.setDate(paramIdx++, filter.getStartDate());
                    ps.setDate(paramIdx++, filter.getEndDate());
                }
                try (ResultSet rs = ps.executeQuery()) {
                    if (rs.next()) {
                        kpi.setActiveShipments(rs.getInt("active_count"));
                    }
                }
            }

            // 2. Containers Available KPI
            StringBuilder sqlCont = new StringBuilder("SELECT COUNT(*) AS avail_count FROM containers WHERE status = 'AVAILABLE' ");
            if (filter.getCompanyId() != null && !"CONSUMER".equalsIgnoreCase(filter.getUserRole())) {
                sqlCont.append("AND seller_id = ? ");
            }
            try (PreparedStatement ps = conn.prepareStatement(sqlCont.toString())) {
                if (filter.getCompanyId() != null && !"CONSUMER".equalsIgnoreCase(filter.getUserRole())) {
                    ps.setInt(1, filter.getCompanyId());
                }
                try (ResultSet rs = ps.executeQuery()) {
                    if (rs.next()) {
                        kpi.setContainersAvailable(rs.getInt("avail_count"));
                    }
                }
            }

            // 3. Revenue KPI (Paid Invoices per SRS FR2.8)
            StringBuilder sqlRev = new StringBuilder(
                "SELECT COALESCE(SUM(paid_amount), 0.00) AS total_rev FROM billing_invoices WHERE status = 'PAID' "
            );
            if (filter.getCompanyId() != null) {
                if ("CONSUMER".equalsIgnoreCase(filter.getUserRole())) {
                    sqlRev.append("AND consumer_id IN (SELECT customer_id FROM customers WHERE company_id = ?) ");
                } else {
                    sqlRev.append("AND seller_id = ? ");
                }
            }
            if (filter.getStartDate() != null && filter.getEndDate() != null) {
                sqlRev.append("AND issue_date BETWEEN ? AND ? ");
            }
            try (PreparedStatement ps = conn.prepareStatement(sqlRev.toString())) {
                int paramIdx = 1;
                if (filter.getCompanyId() != null) {
                    ps.setInt(paramIdx++, filter.getCompanyId());
                }
                if (filter.getStartDate() != null && filter.getEndDate() != null) {
                    ps.setDate(paramIdx++, filter.getStartDate());
                    ps.setDate(paramIdx++, filter.getEndDate());
                }
                try (ResultSet rs = ps.executeQuery()) {
                    if (rs.next()) {
                        kpi.setRevenue(rs.getBigDecimal("total_rev"));
                    }
                }
            }

            // 4. Pending Invoices KPI (Count & Outstanding Balance)
            StringBuilder sqlPending = new StringBuilder(
                "SELECT COUNT(*) AS pend_count, COALESCE(SUM(total_amount - paid_amount), 0.00) AS pend_amount " +
                "FROM billing_invoices WHERE status IN ('UNPAID', 'PARTIAL') "
            );
            if (filter.getCompanyId() != null) {
                if ("CONSUMER".equalsIgnoreCase(filter.getUserRole())) {
                    sqlPending.append("AND consumer_id IN (SELECT customer_id FROM customers WHERE company_id = ?) ");
                } else {
                    sqlPending.append("AND seller_id = ? ");
                }
            }
            if (filter.getStartDate() != null && filter.getEndDate() != null) {
                sqlPending.append("AND issue_date BETWEEN ? AND ? ");
            }
            try (PreparedStatement ps = conn.prepareStatement(sqlPending.toString())) {
                int paramIdx = 1;
                if (filter.getCompanyId() != null) {
                    ps.setInt(paramIdx++, filter.getCompanyId());
                }
                if (filter.getStartDate() != null && filter.getEndDate() != null) {
                    ps.setDate(paramIdx++, filter.getStartDate());
                    ps.setDate(paramIdx++, filter.getEndDate());
                }
                try (ResultSet rs = ps.executeQuery()) {
                    if (rs.next()) {
                        kpi.setPendingInvoicesCount(rs.getInt("pend_count"));
                        kpi.setPendingInvoicesAmount(rs.getBigDecimal("pend_amount"));
                    }
                }
            }

            // 5. Open Claims KPI (Submitted, Under Review, Approved, Partially Approved)
            StringBuilder sqlClaims = new StringBuilder(
                "SELECT COUNT(*) AS open_count, COALESCE(SUM(claimed_amount), 0.00) AS open_amount " +
                "FROM claims WHERE status IN ('SUBMITTED','UNDER_REVIEW','APPROVED','PARTIALLY_APPROVED') "
            );
            if (filter.getCompanyId() != null) {
                if ("CONSUMER".equalsIgnoreCase(filter.getUserRole())) {
                    sqlClaims.append("AND consumer_id IN (SELECT customer_id FROM customers WHERE company_id = ?) ");
                } else {
                    sqlClaims.append("AND shipment_id IN (SELECT shipment_id FROM shipment WHERE seller_id = ?) ");
                }
            }
            if (filter.getStartDate() != null && filter.getEndDate() != null) {
                sqlClaims.append("AND DATE(created_at) BETWEEN ? AND ? ");
            }
            try (PreparedStatement ps = conn.prepareStatement(sqlClaims.toString())) {
                int paramIdx = 1;
                if (filter.getCompanyId() != null) {
                    ps.setInt(paramIdx++, filter.getCompanyId());
                }
                if (filter.getStartDate() != null && filter.getEndDate() != null) {
                    ps.setDate(paramIdx++, filter.getStartDate());
                    ps.setDate(paramIdx++, filter.getEndDate());
                }
                try (ResultSet rs = ps.executeQuery()) {
                    if (rs.next()) {
                        kpi.setOpenClaimsCount(rs.getInt("open_count"));
                        kpi.setOpenClaimsAmount(rs.getBigDecimal("open_amount"));
                    }
                }
            }

        } catch (SQLException e) {
            LOGGER.log(Level.SEVERE, "Error calculating dashboard KPIs", e);
            throw new AnalyticsDataException("Failed to calculate analytics dashboard KPIs", e);
        }

        return kpi;
    }

    /**
     * Retrieves list of active ports for route filter dropdowns.
     */
    public List<Map<String, Object>> getAvailablePorts() {
        List<Map<String, Object>> ports = new ArrayList<>();
        String sql = "SELECT port_id, port_code, port_name, city, country FROM ports ORDER BY port_name ASC";
        try (Connection conn = connectionProvider.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql);
             ResultSet rs = ps.executeQuery()) {
            while (rs.next()) {
                Map<String, Object> map = new HashMap<>();
                map.put("portId", rs.getInt("port_id"));
                map.put("portCode", rs.getString("port_code"));
                map.put("portName", rs.getString("port_name"));
                map.put("city", rs.getString("city"));
                map.put("country", rs.getString("country"));
                ports.add(map);
            }
        } catch (SQLException e) {
            LOGGER.log(Level.SEVERE, "Error fetching ports list", e);
        }
        return ports;
    }

    /**
     * Retrieves list of companies for company filter dropdowns.
     */
    public List<Map<String, Object>> getAvailableCompanies() {
        List<Map<String, Object>> companies = new ArrayList<>();
        String sql = "SELECT company_id, company_name, company_type FROM companies ORDER BY company_name ASC";
        try (Connection conn = connectionProvider.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql);
             ResultSet rs = ps.executeQuery()) {
            while (rs.next()) {
                Map<String, Object> map = new HashMap<>();
                map.put("companyId", rs.getInt("company_id"));
                map.put("companyName", rs.getString("company_name"));
                map.put("companyType", rs.getString("company_type"));
                companies.add(map);
            }
        } catch (SQLException e) {
            LOGGER.log(Level.SEVERE, "Error fetching companies list", e);
        }
        return companies;
    }
}

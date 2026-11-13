package com.nlogistic.fr6.util;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.text.ParseException;
import java.text.SimpleDateFormat;
import java.util.Calendar;
import java.util.Date;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpSession;

/**
 * FR6 Centralized Utility Class.
 * Consolidates date parsing, input sanitization, numeric utilities, and security context.
 */
public final class AnalyticsUtil {

    private static final String DATE_FORMAT = "yyyy-MM-dd";

    private AnalyticsUtil() {
        // Prevent instantiation
    }

    // ==========================================
    // 1. DATE UTILITIES
    // ==========================================

    public static Date parseDate(String dateStr) {
        if (dateStr == null || dateStr.trim().isEmpty()) {
            return null;
        }
        try {
            SimpleDateFormat sdf = new SimpleDateFormat(DATE_FORMAT);
            sdf.setLenient(false);
            return sdf.parse(dateStr.trim());
        } catch (ParseException e) {
            return null;
        }
    }

    public static String formatDate(Date date) {
        if (date == null) return "";
        return new SimpleDateFormat(DATE_FORMAT).format(date);
    }

    public static Date getDefaultStartDate() {
        Calendar cal = Calendar.getInstance();
        cal.add(Calendar.MONTH, -6);
        cal.set(Calendar.DAY_OF_MONTH, 1);
        cal.set(Calendar.HOUR_OF_DAY, 0);
        cal.set(Calendar.MINUTE, 0);
        cal.set(Calendar.SECOND, 0);
        cal.set(Calendar.MILLISECOND, 0);
        return cal.getTime();
    }

    public static Date getDefaultEndDate() {
        Calendar cal = Calendar.getInstance();
        cal.set(Calendar.HOUR_OF_DAY, 23);
        cal.set(Calendar.MINUTE, 59);
        cal.set(Calendar.SECOND, 59);
        cal.set(Calendar.MILLISECOND, 999);
        return cal.getTime();
    }

    // ==========================================
    // 2. SANITIZATION & NUMERIC PARSING
    // ==========================================

    public static String sanitize(String input) {
        if (input == null) return null;
        String trimmed = input.trim();
        return trimmed.isEmpty() ? null : trimmed;
    }

    public static Integer parseInteger(String val, Integer defaultVal) {
        if (val == null || val.trim().isEmpty()) return defaultVal;
        try {
            return Integer.parseInt(val.trim());
        } catch (NumberFormatException e) {
            return defaultVal;
        }
    }

    public static Double parseDouble(String val, Double defaultVal) {
        if (val == null || val.trim().isEmpty()) return defaultVal;
        try {
            return Double.parseDouble(val.trim());
        } catch (NumberFormatException e) {
            return defaultVal;
        }
    }

    public static double round(double value, int places) {
        if (places < 0) throw new IllegalArgumentException();
        BigDecimal bd = BigDecimal.valueOf(value);
        bd = bd.setScale(places, RoundingMode.HALF_UP);
        return bd.doubleValue();
    }

    // ==========================================
    // 3. SECURITY CONTEXT & MULTI-TENANT ISOLATION
    // ==========================================

    public static class SecurityContext {
        private final int userId;
        private final String role;
        private final Integer companyId;

        public SecurityContext(int userId, String role, Integer companyId) {
            this.userId = userId;
            this.role = (role != null) ? role.toUpperCase() : "ADMIN";
            this.companyId = companyId;
        }

        public int getUserId() { return userId; }
        public String getRole() { return role; }
        public Integer getCompanyId() { return companyId; }

        public boolean isAdmin() {
            return "ADMIN".equalsIgnoreCase(role);
        }

        public boolean isSeller() {
            return "SELLER".equalsIgnoreCase(role);
        }

        public boolean isConsumer() {
            return "CONSUMER".equalsIgnoreCase(role);
        }

        public Integer getEffectiveCompanyId(Integer requestedCompanyId) {
            if (isAdmin()) {
                return requestedCompanyId; // Admin can inspect any company or all
            }
            // Enforce tenancy boundary: Non-admins are locked to their own company
            return this.companyId;
        }
    }

    public static SecurityContext extractSecurityContext(HttpServletRequest request) {
        if (request == null) {
            return new SecurityContext(1, "ADMIN", null);
        }
        HttpSession session = request.getSession(false);
        if (session != null && session.getAttribute("user_id") != null) {
            int uid = ((Number) session.getAttribute("user_id")).intValue();
            String role = (String) session.getAttribute("role");
            Integer cid = session.getAttribute("company_id") != null 
                ? ((Number) session.getAttribute("company_id")).intValue() 
                : null;
            return new SecurityContext(uid, role, cid);
        }
        // Development default context
        return new SecurityContext(1, "ADMIN", null);
    }
}

package com.nlogistic.fr6.util;

/**
 * Utility methods for input validation, sanitization, and parsing in FR6.
 */
public final class AnalyticsValidationUtil {

    private AnalyticsValidationUtil() {
        // utility class
    }

    public static String sanitize(String input) {
        if (input == null) {
            return null;
        }
        return input.trim();
    }

    public static Integer parseInteger(String input, Integer defaultValue) {
        if (input == null || input.trim().isEmpty()) {
            return defaultValue;
        }
        try {
            return Integer.valueOf(input.trim());
        } catch (NumberFormatException e) {
            return defaultValue;
        }
    }

    public static Double parseDouble(String input, Double defaultValue) {
        if (input == null || input.trim().isEmpty()) {
            return defaultValue;
        }
        try {
            return Double.valueOf(input.trim());
        } catch (NumberFormatException e) {
            return defaultValue;
        }
    }

    public static boolean isValidRole(String role) {
        if (role == null) return false;
        String r = role.trim().toUpperCase();
        return "ADMIN".equals(r) || "SELLER".equals(r) || "CONSUMER".equals(r);
    }

    public static boolean isValidContainerType(String type) {
        if (type == null) return false;
        String t = type.trim().toUpperCase();
        return "DRY".equals(t) || "REEFER".equals(t) || "OPEN_TOP".equals(t) || "TANK".equals(t);
    }
}

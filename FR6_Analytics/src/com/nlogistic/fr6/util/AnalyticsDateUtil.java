package com.nlogistic.fr6.util;

import java.sql.Date;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.time.format.DateTimeParseException;

/**
 * Utility methods for date manipulation, parsing, and formatting in FR6.
 */
public final class AnalyticsDateUtil {

    public static final DateTimeFormatter ISO_FORMATTER = DateTimeFormatter.ofPattern("yyyy-MM-dd");
    public static final DateTimeFormatter MONTH_FORMATTER = DateTimeFormatter.ofPattern("yyyy-MM");

    private AnalyticsDateUtil() {
        // utility class
    }

    public static Date parseDate(String dateStr) {
        if (dateStr == null || dateStr.trim().isEmpty()) {
            return null;
        }
        try {
            LocalDate ld = LocalDate.parse(dateStr.trim(), ISO_FORMATTER);
            return Date.valueOf(ld);
        } catch (DateTimeParseException e) {
            // Attempt yyyy-MM
            try {
                LocalDate ld = LocalDate.parse(dateStr.trim() + "-01", ISO_FORMATTER);
                return Date.valueOf(ld);
            } catch (DateTimeParseException ex) {
                return null;
            }
        }
    }

    public static String formatDate(Date date) {
        if (date == null) {
            return "";
        }
        return date.toLocalDate().format(ISO_FORMATTER);
    }

    public static String formatMonth(Date date) {
        if (date == null) {
            return "";
        }
        return date.toLocalDate().format(MONTH_FORMATTER);
    }

    public static Date getFirstDayOfMonth(Date date) {
        if (date == null) {
            return null;
        }
        LocalDate ld = date.toLocalDate();
        return Date.valueOf(ld.withDayOfMonth(1));
    }

    public static Date now() {
        return Date.valueOf(LocalDate.now());
    }

    public static Date getDefaultStartDate() {
        // Default to 6 months prior
        return Date.valueOf(LocalDate.now().minusMonths(6).withDayOfMonth(1));
    }

    public static Date getDefaultEndDate() {
        return Date.valueOf(LocalDate.now());
    }
}

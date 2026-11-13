package com.nlogistic.fr6.exception;

/**
 * Exception thrown when database or data mapping operations fail within FR6.
 */
public class AnalyticsDataException extends AnalyticsException {
    private static final long serialVersionUID = 1L;

    public AnalyticsDataException(String message) {
        super(message);
    }

    public AnalyticsDataException(String message, Throwable cause) {
        super(message, cause);
    }
}

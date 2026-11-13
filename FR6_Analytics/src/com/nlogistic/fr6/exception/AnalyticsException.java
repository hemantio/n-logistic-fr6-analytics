package com.nlogistic.fr6.exception;

/**
 * Base unchecked exception for FR6 Analytics module.
 */
public class AnalyticsException extends RuntimeException {
    private static final long serialVersionUID = 1L;

    public AnalyticsException(String message) {
        super(message);
    }

    public AnalyticsException(String message, Throwable cause) {
        super(message, cause);
    }
}

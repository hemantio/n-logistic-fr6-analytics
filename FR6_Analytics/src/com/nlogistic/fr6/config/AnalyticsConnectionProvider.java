package com.nlogistic.fr6.config;

import java.sql.Connection;
import java.sql.SQLException;

/**
 * Interface defining the database connection provider seam for FR6.
 * The main platform integrator can plug in the enterprise shared connection pool
 * by calling {@link #setInstance(AnalyticsConnectionProvider)}.
 */
public interface AnalyticsConnectionProvider {

    Connection getConnection() throws SQLException;

    class Holder {
        private static volatile AnalyticsConnectionProvider instance = new LocalAnalyticsConnectionProvider();
    }

    static AnalyticsConnectionProvider getInstance() {
        return Holder.instance;
    }

    static void setInstance(AnalyticsConnectionProvider provider) {
        if (provider != null) {
            Holder.instance = provider;
        }
    }
}

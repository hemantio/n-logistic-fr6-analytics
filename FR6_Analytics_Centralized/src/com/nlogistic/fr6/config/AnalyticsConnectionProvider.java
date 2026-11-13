package com.nlogistic.fr6.config;

import java.io.InputStream;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;
import java.util.Properties;
import java.util.logging.Level;
import java.util.logging.Logger;

/**
 * FR6 Centralized Database Connection Provider Seam.
 * 
 * Defines the connection contract for FR6 Analytics.
 * Integration developers can plug in the platform connection pool (HikariCP, DBCP, Tomcat JNDI)
 * in one line via:
 *   AnalyticsConnectionProvider.setCustomProvider(() -> platformDataSource.getConnection());
 * 
 * By default, falls back to fr6_db.properties on the classpath.
 */
public interface AnalyticsConnectionProvider {

    Connection provideConnection() throws SQLException;

    // Static registry and default provider
    public static class Holder {
        private static final Logger LOGGER = Logger.getLogger(AnalyticsConnectionProvider.class.getName());
        private static AnalyticsConnectionProvider customProvider = null;
        private static Properties config = null;

        static {
            loadDefaultConfig();
        }

        private static void loadDefaultConfig() {
            config = new Properties();
            try (InputStream in = AnalyticsConnectionProvider.class.getClassLoader().getResourceAsStream("fr6_db.properties")) {
                if (in != null) {
                    config.load(in);
                    Class.forName(config.getProperty("db.driver", "com.mysql.cj.jdbc.Driver"));
                    LOGGER.info("FR6 Centralized Connection Provider initialized from fr6_db.properties");
                } else {
                    LOGGER.warning("fr6_db.properties not found on classpath; using localhost fallback");
                    config.setProperty("db.url", "jdbc:mysql://[::1]:3306/n_logistic_db?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=UTC");
                    config.setProperty("db.user", "root");
                    config.setProperty("db.password", "");
                    Class.forName("com.mysql.cj.jdbc.Driver");
                }
            } catch (Exception e) {
                LOGGER.log(Level.SEVERE, "Failed to initialize default FR6 database driver", e);
            }
        }
    }

    /**
     * Replaces the connection provider with the host application's connection pool.
     */
    public static void setCustomProvider(AnalyticsConnectionProvider provider) {
        Holder.customProvider = provider;
    }

    /**
     * Primary seam to obtain a JDBC connection for FR6 analytics operations.
     */
    public static Connection getConnection() throws SQLException {
        if (Holder.customProvider != null) {
            return Holder.customProvider.provideConnection();
        }
        return DriverManager.getConnection(
            Holder.config.getProperty("db.url"),
            Holder.config.getProperty("db.user"),
            Holder.config.getProperty("db.password")
        );
    }
}

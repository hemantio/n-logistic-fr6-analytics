package com.nlogistic.fr6.config;

import java.io.InputStream;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;
import java.util.Properties;
import java.util.logging.Level;
import java.util.logging.Logger;

/**
 * Default local development database connection provider.
 * Loads configuration from fr6_db.properties or environment variables.
 */
public class LocalAnalyticsConnectionProvider implements AnalyticsConnectionProvider {

    private static final Logger LOGGER = Logger.getLogger(LocalAnalyticsConnectionProvider.class.getName());

    private String jdbcUrl = "jdbc:mysql://localhost:3306/n_logistic_db?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=UTC&characterEncoding=UTF-8";
    private String username = "root";
    private String password = "";
    private String driverClassName = "com.mysql.cj.jdbc.Driver";

    public LocalAnalyticsConnectionProvider() {
        loadConfiguration();
        try {
            Class.forName(driverClassName);
        } catch (ClassNotFoundException e) {
            LOGGER.log(Level.SEVERE, "MySQL JDBC Driver not found: " + driverClassName, e);
        }
    }

    private void loadConfiguration() {
        try (InputStream in = getClass().getClassLoader().getResourceAsStream("fr6_db.properties")) {
            if (in != null) {
                Properties props = new Properties();
                props.load(in);
                if (props.getProperty("db.url") != null) {
                    this.jdbcUrl = props.getProperty("db.url").trim();
                }
                if (props.getProperty("db.user") != null) {
                    this.username = props.getProperty("db.user").trim();
                }
                if (props.getProperty("db.password") != null) {
                    this.password = props.getProperty("db.password").trim();
                }
                if (props.getProperty("db.driver") != null) {
                    this.driverClassName = props.getProperty("db.driver").trim();
                }
                LOGGER.info("FR6 LocalAnalyticsConnectionProvider initialized from fr6_db.properties");
            }
        } catch (Exception e) {
            LOGGER.log(Level.WARNING, "Could not load fr6_db.properties, using defaults", e);
        }

        // Allow system properties or environment variable override
        String envUrl = System.getenv("FR6_DB_URL");
        if (envUrl != null && !envUrl.trim().isEmpty()) {
            this.jdbcUrl = envUrl.trim();
        }
        String envUser = System.getenv("FR6_DB_USER");
        if (envUser != null && !envUser.trim().isEmpty()) {
            this.username = envUser.trim();
        }
        String envPass = System.getenv("FR6_DB_PASSWORD");
        if (envPass != null) {
            this.password = envPass.trim();
        }
    }

    @Override
    public Connection getConnection() throws SQLException {
        return DriverManager.getConnection(jdbcUrl, username, password);
    }
}

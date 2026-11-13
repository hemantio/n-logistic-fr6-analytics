package com.nlogistic.fr6.config;

import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpSession;

/**
 * Encapsulates the user access context and RBAC authorization contract for FR6.
 * Reads the authenticated identity from the HTTP session as established by FR1.
 */
public class AnalyticsAccessContext {

    // Standard session attribute keys matching FR1 auth contract
    public static final String SESSION_KEY_ROLE = "userRole";
    public static final String SESSION_KEY_USER_ID = "userId";
    public static final String SESSION_KEY_COMPANY_ID = "companyId";
    public static final String SESSION_KEY_USER_NAME = "userName";
    public static final String SESSION_KEY_USER_EMAIL = "userEmail";

    private final String role;
    private final Integer userId;
    private final Integer companyId;
    private final String userName;
    private final String userEmail;

    public AnalyticsAccessContext(String role, Integer userId, Integer companyId, String userName, String userEmail) {
        this.role = (role != null) ? role.trim().toUpperCase() : "ADMIN"; // Default to ADMIN for local testing if unassigned
        this.userId = userId;
        this.companyId = companyId;
        this.userName = (userName != null) ? userName : "Authorized User";
        this.userEmail = userEmail;
    }

    /**
     * Extracts or constructs the access context from the current HTTP session.
     */
    public static AnalyticsAccessContext fromRequest(HttpServletRequest request) {
        HttpSession session = request.getSession(false);
        if (session == null) {
            // Standalone development fallback context (Admin)
            return new AnalyticsAccessContext("ADMIN", 1, null, "Local Admin", "admin@nlogistic.com");
        }

        String role = (String) session.getAttribute(SESSION_KEY_ROLE);
        if (role == null) {
            role = (String) session.getAttribute("role");
        }
        if (role == null) {
            role = "ADMIN";
        }

        Integer userId = (Integer) session.getAttribute(SESSION_KEY_USER_ID);
        if (userId == null) {
            userId = (Integer) session.getAttribute("user_id");
        }

        Integer companyId = (Integer) session.getAttribute(SESSION_KEY_COMPANY_ID);
        if (companyId == null) {
            companyId = (Integer) session.getAttribute("company_id");
        }

        String userName = (String) session.getAttribute(SESSION_KEY_USER_NAME);
        String userEmail = (String) session.getAttribute(SESSION_KEY_USER_EMAIL);

        return new AnalyticsAccessContext(role, userId, companyId, userName, userEmail);
    }

    public String getRole() {
        return role;
    }

    public Integer getUserId() {
        return userId;
    }

    public Integer getCompanyId() {
        return companyId;
    }

    public String getUserName() {
        return userName;
    }

    public String getUserEmail() {
        return userEmail;
    }

    public boolean isAdmin() {
        return "ADMIN".equalsIgnoreCase(role);
    }

    public boolean isSeller() {
        return "SELLER".equalsIgnoreCase(role);
    }

    public boolean isConsumer() {
        return "CONSUMER".equalsIgnoreCase(role);
    }

    /**
     * Enforces company-level isolation: a Seller or Consumer can NEVER view another company's data.
     * Admin can view all or filter down to a specific company.
     */
    public Integer getEffectiveCompanyId(Integer requestedCompanyId) {
        if (isAdmin()) {
            return requestedCompanyId; // Admin can specify any company or null (all)
        }
        // Non-admin can ONLY ever access their own assigned companyId
        return this.companyId;
    }

    public boolean canAccessCompany(Integer targetCompanyId) {
        if (isAdmin()) {
            return true;
        }
        if (this.companyId == null || targetCompanyId == null) {
            return false;
        }
        return this.companyId.equals(targetCompanyId);
    }
}

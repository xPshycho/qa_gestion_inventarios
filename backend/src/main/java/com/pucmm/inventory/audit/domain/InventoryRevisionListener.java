package com.pucmm.inventory.audit.domain;

import org.hibernate.envers.RevisionListener;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.util.StringUtils;

public class InventoryRevisionListener implements RevisionListener {
    private static final String PREFERRED_USERNAME_CLAIM = "preferred_username";
    private static final String SYSTEM_USERNAME = "system";
    private static final String ANONYMOUS_USERNAME = "anonymousUser";

    @Override
    public void newRevision(Object revisionEntity) {
        InventoryRevisionEntity revision = (InventoryRevisionEntity) revisionEntity;
        revision.setUsername(resolveUsername());
    }

    private String resolveUsername() {
        Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
        if (authentication == null || !authentication.isAuthenticated()) {
            return SYSTEM_USERNAME;
        }

        String username = resolvePrincipalUsername(authentication);
        if (!StringUtils.hasText(username) || ANONYMOUS_USERNAME.equals(username)) {
            return SYSTEM_USERNAME;
        }

        return username;
    }

    private String resolvePrincipalUsername(Authentication authentication) {
        if (authentication.getPrincipal() instanceof Jwt jwt) {
            String preferredUsername = jwt.getClaimAsString(PREFERRED_USERNAME_CLAIM);
            if (StringUtils.hasText(preferredUsername)) {
                return preferredUsername.trim();
            }
        }

        return authentication.getName();
    }
}

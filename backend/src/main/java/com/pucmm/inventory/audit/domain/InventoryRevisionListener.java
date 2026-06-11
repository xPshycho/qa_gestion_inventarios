package com.pucmm.inventory.audit.domain;

import org.hibernate.envers.RevisionListener;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.util.StringUtils;

public class InventoryRevisionListener implements RevisionListener {
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

        String username = authentication.getName();
        if (!StringUtils.hasText(username) || ANONYMOUS_USERNAME.equals(username)) {
            return SYSTEM_USERNAME;
        }

        return username;
    }
}

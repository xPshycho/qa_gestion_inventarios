package com.pucmm.inventory.stock.service;

import org.springframework.security.core.Authentication;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.stereotype.Component;
import org.springframework.util.StringUtils;

@Component
public class AuthenticatedInventoryUserResolver {
    private static final String PREFERRED_USERNAME_CLAIM = "preferred_username";
    private static final String ANONYMOUS_USERNAME = "anonymousUser";

    public String resolveUsername(Authentication authentication) {
        if (authentication == null || !authentication.isAuthenticated()) {
            throw new AuthenticatedInventoryUserException();
        }

        if (authentication.getPrincipal() instanceof Jwt jwt) {
            String preferredUsername = jwt.getClaimAsString(PREFERRED_USERNAME_CLAIM);
            if (StringUtils.hasText(preferredUsername)) {
                return preferredUsername.trim();
            }
        }

        String username = authentication.getName();
        if (!StringUtils.hasText(username) || ANONYMOUS_USERNAME.equals(username)) {
            throw new AuthenticatedInventoryUserException();
        }

        return username.trim();
    }
}
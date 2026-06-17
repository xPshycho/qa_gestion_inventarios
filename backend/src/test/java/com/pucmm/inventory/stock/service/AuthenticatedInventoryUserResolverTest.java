package com.pucmm.inventory.stock.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.time.Instant;
import org.junit.jupiter.api.Test;
import org.springframework.security.authentication.TestingAuthenticationToken;
import org.springframework.security.oauth2.jwt.Jwt;

class AuthenticatedInventoryUserResolverTest {
    private final AuthenticatedInventoryUserResolver resolver = new AuthenticatedInventoryUserResolver();

    @Test
    void resolvesPreferredUsernameFromJwt() {
        Jwt jwt = Jwt.withTokenValue("token")
                .header("alg", "none")
                .claim("sub", "keycloak-id")
                .claim("preferred_username", "edwin")
                .issuedAt(Instant.parse("2026-06-07T12:00:00Z"))
                .expiresAt(Instant.parse("2026-06-07T12:05:00Z"))
                .build();

        TestingAuthenticationToken authentication = new TestingAuthenticationToken(jwt, "token");
        authentication.setAuthenticated(true);

        String username = resolver.resolveUsername(authentication);

        assertThat(username).isEqualTo("edwin");
    }

    @Test
    void fallsBackToAuthenticationName() {
        TestingAuthenticationToken authentication = new TestingAuthenticationToken("carlos", "token");
        authentication.setAuthenticated(true);

        String username = resolver.resolveUsername(authentication);

        assertThat(username).isEqualTo("carlos");
    }

    @Test
    void rejectsAnonymousAuthentication() {
        TestingAuthenticationToken authentication = new TestingAuthenticationToken("anonymousUser", "token");
        authentication.setAuthenticated(true);

        assertThatThrownBy(() -> resolver.resolveUsername(authentication))
                .isInstanceOf(AuthenticatedInventoryUserException.class);
    }
}

package com.pucmm.inventory.audit.domain;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import java.time.Instant;
import java.time.ZoneOffset;
import java.util.Map;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.security.authentication.TestingAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.test.util.ReflectionTestUtils;

class InventoryRevisionListenerTest {
    private final InventoryRevisionListener listener = new InventoryRevisionListener();

    @AfterEach
    void clearSecurityContext() {
        SecurityContextHolder.clearContext();
    }

    @Test
    void recordsPreferredUsernameFromAuthenticatedJwt() {
        Jwt jwt = new Jwt(
                "token",
                Instant.now(),
                Instant.now().plusSeconds(300),
                Map.of("alg", "none"),
                Map.of("sub", "user-1", "preferred_username", "  edwin  ")
        );
        SecurityContextHolder.getContext().setAuthentication(
                new TestingAuthenticationToken(jwt, null, "ROLE_USER")
        );
        InventoryRevisionEntity revision = revision(7, 1_700_000_000_000L);

        listener.newRevision(revision);

        assertThat(revision.getId()).isEqualTo(7);
        assertThat(revision.getUsername()).isEqualTo("edwin");
        assertThat(revision.getChangedAt()).isEqualTo(
                Instant.ofEpochMilli(1_700_000_000_000L).atOffset(ZoneOffset.UTC)
        );
    }

    @Test
    void fallsBackToAuthenticationNameForNonJwtPrincipal() {
        SecurityContextHolder.getContext().setAuthentication(
                new TestingAuthenticationToken("principal", null, "ROLE_USER") {
                    @Override
                    public String getName() {
                        return "carlos";
                    }
                }
        );
        InventoryRevisionEntity revision = revision(8, 1_700_000_001_000L);

        listener.newRevision(revision);

        assertThat(revision.getUsername()).isEqualTo("carlos");
        assertThat(revision.getRevisionTimestamp()).isEqualTo(1_700_000_001_000L);
    }

    @Test
    void usesSystemWhenAuthenticationIsMissingUnauthenticatedOrAnonymous() {
        InventoryRevisionEntity missing = revision(1, 1L);
        listener.newRevision(missing);

        TestingAuthenticationToken unauthenticated =
                new TestingAuthenticationToken("principal", null);
        unauthenticated.setAuthenticated(false);
        SecurityContextHolder.getContext().setAuthentication(unauthenticated);
        InventoryRevisionEntity inactive = revision(2, 2L);
        listener.newRevision(inactive);

        TestingAuthenticationToken anonymous = mock(TestingAuthenticationToken.class);
        when(anonymous.isAuthenticated()).thenReturn(true);
        when(anonymous.getPrincipal()).thenReturn("principal");
        when(anonymous.getName()).thenReturn("anonymousUser");
        SecurityContextHolder.getContext().setAuthentication(anonymous);
        InventoryRevisionEntity anonymousRevision = revision(3, 3L);
        listener.newRevision(anonymousRevision);

        assertThat(missing.getUsername()).isEqualTo("system");
        assertThat(inactive.getUsername()).isEqualTo("system");
        assertThat(anonymousRevision.getUsername()).isEqualTo("system");
    }

    private InventoryRevisionEntity revision(int id, long timestamp) {
        InventoryRevisionEntity revision = new InventoryRevisionEntity();
        ReflectionTestUtils.setField(revision, "id", id);
        ReflectionTestUtils.setField(revision, "revisionTimestamp", timestamp);
        return revision;
    }
}

package com.pucmm.inventory.security.client;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;

class KeycloakUserTest {
    @Test
    void displayNameCombinesFirstAndLastName() {
        var user = new KeycloakUser("u1", "carlos", "Carlos", "Hernandez", null, true);
        assertThat(user.displayName()).isEqualTo("Carlos Hernandez");
    }

    @Test
    void displayNameFallsBackToUsernameWhenBothNamesNull() {
        var user = new KeycloakUser("u1", "carlos", null, null, null, true);
        assertThat(user.displayName()).isEqualTo("carlos");
    }

    @Test
    void displayNameFallsBackToUsernameWhenBothNamesBlank() {
        var user = new KeycloakUser("u1", "carlos", "  ", "  ", null, true);
        assertThat(user.displayName()).isEqualTo("carlos");
    }

    @Test
    void displayNameHandlesNullFirstName() {
        var user = new KeycloakUser("u1", "carlos", null, "Hernandez", null, true);
        assertThat(user.displayName()).isEqualTo("Hernandez");
    }

    @Test
    void displayNameHandlesNullLastName() {
        var user = new KeycloakUser("u1", "carlos", "Carlos", null, null, true);
        assertThat(user.displayName()).isEqualTo("Carlos");
    }

    @Test
    void isEnabledReturnsTrueWhenEnabledNull() {
        var user = new KeycloakUser("u1", "carlos", null, null, null, null);
        assertThat(user.isEnabled()).isTrue();
    }

    @Test
    void isEnabledReturnsFalseWhenDisabled() {
        var user = new KeycloakUser("u1", "carlos", null, null, null, false);
        assertThat(user.isEnabled()).isFalse();
    }
}

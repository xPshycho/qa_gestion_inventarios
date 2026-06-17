package com.pucmm.inventory.security.client;

public record KeycloakUser(
        String id,
        String username,
        String firstName,
        String lastName,
        String email,
        Boolean enabled
) {
    public boolean isEnabled() {
        return enabled == null || enabled;
    }

    public String displayName() {
        String fullName = ((firstName == null ? "" : firstName) + " " + (lastName == null ? "" : lastName)).trim();
        return fullName.isBlank() ? username : fullName;
    }
}

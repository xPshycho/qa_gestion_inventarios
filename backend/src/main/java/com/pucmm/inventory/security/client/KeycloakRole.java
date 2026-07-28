package com.pucmm.inventory.security.client;

public record KeycloakRole(
        String id,
        String name,
        String description,
        Boolean composite,
        Boolean clientRole,
        String containerId
) {
}

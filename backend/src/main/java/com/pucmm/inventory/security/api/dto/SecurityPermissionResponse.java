package com.pucmm.inventory.security.api.dto;

public record SecurityPermissionResponse(
        String code,
        String module,
        String description
) {
}

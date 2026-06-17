package com.pucmm.inventory.security.api.dto;

import java.util.List;

public record SecurityRoleResponse(
        String code,
        String name,
        String description,
        List<SecurityPermissionResponse> permissions
) {
}

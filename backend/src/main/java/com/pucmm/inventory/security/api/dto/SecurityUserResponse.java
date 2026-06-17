package com.pucmm.inventory.security.api.dto;

import java.util.List;

public record SecurityUserResponse(
        String id,
        String username,
        String displayName,
        String firstName,
        String lastName,
        String email,
        boolean enabled,
        List<String> roleCodes
) {
}

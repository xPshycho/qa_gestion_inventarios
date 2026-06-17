package com.pucmm.inventory.security.repository;

import com.pucmm.inventory.security.api.dto.SecurityPermissionResponse;
import com.pucmm.inventory.security.api.dto.SecurityRoleResponse;
import java.util.ArrayList;
import java.util.List;

record SecurityRoleAccumulator(
        String code,
        String name,
        String description,
        List<SecurityPermissionResponse> permissions
) {
    SecurityRoleAccumulator(String code, String name, String description) {
        this(code, name, description, new ArrayList<>());
    }

    SecurityRoleResponse toResponse() {
        return new SecurityRoleResponse(code, name, description, List.copyOf(permissions));
    }
}

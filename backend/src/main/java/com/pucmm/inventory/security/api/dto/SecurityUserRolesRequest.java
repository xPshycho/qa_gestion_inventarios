package com.pucmm.inventory.security.api.dto;

import jakarta.validation.constraints.NotEmpty;
import java.util.Set;

public record SecurityUserRolesRequest(
        @NotEmpty
        Set<String> roleCodes
) {
}

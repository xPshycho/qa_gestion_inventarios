package com.pucmm.inventory.security.api.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.util.Set;

public record SecurityUserRequest(
        @NotBlank
        @Size(max = 80)
        String username,

        @NotBlank
        @Size(max = 80)
        String firstName,

        @NotBlank
        @Size(max = 80)
        String lastName,

        @Email
        @Size(max = 180)
        String email,

        Boolean enabled,

        Set<String> roleCodes
) {
}

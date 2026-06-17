package com.pucmm.inventory.security.repository;

import static org.assertj.core.api.Assertions.assertThat;

import com.pucmm.inventory.security.api.dto.SecurityPermissionResponse;
import org.junit.jupiter.api.Test;

class SecurityRoleAccumulatorTest {
    @Test
    void toResponseBuildsRoleWithAccumulatedPermissions() {
        var accumulator = new SecurityRoleAccumulator("INVENTORY_ADMIN", "Administrador", "Acceso completo");
        accumulator.permissions().add(new SecurityPermissionResponse("user:manage", "Seguridad", "Gestionar usuarios"));

        var response = accumulator.toResponse();

        assertThat(response.code()).isEqualTo("INVENTORY_ADMIN");
        assertThat(response.name()).isEqualTo("Administrador");
        assertThat(response.permissions()).hasSize(1);
        assertThat(response.permissions().get(0).code()).isEqualTo("user:manage");
    }

    @Test
    void toResponseWithNoPermissionsReturnsEmptyList() {
        var accumulator = new SecurityRoleAccumulator("INVENTORY_ADMIN", "Administrador", "Acceso completo");

        var response = accumulator.toResponse();

        assertThat(response.permissions()).isEmpty();
    }
}

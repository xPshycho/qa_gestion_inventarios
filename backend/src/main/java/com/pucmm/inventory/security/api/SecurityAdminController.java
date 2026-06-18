package com.pucmm.inventory.security.api;

import com.pucmm.inventory.security.api.dto.SecurityPermissionResponse;
import com.pucmm.inventory.security.api.dto.SecurityRoleResponse;
import com.pucmm.inventory.security.api.dto.SecurityUserRequest;
import com.pucmm.inventory.security.api.dto.SecurityUserResponse;
import com.pucmm.inventory.security.api.dto.SecurityUserRolesRequest;
import com.pucmm.inventory.security.service.SecurityAdminService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import java.net.URI;
import java.util.List;
import org.springframework.http.ResponseEntity;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@Validated
@RestController
@RequestMapping("/security")
@Tag(name = "Security administration", description = "Gestion de usuarios, roles y permisos")
public class SecurityAdminController {
    private final SecurityAdminService securityAdminService;

    public SecurityAdminController(SecurityAdminService securityAdminService) {
        this.securityAdminService = securityAdminService;
    }

    @GetMapping("/users")
    @Operation(summary = "Listar usuarios con sus roles funcionales")
    public List<SecurityUserResponse> listUsers() {
        return securityAdminService.listUsers();
    }

    @PostMapping("/users")
    @Operation(summary = "Crear usuario y asignar roles funcionales")
    public ResponseEntity<SecurityUserResponse> createUser(@Valid @RequestBody SecurityUserRequest request) {
        SecurityUserResponse response = securityAdminService.createUser(request);
        return ResponseEntity
                .created(URI.create("/security/users/" + response.id()))
                .body(response);
    }

    @PutMapping("/users/{id}")
    @Operation(summary = "Actualizar datos basicos y estado de un usuario")
    public SecurityUserResponse updateUser(
            @PathVariable String id,
            @Valid @RequestBody SecurityUserRequest request
    ) {
        return securityAdminService.updateUser(id, request);
    }

    @PutMapping("/users/{id}/roles")
    @Operation(summary = "Reemplazar roles funcionales de un usuario")
    public SecurityUserResponse replaceUserRoles(
            @PathVariable String id,
            @Valid @RequestBody SecurityUserRolesRequest request
    ) {
        return securityAdminService.replaceUserRoles(id, request);
    }

    @GetMapping("/roles")
    @Operation(summary = "Listar roles funcionales y permisos incluidos")
    public List<SecurityRoleResponse> listRoles() {
        return securityAdminService.listRoles();
    }

    @GetMapping("/permissions")
    @Operation(summary = "Listar permisos por modulo")
    public List<SecurityPermissionResponse> listPermissions() {
        return securityAdminService.listPermissions();
    }
}

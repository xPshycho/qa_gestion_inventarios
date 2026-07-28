package com.pucmm.inventory.security.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import com.pucmm.inventory.security.api.dto.SecurityPermissionResponse;
import com.pucmm.inventory.security.api.dto.SecurityRoleResponse;
import com.pucmm.inventory.security.api.dto.SecurityUserRequest;
import com.pucmm.inventory.security.api.dto.SecurityUserRolesRequest;
import com.pucmm.inventory.security.client.KeycloakAdminClient;
import com.pucmm.inventory.security.client.KeycloakRole;
import com.pucmm.inventory.security.client.KeycloakUser;
import com.pucmm.inventory.security.repository.SecurityCatalogRepository;
import java.util.List;
import java.util.Set;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class SecurityAdminServiceTest {
    @Mock
    private KeycloakAdminClient keycloakAdminClient;

    @Mock
    private SecurityCatalogRepository securityCatalogRepository;

    @InjectMocks
    private SecurityAdminService securityAdminService;

    @Test
    void listUsersFiltersFunctionalRoles() {
        KeycloakUser user = user();
        when(securityCatalogRepository.findRoleCodes()).thenReturn(Set.of("INVENTORY_ADMIN"));
        when(keycloakAdminClient.listUsers()).thenReturn(List.of(
                user,
                new KeycloakUser(
                        "service-user",
                        "service-account-inventory-admin-service",
                        null,
                        null,
                        null,
                        true
                )
        ));
        when(keycloakAdminClient.listUserRealmRoles("user-1")).thenReturn(List.of(
                role("INVENTORY_ADMIN"),
                role("offline_access")
        ));

        var users = securityAdminService.listUsers();

        assertThat(users).hasSize(1);
        assertThat(users.get(0).roleCodes()).containsExactly("INVENTORY_ADMIN");
    }

    @Test
    void createUserAssignsRolesAndSynchronizesLocalCatalog() {
        SecurityUserRequest request = request(Set.of("INVENTORY_ADMIN"));
        KeycloakRole role = role("INVENTORY_ADMIN");
        KeycloakUser user = user();
        when(securityCatalogRepository.findRoleCodes()).thenReturn(Set.of("INVENTORY_ADMIN"));
        when(keycloakAdminClient.getRealmRole("INVENTORY_ADMIN")).thenReturn(role);
        when(keycloakAdminClient.createUser(request)).thenReturn(user);
        when(keycloakAdminClient.listUserRealmRoles("user-1")).thenReturn(List.of());

        var response = securityAdminService.createUser(request);

        assertThat(response.username()).isEqualTo("carlos");
        assertThat(response.roleCodes()).containsExactly("INVENTORY_ADMIN");
        verify(keycloakAdminClient).replaceUserRealmRoles("user-1", List.of(), List.of(role));
        verify(securityCatalogRepository).syncUser(user, List.of("INVENTORY_ADMIN"));
    }

    @Test
    void createUserWithNullRolesAssignsNoRoles() {
        SecurityUserRequest request = new SecurityUserRequest("carlos", "Carlos", "Hernandez", null, true, null);
        KeycloakUser user = user();
        when(securityCatalogRepository.findRoleCodes()).thenReturn(Set.of("INVENTORY_ADMIN"));
        when(keycloakAdminClient.createUser(request)).thenReturn(user);
        when(keycloakAdminClient.listUserRealmRoles("user-1")).thenReturn(List.of());

        var response = securityAdminService.createUser(request);

        assertThat(response.roleCodes()).isEmpty();
        verify(keycloakAdminClient).replaceUserRealmRoles("user-1", List.of(), List.of());
        verify(securityCatalogRepository).syncUser(user, List.of());
    }

    @Test
    void updateUserUpdatesDataAndReturnsFunctionalRoles() {
        SecurityUserRequest request = request(Set.of());
        KeycloakUser user = user();
        when(keycloakAdminClient.updateUser("user-1", request)).thenReturn(user);
        when(securityCatalogRepository.findRoleCodes()).thenReturn(Set.of("INVENTORY_ADMIN"));
        when(keycloakAdminClient.listUserRealmRoles("user-1")).thenReturn(List.of(role("INVENTORY_ADMIN")));

        var response = securityAdminService.updateUser("user-1", request);

        assertThat(response.username()).isEqualTo("carlos");
        assertThat(response.roleCodes()).containsExactly("INVENTORY_ADMIN");
        verify(securityCatalogRepository).syncUser(user, List.of("INVENTORY_ADMIN"));
    }

    @Test
    void replaceUserRolesAssignsRolesAndSynchronizesLocalCatalog() {
        SecurityUserRolesRequest request = new SecurityUserRolesRequest(Set.of("INVENTORY_ADMIN"));
        KeycloakRole role = role("INVENTORY_ADMIN");
        KeycloakUser user = user();
        when(securityCatalogRepository.findRoleCodes()).thenReturn(Set.of("INVENTORY_ADMIN"));
        when(keycloakAdminClient.getRealmRole("INVENTORY_ADMIN")).thenReturn(role);
        when(keycloakAdminClient.listUserRealmRoles("user-1")).thenReturn(List.of());
        when(keycloakAdminClient.getUser("user-1")).thenReturn(user);

        var response = securityAdminService.replaceUserRoles("user-1", request);

        assertThat(response.roleCodes()).containsExactly("INVENTORY_ADMIN");
        verify(keycloakAdminClient).replaceUserRealmRoles("user-1", List.of(), List.of(role));
        verify(securityCatalogRepository).syncUser(user, List.of("INVENTORY_ADMIN"));
    }

    @Test
    void replaceUserRolesRejectsUnknownFunctionalRole() {
        when(securityCatalogRepository.findRoleCodes()).thenReturn(Set.of("INVENTORY_ADMIN"));
        SecurityUserRolesRequest request = new SecurityUserRolesRequest(Set.of("SUPER_ADMIN"));

        assertThatThrownBy(() -> securityAdminService.replaceUserRoles("user-1", request))
                .isInstanceOf(InvalidSecurityRoleException.class)
                .hasMessageContaining("SUPER_ADMIN");

        verifyNoInteractions(keycloakAdminClient);
    }

    @Test
    void listRolesDelegatesToRepository() {
        var roleResponse = new SecurityRoleResponse("INVENTORY_ADMIN", "Administrador", "Acceso completo", List.of());
        when(securityCatalogRepository.findRoles()).thenReturn(List.of(roleResponse));

        var roles = securityAdminService.listRoles();

        assertThat(roles).containsExactly(roleResponse);
    }

    @Test
    void listPermissionsDelegatesToRepository() {
        var permission = new SecurityPermissionResponse("user:manage", "Seguridad", "Gestionar usuarios");
        when(securityCatalogRepository.findPermissions()).thenReturn(List.of(permission));

        var permissions = securityAdminService.listPermissions();

        assertThat(permissions).containsExactly(permission);
    }

    private SecurityUserRequest request(Set<String> roles) {
        return new SecurityUserRequest(
                "carlos",
                "Carlos",
                "Hernandez",
                "carlos@example.local",
                true,
                roles
        );
    }

    private KeycloakUser user() {
        return new KeycloakUser(
                "user-1",
                "carlos",
                "Carlos",
                "Hernandez",
                "carlos@example.local",
                true
        );
    }

    private KeycloakRole role(String name) {
        return new KeycloakRole("role-" + name, name, name, true, false, "inventory");
    }
}

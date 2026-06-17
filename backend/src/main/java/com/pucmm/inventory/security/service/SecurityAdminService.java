package com.pucmm.inventory.security.service;

import com.pucmm.inventory.security.api.dto.SecurityPermissionResponse;
import com.pucmm.inventory.security.api.dto.SecurityRoleResponse;
import com.pucmm.inventory.security.api.dto.SecurityUserRequest;
import com.pucmm.inventory.security.api.dto.SecurityUserResponse;
import com.pucmm.inventory.security.api.dto.SecurityUserRolesRequest;
import com.pucmm.inventory.security.client.KeycloakAdminClient;
import com.pucmm.inventory.security.client.KeycloakRole;
import com.pucmm.inventory.security.client.KeycloakUser;
import com.pucmm.inventory.security.repository.SecurityCatalogRepository;
import java.util.Comparator;
import java.util.List;
import java.util.Objects;
import java.util.Set;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@Transactional(readOnly = true)
public class SecurityAdminService {
    private final KeycloakAdminClient keycloakAdminClient;
    private final SecurityCatalogRepository securityCatalogRepository;

    public SecurityAdminService(
            KeycloakAdminClient keycloakAdminClient,
            SecurityCatalogRepository securityCatalogRepository
    ) {
        this.keycloakAdminClient = keycloakAdminClient;
        this.securityCatalogRepository = securityCatalogRepository;
    }

    public List<SecurityUserResponse> listUsers() {
        Set<String> allowedRoles = securityCatalogRepository.findRoleCodes();
        return keycloakAdminClient.listUsers().stream()
                .filter(user -> !user.username().startsWith("service-account-"))
                .map(user -> {
                    List<String> roleCodes = findFunctionalRoleCodes(user.id(), allowedRoles);
                    return toResponse(user, roleCodes);
                })
                .sorted(Comparator.comparing(SecurityUserResponse::username, String.CASE_INSENSITIVE_ORDER))
                .toList();
    }

    @Transactional
    public SecurityUserResponse createUser(SecurityUserRequest request) {
        List<KeycloakRole> roles = validateAndLoadRoles(request.roleCodes());
        KeycloakUser user = keycloakAdminClient.createUser(request);
        replaceRoles(user.id(), roles);
        securityCatalogRepository.syncUser(user, roleNames(roles));
        return toResponse(user, roleNames(roles));
    }

    @Transactional
    public SecurityUserResponse updateUser(String userId, SecurityUserRequest request) {
        KeycloakUser user = keycloakAdminClient.updateUser(userId, request);
        Set<String> allowedRoles = securityCatalogRepository.findRoleCodes();
        List<String> roleCodes = findFunctionalRoleCodes(user.id(), allowedRoles);
        securityCatalogRepository.syncUser(user, roleCodes);
        return toResponse(user, roleCodes);
    }

    @Transactional
    public SecurityUserResponse replaceUserRoles(String userId, SecurityUserRolesRequest request) {
        List<KeycloakRole> roles = validateAndLoadRoles(request.roleCodes());
        replaceRoles(userId, roles);
        KeycloakUser user = keycloakAdminClient.getUser(userId);
        securityCatalogRepository.syncUser(user, roleNames(roles));
        return toResponse(user, roleNames(roles));
    }

    public List<SecurityRoleResponse> listRoles() {
        return securityCatalogRepository.findRoles();
    }

    public List<SecurityPermissionResponse> listPermissions() {
        return securityCatalogRepository.findPermissions();
    }

    private void replaceRoles(String userId, List<KeycloakRole> targetRoles) {
        Set<String> allowedRoles = securityCatalogRepository.findRoleCodes();
        List<KeycloakRole> currentRoles = keycloakAdminClient.listUserRealmRoles(userId).stream()
                .filter(role -> allowedRoles.contains(role.name()))
                .toList();
        keycloakAdminClient.replaceUserRealmRoles(userId, currentRoles, targetRoles);
    }

    private List<KeycloakRole> validateAndLoadRoles(Set<String> roleCodes) {
        Set<String> allowedRoles = securityCatalogRepository.findRoleCodes();
        Set<String> requestedRoles = roleCodes == null ? Set.of() : roleCodes;
        return requestedRoles.stream()
                .filter(Objects::nonNull)
                .map(String::trim)
                .peek(roleCode -> {
                    if (!allowedRoles.contains(roleCode)) {
                        throw new InvalidSecurityRoleException(roleCode);
                    }
                })
                .distinct()
                .sorted()
                .map(keycloakAdminClient::getRealmRole)
                .toList();
    }

    private List<String> findFunctionalRoleCodes(String userId, Set<String> allowedRoles) {
        return keycloakAdminClient.listUserRealmRoles(userId).stream()
                .map(KeycloakRole::name)
                .filter(allowedRoles::contains)
                .sorted()
                .toList();
    }

    private List<String> roleNames(List<KeycloakRole> roles) {
        return roles.stream()
                .map(KeycloakRole::name)
                .sorted()
                .toList();
    }

    private SecurityUserResponse toResponse(KeycloakUser user, List<String> roleCodes) {
        return new SecurityUserResponse(
                user.id(),
                user.username(),
                user.displayName(),
                user.firstName(),
                user.lastName(),
                user.email(),
                user.isEnabled(),
                roleCodes
        );
    }
}

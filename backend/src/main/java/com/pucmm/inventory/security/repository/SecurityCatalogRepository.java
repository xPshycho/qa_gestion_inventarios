package com.pucmm.inventory.security.repository;

import com.pucmm.inventory.security.api.dto.SecurityPermissionResponse;
import com.pucmm.inventory.security.api.dto.SecurityRoleResponse;
import com.pucmm.inventory.security.client.KeycloakUser;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class SecurityCatalogRepository {
    private final JdbcTemplate jdbcTemplate;

    public SecurityCatalogRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public List<SecurityPermissionResponse> findPermissions() {
        return jdbcTemplate.query(
                """
                SELECT code, module, description
                FROM permissions
                ORDER BY module, code
                """,
                (rs, rowNum) -> new SecurityPermissionResponse(
                        rs.getString("code"),
                        rs.getString("module"),
                        rs.getString("description")
                )
        );
    }

    public List<SecurityRoleResponse> findRoles() {
        Map<String, SecurityRoleAccumulator> roles = new LinkedHashMap<>();
        jdbcTemplate.query(
                """
                SELECT r.code role_code, r.name role_name, r.description role_description,
                       p.code permission_code, p.module permission_module, p.description permission_description
                FROM roles r
                LEFT JOIN role_permissions rp ON rp.role_id = r.id
                LEFT JOIN permissions p ON p.id = rp.permission_id
                ORDER BY r.code, p.module, p.code
                """,
                rs -> {
                    String roleCode = rs.getString("role_code");
                    String roleName = rs.getString("role_name");
                    String roleDescription = rs.getString("role_description");
                    SecurityRoleAccumulator role = roles.computeIfAbsent(
                            roleCode,
                            ignored -> new SecurityRoleAccumulator(roleCode, roleName, roleDescription)
                    );
                    String permissionCode = rs.getString("permission_code");
                    if (permissionCode != null) {
                        role.permissions().add(new SecurityPermissionResponse(
                                permissionCode,
                                rs.getString("permission_module"),
                                rs.getString("permission_description")
                        ));
                    }
                }
        );

        return roles.values().stream()
                .map(SecurityRoleAccumulator::toResponse)
                .toList();
    }

    public Set<String> findRoleCodes() {
        return Set.copyOf(jdbcTemplate.queryForList("SELECT code FROM roles", String.class));
    }

    public void syncUser(KeycloakUser user, List<String> roleCodes) {
        jdbcTemplate.update(
                """
                INSERT INTO inventory_users (external_id, username, display_name, email, status)
                VALUES (?, ?, ?, ?, ?)
                ON CONFLICT (external_id)
                DO UPDATE SET username = EXCLUDED.username,
                              display_name = EXCLUDED.display_name,
                              email = EXCLUDED.email,
                              status = EXCLUDED.status
                """,
                user.id(),
                user.username(),
                user.displayName(),
                user.email(),
                user.isEnabled() ? "ACTIVE" : "INACTIVE"
        );

        Long userId = jdbcTemplate.queryForObject(
                "SELECT id FROM inventory_users WHERE external_id = ?",
                Long.class,
                user.id()
        );
        replaceLocalUserRoles(userId, roleCodes);
    }

    private void replaceLocalUserRoles(Long userId, List<String> roleCodes) {
        jdbcTemplate.update("DELETE FROM user_roles WHERE user_id = ?", userId);
        for (String roleCode : roleCodes) {
            jdbcTemplate.update(
                    """
                    INSERT INTO user_roles (user_id, role_id)
                    SELECT ?, id
                    FROM roles
                    WHERE code = ?
                    """,
                    userId,
                    roleCode
            );
        }
    }
}

package com.pucmm.inventory.integration;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.jdbc.core.JdbcTemplate;

@SpringBootTest
class DataIntegrityIntegrationTest extends PostgreSqlIntegrationTest {
    private static final int EXPECTED_PERMISSION_COUNT = 7;
    private static final int EXPECTED_ROLE_COUNT = 4;
    private static final int EXPECTED_SEED_USER_COUNT = 4;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Test
    void referenceSeedsHaveExpectedRelationships() {
        Integer seededPermissions = jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM permissions",
                Integer.class
        );
        Integer seededRoles = jdbcTemplate.queryForObject("SELECT COUNT(*) FROM roles", Integer.class);
        Integer seededUsers = jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM inventory_users WHERE username IN ('carlos', 'edwin', 'viewer', 'auditor')",
                Integer.class
        );
        Integer rolesWithoutPermissions = jdbcTemplate.queryForObject(
                """
                SELECT COUNT(*)
                FROM roles role
                WHERE NOT EXISTS (
                  SELECT 1 FROM role_permissions role_permission
                  WHERE role_permission.role_id = role.id
                )
                """,
                Integer.class
        );
        Integer seedUsersWithoutRoles = jdbcTemplate.queryForObject(
                """
                SELECT COUNT(*)
                FROM inventory_users inventory_user
                WHERE inventory_user.username IN ('carlos', 'edwin', 'viewer', 'auditor')
                  AND NOT EXISTS (
                    SELECT 1 FROM user_roles user_role
                    WHERE user_role.user_id = inventory_user.id
                  )
                """,
                Integer.class
        );

        assertThat(seededPermissions).isEqualTo(EXPECTED_PERMISSION_COUNT);
        assertThat(seededRoles).isEqualTo(EXPECTED_ROLE_COUNT);
        assertThat(seededUsers).isEqualTo(EXPECTED_SEED_USER_COUNT);
        assertThat(rolesWithoutPermissions).isZero();
        assertThat(seedUsersWithoutRoles).isZero();
    }

    @Test
    void seededInitialStockHasMatchingInitialMovements() {
        Integer productsWithoutInitialMovement = jdbcTemplate.queryForObject(
                """
                SELECT COUNT(*)
                FROM products product
                WHERE product.sku IN ('DELL-LAT-5440', 'LEN-T14-G4', 'HP-EB840-G10', 'APP-MBA13-M2')
                  AND product.current_stock > 0
                  AND NOT EXISTS (
                    SELECT 1 FROM stock_movements movement
                    WHERE movement.product_id = product.id
                      AND movement.movement_type = 'INITIAL'
                      AND movement.previous_quantity = 0
                      AND movement.new_quantity = product.current_stock
                  )
                """,
                Integer.class
        );

        assertThat(productsWithoutInitialMovement).isZero();
    }

    @Test
    void databaseConstraintsRejectInconsistentOrInvalidInventoryData() {
        String sku = "DATA-QUALITY-" + UUID.randomUUID();
        jdbcTemplate.update(
                """
                INSERT INTO products (sku, name, category, price, current_stock, minimum_stock, status)
                VALUES (?, 'Producto de calidad', 'Testing', 10.00, 1, 0, 'ACTIVE')
                """,
                sku
        );

        try {
            assertThatThrownBy(() -> jdbcTemplate.update(
                    """
                    INSERT INTO products (sku, name, category, price, current_stock, minimum_stock, status)
                    VALUES (?, 'SKU duplicado', 'Testing', 10.00, 1, 0, 'ACTIVE')
                    """,
                    sku
            )).isInstanceOf(DataIntegrityViolationException.class);

            assertThatThrownBy(() -> jdbcTemplate.update(
                    """
                    INSERT INTO products (sku, name, category, price, current_stock, minimum_stock, status)
                    VALUES (?, 'Stock negativo', 'Testing', 10.00, -1, 0, 'ACTIVE')
                    """,
                    "NEGATIVE-STOCK-" + UUID.randomUUID()
            )).isInstanceOf(DataIntegrityViolationException.class);

            assertThatThrownBy(() -> jdbcTemplate.update(
                    """
                    INSERT INTO stock_movements (
                      product_id, movement_type, previous_quantity, new_quantity, delta_quantity
                    ) VALUES (999999999, 'ENTRY', 0, 1, 1)
                    """
            )).isInstanceOf(DataIntegrityViolationException.class);

            Long productId = jdbcTemplate.queryForObject(
                    "SELECT id FROM products WHERE sku = ?",
                    Long.class,
                    sku
            );
            assertThat(productId).isNotNull();

            assertThatThrownBy(() -> jdbcTemplate.update(
                    """
                    INSERT INTO stock_movements (
                      product_id, movement_type, previous_quantity, new_quantity, delta_quantity
                    ) VALUES (?, 'ENTRY', 1, 3, 1)
                    """,
                    productId
            )).isInstanceOf(DataIntegrityViolationException.class);
        } finally {
            jdbcTemplate.update("DELETE FROM products WHERE sku = ?", sku);
        }
    }
}

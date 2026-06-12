package com.pucmm.inventory.integration;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;

@SpringBootTest
class FlywayMigrationIntegrationTest extends PostgreSqlIntegrationTest {
    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Test
    void flywayAppliesMigrationsAndInitialSeeds() {
        Integer appliedMigrations = jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM flyway_schema_history WHERE success",
                Integer.class
        );
        Integer seededProducts = jdbcTemplate.queryForObject(
                """
                SELECT COUNT(*)
                FROM products
                WHERE sku IN ('DELL-LAT-5440', 'LEN-T14-G4', 'HP-EB840-G10', 'APP-MBA13-M2')
                """,
                Integer.class
        );
        Integer seededPermissions = jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM permissions",
                Integer.class
        );

        assertThat(appliedMigrations).isEqualTo(5);
        assertThat(seededProducts).isEqualTo(4);
        assertThat(seededPermissions).isEqualTo(7);
    }
}

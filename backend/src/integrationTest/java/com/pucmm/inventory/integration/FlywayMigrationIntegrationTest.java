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
        Integer seededBaseProducts = jdbcTemplate.queryForObject(
                """
                SELECT COUNT(*)
                FROM products
                WHERE sku IN ('DELL-LAT-5440', 'LEN-T14-G4', 'HP-EB840-G10', 'APP-MBA13-M2')
                """,
                Integer.class
        );
        Integer seededDemoProducts = jdbcTemplate.queryForObject(
                """
                SELECT COUNT(*)
                FROM products
                WHERE sku IN (
                  'MON-DELL-P2422H',
                  'MON-LG-27QN600',
                  'MON-SAM-ODYSSEY-G5',
                  'MOU-LOGI-MX-MASTER-3S',
                  'KEY-LOGI-MX-KEYS',
                  'HEAD-JABRA-EVOLVE2-65',
                  'DOCK-DELL-WD19S',
                  'ADP-LEN-USB-C-65W',
                  'CAB-HDMI-2M',
                  'SSD-SAM-980-1TB',
                  'SSD-KING-NV2-500',
                  'HDD-WD-BLUE-2TB',
                  'RAM-KING-16GB-DDR4',
                  'RAM-CRUCIAL-32GB-DDR5',
                  'SW-UBI-USW-LITE-8',
                  'RTR-MKT-HAP-AX2',
                  'AP-UBI-U6-LITE',
                  'UPS-APC-BV650',
                  'UPS-CDP-RUPR758',
                  'PRN-HP-LJ-M404',
                  'TON-HP-58A',
                  'PAPER-A4-500',
                  'CAM-LOGI-C920',
                  'TAB-SAM-A8'
                )
                """,
                Integer.class
        );
        Integer demoMovements = jdbcTemplate.queryForObject(
                """
                SELECT COUNT(*)
                FROM stock_movements m
                JOIN products p ON p.id = m.product_id
                WHERE p.sku IN (
                  'MON-DELL-P2422H',
                  'MON-LG-27QN600',
                  'MON-SAM-ODYSSEY-G5',
                  'MOU-LOGI-MX-MASTER-3S',
                  'KEY-LOGI-MX-KEYS',
                  'HEAD-JABRA-EVOLVE2-65',
                  'DOCK-DELL-WD19S',
                  'ADP-LEN-USB-C-65W',
                  'CAB-HDMI-2M',
                  'SSD-SAM-980-1TB',
                  'SSD-KING-NV2-500',
                  'HDD-WD-BLUE-2TB',
                  'RAM-KING-16GB-DDR4',
                  'RAM-CRUCIAL-32GB-DDR5',
                  'SW-UBI-USW-LITE-8',
                  'RTR-MKT-HAP-AX2',
                  'AP-UBI-U6-LITE',
                  'UPS-APC-BV650',
                  'UPS-CDP-RUPR758',
                  'PRN-HP-LJ-M404',
                  'TON-HP-58A',
                  'PAPER-A4-500',
                  'CAM-LOGI-C920',
                  'TAB-SAM-A8'
                )
                """,
                Integer.class
        );
        Integer demoUsers = jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM inventory_users WHERE username IN ('carlos', 'edwin', 'viewer', 'auditor')",
                Integer.class
        );
        Integer seededPermissions = jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM permissions",
                Integer.class
        );

        assertThat(appliedMigrations).isEqualTo(7);
        assertThat(seededBaseProducts).isEqualTo(4);
        assertThat(seededDemoProducts).isEqualTo(24);
        assertThat(demoMovements).isGreaterThanOrEqualTo(45);
        assertThat(demoUsers).isEqualTo(4);
        assertThat(seededPermissions).isEqualTo(7);
    }
}

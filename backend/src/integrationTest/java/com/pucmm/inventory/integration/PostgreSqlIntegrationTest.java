package com.pucmm.inventory.integration;

import java.util.UUID;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.testcontainers.containers.PostgreSQLContainer;

public abstract class PostgreSqlIntegrationTest {
    protected static final String SYNTHETIC_KEYCLOAK_CLIENT_SECRET =
            UUID.randomUUID().toString();
    private static final String SYNTHETIC_DATABASE_PASSWORD = UUID.randomUUID().toString();
    private static final PostgreSQLContainer<?> POSTGRES = new PostgreSQLContainer<>("postgres:16-alpine")
            .withDatabaseName("inventory_integration")
            .withUsername("inventory_test")
            .withPassword(SYNTHETIC_DATABASE_PASSWORD);

    static {
        POSTGRES.start();
    }

    @DynamicPropertySource
    static void configurePostgreSql(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", POSTGRES::getJdbcUrl);
        registry.add("spring.datasource.username", POSTGRES::getUsername);
        registry.add("spring.datasource.password", POSTGRES::getPassword);
        registry.add(
                "inventory.keycloak.admin-client-secret",
                () -> SYNTHETIC_KEYCLOAK_CLIENT_SECRET);
    }
}

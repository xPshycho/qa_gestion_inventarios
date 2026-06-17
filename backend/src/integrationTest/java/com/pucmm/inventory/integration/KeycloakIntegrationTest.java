package com.pucmm.inventory.integration;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.net.URI;
import java.net.URLEncoder;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.MediaType;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.testcontainers.containers.GenericContainer;
import org.testcontainers.containers.output.Slf4jLogConsumer;
import org.testcontainers.containers.wait.strategy.Wait;
import org.testcontainers.utility.DockerImageName;
import org.testcontainers.utility.MountableFile;

public abstract class KeycloakIntegrationTest extends PostgreSqlIntegrationTest {
    private static final String REALM = "inventory";
    private static final String ADMIN_CLIENT_ID = "inventory-admin-service";
    private static final String ADMIN_CLIENT_SECRET = "cambiar-admin-service";
    private static final Logger KEYCLOAK_LOGGER = LoggerFactory.getLogger("testcontainers.keycloak");
    private static final ObjectMapper OBJECT_MAPPER = new ObjectMapper();
    private static final HttpClient HTTP_CLIENT = HttpClient.newHttpClient();
    private static final GenericContainer<?> KEYCLOAK =
            new GenericContainer<>(DockerImageName.parse("quay.io/keycloak/keycloak:26.6.3"))
                    .withEnv("KC_BOOTSTRAP_ADMIN_USERNAME", "integration-admin")
                    .withEnv("KC_BOOTSTRAP_ADMIN_PASSWORD", "integration-password")
                    .withCopyFileToContainer(
                            MountableFile.forClasspathResource("inventory-realm.json"),
                            "/opt/keycloak/data/import/inventory-realm.json"
                    )
                    .withCommand("start-dev", "--import-realm")
                    .withExposedPorts(8080)
                    .withLogConsumer(new Slf4jLogConsumer(KEYCLOAK_LOGGER))
                    .waitingFor(Wait.forHttp("/realms/inventory/.well-known/openid-configuration")
                            .forStatusCode(200)
                            .withStartupTimeout(Duration.ofMinutes(4)));

    static {
        KEYCLOAK.start();
    }

    @DynamicPropertySource
    static void configureKeycloak(DynamicPropertyRegistry registry) {
        registry.add(
                "spring.security.oauth2.resourceserver.jwt.issuer-uri",
                () -> keycloakUrl() + "/realms/" + REALM
        );
        registry.add(
                "spring.security.oauth2.resourceserver.jwt.jwk-set-uri",
                () -> keycloakUrl() + "/realms/" + REALM + "/protocol/openid-connect/certs"
        );
        registry.add("inventory.keycloak.admin-url", KeycloakIntegrationTest::keycloakUrl);
        registry.add("inventory.keycloak.admin-realm", () -> REALM);
        registry.add("inventory.keycloak.admin-client-id", () -> ADMIN_CLIENT_ID);
        registry.add("inventory.keycloak.admin-client-secret", () -> ADMIN_CLIENT_SECRET);
    }

    protected static String keycloakUrl() {
        return "http://" + KEYCLOAK.getHost() + ":" + KEYCLOAK.getMappedPort(8080);
    }

    protected static String accessToken(String username, String password) throws Exception {
        String requestBody = formParameter("grant_type", "password")
                + "&" + formParameter("client_id", "inventory-frontend")
                + "&" + formParameter("username", username)
                + "&" + formParameter("password", password);
        HttpRequest request = HttpRequest.newBuilder()
                .uri(URI.create(keycloakUrl() + "/realms/" + REALM + "/protocol/openid-connect/token"))
                .header("Content-Type", MediaType.APPLICATION_FORM_URLENCODED_VALUE)
                .POST(HttpRequest.BodyPublishers.ofString(requestBody))
                .build();

        HttpResponse<String> response = HTTP_CLIENT.send(request, HttpResponse.BodyHandlers.ofString());
        if (response.statusCode() != 200) {
            throw new IllegalStateException("Keycloak token request failed with status " + response.statusCode());
        }

        JsonNode payload = OBJECT_MAPPER.readTree(response.body());
        return payload.path("access_token").asText();
    }

    protected static String adminServiceAccessToken() throws Exception {
        String requestBody = formParameter("grant_type", "client_credentials")
                + "&" + formParameter("client_id", ADMIN_CLIENT_ID)
                + "&" + formParameter("client_secret", ADMIN_CLIENT_SECRET);
        HttpRequest request = HttpRequest.newBuilder()
                .uri(URI.create(keycloakUrl() + "/realms/" + REALM + "/protocol/openid-connect/token"))
                .header("Content-Type", MediaType.APPLICATION_FORM_URLENCODED_VALUE)
                .POST(HttpRequest.BodyPublishers.ofString(requestBody))
                .build();

        HttpResponse<String> response = HTTP_CLIENT.send(request, HttpResponse.BodyHandlers.ofString());
        if (response.statusCode() != 200) {
            throw new IllegalStateException(
                    "Keycloak admin-service token request failed with status " + response.statusCode()
            );
        }

        JsonNode payload = OBJECT_MAPPER.readTree(response.body());
        return payload.path("access_token").asText();
    }

    private static String formParameter(String name, String value) {
        return URLEncoder.encode(name, StandardCharsets.UTF_8)
                + "="
                + URLEncoder.encode(value, StandardCharsets.UTF_8);
    }
}

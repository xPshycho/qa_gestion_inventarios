package com.pucmm.inventory.config;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.pucmm.inventory.integration.KeycloakIntegrationTest;
import com.pucmm.inventory.product.api.dto.ProductRequest;
import com.pucmm.inventory.product.domain.ProductStatus;
import java.math.BigDecimal;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

@SpringBootTest
@AutoConfigureMockMvc
class KeycloakSecurityIntegrationTest extends KeycloakIntegrationTest {
    private static final HttpClient HTTP_CLIENT = HttpClient.newHttpClient();

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Test
    void keycloakImportsInventoryRealmAndPublishesOidcConfiguration() throws Exception {
        HttpRequest request = HttpRequest.newBuilder()
                .uri(URI.create(keycloakUrl() + "/realms/inventory/.well-known/openid-configuration"))
                .GET()
                .build();

        HttpResponse<String> response = HTTP_CLIENT.send(request, HttpResponse.BodyHandlers.ofString());
        JsonNode configuration = objectMapper.readTree(response.body());

        org.assertj.core.api.Assertions.assertThat(response.statusCode()).isEqualTo(200);
        org.assertj.core.api.Assertions.assertThat(configuration.path("issuer").asText())
                .isEqualTo(keycloakUrl() + "/realms/inventory");
        org.assertj.core.api.Assertions.assertThat(configuration.path("jwks_uri").asText())
                .isEqualTo(keycloakUrl() + "/realms/inventory/protocol/openid-connect/certs");
    }

    @Test
    void adminServiceClientCanListUsersThroughKeycloakAdminApi() throws Exception {
        String token = adminServiceAccessToken();
        HttpRequest request = HttpRequest.newBuilder()
                .uri(URI.create(keycloakUrl() + "/admin/realms/inventory/users?briefRepresentation=true"))
                .header(HttpHeaders.AUTHORIZATION, bearer(token))
                .GET()
                .build();

        HttpResponse<String> response = HTTP_CLIENT.send(request, HttpResponse.BodyHandlers.ofString());

        org.assertj.core.api.Assertions.assertThat(response.statusCode()).isEqualTo(200);
        org.assertj.core.api.Assertions.assertThat(objectMapper.readTree(response.body()).isArray()).isTrue();
    }

    @Test
    void administratorTokenAllowsCreatingProducts() throws Exception {
        String token = accessToken("carlos", "admin123");

        mockMvc.perform(post("/products")
                        .header(HttpHeaders.AUTHORIZATION, bearer(token))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(productRequest("INT-KEYCLOAK-ADMIN-001"))))
                .andExpect(status().isCreated())
                .andExpect(header().string(HttpHeaders.LOCATION, org.hamcrest.Matchers.startsWith("/products/")))
                .andExpect(jsonPath("$.sku").value("INT-KEYCLOAK-ADMIN-001"));
    }

    @Test
    void viewerTokenAllowsReadingProducts() throws Exception {
        String token = accessToken("viewer", "admin123");

        mockMvc.perform(get("/products")
                        .header(HttpHeaders.AUTHORIZATION, bearer(token)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content").isArray());
    }

    @Test
    void viewerTokenCannotCreateProducts() throws Exception {
        String token = accessToken("viewer", "admin123");

        mockMvc.perform(post("/products")
                        .header(HttpHeaders.AUTHORIZATION, bearer(token))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(productRequest("INT-KEYCLOAK-VIEWER-001"))))
                .andExpect(status().isForbidden());
    }

    @Test
    void requestWithoutTokenIsUnauthorized() throws Exception {
        mockMvc.perform(get("/products"))
                .andExpect(status().isUnauthorized());
    }

    private ProductRequest productRequest(String sku) {
        return new ProductRequest(
                sku,
                "Producto protegido por Keycloak",
                "Producto creado por pruebas de integracion",
                "Seguridad",
                new BigDecimal("3500.00"),
                5,
                2,
                ProductStatus.ACTIVE
        );
    }

    private String bearer(String token) {
        return "Bearer " + token;
    }
}

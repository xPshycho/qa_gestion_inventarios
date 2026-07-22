package com.pucmm.inventory.config;

import static com.pucmm.inventory.config.SecurityConfig.PRODUCT_VIEW;
import static com.pucmm.inventory.config.SecurityConfig.PRODUCT_MANAGE;
import static com.pucmm.inventory.config.SecurityConfig.REPORT_VIEW;
import static org.hamcrest.Matchers.containsString;
import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.options;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.pucmm.inventory.common.api.GlobalExceptionHandler;
import com.pucmm.inventory.product.api.ProductController;
import com.pucmm.inventory.product.api.dto.ProductRequest;
import com.pucmm.inventory.product.api.dto.ProductResponse;
import com.pucmm.inventory.product.domain.ProductStatus;
import com.pucmm.inventory.product.service.ProductService;
import com.pucmm.inventory.stock.service.AuthenticatedInventoryUserResolver;
import com.pucmm.inventory.stock.service.StockService;
import java.math.BigDecimal;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationConverter;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

@WebMvcTest(ProductController.class)
@Import({GlobalExceptionHandler.class, SecurityConfig.class})
class SecurityConfigTest {
    private static final OffsetDateTime TIMESTAMP = OffsetDateTime.parse("2026-06-07T12:00:00-04:00");

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private JwtAuthenticationConverter jwtAuthenticationConverter;

    @Autowired
    private ObjectMapper objectMapper;

    @MockitoBean
    private ProductService productService;

    @MockitoBean
    private StockService stockService;

    @MockitoBean
    private AuthenticatedInventoryUserResolver authenticatedInventoryUserResolver;

    @Test
    void requestWithoutJwtReturnsUnauthorized() throws Exception {
        mockMvc.perform(get("/products/{id}", 1L))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void prometheusEndpointDoesNotRequireJwt() throws Exception {
        mockMvc.perform(get("/actuator/prometheus"))
                .andExpect(status().isNotFound());
    }

    @Test
    void jwtWithoutRequiredPermissionReturnsForbidden() throws Exception {
        mockMvc.perform(get("/products/{id}", 1L)
                        .with(jwt().authorities(new SimpleGrantedAuthority(REPORT_VIEW))))
                .andExpect(status().isForbidden());
    }

    @Test
    void jwtWithRequiredPermissionAllowsRequest() throws Exception {
        when(productService.getProduct(1L)).thenReturn(response());

        mockMvc.perform(get("/products/{id}", 1L)
                        .with(jwt().authorities(new SimpleGrantedAuthority(PRODUCT_VIEW))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.sku").value("DELL-LAT-5440"));
    }

    @Test
    void mutatingRequestWithJwtDoesNotRequireCsrfToken() throws Exception {
        ProductRequest request = request();
        when(productService.createProduct(request)).thenReturn(response());

        mockMvc.perform(post("/products")
                        .with(jwt().authorities(new SimpleGrantedAuthority(PRODUCT_MANAGE)))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isCreated())
                .andExpect(header().string("Location", "/products/1"));
    }

    @Test
    void preflightFromAllowedOriginReturnsCorsHeaders() throws Exception {
        mockMvc.perform(options("/products")
                        .header("Origin", "http://localhost:5173")
                        .header("Access-Control-Request-Method", "POST")
                        .header("Access-Control-Request-Headers", "Authorization,Content-Type"))
                .andExpect(status().isOk())
                .andExpect(header().string("Access-Control-Allow-Origin", "http://localhost:5173"))
                .andExpect(header().string("Access-Control-Allow-Methods", containsString("POST")))
                .andExpect(header().string("Access-Control-Allow-Headers", containsString("Authorization")));
    }

    @Test
    void preflightFromUnexpectedOriginIsRejected() throws Exception {
        mockMvc.perform(options("/products")
                        .header("Origin", "https://untrusted.example")
                        .header("Access-Control-Request-Method", "POST"))
                .andExpect(status().isForbidden())
                .andExpect(header().doesNotExist("Access-Control-Allow-Origin"));
    }

    @Test
    void allowedOriginStillRequiresJwt() throws Exception {
        mockMvc.perform(get("/products/{id}", 1L)
                        .header("Origin", "http://127.0.0.1:5173"))
                .andExpect(status().isUnauthorized())
                .andExpect(header().string("Access-Control-Allow-Origin", "http://127.0.0.1:5173"));
    }

    @Test
    void permissionsClaimIsMappedToAuthorities() {
        Jwt jwt = Jwt.withTokenValue("token")
                .header("alg", "none")
                .claim("sub", "edwin")
                .claim("permissions", List.of(PRODUCT_VIEW))
                .claim("scope", REPORT_VIEW)
                .issuedAt(Instant.parse("2026-06-07T12:00:00Z"))
                .expiresAt(Instant.parse("2026-06-07T12:05:00Z"))
                .build();

        Authentication authentication = jwtAuthenticationConverter.convert(jwt);

        assertThat(authentication).isNotNull();
        assertThat(authentication.getAuthorities())
                .extracting("authority")
                .containsExactlyInAnyOrder(PRODUCT_VIEW, REPORT_VIEW);
    }

    private ProductResponse response() {
        return new ProductResponse(
                1L,
                "DELL-LAT-5440",
                "Dell Latitude 5440",
                "Laptop empresarial Dell Latitude 5440 con pantalla de 14 pulgadas",
                "Laptops",
                new BigDecimal("68500.00"),
                12,
                4,
                false,
                ProductStatus.ACTIVE,
                TIMESTAMP,
                TIMESTAMP
        );
    }

    private ProductRequest request() {
        return new ProductRequest(
                "DELL-LAT-5440",
                "Dell Latitude 5440",
                "Laptop empresarial Dell Latitude 5440 con pantalla de 14 pulgadas",
                "Laptops",
                new BigDecimal("68500.00"),
                12,
                4,
                ProductStatus.ACTIVE
        );
    }
}

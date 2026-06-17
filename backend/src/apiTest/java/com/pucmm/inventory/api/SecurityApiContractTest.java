package com.pucmm.inventory.api;

import static com.pucmm.inventory.config.SecurityConfig.PRODUCT_VIEW;
import static com.pucmm.inventory.config.SecurityConfig.REPORT_VIEW;
import static io.restassured.module.mockmvc.RestAssuredMockMvc.given;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;

import com.pucmm.inventory.common.api.GlobalExceptionHandler;
import com.pucmm.inventory.config.SecurityConfig;
import com.pucmm.inventory.product.api.ProductController;
import com.pucmm.inventory.product.api.dto.ProductResponse;
import com.pucmm.inventory.product.domain.ProductStatus;
import com.pucmm.inventory.product.service.ProductService;
import com.pucmm.inventory.stock.service.AuthenticatedInventoryUserResolver;
import com.pucmm.inventory.stock.service.StockService;
import io.restassured.module.mockmvc.RestAssuredMockMvc;
import java.math.BigDecimal;
import java.time.OffsetDateTime;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

@WebMvcTest(ProductController.class)
@Import({GlobalExceptionHandler.class, SecurityConfig.class})
class SecurityApiContractTest {
    private static final OffsetDateTime TIMESTAMP = OffsetDateTime.parse("2026-06-07T12:00:00-04:00");

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean
    private ProductService productService;

    @MockitoBean
    private StockService stockService;

    @MockitoBean
    private AuthenticatedInventoryUserResolver authenticatedInventoryUserResolver;

    @BeforeEach
    void configureRestAssured() {
        RestAssuredMockMvc.mockMvc(mockMvc);
    }

    @AfterEach
    void resetRestAssured() {
        RestAssuredMockMvc.reset();
    }

    @Test
    void requestWithoutJwtReturnsUnauthorized() {
        given()
        .when()
                .get("/products/{id}", 1L)
        .then()
                .statusCode(401);
    }

    @Test
    void jwtWithoutRequiredPermissionReturnsForbidden() {
        given()
                .auth().with(jwt().authorities(new SimpleGrantedAuthority(REPORT_VIEW)))
        .when()
                .get("/products/{id}", 1L)
        .then()
                .statusCode(403);
    }

    @Test
    void jwtWithRequiredPermissionAllowsProtectedEndpoint() {
        when(productService.getProduct(1L)).thenReturn(response());

        given()
                .auth().with(jwt().authorities(new SimpleGrantedAuthority(PRODUCT_VIEW)))
        .when()
                .get("/products/{id}", 1L)
        .then()
                .statusCode(200)
                .body("sku", org.hamcrest.Matchers.equalTo("DELL-LAT-5440"));
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
}

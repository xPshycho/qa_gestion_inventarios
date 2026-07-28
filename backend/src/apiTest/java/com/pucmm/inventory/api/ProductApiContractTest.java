package com.pucmm.inventory.api;

import static com.pucmm.inventory.config.SecurityConfig.PRODUCT_MANAGE;
import static com.pucmm.inventory.config.SecurityConfig.PRODUCT_VIEW;
import static io.restassured.module.mockmvc.RestAssuredMockMvc.given;
import static org.hamcrest.Matchers.containsString;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.pucmm.inventory.common.api.GlobalExceptionHandler;
import com.pucmm.inventory.config.SecurityConfig;
import com.pucmm.inventory.product.api.ProductController;
import com.pucmm.inventory.product.api.dto.ProductPageResponse;
import com.pucmm.inventory.product.api.dto.ProductRequest;
import com.pucmm.inventory.product.api.dto.ProductResponse;
import com.pucmm.inventory.product.domain.ProductStatus;
import com.pucmm.inventory.product.service.DuplicateSkuException;
import com.pucmm.inventory.product.service.ProductNotFoundException;
import com.pucmm.inventory.product.service.ProductService;
import com.pucmm.inventory.stock.service.AuthenticatedInventoryUserResolver;
import com.pucmm.inventory.stock.service.StockService;
import io.restassured.http.ContentType;
import io.restassured.module.mockmvc.RestAssuredMockMvc;
import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.List;
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
class ProductApiContractTest {
    private static final OffsetDateTime TIMESTAMP = OffsetDateTime.parse("2026-06-07T12:00:00-04:00");

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

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
    void listProductsReturnsPageContract() {
        ProductPageResponse page = new ProductPageResponse(List.of(response(1L, "DELL-LAT-5440")), 0, 20, 1, 1);
        when(productService.findProducts(
                0,
                20,
                "latitude",
                "Laptops",
                ProductStatus.ACTIVE,
                "name",
                "desc"
        )).thenReturn(page);

        given()
                .auth().with(jwtWith(PRODUCT_VIEW))
                .queryParam("search", "latitude")
                .queryParam("category", "Laptops")
                .queryParam("status", "ACTIVE")
                .queryParam("sort", "name")
                .queryParam("direction", "desc")
        .when()
                .get("/products")
        .then()
                .statusCode(200)
                .body("content[0].id", org.hamcrest.Matchers.equalTo(1))
                .body("content[0].sku", org.hamcrest.Matchers.equalTo("DELL-LAT-5440"))
                .body("content[0].stockAlert", org.hamcrest.Matchers.equalTo(false))
                .body("page", org.hamcrest.Matchers.equalTo(0))
                .body("size", org.hamcrest.Matchers.equalTo(20))
                .body("totalElements", org.hamcrest.Matchers.equalTo(1))
                .body("totalPages", org.hamcrest.Matchers.equalTo(1));
    }

    @Test
    void getProductReturnsProductContract() {
        when(productService.getProduct(1L)).thenReturn(response(1L, "DELL-LAT-5440"));

        given()
                .auth().with(jwtWith(PRODUCT_VIEW))
        .when()
                .get("/products/{id}", 1L)
        .then()
                .statusCode(200)
                .body("id", org.hamcrest.Matchers.equalTo(1))
                .body("sku", org.hamcrest.Matchers.equalTo("DELL-LAT-5440"))
                .body("name", org.hamcrest.Matchers.equalTo("Dell Latitude 5440"))
                .body("category", org.hamcrest.Matchers.equalTo("Laptops"))
                .body("currentStock", org.hamcrest.Matchers.equalTo(12))
                .body("minimumStock", org.hamcrest.Matchers.equalTo(4))
                .body("status", org.hamcrest.Matchers.equalTo("ACTIVE"));
    }

    @Test
    void createProductReturnsCreatedStatusAndLocation() throws Exception {
        ProductRequest request = request("DELL-LAT-5440");
        when(productService.createProduct(request)).thenReturn(response(1L, "DELL-LAT-5440"));

        given()
                .auth().with(jwtWith(PRODUCT_MANAGE))
                .contentType(ContentType.JSON)
                .body(objectMapper.writeValueAsString(request))
        .when()
                .post("/products")
        .then()
                .statusCode(201)
                .header("Location", "/products/1")
                .body("id", org.hamcrest.Matchers.equalTo(1))
                .body("sku", org.hamcrest.Matchers.equalTo("DELL-LAT-5440"));
    }

    @Test
    void updateProductReturnsUpdatedContract() throws Exception {
        ProductRequest request = request("LEN-T14-G4");
        when(productService.updateProduct(1L, request)).thenReturn(response(1L, "LEN-T14-G4"));

        given()
                .auth().with(jwtWith(PRODUCT_MANAGE))
                .contentType(ContentType.JSON)
                .body(objectMapper.writeValueAsString(request))
        .when()
                .put("/products/{id}", 1L)
        .then()
                .statusCode(200)
                .body("id", org.hamcrest.Matchers.equalTo(1))
                .body("sku", org.hamcrest.Matchers.equalTo("LEN-T14-G4"));
    }

    @Test
    void deleteProductReturnsNoContent() {
        given()
                .auth().with(jwtWith(PRODUCT_MANAGE))
        .when()
                .delete("/products/{id}", 1L)
        .then()
                .statusCode(204);

        verify(productService).deleteProduct(1L);
    }

    @Test
    void invalidProductBodyReturnsValidationError() throws Exception {
        ProductRequest request = new ProductRequest(
                "",
                "",
                "Laptop empresarial",
                "Laptops",
                new BigDecimal("68500.00"),
                12,
                4,
                ProductStatus.ACTIVE
        );

        given()
                .auth().with(jwtWith(PRODUCT_MANAGE))
                .contentType(ContentType.JSON)
                .body(objectMapper.writeValueAsString(request))
        .when()
                .post("/products")
        .then()
                .statusCode(400)
                .body("status", org.hamcrest.Matchers.equalTo(400))
                .body("message", containsString("sku"));
    }

    @Test
    void duplicateSkuReturnsConflictError() throws Exception {
        ProductRequest request = request("DELL-LAT-5440");
        when(productService.createProduct(request)).thenThrow(new DuplicateSkuException("DELL-LAT-5440"));

        given()
                .auth().with(jwtWith(PRODUCT_MANAGE))
                .contentType(ContentType.JSON)
                .body(objectMapper.writeValueAsString(request))
        .when()
                .post("/products")
        .then()
                .statusCode(409)
                .body("status", org.hamcrest.Matchers.equalTo(409))
                .body("message", containsString("DELL-LAT-5440"));
    }

    @Test
    void unknownProductReturnsNotFoundError() {
        when(productService.getProduct(99L)).thenThrow(new ProductNotFoundException(99L));

        given()
                .auth().with(jwtWith(PRODUCT_VIEW))
        .when()
                .get("/products/{id}", 99L)
        .then()
                .statusCode(404)
                .body("status", org.hamcrest.Matchers.equalTo(404))
                .body("message", containsString("99"));
    }

    private ProductRequest request(String sku) {
        return new ProductRequest(
                sku,
                "Dell Latitude 5440",
                "Laptop empresarial Dell Latitude 5440 con pantalla de 14 pulgadas",
                "Laptops",
                new BigDecimal("68500.00"),
                12,
                4,
                ProductStatus.ACTIVE
        );
    }

    private ProductResponse response(Long id, String sku) {
        return new ProductResponse(
                id,
                sku,
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

    private static org.springframework.test.web.servlet.request.RequestPostProcessor jwtWith(String permission) {
        return jwt().authorities(new SimpleGrantedAuthority(permission));
    }
}
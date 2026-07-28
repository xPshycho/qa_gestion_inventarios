package com.pucmm.inventory.api;

import static com.pucmm.inventory.config.SecurityConfig.STOCK_MANAGE;
import static com.pucmm.inventory.config.SecurityConfig.STOCK_VIEW;
import static io.restassured.module.mockmvc.RestAssuredMockMvc.given;
import static org.hamcrest.Matchers.containsString;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.pucmm.inventory.common.api.GlobalExceptionHandler;
import com.pucmm.inventory.config.SecurityConfig;
import com.pucmm.inventory.product.api.ProductController;
import com.pucmm.inventory.product.service.ProductService;
import com.pucmm.inventory.stock.api.dto.StockAdjustmentRequest;
import com.pucmm.inventory.stock.api.dto.StockMovementRequest;
import com.pucmm.inventory.stock.api.dto.StockMovementResponse;
import com.pucmm.inventory.stock.domain.StockMovementType;
import com.pucmm.inventory.stock.service.AuthenticatedInventoryUserResolver;
import com.pucmm.inventory.stock.service.InsufficientStockException;
import com.pucmm.inventory.stock.service.StockService;
import io.restassured.http.ContentType;
import io.restassured.module.mockmvc.RestAssuredMockMvc;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

@WebMvcTest(ProductController.class)
@Import({GlobalExceptionHandler.class, SecurityConfig.class})
class StockApiContractTest {
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
    void registerStockEntryReturnsMovementContract() throws Exception {
        StockMovementRequest request = new StockMovementRequest(3, "Recepcion de mercancia");
        when(authenticatedInventoryUserResolver.resolveUsername(any(Authentication.class))).thenReturn("edwin");
        when(stockService.registerEntry(1L, request, "edwin"))
                .thenReturn(movement(1L, StockMovementType.ENTRY, 12, 15, 3));

        given()
                .auth().with(jwtWith(STOCK_MANAGE))
                .contentType(ContentType.JSON)
                .body(objectMapper.writeValueAsString(Map.of(
                        "quantity", 3,
                        "userId", 999,
                        "observations", "Recepcion de mercancia"
                )))
        .when()
                .post("/products/{id}/stock/entries", 1L)
        .then()
                .statusCode(200)
                .body("id", org.hamcrest.Matchers.equalTo(1))
                .body("movementType", org.hamcrest.Matchers.equalTo("ENTRY"))
                .body("previousQuantity", org.hamcrest.Matchers.equalTo(12))
                .body("newQuantity", org.hamcrest.Matchers.equalTo(15))
                .body("deltaQuantity", org.hamcrest.Matchers.equalTo(3))
                .body("stockAlert", org.hamcrest.Matchers.equalTo(false));
    }

    @Test
    void registerStockExitWithInsufficientStockReturnsBusinessError() throws Exception {
        StockMovementRequest request = new StockMovementRequest(20, "Salida");
        when(authenticatedInventoryUserResolver.resolveUsername(any(Authentication.class))).thenReturn("edwin");
        when(stockService.registerExit(1L, request, "edwin")).thenThrow(new InsufficientStockException(1L, 12, 20));

        given()
                .auth().with(jwtWith(STOCK_MANAGE))
                .contentType(ContentType.JSON)
                .body(objectMapper.writeValueAsString(request))
        .when()
                .post("/products/{id}/stock/exits", 1L)
        .then()
                .statusCode(400)
                .body("status", org.hamcrest.Matchers.equalTo(400))
                .body("message", containsString("Stock insuficiente"));
    }

    @Test
    void adjustStockReturnsMovementContract() throws Exception {
        StockAdjustmentRequest request = new StockAdjustmentRequest(4, "Conteo fisico");
        when(authenticatedInventoryUserResolver.resolveUsername(any(Authentication.class))).thenReturn("edwin");
        when(stockService.adjustStock(1L, request, "edwin"))
                .thenReturn(movement(3L, StockMovementType.ADJUSTMENT, 12, 4, -8));

        given()
                .auth().with(jwtWith(STOCK_MANAGE))
                .contentType(ContentType.JSON)
                .body(objectMapper.writeValueAsString(request))
        .when()
                .post("/products/{id}/stock/adjustments", 1L)
        .then()
                .statusCode(200)
                .body("id", org.hamcrest.Matchers.equalTo(3))
                .body("movementType", org.hamcrest.Matchers.equalTo("ADJUSTMENT"))
                .body("previousQuantity", org.hamcrest.Matchers.equalTo(12))
                .body("newQuantity", org.hamcrest.Matchers.equalTo(4))
                .body("deltaQuantity", org.hamcrest.Matchers.equalTo(-8))
                .body("stockAlert", org.hamcrest.Matchers.equalTo(true));
    }

    @Test
    void invalidStockMovementBodyReturnsValidationError() throws Exception {
        StockMovementRequest request = new StockMovementRequest(0, "Cantidad invalida");

        given()
                .auth().with(jwtWith(STOCK_MANAGE))
                .contentType(ContentType.JSON)
                .body(objectMapper.writeValueAsString(request))
        .when()
                .post("/products/{id}/stock/entries", 1L)
        .then()
                .statusCode(400)
                .body("status", org.hamcrest.Matchers.equalTo(400))
                .body("message", containsString("quantity"));
    }

    @Test
    void listStockMovementsReturnsHistoryContract() {
        when(stockService.findMovements(1L)).thenReturn(List.of(movement(2L, StockMovementType.EXIT, 12, 9, -3)));

        given()
                .auth().with(jwtWith(STOCK_VIEW))
        .when()
                .get("/products/{id}/stock-movements", 1L)
        .then()
                .statusCode(200)
                .body("[0].id", org.hamcrest.Matchers.equalTo(2))
                .body("[0].productId", org.hamcrest.Matchers.equalTo(1))
                .body("[0].movementType", org.hamcrest.Matchers.equalTo("EXIT"))
                .body("[0].previousQuantity", org.hamcrest.Matchers.equalTo(12))
                .body("[0].newQuantity", org.hamcrest.Matchers.equalTo(9))
                .body("[0].deltaQuantity", org.hamcrest.Matchers.equalTo(-3));
    }

    private StockMovementResponse movement(
            Long id,
            StockMovementType movementType,
            Integer previousQuantity,
            Integer newQuantity,
            Integer deltaQuantity
    ) {
        return new StockMovementResponse(
                id,
                1L,
                "DELL-LAT-5440",
                "Dell Latitude 5440",
                2L,
                "edwin",
                "Edwin Balbuena",
                movementType,
                previousQuantity,
                newQuantity,
                deltaQuantity,
                "Movimiento de prueba",
                newQuantity <= 4,
                TIMESTAMP
        );
    }

    private static org.springframework.test.web.servlet.request.RequestPostProcessor jwtWith(String permission) {
        return jwt()
                .jwt(jwt -> jwt.claim("preferred_username", "edwin"))
                .authorities(new SimpleGrantedAuthority(permission));
    }
}
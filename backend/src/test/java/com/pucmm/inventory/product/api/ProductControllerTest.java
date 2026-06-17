package com.pucmm.inventory.product.api;

import static org.hamcrest.Matchers.containsString;
import static com.pucmm.inventory.config.SecurityConfig.PRODUCT_MANAGE;
import static com.pucmm.inventory.config.SecurityConfig.PRODUCT_VIEW;
import static com.pucmm.inventory.config.SecurityConfig.STOCK_MANAGE;
import static com.pucmm.inventory.config.SecurityConfig.STOCK_VIEW;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.pucmm.inventory.common.api.GlobalExceptionHandler;
import com.pucmm.inventory.config.SecurityConfig;
import com.pucmm.inventory.product.api.dto.ProductPageResponse;
import com.pucmm.inventory.product.api.dto.ProductRequest;
import com.pucmm.inventory.product.api.dto.ProductResponse;
import com.pucmm.inventory.product.domain.ProductStatus;
import com.pucmm.inventory.product.service.DuplicateSkuException;
import com.pucmm.inventory.product.service.ProductNotFoundException;
import com.pucmm.inventory.product.service.ProductService;
import com.pucmm.inventory.stock.api.dto.StockAdjustmentRequest;
import com.pucmm.inventory.stock.api.dto.StockMovementRequest;
import com.pucmm.inventory.stock.api.dto.StockMovementResponse;
import com.pucmm.inventory.stock.domain.StockMovementType;
import com.pucmm.inventory.stock.service.AuthenticatedInventoryUserResolver;
import com.pucmm.inventory.stock.service.InsufficientStockException;
import com.pucmm.inventory.stock.service.StockService;
import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.http.MediaType;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.request.RequestPostProcessor;
import org.springframework.test.web.servlet.MockMvc;

@WebMvcTest(ProductController.class)
@Import({GlobalExceptionHandler.class, SecurityConfig.class})
class ProductControllerTest {
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

    @Test
    void listProductsReturnsPage() throws Exception {
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

        mockMvc.perform(get("/products")
                        .with(jwtWith(PRODUCT_VIEW))
                        .param("search", "latitude")
                        .param("category", "Laptops")
                        .param("status", "ACTIVE")
                        .param("sort", "name")
                        .param("direction", "desc"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content[0].sku").value("DELL-LAT-5440"))
                .andExpect(jsonPath("$.totalElements").value(1));
    }

    @Test
    void listProductsRejectsUnsupportedSortField() throws Exception {
        mockMvc.perform(get("/products")
                        .with(jwtWith(PRODUCT_VIEW))
                        .param("sort", "unknown"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.status").value(400));
    }

    @Test
    void getProductReturnsProduct() throws Exception {
        when(productService.getProduct(1L)).thenReturn(response(1L, "DELL-LAT-5440"));

        mockMvc.perform(get("/products/{id}", 1L)
                        .with(jwtWith(PRODUCT_VIEW)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(1))
                .andExpect(jsonPath("$.sku").value("DELL-LAT-5440"));
    }

    @Test
    void getProductReturnsNotFoundError() throws Exception {
        when(productService.getProduct(99L)).thenThrow(new ProductNotFoundException(99L));

        mockMvc.perform(get("/products/{id}", 99L)
                        .with(jwtWith(PRODUCT_VIEW)))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.status").value(404))
                .andExpect(jsonPath("$.message", containsString("99")));
    }

    @Test
    void createProductReturnsCreatedProduct() throws Exception {
        ProductRequest request = request("DELL-LAT-5440");
        when(productService.createProduct(request)).thenReturn(response(1L, "DELL-LAT-5440"));

        mockMvc.perform(post("/products")
                        .with(jwtWith(PRODUCT_MANAGE))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isCreated())
                .andExpect(header().string("Location", "/products/1"))
                .andExpect(jsonPath("$.sku").value("DELL-LAT-5440"));
    }

    @Test
    void createProductRequiresValidBody() throws Exception {
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

        mockMvc.perform(post("/products")
                        .with(jwtWith(PRODUCT_MANAGE))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.status").value(400))
                .andExpect(jsonPath("$.message", containsString("sku")));
    }

    @Test
    void createProductReturnsConflictForDuplicateSku() throws Exception {
        ProductRequest request = request("DELL-LAT-5440");
        when(productService.createProduct(request)).thenThrow(new DuplicateSkuException("DELL-LAT-5440"));

        mockMvc.perform(post("/products")
                        .with(jwtWith(PRODUCT_MANAGE))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.status").value(409))
                .andExpect(jsonPath("$.message", containsString("DELL-LAT-5440")));
    }

    @Test
    void createProductRequiresJwtToken() throws Exception {
        mockMvc.perform(post("/products")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request("DELL-LAT-5440"))))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void updateProductReturnsUpdatedProduct() throws Exception {
        ProductRequest request = request("LEN-T14-G4");
        when(productService.updateProduct(1L, request)).thenReturn(response(1L, "LEN-T14-G4"));

        mockMvc.perform(put("/products/{id}", 1L)
                        .with(jwtWith(PRODUCT_MANAGE))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.sku").value("LEN-T14-G4"));
    }

    @Test
    void deleteProductReturnsNoContent() throws Exception {
        mockMvc.perform(delete("/products/{id}", 1L).with(jwtWith(PRODUCT_MANAGE)))
                .andExpect(status().isNoContent());

        verify(productService).deleteProduct(1L);
    }

    @Test
    void registerStockEntryReturnsMovement() throws Exception {
        StockMovementRequest request = new StockMovementRequest(3, "Recepcion de mercancia");
        when(authenticatedInventoryUserResolver.resolveUsername(any(Authentication.class))).thenReturn("edwin");
        when(stockService.registerEntry(1L, request, "edwin"))
                .thenReturn(movement(1L, StockMovementType.ENTRY, 12, 15, 3));

        mockMvc.perform(post("/products/{id}/stock/entries", 1L)
                        .with(jwtWith(STOCK_MANAGE))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "quantity": 3,
                                  "userId": 999,
                                  "observations": "Recepcion de mercancia"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.movementType").value("ENTRY"))
                .andExpect(jsonPath("$.previousQuantity").value(12))
                .andExpect(jsonPath("$.newQuantity").value(15))
                .andExpect(jsonPath("$.deltaQuantity").value(3));

        verify(stockService).registerEntry(1L, request, "edwin");
    }

    @Test
    void registerStockExitReturnsBadRequestWhenStockWouldBeNegative() throws Exception {
        StockMovementRequest request = new StockMovementRequest(20, "Salida");
        when(authenticatedInventoryUserResolver.resolveUsername(any(Authentication.class))).thenReturn("edwin");
        when(stockService.registerExit(1L, request, "edwin"))
                .thenThrow(new InsufficientStockException(1L, 12, 20));

        mockMvc.perform(post("/products/{id}/stock/exits", 1L)
                        .with(jwtWith(STOCK_MANAGE))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.status").value(400))
                .andExpect(jsonPath("$.message", containsString("Stock insuficiente")));
    }

    @Test
    void adjustStockReturnsMovement() throws Exception {
        StockAdjustmentRequest request = new StockAdjustmentRequest(4, "Conteo fisico");
        when(authenticatedInventoryUserResolver.resolveUsername(any(Authentication.class))).thenReturn("edwin");
        when(stockService.adjustStock(1L, request, "edwin"))
                .thenReturn(movement(1L, StockMovementType.ADJUSTMENT, 12, 4, -8));

        mockMvc.perform(post("/products/{id}/stock/adjustments", 1L)
                        .with(jwtWith(STOCK_MANAGE))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.movementType").value("ADJUSTMENT"))
                .andExpect(jsonPath("$.stockAlert").value(true));
    }

    @Test
    void stockMovementRequiresValidBody() throws Exception {
        StockMovementRequest request = new StockMovementRequest(0, "Cantidad invalida");

        mockMvc.perform(post("/products/{id}/stock/entries", 1L)
                        .with(jwtWith(STOCK_MANAGE))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.status").value(400))
                .andExpect(jsonPath("$.message", containsString("quantity")));
    }

    @Test
    void stockEntryRequiresJwtToken() throws Exception {
        mockMvc.perform(post("/products/{id}/stock/entries", 1L)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new StockMovementRequest(1, null))))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void listStockMovementsReturnsHistory() throws Exception {
        when(stockService.findMovements(1L)).thenReturn(List.of(movement(1L, StockMovementType.EXIT, 12, 9, -3)));

        mockMvc.perform(get("/products/{id}/stock-movements", 1L)
                        .with(jwtWith(STOCK_VIEW)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].movementType").value("EXIT"))
                .andExpect(jsonPath("$[0].previousQuantity").value(12))
                .andExpect(jsonPath("$[0].newQuantity").value(9));
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

    private static RequestPostProcessor jwtWith(String permission) {
        return jwt()
                .jwt(jwt -> jwt.claim("preferred_username", "edwin"))
                .authorities(new SimpleGrantedAuthority(permission));
    }
}
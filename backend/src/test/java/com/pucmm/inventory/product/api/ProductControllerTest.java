package com.pucmm.inventory.product.api;

import static org.hamcrest.Matchers.containsString;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.csrf;
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
import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
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

    @Test
    void listProductsReturnsPage() throws Exception {
        ProductPageResponse page = new ProductPageResponse(List.of(response(1L, "DELL-LAT-5440")), 0, 20, 1, 1);
        when(productService.findProducts(0, 20, "latitude", "Laptops", ProductStatus.ACTIVE)).thenReturn(page);

        mockMvc.perform(get("/products")
                        .param("search", "latitude")
                        .param("category", "Laptops")
                        .param("status", "ACTIVE"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content[0].sku").value("DELL-LAT-5440"))
                .andExpect(jsonPath("$.totalElements").value(1));
    }

    @Test
    void getProductReturnsProduct() throws Exception {
        when(productService.getProduct(1L)).thenReturn(response(1L, "DELL-LAT-5440"));

        mockMvc.perform(get("/products/{id}", 1L))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(1))
                .andExpect(jsonPath("$.sku").value("DELL-LAT-5440"));
    }

    @Test
    void getProductReturnsNotFoundError() throws Exception {
        when(productService.getProduct(99L)).thenThrow(new ProductNotFoundException(99L));

        mockMvc.perform(get("/products/{id}", 99L))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.status").value(404))
                .andExpect(jsonPath("$.message", containsString("99")));
    }

    @Test
    void createProductReturnsCreatedProduct() throws Exception {
        ProductRequest request = request("DELL-LAT-5440");
        when(productService.createProduct(request)).thenReturn(response(1L, "DELL-LAT-5440"));

        mockMvc.perform(post("/products")
                        .with(csrf())
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
                        .with(csrf())
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
                        .with(csrf())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.status").value(409))
                .andExpect(jsonPath("$.message", containsString("DELL-LAT-5440")));
    }

    @Test
    void createProductRequiresCsrfToken() throws Exception {
        mockMvc.perform(post("/products")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request("DELL-LAT-5440"))))
                .andExpect(status().isForbidden());
    }

    @Test
    void updateProductReturnsUpdatedProduct() throws Exception {
        ProductRequest request = request("LEN-T14-G4");
        when(productService.updateProduct(1L, request)).thenReturn(response(1L, "LEN-T14-G4"));

        mockMvc.perform(put("/products/{id}", 1L)
                        .with(csrf())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.sku").value("LEN-T14-G4"));
    }

    @Test
    void deleteProductReturnsNoContent() throws Exception {
        mockMvc.perform(delete("/products/{id}", 1L).with(csrf()))
                .andExpect(status().isNoContent());

        verify(productService).deleteProduct(1L);
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
                ProductStatus.ACTIVE,
                TIMESTAMP,
                TIMESTAMP
        );
    }
}

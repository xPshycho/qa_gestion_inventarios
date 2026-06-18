package com.pucmm.inventory.audit.api;

import static com.pucmm.inventory.config.SecurityConfig.AUDIT_VIEW;
import static org.hamcrest.Matchers.containsString;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.pucmm.inventory.audit.api.dto.AuditRevisionResponse;
import com.pucmm.inventory.audit.service.AuditService;
import com.pucmm.inventory.common.api.GlobalExceptionHandler;
import com.pucmm.inventory.config.SecurityConfig;
import com.pucmm.inventory.product.service.ProductNotFoundException;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.request.RequestPostProcessor;

@WebMvcTest(AuditController.class)
@Import({GlobalExceptionHandler.class, SecurityConfig.class})
class AuditControllerTest {
    private static final OffsetDateTime TIMESTAMP = OffsetDateTime.parse("2026-06-07T12:00:00Z");

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean
    private AuditService auditService;

    @Test
    void findProductRevisionsReturnsAuditHistory() throws Exception {
        when(auditService.findProductRevisions(1L)).thenReturn(List.of(new AuditRevisionResponse(
                "Product",
                1L,
                3,
                "MOD",
                TIMESTAMP,
                "edwin",
                Map.of("currentStock", 12),
                Map.of("currentStock", 9)
        )));

        mockMvc.perform(get("/audit/products/{productId}/revisions", 1L)
                        .with(jwtWith(AUDIT_VIEW)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].entityName").value("Product"))
                .andExpect(jsonPath("$[0].revisionType").value("MOD"))
                .andExpect(jsonPath("$[0].username").value("edwin"))
                .andExpect(jsonPath("$[0].previousValues.currentStock").value(12))
                .andExpect(jsonPath("$[0].currentValues.currentStock").value(9));
    }

    @Test
    void findProductStockMovementRevisionsReturnsAuditHistory() throws Exception {
        when(auditService.findProductStockMovementRevisions(1L)).thenReturn(List.of(new AuditRevisionResponse(
                "StockMovement",
                10L,
                4,
                "ADD",
                TIMESTAMP,
                "carlos",
                Map.of(),
                Map.of("movementType", "ENTRY", "newQuantity", 15)
        )));

        mockMvc.perform(get("/audit/products/{productId}/stock-movements/revisions", 1L)
                        .with(jwtWith(AUDIT_VIEW)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].entityName").value("StockMovement"))
                .andExpect(jsonPath("$[0].revisionType").value("ADD"))
                .andExpect(jsonPath("$[0].currentValues.movementType").value("ENTRY"))
                .andExpect(jsonPath("$[0].currentValues.newQuantity").value(15));
    }

    @Test
    void findProductRevisionsReturnsNotFoundForUnknownProduct() throws Exception {
        when(auditService.findProductRevisions(99L)).thenThrow(new ProductNotFoundException(99L));

        mockMvc.perform(get("/audit/products/{productId}/revisions", 99L)
                        .with(jwtWith(AUDIT_VIEW)))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.status").value(404))
                .andExpect(jsonPath("$.message", containsString("99")));
    }

    private static RequestPostProcessor jwtWith(String permission) {
        return jwt().authorities(new SimpleGrantedAuthority(permission));
    }
}

package com.pucmm.inventory.audit.api;

import com.pucmm.inventory.audit.api.dto.AuditRevisionResponse;
import com.pucmm.inventory.audit.service.AuditService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import java.util.List;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/audit")
@Tag(name = "Audit", description = "Consulta de historial de auditoria")
public class AuditController {
    private final AuditService auditService;

    public AuditController(AuditService auditService) {
        this.auditService = auditService;
    }

    @GetMapping("/products/{productId}/revisions")
    @Operation(summary = "Consultar revisiones de auditoria de un producto")
    public List<AuditRevisionResponse> findProductRevisions(@PathVariable Long productId) {
        return auditService.findProductRevisions(productId);
    }

    @GetMapping("/products/{productId}/stock-movements/revisions")
    @Operation(summary = "Consultar revisiones de auditoria de movimientos de stock de un producto")
    public List<AuditRevisionResponse> findProductStockMovementRevisions(@PathVariable Long productId) {
        return auditService.findProductStockMovementRevisions(productId);
    }
}

package com.pucmm.inventory.report.api;

import com.pucmm.inventory.report.api.dto.CriticalProductResponse;
import com.pucmm.inventory.report.api.dto.DashboardMetricsResponse;
import com.pucmm.inventory.report.api.dto.DashboardResponse;
import com.pucmm.inventory.report.api.dto.RecentStockMovementResponse;
import com.pucmm.inventory.report.api.dto.BestSellingProductResponse;
import com.pucmm.inventory.report.service.ReportService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import java.util.List;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@Validated
@RestController
@RequestMapping("/reports")
@Tag(name = "Reports", description = "Reportes y metricas del dashboard de inventario")
public class ReportController {
    private final ReportService reportService;

    public ReportController(ReportService reportService) {
        this.reportService = reportService;
    }

    @GetMapping("/dashboard")
    @Operation(summary = "Obtener datos consolidados del dashboard de inventario")
    public DashboardResponse getDashboard() {
        return reportService.getDashboard();
    }

    @GetMapping("/critical-products")
    @Operation(summary = "Listar productos activos con stock critico")
    public List<CriticalProductResponse> getCriticalProducts(
            @RequestParam(defaultValue = "5") @Min(1) @Max(50) int limit
    ) {
        return reportService.getCriticalProducts(limit);
    }

    @GetMapping("/best-selling-products")
    @Operation(summary = "Listar productos con mas unidades vendidas, calculadas desde salidas de stock")
    public List<BestSellingProductResponse> getBestSellingProducts(
            @RequestParam(defaultValue = "5") @Min(1) @Max(50) int limit
    ) {
        return reportService.getBestSellingProducts(limit);
    }

    @GetMapping("/recent-movements")
    @Operation(summary = "Listar movimientos recientes de inventario")
    public List<RecentStockMovementResponse> getRecentMovements(
            @RequestParam(defaultValue = "8") @Min(1) @Max(50) int limit
    ) {
        return reportService.getRecentMovements(limit);
    }

    @GetMapping("/metrics")
    @Operation(summary = "Obtener metricas operacionales del inventario")
    public DashboardMetricsResponse getMetrics() {
        return reportService.getMetrics();
    }
}

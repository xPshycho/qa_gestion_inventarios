package com.pucmm.inventory.report.api;

import com.pucmm.inventory.report.api.dto.DashboardResponse;
import com.pucmm.inventory.report.service.DashboardService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/reports")
@Tag(name = "Reports", description = "Reportes e indicadores operacionales del inventario")
public class ReportController {
    private final DashboardService dashboardService;

    public ReportController(DashboardService dashboardService) {
        this.dashboardService = dashboardService;
    }

    @GetMapping("/dashboard")
    @Operation(summary = "Consultar dashboard operacional de inventario")
    public DashboardResponse getDashboard() {
        return dashboardService.getDashboard();
    }
}

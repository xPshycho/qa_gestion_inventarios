package com.pucmm.inventory.report.api.dto;

import com.pucmm.inventory.stock.api.dto.StockMovementResponse;
import java.util.List;

public record DashboardResponse(
        DashboardMetricsResponse metrics,
        List<CriticalProductResponse> criticalProducts,
        List<TopMovedProductResponse> mostMovedProducts,
        List<StockMovementResponse> recentMovements
) {
}

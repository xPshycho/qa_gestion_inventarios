package com.pucmm.inventory.report.api.dto;

import java.util.List;

public record DashboardResponse(
        DashboardMetricsResponse metrics,
        List<CriticalProductResponse> criticalProducts,
        List<TopMovedProductResponse> mostMovedProducts,
        List<RecentStockMovementResponse> recentMovements
) {
}

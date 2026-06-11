package com.pucmm.inventory.report.api.dto;

import java.math.BigDecimal;

public record DashboardMetricsResponse(
        long totalProducts,
        long activeProducts,
        long inactiveProducts,
        long criticalProducts,
        long totalStockUnits,
        BigDecimal inventoryValue,
        long totalMovements,
        long initialMovements,
        long entryMovements,
        long exitMovements,
        long adjustmentMovements
) {
}

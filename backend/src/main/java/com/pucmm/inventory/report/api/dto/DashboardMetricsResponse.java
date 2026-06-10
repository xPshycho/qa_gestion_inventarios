package com.pucmm.inventory.report.api.dto;

import java.math.BigDecimal;

public record DashboardMetricsResponse(
        Long totalProducts,
        Long activeProducts,
        Long inactiveProducts,
        Long criticalProducts,
        Long totalStockUnits,
        BigDecimal inventoryValue,
        Long totalMovements,
        Long initialMovements,
        Long entryMovements,
        Long exitMovements,
        Long adjustmentMovements
) {
}

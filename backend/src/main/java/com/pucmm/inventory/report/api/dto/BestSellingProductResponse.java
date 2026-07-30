package com.pucmm.inventory.report.api.dto;

import com.pucmm.inventory.stock.repository.BestSellingProductProjection;
import java.time.OffsetDateTime;

public record BestSellingProductResponse(
        Long productId,
        String productSku,
        String productName,
        String category,
        long exitMovementCount,
        long totalSoldUnits,
        OffsetDateTime lastMovementAt
) {
    public static BestSellingProductResponse from(BestSellingProductProjection projection) {
        return new BestSellingProductResponse(
                projection.getProductId(),
                projection.getProductSku(),
                projection.getProductName(),
                projection.getCategory(),
                projection.getExitMovementCount(),
                projection.getTotalSoldUnits(),
                projection.getLastMovementAt()
        );
    }
}

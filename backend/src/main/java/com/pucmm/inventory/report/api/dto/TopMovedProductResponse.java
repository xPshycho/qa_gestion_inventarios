package com.pucmm.inventory.report.api.dto;

import com.pucmm.inventory.stock.repository.TopMovedProductProjection;
import java.time.OffsetDateTime;

public record TopMovedProductResponse(
        Long productId,
        String productSku,
        String productName,
        String category,
        long movementCount,
        long totalMovedUnits,
        OffsetDateTime lastMovementAt
) {
    public static TopMovedProductResponse from(TopMovedProductProjection projection) {
        return new TopMovedProductResponse(
                projection.getProductId(),
                projection.getProductSku(),
                projection.getProductName(),
                projection.getCategory(),
                projection.getMovementCount(),
                projection.getTotalMovedUnits(),
                projection.getLastMovementAt()
        );
    }
}

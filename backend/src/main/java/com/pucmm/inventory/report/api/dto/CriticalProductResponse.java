package com.pucmm.inventory.report.api.dto;

import com.pucmm.inventory.product.domain.Product;
import com.pucmm.inventory.product.domain.ProductStatus;
import java.time.OffsetDateTime;

public record CriticalProductResponse(
        Long id,
        String sku,
        String name,
        String category,
        Integer currentStock,
        Integer minimumStock,
        Integer shortage,
        ProductStatus status,
        OffsetDateTime updatedAt
) {
    public static CriticalProductResponse from(Product product) {
        return new CriticalProductResponse(
                product.getId(),
                product.getSku(),
                product.getName(),
                product.getCategory(),
                product.getCurrentStock(),
                product.getMinimumStock(),
                product.getMinimumStock() - product.getCurrentStock(),
                product.getStatus(),
                product.getUpdatedAt()
        );
    }
}

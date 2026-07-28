package com.pucmm.inventory.product.domain;

import java.math.BigDecimal;

public record ProductData(
        String sku,
        String name,
        String description,
        String category,
        BigDecimal price,
        Integer currentStock,
        Integer minimumStock,
        ProductStatus status
) {
}

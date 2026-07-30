package com.pucmm.inventory.stock.repository;

import java.time.OffsetDateTime;

public interface BestSellingProductProjection {
    Long getProductId();

    String getProductSku();

    String getProductName();

    String getCategory();

    long getExitMovementCount();

    long getTotalSoldUnits();

    OffsetDateTime getLastMovementAt();
}

package com.pucmm.inventory.stock.repository;

import java.time.OffsetDateTime;

public interface TopMovedProductProjection {
    Long getProductId();

    String getProductSku();

    String getProductName();

    String getCategory();

    Long getMovementCount();

    Long getTotalMovedUnits();

    OffsetDateTime getLastMovementAt();
}

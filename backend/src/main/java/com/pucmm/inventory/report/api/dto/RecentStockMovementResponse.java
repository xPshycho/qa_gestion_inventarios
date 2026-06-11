package com.pucmm.inventory.report.api.dto;

import com.pucmm.inventory.product.domain.Product;
import com.pucmm.inventory.stock.domain.InventoryUser;
import com.pucmm.inventory.stock.domain.StockMovement;
import com.pucmm.inventory.stock.domain.StockMovementType;
import java.time.OffsetDateTime;

public record RecentStockMovementResponse(
        Long id,
        Long productId,
        String productSku,
        String productName,
        Long userId,
        String username,
        String userDisplayName,
        StockMovementType movementType,
        Integer previousQuantity,
        Integer newQuantity,
        Integer deltaQuantity,
        String observations,
        boolean stockAlert,
        OffsetDateTime createdAt
) {
    public static RecentStockMovementResponse from(StockMovement movement) {
        Product product = movement.getProduct();
        InventoryUser user = movement.getUser();

        return new RecentStockMovementResponse(
                movement.getId(),
                product.getId(),
                product.getSku(),
                product.getName(),
                user == null ? null : user.getId(),
                user == null ? null : user.getUsername(),
                user == null ? null : user.getDisplayName(),
                movement.getMovementType(),
                movement.getPreviousQuantity(),
                movement.getNewQuantity(),
                movement.getDeltaQuantity(),
                movement.getObservations(),
                product.hasMinimumStockAlert(),
                movement.getCreatedAt()
        );
    }
}

package com.pucmm.inventory.stock.repository;

import com.pucmm.inventory.stock.domain.StockMovement;
import com.pucmm.inventory.stock.domain.StockMovementType;
import java.util.List;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

public interface StockMovementRepository extends JpaRepository<StockMovement, Long> {
    List<StockMovement> findByProductIdOrderByCreatedAtDescIdDesc(Long productId);

    List<StockMovement> findAllByOrderByCreatedAtDescIdDesc(Pageable pageable);

    long countByMovementType(StockMovementType movementType);

    @Query("""
            select p.id as productId,
                   p.sku as productSku,
                   p.name as productName,
                   p.category as category,
                   count(m.id) as movementCount,
                   coalesce(sum(abs(m.deltaQuantity)), 0) as totalMovedUnits,
                   max(m.createdAt) as lastMovementAt
            from StockMovement m
            join m.product p
            group by p.id, p.sku, p.name, p.category
            order by coalesce(sum(abs(m.deltaQuantity)), 0) desc, count(m.id) desc, p.name asc
            """)
    List<TopMovedProductProjection> findMostMovedProducts(Pageable pageable);
}

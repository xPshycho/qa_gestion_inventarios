package com.pucmm.inventory.stock.repository;

import com.pucmm.inventory.stock.domain.StockMovement;
import com.pucmm.inventory.stock.domain.StockMovementType;
import java.util.List;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

public interface StockMovementRepository extends JpaRepository<StockMovement, Long> {
    List<StockMovement> findByProductIdOrderByCreatedAtDescIdDesc(Long productId);

    long countByMovementType(StockMovementType movementType);

    @EntityGraph(attributePaths = {"product", "user"})
    List<StockMovement> findAllByOrderByCreatedAtDescIdDesc(Pageable pageable);

    @Query("""
            select p.id as productId,
                   p.sku as productSku,
                   p.name as productName,
                   p.category as category,
                   count(m.id) as movementCount,
                   sum(abs(m.deltaQuantity)) as totalMovedUnits,
                   max(m.createdAt) as lastMovementAt
            from StockMovement m
            join m.product p
            group by p.id, p.sku, p.name, p.category
            order by count(m.id) desc, sum(abs(m.deltaQuantity)) desc, max(m.createdAt) desc
            """)
    List<TopMovedProductProjection> findTopMovedProducts(Pageable pageable);
}

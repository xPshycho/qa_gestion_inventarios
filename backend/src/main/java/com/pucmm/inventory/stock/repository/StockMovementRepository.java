package com.pucmm.inventory.stock.repository;

import com.pucmm.inventory.stock.domain.StockMovement;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface StockMovementRepository extends JpaRepository<StockMovement, Long> {
    List<StockMovement> findByProductIdOrderByCreatedAtDescIdDesc(Long productId);
}

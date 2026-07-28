package com.pucmm.inventory.product.repository;

import com.pucmm.inventory.product.domain.Product;
import com.pucmm.inventory.product.domain.ProductStatus;
import jakarta.persistence.LockModeType;
import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface ProductRepository extends JpaRepository<Product, Long>, JpaSpecificationExecutor<Product> {
    boolean existsBySkuIgnoreCase(String sku);

    boolean existsBySkuIgnoreCaseAndIdNot(String sku, Long id);

    long countByStatus(ProductStatus status);

    @Query("""
            select p
            from Product p
            where p.status = com.pucmm.inventory.product.domain.ProductStatus.ACTIVE
              and p.currentStock <= p.minimumStock
            order by (p.minimumStock - p.currentStock) desc, p.currentStock asc, p.name asc
            """)
    List<Product> findCriticalActiveProducts(Pageable pageable);

    @Query("""
            select count(p)
            from Product p
            where p.status = com.pucmm.inventory.product.domain.ProductStatus.ACTIVE
              and p.currentStock <= p.minimumStock
            """)
    long countCriticalActiveProducts();

    @Query("select sum(p.currentStock) from Product p")
    Long sumCurrentStock();

    @Query("select sum(p.price * p.currentStock) from Product p")
    BigDecimal calculateInventoryValue();

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select p from Product p where p.id = :id")
    Optional<Product> findByIdForUpdate(@Param("id") Long id);
}

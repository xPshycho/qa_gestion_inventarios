package com.pucmm.inventory.report.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.pucmm.inventory.product.domain.Product;
import com.pucmm.inventory.product.domain.ProductData;
import com.pucmm.inventory.product.domain.ProductStatus;
import com.pucmm.inventory.product.repository.ProductRepository;
import com.pucmm.inventory.report.api.dto.DashboardResponse;
import com.pucmm.inventory.stock.domain.StockMovement;
import com.pucmm.inventory.stock.domain.StockMovementType;
import com.pucmm.inventory.stock.repository.StockMovementRepository;
import com.pucmm.inventory.stock.repository.TopMovedProductProjection;
import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.Pageable;
import org.springframework.test.util.ReflectionTestUtils;

@ExtendWith(MockitoExtension.class)
class DashboardServiceTest {
    private static final OffsetDateTime TIMESTAMP = OffsetDateTime.parse("2026-06-07T12:00:00-04:00");

    @Mock
    private ProductRepository productRepository;

    @Mock
    private StockMovementRepository stockMovementRepository;

    @InjectMocks
    private DashboardService dashboardService;

    @Test
    void getDashboardReturnsMetricsCriticalProductsTopMovedAndRecentHistory() {
        Product criticalProduct = productWithStock(1L, "DELL-LAT-5440", 2, 5, ProductStatus.ACTIVE);
        StockMovement recentMovement = movement(10L, criticalProduct, StockMovementType.EXIT, 8, 2, -6);
        TopMovedProjection topMoved = new TopMovedProjection(
                1L,
                "DELL-LAT-5440",
                "Dell Latitude 5440",
                "Laptops",
                3L,
                18L,
                TIMESTAMP
        );

        when(productRepository.count()).thenReturn(4L);
        when(productRepository.countByStatus(ProductStatus.ACTIVE)).thenReturn(3L);
        when(productRepository.countByStatus(ProductStatus.INACTIVE)).thenReturn(1L);
        when(productRepository.countCriticalProductsByStatus(ProductStatus.ACTIVE)).thenReturn(1L);
        when(productRepository.sumCurrentStock()).thenReturn(26L);
        when(productRepository.calculateInventoryValue()).thenReturn(new BigDecimal("1728000.00"));
        when(productRepository.findCriticalProducts(eq(ProductStatus.ACTIVE), any(Pageable.class)))
                .thenReturn(List.of(criticalProduct));

        when(stockMovementRepository.count()).thenReturn(8L);
        when(stockMovementRepository.countByMovementType(StockMovementType.INITIAL)).thenReturn(4L);
        when(stockMovementRepository.countByMovementType(StockMovementType.ENTRY)).thenReturn(2L);
        when(stockMovementRepository.countByMovementType(StockMovementType.EXIT)).thenReturn(1L);
        when(stockMovementRepository.countByMovementType(StockMovementType.ADJUSTMENT)).thenReturn(1L);
        when(stockMovementRepository.findMostMovedProducts(any(Pageable.class))).thenReturn(List.of(topMoved));
        when(stockMovementRepository.findAllByOrderByCreatedAtDescIdDesc(any(Pageable.class)))
                .thenReturn(List.of(recentMovement));

        DashboardResponse response = dashboardService.getDashboard();

        assertThat(response.metrics().totalProducts()).isEqualTo(4);
        assertThat(response.metrics().activeProducts()).isEqualTo(3);
        assertThat(response.metrics().criticalProducts()).isEqualTo(1);
        assertThat(response.metrics().inventoryValue()).isEqualByComparingTo("1728000.00");
        assertThat(response.metrics().exitMovements()).isEqualTo(1);
        assertThat(response.criticalProducts()).hasSize(1);
        assertThat(response.criticalProducts().getFirst().shortage()).isEqualTo(3);
        assertThat(response.mostMovedProducts().getFirst().totalMovedUnits()).isEqualTo(18);
        assertThat(response.recentMovements().getFirst().movementType()).isEqualTo(StockMovementType.EXIT);

        ArgumentCaptor<Pageable> criticalPageable = ArgumentCaptor.forClass(Pageable.class);
        verify(productRepository).findCriticalProducts(eq(ProductStatus.ACTIVE), criticalPageable.capture());
        assertThat(criticalPageable.getValue().getPageSize()).isEqualTo(5);
    }

    @Test
    void getDashboardNormalizesEmptyNumericAggregates() {
        when(productRepository.count()).thenReturn(0L);
        when(productRepository.countByStatus(ProductStatus.ACTIVE)).thenReturn(0L);
        when(productRepository.countByStatus(ProductStatus.INACTIVE)).thenReturn(0L);
        when(productRepository.countCriticalProductsByStatus(ProductStatus.ACTIVE)).thenReturn(0L);
        when(productRepository.sumCurrentStock()).thenReturn(null);
        when(productRepository.calculateInventoryValue()).thenReturn(null);
        when(productRepository.findCriticalProducts(eq(ProductStatus.ACTIVE), any(Pageable.class)))
                .thenReturn(List.of());

        when(stockMovementRepository.count()).thenReturn(0L);
        when(stockMovementRepository.countByMovementType(any(StockMovementType.class))).thenReturn(0L);
        when(stockMovementRepository.findMostMovedProducts(any(Pageable.class))).thenReturn(List.of());
        when(stockMovementRepository.findAllByOrderByCreatedAtDescIdDesc(any(Pageable.class))).thenReturn(List.of());

        DashboardResponse response = dashboardService.getDashboard();

        assertThat(response.metrics().totalStockUnits()).isZero();
        assertThat(response.metrics().inventoryValue()).isEqualByComparingTo(BigDecimal.ZERO);
        assertThat(response.criticalProducts()).isEmpty();
        assertThat(response.mostMovedProducts()).isEmpty();
        assertThat(response.recentMovements()).isEmpty();
    }

    private Product productWithStock(
            Long id,
            String sku,
            int currentStock,
            int minimumStock,
            ProductStatus status
    ) {
        Product product = new Product(new ProductData(
                sku,
                "Dell Latitude 5440",
                "Laptop empresarial",
                "Laptops",
                new BigDecimal("68500.00"),
                currentStock,
                minimumStock,
                status
        ));
        ReflectionTestUtils.setField(product, "id", id);
        ReflectionTestUtils.setField(product, "createdAt", TIMESTAMP);
        ReflectionTestUtils.setField(product, "updatedAt", TIMESTAMP);
        return product;
    }

    private StockMovement movement(
            Long id,
            Product product,
            StockMovementType movementType,
            int previousQuantity,
            int newQuantity,
            int deltaQuantity
    ) {
        StockMovement movement = new StockMovement(
                product,
                null,
                movementType,
                previousQuantity,
                newQuantity,
                deltaQuantity,
                "Movimiento de prueba"
        );
        ReflectionTestUtils.setField(movement, "id", id);
        ReflectionTestUtils.setField(movement, "createdAt", TIMESTAMP);
        return movement;
    }

    private record TopMovedProjection(
            Long productId,
            String productSku,
            String productName,
            String category,
            Long movementCount,
            Long totalMovedUnits,
            OffsetDateTime lastMovementAt
    ) implements TopMovedProductProjection {
        @Override
        public Long getProductId() {
            return productId;
        }

        @Override
        public String getProductSku() {
            return productSku;
        }

        @Override
        public String getProductName() {
            return productName;
        }

        @Override
        public String getCategory() {
            return category;
        }

        @Override
        public Long getMovementCount() {
            return movementCount;
        }

        @Override
        public Long getTotalMovedUnits() {
            return totalMovedUnits;
        }

        @Override
        public OffsetDateTime getLastMovementAt() {
            return lastMovementAt;
        }
    }
}

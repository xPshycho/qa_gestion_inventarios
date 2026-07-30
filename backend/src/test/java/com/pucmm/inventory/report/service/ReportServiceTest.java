package com.pucmm.inventory.report.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.pucmm.inventory.product.domain.Product;
import com.pucmm.inventory.product.domain.ProductData;
import com.pucmm.inventory.product.domain.ProductStatus;
import com.pucmm.inventory.product.repository.ProductRepository;
import com.pucmm.inventory.report.api.dto.CriticalProductResponse;
import com.pucmm.inventory.report.api.dto.DashboardMetricsResponse;
import com.pucmm.inventory.report.api.dto.DashboardResponse;
import com.pucmm.inventory.report.api.dto.RecentStockMovementResponse;
import com.pucmm.inventory.report.api.dto.BestSellingProductResponse;
import com.pucmm.inventory.stock.domain.InventoryUser;
import com.pucmm.inventory.stock.domain.StockMovement;
import com.pucmm.inventory.stock.domain.StockMovementType;
import com.pucmm.inventory.stock.repository.StockMovementRepository;
import com.pucmm.inventory.stock.repository.BestSellingProductProjection;
import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.beans.BeanUtils;
import org.springframework.data.domain.PageRequest;
import org.springframework.test.util.ReflectionTestUtils;

@ExtendWith(MockitoExtension.class)
class ReportServiceTest {
    private static final OffsetDateTime TIMESTAMP = OffsetDateTime.parse("2026-06-07T12:00:00-04:00");

    @Mock
    private ProductRepository productRepository;

    @Mock
    private StockMovementRepository stockMovementRepository;

    @InjectMocks
    private ReportService reportService;

    @Test
    void getMetricsReturnsOperationalTotals() {
        when(productRepository.countByArchivedFalse()).thenReturn(4L);
        when(productRepository.countByStatusAndArchivedFalse(ProductStatus.ACTIVE)).thenReturn(3L);
        when(productRepository.countByStatusAndArchivedFalse(ProductStatus.INACTIVE)).thenReturn(1L);
        when(productRepository.countCriticalActiveProducts()).thenReturn(1L);
        when(productRepository.sumCurrentStock()).thenReturn(26L);
        when(productRepository.calculateInventoryValue()).thenReturn(new BigDecimal("1728000.00"));
        when(stockMovementRepository.count()).thenReturn(8L);
        when(stockMovementRepository.countByMovementType(StockMovementType.INITIAL)).thenReturn(4L);
        when(stockMovementRepository.countByMovementType(StockMovementType.ENTRY)).thenReturn(2L);
        when(stockMovementRepository.countByMovementType(StockMovementType.EXIT)).thenReturn(1L);
        when(stockMovementRepository.countByMovementType(StockMovementType.ADJUSTMENT)).thenReturn(1L);

        DashboardMetricsResponse response = reportService.getMetrics();

        assertThat(response.totalProducts()).isEqualTo(4);
        assertThat(response.activeProducts()).isEqualTo(3);
        assertThat(response.criticalProducts()).isEqualTo(1);
        assertThat(response.totalStockUnits()).isEqualTo(26);
        assertThat(response.inventoryValue()).isEqualByComparingTo("1728000.00");
        assertThat(response.entryMovements()).isEqualTo(2);
        assertThat(response.exitMovements()).isEqualTo(1);
    }

    @Test
    void getMetricsReturnsZeroWhenAggregateSumsAreNull() {
        when(productRepository.countByArchivedFalse()).thenReturn(0L);
        when(productRepository.countByStatusAndArchivedFalse(ProductStatus.ACTIVE)).thenReturn(0L);
        when(productRepository.countByStatusAndArchivedFalse(ProductStatus.INACTIVE)).thenReturn(0L);
        when(productRepository.countCriticalActiveProducts()).thenReturn(0L);
        when(productRepository.sumCurrentStock()).thenReturn(null);
        when(productRepository.calculateInventoryValue()).thenReturn(null);
        when(stockMovementRepository.count()).thenReturn(0L);
        when(stockMovementRepository.countByMovementType(StockMovementType.INITIAL)).thenReturn(0L);
        when(stockMovementRepository.countByMovementType(StockMovementType.ENTRY)).thenReturn(0L);
        when(stockMovementRepository.countByMovementType(StockMovementType.EXIT)).thenReturn(0L);
        when(stockMovementRepository.countByMovementType(StockMovementType.ADJUSTMENT)).thenReturn(0L);

        DashboardMetricsResponse response = reportService.getMetrics();

        assertThat(response.totalStockUnits()).isZero();
        assertThat(response.inventoryValue()).isEqualByComparingTo(BigDecimal.ZERO);
    }

    @Test
    void getCriticalProductsMapsShortageAndUsesLimit() {
        Product product = productWithStock(2, 5);
        when(productRepository.findCriticalActiveProducts(PageRequest.of(0, 3))).thenReturn(List.of(product));

        List<CriticalProductResponse> response = reportService.getCriticalProducts(3);

        assertThat(response).hasSize(1);
        assertThat(response.getFirst().sku()).isEqualTo("DELL-LAT-5440");
        assertThat(response.getFirst().shortage()).isEqualTo(3);
        verify(productRepository).findCriticalActiveProducts(PageRequest.of(0, 3));
    }

    @Test
    void getBestSellingProductsMapsProjectionAndUsesLimit() {
        BestSellingProductProjection projection = projection(3, 18);
        when(stockMovementRepository.findBestSellingProducts(PageRequest.of(0, 5))).thenReturn(List.of(projection));

        List<BestSellingProductResponse> response = reportService.getBestSellingProducts(5);

        assertThat(response).hasSize(1);
        assertThat(response.getFirst().productSku()).isEqualTo("DELL-LAT-5440");
        assertThat(response.getFirst().exitMovementCount()).isEqualTo(3);
        assertThat(response.getFirst().totalSoldUnits()).isEqualTo(18);
    }

    @Test
    void getRecentMovementsMapsMovementHistoryAndUsesLimit() {
        Product product = productWithStock(2, 5);
        StockMovement movement = new StockMovement(
                product,
                null,
                StockMovementType.EXIT,
                8,
                2,
                -6,
                "Entrega"
        );
        ReflectionTestUtils.setField(movement, "id", 10L);
        ReflectionTestUtils.setField(movement, "createdAt", TIMESTAMP);
        when(stockMovementRepository.findAllByOrderByCreatedAtDescIdDesc(PageRequest.of(0, 8)))
                .thenReturn(List.of(movement));

        List<RecentStockMovementResponse> response = reportService.getRecentMovements(8);

        assertThat(response).hasSize(1);
        assertThat(response.getFirst().id()).isEqualTo(10L);
        assertThat(response.getFirst().productSku()).isEqualTo("DELL-LAT-5440");
        assertThat(response.getFirst().movementType()).isEqualTo(StockMovementType.EXIT);
        assertThat(response.getFirst().stockAlert()).isTrue();
        assertThat(response.getFirst().userId()).isNull();
    }

    @Test
    void getRecentMovementsMapsMovementUserWhenPresent() {
        Product product = productWithStock(8, 5);
        InventoryUser user = inventoryUser();
        StockMovement movement = new StockMovement(
                product,
                user,
                StockMovementType.ENTRY,
                5,
                8,
                3,
                "Recepcion"
        );
        ReflectionTestUtils.setField(movement, "id", 11L);
        ReflectionTestUtils.setField(movement, "createdAt", TIMESTAMP);
        when(stockMovementRepository.findAllByOrderByCreatedAtDescIdDesc(PageRequest.of(0, 2)))
                .thenReturn(List.of(movement));

        List<RecentStockMovementResponse> response = reportService.getRecentMovements(2);

        assertThat(response).hasSize(1);
        assertThat(response.getFirst().userId()).isEqualTo(7L);
        assertThat(response.getFirst().username()).isEqualTo("edwin");
        assertThat(response.getFirst().userDisplayName()).isEqualTo("Edwin Balbuena");
        assertThat(response.getFirst().stockAlert()).isFalse();
    }

    @Test
    void getDashboardUsesDefaultSectionLimits() {
        when(productRepository.countByArchivedFalse()).thenReturn(4L);
        when(productRepository.countByStatusAndArchivedFalse(ProductStatus.ACTIVE)).thenReturn(3L);
        when(productRepository.countByStatusAndArchivedFalse(ProductStatus.INACTIVE)).thenReturn(1L);
        when(productRepository.countCriticalActiveProducts()).thenReturn(1L);
        when(productRepository.sumCurrentStock()).thenReturn(26L);
        when(productRepository.calculateInventoryValue()).thenReturn(new BigDecimal("1728000.00"));
        when(stockMovementRepository.count()).thenReturn(8L);
        when(stockMovementRepository.countByMovementType(StockMovementType.INITIAL)).thenReturn(4L);
        when(stockMovementRepository.countByMovementType(StockMovementType.ENTRY)).thenReturn(2L);
        when(stockMovementRepository.countByMovementType(StockMovementType.EXIT)).thenReturn(1L);
        when(stockMovementRepository.countByMovementType(StockMovementType.ADJUSTMENT)).thenReturn(1L);
        when(productRepository.findCriticalActiveProducts(PageRequest.of(0, 5))).thenReturn(List.of(productWithStock(2, 5)));
        when(stockMovementRepository.findBestSellingProducts(PageRequest.of(0, 5))).thenReturn(List.of(projection(3, 18)));
        when(stockMovementRepository.findAllByOrderByCreatedAtDescIdDesc(PageRequest.of(0, 8))).thenReturn(List.of());

        DashboardResponse response = reportService.getDashboard();

        assertThat(response.metrics().totalProducts()).isEqualTo(4);
        assertThat(response.criticalProducts()).hasSize(1);
        assertThat(response.bestSellingProducts()).hasSize(1);
        assertThat(response.recentMovements()).isEmpty();
    }

    private Product productWithStock(int currentStock, int minimumStock) {
        Product product = new Product(new ProductData(
                "DELL-LAT-5440",
                "Dell Latitude 5440",
                "Laptop empresarial",
                "Laptops",
                new BigDecimal("68500.00"),
                currentStock,
                minimumStock,
                ProductStatus.ACTIVE
        ));
        ReflectionTestUtils.setField(product, "id", 1L);
        ReflectionTestUtils.setField(product, "createdAt", TIMESTAMP);
        ReflectionTestUtils.setField(product, "updatedAt", TIMESTAMP);
        return product;
    }

    private InventoryUser inventoryUser() {
        InventoryUser user = BeanUtils.instantiateClass(InventoryUser.class);
        ReflectionTestUtils.setField(user, "id", 7L);
        ReflectionTestUtils.setField(user, "username", "edwin");
        ReflectionTestUtils.setField(user, "displayName", "Edwin Balbuena");
        return user;
    }

    private BestSellingProductProjection projection(long exitMovementCount, long totalSoldUnits) {
        return new BestSellingProductProjection() {
            @Override
            public Long getProductId() {
                return 1L;
            }

            @Override
            public String getProductSku() {
                return "DELL-LAT-5440";
            }

            @Override
            public String getProductName() {
                return "Dell Latitude 5440";
            }

            @Override
            public String getCategory() {
                return "Laptops";
            }

            @Override
            public long getExitMovementCount() {
                return exitMovementCount;
            }

            @Override
            public long getTotalSoldUnits() {
                return totalSoldUnits;
            }

            @Override
            public OffsetDateTime getLastMovementAt() {
                return TIMESTAMP;
            }
        };
    }
}

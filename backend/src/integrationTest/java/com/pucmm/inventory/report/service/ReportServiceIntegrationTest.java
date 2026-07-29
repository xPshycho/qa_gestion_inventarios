package com.pucmm.inventory.report.service;

import static org.assertj.core.api.Assertions.assertThat;

import com.pucmm.inventory.integration.PostgreSqlIntegrationTest;
import com.pucmm.inventory.product.domain.Product;
import com.pucmm.inventory.product.domain.ProductData;
import com.pucmm.inventory.product.domain.ProductStatus;
import com.pucmm.inventory.product.repository.ProductRepository;
import com.pucmm.inventory.report.api.dto.DashboardResponse;
import com.pucmm.inventory.stock.domain.InventoryUser;
import com.pucmm.inventory.stock.domain.StockMovement;
import com.pucmm.inventory.stock.domain.StockMovementType;
import com.pucmm.inventory.stock.repository.InventoryUserRepository;
import com.pucmm.inventory.stock.repository.StockMovementRepository;
import java.math.BigDecimal;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;

@SpringBootTest
class ReportServiceIntegrationTest extends PostgreSqlIntegrationTest {
    @Autowired
    private ReportService reportService;

    @Autowired
    private ProductRepository productRepository;

    @Autowired
    private InventoryUserRepository inventoryUserRepository;

    @Autowired
    private StockMovementRepository stockMovementRepository;

    @Test
    void dashboardReconcilesPersistedProductsAndMovements() {
        Product critical = saveProduct("INT-REPORT-CRITICAL", 2, 5, ProductStatus.ACTIVE);
        Product inactive = saveProduct("INT-REPORT-INACTIVE", 7, 3, ProductStatus.INACTIVE);
        InventoryUser user = inventoryUserRepository.findAll().stream()
                .filter(candidate -> "edwin".equals(candidate.getUsername()))
                .findFirst()
                .orElseThrow();
        stockMovementRepository.saveAndFlush(new StockMovement(
                critical,
                user,
                StockMovementType.EXIT,
                4,
                2,
                -2,
                "Salida cubierta por reporte de integración"
        ));

        DashboardResponse dashboard = reportService.getDashboard();

        assertThat(dashboard.metrics().totalProducts()).isGreaterThanOrEqualTo(2);
        assertThat(dashboard.metrics().activeProducts()).isGreaterThanOrEqualTo(1);
        assertThat(dashboard.metrics().inactiveProducts()).isGreaterThanOrEqualTo(1);
        assertThat(dashboard.metrics().criticalProducts()).isGreaterThanOrEqualTo(1);
        assertThat(dashboard.metrics().totalStockUnits()).isGreaterThanOrEqualTo(9);
        assertThat(dashboard.metrics().inventoryValue()).isGreaterThan(BigDecimal.ZERO);
        assertThat(dashboard.metrics().exitMovements()).isGreaterThanOrEqualTo(1);
        assertThat(dashboard.criticalProducts())
                .anySatisfy(product -> {
                    assertThat(product.id()).isEqualTo(critical.getId());
                    assertThat(product.shortage()).isEqualTo(3);
                });
        assertThat(dashboard.mostMovedProducts())
                .anySatisfy(product -> {
                    assertThat(product.productId()).isEqualTo(critical.getId());
                    assertThat(product.totalMovedUnits()).isEqualTo(2);
                });
        assertThat(dashboard.recentMovements())
                .anySatisfy(movement -> {
                    assertThat(movement.productId()).isEqualTo(critical.getId());
                    assertThat(movement.userId()).isEqualTo(user.getId());
                    assertThat(movement.username()).isEqualTo("edwin");
                    assertThat(movement.stockAlert()).isTrue();
                });
        assertThat(inactive.getStatus()).isEqualTo(ProductStatus.INACTIVE);
    }

    @Test
    void emptyDatabaseAggregatesUseZeroValues() {
        stockMovementRepository.deleteAll();
        productRepository.deleteAll();

        DashboardResponse dashboard = reportService.getDashboard();

        assertThat(dashboard.metrics().totalProducts()).isZero();
        assertThat(dashboard.metrics().totalStockUnits()).isZero();
        assertThat(dashboard.metrics().inventoryValue()).isEqualByComparingTo(BigDecimal.ZERO);
        assertThat(dashboard.metrics().totalMovements()).isZero();
        assertThat(dashboard.criticalProducts()).isEmpty();
        assertThat(dashboard.mostMovedProducts()).isEmpty();
        assertThat(dashboard.recentMovements()).isEmpty();
    }

    private Product saveProduct(
            String sku,
            int currentStock,
            int minimumStock,
            ProductStatus status
    ) {
        return productRepository.saveAndFlush(new Product(new ProductData(
                sku,
                "Producto para reporte",
                "Datos de integración para dashboard",
                "Pruebas",
                new BigDecimal("125.50"),
                currentStock,
                minimumStock,
                status
        )));
    }
}

package com.pucmm.inventory.observability;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.when;

import com.pucmm.inventory.product.repository.ProductRepository;
import com.pucmm.inventory.stock.repository.StockMovementRepository;
import io.micrometer.core.instrument.simple.SimpleMeterRegistry;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;

class InventoryObservabilityConfigurationTest {
    private final InventoryObservabilityConfiguration configuration = new InventoryObservabilityConfiguration();

    @Test
    void registersInventoryGaugesWithRepositoryValues() {
        ProductRepository productRepository = Mockito.mock(ProductRepository.class);
        StockMovementRepository stockMovementRepository = Mockito.mock(StockMovementRepository.class);
        when(productRepository.countCriticalActiveProducts()).thenReturn(3L);
        when(productRepository.sumCurrentStock()).thenReturn(null);
        when(stockMovementRepository.count()).thenReturn(7L);

        SimpleMeterRegistry meterRegistry = new SimpleMeterRegistry();
        InventoryObservabilityConfiguration.InventoryBusinessMetrics metrics = configuration.inventoryBusinessMetrics(
                meterRegistry,
                productRepository,
                stockMovementRepository
        );

        assertThat(metrics).isNotNull();
        assertThat(meterRegistry.get("inventory.products.critical").gauge().value()).isEqualTo(3.0);
        assertThat(meterRegistry.get("inventory.stock.units").gauge().value()).isZero();
        assertThat(meterRegistry.get("inventory.stock.movements").gauge().value()).isEqualTo(7.0);

        when(productRepository.sumCurrentStock()).thenReturn(12L);

        assertThat(meterRegistry.get("inventory.stock.units").gauge().value()).isEqualTo(12.0);
    }
}

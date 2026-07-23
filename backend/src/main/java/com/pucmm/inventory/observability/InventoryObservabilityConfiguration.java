package com.pucmm.inventory.observability;

import com.pucmm.inventory.product.repository.ProductRepository;
import com.pucmm.inventory.stock.repository.StockMovementRepository;
import io.micrometer.core.instrument.Gauge;
import io.micrometer.core.instrument.MeterRegistry;
import org.springframework.boot.autoconfigure.condition.ConditionalOnBean;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/** Publishes low-cardinality inventory indicators for the business dashboard. */
@Configuration
@ConditionalOnBean({ProductRepository.class, StockMovementRepository.class})
public class InventoryObservabilityConfiguration {
    @Bean
    InventoryBusinessMetrics inventoryBusinessMetrics(
            MeterRegistry meterRegistry,
            ProductRepository productRepository,
            StockMovementRepository stockMovementRepository
    ) {
        Gauge.builder("inventory.products.critical", productRepository, ProductRepository::countCriticalActiveProducts)
                .description("Active products at or below their minimum stock")
                .register(meterRegistry);
        Gauge.builder("inventory.stock.units", productRepository, repository -> safeLong(repository.sumCurrentStock()))
                .description("Current stock units across all products")
                .register(meterRegistry);
        Gauge.builder("inventory.stock.movements", stockMovementRepository, StockMovementRepository::count)
                .description("Persisted stock movements")
                .register(meterRegistry);
        return new InventoryBusinessMetrics();
    }

    private static long safeLong(Long value) {
        return value == null ? 0L : value;
    }

    static final class InventoryBusinessMetrics {
    }
}

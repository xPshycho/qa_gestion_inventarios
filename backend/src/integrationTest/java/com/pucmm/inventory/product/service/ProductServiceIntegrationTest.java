package com.pucmm.inventory.product.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.pucmm.inventory.integration.PostgreSqlIntegrationTest;
import com.pucmm.inventory.product.api.dto.ProductRequest;
import com.pucmm.inventory.product.api.dto.ProductResponse;
import com.pucmm.inventory.product.domain.ProductStatus;
import com.pucmm.inventory.product.repository.ProductRepository;
import java.math.BigDecimal;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;

@SpringBootTest
class ProductServiceIntegrationTest extends PostgreSqlIntegrationTest {
    @Autowired
    private ProductService productService;

    @Autowired
    private ProductRepository productRepository;

    @Test
    void productCrudPersistsChangesInPostgreSql() {
        ProductResponse created = productService.createProduct(request(
                "INT-CRUD-001",
                "Monitor Dell P2425H",
                new BigDecimal("14900.00"),
                8,
                ProductStatus.ACTIVE
        ));

        assertThat(created.id()).isNotNull();
        assertThat(productRepository.findById(created.id()))
                .get()
                .extracting(product -> product.getSku(), product -> product.getCurrentStock())
                .containsExactly("INT-CRUD-001", 8);

        ProductResponse updated = productService.updateProduct(created.id(), request(
                "INT-CRUD-001",
                "Monitor Dell P2425H USB-C",
                new BigDecimal("16900.00"),
                8,
                ProductStatus.INACTIVE
        ));
        ProductResponse loaded = productService.getProduct(created.id());

        assertThat(updated.name()).isEqualTo("Monitor Dell P2425H USB-C");
        assertThat(loaded.price()).isEqualByComparingTo("16900.00");
        assertThat(loaded.currentStock()).isEqualTo(8);
        assertThat(loaded.status()).isEqualTo(ProductStatus.INACTIVE);

        assertThatThrownBy(() -> productService.updateProduct(created.id(), request(
                "INT-CRUD-001",
                "Monitor Dell P2425H USB-C",
                new BigDecimal("16900.00"),
                6,
                ProductStatus.INACTIVE
        ))).isInstanceOf(DirectStockUpdateException.class);

        productService.deleteProduct(created.id());

        assertThat(productRepository.existsById(created.id())).isFalse();
        assertThatThrownBy(() -> productService.getProduct(created.id()))
                .isInstanceOf(ProductNotFoundException.class);
    }

    private ProductRequest request(
            String sku,
            String name,
            BigDecimal price,
            int currentStock,
            ProductStatus status
    ) {
        return new ProductRequest(
                sku,
                name,
                "Producto creado por pruebas de integracion",
                "Perifericos",
                price,
                currentStock,
                3,
                status
        );
    }
}

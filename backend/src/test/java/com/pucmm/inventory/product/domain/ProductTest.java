package com.pucmm.inventory.product.domain;

import static org.assertj.core.api.Assertions.assertThat;

import java.math.BigDecimal;
import org.junit.jupiter.api.Test;

class ProductTest {
    @Test
    void prePersistSetsUtcTimestamps() {
        Product product = new Product(productData("DELL-LAT-5440"));

        product.prePersist();

        assertThat(product.getCreatedAt()).isNotNull();
        assertThat(product.getUpdatedAt()).isEqualTo(product.getCreatedAt());
        assertThat(product.getCreatedAt().getOffset().getTotalSeconds()).isZero();
    }

    @Test
    void preUpdateRefreshesUpdatedAtInUtc() {
        Product product = new Product(productData("DELL-LAT-5440"));
        product.prePersist();

        product.preUpdate();

        assertThat(product.getUpdatedAt()).isNotNull();
        assertThat(product.getUpdatedAt().getOffset().getTotalSeconds()).isZero();
    }

    @Test
    void updateAppliesProductData() {
        Product product = new Product(productData("DELL-LAT-5440"));

        product.update(productData("LEN-T14-G4"));

        assertThat(product.getSku()).isEqualTo("LEN-T14-G4");
        assertThat(product.getName()).isEqualTo("Dell Latitude 5440");
        assertThat(product.getCategory()).isEqualTo("Laptops");
    }

    private ProductData productData(String sku) {
        return new ProductData(
                sku,
                "Dell Latitude 5440",
                "Laptop empresarial Dell Latitude 5440 con pantalla de 14 pulgadas",
                "Laptops",
                new BigDecimal("68500.00"),
                12,
                4,
                ProductStatus.ACTIVE
        );
    }
}

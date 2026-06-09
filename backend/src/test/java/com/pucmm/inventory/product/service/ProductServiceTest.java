package com.pucmm.inventory.product.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.pucmm.inventory.product.api.dto.ProductPageResponse;
import com.pucmm.inventory.product.api.dto.ProductRequest;
import com.pucmm.inventory.product.api.dto.ProductResponse;
import com.pucmm.inventory.product.domain.Product;
import com.pucmm.inventory.product.domain.ProductData;
import com.pucmm.inventory.product.domain.ProductStatus;
import com.pucmm.inventory.product.repository.ProductRepository;
import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.test.util.ReflectionTestUtils;

@ExtendWith(MockitoExtension.class)
class ProductServiceTest {
    @Mock
    private ProductRepository productRepository;

    @InjectMocks
    private ProductService productService;

    @Test
    void findProductsReturnsPaginatedProducts() {
        Product product = productWithId(1L, "DELL-LAT-5440");
        when(productRepository.findAll(org.mockito.ArgumentMatchers.<Specification<Product>>any(), any(Pageable.class)))
                .thenReturn(new PageImpl<>(List.of(product), PageRequest.of(0, 20), 1));

        ProductPageResponse response = productService.findProducts(
                0,
                20,
                "latitude",
                "Laptops",
                ProductStatus.ACTIVE,
                "name",
                "desc"
        );

        assertThat(response.content()).hasSize(1);
        assertThat(response.content().getFirst().sku()).isEqualTo("DELL-LAT-5440");
        assertThat(response.totalElements()).isEqualTo(1);
        ArgumentCaptor<Pageable> pageableCaptor = ArgumentCaptor.forClass(Pageable.class);
        verify(productRepository).findAll(org.mockito.ArgumentMatchers.<Specification<Product>>any(), pageableCaptor.capture());
        assertThat(pageableCaptor.getValue().getSort().getOrderFor("name"))
                .extracting(Sort.Order::getDirection)
                .isEqualTo(Sort.Direction.DESC);
    }

    @Test
    void getProductReturnsExistingProduct() {
        when(productRepository.findById(1L)).thenReturn(Optional.of(productWithId(1L, "DELL-LAT-5440")));

        ProductResponse response = productService.getProduct(1L);

        assertThat(response.id()).isEqualTo(1L);
        assertThat(response.sku()).isEqualTo("DELL-LAT-5440");
    }

    @Test
    void getProductThrowsWhenProductDoesNotExist() {
        when(productRepository.findById(99L)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> productService.getProduct(99L))
                .isInstanceOf(ProductNotFoundException.class)
                .hasMessageContaining("99");
    }

    @Test
    void createProductSavesValidProduct() {
        ProductRequest request = request("DELL-LAT-5440");
        when(productRepository.existsBySkuIgnoreCase("DELL-LAT-5440")).thenReturn(false);
        when(productRepository.save(any(Product.class))).thenAnswer(invocation -> {
            Product product = invocation.getArgument(0);
            setPersistenceFields(product, 1L);
            return product;
        });

        ProductResponse response = productService.createProduct(request);

        assertThat(response.id()).isEqualTo(1L);
        assertThat(response.sku()).isEqualTo("DELL-LAT-5440");
        ArgumentCaptor<Product> productCaptor = ArgumentCaptor.forClass(Product.class);
        verify(productRepository).save(productCaptor.capture());
        assertThat(productCaptor.getValue().getName()).isEqualTo("Dell Latitude 5440");
    }

    @Test
    void createProductRejectsDuplicateSku() {
        ProductRequest request = request("DELL-LAT-5440");
        when(productRepository.existsBySkuIgnoreCase("DELL-LAT-5440")).thenReturn(true);

        assertThatThrownBy(() -> productService.createProduct(request))
                .isInstanceOf(DuplicateSkuException.class)
                .hasMessageContaining("DELL-LAT-5440");
    }

    @Test
    void updateProductChangesExistingProduct() {
        Product existing = productWithId(1L, "DELL-LAT-5440");
        ProductRequest request = request("LEN-T14-G4");
        when(productRepository.findById(1L)).thenReturn(Optional.of(existing));
        when(productRepository.existsBySkuIgnoreCaseAndIdNot("LEN-T14-G4", 1L)).thenReturn(false);
        when(productRepository.save(existing)).thenReturn(existing);

        ProductResponse response = productService.updateProduct(1L, request);

        assertThat(response.sku()).isEqualTo("LEN-T14-G4");
        assertThat(response.name()).isEqualTo("Dell Latitude 5440");
    }

    @Test
    void updateProductRejectsDuplicateSku() {
        Product existing = productWithId(1L, "DELL-LAT-5440");
        ProductRequest request = request("LEN-T14-G4");
        when(productRepository.findById(1L)).thenReturn(Optional.of(existing));
        when(productRepository.existsBySkuIgnoreCaseAndIdNot("LEN-T14-G4", 1L)).thenReturn(true);

        assertThatThrownBy(() -> productService.updateProduct(1L, request))
                .isInstanceOf(DuplicateSkuException.class)
                .hasMessageContaining("LEN-T14-G4");
    }

    @Test
    void deleteProductDeletesExistingProduct() {
        Product existing = productWithId(1L, "DELL-LAT-5440");
        when(productRepository.findById(1L)).thenReturn(Optional.of(existing));

        productService.deleteProduct(1L);

        verify(productRepository).delete(existing);
    }

    private ProductRequest request(String sku) {
        return new ProductRequest(
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

    private Product productWithId(Long id, String sku) {
        Product product = new Product(new ProductData(
                sku,
                "Dell Latitude 5440",
                "Laptop empresarial Dell Latitude 5440 con pantalla de 14 pulgadas",
                "Laptops",
                new BigDecimal("68500.00"),
                12,
                4,
                ProductStatus.ACTIVE
        ));
        setPersistenceFields(product, id);
        return product;
    }

    private void setPersistenceFields(Product product, Long id) {
        OffsetDateTime now = OffsetDateTime.parse("2026-06-07T12:00:00-04:00");
        ReflectionTestUtils.setField(product, "id", id);
        ReflectionTestUtils.setField(product, "createdAt", now);
        ReflectionTestUtils.setField(product, "updatedAt", now);
    }
}

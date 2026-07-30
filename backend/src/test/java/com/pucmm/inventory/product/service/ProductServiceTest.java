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
import com.pucmm.inventory.stock.domain.InventoryUser;
import com.pucmm.inventory.stock.domain.StockMovement;
import com.pucmm.inventory.stock.domain.StockMovementType;
import com.pucmm.inventory.stock.repository.InventoryUserRepository;
import com.pucmm.inventory.stock.repository.StockMovementRepository;
import jakarta.persistence.criteria.CriteriaBuilder;
import jakarta.persistence.criteria.CriteriaQuery;
import jakarta.persistence.criteria.Expression;
import jakarta.persistence.criteria.Path;
import jakarta.persistence.criteria.Predicate;
import jakarta.persistence.criteria.Root;
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

    @Mock
    private InventoryUserRepository inventoryUserRepository;

    @Mock
    private StockMovementRepository stockMovementRepository;

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
    void findProductsSpecificationAppliesAllFilters() {
        Product product = productWithId(1L, "DELL-LAT-5440");
        when(productRepository.findAll(org.mockito.ArgumentMatchers.<Specification<Product>>any(), any(Pageable.class)))
                .thenReturn(new PageImpl<>(List.of(product), PageRequest.of(0, 20), 1));
        CriteriaMocks criteria = CriteriaMocks.create();

        productService.findProducts(0, 20, " Latitude ", " Laptops ", ProductStatus.ACTIVE, "name", "asc");

        Specification<Product> specification = captureSpecification();
        Predicate predicate = specification.toPredicate(criteria.root, criteria.query, criteria.builder);

        assertThat(predicate).isSameAs(criteria.combinedPredicate);
        verify(criteria.builder).like(criteria.lowerName, "%latitude%");
        verify(criteria.builder).like(criteria.lowerSku, "%latitude%");
        verify(criteria.builder).like(criteria.lowerDescription, "%latitude%");
        verify(criteria.builder).equal(criteria.lowerCategory, "laptops");
        verify(criteria.builder).equal(criteria.statusPath, ProductStatus.ACTIVE);
        verify(criteria.builder).and(org.mockito.ArgumentMatchers.any(Predicate[].class));
    }

    @Test
    void findProductsSpecificationIgnoresBlankFilters() {
        Product product = productWithId(1L, "DELL-LAT-5440");
        when(productRepository.findAll(org.mockito.ArgumentMatchers.<Specification<Product>>any(), any(Pageable.class)))
                .thenReturn(new PageImpl<>(List.of(product), PageRequest.of(0, 20), 1));
        CriteriaMocks criteria = CriteriaMocks.create();

        productService.findProducts(0, 20, "   ", "", null, "name", "asc");

        Specification<Product> specification = captureSpecification();
        Predicate predicate = specification.toPredicate(criteria.root, criteria.query, criteria.builder);

        assertThat(predicate).isSameAs(criteria.combinedPredicate);
        verify(criteria.builder).and(org.mockito.ArgumentMatchers.any(Predicate[].class));
    }

    @Test
    void getProductReturnsExistingProduct() {
        when(productRepository.findByIdAndArchivedFalse(1L)).thenReturn(Optional.of(productWithId(1L, "DELL-LAT-5440")));

        ProductResponse response = productService.getProduct(1L);

        assertThat(response.id()).isEqualTo(1L);
        assertThat(response.sku()).isEqualTo("DELL-LAT-5440");
    }

    @Test
    void getProductThrowsWhenProductDoesNotExist() {
        when(productRepository.findByIdAndArchivedFalse(99L)).thenReturn(Optional.empty());

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
        InventoryUser actor = inventoryUser();
        when(inventoryUserRepository.findByUsernameIgnoreCase("edwin")).thenReturn(Optional.of(actor));
        when(stockMovementRepository.save(any(StockMovement.class))).thenAnswer(invocation -> invocation.getArgument(0));

        ProductResponse response = productService.createProduct(request, "edwin");

        assertThat(response.id()).isEqualTo(1L);
        assertThat(response.sku()).isEqualTo("DELL-LAT-5440");
        ArgumentCaptor<Product> productCaptor = ArgumentCaptor.forClass(Product.class);
        verify(productRepository).save(productCaptor.capture());
        assertThat(productCaptor.getValue().getName()).isEqualTo("Dell Latitude 5440");
        ArgumentCaptor<StockMovement> movementCaptor = ArgumentCaptor.forClass(StockMovement.class);
        verify(stockMovementRepository).save(movementCaptor.capture());
        assertThat(movementCaptor.getValue().getMovementType()).isEqualTo(StockMovementType.INITIAL);
        assertThat(movementCaptor.getValue().getPreviousQuantity()).isZero();
        assertThat(movementCaptor.getValue().getNewQuantity()).isEqualTo(12);
        assertThat(movementCaptor.getValue().getUser()).isSameAs(actor);
    }

    @Test
    void createProductRejectsDuplicateSku() {
        ProductRequest request = request("DELL-LAT-5440");
        when(productRepository.existsBySkuIgnoreCase("DELL-LAT-5440")).thenReturn(true);

        assertThatThrownBy(() -> productService.createProduct(request, "edwin"))
                .isInstanceOf(DuplicateSkuException.class)
                .hasMessageContaining("DELL-LAT-5440");
    }

    @Test
    void updateProductChangesExistingProduct() {
        Product existing = productWithId(1L, "DELL-LAT-5440");
        ProductRequest request = request("LEN-T14-G4");
        when(productRepository.findByIdAndArchivedFalse(1L)).thenReturn(Optional.of(existing));
        when(productRepository.existsBySkuIgnoreCaseAndIdNot("LEN-T14-G4", 1L)).thenReturn(false);
        when(productRepository.save(existing)).thenReturn(existing);

        ProductResponse response = productService.updateProduct(1L, request);

        assertThat(response.sku()).isEqualTo("LEN-T14-G4");
        assertThat(response.name()).isEqualTo("Dell Latitude 5440");
        assertThat(response.currentStock()).isEqualTo(12);
    }

    @Test
    void updateProductRejectsDirectStockChange() {
        Product existing = productWithId(1L, "DELL-LAT-5440");
        ProductRequest request = request("LEN-T14-G4", 9);
        when(productRepository.findByIdAndArchivedFalse(1L)).thenReturn(Optional.of(existing));
        when(productRepository.existsBySkuIgnoreCaseAndIdNot("LEN-T14-G4", 1L)).thenReturn(false);

        assertThatThrownBy(() -> productService.updateProduct(1L, request))
                .isInstanceOf(DirectStockUpdateException.class)
                .hasMessageContaining("currentStock");
    }

    @Test
    void updateProductRejectsDuplicateSku() {
        Product existing = productWithId(1L, "DELL-LAT-5440");
        ProductRequest request = request("LEN-T14-G4");
        when(productRepository.findByIdAndArchivedFalse(1L)).thenReturn(Optional.of(existing));
        when(productRepository.existsBySkuIgnoreCaseAndIdNot("LEN-T14-G4", 1L)).thenReturn(true);

        assertThatThrownBy(() -> productService.updateProduct(1L, request))
                .isInstanceOf(DuplicateSkuException.class)
                .hasMessageContaining("LEN-T14-G4");
    }

    @Test
    void deleteProductArchivesExistingProductAndPreservesHistory() {
        Product existing = productWithId(1L, "DELL-LAT-5440");
        when(productRepository.findByIdAndArchivedFalse(1L)).thenReturn(Optional.of(existing));
        when(productRepository.save(existing)).thenReturn(existing);

        productService.deleteProduct(1L);

        verify(productRepository).save(existing);
        assertThat(existing.isArchived()).isTrue();
        assertThat(existing.getStatus()).isEqualTo(ProductStatus.INACTIVE);
    }

    private ProductRequest request(String sku) {
        return request(sku, 12);
    }

    private ProductRequest request(String sku, int currentStock) {
        return new ProductRequest(
                sku,
                "Dell Latitude 5440",
                "Laptop empresarial Dell Latitude 5440 con pantalla de 14 pulgadas",
                "Laptops",
                new BigDecimal("68500.00"),
                currentStock,
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

    private InventoryUser inventoryUser() {
        InventoryUser user = org.springframework.beans.BeanUtils.instantiateClass(InventoryUser.class);
        ReflectionTestUtils.setField(user, "id", 7L);
        ReflectionTestUtils.setField(user, "username", "edwin");
        ReflectionTestUtils.setField(user, "displayName", "Edwin Balbuena");
        return user;
    }

    private void setPersistenceFields(Product product, Long id) {
        OffsetDateTime now = OffsetDateTime.parse("2026-06-07T12:00:00-04:00");
        ReflectionTestUtils.setField(product, "id", id);
        ReflectionTestUtils.setField(product, "createdAt", now);
        ReflectionTestUtils.setField(product, "updatedAt", now);
    }

    @SuppressWarnings("unchecked")
    private Specification<Product> captureSpecification() {
        ArgumentCaptor<Specification<Product>> specificationCaptor = ArgumentCaptor.forClass(Specification.class);
        verify(productRepository).findAll(specificationCaptor.capture(), any(Pageable.class));
        return specificationCaptor.getValue();
    }

    private static final class CriteriaMocks {
        private final Root<Product> root;
        private final CriteriaQuery<?> query;
        private final CriteriaBuilder builder;
        private final Expression<String> lowerName;
        private final Expression<String> lowerSku;
        private final Expression<String> lowerDescription;
        private final Expression<String> lowerCategory;
        private final Path<ProductStatus> statusPath;
        private final Predicate searchPredicate;
        private final Predicate categoryPredicate;
        private final Predicate statusPredicate;
        private final Predicate combinedPredicate;

        private CriteriaMocks(
                Root<Product> root,
                CriteriaQuery<?> query,
                CriteriaBuilder builder,
                Expression<String> lowerName,
                Expression<String> lowerSku,
                Expression<String> lowerDescription,
                Expression<String> lowerCategory,
                Path<ProductStatus> statusPath,
                Predicate searchPredicate,
                Predicate categoryPredicate,
                Predicate statusPredicate,
                Predicate combinedPredicate
        ) {
            this.root = root;
            this.query = query;
            this.builder = builder;
            this.lowerName = lowerName;
            this.lowerSku = lowerSku;
            this.lowerDescription = lowerDescription;
            this.lowerCategory = lowerCategory;
            this.statusPath = statusPath;
            this.searchPredicate = searchPredicate;
            this.categoryPredicate = categoryPredicate;
            this.statusPredicate = statusPredicate;
            this.combinedPredicate = combinedPredicate;
        }

        @SuppressWarnings("unchecked")
        private static CriteriaMocks create() {
            Root<Product> root = org.mockito.Mockito.mock(Root.class);
            CriteriaQuery<?> query = org.mockito.Mockito.mock(CriteriaQuery.class);
            CriteriaBuilder builder = org.mockito.Mockito.mock(CriteriaBuilder.class);
            Path<String> namePath = org.mockito.Mockito.mock(Path.class);
            Path<String> skuPath = org.mockito.Mockito.mock(Path.class);
            Path<String> descriptionPath = org.mockito.Mockito.mock(Path.class);
            Path<String> categoryPath = org.mockito.Mockito.mock(Path.class);
            Path<ProductStatus> statusPath = org.mockito.Mockito.mock(Path.class);
            Expression<String> lowerName = org.mockito.Mockito.mock(Expression.class);
            Expression<String> lowerSku = org.mockito.Mockito.mock(Expression.class);
            Expression<String> lowerDescription = org.mockito.Mockito.mock(Expression.class);
            Expression<String> lowerCategory = org.mockito.Mockito.mock(Expression.class);
            Predicate namePredicate = org.mockito.Mockito.mock(Predicate.class);
            Predicate skuPredicate = org.mockito.Mockito.mock(Predicate.class);
            Predicate descriptionPredicate = org.mockito.Mockito.mock(Predicate.class);
            Predicate searchPredicate = org.mockito.Mockito.mock(Predicate.class);
            Predicate categoryPredicate = org.mockito.Mockito.mock(Predicate.class);
            Predicate statusPredicate = org.mockito.Mockito.mock(Predicate.class);
            Predicate combinedPredicate = org.mockito.Mockito.mock(Predicate.class);

            org.mockito.Mockito.lenient().when(root.<String>get("name")).thenReturn(namePath);
            org.mockito.Mockito.lenient().when(root.<String>get("sku")).thenReturn(skuPath);
            org.mockito.Mockito.lenient().when(root.<String>get("description")).thenReturn(descriptionPath);
            org.mockito.Mockito.lenient().when(root.<String>get("category")).thenReturn(categoryPath);
            org.mockito.Mockito.lenient().when(root.<ProductStatus>get("status")).thenReturn(statusPath);
            org.mockito.Mockito.lenient().when(builder.lower(namePath)).thenReturn(lowerName);
            org.mockito.Mockito.lenient().when(builder.lower(skuPath)).thenReturn(lowerSku);
            org.mockito.Mockito.lenient().when(builder.lower(descriptionPath)).thenReturn(lowerDescription);
            org.mockito.Mockito.lenient().when(builder.lower(categoryPath)).thenReturn(lowerCategory);
            org.mockito.Mockito.lenient().when(builder.like(lowerName, "%latitude%")).thenReturn(namePredicate);
            org.mockito.Mockito.lenient().when(builder.like(lowerSku, "%latitude%")).thenReturn(skuPredicate);
            org.mockito.Mockito.lenient().when(builder.like(lowerDescription, "%latitude%")).thenReturn(descriptionPredicate);
            org.mockito.Mockito.lenient().when(builder.or(namePredicate, skuPredicate, descriptionPredicate))
                    .thenReturn(searchPredicate);
            org.mockito.Mockito.lenient().when(builder.equal(lowerCategory, "laptops")).thenReturn(categoryPredicate);
            org.mockito.Mockito.lenient().when(builder.equal(statusPath, ProductStatus.ACTIVE)).thenReturn(statusPredicate);
            org.mockito.Mockito.when(builder.and(org.mockito.ArgumentMatchers.any(Predicate[].class)))
                    .thenReturn(combinedPredicate);

            return new CriteriaMocks(
                    root,
                    query,
                    builder,
                    lowerName,
                    lowerSku,
                    lowerDescription,
                    lowerCategory,
                    statusPath,
                    searchPredicate,
                    categoryPredicate,
                    statusPredicate,
                    combinedPredicate
            );
        }
    }
}

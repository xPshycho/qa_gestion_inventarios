package com.pucmm.inventory.audit.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.mockStatic;
import static org.mockito.Mockito.when;

import com.pucmm.inventory.audit.api.dto.AuditRevisionResponse;
import com.pucmm.inventory.audit.domain.InventoryRevisionEntity;
import com.pucmm.inventory.product.domain.Product;
import com.pucmm.inventory.product.domain.ProductData;
import com.pucmm.inventory.product.domain.ProductStatus;
import com.pucmm.inventory.product.repository.ProductRepository;
import com.pucmm.inventory.product.service.ProductNotFoundException;
import com.pucmm.inventory.stock.domain.InventoryUser;
import com.pucmm.inventory.stock.domain.StockMovement;
import com.pucmm.inventory.stock.domain.StockMovementType;
import jakarta.persistence.EntityManager;
import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.List;
import org.hibernate.envers.AuditReader;
import org.hibernate.envers.AuditReaderFactory;
import org.hibernate.envers.RevisionType;
import org.hibernate.envers.query.AuditQuery;
import org.hibernate.envers.query.AuditQueryCreator;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.MockedStatic;
import org.springframework.test.util.ReflectionTestUtils;

class AuditServiceTest {
    private static final OffsetDateTime TIMESTAMP = OffsetDateTime.parse("2026-06-07T12:00:00Z");

    private ProductRepository productRepository;
    private EntityManager entityManager;
    private AuditService auditService;

    @BeforeEach
    void setUp() {
        productRepository = mock(ProductRepository.class);
        entityManager = mock(EntityManager.class);
        auditService = new AuditService(productRepository);
        ReflectionTestUtils.setField(auditService, "entityManager", entityManager);
    }

    @Test
    void findProductRevisionsMapsPreviousAndCurrentValues() {
        Product first = product(1L, "AUD-001", 12);
        Product second = product(1L, "AUD-001", 7);
        InventoryRevisionEntity addRevision = revision(1, "edwin");
        InventoryRevisionEntity modRevision = revision(2, "edwin");
        AuditQuery query = productRevisionQuery(List.of(
                new Object[] {first, addRevision, RevisionType.ADD},
                new Object[] {second, modRevision, RevisionType.MOD}
        ));

        when(productRepository.existsById(1L)).thenReturn(true);

        try (MockedStatic<AuditReaderFactory> auditReaderFactory = mockStatic(AuditReaderFactory.class)) {
            mockAuditReader(auditReaderFactory, query);

            List<AuditRevisionResponse> revisions = auditService.findProductRevisions(1L);

            assertThat(revisions).hasSize(2);
            assertThat(revisions.get(0).entityName()).isEqualTo("Product");
            assertThat(revisions.get(0).previousValues()).isEmpty();
            assertThat(revisions.get(0).currentValues())
                    .containsEntry("id", 1L)
                    .containsEntry("sku", "AUD-001")
                    .containsEntry("currentStock", 12);
            assertThat(revisions.get(1).revisionType()).isEqualTo("MOD");
            assertThat(revisions.get(1).previousValues()).containsEntry("currentStock", 12);
            assertThat(revisions.get(1).currentValues()).containsEntry("currentStock", 7);
        }
    }

    @Test
    void findProductStockMovementRevisionsTracksPreviousValuesByMovement() {
        Product product = product(1L, "AUD-STOCK-001", 10);
        InventoryUser user = user(3L);
        StockMovement first = movement(5L, product, user, 10, 15, 5);
        StockMovement second = movement(5L, product, user, 15, 11, -4);
        InventoryRevisionEntity addRevision = revision(1, "carlos");
        InventoryRevisionEntity modRevision = revision(2, "carlos");
        AuditQuery query = stockMovementRevisionQuery(List.of(
                new Object[] {first, addRevision, RevisionType.ADD},
                new Object[] {second, modRevision, RevisionType.MOD}
        ));

        when(productRepository.existsById(1L)).thenReturn(true);

        try (MockedStatic<AuditReaderFactory> auditReaderFactory = mockStatic(AuditReaderFactory.class)) {
            mockAuditReader(auditReaderFactory, query);

            List<AuditRevisionResponse> revisions = auditService.findProductStockMovementRevisions(1L);

            assertThat(revisions).hasSize(2);
            assertThat(revisions.get(0).entityName()).isEqualTo("StockMovement");
            assertThat(revisions.get(0).currentValues())
                    .containsEntry("productId", 1L)
                    .containsEntry("userId", 3L)
                    .containsEntry("movementType", StockMovementType.ENTRY)
                    .containsEntry("newQuantity", 15);
            assertThat(revisions.get(1).revisionType()).isEqualTo("MOD");
            assertThat(revisions.get(1).previousValues()).containsEntry("newQuantity", 15);
            assertThat(revisions.get(1).currentValues()).containsEntry("newQuantity", 11);
        }
    }

    @Test
    void findProductRevisionsRejectsUnknownProduct() {
        when(productRepository.existsById(99L)).thenReturn(false);

        assertThatThrownBy(() -> auditService.findProductRevisions(99L))
                .isInstanceOf(ProductNotFoundException.class)
                .hasMessageContaining("99");
    }

    private AuditQuery productRevisionQuery(List<Object[]> revisions) {
        AuditQuery query = mock(AuditQuery.class);
        when(query.add(any())).thenReturn(query);
        when(query.addOrder(any())).thenReturn(query);
        when(query.getResultList()).thenReturn(revisions);
        return query;
    }

    private AuditQuery stockMovementRevisionQuery(List<Object[]> revisions) {
        return productRevisionQuery(revisions);
    }

    private void mockAuditReader(MockedStatic<AuditReaderFactory> auditReaderFactory, AuditQuery query) {
        AuditReader reader = mock(AuditReader.class);
        AuditQueryCreator queryCreator = mock(AuditQueryCreator.class);
        auditReaderFactory.when(() -> AuditReaderFactory.get(entityManager)).thenReturn(reader);
        when(reader.createQuery()).thenReturn(queryCreator);
        when(queryCreator.forRevisionsOfEntity(Product.class, false, true)).thenReturn(query);
        when(queryCreator.forRevisionsOfEntity(StockMovement.class, false, true)).thenReturn(query);
    }

    private Product product(Long id, String sku, int currentStock) {
        Product product = new Product(new ProductData(
                sku,
                "Dell Latitude 5440",
                "Laptop empresarial",
                "Laptops",
                new BigDecimal("68500.00"),
                currentStock,
                4,
                ProductStatus.ACTIVE
        ));
        ReflectionTestUtils.setField(product, "id", id);
        ReflectionTestUtils.setField(product, "createdAt", TIMESTAMP);
        ReflectionTestUtils.setField(product, "updatedAt", TIMESTAMP.plusHours(1));
        return product;
    }

    private StockMovement movement(
            Long id,
            Product product,
            InventoryUser user,
            int previousQuantity,
            int newQuantity,
            int deltaQuantity
    ) {
        StockMovement movement = new StockMovement(
                product,
                user,
                StockMovementType.ENTRY,
                previousQuantity,
                newQuantity,
                deltaQuantity,
                "Movimiento auditado"
        );
        ReflectionTestUtils.setField(movement, "id", id);
        ReflectionTestUtils.setField(movement, "createdAt", TIMESTAMP);
        return movement;
    }

    private InventoryUser user(Long id) {
        InventoryUser user = mock(InventoryUser.class);
        when(user.getId()).thenReturn(id);
        return user;
    }

    private InventoryRevisionEntity revision(Integer id, String username) {
        InventoryRevisionEntity revision = new InventoryRevisionEntity();
        ReflectionTestUtils.setField(revision, "id", id);
        ReflectionTestUtils.setField(revision, "revisionTimestamp", TIMESTAMP.toInstant().toEpochMilli());
        ReflectionTestUtils.setField(revision, "username", username);
        return revision;
    }
}

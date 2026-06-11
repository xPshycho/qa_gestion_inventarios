package com.pucmm.inventory.audit.service;

import com.pucmm.inventory.audit.api.dto.AuditRevisionResponse;
import com.pucmm.inventory.audit.domain.InventoryRevisionEntity;
import com.pucmm.inventory.product.domain.Product;
import com.pucmm.inventory.product.repository.ProductRepository;
import com.pucmm.inventory.product.service.ProductNotFoundException;
import com.pucmm.inventory.stock.domain.StockMovement;
import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.hibernate.envers.AuditReader;
import org.hibernate.envers.AuditReaderFactory;
import org.hibernate.envers.RevisionType;
import org.hibernate.envers.query.AuditEntity;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@Transactional(readOnly = true)
public class AuditService {
    private static final String PRODUCT_ENTITY_NAME = "Product";
    private static final String STOCK_MOVEMENT_ENTITY_NAME = "StockMovement";

    private final ProductRepository productRepository;

    @PersistenceContext
    private EntityManager entityManager;

    public AuditService(ProductRepository productRepository) {
        this.productRepository = productRepository;
    }

    @SuppressWarnings("unchecked")
    public List<AuditRevisionResponse> findProductRevisions(Long productId) {
        requireExistingProduct(productId);

        AuditReader reader = AuditReaderFactory.get(entityManager);
        List<Object[]> revisions = reader.createQuery()
                .forRevisionsOfEntity(Product.class, false, true)
                .add(AuditEntity.id().eq(productId))
                .addOrder(AuditEntity.revisionNumber().asc())
                .getResultList();

        List<AuditRevisionResponse> response = new ArrayList<>();
        Map<String, Object> previousValues = Map.of();
        for (Object[] revision : revisions) {
            Product product = (Product) revision[0];
            InventoryRevisionEntity revisionEntity = (InventoryRevisionEntity) revision[1];
            RevisionType revisionType = (RevisionType) revision[2];
            Map<String, Object> currentValues = productValues(product);

            response.add(toResponse(
                    PRODUCT_ENTITY_NAME,
                    product.getId(),
                    revisionEntity,
                    revisionType,
                    previousValues,
                    currentValues
            ));
            previousValues = currentValues;
        }

        return response;
    }

    @SuppressWarnings("unchecked")
    public List<AuditRevisionResponse> findProductStockMovementRevisions(Long productId) {
        requireExistingProduct(productId);

        AuditReader reader = AuditReaderFactory.get(entityManager);
        List<Object[]> revisions = reader.createQuery()
                .forRevisionsOfEntity(StockMovement.class, false, true)
                .add(AuditEntity.relatedId("product").eq(productId))
                .addOrder(AuditEntity.revisionNumber().asc())
                .addOrder(AuditEntity.id().asc())
                .getResultList();

        List<AuditRevisionResponse> response = new ArrayList<>();
        Map<Long, Map<String, Object>> previousValuesByMovement = new LinkedHashMap<>();
        for (Object[] revision : revisions) {
            StockMovement movement = (StockMovement) revision[0];
            InventoryRevisionEntity revisionEntity = (InventoryRevisionEntity) revision[1];
            RevisionType revisionType = (RevisionType) revision[2];
            Map<String, Object> previousValues = previousValuesByMovement.getOrDefault(movement.getId(), Map.of());
            Map<String, Object> currentValues = stockMovementValues(movement);

            response.add(toResponse(
                    STOCK_MOVEMENT_ENTITY_NAME,
                    movement.getId(),
                    revisionEntity,
                    revisionType,
                    previousValues,
                    currentValues
            ));
            previousValuesByMovement.put(movement.getId(), currentValues);
        }

        return response;
    }

    private void requireExistingProduct(Long productId) {
        if (!productRepository.existsById(productId)) {
            throw new ProductNotFoundException(productId);
        }
    }

    private AuditRevisionResponse toResponse(
            String entityName,
            Long entityId,
            InventoryRevisionEntity revisionEntity,
            RevisionType revisionType,
            Map<String, Object> previousValues,
            Map<String, Object> currentValues
    ) {
        return new AuditRevisionResponse(
                entityName,
                entityId,
                revisionEntity.getId(),
                revisionType.name(),
                revisionEntity.getChangedAt(),
                revisionEntity.getUsername(),
                previousValues,
                currentValues
        );
    }

    private Map<String, Object> productValues(Product product) {
        Map<String, Object> values = new LinkedHashMap<>();
        values.put("id", product.getId());
        values.put("sku", product.getSku());
        values.put("name", product.getName());
        values.put("description", product.getDescription());
        values.put("category", product.getCategory());
        values.put("price", product.getPrice());
        values.put("currentStock", product.getCurrentStock());
        values.put("minimumStock", product.getMinimumStock());
        values.put("status", product.getStatus());
        values.put("createdAt", product.getCreatedAt());
        values.put("updatedAt", product.getUpdatedAt());
        return values;
    }

    private Map<String, Object> stockMovementValues(StockMovement movement) {
        Map<String, Object> values = new LinkedHashMap<>();
        values.put("id", movement.getId());
        values.put("productId", movement.getProduct().getId());
        values.put("userId", movement.getUser() == null ? null : movement.getUser().getId());
        values.put("movementType", movement.getMovementType());
        values.put("previousQuantity", movement.getPreviousQuantity());
        values.put("newQuantity", movement.getNewQuantity());
        values.put("deltaQuantity", movement.getDeltaQuantity());
        values.put("observations", movement.getObservations());
        values.put("createdAt", movement.getCreatedAt());
        return values;
    }
}

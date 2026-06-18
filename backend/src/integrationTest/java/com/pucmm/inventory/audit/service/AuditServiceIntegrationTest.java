package com.pucmm.inventory.audit.service;

import static org.assertj.core.api.Assertions.assertThat;

import com.pucmm.inventory.audit.api.dto.AuditRevisionResponse;
import com.pucmm.inventory.integration.PostgreSqlIntegrationTest;
import com.pucmm.inventory.product.domain.Product;
import com.pucmm.inventory.product.domain.ProductData;
import com.pucmm.inventory.product.domain.ProductStatus;
import com.pucmm.inventory.product.repository.ProductRepository;
import com.pucmm.inventory.stock.api.dto.StockMovementRequest;
import com.pucmm.inventory.stock.domain.StockMovementType;
import com.pucmm.inventory.stock.service.StockService;
import java.math.BigDecimal;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.test.context.support.WithMockUser;

@SpringBootTest
class AuditServiceIntegrationTest extends PostgreSqlIntegrationTest {
    @Autowired
    private ProductRepository productRepository;

    @Autowired
    private StockService stockService;

    @Autowired
    private AuditService auditService;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Test
    @WithMockUser(username = "auditor")
    void productRevisionsIncludePreviousAndCurrentValues() {
        Product product = saveProduct("AUD-PROD-001", 12);

        product.update(new ProductData(
                product.getSku(),
                "Dell Latitude Audit",
                "Laptop empresarial auditada",
                "Laptops",
                new BigDecimal("69500.00"),
                7,
                3,
                ProductStatus.ACTIVE
        ));
        productRepository.saveAndFlush(product);

        List<AuditRevisionResponse> revisions = auditService.findProductRevisions(product.getId());

        assertThat(revisions).hasSize(2);
        assertThat(revisions.get(0).revisionType()).isEqualTo("ADD");
        assertThat(revisions.get(0).username()).isEqualTo("auditor");
        assertThat(revisions.get(0).currentValues()).containsEntry("currentStock", 12);
        assertThat(revisions.get(1).revisionType()).isEqualTo("MOD");
        assertThat(revisions.get(1).previousValues()).containsEntry("currentStock", 12);
        assertThat(revisions.get(1).currentValues()).containsEntry("currentStock", 7);

        Integer auditRows = jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM products_aud WHERE id = ?",
                Integer.class,
                product.getId()
        );
        assertThat(auditRows).isEqualTo(2);
    }

    @Test
    @WithMockUser(username = "edwin")
    void stockMovementRevisionsAreStoredForProductMovements() {
        Product product = saveProduct("AUD-STOCK-001", 10);

        stockService.registerEntry(product.getId(), new StockMovementRequest(5, "Recepcion auditada"), "edwin");

        List<AuditRevisionResponse> revisions = auditService.findProductStockMovementRevisions(product.getId());

        assertThat(revisions).hasSize(1);
        AuditRevisionResponse revision = revisions.getFirst();
        assertThat(revision.entityName()).isEqualTo("StockMovement");
        assertThat(revision.revisionType()).isEqualTo("ADD");
        assertThat(revision.username()).isEqualTo("edwin");
        assertThat(revision.currentValues())
                .containsEntry("productId", product.getId())
                .containsEntry("movementType", StockMovementType.ENTRY)
                .containsEntry("previousQuantity", 10)
                .containsEntry("newQuantity", 15)
                .containsEntry("deltaQuantity", 5);

        Integer auditRows = jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM stock_movements_aud WHERE product_id = ?",
                Integer.class,
                product.getId()
        );
        assertThat(auditRows).isEqualTo(1);
    }

    private Product saveProduct(String sku, int currentStock) {
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
        return productRepository.saveAndFlush(product);
    }
}
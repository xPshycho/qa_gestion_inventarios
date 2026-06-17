package com.pucmm.inventory.stock.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.pucmm.inventory.integration.PostgreSqlIntegrationTest;
import com.pucmm.inventory.product.domain.Product;
import com.pucmm.inventory.product.domain.ProductData;
import com.pucmm.inventory.product.domain.ProductStatus;
import com.pucmm.inventory.product.repository.ProductRepository;
import com.pucmm.inventory.stock.api.dto.StockAdjustmentRequest;
import com.pucmm.inventory.stock.api.dto.StockMovementRequest;
import com.pucmm.inventory.stock.api.dto.StockMovementResponse;
import com.pucmm.inventory.stock.domain.InventoryUser;
import com.pucmm.inventory.stock.domain.StockMovementType;
import com.pucmm.inventory.stock.repository.InventoryUserRepository;
import com.pucmm.inventory.stock.repository.StockMovementRepository;
import java.math.BigDecimal;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;

@SpringBootTest
class StockServiceIntegrationTest extends PostgreSqlIntegrationTest {
    @Autowired
    private StockService stockService;

    @Autowired
    private ProductRepository productRepository;

    @Autowired
    private InventoryUserRepository inventoryUserRepository;

    @Autowired
    private StockMovementRepository stockMovementRepository;

    @Test
    void stockMovementsUpdateProductAndPersistOrderedHistory() {
        Product product = saveProduct("INT-STOCK-001", 10);
        InventoryUser user = findSeedUser("edwin");

        StockMovementResponse entry = stockService.registerEntry(
                product.getId(),
                new StockMovementRequest(5, "Recepcion de inventario"),
                user.getUsername()
        );
        StockMovementResponse exit = stockService.registerExit(
                product.getId(),
                new StockMovementRequest(3, "Entrega a sucursal"),
                user.getUsername()
        );
        StockMovementResponse adjustment = stockService.adjustStock(
                product.getId(),
                new StockAdjustmentRequest(4, "Conteo fisico"),
                user.getUsername()
        );
        List<StockMovementResponse> history = stockService.findMovements(product.getId());

        assertThat(entry)
                .extracting(
                        StockMovementResponse::movementType,
                        StockMovementResponse::previousQuantity,
                        StockMovementResponse::newQuantity,
                        StockMovementResponse::deltaQuantity
                )
                .containsExactly(StockMovementType.ENTRY, 10, 15, 5);
        assertThat(exit)
                .extracting(
                        StockMovementResponse::movementType,
                        StockMovementResponse::previousQuantity,
                        StockMovementResponse::newQuantity,
                        StockMovementResponse::deltaQuantity
                )
                .containsExactly(StockMovementType.EXIT, 15, 12, -3);
        assertThat(adjustment)
                .extracting(
                        StockMovementResponse::movementType,
                        StockMovementResponse::previousQuantity,
                        StockMovementResponse::newQuantity,
                        StockMovementResponse::deltaQuantity
                )
                .containsExactly(StockMovementType.ADJUSTMENT, 12, 4, -8);
        assertThat(adjustment.stockAlert()).isTrue();
        assertThat(productRepository.findById(product.getId()))
                .get()
                .extracting(Product::getCurrentStock)
                .isEqualTo(4);
        assertThat(history)
                .extracting(StockMovementResponse::movementType)
                .containsExactly(
                        StockMovementType.ADJUSTMENT,
                        StockMovementType.EXIT,
                        StockMovementType.ENTRY
                );
        assertThat(history)
                .extracting(StockMovementResponse::username)
                .containsOnly("edwin");
    }

    @Test
    void insufficientStockRollsBackProductAndMovement() {
        Product product = saveProduct("INT-STOCK-ROLLBACK-001", 2);
        InventoryUser user = findSeedUser("edwin");
        long movementsBefore = stockMovementRepository.count();

        assertThatThrownBy(() -> stockService.registerExit(
                product.getId(),
                new StockMovementRequest(3, "Salida invalida"),
                user.getUsername()
        )).isInstanceOf(InsufficientStockException.class);

        assertThat(productRepository.findById(product.getId()))
                .get()
                .extracting(Product::getCurrentStock)
                .isEqualTo(2);
        assertThat(stockMovementRepository.count()).isEqualTo(movementsBefore);
        assertThat(stockService.findMovements(product.getId())).isEmpty();
    }

    private Product saveProduct(String sku, int currentStock) {
        Product product = new Product(new ProductData(
                sku,
                "Producto para stock",
                "Producto creado por pruebas de integracion",
                "Perifericos",
                new BigDecimal("2500.00"),
                currentStock,
                4,
                ProductStatus.ACTIVE
        ));
        return productRepository.saveAndFlush(product);
    }

    private InventoryUser findSeedUser(String username) {
        return inventoryUserRepository.findAll().stream()
                .filter(user -> username.equals(user.getUsername()))
                .findFirst()
                .orElseThrow();
    }
}
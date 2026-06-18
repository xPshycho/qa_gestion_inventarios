package com.pucmm.inventory.stock.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.when;

import com.pucmm.inventory.product.domain.Product;
import com.pucmm.inventory.product.domain.ProductData;
import com.pucmm.inventory.product.domain.ProductStatus;
import com.pucmm.inventory.product.repository.ProductRepository;
import com.pucmm.inventory.product.service.ProductNotFoundException;
import com.pucmm.inventory.stock.api.dto.StockAdjustmentRequest;
import com.pucmm.inventory.stock.api.dto.StockMovementRequest;
import com.pucmm.inventory.stock.api.dto.StockMovementResponse;
import com.pucmm.inventory.stock.domain.InventoryUser;
import com.pucmm.inventory.stock.domain.StockMovement;
import com.pucmm.inventory.stock.domain.StockMovementType;
import com.pucmm.inventory.stock.repository.InventoryUserRepository;
import com.pucmm.inventory.stock.repository.StockMovementRepository;
import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;

@ExtendWith(MockitoExtension.class)
class StockServiceTest {
    private static final OffsetDateTime TIMESTAMP = OffsetDateTime.parse("2026-06-07T12:00:00-04:00");

    @Mock
    private ProductRepository productRepository;

    @Mock
    private InventoryUserRepository inventoryUserRepository;

    @Mock
    private StockMovementRepository stockMovementRepository;

    @InjectMocks
    private StockService stockService;

    @BeforeEach
    void setUp() {
        lenient().when(stockMovementRepository.save(any(StockMovement.class))).thenAnswer(invocation -> {
            StockMovement movement = invocation.getArgument(0);
            ReflectionTestUtils.setField(movement, "id", 1L);
            ReflectionTestUtils.setField(movement, "createdAt", TIMESTAMP);
            return movement;
        });
    }

    @Test
    void registerEntryIncreasesStockAndCreatesMovement() {
        Product product = productWithStock(12, 4);
        when(productRepository.findByIdForUpdate(1L)).thenReturn(Optional.of(product));
        allowAuthenticatedUser("edwin");

        StockMovementResponse response = stockService.registerEntry(
                1L,
                new StockMovementRequest(3, "Recepcion"),
                "edwin"
        );

        assertThat(product.getCurrentStock()).isEqualTo(15);
        assertThat(response.username()).isEqualTo("edwin");
        assertThat(response.movementType()).isEqualTo(StockMovementType.ENTRY);
        assertThat(response.previousQuantity()).isEqualTo(12);
        assertThat(response.newQuantity()).isEqualTo(15);
        assertThat(response.deltaQuantity()).isEqualTo(3);
        assertThat(response.stockAlert()).isFalse();
    }

    @Test
    void registerExitDecreasesStockAndCreatesMovement() {
        Product product = productWithStock(12, 4);
        when(productRepository.findByIdForUpdate(1L)).thenReturn(Optional.of(product));
        allowAuthenticatedUser("edwin");

        StockMovementResponse response = stockService.registerExit(
                1L,
                new StockMovementRequest(8, "Entrega"),
                "edwin"
        );

        assertThat(product.getCurrentStock()).isEqualTo(4);
        assertThat(response.movementType()).isEqualTo(StockMovementType.EXIT);
        assertThat(response.previousQuantity()).isEqualTo(12);
        assertThat(response.newQuantity()).isEqualTo(4);
        assertThat(response.deltaQuantity()).isEqualTo(-8);
        assertThat(response.stockAlert()).isTrue();
    }

    @Test
    void registerExitRejectsNegativeStock() {
        Product product = productWithStock(2, 4);
        StockMovementRequest request = new StockMovementRequest(3, "Entrega");
        when(productRepository.findByIdForUpdate(1L)).thenReturn(Optional.of(product));
        allowAuthenticatedUser("edwin");

        assertThatThrownBy(() -> stockService.registerExit(1L, request, "edwin"))
                .isInstanceOf(InsufficientStockException.class)
                .hasMessageContaining("Stock insuficiente");
    }

    @Test
    void adjustStockSetsAbsoluteQuantityAndRecordsDelta() {
        Product product = productWithStock(12, 4);
        when(productRepository.findByIdForUpdate(1L)).thenReturn(Optional.of(product));
        allowAuthenticatedUser("edwin");

        StockMovementResponse response = stockService.adjustStock(
                1L,
                new StockAdjustmentRequest(5, "Conteo fisico"),
                "edwin"
        );

        assertThat(product.getCurrentStock()).isEqualTo(5);
        assertThat(response.movementType()).isEqualTo(StockMovementType.ADJUSTMENT);
        assertThat(response.previousQuantity()).isEqualTo(12);
        assertThat(response.newQuantity()).isEqualTo(5);
        assertThat(response.deltaQuantity()).isEqualTo(-7);
    }

    @Test
    void registerEntryRejectsUnknownProduct() {
        StockMovementRequest request = new StockMovementRequest(1, null);
        when(productRepository.findByIdForUpdate(99L)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> stockService.registerEntry(99L, request, "edwin"))
                .isInstanceOf(ProductNotFoundException.class)
                .hasMessageContaining("99");
    }

    @Test
    void registerEntryRejectsUnregisteredAuthenticatedUser() {
        Product product = productWithStock(12, 4);
        StockMovementRequest request = new StockMovementRequest(1, null);
        when(productRepository.findByIdForUpdate(1L)).thenReturn(Optional.of(product));
        when(inventoryUserRepository.findByUsernameIgnoreCase("externo")).thenReturn(Optional.empty());

        assertThatThrownBy(() -> stockService.registerEntry(1L, request, "externo"))
                .isInstanceOf(AuthenticatedInventoryUserException.class)
                .hasMessageContaining("externo");
    }

    @Test
    void findMovementsRequiresExistingProduct() {
        when(productRepository.existsById(99L)).thenReturn(false);

        assertThatThrownBy(() -> stockService.findMovements(99L))
                .isInstanceOf(ProductNotFoundException.class)
                .hasMessageContaining("99");
    }

    @Test
    void findMovementsReturnsHistory() {
        Product product = productWithStock(12, 4);
        StockMovement movement = new StockMovement(
                product,
                null,
                StockMovementType.INITIAL,
                0,
                12,
                12,
                "Seed"
        );
        ReflectionTestUtils.setField(movement, "id", 10L);
        ReflectionTestUtils.setField(movement, "createdAt", TIMESTAMP);
        when(productRepository.existsById(1L)).thenReturn(true);
        when(stockMovementRepository.findByProductIdOrderByCreatedAtDescIdDesc(1L)).thenReturn(List.of(movement));

        List<StockMovementResponse> response = stockService.findMovements(1L);

        assertThat(response).hasSize(1);
        assertThat(response.getFirst().movementType()).isEqualTo(StockMovementType.INITIAL);
        assertThat(response.getFirst().newQuantity()).isEqualTo(12);
    }

    private Product productWithStock(int currentStock, int minimumStock) {
        Product product = new Product(new ProductData(
                "DELL-LAT-5440",
                "Dell Latitude 5440",
                "Laptop empresarial",
                "Laptops",
                new BigDecimal("68500.00"),
                currentStock,
                minimumStock,
                ProductStatus.ACTIVE
        ));
        ReflectionTestUtils.setField(product, "id", 1L);
        ReflectionTestUtils.setField(product, "createdAt", TIMESTAMP);
        ReflectionTestUtils.setField(product, "updatedAt", TIMESTAMP);
        return product;
    }

    private InventoryUser user(String username) {
        InventoryUser user = org.mockito.Mockito.mock(InventoryUser.class);
        lenient().when(user.getId()).thenReturn(2L);
        lenient().when(user.getUsername()).thenReturn(username);
        lenient().when(user.getDisplayName()).thenReturn("Usuario " + username);
        return user;
    }

    private void allowAuthenticatedUser(String username) {
        InventoryUser user = user(username);
        when(inventoryUserRepository.findByUsernameIgnoreCase(username)).thenReturn(Optional.of(user));
    }
}
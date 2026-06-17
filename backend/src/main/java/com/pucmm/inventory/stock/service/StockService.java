package com.pucmm.inventory.stock.service;

import com.pucmm.inventory.product.domain.Product;
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
import java.util.List;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

@Service
@Transactional(readOnly = true)
public class StockService {
    private final ProductRepository productRepository;
    private final InventoryUserRepository inventoryUserRepository;
    private final StockMovementRepository stockMovementRepository;

    public StockService(
            ProductRepository productRepository,
            InventoryUserRepository inventoryUserRepository,
            StockMovementRepository stockMovementRepository
    ) {
        this.productRepository = productRepository;
        this.inventoryUserRepository = inventoryUserRepository;
        this.stockMovementRepository = stockMovementRepository;
    }

    @Transactional
    public StockMovementResponse registerEntry(Long productId, StockMovementRequest request, String actorUsername) {
        validatePositiveQuantity(request.quantity(), "quantity");
        Product product = findProductForUpdate(productId);
        InventoryUser user = findAuthenticatedUser(actorUsername);
        int previousQuantity = product.getCurrentStock();

        product.increaseStock(request.quantity());

        return saveMovement(
                product,
                user,
                StockMovementType.ENTRY,
                previousQuantity,
                product.getCurrentStock(),
                request.quantity(),
                request.observations()
        );
    }

    @Transactional
    public StockMovementResponse registerExit(Long productId, StockMovementRequest request, String actorUsername) {
        validatePositiveQuantity(request.quantity(), "quantity");
        Product product = findProductForUpdate(productId);
        InventoryUser user = findAuthenticatedUser(actorUsername);
        int previousQuantity = product.getCurrentStock();

        if (request.quantity() > previousQuantity) {
            throw new InsufficientStockException(productId, previousQuantity, request.quantity());
        }

        product.decreaseStock(request.quantity());

        return saveMovement(
                product,
                user,
                StockMovementType.EXIT,
                previousQuantity,
                product.getCurrentStock(),
                -request.quantity(),
                request.observations()
        );
    }

    @Transactional
    public StockMovementResponse adjustStock(Long productId, StockAdjustmentRequest request, String actorUsername) {
        if (request.newQuantity() == null || request.newQuantity() < 0) {
            throw new StockMovementValidationException("newQuantity must be greater than or equal to 0");
        }

        Product product = findProductForUpdate(productId);
        InventoryUser user = findAuthenticatedUser(actorUsername);
        int previousQuantity = product.getCurrentStock();

        product.adjustStock(request.newQuantity());

        return saveMovement(
                product,
                user,
                StockMovementType.ADJUSTMENT,
                previousQuantity,
                product.getCurrentStock(),
                request.newQuantity() - previousQuantity,
                request.observations()
        );
    }

    public List<StockMovementResponse> findMovements(Long productId) {
        if (!productRepository.existsById(productId)) {
            throw new ProductNotFoundException(productId);
        }

        return stockMovementRepository.findByProductIdOrderByCreatedAtDescIdDesc(productId).stream()
                .map(StockMovementResponse::from)
                .toList();
    }

    private StockMovementResponse saveMovement(
            Product product,
            InventoryUser user,
            StockMovementType movementType,
            int previousQuantity,
            int newQuantity,
            int deltaQuantity,
            String observations
    ) {
        StockMovement movement = new StockMovement(
                product,
                user,
                movementType,
                previousQuantity,
                newQuantity,
                deltaQuantity,
                observations
        );

        return StockMovementResponse.from(stockMovementRepository.save(movement));
    }

    private Product findProductForUpdate(Long productId) {
        return productRepository.findByIdForUpdate(productId)
                .orElseThrow(() -> new ProductNotFoundException(productId));
    }

    private InventoryUser findAuthenticatedUser(String username) {
        if (!StringUtils.hasText(username)) {
            throw new AuthenticatedInventoryUserException();
        }

        String normalizedUsername = username.trim();
        return inventoryUserRepository.findByUsernameIgnoreCase(normalizedUsername)
                .orElseThrow(() -> new AuthenticatedInventoryUserException(normalizedUsername));
    }

    private void validatePositiveQuantity(Integer quantity, String fieldName) {
        if (quantity == null || quantity <= 0) {
            throw new StockMovementValidationException(fieldName + " must be greater than 0");
        }
    }
}

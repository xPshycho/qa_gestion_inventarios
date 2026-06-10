package com.pucmm.inventory.report.service;

import com.pucmm.inventory.product.domain.ProductStatus;
import com.pucmm.inventory.product.repository.ProductRepository;
import com.pucmm.inventory.report.api.dto.CriticalProductResponse;
import com.pucmm.inventory.report.api.dto.DashboardMetricsResponse;
import com.pucmm.inventory.report.api.dto.DashboardResponse;
import com.pucmm.inventory.report.api.dto.TopMovedProductResponse;
import com.pucmm.inventory.stock.api.dto.StockMovementResponse;
import com.pucmm.inventory.stock.domain.StockMovementType;
import com.pucmm.inventory.stock.repository.StockMovementRepository;
import java.math.BigDecimal;
import java.util.List;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@Transactional(readOnly = true)
public class DashboardService {
    private static final int CRITICAL_PRODUCTS_LIMIT = 5;
    private static final int MOST_MOVED_PRODUCTS_LIMIT = 5;
    private static final int RECENT_MOVEMENTS_LIMIT = 8;

    private final ProductRepository productRepository;
    private final StockMovementRepository stockMovementRepository;

    public DashboardService(ProductRepository productRepository, StockMovementRepository stockMovementRepository) {
        this.productRepository = productRepository;
        this.stockMovementRepository = stockMovementRepository;
    }

    public DashboardResponse getDashboard() {
        return new DashboardResponse(
                buildMetrics(),
                findCriticalProducts(),
                findMostMovedProducts(),
                findRecentMovements()
        );
    }

    private DashboardMetricsResponse buildMetrics() {
        return new DashboardMetricsResponse(
                productRepository.count(),
                productRepository.countByStatus(ProductStatus.ACTIVE),
                productRepository.countByStatus(ProductStatus.INACTIVE),
                productRepository.countCriticalProductsByStatus(ProductStatus.ACTIVE),
                nullToZero(productRepository.sumCurrentStock()),
                nullToZero(productRepository.calculateInventoryValue()),
                stockMovementRepository.count(),
                stockMovementRepository.countByMovementType(StockMovementType.INITIAL),
                stockMovementRepository.countByMovementType(StockMovementType.ENTRY),
                stockMovementRepository.countByMovementType(StockMovementType.EXIT),
                stockMovementRepository.countByMovementType(StockMovementType.ADJUSTMENT)
        );
    }

    private List<CriticalProductResponse> findCriticalProducts() {
        return productRepository
                .findCriticalProducts(ProductStatus.ACTIVE, PageRequest.of(0, CRITICAL_PRODUCTS_LIMIT))
                .stream()
                .map(CriticalProductResponse::from)
                .toList();
    }

    private List<TopMovedProductResponse> findMostMovedProducts() {
        return stockMovementRepository
                .findMostMovedProducts(PageRequest.of(0, MOST_MOVED_PRODUCTS_LIMIT))
                .stream()
                .map(TopMovedProductResponse::from)
                .toList();
    }

    private List<StockMovementResponse> findRecentMovements() {
        return stockMovementRepository
                .findAllByOrderByCreatedAtDescIdDesc(PageRequest.of(0, RECENT_MOVEMENTS_LIMIT))
                .stream()
                .map(StockMovementResponse::from)
                .toList();
    }

    private Long nullToZero(Long value) {
        return value == null ? 0L : value;
    }

    private BigDecimal nullToZero(BigDecimal value) {
        return value == null ? BigDecimal.ZERO : value;
    }
}

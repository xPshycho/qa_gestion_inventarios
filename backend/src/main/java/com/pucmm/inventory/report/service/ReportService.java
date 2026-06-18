package com.pucmm.inventory.report.service;

import com.pucmm.inventory.product.domain.ProductStatus;
import com.pucmm.inventory.product.repository.ProductRepository;
import com.pucmm.inventory.report.api.dto.CriticalProductResponse;
import com.pucmm.inventory.report.api.dto.DashboardMetricsResponse;
import com.pucmm.inventory.report.api.dto.DashboardResponse;
import com.pucmm.inventory.report.api.dto.RecentStockMovementResponse;
import com.pucmm.inventory.report.api.dto.TopMovedProductResponse;
import com.pucmm.inventory.stock.domain.StockMovementType;
import com.pucmm.inventory.stock.repository.StockMovementRepository;
import java.math.BigDecimal;
import java.util.List;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@Transactional(readOnly = true)
public class ReportService {
    private static final int CRITICAL_PRODUCTS_LIMIT = 5;
    private static final int MOST_MOVED_PRODUCTS_LIMIT = 5;
    private static final int RECENT_MOVEMENTS_LIMIT = 8;

    private final ProductRepository productRepository;
    private final StockMovementRepository stockMovementRepository;

    public ReportService(ProductRepository productRepository, StockMovementRepository stockMovementRepository) {
        this.productRepository = productRepository;
        this.stockMovementRepository = stockMovementRepository;
    }

    public DashboardResponse getDashboard() {
        return new DashboardResponse(
                getMetrics(),
                getCriticalProducts(CRITICAL_PRODUCTS_LIMIT),
                getMostMovedProducts(MOST_MOVED_PRODUCTS_LIMIT),
                getRecentMovements(RECENT_MOVEMENTS_LIMIT)
        );
    }

    public List<CriticalProductResponse> getCriticalProducts(int limit) {
        return productRepository.findCriticalActiveProducts(PageRequest.of(0, limit)).stream()
                .map(CriticalProductResponse::from)
                .toList();
    }

    public List<TopMovedProductResponse> getMostMovedProducts(int limit) {
        return stockMovementRepository.findTopMovedProducts(PageRequest.of(0, limit)).stream()
                .map(TopMovedProductResponse::from)
                .toList();
    }

    public List<RecentStockMovementResponse> getRecentMovements(int limit) {
        return stockMovementRepository.findAllByOrderByCreatedAtDescIdDesc(PageRequest.of(0, limit)).stream()
                .map(RecentStockMovementResponse::from)
                .toList();
    }

    public DashboardMetricsResponse getMetrics() {
        return new DashboardMetricsResponse(
                productRepository.count(),
                productRepository.countByStatus(ProductStatus.ACTIVE),
                productRepository.countByStatus(ProductStatus.INACTIVE),
                productRepository.countCriticalActiveProducts(),
                zeroIfNull(productRepository.sumCurrentStock()),
                zeroIfNull(productRepository.calculateInventoryValue()),
                stockMovementRepository.count(),
                stockMovementRepository.countByMovementType(StockMovementType.INITIAL),
                stockMovementRepository.countByMovementType(StockMovementType.ENTRY),
                stockMovementRepository.countByMovementType(StockMovementType.EXIT),
                stockMovementRepository.countByMovementType(StockMovementType.ADJUSTMENT)
        );
    }

    private long zeroIfNull(Long value) {
        return value == null ? 0 : value;
    }

    private BigDecimal zeroIfNull(BigDecimal value) {
        return value == null ? BigDecimal.ZERO : value;
    }
}

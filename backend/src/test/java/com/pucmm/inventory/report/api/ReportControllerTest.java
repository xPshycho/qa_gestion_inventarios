package com.pucmm.inventory.report.api;

import static com.pucmm.inventory.config.SecurityConfig.REPORT_VIEW;
import static org.hamcrest.Matchers.containsString;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.pucmm.inventory.common.api.GlobalExceptionHandler;
import com.pucmm.inventory.config.SecurityConfig;
import com.pucmm.inventory.product.domain.ProductStatus;
import com.pucmm.inventory.report.api.dto.CriticalProductResponse;
import com.pucmm.inventory.report.api.dto.DashboardMetricsResponse;
import com.pucmm.inventory.report.api.dto.DashboardResponse;
import com.pucmm.inventory.report.api.dto.RecentStockMovementResponse;
import com.pucmm.inventory.report.api.dto.BestSellingProductResponse;
import com.pucmm.inventory.report.service.ReportService;
import com.pucmm.inventory.stock.domain.StockMovementType;
import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.request.RequestPostProcessor;

@WebMvcTest(ReportController.class)
@Import({GlobalExceptionHandler.class, SecurityConfig.class})
class ReportControllerTest {
    private static final OffsetDateTime TIMESTAMP = OffsetDateTime.parse("2026-06-07T12:00:00-04:00");

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean
    private ReportService reportService;

    @Test
    void getDashboardReturnsDashboardContract() throws Exception {
        when(reportService.getDashboard()).thenReturn(dashboard());

        mockMvc.perform(get("/reports/dashboard")
                        .with(jwtWith(REPORT_VIEW)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.metrics.totalProducts").value(4))
                .andExpect(jsonPath("$.metrics.inventoryValue").value(1728000))
                .andExpect(jsonPath("$.criticalProducts[0].sku").value("DELL-LAT-5440"))
                .andExpect(jsonPath("$.criticalProducts[0].shortage").value(3))
                .andExpect(jsonPath("$.bestSellingProducts[0].exitMovementCount").value(3))
                .andExpect(jsonPath("$.recentMovements[0].movementType").value("EXIT"))
                .andExpect(jsonPath("$.recentMovements[0].stockAlert").value(true));
    }

    @Test
    void getCriticalProductsUsesRequestedLimit() throws Exception {
        when(reportService.getCriticalProducts(10)).thenReturn(List.of(criticalProduct()));

        mockMvc.perform(get("/reports/critical-products")
                        .with(jwtWith(REPORT_VIEW))
                        .param("limit", "10"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].sku").value("DELL-LAT-5440"));

        verify(reportService).getCriticalProducts(10);
    }

    @Test
    void getBestSellingProductsUsesRequestedLimit() throws Exception {
        when(reportService.getBestSellingProducts(3)).thenReturn(List.of(bestSellingProduct()));

        mockMvc.perform(get("/reports/best-selling-products")
                        .with(jwtWith(REPORT_VIEW))
                        .param("limit", "3"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].productSku").value("DELL-LAT-5440"));

        verify(reportService).getBestSellingProducts(3);
    }

    @Test
    void getRecentMovementsUsesRequestedLimit() throws Exception {
        when(reportService.getRecentMovements(4)).thenReturn(List.of(recentMovement()));

        mockMvc.perform(get("/reports/recent-movements")
                        .with(jwtWith(REPORT_VIEW))
                        .param("limit", "4"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].id").value(10));

        verify(reportService).getRecentMovements(4);
    }

    @Test
    void getMetricsReturnsOperationalMetrics() throws Exception {
        when(reportService.getMetrics()).thenReturn(metrics());

        mockMvc.perform(get("/reports/metrics")
                        .with(jwtWith(REPORT_VIEW)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.entryMovements").value(2))
                .andExpect(jsonPath("$.exitMovements").value(1));
    }

    @Test
    void sectionEndpointsRejectInvalidLimit() throws Exception {
        mockMvc.perform(get("/reports/critical-products")
                        .with(jwtWith(REPORT_VIEW))
                        .param("limit", "0"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.status").value(400))
                .andExpect(jsonPath("$.message", containsString("must be greater than or equal to 1")));
    }

    private DashboardResponse dashboard() {
        return new DashboardResponse(
                metrics(),
                List.of(criticalProduct()),
                List.of(bestSellingProduct()),
                List.of(recentMovement())
        );
    }

    private DashboardMetricsResponse metrics() {
        return new DashboardMetricsResponse(
                4,
                3,
                1,
                1,
                26,
                new BigDecimal("1728000.00"),
                8,
                4,
                2,
                1,
                1
        );
    }

    private CriticalProductResponse criticalProduct() {
        return new CriticalProductResponse(
                1L,
                "DELL-LAT-5440",
                "Dell Latitude 5440",
                "Laptops",
                2,
                5,
                3,
                ProductStatus.ACTIVE,
                TIMESTAMP
        );
    }

    private BestSellingProductResponse bestSellingProduct() {
        return new BestSellingProductResponse(
                1L,
                "DELL-LAT-5440",
                "Dell Latitude 5440",
                "Laptops",
                3,
                18,
                TIMESTAMP
        );
    }

    private RecentStockMovementResponse recentMovement() {
        return new RecentStockMovementResponse(
                10L,
                1L,
                "DELL-LAT-5440",
                "Dell Latitude 5440",
                null,
                null,
                null,
                StockMovementType.EXIT,
                8,
                2,
                -6,
                "Movimiento de prueba",
                true,
                TIMESTAMP
        );
    }

    private static RequestPostProcessor jwtWith(String permission) {
        return jwt().authorities(new SimpleGrantedAuthority(permission));
    }
}

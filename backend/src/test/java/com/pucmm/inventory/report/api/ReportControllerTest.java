package com.pucmm.inventory.report.api;

import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.pucmm.inventory.common.api.GlobalExceptionHandler;
import com.pucmm.inventory.config.SecurityConfig;
import com.pucmm.inventory.product.domain.ProductStatus;
import com.pucmm.inventory.report.api.dto.CriticalProductResponse;
import com.pucmm.inventory.report.api.dto.DashboardMetricsResponse;
import com.pucmm.inventory.report.api.dto.DashboardResponse;
import com.pucmm.inventory.report.api.dto.TopMovedProductResponse;
import com.pucmm.inventory.report.service.DashboardService;
import com.pucmm.inventory.stock.api.dto.StockMovementResponse;
import com.pucmm.inventory.stock.domain.StockMovementType;
import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

@WebMvcTest(ReportController.class)
@Import({GlobalExceptionHandler.class, SecurityConfig.class})
class ReportControllerTest {
    private static final OffsetDateTime TIMESTAMP = OffsetDateTime.parse("2026-06-07T12:00:00-04:00");

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean
    private DashboardService dashboardService;

    @Test
    void getDashboardReturnsOperationalIndicators() throws Exception {
        when(dashboardService.getDashboard()).thenReturn(dashboard());

        mockMvc.perform(get("/reports/dashboard"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.metrics.totalProducts").value(4))
                .andExpect(jsonPath("$.metrics.criticalProducts").value(1))
                .andExpect(jsonPath("$.criticalProducts[0].sku").value("DELL-LAT-5440"))
                .andExpect(jsonPath("$.criticalProducts[0].shortage").value(3))
                .andExpect(jsonPath("$.mostMovedProducts[0].totalMovedUnits").value(18))
                .andExpect(jsonPath("$.recentMovements[0].movementType").value("EXIT"));
    }

    private DashboardResponse dashboard() {
        return new DashboardResponse(
                new DashboardMetricsResponse(
                        4L,
                        3L,
                        1L,
                        1L,
                        26L,
                        new BigDecimal("1728000.00"),
                        8L,
                        4L,
                        2L,
                        1L,
                        1L
                ),
                List.of(new CriticalProductResponse(
                        1L,
                        "DELL-LAT-5440",
                        "Dell Latitude 5440",
                        "Laptops",
                        2,
                        5,
                        3,
                        ProductStatus.ACTIVE,
                        TIMESTAMP
                )),
                List.of(new TopMovedProductResponse(
                        1L,
                        "DELL-LAT-5440",
                        "Dell Latitude 5440",
                        "Laptops",
                        3L,
                        18L,
                        TIMESTAMP
                )),
                List.of(new StockMovementResponse(
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
                ))
        );
    }
}

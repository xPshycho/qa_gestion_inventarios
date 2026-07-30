package com.pucmm.inventory.api;

import static com.pucmm.inventory.config.SecurityConfig.AUDIT_VIEW;
import static com.pucmm.inventory.config.SecurityConfig.REPORT_VIEW;
import static io.restassured.module.mockmvc.RestAssuredMockMvc.given;
import static org.hamcrest.Matchers.containsString;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;

import com.pucmm.inventory.audit.api.AuditController;
import com.pucmm.inventory.audit.api.dto.AuditRevisionResponse;
import com.pucmm.inventory.audit.service.AuditService;
import com.pucmm.inventory.common.api.GlobalExceptionHandler;
import com.pucmm.inventory.config.SecurityConfig;
import com.pucmm.inventory.product.domain.ProductStatus;
import com.pucmm.inventory.product.service.ProductNotFoundException;
import com.pucmm.inventory.report.api.ReportController;
import com.pucmm.inventory.report.api.dto.CriticalProductResponse;
import com.pucmm.inventory.report.api.dto.DashboardMetricsResponse;
import com.pucmm.inventory.report.api.dto.DashboardResponse;
import com.pucmm.inventory.report.api.dto.RecentStockMovementResponse;
import com.pucmm.inventory.report.api.dto.BestSellingProductResponse;
import com.pucmm.inventory.report.service.ReportService;
import com.pucmm.inventory.stock.domain.StockMovementType;
import io.restassured.module.mockmvc.RestAssuredMockMvc;
import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

@WebMvcTest({ReportController.class, AuditController.class})
@Import({GlobalExceptionHandler.class, SecurityConfig.class})
class ReportAuditApiContractTest {
    private static final OffsetDateTime TIMESTAMP = OffsetDateTime.parse("2026-06-07T12:00:00-04:00");

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean
    private ReportService reportService;

    @MockitoBean
    private AuditService auditService;

    @BeforeEach
    void configureRestAssured() {
        RestAssuredMockMvc.mockMvc(mockMvc);
    }

    @AfterEach
    void resetRestAssured() {
        RestAssuredMockMvc.reset();
    }

    @Test
    void dashboardReturnsOperationalReportContract() {
        when(reportService.getDashboard()).thenReturn(dashboard());

        given()
                .auth().with(jwtWith(REPORT_VIEW))
        .when()
                .get("/reports/dashboard")
        .then()
                .statusCode(200)
                .body("metrics.totalProducts", org.hamcrest.Matchers.equalTo(4))
                .body("metrics.inventoryValue", org.hamcrest.Matchers.equalTo(1728000.0F))
                .body("criticalProducts[0].sku", org.hamcrest.Matchers.equalTo("DELL-LAT-5440"))
                .body("criticalProducts[0].shortage", org.hamcrest.Matchers.equalTo(3))
                .body("bestSellingProducts[0].exitMovementCount", org.hamcrest.Matchers.equalTo(3))
                .body("recentMovements[0].movementType", org.hamcrest.Matchers.equalTo("EXIT"))
                .body("recentMovements[0].stockAlert", org.hamcrest.Matchers.equalTo(true));
    }

    @Test
    void reportSectionRejectsInvalidLimit() {
        given()
                .auth().with(jwtWith(REPORT_VIEW))
                .queryParam("limit", 0)
        .when()
                .get("/reports/critical-products")
        .then()
                .statusCode(400)
                .body("status", org.hamcrest.Matchers.equalTo(400))
                .body("message", containsString("must be greater than or equal to 1"));
    }

    @Test
    void auditProductRevisionsReturnRevisionContract() {
        when(auditService.findProductRevisions(1L)).thenReturn(List.of(new AuditRevisionResponse(
                "Product",
                1L,
                3,
                "MOD",
                TIMESTAMP,
                "edwin",
                Map.of("currentStock", 12),
                Map.of("currentStock", 9)
        )));

        given()
                .auth().with(jwtWith(AUDIT_VIEW))
        .when()
                .get("/audit/products/{productId}/revisions", 1L)
        .then()
                .statusCode(200)
                .body("[0].entityName", org.hamcrest.Matchers.equalTo("Product"))
                .body("[0].entityId", org.hamcrest.Matchers.equalTo(1))
                .body("[0].revisionType", org.hamcrest.Matchers.equalTo("MOD"))
                .body("[0].username", org.hamcrest.Matchers.equalTo("edwin"))
                .body("[0].previousValues.currentStock", org.hamcrest.Matchers.equalTo(12))
                .body("[0].currentValues.currentStock", org.hamcrest.Matchers.equalTo(9));
    }

    @Test
    void auditStockMovementRevisionsReturnRevisionContract() {
        when(auditService.findProductStockMovementRevisions(1L)).thenReturn(List.of(new AuditRevisionResponse(
                "StockMovement",
                10L,
                4,
                "ADD",
                TIMESTAMP,
                "carlos",
                Map.of(),
                Map.of("movementType", "ENTRY", "newQuantity", 15)
        )));

        given()
                .auth().with(jwtWith(AUDIT_VIEW))
        .when()
                .get("/audit/products/{productId}/stock-movements/revisions", 1L)
        .then()
                .statusCode(200)
                .body("[0].entityName", org.hamcrest.Matchers.equalTo("StockMovement"))
                .body("[0].entityId", org.hamcrest.Matchers.equalTo(10))
                .body("[0].revisionType", org.hamcrest.Matchers.equalTo("ADD"))
                .body("[0].currentValues.movementType", org.hamcrest.Matchers.equalTo("ENTRY"))
                .body("[0].currentValues.newQuantity", org.hamcrest.Matchers.equalTo(15));
    }

    @Test
    void auditUnknownProductReturnsNotFound() {
        when(auditService.findProductRevisions(99L)).thenThrow(new ProductNotFoundException(99L));

        given()
                .auth().with(jwtWith(AUDIT_VIEW))
        .when()
                .get("/audit/products/{productId}/revisions", 99L)
        .then()
                .statusCode(404)
                .body("status", org.hamcrest.Matchers.equalTo(404))
                .body("message", containsString("99"));
    }

    @Test
    void reportLimitIsForwardedToService() {
        when(reportService.getBestSellingProducts(3)).thenReturn(List.of(bestSellingProduct()));

        given()
                .auth().with(jwtWith(REPORT_VIEW))
                .queryParam("limit", 3)
        .when()
                .get("/reports/best-selling-products")
        .then()
                .statusCode(200)
                .body("[0].productSku", org.hamcrest.Matchers.equalTo("DELL-LAT-5440"));

        verify(reportService).getBestSellingProducts(3);
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

    private static org.springframework.test.web.servlet.request.RequestPostProcessor jwtWith(String permission) {
        return jwt().authorities(new SimpleGrantedAuthority(permission));
    }
}

package com.pucmm.inventory.config;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.pucmm.inventory.audit.service.AuditService;
import com.pucmm.inventory.product.service.ProductService;
import com.pucmm.inventory.report.service.ReportService;
import com.pucmm.inventory.security.repository.SecurityCatalogRepository;
import com.pucmm.inventory.security.service.SecurityAdminService;
import com.pucmm.inventory.stock.service.AuthenticatedInventoryUserResolver;
import com.pucmm.inventory.stock.service.StockService;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.web.servlet.MockMvc;

@SpringBootTest(properties = {
        "spring.autoconfigure.exclude="
                + "org.springframework.boot.autoconfigure.jdbc.DataSourceAutoConfiguration,"
                + "org.springframework.boot.autoconfigure.orm.jpa.HibernateJpaAutoConfiguration,"
                + "org.springframework.boot.autoconfigure.flyway.FlywayAutoConfiguration,"
                + "org.springframework.boot.autoconfigure.data.jpa.JpaRepositoriesAutoConfiguration"
})
@AutoConfigureMockMvc
class OpenApiDocumentationTest {
    private static final String SYNTHETIC_DATASOURCE_PASSWORD = UUID.randomUUID().toString();
    private static final String SYNTHETIC_KEYCLOAK_CLIENT_SECRET = UUID.randomUUID().toString();

    @DynamicPropertySource
    static void registerSyntheticSecrets(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.password", () -> SYNTHETIC_DATASOURCE_PASSWORD);
        registry.add(
                "inventory.keycloak.admin-client-secret",
                () -> SYNTHETIC_KEYCLOAK_CLIENT_SECRET);
    }

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean
    private ProductService productService;

    @MockitoBean
    private StockService stockService;

    @MockitoBean
    private AuthenticatedInventoryUserResolver authenticatedInventoryUserResolver;

    @MockitoBean
    private ReportService reportService;

    @MockitoBean
    private AuditService auditService;

    @MockitoBean
    private SecurityAdminService securityAdminService;

    @MockitoBean
    private SecurityCatalogRepository securityCatalogRepository;

    @Test
    void openApiDocsArePublicAndExposeMainInventoryPaths() throws Exception {
        mockMvc.perform(get("/v3/api-docs"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.info.title").value("Sistema de Gestion de Inventarios API"))
                .andExpect(jsonPath("$.components.securitySchemes['bearer-jwt']").exists())
                .andExpect(jsonPath("$.components.securitySchemes['bearer-jwt'].type").value("http"))
                .andExpect(jsonPath("$.components.securitySchemes['bearer-jwt'].scheme").value("bearer"))
                .andExpect(jsonPath("$.components.securitySchemes['bearer-jwt'].bearerFormat").value("JWT"))
                .andExpect(jsonPath("$.security[0]['bearer-jwt']").exists())
                .andExpect(jsonPath("$.paths['/products']").exists())
                .andExpect(jsonPath("$.paths['/products/{id}/stock-movements']").exists())
                .andExpect(jsonPath("$.paths['/reports/dashboard']").exists())
                .andExpect(jsonPath("$.paths['/audit/products/{productId}/revisions']").exists())
                .andExpect(jsonPath("$.paths['/security/users']").exists());
    }

    @Test
    void swaggerUiIsPubliclyReachable() throws Exception {
        mockMvc.perform(get("/swagger-ui/index.html"))
                .andExpect(status().isOk());
    }
}

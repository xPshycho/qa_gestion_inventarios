package com.pucmm.inventory.config;

import io.swagger.v3.oas.annotations.OpenAPIDefinition;
import io.swagger.v3.oas.annotations.info.Info;
import org.springframework.context.annotation.Configuration;

@Configuration
@OpenAPIDefinition(
        info = @Info(
                title = "Sistema de Gestion de Inventarios API",
                version = "1.0.0",
                description = "API REST para gestion de productos de inventario"
        )
)
public class OpenApiConfig {
}

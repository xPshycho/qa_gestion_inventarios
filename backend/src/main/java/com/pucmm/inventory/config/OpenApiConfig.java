package com.pucmm.inventory.config;

import io.swagger.v3.oas.annotations.OpenAPIDefinition;
import io.swagger.v3.oas.annotations.info.Info;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.security.SecurityScheme;
import io.swagger.v3.oas.annotations.enums.SecuritySchemeType;
import org.springframework.context.annotation.Configuration;

@Configuration
@OpenAPIDefinition(
        info = @Info(
                title = "Sistema de Gestion de Inventarios API",
                version = "1.0.0",
                description = "API REST para productos, stock, reportes, auditoria y administracion de seguridad. "
                        + "Los endpoints de negocio requieren JWT con permisos granulares."
        ),
        security = @SecurityRequirement(name = OpenApiConfig.BEARER_AUTH)
)
@SecurityScheme(
        name = OpenApiConfig.BEARER_AUTH,
        type = SecuritySchemeType.HTTP,
        scheme = "bearer",
        bearerFormat = "JWT",
        description = "Access token JWT emitido por Keycloak con permisos como product:view o user:manage."
)
public class OpenApiConfig {
    public static final String BEARER_AUTH = "bearer-jwt";
}

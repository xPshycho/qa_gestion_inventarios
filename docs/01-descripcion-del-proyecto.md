# Descripción del proyecto

## Propósito

El sistema administra productos, existencias, movimientos y reportes de
inventario para pequeñas empresas. Añade autorización granular, auditoría,
pruebas en varios niveles, observabilidad y automatización de entrega.

La solución real es un monolito modular:

- SPA Angular para operación;
- API REST Spring Boot;
- PostgreSQL para inventario y catálogo de seguridad;
- Keycloak como proveedor OIDC/OAuth2 y emisor de JWT;
- Flyway para esquema y datos semilla;
- servicios de telemetría Prometheus, Grafana, Loki, Tempo, Alloy y
  Alertmanager;
- Docker Compose para development, staging local, pruebas y producción VM;
- GitHub Actions como pipeline principal y Jenkins como pipeline
  complementario.

## Alcance funcional verificado

| Área | Capacidad real | Evidencia |
|---|---|---|
| Productos | CRUD, paginación, búsqueda, filtros y ordenamiento | `ProductController`, líneas 34-134 |
| Stock | Entradas, salidas, ajustes e historial | `ProductController`, líneas 100-134; `StockService`, líneas aproximadas 36-154 |
| Reportes | Dashboard, críticos, más movidos, recientes y métricas | `ReportController`, líneas 20-65 |
| Auditoría | Revisiones de productos y movimientos con Envers | `AuditController`, líneas 13-33; migraciones V6-V7 |
| Seguridad | Usuarios, roles, permisos y asignación mediante Keycloak Admin API | `SecurityAdminController`, líneas 24-78 |
| API | OpenAPI/Swagger y autenticación Bearer | `OpenApiConfig`; `SecurityConfig`, líneas 47-118 |

## Referencias al código

Ruta: `backend/src/main/java/com/pucmm/inventory/product/api/ProductController.java`\
Líneas aproximadas: 34-134\
Componente: `ProductController`\
Responsabilidad: expone CRUD, consulta y operaciones de stock; valida DTO,
paginación y parámetros antes de delegar a servicios.

Ruta: `backend/src/main/java/com/pucmm/inventory/stock/service/StockService.java`\
Líneas aproximadas: 36-154\
Componente: `StockService`\
Responsabilidad: aplica reglas de entrada/salida/ajuste, registra usuario y
persiste movimientos. Lo consumen los endpoints de producto y las pruebas
unitarias/integración.

Ruta: `backend/src/main/java/com/pucmm/inventory/report/api/ReportController.java`\
Líneas aproximadas: 20-65\
Componente: `ReportController`\
Responsabilidad: publica vistas agregadas de inventario con límites de 1 a 50.

## Tecnologías verificadas

| Capa | Tecnología/versionado observado |
|---|---|
| Backend | Java 21, Spring Boot 3.5.14, Gradle wrapper 8.14 |
| Frontend | Angular 20.3, TypeScript 5.9, Angular Material, pnpm 10.12.1 |
| Identidad | Keycloak 26.6.3, `keycloak-js` 26.2.4 |
| Datos | PostgreSQL 16, Flyway, Hibernate/JPA y Envers |
| E2E | Playwright 1.60 |
| Seguridad/rendimiento | ZAP 2.17.0, Trivy 0.70.0, k6 0.57.0 |

Las versiones de contenedores están fijadas por digest en Compose o scripts.

## Hallazgos funcionales abiertos

No se cambió código funcional durante esta entrega documental.

| ID | Hallazgo basado en código/pruebas | Riesgo |
|---|---|---|
| F-01 | Crear un producto con stock inicial positivo no genera movimiento `INITIAL`. | Trazabilidad incompleta del inventario inicial. |
| F-02 | El ranking de productos se ordena primero por cantidad de eventos y no por unidades movidas. | La etiqueta “más movido” puede interpretarse de forma distinta. |
| F-03 | Eliminar un producto con movimientos puede terminar en 500; se espera un conflicto controlado 409. | Contrato de error inconsistente. |
| F-04 | El hallazgo histórico de foco aparenta estar corregido; requiere retest manual asistivo. | Accesibilidad pendiente de verificación manual. |
| F-05 | El dashboard versionado referencia un histograma no emitido y una etiqueta Loki distinta a `compose_service`; hay paneles Tempo por revisar. | Paneles vacíos o engañosos. |

## Fuentes normativas

La rúbrica y los avances `proyecto_final*` se utilizaron como fuentes durante
la auditoría, pero no forman parte de este commit documental por la exclusión
expresa de reportes preexistentes. Su disponibilidad posterior al clonado es
**Pendiente de verificación**. La matriz de correspondencia está en
[trazabilidad](25-trazabilidad-entregables.md).

# Recorrido integral verificable


**Duración total:** 30–35 minutos.

**Objetivo:** comprobar funcionalidad, testing, seguridad, observabilidad, CI/CD y trazabilidad sin saltos entre evidencias.

**Stack:** Docker Compose, Spring Boot, Angular, PostgreSQL, Keycloak, OpenTelemetry, Grafana y GitHub Actions.

**Archivos navegables:**

- [docker-compose.yml](../docker-compose.yml): define aplicación, identidad, datos y observabilidad.
- [README.md](../README.md): concentra instalación, servicios, ambientes y comandos.
- [00-indice-general.md](00-indice-general.md): abre toda la documentación especializada.

**Resultado:** un entorno reproducible y una ruta única desde la operación funcional hasta la evidencia técnica.

## 1. Preparar el entorno — 2 minutos


**Objetivo:** iniciar todos los servicios con configuración segura y datos reproducibles.

**Stack:** Docker Compose, Flyway, PostgreSQL y Keycloak.

**Archivos navegables:**

- [docker-compose.yml](../docker-compose.yml): levanta el stack principal.
- [.env.example](../.env.example): declara variables sin secretos reales.
- [init-secret-env.sh](../scripts/security/init-secret-env.sh): genera credenciales locales efímeras.
- [V1 — productos](../backend/src/main/resources/db/migration/V1__create_products_table.sql) y [V8 — baja lógica](../backend/src/main/resources/db/migration/V8__add_product_soft_delete.sql): muestran el inicio y estado final del esquema.

**Acción:** ejecutar `make env` y `docker compose up --build --wait -d`; confirmar con `docker compose ps`.

**Resultado:** frontend, backend, bases de datos, identidad y observabilidad quedan `healthy`, sin credenciales versionadas.

## 2. Ubicar la arquitectura — 2 minutos


**Objetivo:** relacionar cada componente con su responsabilidad y flujo de datos.

**Stack:** Angular, Spring Boot, PostgreSQL, Keycloak, OpenTelemetry y LGTM.

**Archivos navegables:**

- [02-arquitectura.md](02-arquitectura.md): explica componentes y responsabilidades.
- [arquitectura-general.md](diagrams/arquitectura-general.md): muestra el flujo técnico completo.
- [docker-compose.yml](../docker-compose.yml): materializa la arquitectura local.
- [InventoryApplication.java](../backend/src/main/java/com/pucmm/inventory/InventoryApplication.java): inicia el backend.
- [app.routes.ts](../frontend/src/app/app.routes.ts): define navegación y protección de vistas.

**Acción:** seguir el flujo navegador → Keycloak → API → PostgreSQL y API → Alloy → Prometheus/Loki/Tempo → Grafana.

**Resultado:** se identifica dónde se ejecuta cada responsabilidad y cómo se propaga identidad y telemetría.

## 3. Validar acceso granular — 3 minutos


**Objetivo:** comprobar que la autorización depende de permisos y no del nombre del rol.

**Stack:** Keycloak, OAuth2 Authorization Code + PKCE, JWT y Spring Security.

**Archivos navegables:**

- [inventory-realm.json](../infra/keycloak/inventory-realm.json): define clientes, scopes, recursos, policies, roles y usuarios.
- [SecurityConfig.java](../backend/src/main/java/com/pucmm/inventory/config/SecurityConfig.java): aplica permisos por endpoint.
- [auth.config.ts](../frontend/src/app/auth/auth.config.ts): conecta Angular con Keycloak.
- [auth.service.ts](../frontend/src/app/auth/auth.service.ts): controla login, logout y renovación.
- [auth.guards.ts](../frontend/src/app/auth/auth.guards.ts): restringe rutas por permiso.
- [SecurityAdminService.java](../backend/src/main/java/com/pucmm/inventory/security/service/SecurityAdminService.java): crea usuarios y asigna roles mediante la API administrativa de Keycloak.
- [SecurityCatalogRepository.java](../backend/src/main/java/com/pucmm/inventory/security/repository/SecurityCatalogRepository.java): mantiene la copia local usada por catálogo, validación y auditoría.
- [roles.spec.ts](../tests/e2e/specs/roles.spec.ts): demuestra acceso permitido y denegado.

**Acción:** entrar como `viewer`, comprobar lectura sin mutaciones; entrar como `carlos`, comprobar administración completa.

**Distribución de responsabilidad:** Keycloak es la fuente de identidad y asignación de roles. Sus roles compuestos agrupan permisos y el mapper `inventory permissions` los coloca en el claim `permissions` del JWT. Spring Security valida ese claim con `hasAuthority` en cada endpoint. PostgreSQL conserva un catálogo sincronizado para mostrar roles/permisos, validar los roles funcionales permitidos y asociar usuarios con movimientos y auditoría; no autentica ni sustituye a Keycloak.

**Resultado:** `product:view`, `product:manage`, `stock:view`, `stock:manage`, `report:view`, `user:manage` y `audit:view` se aplican por operación.

## 4. Recorrer productos — 3 minutos


**Objetivo:** comprobar CRUD, paginación, búsqueda, filtros, ordenamiento y validaciones.

**Stack:** Angular Material, Spring MVC, Bean Validation, Spring Data JPA y PostgreSQL.

**Archivos navegables:**

- [products.component.ts](../frontend/src/app/products.component.ts): listado, búsqueda, filtros, ordenamiento y eliminación.
- [product-form.component.ts](../frontend/src/app/product-form.component.ts): formulario y validaciones.
- [product.service.ts](../frontend/src/app/product.service.ts): comunica la interfaz con la API.
- [ProductController.java](../backend/src/main/java/com/pucmm/inventory/product/api/ProductController.java): expone el CRUD REST.
- [ProductService.java](../backend/src/main/java/com/pucmm/inventory/product/service/ProductService.java): aplica SKU único, movimiento inicial y baja lógica.
- [ProductRepository.java](../backend/src/main/java/com/pucmm/inventory/product/repository/ProductRepository.java): ejecuta filtros y consultas sin archivados.
- [products-crud.spec.ts](../tests/e2e/specs/products-crud.spec.ts): valida el flujo completo desde navegador.

**Acción:** crear un producto, buscarlo por nombre/SKU, filtrar, ordenar, editarlo y revisar una validación inválida.

**Resultado:** el catálogo responde de forma paginada; SKU duplicado devuelve `409`; la cantidad inicial crea un movimiento `INITIAL` asociado al usuario.

## 5. Recorrer stock y auditoría — 4 minutos


**Objetivo:** comprobar entradas, salidas, ajustes, stock mínimo e historial inmutable.

**Stack:** Spring Boot, transacciones JPA, PostgreSQL, Hibernate Envers y JWT.

**Archivos navegables:**

- [StockService.java](../backend/src/main/java/com/pucmm/inventory/stock/service/StockService.java): valida y registra entradas, salidas y ajustes.
- [StockMovement.java](../backend/src/main/java/com/pucmm/inventory/stock/domain/StockMovement.java): representa cantidades, actor, tipo y observación.
- [StockMovementRepository.java](../backend/src/main/java/com/pucmm/inventory/stock/repository/StockMovementRepository.java): consulta historial y ventas.
- [AuditService.java](../backend/src/main/java/com/pucmm/inventory/audit/service/AuditService.java): recupera revisiones Envers.
- [InventoryRevisionListener.java](../backend/src/main/java/com/pucmm/inventory/audit/domain/InventoryRevisionListener.java): asocia usuario y momento a cada revisión.
- [stock-movements-page.component.ts](../frontend/src/app/stock-movements-page.component.ts): presenta y registra movimientos.
- [stock-movements.spec.ts](../tests/e2e/specs/stock-movements.spec.ts) y [audit.spec.ts](../tests/e2e/specs/audit.spec.ts): validan historial y auditoría.

**Acción:** registrar entrada, salida y ajuste; consultar movimientos y auditoría; intentar una salida superior a la existencia.

**Resultado:** quedan fecha, actor, tipo, cantidad anterior/nueva y observación; el stock negativo se rechaza; `DELETE` retira el producto del catálogo mediante baja lógica y conserva movimientos y revisiones.

## 6. Leer indicadores del negocio — 3 minutos


**Objetivo:** comprobar productos críticos, productos más vendidos, historial reciente y métricas operacionales.

**Stack:** Angular, Spring Data JPQL y PostgreSQL.

**Archivos navegables:**

- [dashboard.component.html](../frontend/src/app/dashboard.component.html): muestra tarjetas, críticos, ventas e historial.
- [dashboard.service.ts](../frontend/src/app/dashboard.service.ts): obtiene los indicadores.
- [ReportController.java](../backend/src/main/java/com/pucmm/inventory/report/api/ReportController.java): expone dashboard y reportes.
- [ReportService.java](../backend/src/main/java/com/pucmm/inventory/report/service/ReportService.java): compone métricas, críticos y ventas.
- [StockMovementRepository.java](../backend/src/main/java/com/pucmm/inventory/stock/repository/StockMovementRepository.java): suma exclusivamente movimientos `EXIT`.
- [ReportServiceIntegrationTest.java](../backend/src/integrationTest/java/com/pucmm/inventory/report/service/ReportServiceIntegrationTest.java): contrasta resultados con PostgreSQL real.

**Acción:** abrir el dashboard y contrastar una salida de stock con el ranking y el historial.

**Resultado:** los críticos usan `currentStock <= minimumStock`; los más vendidos suman exclusivamente movimientos `EXIT`; entradas, ajustes e inventario inicial no inflan ventas.

## 7. Verificar API y contrato — 2 minutos


**Objetivo:** comprobar documentación ejecutable, códigos HTTP y esquemas.

**Stack:** REST, OpenAPI 3, Swagger UI y RestAssured.

**Archivos navegables:**

- [OpenApiConfig.java](../backend/src/main/java/com/pucmm/inventory/config/OpenApiConfig.java): configura OpenAPI y bearer JWT.
- [ProductApiContractTest.java](../backend/src/apiTest/java/com/pucmm/inventory/api/ProductApiContractTest.java): valida CRUD, permisos, payloads y status.
- [ReportAuditApiContractTest.java](../backend/src/apiTest/java/com/pucmm/inventory/api/ReportAuditApiContractTest.java): valida reportes y auditoría.
- [GlobalExceptionHandler.java](../backend/src/main/java/com/pucmm/inventory/common/api/GlobalExceptionHandler.java): uniforma errores.
- [07-api.md](07-api.md): explica rutas, autenticación y contrato.

**Acción:** abrir `http://localhost:8080/swagger-ui.html`, autorizar con JWT y consultar productos, reportes y movimientos.

**Resultado:** `/v3/api-docs` expone el contrato, los endpoints protegidos exigen bearer JWT y los errores mantienen un payload uniforme.

## 8. Ejecutar Full Stack Testing — 4 minutos


**Objetivo:** mostrar cobertura automatizada desde unidades hasta navegador y datos reales.

**Stack:** JUnit, Mockito, JaCoCo, Testcontainers, RestAssured, Karma y Playwright.

**Archivos navegables:**

- [ProductServiceTest.java](../backend/src/test/java/com/pucmm/inventory/product/service/ProductServiceTest.java): ejemplo unitario de reglas de productos.
- [ProductApiContractTest.java](../backend/src/apiTest/java/com/pucmm/inventory/api/ProductApiContractTest.java): ejemplo de contrato REST.
- [FlywayMigrationIntegrationTest.java](../backend/src/integrationTest/java/com/pucmm/inventory/integration/FlywayMigrationIntegrationTest.java): prueba migraciones sobre PostgreSQL Testcontainers.
- [dashboard.component.spec.ts](../frontend/src/app/dashboard.component.spec.ts): ejemplo unitario frontend.
- [playwright.config.ts](../tests/e2e/playwright.config.ts): configura browsers, responsive, artifacts y seguridad.
- [run_all_local_tests.sh](../scripts/testing/run_all_local_tests.sh): orquesta todas las suites locales.
- [11-guia-de-pruebas.md](11-guia-de-pruebas.md): detalla comandos, resultados y alcance.

**Acción:** ejecutar `make test-backend`, `make test-api`, `make test-integration`, `make test-frontend` y `make test-e2e`.

**Resultado:** gates de coverage, contratos, PostgreSQL/Keycloak reales, roles, accesibilidad, responsive y Chromium/Firefox/WebKit producen resultados centralizados en `test-results/`.

## 9. Verificar seguridad y rendimiento — 4 minutos


**Objetivo:** comprobar vulnerabilidades, autenticación, carga, estrés, concurrencia, latencia y throughput.

**Stack:** OWASP ZAP, Trivy, k6, Keycloak y Docker.

**Archivos navegables:**

- [run-local.sh de seguridad](../tests/security/run-local.sh): orquesta headers, Trivy y ZAP.
- [run-zap-api-scan.sh](../tests/security/run-zap-api-scan.sh): ejecuta el escaneo OpenAPI autenticado.
- [security-testing.yml](../.github/workflows/security-testing.yml): reproduce los gates en GitHub Actions.
- [performance.js](../tests/performance/performance.js): define la mezcla autenticada de lecturas.
- [profiles.js](../tests/performance/config/profiles.js): configura smoke, load y stress hasta 100 VUs.
- [run-local.sh de rendimiento](../tests/performance/run-local.sh): levanta el stack aislado y exporta resultados.
- [14-seguridad-zap.md](14-seguridad-zap.md) y [15-rendimiento-k6.md](15-rendimiento-k6.md): explican criterios y cifras.

**Acción:** ejecutar `make test-security`; luego `K6_PROFILE=load ./tests/performance/run-local.sh` y `K6_PROFILE=stress ./tests/performance/run-local.sh`.

**Resultado:** Trivy controla HIGH/CRITICAL; ZAP API activo dejó 118 reglas PASS y cero fallos; k6 stress sostuvo 100 VUs, 10,804 requests, 51 req/s, 0 % de errores y p95 de 166.11 ms.

## 10. Correlacionar métricas, logs, trazas y alertas — 4 minutos


**Objetivo:** seguir una petición entre las cuatro señales operacionales.

**Stack:** OpenTelemetry, Alloy, Prometheus, Loki, Tempo, Grafana y Alertmanager.

**Archivos navegables:**

- [application.properties](../backend/src/main/resources/application.properties): habilita Actuator, métricas y OpenTelemetry.
- [CorrelationIdFilter.java](../backend/src/main/java/com/pucmm/inventory/observability/CorrelationIdFilter.java): propaga `correlationId`, endpoint y usuario.
- [config.alloy](../infra/observability/alloy/config.alloy): recibe y enruta telemetría.
- [prometheus.yml](../infra/observability/prometheus/prometheus.yml): scrapea métricas.
- [inventory-alerts.yml](../infra/observability/prometheus/rules/inventory-alerts.yml): define alertas operativas y de autenticación.
- [inventory-final-observability.json](../infra/observability/grafana/dashboards/inventory-final-observability.json): provisiona el dashboard final.
- [loki.yaml](../infra/observability/loki/loki.yaml) y [tempo.yaml](../infra/observability/tempo/tempo.yaml): almacenan logs y trazas.
- [17-observabilidad.md](17-observabilidad.md): explica consultas, correlación y límites.

**Acción:** abrir `http://localhost:3000`, localizar latencia/throughput, filtrar `{compose_service="backend"}`, abrir una traza y revisar reglas de Alertmanager.

**Resultado:** CPU, memoria, JVM, latencia, throughput, error rate y pool aparecen en Grafana; logs incluyen `traceId`, `spanId`, `correlationId`, usuario y endpoint; existen alertas de disponibilidad, CPU, memoria, errores, latencia, pool y fallos 401/403.

## 11. Seguir CI/CD y calidad — 3 minutos


**Objetivo:** comprobar que cada cambio atraviesa build, pruebas, seguridad, calidad, imagen y despliegue.

**Stack:** GitHub Actions, SonarCloud, Docker, OpenTofu, Workload Identity Federation y Jenkins.

**Archivos navegables:**

- [ci-required.yml](../.github/workflows/ci-required.yml): selecciona y exige los pipelines aplicables.
- [backend-ci.yml](../.github/workflows/backend-ci.yml) y [frontend-ci.yml](../.github/workflows/frontend-ci.yml): ejecutan build, pruebas y coverage.
- [staging-preview.yml](../.github/workflows/staging-preview.yml): despliega y prueba el preview runner-private.
- [gcp-managed-deploy.yml](../.github/workflows/gcp-managed-deploy.yml): aplica ambientes GCP mediante WIF.
- [Jenkinsfile](../Jenkinsfile): refleja el pipeline visual complementario.
- [github_wif/main.tf](../infra/opentofu/modules/github_wif/main.tf): define identidades y permisos del pipeline.
- [16-ci-cd-jenkins.md](16-ci-cd-jenkins.md): explica gates, promoción y artifacts.

**Acción:** abrir el último run y recorrer `CI Required`; mostrar stages equivalentes en `Jenkinsfile` y el flujo `develop → staging → main`.

**Resultado:** las ramas protegidas exigen PR, aprobación cruzada y quality gate; el despliegue utiliza identidad sin llaves y ejecuta validaciones post-deploy.

## 12. Cerrar con trazabilidad — 2 minutos


**Objetivo:** conectar requisito, código, prueba y evidencia sin afirmaciones no verificadas.

**Stack:** Git, GitHub Issues/PR, Conventional Commits y reportes Markdown/JSON.

**Archivos navegables:**

- [25-trazabilidad-entregables.md](25-trazabilidad-entregables.md): cruza requisito, implementación, prueba y evidencia.
- [22-evidencias.md](22-evidencias.md): indica dónde consultar cada resultado.
- [PULL_REQUEST_TEMPLATE.md](../.github/PULL_REQUEST_TEMPLATE.md): exige issue, pruebas, staging y revisión.
- [test-results/README.md](../test-results/README.md): define el contrato común de resultados.
- [24-script-demostracion.md](24-script-demostracion.md): mantiene este recorrido como punto único de apoyo.

**Acción:** seleccionar un requisito y seguir issue → rama → commit → PR → check → archivo → reporte.

**Resultado:** cada conclusión puede verificarse en el repositorio o en GitHub y los pendientes externos quedan identificados por su issue.

## Comprobación final — 1 minuto


**Objetivo:** evitar cerrar con servicios o resultados inconsistentes.

**Stack:** Docker Compose, Git y recolector de evidencias.

**Archivos navegables:**

- [Makefile](../Makefile): ofrece los comandos reproducibles.
- [collect_local_test_results.sh](../scripts/testing/collect_local_test_results.sh): reúne resultados locales.
- [22-evidencias.md](22-evidencias.md): permite localizar reportes y artifacts.
- [verify-artifacts.sh](../scripts/security/verify-artifacts.sh): evita publicar evidencia sensible.

**Acción:** ejecutar `make results`, `git status --short` y `docker compose ps`; al finalizar, `docker compose down`.

**Resultado:** resultados reunidos, cambios conocidos y entorno apagado de forma controlada.

## Comportamiento seguro en producción — sólo lectura

**Objetivo:** generar peticiones reales para observar métricas, logs y trazas sin modificar inventario ni ejecutar carga peligrosa.

**Stack:** Playwright, Keycloak, usuario `viewer`, HTTPS, OpenTelemetry y Grafana.

**Archivos navegables:**

- [deployed-smoke.spec.ts](../tests/e2e/specs/deployed-smoke.spec.ts): comprueba health, OIDC, login, dashboard y catálogo; intercepta y bloquea cualquier método de mutación.
- [package.json de E2E](../tests/e2e/package.json): expone el script existente `test:smoke`.
- [playwright.config.ts](../tests/e2e/playwright.config.ts): recibe la URL objetivo y controla artifacts.
- [post-deploy.sh](../scripts/gcp/post-deploy.sh): valida SHA, contenedores, health, OIDC, frontera `401`, HTTPS y evidencia después de desplegar.
- [gcp-production-deploy.yml](../.github/workflows/gcp-production-deploy.yml): ejecuta el gate productivo con secretos administrados.
- [collect-evidence.sh](../scripts/gcp/collect-evidence.sh): reúne logs y estado sin publicar credenciales.

**Manera recomendada:** ejecutar el smoke existente desde un runner controlado, apuntando `E2E_BASE_URL` al origen HTTPS de producción y entregando URL de Keycloak, issuer, realm y credenciales `viewer` desde el almacén de secretos. El flujo inicia sesión, consulta dashboard y catálogo, y falla si detecta POST, PUT, PATCH o DELETE. Es suficiente para producir requests, métricas, logs y trazas representativas de navegación real.

**Para observar telemetría:** mantener abierto Grafana mientras se ejecuta el smoke o navegar manualmente con `viewer`. Buscar el mismo intervalo en métricas, logs y trazas; usar `correlationId`, `traceId`, endpoint y usuario para demostrar la relación. Una única autenticación inválida, previamente autorizada, puede comprobar la señal de fallos 401/403; no debe repetirse ni convertirse en fuerza bruta.

**Qué no ejecutar en producción:** k6 load/stress, ZAP activo, CRUD E2E, pruebas de stock, seeds, migraciones experimentales ni exploratory testing con mutaciones. Esas suites crean datos, elevan concurrencia o atacan parámetros y pertenecen a staging. Para demostrar ventas, auditoría, stock mínimo, errores o alertas de latencia, usar el preview de staging; no degradar producción deliberadamente.

**Resultado:** se genera comportamiento observable de bajo riesgo y queda evidencia de disponibilidad, autenticación y lecturas reales, sin alterar datos empresariales.

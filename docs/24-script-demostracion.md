# Recorrido integral verificable


**Duración total:** 30–35 minutos.

**Objetivo:** comprobar funcionalidad, testing, seguridad, observabilidad, CI/CD y trazabilidad sin saltos entre evidencias.

**Stack:** Docker Compose, Spring Boot, Angular, PostgreSQL, Keycloak, OpenTelemetry, Grafana y GitHub Actions.

**Archivos:** `docker-compose.yml`, `README.md`, `docs/00-indice-general.md`.

**Resultado:** un entorno reproducible y una ruta única desde la operación funcional hasta la evidencia técnica.

## 1. Preparar el entorno — 2 minutos


**Objetivo:** iniciar todos los servicios con configuración segura y datos reproducibles.

**Stack:** Docker Compose, Flyway, PostgreSQL y Keycloak.

**Archivos:** `docker-compose.yml`, `.env.example`, `scripts/security/init-secret-env.sh`, `backend/src/main/resources/db/migration/`.

**Acción:** ejecutar `make env` y `docker compose up --build --wait -d`; confirmar con `docker compose ps`.

**Resultado:** frontend, backend, bases de datos, identidad y observabilidad quedan `healthy`, sin credenciales versionadas.

## 2. Ubicar la arquitectura — 2 minutos


**Objetivo:** relacionar cada componente con su responsabilidad y flujo de datos.

**Stack:** Angular, Spring Boot, PostgreSQL, Keycloak, OpenTelemetry y LGTM.

**Archivos:** `docs/02-arquitectura.md`, `docs/diagrams/architecture.md`, `docker-compose.yml`.

**Acción:** seguir el flujo navegador → Keycloak → API → PostgreSQL y API → Alloy → Prometheus/Loki/Tempo → Grafana.

**Resultado:** se identifica dónde se ejecuta cada responsabilidad y cómo se propaga identidad y telemetría.

## 3. Validar acceso granular — 3 minutos


**Objetivo:** comprobar que la autorización depende de permisos y no del nombre del rol.

**Stack:** Keycloak, OAuth2 Authorization Code + PKCE, JWT y Spring Security.

**Archivos:** `infra/keycloak/inventory-realm.json`, `backend/src/main/java/com/pucmm/inventory/config/SecurityConfig.java`, `frontend/src/app/auth/`.

**Acción:** entrar como `viewer`, comprobar lectura sin mutaciones; entrar como `carlos`, comprobar administración completa.

**Resultado:** `product:view`, `product:manage`, `stock:view`, `stock:manage`, `report:view`, `user:manage` y `audit:view` se aplican por operación.

## 4. Recorrer productos — 3 minutos


**Objetivo:** comprobar CRUD, paginación, búsqueda, filtros, ordenamiento y validaciones.

**Stack:** Angular Material, Spring MVC, Bean Validation, Spring Data JPA y PostgreSQL.

**Archivos:** `frontend/src/app/products.component.ts`, `frontend/src/app/product-form.component.ts`, `backend/src/main/java/com/pucmm/inventory/product/`.

**Acción:** crear un producto, buscarlo por nombre/SKU, filtrar, ordenar, editarlo y revisar una validación inválida.

**Resultado:** el catálogo responde de forma paginada; SKU duplicado devuelve `409`; la cantidad inicial crea un movimiento `INITIAL` asociado al usuario.

## 5. Recorrer stock y auditoría — 4 minutos


**Objetivo:** comprobar entradas, salidas, ajustes, stock mínimo e historial inmutable.

**Stack:** Spring Boot, transacciones JPA, PostgreSQL, Hibernate Envers y JWT.

**Archivos:** `backend/src/main/java/com/pucmm/inventory/stock/`, `backend/src/main/java/com/pucmm/inventory/audit/`, `frontend/src/app/stock-movement-dialog.component.ts`.

**Acción:** registrar entrada, salida y ajuste; consultar movimientos y auditoría; intentar una salida superior a la existencia.

**Resultado:** quedan fecha, actor, tipo, cantidad anterior/nueva y observación; el stock negativo se rechaza; `DELETE` retira el producto del catálogo mediante baja lógica y conserva movimientos y revisiones.

## 6. Leer indicadores del negocio — 3 minutos


**Objetivo:** comprobar productos críticos, productos más vendidos, historial reciente y métricas operacionales.

**Stack:** Angular, Spring Data JPQL y PostgreSQL.

**Archivos:** `frontend/src/app/dashboard.component.html`, `backend/src/main/java/com/pucmm/inventory/report/`, `backend/src/main/java/com/pucmm/inventory/stock/repository/StockMovementRepository.java`.

**Acción:** abrir el dashboard y contrastar una salida de stock con el ranking y el historial.

**Resultado:** los críticos usan `currentStock <= minimumStock`; los más vendidos suman exclusivamente movimientos `EXIT`; entradas, ajustes e inventario inicial no inflan ventas.

## 7. Verificar API y contrato — 2 minutos


**Objetivo:** comprobar documentación ejecutable, códigos HTTP y esquemas.

**Stack:** REST, OpenAPI 3, Swagger UI y RestAssured.

**Archivos:** `backend/src/main/java/com/pucmm/inventory/config/OpenApiConfig.java`, `backend/src/apiTest/`, `docs/07-api-openapi.md`.

**Acción:** abrir `http://localhost:8080/swagger-ui.html`, autorizar con JWT y consultar productos, reportes y movimientos.

**Resultado:** `/v3/api-docs` expone el contrato, los endpoints protegidos exigen bearer JWT y los errores mantienen un payload uniforme.

## 8. Ejecutar Full Stack Testing — 4 minutos


**Objetivo:** mostrar cobertura automatizada desde unidades hasta navegador y datos reales.

**Stack:** JUnit, Mockito, JaCoCo, Testcontainers, RestAssured, Karma y Playwright.

**Archivos:** `backend/src/test/`, `backend/src/apiTest/`, `backend/src/integrationTest/`, `frontend/src/`, `tests/e2e/`.

**Acción:** ejecutar `make test-backend`, `make test-api`, `make test-integration`, `make test-frontend` y `make test-e2e`.

**Resultado:** gates de coverage, contratos, PostgreSQL/Keycloak reales, roles, accesibilidad, responsive y Chromium/Firefox/WebKit producen resultados centralizados en `test-results/`.

## 9. Verificar seguridad y rendimiento — 4 minutos


**Objetivo:** comprobar vulnerabilidades, autenticación, carga, estrés, concurrencia, latencia y throughput.

**Stack:** OWASP ZAP, Trivy, k6, Keycloak y Docker.

**Archivos:** `tests/security/`, `tests/performance/performance.js`, `tests/performance/config/profiles.js`.

**Acción:** ejecutar `make test-security`; luego `K6_PROFILE=load ./tests/performance/run-local.sh` y `K6_PROFILE=stress ./tests/performance/run-local.sh`.

**Resultado:** Trivy controla HIGH/CRITICAL; ZAP API activo dejó 118 reglas PASS y cero fallos; k6 stress sostuvo 100 VUs, 10,804 requests, 51 req/s, 0 % de errores y p95 de 166.11 ms.

## 10. Correlacionar métricas, logs, trazas y alertas — 4 minutos


**Objetivo:** seguir una petición entre las cuatro señales operacionales.

**Stack:** OpenTelemetry, Alloy, Prometheus, Loki, Tempo, Grafana y Alertmanager.

**Archivos:** `infra/observability/`, `backend/src/main/resources/application.properties`, `backend/src/main/resources/logback-spring.xml`.

**Acción:** abrir `http://localhost:3000`, localizar latencia/throughput, filtrar `{compose_service="backend"}`, abrir una traza y revisar reglas de Alertmanager.

**Resultado:** CPU, memoria, JVM, latencia, throughput, error rate y pool aparecen en Grafana; logs incluyen `traceId`, `spanId`, `correlationId`, usuario y endpoint; existen alertas de disponibilidad, CPU, memoria, errores, latencia, pool y fallos 401/403.

## 11. Seguir CI/CD y calidad — 3 minutos


**Objetivo:** comprobar que cada cambio atraviesa build, pruebas, seguridad, calidad, imagen y despliegue.

**Stack:** GitHub Actions, SonarCloud, Docker, OpenTofu, Workload Identity Federation y Jenkins.

**Archivos:** `.github/workflows/`, `Jenkinsfile`, `infra/opentofu/`, `docs/16-ci-cd-jenkins.md`.

**Acción:** abrir el último run y recorrer `CI Required`; mostrar stages equivalentes en `Jenkinsfile` y el flujo `develop → staging → main`.

**Resultado:** las ramas protegidas exigen PR, aprobación cruzada y quality gate; el despliegue utiliza identidad sin llaves y ejecuta validaciones post-deploy.

## 12. Cerrar con trazabilidad — 2 minutos


**Objetivo:** conectar requisito, código, prueba y evidencia sin afirmaciones no verificadas.

**Stack:** Git, GitHub Issues/PR, Conventional Commits y reportes Markdown/JSON.

**Archivos:** `docs/25-trazabilidad-entregables.md`, `docs/22-evidencias.md`, `.github/PULL_REQUEST_TEMPLATE.md`, `test-results/README.md`.

**Acción:** seleccionar un requisito y seguir issue → rama → commit → PR → check → archivo → reporte.

**Resultado:** cada conclusión puede verificarse en el repositorio o en GitHub y los pendientes externos quedan identificados por su issue.

## Comprobación final — 1 minuto


**Objetivo:** evitar cerrar con servicios o resultados inconsistentes.

**Stack:** Docker Compose, Git y recolector de evidencias.

**Archivos:** `Makefile`, `scripts/testing/collect_local_test_results.sh`, `docs/22-evidencias.md`.

**Acción:** ejecutar `make results`, `git status --short` y `docker compose ps`; al finalizar, `docker compose down`.

**Resultado:** resultados reunidos, cambios conocidos y entorno apagado de forma controlada.

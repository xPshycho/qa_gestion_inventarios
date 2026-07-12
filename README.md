# Sistema de Gestion de Inventarios Empresarial

Proyecto final de la asignatura Aseguramiento de Calidad de Software.  
Pontificia Universidad Catolica Madre y Maestra - Facultad de Ciencias e Ingenieria.

## Descripcion  

Sistema moderno de gestion de inventarios orientado a pequenas empresas, construido con un
ecosistema completo de aseguramiento de calidad de software (QAS), pruebas automatizadas,
seguridad, observabilidad, integracion y despliegue continuos.

## Integrantes

| Nombre | GitHub  |
|--------|--------|
| Edwin  | [xPshycho](https://github.com/xPshycho) |
| Carlos | [Code-Hdez](https://github.com/Code-Hdez) |

## Stack tecnologico

| Capa | Tecnologia |
|------|------------|
| Backend | Spring Boot |
| Frontend | Angular |
| Base de datos | PostgreSQL |
| Migraciones | Flyway |
| Seguridad | Keycloak, OAuth2, JWT |
| Contenedores | Docker, Docker Compose |
| Observabilidad | OpenTelemetry, Prometheus, Loki, Tempo, Alloy, Grafana, Alertmanager |
| Calidad de codigo | SonarCloud |
| Testing | JUnit, Mockito, Testcontainers, RestAssured, Playwright, k6, OWASP ZAP |
| CI/CD | GitHub Actions, Jenkins |

## Requisitos previos

- Docker >= 24
- Docker Compose >= 2.20
- Java 21
- Node.js >= 20

## Instalacion local

```bash
# 1. Clonar el repositorio
git clone https://github.com/xPshycho/qa_gestion_inventarios
cd qa_gestion_inventarios

# 2. Configurar variables de entorno
cp .env.example .env

# Editar .env con los valores reales

# 3. Levantar el sistema completo
docker compose up --build -d

# 4. Verificar que todos los servicios esten corriendo
docker compose ps
```

## Servicios locales con Docker Compose

| Servicio | URL / puerto | Descripcion |
|----------|--------------|-------------|
| Frontend | http://localhost:5173 | Interfaz Angular de gestion de productos |
| Backend | http://localhost:8080/actuator/health | Healthcheck HTTP del API |
| Swagger UI | http://localhost:8080/swagger-ui/index.html | Documentacion interactiva de la API REST |
| OpenAPI JSON | http://localhost:8080/v3/api-docs | Contrato OpenAPI generado por Springdoc |
| Keycloak | http://localhost:8081 | Realm `inventory` para OAuth2/JWT |
| PostgreSQL | localhost:55432 | Base de datos local para desarrollo |
| Flyway | Servicio interno | Aplica migraciones antes de iniciar el backend |
| Prometheus | http://localhost:9090 | Scraping de metricas del backend y Keycloak |
| Grafana | http://localhost:3000 | Dashboard operativo con datasource Prometheus |

Los puertos pueden cambiarse en `.env` usando `FRONTEND_PORT`, `BACKEND_PORT`, `KEYCLOAK_PORT`
y `POSTGRES_PORT`, `PROMETHEUS_PORT` y `GRAFANA_PORT`.
El puerto local por defecto de PostgreSQL es `55432` para evitar conflictos con instalaciones
locales que ya usan `5432`. Si se necesita usar otro puerto, definir `POSTGRES_PORT`.
La interfaz Angular consume la API del backend mediante la ruta `/api`.

Swagger UI y `/v3/api-docs` quedan publicos para facilitar la evaluacion del avance. Los endpoints
de negocio siguen protegidos por JWT y permisos granulares; para probar operaciones desde Swagger,
usar el boton **Authorize** con un access token emitido por Keycloak.

```bash
# Validar que el contrato OpenAPI esta disponible
curl http://localhost:8080/v3/api-docs
```

OpenTelemetry queda deshabilitado por defecto en Docker Compose con `OTEL_SDK_DISABLED=true`.
Las metricas operativas se exponen por Actuator en `/actuator/prometheus` y Prometheus las
scrapea desde la red interna de Docker Compose.

## Credenciales demo locales

Estas credenciales son solo para desarrollo local y datos de prueba.

| Servicio | Usuario | Contrasena |
|----------|---------|------------|
| Aplicacion | `carlos` | `admin123` |
| Aplicacion | `edwin` | `admin123` |
| Aplicacion | `viewer` | `admin123` |
| Aplicacion | `auditor` | `admin123` |
| Keycloak admin | `admin` | `admin123` |
| Grafana admin | `admin` | `admin123` |

Si Keycloak o Grafana ya tenian volumenes creados con credenciales anteriores, recrear los
contenedores/volumenes locales para que se importe la configuracion nueva.

## Migraciones de base de datos

Flyway ejecuta las migraciones versionadas ubicadas en `backend/src/main/resources/db/migration`.
El servicio `backend` inicia despues de que Flyway aplica correctamente los scripts sobre PostgreSQL.

```bash
# Levantar PostgreSQL, ejecutar migraciones y dejar el entorno local arriba
docker compose up --build -d

# Ver estado de servicios y confirmar que Flyway completo su ejecucion
docker compose ps

# Validar datos iniciales de productos
docker compose exec postgres \
  psql -U inventory_user -d inventory -c "SELECT sku, name, current_stock FROM products ORDER BY sku;"

# Validar permisos y roles iniciales
docker compose exec postgres \
  psql -U inventory_user -d inventory -c "SELECT code, module FROM permissions ORDER BY code;"
```

## Estructura del repositorio

```
.
├── .github/
│   ├── ISSUE_TEMPLATE/         # Plantillas de issues
│   ├── workflows/              # GitHub Actions pipelines
│   └── PULL_REQUEST_TEMPLATE.md
├── backend/                    # API REST Spring Boot
├── frontend/                   # Interfaz Angular
├── infra/
│   ├── docker/                 # Dockerfiles y compose
│   ├── keycloak/               # Realm export y configuracion
│   ├── migrations/             # Evidencias o recursos de migraciones
│   └── observability/          # Grafana, Prometheus, Loki, Tempo, Alloy
├── tests/
│   ├── e2e/                    # Playwright
│   ├── performance/            # k6 / JMeter
│   └── security/               # OWASP ZAP
├── docs/                       # Documentacion tecnica y de pruebas
├── .env.example
├── .gitignore
├── commitlint.config.js
├── docker-compose.override.yml
└── docker-compose.yml
```

## Ambientes

| Ambiente | Descripcion | URL |
|----------|-------------|-----|
| Development | Local con Docker Compose | http://localhost:5173 |
| Staging | Replica de produccion para pruebas post-deploy | Pendiente de issue de deployment/staging |
| Production | Ambiente final | Pendiente de release final |

## Permisos del sistema

| Permiso | Descripcion |
|---------|-------------|
| `product:view` | Ver productos |
| `product:manage` | Crear, editar y eliminar productos |
| `stock:view` | Ver existencia e historial |
| `stock:manage` | Registrar entradas, salidas y ajustes |
| `report:view` | Ver reportes y dashboard |
| `user:manage` | Gestionar usuarios, roles y permisos |
| `audit:view` | Consultar auditoria del sistema |

La configuracion importable de Keycloak vive en `infra/keycloak/inventory-realm.json`.
La matriz de roles, usuarios demo y comandos de validacion JWT estan documentados en
`docs/security/keycloak.md`.

## Branch strategy

| Rama | Uso |
|------|-----|
| `main` | Version final estable. Solo recibe merges desde staging con pruebas aprobadas. |
| `develop` | Integracion continua de funcionalidades terminadas. |
| `staging` | Ambiente preview para pruebas contra sistema desplegado. |
| `feature/{nombre}-{modulo}` | Requisitos funcionales. |
| `test/{nombre}-{tipo}` | Pruebas automatizadas. |
| `security/{nombre}-{tema}` | Seguridad y validaciones. |
| `observability/{nombre}-{tema}` | Observabilidad y monitoreo. |
| `ci/{nombre}-{pipeline}` | Pipelines CI/CD. |
| `docs/{nombre}-{documento}` | Documentacion. |

## Conventional Commits

Este proyecto valida el formato de commits mediante commitlint en cada Pull Request.

Formato: `tipo(scope): descripcion`

| Tipo | Uso |
|------|-----|
| `feat` | Nueva funcionalidad |
| `fix` | Correccion de bug |
| `test` | Agregar o modificar pruebas |
| `ci` | Cambios en pipelines CI/CD |
| `docs` | Documentacion |
| `chore` | Mantenimiento, configuracion |
| `build` | Sistema de build, dependencias |
| `refactor` | Refactorizacion sin cambio funcional |
| `perf` | Mejoras de rendimiento |
| `security` | Cambios relacionados a seguridad |

Ejemplo: `feat(products): add product search by SKU`

## Ejecutar pruebas

```bash
# Build backend
cd backend && ./gradlew clean assemble

# Unit tests
cd backend && ./gradlew test

# Unit tests + JaCoCo + quality gate de cobertura
cd backend && ./gradlew test jacocoTestReport jacocoTestCoverageVerification

# Integration tests (requiere Docker y Java 21)
cd backend && ./gradlew integrationTest

# API tests con RestAssured
cd backend && ./gradlew apiTest

# Verificacion backend completa
cd backend && ./gradlew check

# Frontend unit tests + coverage
cd frontend && CHROME_BIN=/usr/bin/chromium pnpm exec ng test --watch=false --browsers=ChromeHeadless --code-coverage

# Build frontend
cd frontend && pnpm build

# E2E con Playwright, Keycloak y base de datos real
cd tests/e2e
npx --yes pnpm@10.12.1 install
PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH=/usr/bin/chromium npx --yes pnpm@10.12.1 test

# E2E usando un stack Docker Compose ya levantado
cd "$(git rev-parse --show-toplevel)"
docker compose up --build --wait --wait-timeout 240 -d
cd tests/e2e
E2E_MANAGE_STACK=false npx --yes pnpm@10.12.1 run stack:ready
E2E_MANAGE_STACK=false npx --yes pnpm@10.12.1 exec playwright test

# Performance tests
K6_PROFILE=smoke K6_PASSWORD="<password-local>" k6 run tests/performance/performance.js

# Guia completa: tests/performance/README.md

# Security scan
# Jenkins ejecuta pnpm audit --prod; ZAP/dependency scan dedicados pertenecen al issue de security testing
```

Las pruebas de integracion levantan PostgreSQL 16 y Keycloak 26.6.3 con Testcontainers. Si el
entorno de Keycloak/Testcontainers bloquea `integrationTest`, el reporte HTML y los resultados
XML quedan disponibles para diagnostico.

## Evidencias de pruebas y cobertura

El workflow automatico `Backend CI` ejecuta build, unit tests, API tests, quality gate de cobertura e
integration tests en GitHub Actions para `main`, `develop`, `staging`, ramas `test/**`, ramas
`ci/**` y Pull Requests hacia `main`, `develop` o `staging`. Los reportes se publican como
artifacts aun cuando un job de pruebas falle, para conservar logs y HTML de diagnostico.

El quality gate de backend exige cobertura de lineas >= 60% mediante JaCoCo. Los reportes de
SonarCloud consumen los XML de JaCoCo generados por Gradle.

El pipeline Jenkins se mantiene como flujo complementario y esta documentado en
`docs/ci/jenkins.md`. Ejecuta checkout, build, pruebas, analisis de calidad, build Docker,
despliegue preview con Docker Compose y E2E con Playwright.

El Jenkins local se entrega preconfigurado con el usuario `admin`, el job
`inventory-avance-ci` y todas las herramientas requeridas. Se inicia desde la raiz con:

```bash
docker compose -p inventory-jenkins -f compose.jenkins.yml up -d --build --wait
```

La interfaz queda disponible en `http://localhost:18080`; la guia de operacion, reinicio y
limpieza esta en `docs/ci/jenkins.md`.

| Evidencia | Comando local | Reporte local | Artifact CI |
|-----------|---------------|---------------|-------------|
| Build backend | `cd backend && ./gradlew clean assemble` | `backend/build/libs/*.jar` | `backend-build-*` |
| Unit tests | `cd backend && ./gradlew test` | `backend/build/reports/tests/test/index.html` | `backend-unit-test-reports-*` |
| Cobertura unit tests | `cd backend && ./gradlew test jacocoTestReport jacocoTestCoverageVerification` | `backend/build/reports/jacoco/test/html/index.html` | `backend-unit-test-reports-*` |
| Integration tests | `cd backend && ./gradlew integrationTest` | `backend/build/reports/tests/integrationTest/index.html` | `backend-integration-test-reports-*` |
| Cobertura integration tests | `cd backend && ./gradlew integrationTest` | `backend/build/reports/jacoco/integrationTest/html/index.html` | `backend-integration-test-reports-*` |
| API tests | `cd backend && ./gradlew apiTest` | `backend/build/reports/tests/apiTest/index.html` | `backend-api-test-reports-*` |
| Frontend unit + coverage | `cd frontend && pnpm exec ng test --watch=false --browsers=ChromeHeadless --code-coverage` | `frontend/coverage/qa-gestion-inventarios-frontend/index.html` | `frontend-coverage-*` |
| E2E Playwright | `cd tests/e2e && npx --yes pnpm@10.12.1 test` | `tests/e2e/playwright-report/index.html`, `tests/e2e/test-results/playwright-results.xml` | `playwright-e2e-*`, Jenkins Pipeline |

Estado de automatizacion de testing:

| Tipo | Estado | Detalle |
|------|--------|---------|
| Unit | Automatizada en CI | JUnit/Mockito ejecutado por `./gradlew test` y publicado con JaCoCo. |
| Integration | Automatizada | Testcontainers ejecutado por `./gradlew integrationTest`; los reportes se publican para diagnosticar fallos de entorno. |
| API | Automatizada en CI | RestAssured valida contratos REST, status codes, errores y permisos en `backend/src/apiTest`. |
| Frontend | Automatizada en CI | Angular/Karma ejecuta unit tests con cobertura y publica artifact `frontend-coverage-*`. |
| E2E | Automatizada en GitHub Actions y Jenkins | Playwright cubre login, CRUD de productos, roles y responsive; se publican HTML, JUnit, screenshots, videos, traces y diagnosticos Docker. |

La guia consolidada de comandos, reportes y artifacts esta en `docs/testing/ci-reporting.md`.

## Observabilidad

Una vez levantado el sistema:

| Herramienta | URL |
|-------------|-----|
| Grafana | Pendiente de issue #52 |
| Prometheus | Pendiente de issue #52 |
| Alertmanager | Pendiente de issue #52 |


## Documentacion
- `docs/security/keycloak.md`: configuracion de seguridad, usuarios demo, scopes y permisos.
- `docs/ci/jenkins.md`: pipeline Jenkins, credenciales, stages, reportes y artifacts.
- `docs/testing/ci-reporting.md`: guia de testing, cobertura, artifacts y evidencia para PRs.

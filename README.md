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
- Node.js 20.19+, 22.12+ o 24.x
- `bash`, `curl`, `jq` y `openssl`

## Instalacion local

```bash
# 1. Clonar el repositorio
git clone https://github.com/xPshycho/qa_gestion_inventarios
cd qa_gestion_inventarios

# 2. Generar .env con secretos aleatorios y permisos 0600
./scripts/security/init-secret-env.sh local

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
| Loki | http://localhost:3100 | Agregacion de logs |
| Tempo | http://localhost:3200 | Almacenamiento y consulta de trazas |
| Alertmanager | http://localhost:9093 | Enrutamiento de alertas |

Los puertos pueden cambiarse en `.env` usando `FRONTEND_PORT`, `BACKEND_PORT`, `KEYCLOAK_PORT`
y `POSTGRES_PORT`, `PROMETHEUS_PORT` y `GRAFANA_PORT`.
La matriz canónica de puertos internos, development, staging, producción y
Jenkins está en [`puertos.md`](puertos.md).
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

`OTEL_SDK_DISABLED` controla la exportacion de trazas en desarrollo. El perfil staging la
habilita y etiqueta la telemetria con ambiente y version. Las metricas operativas se exponen por
Actuator en `/actuator/prometheus` y Prometheus las scrapea desde la red interna de Compose.

## Credenciales locales

Los usernames no sensibles están declarados en `.env.example`. Todas las
contraseñas y el client secret se generan en `.env`, que está ignorado y usa
permisos `0600`. No hay passwords compartidos ni valores predeterminados en
Compose, el realm de Keycloak o la documentación.

Para rotarlos:

```bash
./scripts/security/init-secret-env.sh local --rotate
docker compose down -v
docker compose up --build -d
```

La guía completa de proveedores, nombres, Jenkins, GitHub Actions y respuesta
a exposiciones está en `docs/security/secrets-management.md`.

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
│   ├── workflows/              # CI y staging preview en GitHub Actions
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
│   ├── staging/                # Verificacion black-box post-deploy
│   └── security/               # OWASP ZAP
├── scripts/staging/            # Deploy, evidencia, backup, rollback y limpieza
├── docs/                       # Documentacion tecnica y de pruebas
├── .env.example
├── .env.staging.example
├── .gitignore
├── commitlint.config.js
├── docker-compose.override.yml
├── docker-compose.staging.yml
└── docker-compose.yml
```

## Ambientes

| Ambiente | Descripcion | URL |
|----------|-------------|-----|
| Development | Local con Docker Compose | http://localhost:5173 |
| Staging local | Overlay aislado, secretos generados y puertos solo en loopback | http://127.0.0.1:15173 |
| Staging CI | Preview efimero por SHA en el runner de GitHub Actions | Runner-private; no publica URL externa |
| Production | Ambiente final | Fuera del alcance del preview de staging |

El staging no usa `docker-compose.override.yml`, no comparte proyecto ni volumenes con desarrollo
y ejecuta Keycloak en modo `start` con PostgreSQL propio. El runbook completo, el contrato de
variables, las URLs, el flujo de promocion y el rollback estan en
[`docs/deployment/staging.md`](docs/deployment/staging.md).

```bash
./scripts/staging/init-env.sh
./scripts/staging/deploy.sh
./scripts/staging/post-deploy.sh
```

Los secretos, el realm renderizado y la evidencia local viven bajo `.staging/`, que esta ignorado
por Git. `post-deploy.sh` es un gate: valida integracion real, API, login, flujo principal,
Playwright, headers, ZAP, k6, observabilidad y seguridad de evidencia antes de devolver exito.

El workflow `Quality Pipeline` clasifica cada PR por los archivos cambiados y llama
`Staging Preview` solamente cuando el cambio afecta runtime, E2E, seguridad,
performance, observabilidad, Compose o CI/CD. Un push a `staging` siempre ejecuta
el preview completo. Un PR hacia `main` solo es valido si proviene exactamente
de `staging`. El preview usa un proyecto Compose exclusivo, valida que todos los
puertos y URLs permanezcan en `127.0.0.1` y se destruye al terminar.

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

Desde la raíz del repositorio, el comando recomendado para preparar el entorno,
ejecutar todas las suites automatizadas y centralizar sus resultados es:

```bash
make test
```

No requiere Chromium instalado en `/usr/bin`: las pruebas frontend y E2E usan
la imagen Playwright fijada en Docker. La guía de ejecución individual y
diagnóstico está en `docs/testing/ci-reporting.md`.

Comandos habituales:

```bash
make help
make env
make build
make build-backend
make build-frontend
make check-config
make test
make test-backend
make test-api
make test-integration
make test-frontend
make test-e2e
make test-performance
make test-security
make results
```

`make check-config` valida scripts, pruebas del recolector y la combinación
local `docker-compose.yml` + `docker-compose.override.yml` sin levantar el
stack. Los targets E2E, performance y seguridad usan esa misma combinación,
publican únicamente los puertos definidos en `.env`, esperan las URLs desde el
host y limpian sus contenedores y artifacts al terminar.

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

# Frontend unit tests + coverage sin depender del navegador del host
make test-frontend

# Build frontend
cd frontend && pnpm build

# E2E con Playwright, Keycloak y base de datos real, desde la raíz
pnpm --dir tests/e2e test

# Performance tests con stack y credenciales locales aisladas
./tests/performance/run-local.sh

# Guia completa: tests/performance/README.md

# Security headers + OWASP ZAP con stack local aislado
./tests/security/run-local.sh

# Staging completo contra una instancia ya desplegada
./scripts/staging/init-env.sh
./scripts/staging/deploy.sh
./scripts/staging/post-deploy.sh
```

Las pruebas de integracion levantan PostgreSQL 16 y Keycloak 26.6.3 con Testcontainers. Si el
entorno de Keycloak/Testcontainers bloquea `integrationTest`, el reporte HTML y los resultados
XML quedan disponibles para diagnostico.

## Evidencias de pruebas y cobertura

El workflow automático `Quality Pipeline` se ejecuta en cada Pull Request hacia
`main`, `develop` o `staging`. Primero clasifica las rutas modificadas según las
áreas del proyecto y llama los pipelines aplicables. Un cambio backend ejecuta
build, unitarias, API, integración, cobertura y SonarCloud; un cambio frontend
ejecuta build y unitarias; las rutas E2E, security, performance, observability y
CI/CD activan sus gates especializados y staging cuando corresponde. Los PR
exclusivamente documentales conservan Conventional Commits y Gitleaks, sin
levantar infraestructura innecesaria.

El job agregado `CI Required` comprueba que cada pipeline seleccionado termine
exitosamente y que los no aplicables hayan sido omitidos. Los reportes se
publican como artifacts aun cuando una suite falle, para conservar evidencia de
diagnóstico.

El quality gate de backend exige cobertura de lineas >= 60% mediante JaCoCo. Los reportes de
SonarCloud consumen los XML de JaCoCo generados por Gradle.

El pipeline Jenkins se mantiene como flujo complementario y esta documentado en
`docs/ci/jenkins.md`. Ejecuta checkout, build, pruebas, analisis de calidad, build Docker,
despliegue preview con Docker Compose y E2E con Playwright.

El Jenkins local se entrega preconfigurado con el usuario `admin`, el job
`inventory-avance-ci` y todas las herramientas requeridas. Se inicia desde la raiz con:

```bash
./scripts/security/init-secret-env.sh jenkins
docker compose --env-file .env.jenkins \
  -p inventory-jenkins \
  -f compose.jenkins.yml \
  up -d --build --wait
```

La interfaz queda disponible en `http://localhost:18080`. El password se lee
del archivo local ignorado `.env.jenkins`; la guía de operación, reinicio y
limpieza está en `docs/ci/jenkins.md`.

| Evidencia | Comando local | Reporte local | Artifact CI |
|-----------|---------------|---------------|-------------|
| Build backend | `cd backend && ./gradlew clean assemble` | `backend/build/libs/*.jar` | `backend-build-*` |
| Unit tests | `cd backend && ./gradlew test` | `test-results/backend/unit/` después del recolector | `test-results-backend-unit-*` |
| Cobertura unit tests | `cd backend && ./gradlew test jacocoTestReport jacocoTestCoverageVerification` | `test-results/backend/unit/evidence/coverage/` | `test-results-backend-unit-*` |
| Integration tests | `cd backend && ./gradlew integrationTest` | `test-results/backend/integration/` después del recolector | `test-results-backend-integration-*` |
| Cobertura integration tests | `cd backend && ./gradlew integrationTest` | `test-results/backend/integration/evidence/coverage/` | `test-results-backend-integration-*` |
| API tests | `cd backend && ./gradlew apiTest` | `test-results/backend/api/` después del recolector | `test-results-backend-api-*` |
| Frontend unit + coverage | `cd frontend && pnpm test` | `test-results/frontend/unit/` | `test-results-frontend-unit-*` |
| E2E Playwright | `cd tests/e2e && pnpm test` | `test-results/e2e/playwright/` | `test-results-e2e-playwright-*`, Jenkins Pipeline |
| Staging post-deploy | `./scripts/staging/post-deploy.sh` | `test-results/staging/post-deploy/` después del recolector | `test-results-staging-post-deploy-<DEPLOYED_SHA>-<run_attempt>`, solo con safety `PASS` |

Estado de automatizacion de testing:

| Tipo | Estado | Detalle |
|------|--------|---------|
| Unit | Automatizada en CI | JUnit/Mockito ejecutado por `./gradlew test` y publicado con JaCoCo. |
| Integration | Automatizada | Testcontainers ejecutado por `./gradlew integrationTest`; los reportes se publican para diagnosticar fallos de entorno. |
| API | Automatizada en CI | RestAssured valida contratos REST, status codes, errores y permisos en `backend/src/apiTest`. |
| Frontend | Automatizada en CI | Angular/Karma ejecuta unit tests con cobertura y publica artifact `test-results-frontend-unit-*`. |
| E2E | Automatizada en GitHub Actions y Jenkins | Playwright cubre login, CRUD de productos, roles, accesibilidad, responsive y navegadores; CI desactiva HTML, screenshots automáticos, traces y videos, y publica JUnit y evidencia UX controlada solo después del safety. |
| Post-deploy staging | Automatizada en GitHub Actions | Despliega `DEPLOYED_SHA`, ejecuta siete fases y solo publica evidencia tras el safety final. Playwright staging usa `list` + JUnit y capturas controladas, sin HTML, traces ni videos. |

La ruta única de resultados locales y artifacts es `test-results/`. La guía
consolidada de comandos, estructura, resúmenes JSON y métricas Prometheus está
en `docs/testing/ci-reporting.md`.

## Observabilidad

Una vez levantado el sistema:

| Herramienta | URL |
|-------------|-----|
| Grafana | Development `http://localhost:3000`; staging `http://127.0.0.1:13000` |
| Prometheus | Development `http://localhost:9090`; staging `http://127.0.0.1:19090` |
| Loki | Development `http://localhost:3100`; staging `http://127.0.0.1:13100` |
| Tempo | Development `http://localhost:3200`; staging `http://127.0.0.1:13200` |
| Alertmanager | Development `http://localhost:9093`; staging `http://127.0.0.1:19093` |

Los puertos staging se enlazan exclusivamente a loopback. El gate post-deploy comprueba readiness,
el target actual del backend en Prometheus y los datasources de Grafana. Alloy filtra por el
proyecto Compose actual; Loki exige un marcador nuevo con esa label y Tempo exige una traza
posterior al inicio del check con el `deployment.id` de este preview.


## Documentacion
- `docs/security/keycloak.md`: configuracion de seguridad, usuarios demo, scopes y permisos.
- `docs/security/secrets-management.md`: contrato de secretos, rotación, Gitleaks, Jenkins y GitHub Actions.
- `docs/ci/jenkins.md`: pipeline Jenkins, credenciales, stages, reportes y artifacts.
- `docs/deployment/staging.md`: despliegue staging reproducible, secretos, validacion, promocion y rollback.
- `docs/testing/ci-reporting.md`: guia de testing, cobertura, artifacts y evidencia para PRs.

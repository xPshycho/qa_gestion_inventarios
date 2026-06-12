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
| Backend | http://localhost:8080/health | Healthcheck HTTP del stub de API |
| Keycloak | http://localhost:8081 | Realm `inventory` para OAuth2/JWT |
| PostgreSQL | localhost:5432 | Base de datos local para desarrollo |
| Flyway | Servicio interno | Aplica migraciones antes de iniciar el backend |

Los puertos pueden cambiarse en `.env` usando `FRONTEND_PORT`, `BACKEND_PORT`, `KEYCLOAK_PORT`
y `POSTGRES_PORT`.
Si el puerto local `5432` ya esta ocupado, usar por ejemplo `POSTGRES_PORT=55432`.
La interfaz Angular consume la API del backend mediante la ruta `/api`.

## Migraciones de base de datos

Flyway ejecuta las migraciones versionadas ubicadas en `backend/src/main/resources/db/migration`.
El servicio `backend` inicia despues de que Flyway aplica correctamente los scripts sobre PostgreSQL.

```bash
# Levantar PostgreSQL, ejecutar migraciones y dejar el entorno local arriba
POSTGRES_PORT=55432 docker compose up --build -d

# Ver estado de servicios y confirmar que Flyway completo su ejecucion
POSTGRES_PORT=55432 docker compose ps

# Validar datos iniciales de productos
POSTGRES_PORT=55432 docker compose exec postgres \
  psql -U inventory_user -d inventory -c "SELECT sku, name, current_stock FROM products ORDER BY sku;"

# Validar permisos y roles iniciales
POSTGRES_PORT=55432 docker compose exec postgres \
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
├── frontend/                   # Interfaz React
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
| Staging | Replica de produccion para pruebas post-deploy | TBD |
| Production | Ambiente final | TBD |

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
# Unit tests
cd backend && TBD

# Integration tests (requiere Docker)
cd backend && TBD

# Frontend
cd frontend && CHROME_BIN=/usr/bin/chromium pnpm test

# Build frontend
cd frontend && pnpm build

# E2E con Playwright, Keycloak y base de datos real
cd tests/e2e
npx --yes pnpm@10.12.1 install
PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH=/usr/bin/chromium npx --yes pnpm@10.12.1 test

# Performance tests
TBD

# Security scan
TBD
```

### Pruebas E2E con Playwright

La suite E2E valida flujos reales de usuario contra el frontend Angular, backend Spring Boot,
PostgreSQL y Keycloak. Cubre disponibilidad del entorno, login/logout, CRUD de productos,
permisos por rol y una verificacion responsive en vista movil.

Antes de ejecutar la suite despues de cambiar de rama, reconstruir el stack para evitar imagenes
Docker desactualizadas:

```bash
docker compose up --build -d
```

Comandos principales:

```bash
cd tests/e2e

# Instalar dependencias
npx --yes pnpm@10.12.1 install

# Ejecutar toda la suite
PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH=/usr/bin/chromium npx --yes pnpm@10.12.1 test

# Ejecutar una prueba especifica
PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH=/usr/bin/chromium \
  ./node_modules/.bin/playwright test specs/products-crud.spec.ts

# Abrir el reporte HTML generado
./node_modules/.bin/playwright show-report
```

Variables opcionales:

| Variable | Valor por defecto | Uso |
|----------|-------------------|-----|
| `E2E_BASE_URL` | `http://localhost:5173` | URL del frontend |
| `E2E_BACKEND_URL` | `http://localhost:8080` | URL del backend |
| `E2E_KEYCLOAK_URL` | `http://localhost:8081` | URL publica de Keycloak |
| `E2E_MANAGE_STACK` | `true` | Permite iniciar Docker Compose si los servicios no responden |
| `PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH` | Detectado por Playwright | Ruta de Chromium local |

Playwright genera capturas, trazas, videos y el reporte en `tests/e2e/test-results/` y
`tests/e2e/playwright-report/`. Esos artefactos no se versionan; se adjuntan como evidencia en el
Pull Request cuando corresponda.

## Observabilidad

Una vez levantado el sistema:

| Herramienta | URL |
|-------------|-----|
| Grafana | `TBD` |
| Prometheus | `TBD` |
| Alertmanager | `TBD` |


## Documentacion
`TBD`

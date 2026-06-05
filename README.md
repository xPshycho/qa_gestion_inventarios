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
| Frontend | React |
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
| Frontend | http://localhost:5173 | Stub temporal para validar el entorno local |
| Backend | http://localhost:8080/health | Healthcheck HTTP del stub de API |
| PostgreSQL | localhost:5432 | Base de datos local para desarrollo |

Los puertos pueden cambiarse en `.env` usando `FRONTEND_PORT`, `BACKEND_PORT` y `POSTGRES_PORT`.
Los stubs de backend y frontend se reemplazaran por las aplicaciones reales cuando se implementen
los issues de API y UI.

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
│   ├── migrations/             # Scripts Flyway
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

# E2E tests
TBD

# Performance tests
TBD

# Security scan
TBD
```

## Observabilidad

Una vez levantado el sistema:

| Herramienta | URL |
|-------------|-----|
| Grafana | `TBD` |
| Prometheus | `TBD` |
| Alertmanager | `TBD` |


## Documentacion
`TBD`

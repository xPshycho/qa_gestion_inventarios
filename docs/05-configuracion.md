# Configuración

## Principios

- Los ejemplos `.env*.example` contienen nombres/contrato, no valores reales.
- `.env`, `.env.jenkins`, `.staging/` y estado de producción son locales o
  secretos administrados.
- Nunca ejecutar ni publicar `docker compose config` sin redacción: expande
  secretos.
- Los secretos de GCP se gestionan en Secret Manager; los de GitHub/Jenkins en
  sus almacenes de credenciales.

## Variables por consumidor

| Grupo | Variables principales verificadas | Consumidor |
|---|---|---|
| PostgreSQL | `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_PORT` | PostgreSQL/Flyway/backend |
| Backend | `SPRING_DATASOURCE_*`, `INVENTORY_CORS_ALLOWED_ORIGINS`, `SERVER_PORT` | Spring Boot |
| JWT | `SPRING_SECURITY_OAUTH2_RESOURCESERVER_JWT_ISSUER_URI`, `...JWK_SET_URI` | Spring Security |
| Keycloak admin | `KEYCLOAK_ADMIN_URL`, `...REALM`, `...CLIENT_ID`, `...CLIENT_SECRET` | backend |
| Frontend | `KEYCLOAK_PUBLIC_URL`, `KEYCLOAK_REALM`, `KEYCLOAK_CLIENT_ID`, `BACKEND_UPSTREAM` | entrypoint/Nginx |
| Telemetría | `OTEL_*`, puertos Prometheus/Grafana/Loki/Tempo/Alloy/Alertmanager | backend/stack observabilidad |
| Pruebas | usernames y contraseñas `E2E_*`, `K6_*`, URLs base | Playwright/k6/scripts |

Fuente del backend:

Ruta: `backend/src/main/resources/application.properties`\
Líneas aproximadas: 1-31\
Componente: configuración Spring\
Responsabilidad: datasource obligatorio, Flyway/Envers, Actuator, issuer/JWK,
cliente admin y CORS. Los passwords/client secret no tienen valor por defecto.

Fuente del frontend:

Ruta: `frontend/docker-entrypoint.sh`\
Líneas aproximadas: archivo completo\
Componente: configuración runtime\
Responsabilidad: genera `auth-config.json` y Nginx a partir del entorno sin
incrustar URLs/secretos durante el build.

## Puertos

| Servicio | Contenedor | Development host | Staging host |
|---|---:|---:|---:|
| Frontend/Nginx | 8080 | 5173 | 15173 loopback |
| Backend | 8080 | 8080 | 18082 loopback |
| Keycloak HTTP | 8080 | 8081 | 18081 loopback |
| Keycloak management | 9000 | no publicado | 19000 loopback |
| PostgreSQL | 5432 | 55432 | no publicado |
| Prometheus | 9090 | 9090 | 19090 loopback |
| Grafana | 3000 | 3000 | 13000 loopback |
| Loki | 3100 | 3100 | 13100 loopback |
| Tempo query | 3200 | 3200 | 13200 loopback |
| OTLP gRPC/HTTP | 4317/4318 | interno | interno |
| Alloy UI | 12345 | 12345 | 12346 loopback |
| Alertmanager | 9093 | 9093 | 19093 loopback |
| Jenkins | 8080 contenedor | 18080 | no aplica |
| Jenkins agent | 50000 | 50000 | no aplica |
| DinD TLS | 2376 | interno | no aplica |

Producción VM publica TCP 80/443 y permite TCP 22 solo desde IAP. Nginx enruta
`/`, `/api/`, `/auth/` y `/grafana/`; no se deben abrir puertos internos para
diagnóstico. Matriz detallada: [`../puertos.md`](../puertos.md).

## URLs

| Entorno | Frontend | API | Keycloak |
|---|---|---|---|
| Development | `http://localhost:5173` | `http://localhost:8080` o `/api` vía frontend | `http://localhost:8081` |
| Staging local | `http://127.0.0.1:15173` | `/api` vía frontend | `http://127.0.0.1:18081` |
| GCP development | `https://inventory-development-po26gewv5q-uc.a.run.app` | `/api` | `/auth` |
| GCP staging | **Pendiente de verificación**; no se observó servicio Cloud Run | no disponible | no disponible |
| Producción VM | `https://34.123.136.144` | `/api` | `/auth` |

La API no tiene prefijo de versión (`/v1` no existe).

## Validación segura

`Verificado · no muestra valores`

```bash
./scripts/security/init-secret-env.sh local
make check-config
```

`No verificado · seguro si se listan solo nombres`

```bash
awk -F= '/^[A-Z0-9_]+=/ {print $1}' .env.example | sort -u
```

## Rotación

Local, `Destructivo para datos si se recrean volúmenes`:

```bash
./scripts/security/init-secret-env.sh local --rotate
# Respaldar antes de recrear servicios dependientes.
docker compose up -d --force-recreate
```

GCP: crear una nueva versión, coordinar el consumidor real, actualizar
`secret_version`, plan/apply, validar y solo después deshabilitar la versión
anterior. PostgreSQL/Keycloak no se rotan cambiando únicamente Secret Manager.
Procedimiento y límites:
[Guía operativa GCP/OpenTofu](27-guia-operativa-gcp-opentofu.md#rotación-de-secretos).
No se documenta `versions access` porque no es necesario para rotar y expondría
el valor.

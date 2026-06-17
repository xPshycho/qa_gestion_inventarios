# Grafana y dashboard operativo

Esta guia documenta el stack de observabilidad del issue #52. El objetivo es validar metricas reales del backend desde Prometheus y visualizarlas en Grafana con configuracion versionada.

## Servicios

| Servicio | URL local | Uso |
|---|---|---|
| Prometheus | `http://localhost:9090` | Scraping y consulta de metricas |
| Grafana | `http://localhost:3000` | Dashboard operativo |
| Backend metrics | `http://localhost:8080/actuator/prometheus` | Endpoint Prometheus del backend |

Las credenciales demo de Grafana son:

| Usuario | Contrasena |
|---|---|
| `admin` | `cambiar` |

Los valores se pueden cambiar en `.env` con `GRAFANA_ADMIN_USER`, `GRAFANA_ADMIN_PASSWORD`, `GRAFANA_PORT` y `PROMETHEUS_PORT`.

## Archivos versionados

| Archivo | Proposito |
|---|---|
| `infra/observability/prometheus/prometheus.yml` | Targets de Prometheus |
| `infra/observability/grafana/provisioning/datasources/prometheus.yml` | Datasource Prometheus provisionado |
| `infra/observability/grafana/provisioning/dashboards/inventory.yml` | Provider del dashboard |
| `infra/observability/grafana/dashboards/inventory-operational-dashboard.json` | Dashboard operativo exportado |

## Ejecucion local

```bash
docker compose up --build -d backend prometheus grafana
docker compose ps
```

Verificar metricas del backend:

```bash
curl -fsS http://localhost:8080/actuator/prometheus | head
```

Verificar Prometheus:

```bash
curl -fsS http://localhost:9090/-/ready
curl -fsS "http://localhost:9090/api/v1/query?query=up"
```

Verificar Grafana:

```bash
curl -fsS http://localhost:3000/api/health
```

Luego abrir `http://localhost:3000`, iniciar sesion y entrar a `Inventory / Inventory Operational Dashboard`.

## Dashboard

El dashboard operativo incluye:

- estado del backend;
- throughput HTTP;
- latencia promedio HTTP;
- uso de CPU del proceso;
- memoria heap JVM;
- conexiones HikariCP activas e inactivas;
- requests por endpoint;
- tasa de respuestas HTTP 5xx.

Si los paneles aparecen vacios, generar trafico contra el backend y esperar al siguiente scrape de Prometheus:

```bash
curl -fsS http://localhost:8080/actuator/health
curl -fsS http://localhost:8080/actuator/prometheus >/dev/null
```

## Evidencia para PR

Adjuntar en el PR:

- salida de `docker compose ps`;
- salida de `curl -fsS http://localhost:8080/actuator/prometheus | head`;
- captura del dashboard de Grafana;
- captura o salida de Prometheus mostrando el target `inventory-backend` en estado UP.

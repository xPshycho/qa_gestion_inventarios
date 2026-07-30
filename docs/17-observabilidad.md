# Observabilidad

## Stack

| Componente | Responsabilidad |
|---|---|
| Spring Actuator/Micrometer | health y métricas Prometheus |
| OpenTelemetry | trazas/correlación |
| Prometheus | scrape backend/Keycloak y evaluación de reglas |
| Alloy | receiver OTLP y descubrimiento/logs Docker |
| Loki | logs |
| Tempo | trazas |
| Grafana | dashboards/datasources |
| Alertmanager | enrutamiento de alertas |
| GCP Ops Agent | telemetría de la VM |

## Flujo

Véase [diagrama](diagrams/observabilidad.md).

Ruta: `infra/observability/prometheus/prometheus.yml`\
Líneas aproximadas: 1-25\
Componente: Prometheus\
Responsabilidad: scrape cada 15 s de backend
`/actuator/prometheus` y Keycloak management `/metrics`.

Ruta: `infra/observability/prometheus/rules/inventory-alerts.yml`\
Líneas aproximadas: 1-33\
Componente: alertas\
Responsabilidad: backend down, error rate >5 %, p95 >1 s, CPU >85 % y Hikari
>90 %.

Ruta: `infra/observability/alloy/config.alloy`\
Líneas aproximadas: 1-83\
Componente: Alloy\
Responsabilidad: OTLP -> Tempo; descubre contenedores del
`COMPOSE_PROJECT_NAME`, etiqueta `compose_project`, `compose_service` y
`deployment_id`, extrae correlación y envía logs a Loki.

## Health y consultas

`Health verificado al iniciar stacks de pruebas; consultas siguientes no
repetidas en el run del 29/30 de julio`

```bash
curl --fail http://localhost:8080/actuator/health
curl --fail http://localhost:9090/-/ready
curl --fail http://localhost:3000/api/health
curl --fail http://localhost:3100/ready
curl --fail http://localhost:3200/ready
curl --fail http://localhost:9093/-/ready
```

Targets:

```bash
curl --fail --silent \
  http://localhost:9090/api/v1/targets |
  jq '.data.activeTargets[] | {scrapeUrl,health,lastError}'
```

PromQL:

```bash
curl --get --fail --silent \
  --data-urlencode 'query=up{job="inventory-backend"}' \
  http://localhost:9090/api/v1/query | jq .
```

Loki:

```bash
curl --get --fail --silent \
  --data-urlencode 'query={compose_service="backend"}' \
  http://localhost:3100/loki/api/v1/query_range | jq .
```

No incluir tokens, passwords o payloads personales en consultas/evidencias.

## Evidencia versionada

Una ejecución exploratoria del 25 de julio de 2026 sí preservó resultados
detallados de development:

- [targets Prometheus UP](testing/evidence/exploratory/2026-07-25/EXP-OBS-01-02-prometheus-targets-up.png);
- [JSON de targets](testing/evidence/exploratory/2026-07-25/EXP-OBS-01-prometheus-targets.json);
- [métrica de negocio](testing/evidence/exploratory/2026-07-25/EXP-OBS-01-prometheus-business-metric.json);
- [alerta controlada en firing](testing/evidence/exploratory/2026-07-25/EXP-OBS-01-04-alerta-backend-down-firing.png);
- [estado resuelto](testing/evidence/exploratory/2026-07-25/EXP-OBS-01-alertmanager-resolved.json);
- [dashboard con paneles sin datos](testing/evidence/exploratory/2026-07-25/EXP-OBS-01-01-dashboard-paneles-sin-datos.png).

La interpretación y limitaciones están en el
[índice de evidencia](evidence/observability/README.md). Esta evidencia no se
atribuye a producción.

## Grafana

Development `http://localhost:3000`; staging
`http://127.0.0.1:13000`; producción esperada `/grafana/`. Datasources
versionados: Prometheus, Loki y Tempo.

El password admin viene del secret store del entorno. Revisar
`Administration -> Data sources` y el dashboard versionado.

## Hallazgos

1. El dashboard usa
   `http_server_requests_seconds_bucket`, pero no se verificó que la
   distribución/histogram esté publicada. Si no existe, p95 y alerta quedan
   vacíos.
2. El panel Loki usa `{container=~".*backend.*"}` mientras Alloy define
   `compose_service`; la consulta canónica debe usar
   `{compose_service="backend"}`.
3. El panel Tempo/query y links log-trace requieren validación visual.
4. GCP tenía 0 alert policies, notification channels, dashboards y uptime
   checks.
5. No se pudo verificar el stack interno de la VM por falta de OS Login.
6. Firewall logging estaba deshabilitado.

Estado de dashboards/alertas de producción: **Pendiente de verificación**.

## Diagnóstico de target caído

1. `docker compose ps backend prometheus`.
2. `curl backend health`.
3. consultar `/api/v1/targets` y `lastError`.
4. desde red Compose, confirmar `backend:8080/actuator/prometheus`.
5. revisar reglas de Spring: GET Prometheus es público.
6. revisar reloj, DNS Compose y labels.

`No verificado · reinicio seguro local`

```bash
docker compose restart prometheus
docker compose logs --tail=200 prometheus
```

En producción no reiniciar automáticamente: confirmar réplica/impacto, tomar
evidencia y usar el runbook autorizado.

## Retención

La retención local de volúmenes no está parametrizada en la documentación
canónica: persiste hasta limpieza del volumen. GCP Logging: Default 30 días,
Required 400 días. Loki/Tempo/Prometheus de producción:
**Pendiente de verificación** desde su configuración efectiva/volúmenes.

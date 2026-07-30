# Evidencia de observabilidad

- Nombre: stack, dashboards, alertas y superficie de health.
- Fecha: 29/30 de julio de 2026.
- Entorno: stacks locales de prueba y endpoints públicos de VM/Cloud Run.
- Comandos: health de Compose durante E2E/k6/security; curl a VM y Cloud Run.
- Resultado: servicios Compose healthy; VM frontend/API/OIDC UP; Cloud Run UP
  tras cold start.
- Evidencia versionada:
  - dashboard
    [`inventory-final-observability.json`](../../../infra/observability/grafana/dashboards/inventory-final-observability.json);
  - [targets Prometheus UP](../../testing/evidence/exploratory/2026-07-25/EXP-OBS-01-02-prometheus-targets-up.png);
  - [dashboard exploratorio](../../testing/evidence/exploratory/2026-07-25/EXP-OBS-01-01-dashboard-paneles-sin-datos.png);
  - [alerta controlada en firing](../../testing/evidence/exploratory/2026-07-25/EXP-OBS-01-04-alerta-backend-down-firing.png);
  - [resultado estructurado de targets](../../testing/evidence/exploratory/2026-07-25/EXP-OBS-01-prometheus-targets.json);
  - `docs/17-observabilidad.md`.
- Interpretación: health externo aprobado; el run exploratorio del 25 de julio
  demostró targets y transición de alerta, y también detectó paneles sin datos.
- Requisito: métricas, logs, trazas, dashboard y alertas.
- Limitaciones: las capturas/queries corresponden a development del 25 de
  julio, no a producción; interior VM pendiente por OS Login; dashboard tiene
  queries por corregir. En GCP se observaron cero dashboards, alert policies,
  notification channels y uptime checks administrados.

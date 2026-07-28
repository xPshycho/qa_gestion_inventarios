# Stack final de observabilidad

El Compose raíz despliega Prometheus, Grafana, Alloy, Loki, Tempo y Alertmanager junto al sistema de inventario. Prometheus recoge métricas de Actuator; Alloy recibe trazas OTLP y recoge los logs de contenedores; Grafana consulta las tres fuentes de datos.

## Verificación local

```bash
docker compose up --build -d
./scripts/verify-observability.sh
```

Generar una solicitud al backend y abrir Grafana en `http://localhost:3000`:

1. En **Inventory Final Observability**, verificar infraestructura, aplicación, negocio y seguridad.
2. En **Explore / Loki**, consultar
   `{compose_project="inventory-platform", compose_service="backend"}` en
   desarrollo. Para staging, sustituir el proyecto por el
   `COMPOSE_PROJECT_NAME` registrado en `deployment.json`.
3. En **Explore / Tempo**, buscar `{ resource.service.name = "inventory-backend" }` o el identificador de traza.
4. En Prometheus o Alertmanager, verificar las reglas `InventoryBackendDown`, `InventoryHighErrorRate` y `InventoryHighLatencyP95`.

Las alertas se entregan al receptor local de Alertmanager para no almacenar secretos. Para un ambiente externo, sustituirlo por un receptor webhook, Slack o SMTP mediante secretos/variables protegidas.

## Evidencia para el PR

- `docker compose ps` con todos los servicios saludables.
- Target `inventory-backend` UP en Prometheus.
- Capturas de dashboards y de los datasources Prometheus, Loki y Tempo.
- Una consulta LogQL, una traza de Tempo y una alerta visible en Alertmanager.

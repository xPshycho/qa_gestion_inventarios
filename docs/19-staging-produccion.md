# Staging y producción

## Matriz

| Aspecto | Development | Staging local/CI | GCP development | Producción VM |
|---|---|---|---|---|
| Runtime | Compose | Compose aislado | Cloud Run multi-container | Compose |
| Exposición | localhost | loopback runner | público `run.app` | 80/443 |
| Base | PostgreSQL contenedor | volumen exclusivo | Cloud SQL | PostgreSQL contenedor |
| Keycloak | `start-dev` | `start`/config estricta | sidecar | contenedor |
| Secretos | `.env` 0600 | `.staging/`/CI | Secret Manager | estado compartido/CI |
| Evidencia | `test-results/` | 7 fases + safety | logs GCP/pruebas | workflow/evidence VM |

No existe un servicio Cloud Run staging o production observado. Sí apareció
una red y Cloud SQL privada staging `RUNNABLE`, sin consumidor Cloud Run
observado. La producción real es la VM; OpenTofu representa una plataforma
objetivo/parcial.

## Staging

Runbook detallado: [`deployment/staging.md`](deployment/staging.md).

`Verificado históricamente por evidencia issue #86; no repetido en esta auditoría`

```bash
./scripts/staging/init-env.sh
./scripts/staging/deploy.sh
./scripts/staging/post-deploy.sh
```

El post-deploy valida health, login, API, flujo, Playwright, headers, ZAP, k6,
observabilidad y safety. Puertos solo en `127.0.0.1`; el proyecto Compose debe
comenzar con `inventory-staging-`.

Destrucción staging:

`Destructivo para el staging aislado`

```bash
./scripts/staging/destroy.sh --volumes
```

Confirmar el nombre/contrato del proyecto antes; no ejecutar sobre development
o producción.

## Producción VM

URL verificada: `https://34.123.136.144`.

Predeploy:

- SHA inmutable y gates aprobados;
- snapshot/backup y espacio disponibles;
- secretos/referencias válidos;
- certificado/health actual;
- ventana y responsable de rollback;
- migraciones revisadas por compatibilidad hacia atrás;
- no hay proceso OpenTofu concurrente sobre el mismo recurso.

Flujo real: workflow `.github/workflows/gcp-production-deploy.yml` transfiere
scripts, clona un release por SHA bajo `/opt/inventory/releases`, renderiza
estado en `/opt/inventory/shared` y ejecuta `scripts/gcp/deploy.sh`.

No se ejecutó despliegue en esta auditoría documental.

## Smoke posterior

`Verificado sobre versión vigente`

```bash
curl --fail https://34.123.136.144/health
curl --fail https://34.123.136.144/api/actuator/health
curl --fail \
  https://34.123.136.144/auth/realms/inventory/.well-known/openid-configuration
```

Además: login viewer, GET productos/reportes sin mutación, targets/métricas,
errores/latencia por 15-30 minutos y estado TLS.

## Cloud Run development

Health público aprobado tras cold start. Min scale 0 explica latencia inicial.
Un release posterior estaba `Retired`; investigar sus logs antes de promover
la misma imagen/configuración.

## Aprobaciones y promoción

Las reglas versionadas esperan `develop -> staging -> main`; producción usa
WIF de `main`/environment.

Estado público verificado el 29 de julio de 2026:

- `production`: required reviewer `Code-Hdez`, autoaprobación impedida y branch
  policy limitada a `main`;
- `staging`: Environment existente, pero sin required reviewer ni branch
  policy;
- `development`: Environment consumido por el deploy GCP administrado, sin
  reglas de aprobación.

Por tanto, producción tiene aprobación implementada; staging conserva una
brecha de control. `ci-required.yml` conecta staging con
`gcp-managed-deploy.yml`, pero su ejecución real aún debe validarse porque el
primer job equivalente de development quedó `skipped`. Detalle y responsables
en la
[guía operativa GCP/OpenTofu](27-guia-operativa-gcp-opentofu.md#github-environments).

## Costos/dimensionamiento

VM `e2-standard-8` mostró utilización baja en una ventana corta de la auditoría
previa (CPU aprox. 2.7 %, memoria aprox. 9 %). No redimensionar con una muestra
corta: recoger al menos 14-30 días con p95/p99, picos, headroom y ventana de
rollback. Cloud SQL `db-f1-micro` es development, no una recomendación
productiva.

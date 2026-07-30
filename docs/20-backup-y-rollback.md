# Backup y rollback

## Principios

- rollback de aplicación y restauración de datos son decisiones distintas;
- tomar backup antes de migraciones no reversibles;
- preferir imágenes/SHA inmutables;
- no ejecutar pruebas de rollback destructivas en producción durante una
  auditoría documental;
- toda validación debe incluir health, login, lectura y métricas.

## Producción VM

Tecnología real: releases por SHA bajo `/opt/inventory`, estado compartido y
script `scripts/gcp/rollback.sh`.

| Campo | Procedimiento |
|---|---|
| Condición | 5xx, health fallido, login/API crítica rota o regresión severa después del deploy |
| Versión actual | leer el release/`DEPLOYED_SHA` registrado |
| Versión anterior | release previamente aprobado presente en `releases/` |
| Backup | snapshot VM + dump/backup del estado de datos según runbook |
| Acción | ejecutar `rollback.sh` con paths/SHAs exactos |
| Validación | health, OIDC, viewer smoke, métricas/logs |
| Contingencia | restaurar datos a instancia/volumen separado o mantener servicio degradado mientras se recupera |

`No verificado en producción · Solo producción · Requiere IAP/sudo`

```bash
sudo env \
  GCP_DEPLOY_PATH=/opt/inventory \
  PRODUCTION_STATE_DIR=/opt/inventory/shared \
  PRODUCTION_ENV_FILE=/opt/inventory/shared/production.env \
  PRODUCTION_EVIDENCE_DIR=/opt/inventory/shared/evidence/<SHA_FALLIDO> \
  bash /opt/inventory/releases/<SHA_FALLIDO>/scripts/gcp/rollback.sh
```

Este comando cambia contenedores/release. Sustituir placeholders después de
resolver y registrar ambas versiones. No copiar el env file.

El script limita el cambio de backend/frontend con `--no-deps` según el
runbook; revisar su output y no usar `docker compose down -v`.

## Cloud Run

`No verificado · cambia tráfico`

```bash
gcloud run services update-traffic inventory-development \
  --project=project-e70349a8-c787-4733-9a0 \
  --region=us-central1 \
  --to-revisions=<REVISION_ANTERIOR>=100
```

Antes: listar revisiones y confirmar que la anterior está Ready y usa
configuración/DB compatible. Después: health/OIDC/viewer smoke. Reversión:
redirigir 100 % a la revisión original.

## Staging seguro

El issue #86 documenta una simulación/validación de recuperación. Repetir:

1. desplegar SHA A;
2. tomar evidencia/backup;
3. desplegar SHA B compatible;
4. ejecutar rollback a A;
5. verificar siete fases;
6. destruir solo el staging aislado.

No se repitió en esta auditoría para respetar “solo documentación”.

## Base de datos

Cloud SQL tenía backup/PITR habilitado, pero no restore drill. Restaurar a una
instancia nueva, no sobre la original, y validar antes de conmutar.

`Destructivo/costoso · Pendiente de verificación · requiere aprobación`

```bash
gcloud sql backups list \
  --instance=inventory-development \
  --project=project-e70349a8-c787-4733-9a0
# La creación/restauración de una instancia se omite deliberadamente hasta
# disponer de nombre, backup ID, RPO/RTO, costo y aprobación.
```

PostgreSQL local: véase [backup/restauración](06-base-de-datos.md#backup-local).

## Riesgos

- migración no backward-compatible puede impedir rollback de binario;
- rollback sin backup puede consolidar pérdida;
- los secrets actuales pueden no ser compatibles con release antiguo;
- certificate/gateway puede ser la causa, no la app;
- Cloud Run min 0 puede parecer fallo por cold start;
- una instancia SQL privada estaba en creación concurrente.

## Evidencia requerida

Fecha, ambiente, current/previous SHA, comandos, snapshot/backup ID, duración,
health antes/después, pruebas, métricas, responsable y decisión. No adjuntar
secrets ni dumps.

# Operación y mantenimiento

## Checklist diario

1. Health frontend/API/OIDC.
2. Estado de contenedores/Cloud Run/SQL.
3. Targets Prometheus y alertas.
4. errores 5xx, latencia y saturación Hikari/CPU/memoria/disco.
5. backup/snapshot más reciente.
6. expiración y renovación TLS.
7. deployments/revisiones recientes.

## Local

`Verificado`

```bash
docker compose ps
curl --fail http://localhost:5173/health
curl --fail http://localhost:8080/actuator/health
docker compose logs --tail=200 backend
```

Reinicio acotado:

```bash
docker compose restart backend
docker compose ps backend
curl --fail http://localhost:8080/actuator/health
```

No usar `down -v` como reinicio.

## VM de producción

Los siguientes comandos no pudieron ejecutarse por falta de OS Login.

`No verificado · Solo producción · Requiere IAP/OS Login/sudo`

```bash
gcloud compute ssh qa-inventario \
  --project=project-e70349a8-c787-4733-9a0 \
  --zone=us-central1-a \
  --tunnel-through-iap

sudo docker ps
sudo ss -lnt
sudo systemctl status inventory-certbot-renew.timer --no-pager
sudo systemctl list-timers inventory-certbot-renew.timer --no-pager
sudo /opt/certbot/bin/certbot certificates
```

No ejecutar `cat /opt/inventory/shared/production.env`, `set -x` ni
`docker compose config`: exponen secretos.

Estado externo, `Verificado`:

```bash
curl --fail https://34.123.136.144/health
curl --fail https://34.123.136.144/api/actuator/health
curl --fail \
  https://34.123.136.144/auth/realms/inventory/.well-known/openid-configuration
```

El certificado observado vence el 4 de agosto de 2026: comprobar el timer y
hacer un `certbot renew --dry-run` solo durante una ventana autorizada.

## Cloud Run/SQL

`Verificado · Requiere IAM`

```bash
gcloud run services describe inventory-development \
  --project=project-e70349a8-c787-4733-9a0 \
  --region=us-central1
gcloud run revisions list \
  --project=project-e70349a8-c787-4733-9a0 \
  --region=us-central1 \
  --service=inventory-development
gcloud sql instances describe inventory-development \
  --project=project-e70349a8-c787-4733-9a0
```

Las instancias privadas development/staging convergieron a `RUNNABLE` durante
la auditoría. Reconfirmar bases y consumidores antes de usarlas y no eliminar
recursos duplicados sin conocer el proceso OpenTofu concurrente.

## Mantenimiento preventivo

- actualizar dependencias mediante PR con build, tests, ZAP/Trivy y rollback;
- renovar imágenes fijando nuevos digests;
- probar restore trimestralmente en aislamiento;
- revisar IAM, WIF, usuarios y secretos;
- revisar certificado antes de cada vencimiento;
- verificar retención/capacidad de volúmenes;
- validar dashboard/alertas tras cambios de métricas/labels;
- revisar CVE y findings Trivy;
- comparar OpenTofu plan con inventario real sin aplicar.

## Mantenimiento correctivo

1. declarar incidente/ambiente/impacto;
2. congelar despliegues;
3. capturar health, versión, logs y métricas sanitizados;
4. decidir fix forward o rollback;
5. respaldar base antes de una acción de datos;
6. ejecutar procedimiento aprobado;
7. smoke + monitoreo;
8. documentar causa, tiempos y prevención.

## Actualización

No actualizar directamente contenedores productivos. Construir por SHA,
publicar imagen inmutable, ejecutar gates, promover staging y usar el workflow.
La reversión se describe en [backup/rollback](20-backup-y-rollback.md).
Para OpenTofu, aprobaciones GCP, recuperación de state y matriz del issue #109,
usar la [guía operativa GCP/OpenTofu](27-guia-operativa-gcp-opentofu.md).

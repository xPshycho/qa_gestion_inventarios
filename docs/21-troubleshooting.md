# Troubleshooting

| Síntoma | Causa probable | Diagnóstico | Solución | Evidencia |
|---|---|---|---|---|
| Gradle usa Java incorrecto | host fuera de Java 21 | `java -version` | usar `scripts/testing/run_with_java_21.sh` | versión + build log |
| pnpm/Node rechaza engines | host Node 25/pnpm 11 | `node -v; pnpm -v` | Node 22 + pnpm 10.12.1 o scripts Docker | versiones |
| Puerto ocupado | stack previo/servicio host | `ss -lnt` y `docker compose ps` | detener stack correcto o cambiar `.env` | listener/proyecto |
| Backend no inicia | DB/Flyway/issuer/secret | health + logs sanitizados | corregir variable o migración nueva | logs sin valores |
| Flyway falla | script/estado incompatible | logs + `flyway_schema_history` | no editar aplicada; nueva migración | history |
| 401 | token ausente/expirado/issuer | OIDC metadata y header | relogin/refresco; corregir issuer/JWK | status sin token |
| 403 | falta permiso claim | inspeccionar claims localmente sin publicar token | asignar rol/permisos correctos | prueba permitida/denegada |
| CORS | origin no listado | navegador + variable de origen | añadir origen exacto y redeploy | preflight |
| Eliminar producto da 500 | FK a movimientos (F-03) | logs + existencia movimientos | no borrar; definir manejo 409 en cambio funcional futuro | request ID |
| Playwright sin browser | ejecución nativa incompleta | `playwright --version` | usar `pnpm --dir tests/e2e test` Docker | summary |
| E2E flaky | servicio no ready/datos | JUnit, compose log | repetir una prueba, revisar readiness | trace local seguro |
| Coverage falla | nuevo código sin pruebas | HTML por paquete | añadir pruebas; no bajar gate sin decisión | JaCoCo/Karma |
| ZAP warnings | headers/CSP/cache | JSON ZAP | triage y corrección compatible | report JSON |
| Trivy falla | HIGH/CRITICAL corregible | JSON por target | actualizar dependencia/base image | report JSON |
| k6 threshold falla | errores/latencia/entorno | k6 summary + logs | separar auth/DB/CPU, repetir mismo perfil | summary |
| Prometheus target DOWN | endpoint/DNS/auth | `/api/v1/targets` | health, ruta, red Compose | `lastError` |
| Grafana panel vacío | métrica/label incorrecta | Explore Prometheus/Loki | corregir query; F-05 | query/result |
| Tempo sin trazas | OTEL desactivado/OTLP | Alloy/Tempo ready + logs | habilitar exporter y generar request | trace ID |
| Jenkins no inicia | DinD/JCasC/secret | Compose ps/log | revisar `.env.jenkins`, volumen y plugins | log |
| Jenkins no muestra report | suite no generó o ruta distinta | workspace/artifacts | corregir suite/ruta; `allowMissing` oculta ausencia | build |
| Cloud Run primer request tarda | min scale 0 | revisions/log/latency | esperar cold start o evaluar min scale/costo | timestamps |
| Cloud Run nueva revisión Retired | readiness/config | revisions/logging | mantener tráfico anterior; investigar | revision |
| Cloud SQL `PENDING_CREATE` | operación concurrente | `gcloud sql instances describe` | esperar/coordinar; no recrear | state |
| SSH IAP denied | falta OS Login/key IAM | `gcloud compute ssh --troubleshoot` | conceder mínimo rol temporal | IAM audit |
| Certificado próximo a vencer | timer/renewal no verificado | x509 + systemctl | validar timer/dry-run con operador | notAfter/timer |
| GCP permiso denegado | IAM insuficiente/API disabled | mensaje + policy | no habilitar API por diagnóstico; solicitar rol | comando/error |
| OpenTofu quiere reemplazar | deriva/state incompleto | `tofu plan` | importar/conciliar, revisar plan | plan guardado |
| Rollback falla | release/DB/secrets incompatibles | health/log/migrations | contingencia + restore aislado | SHA/backup |

## Comandos base

`Verificado local`

```bash
docker compose ps
docker compose logs --tail=200 backend
curl --fail http://localhost:8080/actuator/health
```

`Verificado GCP, solo lectura`

```bash
gcloud compute instances describe qa-inventario \
  --project=project-e70349a8-c787-4733-9a0 \
  --zone=us-central1-a
gcloud run revisions list \
  --project=project-e70349a8-c787-4733-9a0 \
  --region=us-central1 \
  --service=inventory-development
```

Antes de compartir logs:

```bash
./scripts/security/verify-artifacts.sh test-results/<suite>
```

No ejecutar `cat .env`, no pegar JWT en tickets y no abrir puertos internos
para “probar”.

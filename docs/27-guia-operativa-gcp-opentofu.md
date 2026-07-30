# Guía operativa GCP y OpenTofu

## Propósito y dictamen del issue #109

Esta guía responde al issue público
[#109](https://github.com/xPshycho/qa_gestion_inventarios/issues/109):
operación reproducible de `development`, `staging` y `production` en GCP,
OpenTofu, aprobaciones, incidentes, secretos, state y evidencia.

Estado documental: **Completo con dependencias técnicas explícitas**.
Estado remoto observado del issue: `open`.

Estado de dependencias consultado en modo público y solo lectura el 29 de julio
de 2026:

| Issue dependiente | Estado observado | Consecuencia |
|---|---|---|
| [#106 — Base GCP declarativa/OpenTofu](https://github.com/xPshycho/qa_gestion_inventarios/issues/106) | `closed` el 29-07-2026 | roots, módulos, state separado y validación offline disponibles |
| [#107 — Deploy promovido por ambiente/WIF](https://github.com/xPshycho/qa_gestion_inventarios/issues/107) | `open`; implementación fusionada por PR #145 | el plan GCP read-only pasó; los jobs de `apply` por `develop`/`staging` existen, pero el primer job development post-merge quedó `skipped` |
| [#108 — Validación post-deploy GCP](https://github.com/xPshycho/qa_gestion_inventarios/issues/108) | `closed` el 28-07-2026 | producción VM tiene smoke/ZAP/rollback; el workflow administrado valida health/OIDC y exige validación funcional adicional |

No se modificó ningún issue, GitHub Environment, secreto, recurso GCP o state
durante esta actualización.

## Dos planos que no deben confundirse

La operación vigente no coincide completamente con la topología administrada
que describe OpenTofu:

| Ambiente | Operación vigente observada | Plataforma OpenTofu declarada | Estado |
|---|---|---|---|
| Development | Cloud Run `inventory-development`, Cloud SQL y acceso público | `inventory-development-web`, `inventory-development-identity`, SQL privada y VPC propia | foundation aplicada; job por `develop` implementado, primera ejecución `skipped`; activación controlada por `GCP_DEVELOPMENT_DEPLOY_SERVICES` |
| Staging | preview Compose efímero en runner y foundation GCP sin servicio Cloud Run público observado | web/identity Cloud Run, SQL privada, VPC y state propios | foundation aplicada; job por `staging` implementado y pendiente de ejecución verificada |
| Production | VM `qa-inventario` con Compose, WIF, IAP y workflow dedicado | Cloud Run/SQL regional protegidos | la VM es producción; el root OpenTofu está planificado pero no aplicado |

Ruta: `infra/opentofu/modules/environment/main.tf`\
Líneas aproximadas: 1-300\
Componente: módulo `environment`\
Responsabilidad: VPC, SQL, Secret Manager, identidades runtime y servicios
Cloud Run opcionales.

Ruta: `.github/workflows/gcp-production-deploy.yml`\
Líneas aproximadas: 1-704\
Componente: `GCP Production Deploy`\
Responsabilidad: promover a la VM el SHA aprobado, validar, publicar evidencia
y hacer rollback automático ante fallo.

Ruta: `.github/workflows/gcp-managed-deploy.yml`\
Líneas aproximadas: 1-218\
Componente: `GCP Managed Environment Deploy`\
Responsabilidad: autenticar por WIF, construir imágenes inmutables y aplicar
los planes exactos de plataforma, development o staging. La ejecución del
`apply` sigue pendiente de validación por el `skipped` observado.

Aplicar el root OpenTofu de production no modifica ni importa automáticamente
la VM. No aplicarlo hasta aprobar una migración y conciliar state, recursos y
tráfico.

## Prerrequisitos

### Herramientas y acceso

- OpenTofu `1.12.5` para reproducir la versión de CI;
- Google Cloud CLI;
- Git, Bash, `curl`, `jq`, `openssl` y `sha256sum`;
- proyecto `project-e70349a8-c787-4733-9a0` con billing habilitado;
- identidad humana autorizada para el root concreto;
- Application Default Credentials para operación manual;
- revisión independiente antes de cualquier `apply` de staging/production.

OpenTofu no está instalado en la estación usada para esta auditoría. Los
comandos de validación fueron comprobados en GitHub Actions, run
[30499884455](https://github.com/xPshycho/qa_gestion_inventarios/actions/runs/30499884455),
job `OpenTofu / Format, validate and test plans`.

`No verificado localmente · modifica credenciales locales, no GCP`

```bash
gcloud auth application-default login
gcloud auth application-default set-quota-project \
  project-e70349a8-c787-4733-9a0
```

No usar claves JSON ni escribir `credentials` en `.tf`, `backend.hcl` o
`.tfvars`.

### APIs

`infra/opentofu/platform/main.tf` habilita exactamente:

- Artifact Registry;
- Compute Engine;
- Cloud Resource Manager;
- IAM e IAM Credentials;
- Logging y Monitoring;
- Cloud Run;
- Secret Manager;
- Service Usage y Service Networking;
- Cloud SQL Admin;
- Cloud Storage.

WIF necesita además Security Token Service. La producción VM usa IAP y OS
Login. Estas APIs se observaron habilitadas en el proyecto, pero el módulo
`platform` no administra STS, IAP ni OS Login.

`Verificado · solo lectura · requiere IAM`

```bash
gcloud services list --enabled \
  --project=project-e70349a8-c787-4733-9a0 \
  --format='value(config.name)'
```

`Cambia GCP · Requiere privilegios · No ejecutado`

```bash
gcloud services enable \
  artifactregistry.googleapis.com \
  cloudresourcemanager.googleapis.com \
  compute.googleapis.com \
  iam.googleapis.com \
  iamcredentials.googleapis.com \
  iap.googleapis.com \
  logging.googleapis.com \
  monitoring.googleapis.com \
  oslogin.googleapis.com \
  run.googleapis.com \
  secretmanager.googleapis.com \
  serviceusage.googleapis.com \
  servicenetworking.googleapis.com \
  sqladmin.googleapis.com \
  storage.googleapis.com \
  sts.googleapis.com \
  --project=project-e70349a8-c787-4733-9a0
```

Antes de habilitar, comparar la lista actual. No habilitar servicios solo para
auditar.

### IAM

| Identidad | Permisos respaldados por código/infraestructura | Uso |
|---|---|---|
| runtime web/identity OpenTofu | `roles/cloudsql.client`, `roles/logging.logWriter`, `roles/monitoring.metricWriter` | Cloud Run y SQL privada |
| runtime por secreto | `roles/secretmanager.secretAccessor` solo en secretos consumidos | inyección de versión numérica |
| administradores de state | `roles/storage.objectAdmin` sobre el bucket | leer/escribir state remoto |
| deployer VM producción | `roles/compute.viewer`, `roles/compute.osAdminLogin`, `roles/iap.tunnelResourceAccessor`, `roles/serviceusage.serviceUsageConsumer` | SSH/SCP por IAP |
| deployer VM sobre SA adjunta | `roles/iam.serviceAccountUser` | OS Login/act-as acotado |
| plan de pull request | readers/viewers de Artifact Registry, Cloud SQL, red, IAM/WIF, Cloud Run, Secret Manager y Service Usage; lectura condicionada de state | plan real sin `apply` |
| deploy por ambiente | administradores de Cloud SQL, red, service accounts, IAM del proyecto, Cloud Run, Secret Manager y Service Usage; writer de Artifact Registry y state condicionado | `apply` development/staging |
| deploy development adicional | `artifactregistry.admin`, `iam.workloadIdentityPoolAdmin` y administración del state de plataforma | reconciliar plataforma compartida |

Los roles exactos están codificados en
`infra/opentofu/modules/github_wif/main.tf`. Son permisos amplios de
aprovisionamiento, aunque no `Owner`; cualquier reducción debe validarse con
planes reales y pruebas de autorización.

`Verificado · solo lectura · omitir valores humanos en evidencia`

```bash
gcloud projects get-iam-policy \
  project-e70349a8-c787-4733-9a0

gcloud iam service-accounts list \
  --project=project-e70349a8-c787-4733-9a0
```

## Workload Identity Federation

El snapshot GCP encontró tres pools activos:
`github-inventory`, `github-inventory-cloudrun` y `github-inventory-tofu`.
También encontró service accounts separadas para plan/deploy por ambiente y
cero claves administradas por usuarios.

La producción VM usa:

```text
projects/61520277984/locations/global/workloadIdentityPools/github-inventory/providers/github-main
```

y la cuenta:

```text
github-inventory-deploy@project-e70349a8-c787-4733-9a0.iam.gserviceaccount.com
```

El provider restringe repository ID, owner ID y `refs/heads/main`. Sin embargo,
los bindings `roles/iam.workloadIdentityUser` observados usan el principal set
del repositorio, no una condición de provider/ref. Antes de automatizar
staging/production OpenTofu, separar pools o aplicar condiciones IAM por
ambiente.

`Verificado · solo lectura`

```bash
gcloud iam workload-identity-pools list \
  --project=project-e70349a8-c787-4733-9a0 \
  --location=global

gcloud iam workload-identity-pools providers list \
  --project=project-e70349a8-c787-4733-9a0 \
  --location=global \
  --workload-identity-pool=github-inventory

gcloud iam service-accounts get-iam-policy \
  github-inventory-deploy@project-e70349a8-c787-4733-9a0.iam.gserviceaccount.com
```

Ruta: `.github/workflows/gcp-production-deploy.yml`\
Líneas aproximadas: 12-14 y 127-140\
Componente: permisos OIDC y `google-github-actions/auth`\
Responsabilidad: token efímero `id-token: write`, sin service-account key.

## GitHub Environments

Consulta pública de solo lectura del 29 de julio de 2026:

| Environment | Workflow consumidor | Protección observada | Evaluación |
|---|---|---|---|
| `development` | `GCP Managed Environment Deploy` desde `develop` | sin reglas; sin branch policy | consumidor versionado; primer job post-merge `skipped` |
| `staging` | `Staging Preview` y `GCP Managed Environment Deploy` | sin reglas; sin branch policy | consumidor versionado; ejecución y aprobación pendientes |
| `production` | `GCP Production Deploy` | reviewer `Code-Hdez`, `prevent_self_review=true`, branch `main` | aprobación implementada |

En `production`, `can_admins_bypass=true`; registrar cualquier bypass como
incidente de cambio. Los nombres/valores de variables y secrets de Environment
no fueron accesibles por API pública (`401`). Los nombres siguientes se
obtuvieron del workflow versionado y un run exitoso demuestra que estuvieron
disponibles para ese despliegue:

| Variable no sensible `production` | Valor/contrato |
|---|---|
| `GCP_PROJECT_ID` | `project-e70349a8-c787-4733-9a0` |
| `GCP_ZONE` | `us-central1-a` |
| `GCP_VM_NAME` | `qa-inventario` |
| `GCP_VM_IP` | `34.123.136.144` |
| `GCP_DEPLOY_PATH` | `/opt/inventory` |
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | provider `github-main` indicado arriba |
| `GCP_DEPLOY_SERVICE_ACCOUNT` | deployer indicado arriba |
| `PRODUCTION_URL` | `https://34.123.136.144` |
| `E2E_VIEWER_USERNAME` | `viewer` |

Secret permitido en ese Environment: solo el nombre
`E2E_VIEWER_PASSWORD`; nunca documentar su valor.

Las variables no sensibles requeridas para el workflow administrado están
enumeradas en
[`deployment/gcp-managed-environments.md`](deployment/gcp-managed-environments.md).
Los ocho valores sensibles de activación deben existir como secrets del
Environment correspondiente.

Responsabilidad pendiente de configuración:

- administrador del repositorio: añadir required reviewer y
  `prevent_self_review` a `staging`;
- responsable de release: aprobar un SHA después de `CI Required`;
- autor del cambio: no puede autoaprobar staging/production;
- responsable GCP: mantener `GCP_<ENV>_DEPLOY_SERVICES=false` hasta que
  usuarios y secretos estén listos, y registrar la primera activación.

## Secret Manager

OpenTofu crea únicamente metadatos
`google_secret_manager_secret`; no crea `secret_data` ni versiones. Los
secretos por ambiente son:

```text
inventory-<env>-inventory-db-password
inventory-<env>-keycloak-db-password
inventory-<env>-keycloak-admin-password
inventory-<env>-keycloak-admin-client-secret
inventory-<env>-e2e-admin-password
inventory-<env>-e2e-operator-password
inventory-<env>-e2e-viewer-password
inventory-<env>-e2e-auditor-password
```

El snapshot encontró nueve secretos development y ocho staging; no se accedió
a valores. La producción VM vigente usa
`/opt/inventory/shared/production.env` con modo `0600`, no Secret Manager.
Cuando `deploy_services=true`, `gcp-managed-deploy.yml` delega en
`seed-runtime-secrets.sh` la creación de versiones faltantes y la
sincronización de los usuarios PostgreSQL; los valores provienen del GitHub
Environment y no de `.tfvars`.

`Cambia Secret Manager · Requiere privilegios · valor por stdin`

```bash
read -r -s SECRET_VALUE
printf '%s' "$SECRET_VALUE" |
  gcloud secrets versions add SECRET_ID \
    --project=project-e70349a8-c787-4733-9a0 \
    --data-file=-
unset SECRET_VALUE
```

No usar `latest`: `secret_version` debe ser una versión numérica explícita.

## URLs, health y observabilidad

| Ambiente | URL vigente | Health | Observabilidad |
|---|---|---|---|
| local development | `http://localhost:5173` | frontend `/health`, backend `:8080/actuator/health`, OIDC `:8081/realms/inventory/...` | Prometheus `:9090`, Grafana `:3000`, Loki `:3100`, Tempo `:3200`, Alertmanager `:9093` |
| GCP development | `https://inventory-development-po26gewv5q-uc.a.run.app` | `/health`, `/api/actuator/health`, `/auth/realms/inventory/.well-known/openid-configuration` | Cloud Logging/Monitoring; stack persistente Grafana/Prometheus no observado |
| staging CI/local | runner-private; `http://127.0.0.1:15173` local | backend `:18082`, Keycloak `:18081` | Prometheus `:19090`, Grafana `:13000`, Loki `:13100`, Tempo `:13200`, Alertmanager `:19093` |
| GCP staging | sin URL pública observada | **Pendiente de verificación** | SQL/VPC parciales; sin workload que produzca health |
| production VM | `https://34.123.136.144` | `/health`, `/api/actuator/health`, OIDC bajo `/auth` | `/grafana/` configurado, stack interno + Ops Agent; acceso interno pendiente por OS Login |
| OpenTofu target | URLs outputs de `<env>-web` y `<env>-identity` después de `apply` | web `/health`, API `/api/actuator/health`, identity `/realms/inventory/...` | Logging/Monitoring IAM; no despliega Grafana/Prometheus persistentes |

`Verificado desde superficie pública`

```bash
curl --fail \
  https://inventory-development-po26gewv5q-uc.a.run.app/health
curl --fail \
  https://inventory-development-po26gewv5q-uc.a.run.app/api/actuator/health
curl --fail \
  https://34.123.136.144/health
curl --fail \
  https://34.123.136.144/api/actuator/health
```

Las URLs Cloud Run deben obtenerse de outputs/state tras cada apply, no
construirse por nombre:

`No verificado · requiere state/ADC`

```bash
tofu -chdir=infra/opentofu/environments/development output -json
```

## Ciclo OpenTofu reproducible

### 1. Validación offline

`Verificado en GitHub Actions · no modifica GCP`

```bash
make test-infra
```

Ejecuta formato, rechaza state/planes/credenciales, inicializa con
`-backend=false`, valida y ejecuta tests con provider simulado para los tres
ambientes.

Ruta: `scripts/opentofu/validate.sh`\
Líneas aproximadas: 1-42\
Componente: validación offline\
Responsabilidad: `fmt`, seguridad, `init`, `validate` y `tofu test`.

### 2. Bootstrap de state

El bucket observado ya existe:
`project-e70349a8-c787-4733-9a0-opentofu-state`. No volver a crearlo. En un
proyecto nuevo:

`Cambia GCP · una sola vez · Requiere aprobación`

```bash
cp infra/opentofu/bootstrap/terraform.tfvars.example \
  infra/opentofu/bootstrap/terraform.tfvars
chmod 0600 infra/opentofu/bootstrap/terraform.tfvars

tofu -chdir=infra/opentofu/bootstrap init
tofu -chdir=infra/opentofu/bootstrap plan -out=bootstrap.tfplan
tofu -chdir=infra/opentofu/bootstrap show -no-color bootstrap.tfplan
tofu -chdir=infra/opentofu/bootstrap apply bootstrap.tfplan
```

El state de bootstrap es local y sensible. Custodiarlo cifrado. El bucket tiene
versionado, prevención pública, `force_destroy=false` y
`prevent_destroy=true`.

### 3. Preparar archivos privados

`No modifica GCP`

```bash
cp infra/opentofu/platform/backend.hcl.example \
  infra/opentofu/platform/backend.hcl
cp infra/opentofu/platform/terraform.tfvars.example \
  infra/opentofu/platform/terraform.tfvars
cp infra/opentofu/environments/development/backend.hcl.example \
  infra/opentofu/environments/development/backend.hcl
cp infra/opentofu/environments/development/terraform.tfvars.example \
  infra/opentofu/environments/development/terraform.tfvars

chmod 0600 \
  infra/opentofu/platform/backend.hcl \
  infra/opentofu/platform/terraform.tfvars \
  infra/opentofu/environments/development/backend.hcl \
  infra/opentofu/environments/development/terraform.tfvars
```

Configurar el bucket exacto y mantener para el primer pase:

```hcl
deploy_services = false
```

`.tfvars`, state, `.terraform/` y `*.tfplan` están ignorados por Git.
`backend.hcl` no está ignorado actualmente; solo debe contener bucket/prefix,
nunca credenciales, y no debe añadirse accidentalmente. Verificar antes de
continuar:

```bash
git status --short
./scripts/security/scan-secrets.sh --worktree
```

### 4. Init y plan

`Requiere ADC/state · plan es lectura/preview; no hace apply`

```bash
./scripts/opentofu/plan.sh \
  platform \
  "$PWD/infra/opentofu/platform/backend.hcl" \
  "$PWD/infra/opentofu/platform/terraform.tfvars" \
  "$PWD/infra/opentofu/platform/platform.tfplan"

./scripts/opentofu/plan.sh \
  development \
  "$PWD/infra/opentofu/environments/development/backend.hcl" \
  "$PWD/infra/opentofu/environments/development/terraform.tfvars" \
  "$PWD/infra/opentofu/environments/development/development.tfplan"
```

`plan.sh` ejecuta `init -reconfigure`, bloquea hasta cinco minutos, guarda el
plan y lo muestra. No usar `-lock=false`.

Antes de aprobar:

```bash
tofu -chdir=infra/opentofu/platform state list
tofu -chdir=infra/opentofu/environments/development state list
sha256sum infra/opentofu/platform/platform.tfplan
sha256sum \
  infra/opentofu/environments/development/development.tfplan
```

Si el plan intenta crear un recurso que ya existe, detenerse: importar o
conciliar primero. Si intenta reemplazar SQL, state bucket, red o servicio,
rechazarlo y abrir revisión.

### 5. Apply del plan aprobado

`Cambia GCP · Requiere aprobación explícita · No ejecutado en esta auditoría`

```bash
tofu -chdir=infra/opentofu/platform \
  apply platform.tfplan

tofu -chdir=infra/opentofu/environments/development \
  apply development.tfplan
```

Aplicar exactamente el archivo cuyo hash fue aprobado. No regenerar el plan
entre aprobación y apply. Guardar en evidencia: SHA Git, hash del plan,
aprobador, root, hora, resultado y outputs no sensibles. No publicar el plan:
puede contener metadatos sensibles.

### 6. Activación de servicios

La foundation `deploy_services=false` crea red, SQL, identidades y catálogos de
secretos. Antes de cambiar a `true`:

1. crear usuarios PostgreSQL `inventory` y `keycloak`;
2. cargar versiones de secretos por stdin;
3. publicar frontend/backend/Keycloak y Cloud SQL Proxy por digest completo;
4. fijar `secret_version` numérica;
5. generar y aprobar un segundo plan;
6. aplicar y ejecutar health, OIDC, API, permisos, Playwright, ZAP y k6.

La primera creación coordinada está automatizada por
`seed-runtime-secrets.sh`. La rotación completa continúa siendo una operación
aprobada: el script no sustituye la validación de consumidores ni el periodo
de rollback.

### 7. Staging y production OpenTofu

Repetir el mismo procedimiento usando los roots independientes:

```text
infra/opentofu/environments/staging
infra/opentofu/environments/production
```

Staging y production tienen protección de borrado forzada en SQL y Cloud Run;
production exige SQL regional y al menos una instancia web/identity.
`gcp-managed-deploy.yml` aplica staging con identidad y concurrencia
específicas. El root production solo se planifica: no aplicarlo manualmente
mientras la VM siga siendo el runtime vigente y no exista una decisión de
migración aprobada.

## Rollback

### OpenTofu

OpenTofu no ofrece un “rollback” transaccional general. El procedimiento es:

1. congelar writers y despliegues;
2. identificar commit, plan, outputs e imágenes anteriores;
3. restaurar variables/digests anteriores en una rama revisada;
4. generar un plan nuevo;
5. rechazar destrucciones/reemplazos inesperados;
6. aprobar y aplicar el plan correctivo;
7. ejecutar health y smoke;
8. conservar evidencia.

No usar `tofu destroy` como rollback. Para foundation/SQL, preferir fix-forward;
la eliminación puede perder datos y está protegida.

Cloud Run permite revertir tráfico a una revisión lista, pero esto cambia
estado y no sustituye la reconciliación posterior de OpenTofu:

`Cambia tráfico · Requiere aprobación`

```bash
gcloud run services update-traffic SERVICE_NAME \
  --project=project-e70349a8-c787-4733-9a0 \
  --region=us-central1 \
  --to-revisions=REVISION_ANTERIOR=100
```

### Staging vigente

- Actions: preview efímero; recuperación = nuevo run con SHA conocido.
- Local: `./scripts/staging/rollback.sh <SHA_ANTERIOR>`.
- Restore de datos: `restore-database.sh` es destructivo y exige backup +
  `--confirm`.

### Producción VM vigente

El workflow ejecuta automáticamente `scripts/gcp/rollback.sh` cuando falla
deploy, post-deploy, Playwright, ZAP, recolección o safety. Usa
`previous-release`/`previous-sha`; no restaura la base automáticamente.

Run aprobado observado:
[30500093137](https://github.com/xPshycho/qa_gestion_inventarios/actions/runs/30500093137).
Artifact: `production-evidence-0cfbd7...-1`, expiración observada
28 de agosto de 2026.

## Recuperación del state

### Lock abandonado

`Cambia lock · Requiere privilegios`

1. comprobar que no existe otro plan/apply en Actions ni estación operativa;
2. registrar root y lock ID;
3. solo entonces:

```bash
tofu -chdir=infra/opentofu/environments/ENVIRONMENT \
  force-unlock LOCK_ID
```

No usar `-lock=false`.

### Generación GCS anterior

El objeto esperado del workspace default es
`<prefix>/default.tfstate`. Confirmarlo con el listado; no asumirlo.

`Solo lectura`

```bash
gcloud storage ls --all-versions \
  gs://project-e70349a8-c787-4733-9a0-opentofu-state/inventory/environments/ENVIRONMENT/
```

`Destructivo para state · Requiere aprobación, copia cifrada y ventana`

1. detener todos los writers;
2. preservar la generación actual;
3. descargar la generación elegida a un directorio privado con `umask 077`;
4. comprobar hash/tamaño sin imprimir contenido;
5. subirla al mismo objeto para crear una nueva generación actual;
6. ejecutar `init`, `state list` y `plan`;
7. si aparecen destrucciones inesperadas, restaurar la generación preservada;
8. eliminar de forma segura las copias locales.

La sintaxis exacta de copia por generación depende de la versión instalada de
`gcloud`; validarla primero con `gcloud storage cp --help`. No se ejecutó una
recuperación real: RPO/RTO es **Pendiente de verificación**.

Si se pierde el state local de bootstrap, importar primero el bucket:

```bash
tofu -chdir=infra/opentofu/bootstrap import \
  google_storage_bucket.state \
  project-e70349a8-c787-4733-9a0-opentofu-state
```

Después importar/reconciliar los bindings configurados y aprobar el plan. No
ejecutar `destroy` sobre bootstrap.

## Rotación de secretos

### Secret Manager/OpenTofu target

1. identificar consumidores y versión actual sin leer el valor;
2. tomar backup si afecta base/identidad;
3. crear nueva versión por stdin;
4. coordinar el cambio del usuario PostgreSQL o cliente Keycloak;
5. actualizar `secret_version` numérica;
6. plan/apply aprobado;
7. health, login, API y métricas;
8. deshabilitar la versión anterior solo después de la ventana de observación.

Cambiar solo Secret Manager no rota PostgreSQL ni Keycloak. Para passwords de
base no existe dual password implementado; se requiere ventana y plan de
reversión. Para `keycloak-admin-password`, un nuevo valor de bootstrap no
demuestra que un realm ya inicializado haya rotado: usar la administración de
Keycloak y verificar.

### Producción VM

`scripts/gcp/init-env.sh --force` preserva valores existentes salvo que se
inyecten reemplazos. No es un comando de rotación integral. La rotación de
PostgreSQL, Keycloak, client secret, E2E y Grafana debe coordinar servicio,
archivo `0600`, restart controlado, smoke y rollback; hoy es
**Pendiente de procedimiento automatizado**.

### GitHub Environment

Rotar `E2E_VIEWER_PASSWORD` en Keycloak y luego en el Environment
`production`, ejecutar smoke read-only y revocar el anterior. Nunca mostrar el
valor en issue, PR, artifact o salida.

## Runbook de incidentes

| Síntoma | Contención | Diagnóstico seguro | Recuperación | Evidencia |
|---|---|---|---|---|
| plan quiere reemplazar recursos | no aplicar | state list, drift e import pendiente | conciliar/importar y regenerar | plan/hash, sin publicarlo |
| lock persistente | congelar writers | Actions/sesiones y lock ID | `force-unlock` aprobado | root, ID, operador, hora |
| development Cloud Run 5xx | detener promoción | revisions, logs, health, SQL | revisión anterior o fix-forward | Logs Explorer + smoke |
| staging runner falla | no promover | artifact/safety/Compose logs | nuevo run SHA bueno; local rollback | `test-results-staging-post-deploy-*` |
| producción falla post-deploy | workflow queda rojo | artifact seguro, VM health/logs | rollback automático a previous SHA | `production-evidence-*` |
| SQL/migración incompatible | congelar escritura | Flyway, backup, compatibilidad | instancia/volumen aislado, no overwrite | backup ID, prueba restore |
| secreto expuesto | revocar y bloquear deploy | proveedor, consumidores, artifacts | reemplazo coordinado + smoke | nombre/fecha, nunca valor |
| state corrupto/perdido | detener todo apply | generaciones GCS y state actual | nueva generación desde versión válida | generaciones/hash/plan |

Responsabilidades:

| Actividad | Ejecutor | Aprobador | Estado real |
|---|---|---|---|
| development foundation | operador GCP/OpenTofu | administrador de state | asignación nominal pendiente |
| staging preview | workflow + responsable QA | reviewer distinto del autor | proceso documentado; regla GitHub ausente |
| production deploy | workflow por SHA | `Code-Hdez` verificado en Environment | implementado |
| rollback production | workflow; operador IAP si manual | responsable de release/incidente | automático implementado; manual requiere acceso |
| state recovery | administrador de state | segundo operador/revisor | procedimiento documentado; drill pendiente |
| secret rotation | propietario del servicio/identidad | responsable de seguridad | Secret Manager target; VM sin automatización integral |

Para cualquier incidente:

1. declarar ambiente, impacto y SHA;
2. congelar promoción/apply;
3. preservar evidencia sanitizada;
4. asignar responsable y aprobador;
5. decidir fix-forward, revisión anterior o recuperación de datos/state;
6. ejecutar health/smoke;
7. observar métricas 15-30 minutos;
8. registrar causa, tiempos, acciones y pendientes.

## Dónde consultar evidencia y artifacts

| Resultado | Ubicación | Retención/estado |
|---|---|---|
| OpenTofu offline | run Actions -> job `OpenTofu / Format, validate and test plans` | log del run |
| planes GCP de PR | job `OpenTofu / Read-only GCP plan`; el plan se muestra en logs sanitizados y no se publica como artifact | retención del run |
| deploy GCP administrado | artifact previsto `gcp-managed-<environment>-<SHA>-<attempt>` con `deployment.json` y outputs no sensibles | 30 días cuando el job se ejecute; primera ejecución development `skipped` |
| staging post-deploy | `test-results/staging/post-deploy/` y artifact `test-results-staging-post-deploy-<SHA>-<attempt>` | 30 días |
| production deploy | run 30500093137, artifact `production-evidence-*` | 30 días; expiración observada 28-08-2026 |
| Cloud Run dev | Cloud Logging/Monitoring y revision list | retención GCP efectiva |
| state | bucket GCS versionado `...-opentofu-state` | versionado + soft delete observado |
| inventario GCP | [Infraestructura](03-infraestructura-gcp.md) | snapshot 29-07-2026 |
| resultados centrales | [Evidencias](22-evidencias.md) | según categoría |

## Matriz de trazabilidad del issue #109

| Requisito | Workflow/procedimiento | Prueba o validación | Evidencia | Estado |
|---|---|---|---|---|
| prerrequisitos/APIs | `platform/main.tf` + comandos de inventario | APIs GCP observadas; OpenTofu CI | 03 + esta guía | Completo |
| IAM mínimo | módulos environment/GitHub WIF + deploy VM | roles versionados y IAM read-only auditado | 03, `gcp-vm.md`, módulo `github_wif` | Completo con permisos de aprovisionamiento amplios |
| WIF sin keys | planes PR, deploy administrado y VM | plan read-only PR #145 PASS; deploy job `skipped`; 0 user-managed SA keys | runs 30508694249 y 30509955395; producción 30500093137 | Parcial hasta validar apply |
| GitHub Environments | `gcp-managed-deploy.yml`, `staging-preview.yml`, `gcp-production-deploy.yml` | API pública + referencias versionadas | production protegido; staging sin protección | Parcial |
| Secret Manager | catálogo OpenTofu + versiones externas | 17 nombres observados; valores no leídos | 03 y esta guía | Completo documental |
| init/plan/apply | `render-ci-config.sh`, `plan.sh`, `opentofu-ci.yml`, `gcp-managed-deploy.yml` | plan PR PASS; primer apply development `skipped` | runs 30508694249 y 30509955395 | Parcial: implementación presente, apply sin validar |
| rollback OpenTofu | plan correctivo/revisión anterior | no hubo drill | 20 + esta guía | Pendiente de validación |
| URLs/variables/health | workflows, outputs y scripts de environment | curl dev/production; staging histórico | 19, 22, evidencia deployment | Completo con staging GCP pendiente |
| observabilidad por ambiente | Compose/Cloud Monitoring/Ops Agent | local/staging histórica; producción externa | 17 y evidence/observability | Parcial |
| incidentes | tabla/runbook anterior | revisión contra scripts reales | esta guía | Completo documental |
| rotación | stdin Secret Manager + coordinación | no se rotaron valores | security/secrets + esta guía | Pendiente de validación |
| recuperación state | GCS versionado/import/lock | bucket observado; sin restore drill | 03 + esta guía | Pendiente de validación |
| rutas de evidencia | uploads Actions y GCS | runs/artifacts abiertos | 22 + evidence/pipeline | Completo |
| dependencias actualizadas | consulta pública #106/#107/#108 | estados y fechas observados | sección inicial | Completo |

## Criterios de aceptación

| Criterio | Dictamen |
|---|---|
| integrante nuevo prepara development sin secretos versionados | **Completo documentalmente** para validación y foundation; activar servicios requiere secretos/usuarios externos |
| staging y production tienen aprobación, rollback y responsables | **Parcial**: producción sí; staging tiene proceso/rollback pero el Environment no exige reviewer |
| evidencia y artifacts documentados | **Completo** |
| consistencia con workflows/infra final | **Completo**: separa VM, runner-private y OpenTofu; refleja plan PR aprobado y jobs apply todavía no validados |

El issue #109 no debe considerarse técnicamente cerrado solo por este documento:
staging carece de required reviewer, #107 sigue abierto aunque su implementación
fue fusionada, el primer apply quedó `skipped` y no se ha probado recuperación
de state/rotación.

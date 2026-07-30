# Infraestructura GCP

## Alcance de la inspección

Snapshot de solo lectura: 29 de julio de 2026, aproximadamente 21:41-22:17
`America/Santo_Domingo` (30 de julio UTC).

Proyecto: `project-e70349a8-c787-4733-9a0`\
Número: `61520277984`\
Estado: `ACTIVE`\
Facturación: habilitada

No se aplicó OpenTofu, no se leyó ninguna versión de secreto y no se modificó
IAM. Los recursos estaban cambiando concurrentemente durante la auditoría; por
eso cada estado es un snapshot y debe reconfirmarse antes de operar.

## Inventario observado

### Producción en Compute Engine

| Propiedad | Valor observado |
|---|---|
| VM | `qa-inventario`, `RUNNING`, `us-central1-a` |
| Máquina | `e2-standard-8` |
| Imagen SO | Debian 13 según inventario de la auditoría |
| Red | `default`, privada `10.128.0.2` |
| IP reservada | `qa-inventario-ip`, `34.123.136.144`, `IN_USE` |
| Disco | 50 GiB persistente; política diaria, retención 14 días |
| Último snapshot observado | `qa-inventario-us-central1-a-20260729115256-1848swgw`, `READY` |
| Protección de eliminación | deshabilitada |
| Shielded VM | vTPM e integridad habilitados; Secure Boot deshabilitado |
| Acceso | OS Login y bloqueo de project SSH keys habilitados |
| Agente | etiqueta de política Google Ops Agent presente |

La VM usa la cuenta Compute Engine predeterminada. Sus scopes observados
incluyen escritura de logging/monitoring/traces y lectura de Storage. La
asignación de roles IAM debe revisarse además de los scopes.

### Red y firewall

| Regla habilitada | Origen | Destino/puerto | Logging |
|---|---|---|---|
| `inventory-allow-http` | `0.0.0.0/0` | tag `inventory-web`, TCP 80 | no |
| `inventory-allow-https` | `0.0.0.0/0` | tag `inventory-web`, TCP 443 | no |
| `inventory-allow-iap-ssh` | `35.235.240.0/20` | tag `iap-ssh`, TCP 22 | no |
| `default-allow-internal` | `10.128.0.0/9` | TCP/UDP completo + ICMP | no |
| `default-allow-icmp` | `0.0.0.0/0` | ICMP | no |

Las reglas públicas predeterminadas de SSH, RDP, HTTP y HTTPS están
deshabilitadas. El acceso administrativo esperado es IAP TCP forwarding +
OS Login. El firewall no registra conexiones; esto reduce capacidad forense.

Superficie pública verificada:

- `http://34.123.136.144/` devuelve 301 a HTTPS;
- `https://34.123.136.144/` devuelve 200 con HSTS/CSP;
- `/health` devuelve `ok`;
- `/api/actuator/health` devuelve `{"status":"UP"}`;
- `/auth/realms/inventory/.well-known/openid-configuration` publica el issuer
  exacto de producción.

Certificado observado: Let's Encrypt para la IP `34.123.136.144`, válido del
28 de julio al 4 de agosto de 2026. La duración corta exige renovación
automática. El timer interno no pudo verificarse porque IAP SSH rechazó la
clave pública de la identidad auditora.

**Pendiente de verificación**

- Información faltante: contenedores, listeners internos, release actual,
  estado/última ejecución de `inventory-certbot-renew.timer`.
- Motivo: `gcloud compute ssh ... --tunnel-through-iap` terminó con
  `Permission denied (publickey)`.
- Cómo verificar: conceder temporalmente el rol OS Login mínimo a un operador
  autorizado y ejecutar los comandos de
  [operación](18-operacion-y-mantenimiento.md#vm-de-producción).

### Cloud Run development

Servicio `inventory-development`, región `us-central1`, invocación pública
(`allUsers` con `roles/run.invoker`), min 0, max 3, concurrencia 80 y timeout
300 s. El primer health tardó por cold start; el reintento devolvió 200/UP.

Revisión con 100 % de tráfico: `inventory-development-4eccbf5f677d`.
Había seis revisiones `Ready`; una revisión posterior
`inventory-development-8ae092d201f6` estaba `Retired`, evidencia de historial
de releases, no de rollback validado.

| Contenedor | Límite | Función |
|---|---:|---|
| `cloud-sql-proxy` | 1 CPU / 256 MiB | conexión autenticada a Cloud SQL |
| `keycloak` | 1 CPU / 1 GiB | identidad |
| `backend` | 1 CPU / 1 GiB | API |
| `frontend` | 1 CPU / 256 MiB | gateway y SPA; puerto 8080 |

Runtime SA:
`inventory-development-runtime@project-e70349a8-c787-4733-9a0.iam.gserviceaccount.com`.

### Cloud SQL

| Instancia | Snapshot de estado | Red | Configuración |
|---|---|---|---|
| `inventory-development` | `RUNNABLE` | IP pública, sin redes autorizadas; acceso por Cloud SQL Proxy | PostgreSQL 16, `db-f1-micro`, zonal, 10 GiB SSD |
| `inventory-development-postgres` | `RUNNABLE` a las 22:15; había estado `PENDING_CREATE` a las 21:41 | IP privada `10.247.0.3`, VPC `inventory-development-network` | PostgreSQL 16, `db-f1-micro`, zonal, 10 GiB SSD |
| `inventory-staging-postgres` | `RUNNABLE`, apareció en la reconfirmación final | IP privada `10.188.0.3`, VPC `inventory-staging-network` | PostgreSQL 16, `db-g1-small`, zonal, 10 GiB SSD |

La primera instancia usa `sslMode: ENCRYPTED_ONLY`, backups diarios 03:00,
retención 7, PITR 7 días. Bases verificadas: `postgres`, `keycloak`,
`inventory`. Backup observado: ID `1785345787971`, `SUCCESSFUL`.

Las instancias privadas aparecieron mientras OpenTofu u otro proceso estaba
convergiendo. Aunque ambas terminaron `RUNNABLE`, no se observaron servicios
Cloud Run que las consumieran ni se listaron sus bases/usuarios. Sus backups y
PITR estaban habilitados con 7 backups y 3 días de transaction logs.

Las tres tenían protección de eliminación deshabilitada. No se ejecutó una
restauración; el RPO/RTO real es **Pendiente de verificación**.

### Secret Manager, Artifact Registry y Storage

Al finalizar se observaron 17 secretos: nueve development y ocho staging,
todos con replicación automática y sin calendario de rotación. Nombres
development permitidos en documentación:

- `inventory-development-app-db-password`;
- `inventory-development-inventory-db-password`;
- `inventory-development-keycloak-db-password`;
- `inventory-development-keycloak-admin-password`;
- `inventory-development-keycloak-admin-client-secret`;
- cuatro contraseñas E2E por rol.

Staging repite `inventory-db-password`, Keycloak DB/admin/client secret y las
cuatro contraseñas E2E con prefijo `inventory-staging-`. No existía un secreto
staging separado llamado `app-db-password` en el snapshot.

Todos deben representarse como
`<SECRET_ADMINISTRADO_EN_GCP_SECRET_MANAGER>`. Cloud Run referencia versiones
por número; rotar requiere crear versión, actualizar consumidores, desplegar y
deshabilitar la anterior después de validar.

Artifact Registry tenía cuatro repositorios Docker:
`inventory-development`, `inventory-staging`, `inventory-production` e
`inventory-images`. En development se observaron 103 archivos y
458,608,214 bytes; no se emitió recomendación de limpieza sin revisar
retención/referencias.

Bucket de estado:
`project-e70349a8-c787-4733-9a0-opentofu-state`, `US-CENTRAL1`, acceso uniforme,
prevención pública forzada, versionado y soft delete de 7 días. El lifecycle
elimina versiones no vigentes después de 90 días/con 20 más nuevas y
`validation/` después de 30 días.

### IAM y federación

- 15 service accounts observadas; ninguna tenía claves administradas por el
  usuario.
- Tres pools WIF activos: `github-inventory`,
  `github-inventory-cloudrun`, `github-inventory-tofu`.
- Los providers restringen repository ID, owner ID y ref (`develop`,
  `staging`, `main` o PR).
- Las políticas `roles/iam.workloadIdentityUser` de cuentas de deploy están
  ligadas al `attribute.repository_id` del pool, no al provider/ref.

Riesgo alto: dentro de un pool con varios providers, una identidad aceptada
para una rama podría intentar impersonar otra cuenta enlazada al mismo
repository principal set. Verificar condiciones IAM efectivas y separar pools
o añadir condiciones por ambiente antes de promover producción.

Service accounts observadas (solo nombre, sin credencial):

- Compute Engine default;
- `github-inventory-deploy`;
- `inv-tofu-plan` e `inventory-tofu-plan`;
- `inv-developm-deploy` e `inventory-development-deploy`;
- `inv-staging-deploy` e `inventory-staging-deploy`;
- `inv-producti-deploy` e `inventory-production-deploy`;
- `inventory-development-runtime`, `inventory-staging-runtime` e
  `inventory-production-runtime`;
- `inv-developm-identity`;
- `inv-developm-web`.

La duplicación de prefijos `inv-*`/`inventory-*` sugiere dos generaciones de
OpenTofu o bootstrap. No eliminar ninguna identidad hasta resolver bindings,
workflows y state.

Las dos identidades humanas con rol Owner observadas se omiten deliberadamente.
Revisar Owners con el comando siguiente y aplicar mínimo privilegio mediante
un proceso autorizado.

### Logging y Monitoring

| Recurso | Estado |
|---|---|
| Log bucket `_Default` | 30 días |
| Log bucket `_Required` | 400 días, bloqueado |
| Dashboards GCP | 0 |
| Alert policies GCP | 0 |
| Notification channels | 0 |
| Uptime checks | 0 |

La producción usa además observabilidad autohospedada, pero su estado interno
no pudo comprobarse por SSH. La ausencia de alertas GCP y firewall logging es
una brecha operativa.

No se encontraron forwarding rules, certificados de Load Balancer o GKE. Las
APIs Cloud DNS y GKE estaban deshabilitadas; no se habilitaron. No hay evidencia
de DNS administrado por Cloud DNS.

### APIs habilitadas

El snapshot mostró: Artifact Registry, Cloud Resource Manager, Cloud Trace,
Compute Engine, Container Registry, IAM/IAM Credentials, IAP, Logging,
Monitoring, Network Management, OS Config, OS Login, Pub/Sub, Cloud Run, Secret
Manager, Service Networking/Usage, Cloud SQL Admin, Storage, STS y Telemetry.
También estaban habilitados servicios BigQuery/Analytics/Dataform/Dataplex/
Datastore provistos por la plataforma, sin recursos del inventario
identificados en esta auditoría.

Cloud DNS y Kubernetes Engine no estaban habilitados. No habilitar APIs solo
para inventariar: un error `SERVICE_DISABLED` es evidencia suficiente de su
estado.

## Deriva entre lo declarado y lo observado

Los roots de `infra/opentofu/` describen red privada, Cloud SQL privada y
servicios Cloud Run separados por ambiente. Lo observado incluyó:

- una VM de producción fuera del estado OpenTofu;
- un servicio Cloud Run development público de cuatro contenedores;
- una instancia SQL development pública y dos instancias privadas
  development/staging, las nuevas ya `RUNNABLE`;
- redes/subredes privadas development y staging;
- ningún servicio Cloud Run staging/production, por lo que la plataforma
  staging estaba incompleta.

No ejecutar `tofu apply` hasta importar/conciliar recursos y revisar el plan.

## Comandos reproducibles

`Verificado · Requiere privilegios GCP`

```bash
gcloud projects describe project-e70349a8-c787-4733-9a0
gcloud compute instances list --project=project-e70349a8-c787-4733-9a0
gcloud compute firewall-rules list --project=project-e70349a8-c787-4733-9a0
gcloud run services list --project=project-e70349a8-c787-4733-9a0 \
  --platform=managed
gcloud sql instances list --project=project-e70349a8-c787-4733-9a0
gcloud secrets list --project=project-e70349a8-c787-4733-9a0
gcloud iam service-accounts list --project=project-e70349a8-c787-4733-9a0
gcloud projects get-iam-policy project-e70349a8-c787-4733-9a0
```

No usar `gcloud config set project`: `--project` evita modificar el contexto
global. Nunca ejecutar `gcloud secrets versions access` durante una auditoría
documental.

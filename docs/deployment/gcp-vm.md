# Producción en una VM de Google Cloud

Esta guía define el despliegue de producción por SHA sobre una única VM de
Compute Engine. La aplicación se publica directamente en la IP estática
`34.123.136.144`; no depende de un dominio. El workflow
`.github/workflows/gcp-production-deploy.yml` es la única ruta automatizada y
se activa exclusivamente con un `push` a `main`.

La guía describe el contrato de infraestructura y operación. La existencia de
los archivos en el repositorio no demuestra por sí sola que IAM, la VM, el
GitHub Environment o un despliegue remoto hayan sido configurados.

La auditoría del 29 de julio de 2026 sí verificó la VM, WIF, el Environment
`production` protegido, health público y el run exitoso
[30500093137](https://github.com/xPshycho/qa_gestion_inventarios/actions/runs/30500093137).
La inspección interna por OS Login continúa pendiente.

La VM debe usar una imagen Debian soportada por Docker CE (Debian 12 es la
referencia), tener una dirección externa estática y recursos suficientes para
aplicación, dos bases, identidad y observabilidad. Como punto de partida,
reservar al menos 4 vCPU, 16 GiB de RAM y 50 GiB de disco persistente; confirmar
el dimensionamiento con métricas reales antes de considerarlo un SLO.

## Arquitectura

```text
Internet
  │
  ├── TCP 80  ── HTTP-01 y redirección a HTTPS
  └── TCP 443 ── https://34.123.136.144
                    │
                    └── gateway Nginx
                         ├── /          frontend Angular
                         ├── /api/      backend Spring Boot
                         ├── /auth/     Keycloak
                         └── /grafana/  Grafana autenticado

GitHub Actions ── WIF ── Google Cloud ── IAP/OS Login ── VM:22
```

PostgreSQL, la base de Keycloak, backend, Keycloak y los componentes de
observabilidad permanecen en la red privada de Docker Compose. La VM no publica
PostgreSQL, backend, Keycloak, Prometheus, Loki, Tempo, Alloy ni Alertmanager.
Los únicos puertos públicos son `80/tcp` y `443/tcp`. SSH no se abre a Internet:
solo se admite el rango de IAP.

El estado persistente se separa de cada release:

```text
/opt/inventory/
├── releases/
│   └── <SHA completo>/             fuentes exactas de ese commit
└── shared/                         modo 0700
    ├── production.env              modo 0600; nunca se descarga
    ├── current-release
    ├── current-sha
    ├── previous-release
    ├── previous-sha
    ├── backups/
    ├── evidence/<SHA>/
    └── keycloak/
```

`GCP_DEPLOY_PATH` puede cambiar `/opt/inventory`, pero debe ser una ruta
absoluta dedicada. No debe ser `/`, `/home`, una ruta compartida con otro
servicio ni contener `..`.

## TLS sin dominio

La IP debe ser estática antes de emitir el certificado. Let’s Encrypt admite
certificados de IP públicos desde 2026. Estos certificados usan obligatoriamente
el perfil ACME `shortlived`, tienen una validez de 160 horas (algo más de seis
días) y requieren renovación completamente automatizada. Certbot `5.4` o
posterior permite solicitarlos por `webroot` con `--ip-address`. Véanse los
anuncios oficiales sobre [certificados de IP y seis días][le-ip] y
[soporte en Certbot][le-certbot].

El gateway conserva `/.well-known/acme-challenge/` en HTTP y redirige el resto a
HTTPS. Por ello `80/tcp` debe permanecer accesible mientras se use HTTP-01. El
certificado y su clave residen únicamente en `/etc/letsencrypt` de la VM; no se
copian al repositorio, GitHub ni los artifacts.

Verificaciones operativas:

```bash
sudo /opt/certbot/bin/certbot certificates
sudo systemctl status inventory-certbot-renew.timer
sudo /opt/certbot/bin/certbot renew --dry-run
curl --fail --show-error https://34.123.136.144/health
```

`scripts/gcp/install-certificate-renewal.sh` instala
`inventory-certbot-renew.timer`, que comprueba la renovación cada seis horas.
Su hook envía `HUP` al gateway solo cuando el contenedor está activo. Debido a
la vida de seis días, un timer deshabilitado es una incidencia de producción,
no una tarea de mantenimiento postergable. También se debe alertar antes de que
queden 48 horas de validez. Certbot obtiene el certificado, pero la
configuración de Nginx de este repositorio es la que lo instala en el gateway.

La aceptación de términos y la emisión inicial son actos explícitos de
provisioning, no efectos secundarios de un push. El workflow nunca define
`LETSENCRYPT_AGREE_TOS`, email ni modo sin email. El despliegue falla cerrado si
el certificado no existe, no corresponde a la IP o no tiene vigencia suficiente.

[le-ip]: https://letsencrypt.org/2026/01/15/6day-and-ip-general-availability.html
[le-certbot]: https://letsencrypt.org/2026/03/11/shorter-certs-certbot

## Preparación de Google Cloud

Los ejemplos siguientes se ejecutan una sola vez desde una estación de
administración autenticada con `gcloud`. Sustituir los identificadores por los
del proyecto y la VM existentes:

```bash
export GCP_PROJECT_ID="project-e70349a8-c787-4733-9a0"
export GCP_ZONE="us-central1-a"
export GCP_VM_NAME="qa-inventario"
export GCP_VM_IP="34.123.136.144"
export GCP_REGION="${GCP_ZONE%-*}"
export GITHUB_REPOSITORY="xPshycho/qa_gestion_inventarios"
export GITHUB_REPOSITORY_ID="1258796980"
export GITHUB_REPOSITORY_OWNER_ID="115911218"
export GCP_DEPLOY_SERVICE_ACCOUNT_ID="github-inventory-deploy"
export GCP_WIF_POOL_ID="github-inventory"
export GCP_WIF_PROVIDER_ID="github-main"

gcloud config set project "$GCP_PROJECT_ID"
gcloud services enable \
  compute.googleapis.com \
  iam.googleapis.com \
  iamcredentials.googleapis.com \
  iap.googleapis.com \
  oslogin.googleapis.com \
  serviceusage.googleapis.com \
  sts.googleapis.com
```

### IP estática, OS Login y firewall

Confirmar primero que la IP pertenece a la VM:

```bash
gcloud compute instances describe "$GCP_VM_NAME" \
  --zone="$GCP_ZONE" \
  --format='get(networkInterfaces[0].accessConfigs[0].natIP)'
```

Si `34.123.136.144` todavía es efímera, promover esa misma dirección a estática
regional antes de emitir TLS:

```bash
gcloud compute addresses create qa-inventario-ip \
  --addresses="$GCP_VM_IP" \
  --region="$GCP_REGION"
```

Activar OS Login y etiquetar la VM:

```bash
gcloud compute instances add-metadata "$GCP_VM_NAME" \
  --zone="$GCP_ZONE" \
  --metadata=enable-oslogin=TRUE,block-project-ssh-keys=TRUE

gcloud compute instances add-tags "$GCP_VM_NAME" \
  --zone="$GCP_ZONE" \
  --tags=iap-ssh,inventory-web
```

Crear reglas de firewall dedicadas. Si una regla con ese nombre ya existe,
comparar su alcance antes de actualizarla; no crear reglas amplias duplicadas.

```bash
gcloud compute firewall-rules create inventory-allow-iap-ssh \
  --direction=INGRESS \
  --action=ALLOW \
  --rules=tcp:22 \
  --source-ranges=35.235.240.0/20 \
  --target-tags=iap-ssh

gcloud compute firewall-rules create inventory-allow-http \
  --direction=INGRESS \
  --action=ALLOW \
  --rules=tcp:80 \
  --source-ranges=0.0.0.0/0 \
  --target-tags=inventory-web

gcloud compute firewall-rules create inventory-allow-https \
  --direction=INGRESS \
  --action=ALLOW \
  --rules=tcp:443 \
  --source-ranges=0.0.0.0/0 \
  --target-tags=inventory-web
```

Eliminar o restringir cualquier regla anterior que publique `22/tcp` a
`0.0.0.0/0`. El acceso administrativo debe funcionar así:

```bash
gcloud compute ssh "$GCP_VM_NAME" \
  --project="$GCP_PROJECT_ID" \
  --zone="$GCP_ZONE" \
  --tunnel-through-iap
```

### Cuenta de despliegue y Workload Identity Federation

Crear una cuenta de servicio sin claves:

```bash
gcloud iam service-accounts create "$GCP_DEPLOY_SERVICE_ACCOUNT_ID" \
  --display-name="GitHub production deployer"

export GCP_DEPLOY_SERVICE_ACCOUNT="$GCP_DEPLOY_SERVICE_ACCOUNT_ID@$GCP_PROJECT_ID.iam.gserviceaccount.com"
```

La cuenta necesita leer la VM, abrir el túnel IAP y obtener OS Admin Login para
ejecutar el bootstrap con `sudo`:

```bash
for role in \
  roles/compute.viewer \
  roles/compute.osAdminLogin \
  roles/iap.tunnelResourceAccessor \
  roles/serviceusage.serviceUsageConsumer; do
  gcloud projects add-iam-policy-binding "$GCP_PROJECT_ID" \
    --member="serviceAccount:$GCP_DEPLOY_SERVICE_ACCOUNT" \
    --role="$role"
done
```

Crear el pool y un proveedor OIDC restringido a los IDs inmutables del
repositorio y su owner, además de `refs/heads/main`. Los IDs evitan que un
repositorio renombrado o recreado herede confianza por nombre:

```bash
gcloud iam workload-identity-pools create "$GCP_WIF_POOL_ID" \
  --location=global \
  --display-name="GitHub Actions"

gcloud iam workload-identity-pools providers create-oidc "$GCP_WIF_PROVIDER_ID" \
  --location=global \
  --workload-identity-pool="$GCP_WIF_POOL_ID" \
  --display-name="GitHub repository production" \
  --issuer-uri="https://token.actions.githubusercontent.com" \
  --attribute-mapping="google.subject=assertion.sub,attribute.repository_id=assertion.repository_id,attribute.repository_owner_id=assertion.repository_owner_id,attribute.ref=assertion.ref" \
  --attribute-condition="assertion.repository_id=='$GITHUB_REPOSITORY_ID' && assertion.repository_owner_id=='$GITHUB_REPOSITORY_OWNER_ID' && assertion.ref=='refs/heads/main'"

export GCP_PROJECT_NUMBER="$(gcloud projects describe "$GCP_PROJECT_ID" --format='value(projectNumber)')"
export GCP_WORKLOAD_IDENTITY_PROVIDER="projects/$GCP_PROJECT_NUMBER/locations/global/workloadIdentityPools/$GCP_WIF_POOL_ID/providers/$GCP_WIF_PROVIDER_ID"
```

Autorizar únicamente las identidades del repositorio a impersonar la cuenta:

```bash
gcloud iam service-accounts add-iam-policy-binding \
  "$GCP_DEPLOY_SERVICE_ACCOUNT" \
  --role=roles/iam.workloadIdentityUser \
  --member="principalSet://iam.googleapis.com/projects/$GCP_PROJECT_NUMBER/locations/global/workloadIdentityPools/$GCP_WIF_POOL_ID/attribute.repository_id/$GITHUB_REPOSITORY_ID"
```

OS Login necesita que el deployer pueda actuar como la cuenta adjunta a la VM.
Resolverla sin asumir su nombre y otorgar el binding únicamente sobre esa
cuenta:

```bash
export GCP_VM_SERVICE_ACCOUNT="$(
  gcloud compute instances describe "$GCP_VM_NAME" \
    --zone="$GCP_ZONE" \
    --format='value(serviceAccounts[0].email)'
)"
test -n "$GCP_VM_SERVICE_ACCOUNT"

gcloud iam service-accounts add-iam-policy-binding \
  "$GCP_VM_SERVICE_ACCOUNT" \
  --member="serviceAccount:$GCP_DEPLOY_SERVICE_ACCOUNT" \
  --role=roles/iam.serviceAccountUser

for role in roles/logging.logWriter roles/monitoring.metricWriter; do
  gcloud projects add-iam-policy-binding "$GCP_PROJECT_ID" \
    --member="serviceAccount:$GCP_VM_SERVICE_ACCOUNT" \
    --role="$role"
done
```

No crear ni descargar una clave JSON. El workflow solicita un token OIDC de
GitHub, lo intercambia mediante WIF y deja que `gcloud compute ssh/scp` gestione
credenciales efímeras de OS Login. Tampoco existe una clave SSH guardada en
GitHub.

### Instancia provisionada

Estos son los identificadores resueltos para este despliegue, no placeholders:

| Recurso | Valor |
| --- | --- |
| Proyecto | `project-e70349a8-c787-4733-9a0` |
| Número de proyecto | `61520277984` |
| VM | `qa-inventario` |
| Zona / región | `us-central1-a` / `us-central1` |
| IP estática | `34.123.136.144` (`IN_USE`) |
| Dirección reservada | `qa-inventario-ip` |
| Network tag de IAP | `iap-ssh` |
| Network tag web | `inventory-web` |
| Regla SSH de IAP | `inventory-allow-iap-ssh` |
| Reglas web | `inventory-allow-http`, `inventory-allow-https` |
| Pool WIF | `github-inventory` |
| Provider WIF | `github-main` |
| Provider resource | `projects/61520277984/locations/global/workloadIdentityPools/github-inventory/providers/github-main` |
| Deploy service account | `github-inventory-deploy@project-e70349a8-c787-4733-9a0.iam.gserviceaccount.com` |
| GitHub repository ID | `1258796980` |
| GitHub owner ID | `115911218` |

### Provisioning inicial de la VM y TLS

Este paso ocurre una sola vez, antes del primer push que deba desplegar. Debe
ejecutarlo un operador que haya leído y aceptado los
[términos de Let’s Encrypt](https://letsencrypt.org/repository/). Desde un
checkout confiable del repositorio, copiar los tres scripts por IAP:

```bash
gcloud compute scp \
  scripts/gcp/bootstrap-vm.sh \
  scripts/gcp/issue-ip-certificate.sh \
  scripts/gcp/install-certificate-renewal.sh \
  "$GCP_VM_NAME:/tmp/" \
  --project="$GCP_PROJECT_ID" \
  --zone="$GCP_ZONE" \
  --tunnel-through-iap

gcloud compute ssh "$GCP_VM_NAME" \
  --project="$GCP_PROJECT_ID" \
  --zone="$GCP_ZONE" \
  --tunnel-through-iap
```

Ya dentro de la VM, ejecutar en este orden y usar un email operacional real:

```bash
export PRODUCTION_PUBLIC_IP="34.123.136.144"
export TLS_CERTIFICATE_NAME="$PRODUCTION_PUBLIC_IP"
export LETSENCRYPT_EMAIL="operaciones@example.com"
export LETSENCRYPT_AGREE_TOS=true

sudo env GCP_DEPLOY_PATH=/opt/inventory \
  bash /tmp/bootstrap-vm.sh

sudo env \
  PRODUCTION_PUBLIC_IP="$PRODUCTION_PUBLIC_IP" \
  TLS_CERTIFICATE_NAME="$TLS_CERTIFICATE_NAME" \
  LETSENCRYPT_EMAIL="$LETSENCRYPT_EMAIL" \
  LETSENCRYPT_AGREE_TOS="$LETSENCRYPT_AGREE_TOS" \
  bash /tmp/install-certificate-renewal.sh

sudo env \
  PRODUCTION_PUBLIC_IP="$PRODUCTION_PUBLIC_IP" \
  TLS_CERTIFICATE_NAME="$TLS_CERTIFICATE_NAME" \
  LETSENCRYPT_EMAIL="$LETSENCRYPT_EMAIL" \
  LETSENCRYPT_AGREE_TOS="$LETSENCRYPT_AGREE_TOS" \
  bash /tmp/issue-ip-certificate.sh

sudo /opt/certbot/bin/certbot certificates
sudo systemctl status inventory-certbot-renew.timer
```

`LETSENCRYPT_WITHOUT_EMAIL=true` es una alternativa soportada, pero debe ser una
decisión operacional explícita y no puede coexistir con `LETSENCRYPT_EMAIL`.
Nunca ejecutar primero contra producción para experimentar. Validar
`LETSENCRYPT_STAGING=true` en una VM descartable, sin reutilizar esa lineage en
el host final; un certificado del endpoint staging no permite que el deploy de
producción pase.

## GitHub Environment y variables

Crear un Environment llamado exactamente `production`. Configurarlo con:

- required reviewers para aprobar despliegue y ZAP contra producción;
- deployment branches limitado a `main`;
- protección de `main` con los checks requeridos del repositorio;
- un solo secret, `E2E_VIEWER_PASSWORD`, para el smoke read-only.

El password debe usar únicamente letras, dígitos y `._:/@+-`, debe corresponder
al usuario `viewer` de Keycloak y GitHub lo enmascara en logs. No se inyecta el
password de administrador en el runner.

Definir estas GitHub Environment variables:

| Variable | Valor esperado |
| --- | --- |
| `GCP_PROJECT_ID` | `project-e70349a8-c787-4733-9a0` |
| `GCP_ZONE` | `us-central1-a` |
| `GCP_VM_NAME` | `qa-inventario` |
| `GCP_VM_IP` | `34.123.136.144` |
| `GCP_DEPLOY_PATH` | `/opt/inventory` |
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | `projects/61520277984/locations/global/workloadIdentityPools/github-inventory/providers/github-main` |
| `GCP_DEPLOY_SERVICE_ACCOUNT` | `github-inventory-deploy@project-e70349a8-c787-4733-9a0.iam.gserviceaccount.com` |
| `PRODUCTION_URL` | `https://34.123.136.144`, sin `/` final |
| `E2E_VIEWER_USERNAME` | `viewer` |

Estos valores no son secretos. El workflow valida su forma y exige que
`PRODUCTION_URL` sea exactamente `https://$GCP_VM_IP`.

## Secretos de aplicación

En el primer despliegue, `scripts/gcp/init-env.sh --force` recibe únicamente el
password del viewer y genera en la VM:

- passwords de PostgreSQL y de la base de Keycloak;
- administrador, client secret y usuarios no usados por el smoke;
- password de Grafana.

Los despliegues posteriores conservan los valores actuales de
`shared/production.env`. El archivo tiene modo `0600`; `shared`, backups y
evidencia tienen modo `0700`. El colector redacta los valores sensibles y el
gate de seguridad rechaza secretos, JWT, credenciales HTTP, symlinks y formatos
de navegador que puedan retener sesiones.

No ejecutar `cat`, `set -x`, `docker compose config` sin redacción ni adjuntar
`production.env`, el realm renderizado, `/etc/letsencrypt` o dumps de base de
datos a un issue o artifact.

Para rotar secretos de aplicación se requiere un procedimiento coordinado con
PostgreSQL, Keycloak y Grafana; cambiar solo un valor en GitHub no rota el
servicio remoto.

## Flujo automático de producción

El workflow no tiene `workflow_dispatch`, no responde a pull requests ni se
activa desde `develop` o `staging`. Se activa mediante `workflow_run` únicamente
cuando `Quality Pipeline` termina exitosamente para un push a `main`, usando
exactamente `workflow_run.head_sha`. Su secuencia es:

1. Verificación previa completa en `Quality Pipeline`: pipelines aplicables,
   `CI Required` y mismo SHA que será promovido.
2. Aprobación del GitHub Environment `production`.
3. WIF oficial de Google y conexión a la VM mediante IAP/OS Login.
4. Creación de un Git bundle completo desde el checkout exacto, con credenciales
   persistentes del checkout deshabilitadas; checksum, clonación estándar y
   verificación remota.
5. Bootstrap idempotente cuando falten Git, Docker/Compose o Certbot `>=5.4`.
   El release queda en `releases/<SHA>` y se comprueba que
   `git rev-parse HEAD` coincide con el SHA del evento.
6. Verificación cerrada del certificado IP emitido durante el provisioning.
7. Backup y despliegue remoto con `scripts/gcp/deploy.sh`.
8. Checks remotos de health y rutas públicas.
9. `pnpm test:smoke` desde el runner contra la IP: frontend, backend health,
   OIDC, login viewer, dashboard, API y catálogo, sin mutaciones.
10. OWASP ZAP baseline desde el runner contra la misma URL.
11. Recolección, revisión de seguridad, rollback cuando corresponde, segunda
    recolección y revisión final.
12. Descarga y publicación solo si la revisión final de evidencia da `PASS`.
13. Retención remota: se conservan únicamente los releases actual y anterior,
    el último backup pre-deploy y la evidencia de esos dos SHA. También se
    eliminan imágenes etiquetadas de releases descartados, caché de build y
    paquetes temporales del workflow.

La concurrencia de producción no cancela un despliegue en curso. Un push
posterior espera; no interrumpe una migración o un rollback ya iniciado.

Todas las acciones del workflow, incluidas autenticación WIF y configuración de
`gcloud`, están fijadas por SHA inmutable con el tag mayor documentado al lado.

## Evidencia y bloqueo de promoción

El resumen de cada run enlaza:

- `https://34.123.136.144`;
- el SHA completo solicitado y el release remoto;
- el run de Actions;
- `production-evidence-<SHA>-<run_attempt>`.

El artifact, retenido 30 días, reúne como mínimo el manifiesto del despliegue,
estado de Compose, logs redactados, checks remotos, JUnit/capturas controladas
de Playwright, JSON/Markdown de ZAP, resultado de rollback y el reporte del gate
de seguridad. No se conservan trace, video, HAR, HTML de Playwright, tokens ni
archivos de configuración sensibles.

La evidencia de runner se transfiere primero a la VM. Allí se analiza junto con
los diagnósticos del servidor. Solo después de un `PASS` se empaqueta, se
comprueba su SHA-256 al descargarla y se entrega a
`actions/upload-artifact`. Si el safety gate falla, el resumen indica que se
retuvo la evidencia y no publica su contenido.

El job termina en rojo si falla el upload del release, deploy, post-deploy,
Playwright, ZAP, recolección, safety, descarga o publicación del artifact.
Configurar este workflow como check requerido de la política de promoción.

## Rollback

`deploy.sh` registra `current-release`, `current-sha`, `previous-release` y
`previous-sha`, y realiza un backup antes de cambiar la versión activa. Si falla
una validación o la evidencia preliminar, el workflow invoca automáticamente,
en la VM:

```bash
sudo env \
  GCP_DEPLOY_PATH=/opt/inventory \
  PRODUCTION_STATE_DIR=/opt/inventory/shared \
  PRODUCTION_ENV_FILE=/opt/inventory/shared/production.env \
  PRODUCTION_EVIDENCE_DIR=/opt/inventory/shared/evidence/<SHA-fallido> \
  bash /opt/inventory/releases/<SHA-fallido>/scripts/gcp/rollback.sh
```

`rollback.sh` no recibe una versión arbitraria: usa `previous-release` y
`previous-sha`, restaura las imágenes anteriores y vuelve a validar la
instancia. Luego el workflow recolecta la evidencia final. El run permanece
fallido aunque el rollback pase, porque el SHA nuevo no fue promovido.

El rollback automático preserva las bases; no restaura dumps. El manifiesto del
backup pre-deploy queda para una recuperación manual expresamente aprobada.
Por ello las migraciones de producción deben ser compatibles hacia atrás con la
versión anterior. Una migración destructiva requiere su propio plan de
restauración y no queda autorizada por este workflow.

## Retención y uso de disco

Cada SHA se despliega primero en `releases/<SHA>` para que el release sea
inmutable y verificable. Después de publicar la evidencia segura,
`scripts/gcp/cleanup-retention.sh` aplica una retención acotada:

- conserva `current-release` y `previous-release`;
- elimina cualquier release más antiguo;
- conserva únicamente el último backup pre-deploy;
- conserva en la VM la evidencia del SHA actual y del anterior;
- elimina las etiquetas `inventory-backend:<SHA>` e
  `inventory-frontend:<SHA>` que ya no pertenecen a esos releases;
- elimina imágenes Docker colgantes y toda la caché de build no utilizada;
- elimina paquetes temporales antiguos y el workflow borra los paquetes
  exactos de la ejecución al finalizar.

Los artifacts descargables de GitHub mantienen su retención independiente de
30 días. La limpieza no usa `docker system prune`, `docker volume prune` ni
`docker compose down -v`; los volúmenes de PostgreSQL, Keycloak y
observabilidad no se eliminan. Si la limpieza falla, el gate final queda rojo
para evitar que el crecimiento de disco pase inadvertido.

En el primer despliegue no existe una versión anterior. Si ese intento falla, no
hay release al cual volver: el job queda rojo, conserva diagnóstico seguro y el
servicio no debe declararse disponible hasta corregir y volver a desplegar.

Para una intervención manual, autenticar a un operador por IAP, confirmar
`current-release`, `current-sha`, `previous-release`, `previous-sha` y el
backup, y ejecutar el mismo script. Nunca editar esos archivos ni el environment
mientras Compose está cambiando.

## Operación y diagnóstico

Entrar por IAP y revisar sin imprimir el environment:

```bash
gcloud compute ssh "$GCP_VM_NAME" \
  --project="$GCP_PROJECT_ID" \
  --zone="$GCP_ZONE" \
  --tunnel-through-iap

sudo docker compose \
  --env-file /opt/inventory/shared/production.env \
  --project-name inventory-production \
  --file "$(sudo cat /opt/inventory/shared/current-release)/docker-compose.yml" \
  --file "$(sudo cat /opt/inventory/shared/current-release)/docker-compose.production.yml" \
  ps
```

Comprobaciones públicas:

```bash
curl --fail --show-error https://34.123.136.144/health
curl --fail --show-error https://34.123.136.144/api/actuator/health
curl --fail --show-error https://34.123.136.144/auth/realms/inventory/.well-known/openid-configuration
```

No abrir puertos internos como medida de diagnóstico. Usar IAP, `docker compose
ps`, logs redactados y el artifact seguro del run.

## Alcance frente al issue #108

Esta topología cubre producción en una sola VM y sus validaciones post-deploy.
No convierte automáticamente `development` ni `staging` en ambientes GCP
persistentes. El preview actual de staging sigue siendo runner-private. El
issue #108 fue cerrado el 28 de julio de 2026, pero esa decisión externa no
cambia el alcance técnico observado: production tiene validación desplegada;
development posee Cloud Run y staging una foundation GCP. El PR #145 añadió
planes read-only y `apply` administrado para development/staging, pero ese
workflow solo valida health/OIDC; no equivale por sí solo a los gates completos
de producción.

El issue #107 seguía abierto el 29 de julio aunque su implementación fue
fusionada. No usar el estado `closed` de #108 ni la existencia del workflow
administrado para afirmar que los tres ambientes GCP tienen promoción y smoke
equivalentes: production continúa en la VM.

Una sola VM también comparte blast radius, disco, CPU y ventana de
mantenimiento para gateway, aplicación, identidad, bases y observabilidad. No
ofrece alta disponibilidad, rolling deploy real, base administrada ni failover
regional. Para una producción con SLO estricto, migrar bases a servicios
administrados, imágenes a Artifact Registry y workloads a MIG/GKE/Cloud Run,
manteniendo los mismos gates por SHA.

La base declarativa para esa evolución está documentada en
[`opentofu-gcp.md`](opentofu-gcp.md). Sus recursos se crean en paralelo y no
administran ni importan esta VM; cualquier cambio de tráfico requiere una
migración posterior y un rollback explícito.

# Usuarios y accesos

No se incluyen contraseñas, tokens, correos humanos ni claves privadas.

## Inventario

| Servicio | Identidad | Rol | Propósito | Entorno | Origen de credencial | Acceso/rotación |
|---|---|---|---|---|---|---|
| Aplicación/Keycloak | `carlos` | `INVENTORY_ADMIN` | administración funcional/demo | local/realm semilla | `.env` generado | login OIDC; rotar en Keycloak o regenerar entorno |
| Aplicación/Keycloak | `edwin` | `STOCK_OPERATOR` | operación de stock | local/realm semilla | `.env` generado | igual |
| Aplicación/Keycloak | `viewer` | `INVENTORY_VIEWER` | consulta/E2E/k6 | local/QA | `.env` o Secret Manager por ambiente | revocar/deshabilitar en Keycloak |
| Aplicación/Keycloak | `auditor` | `AUDIT_REVIEWER` | auditoría | local/QA | `.env` o Secret Manager | revocar/deshabilitar en Keycloak |
| Keycloak | `service-account-inventory-admin-service` | realm-management mínimo | Admin REST desde backend | todos | client secret administrado | rotar secreto y redeploy backend |
| PostgreSQL | `inventory_user` | propietario/usuario de app local | inventario/Flyway | local | `.env` | rotar coordinadamente con backend/Flyway |
| Jenkins | `admin` | administrador local inicial | operar Jenkins | Jenkins local | `.env.jenkins` | JCasC/credential store; rotar antes de exponer |
| Grafana | usuario admin configurado por entorno | admin | dashboards/datasources | local/staging/prod | `.env`/secret store | rotar y reiniciar/reprovisionar |
| Prometheus | ninguna identidad propia verificada | n/a | consulta de métricas | local/staging | control de red/gateway | mantener privado o proteger con proxy |
| GCP VM | identidad Google autorizada | OS Login/IAP | administración | producción | Google IAM | conceder/revocar IAM; no usar claves compartidas |
| Cloud Run | `inventory-development-runtime@...` | runtime | leer secretos/conectar SQL | development GCP | IAM sin clave | revocar roles o cambiar SA |
| GitHub deploy | SAs `*-deploy@...` | despliegue por ambiente | CI/CD | GCP | WIF | revocar binding/provider; no hay keys |
| OpenTofu plan | SAs `*tofu-plan@...` | plan read-only esperado | PR plan | GCP | WIF | revisar mínimo privilegio |
| VM runtime | Compute Engine default SA | scopes logging/monitoring/storage | VM producción | GCP | metadata server | reemplazar por SA dedicada si es viable |

El sufijo `@...` oculta el dominio repetitivo del proyecto en esta tabla; los
nombres completos se obtienen con `gcloud iam service-accounts list`.

## Keycloak

El export versionado declara usernames y roles, no passwords reales. Los
passwords se renderizan/injectan por ambiente.

`Verificado indirectamente por E2E`

```bash
curl --fail \
  http://localhost:8081/realms/inventory/.well-known/openid-configuration
```

Administrar usuarios desde la UI de la aplicación requiere `user:manage`; el
backend utiliza el cliente confidencial. La gestión de contraseñas permanece
en Keycloak.

## GCP

Se observaron 15 service accounts y cero claves user-managed. Había dos
identidades humanas Owner; se omiten sus correos. Revisión autorizada:

`Verificado · Requiere privilegios`

```bash
gcloud projects get-iam-policy project-e70349a8-c787-4733-9a0
gcloud iam service-accounts list \
  --project=project-e70349a8-c787-4733-9a0
```

Revocar IAM o deshabilitar una SA cambia producción: requiere ticket,
aprobación, análisis de consumidores y rollback. No se ejecutó.

La auditoría WIF detectó bindings por repositorio que pueden cruzar providers
del mismo pool. La revisión por ambiente, GitHub Environments y comandos están
en [Guía operativa GCP/OpenTofu](27-guia-operativa-gcp-opentofu.md#workload-identity-federation).

## Jenkins

La instancia local se crea desde `compose.jenkins.yml` y
`infra/jenkins/jenkins.yaml`. La contraseña inicial se encuentra en
`.env.jenkins`, ignorado por Git. No se verificó una instancia Jenkins remota.

Estado remoto: **Pendiente de verificación**. Confirmar URL, TLS, RBAC, SSO,
backups, plugins y ejecución real desde un operador autorizado.

## Grafana y Prometheus

Grafana gestiona su usuario admin por entorno. Prometheus no incluye un sistema
de usuarios propio en la configuración del repositorio: en development se
publica el puerto; staging usa loopback; producción debería depender de
Nginx/red. La autenticación del `/grafana/` productivo no pudo comprobarse sin
credenciales/SSH.

Riesgo: un Prometheus público expone topología y etiquetas. Mantener 9090
cerrado en producción (firewall observado solo publica 80/443).

## Solicitud, rotación y revocación

1. Identificar ambiente, identidad, rol mínimo y fecha de expiración.
2. Aprobar por responsable del sistema/ambiente.
3. Crear identidad individual o WIF; nunca compartir password.
4. Validar acceso y denegación fuera de alcance.
5. Registrar owner y revisión periódica.
6. Rotar en el almacén, actualizar consumidor, validar y revocar versión
   anterior.
7. Al retirar acceso, revocar sesión/tokens y revisar logs.

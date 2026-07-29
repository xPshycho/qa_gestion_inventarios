# Staging preview

Esta guía define el ambiente validable del issue #86. El despliegue actual es un
preview reproducible y aislado en el runner de GitHub Actions: los servicios se
publican únicamente en `127.0.0.1`, se validan desde ese mismo host, se conserva
la evidencia y luego se destruye el stack con sus volúmenes.

No existe una URL pública o persistente. La referencia verificable de cada
despliegue es el run de `Staging Preview`, su SHA desplegado y el artifact
`test-results-staging-post-deploy-<DEPLOYED_SHA>-<run_attempt>`, si el gate de seguridad permite
publicarlo. En una ejecución local, el stack permanece disponible en el host
hasta ejecutar `destroy.sh`. Esta guía describe el contrato implementado; no
constituye por sí sola evidencia de que exista un run remoto.

## Arquitectura y aislamiento

El despliegue combina `docker-compose.yml` con
`docker-compose.staging.yml`. No usa `docker-compose.override.yml`, reservado
para desarrollo.

| Servicio | URL predeterminada en el host |
| --- | --- |
| Frontend | `http://127.0.0.1:15173` |
| Backend / Swagger UI | `http://127.0.0.1:18082` / `http://127.0.0.1:18082/swagger-ui/index.html` |
| Keycloak | `http://127.0.0.1:18081` |
| Prometheus | `http://127.0.0.1:19090` |
| Grafana | `http://127.0.0.1:13000` |
| Alloy | `http://127.0.0.1:12346` |
| Loki | `http://127.0.0.1:13100` |
| Tempo | `http://127.0.0.1:13200` |
| Alertmanager | `http://127.0.0.1:19093` |

PostgreSQL de la aplicación y PostgreSQL de Keycloak son servicios separados.
Las imágenes de backend y frontend usan `APP_VERSION` como tag y ambos
contenedores registran labels de ambiente, versión y `STAGING_DEPLOYMENT_ID`.
En Actions, `APP_VERSION` es el SHA completo obtenido después del checkout. El
backend usa el perfil Spring `staging` y emite telemetría con el atributo
`deployment.environment=staging`.

Todos los puertos se enlazan a `STAGING_BIND_ADDRESS=127.0.0.1`. El tráfico HTTP
sin TLS es aceptable únicamente bajo ese aislamiento de loopback; este diseño no
debe exponerse directamente a Internet ni tratarse como configuración de
producción.

El aislamiento se valida antes de usar Compose:

- `COMPOSE_PROJECT_NAME` debe cumplir
  `^inventory-staging-[a-z0-9][a-z0-9_-]*$`; en Actions incorpora el run y el
  intento;
- `STAGING_BIND_ADDRESS` debe ser exactamente `127.0.0.1`;
- cada URL pública debe ser `http://127.0.0.1:<puerto configurado>`, todos los
  puertos deben ser numéricos, válidos y distintos;
- las únicas combinaciones admitidas son
  `operator-managed:host-loopback` y `ephemeral:runner-private`;
- todos los comandos pasan de forma explícita el environment, los dos archivos
  Compose y `--project-name`; no dependen del nombre del directorio.

Alloy aplica un `keep` a la label Docker
`com.docker.compose.project` igual a `COMPOSE_PROJECT_NAME`. Por tanto, solo
descubre logs de ese proyecto y les añade `compose_project`, `compose_service`
y `deployment_id`; no mezcla contenedores de desarrollo ni de otro preview.

## Archivos que definen el ambiente

- `.env.staging.example`: contrato de variables sin valores secretos.
- `docker-compose.staging.yml`: overlay y puertos exclusivos de staging.
- `backend/src/main/resources/application-staging.properties`: configuración
  de aplicación separada.
- `scripts/staging/`: inicialización, despliegue, validación, evidencia, backup,
  rollback y destrucción.
- `tests/staging/post-deploy.mjs`: pruebas black-box de API, flujos principales y
  observabilidad.
- `.github/workflows/staging-preview.yml`: quality gates, despliegue efímero y
  publicación de evidencia.

`.staging/` es estado generado y está ignorado por Git. Nunca se debe añadir al
repositorio.

## Requisitos para una ejecución local

- Bash, OpenSSL y `jq`.
- Docker Engine con Docker Compose v2.
- Node.js y `pnpm`.
- Chromium compatible con Playwright.

Las imágenes de ZAP y k6 se descargan por Docker. El equipo debe disponer de
recursos suficientes para ejecutar los once servicios persistentes, el job
one-shot de Flyway y las validaciones.

## Variables y secretos

Crear la configuración a partir del contrato:

```bash
./scripts/staging/init-env.sh
```

El comando genera `.staging/staging.env` con permisos `0600` y crea valores
aleatorios si no fueron inyectados. `--force` reemplaza ese archivo, pero
reutiliza sus secretos actuales salvo que se inyecten valores nuevos:

```bash
./scripts/staging/init-env.sh --force
```

Las variables no sensibles se agrupan así:

| Propósito | Variables |
| --- | --- |
| Trazabilidad | `COMPOSE_PROJECT_NAME`, `APP_VERSION`, `STAGING_DEPLOYMENT_ID`, `STAGING_LIFECYCLE`, `STAGING_VISIBILITY` |
| Red | `STAGING_BIND_ADDRESS`, `STAGING_FRONTEND_URL`, `STAGING_BACKEND_URL`, `STAGING_KEYCLOAK_URL` y las variables `*_PORT` |
| Base de aplicación | `POSTGRES_DB`, `POSTGRES_USER` |
| Identidad | `KEYCLOAK_DB`, `KEYCLOAK_DB_USER`, `KEYCLOAK_ADMIN`, `KEYCLOAK_REALM`, `KEYCLOAK_CLIENT_ID`, `KEYCLOAK_ADMIN_CLIENT_ID` y los usernames `E2E_*` |
| Aplicación y telemetría | `INVENTORY_CORS_ALLOWED_ORIGINS`, `OTEL_SDK_DISABLED`, `OTEL_DEPLOYMENT_ENVIRONMENT` |
| Grafana | `GRAFANA_ADMIN_USER` |

`.env.staging.example` contiene el contrato completo y los valores no sensibles
predeterminados. Para sobrescribirlos de forma reproducible, exportar las
variables antes de ejecutar `init-env.sh --force`.

Los secretos administrados son:

- `POSTGRES_PASSWORD`
- `KEYCLOAK_DB_PASSWORD`
- `KEYCLOAK_ADMIN_PASSWORD`
- `KEYCLOAK_ADMIN_CLIENT_SECRET`
- `E2E_ADMIN_PASSWORD`
- `E2E_OPERATOR_PASSWORD`
- `E2E_VIEWER_PASSWORD`
- `E2E_AUDITOR_PASSWORD`
- `GRAFANA_ADMIN_PASSWORD`

No se imprimen en los logs ni se incluyen en artifacts. El colector redacta sus
valores de los logs de Compose. No se deben copiar `staging.env`, el realm
renderizado de `.staging/keycloak/`, contraseñas ni tokens a un PR.

El workflow genera secretos efímeros dentro del runner; actualmente no requiere
secretos persistentes del repositorio ni del environment. Una futura integración
con proveedor externo debe almacenar sus credenciales como GitHub Environment
secrets, nunca en el YAML.

## Despliegue local reproducible

Desde la raíz del repositorio:

```bash
./scripts/staging/init-env.sh
./scripts/staging/deploy.sh
./scripts/staging/post-deploy.sh
```

`deploy.sh` renderiza el realm de Keycloak, valida la configuración Compose,
construye las imágenes y espera que los servicios estén saludables.
`post-deploy.sh` ejecuta las seis validaciones funcionales aunque una falle,
recolecta evidencia, ejecuta `evidence-safety` como séptima fase, genera el
resumen y devuelve un código distinto de cero si cualquier fase o la
recolección no pasa.

La ejecución local usa:

- `STAGING_LIFECYCLE=operator-managed`
- `STAGING_VISIBILITY=host-loopback`

Por ello el stack continúa activo para inspección. Para recolectar evidencia de
nuevo:

```bash
./scripts/staging/collect-evidence.sh
```

Para detenerlo conservando los volúmenes:

```bash
./scripts/staging/destroy.sh
```

Usar `--volumes` solamente para un ambiente descartable:

```bash
./scripts/staging/destroy.sh --volumes
```

## Pipeline de GitHub Actions

`Staging Preview` se ejecuta en:

- pull requests cuyo destino es `develop`;
- pull requests cuyo destino es `main`, con un gate que exige que la rama
  origen sea exactamente `staging`;
- pushes a `staging`;
- `workflow_dispatch`, con un `deploy_ref` opcional, cuando el workflow ya
  exista en la rama por defecto.

Un PR hacia `main` desde cualquier rama distinta de `staging` o desde un fork
falla el job de despliegue y no es una ruta de promoción válida.

El checkout, las imágenes y `deployment.json` usan el commit exacto que se
despliega. El pipeline primero ejecuta los quality gates:

- backend unitario, API MockMvc, integración Testcontainers y JaCoCo;
- frontend build, unit tests y cobertura.

Después crea un proyecto Compose único por run, con:

- `STAGING_LIFECYCLE=ephemeral`;
- `STAGING_VISIBILITY=runner-private`;
- puertos accesibles solo desde el runner;
- volúmenes nuevos y datos sintéticos deterministas.

Las pruebas `apiTest` e `integrationTest` son gates previos al despliegue, no
pruebas contra la instancia desplegada. La aceptación post-deploy proviene de
las fases black-box siguientes:

| Fase | Verificación |
| --- | --- |
| `integration` | 11 servicios, Flyway sin fallos y datos semilla esperados |
| `api-and-observability` | health, OIDC, Swagger/OpenAPI, autenticación, CORS, productos, dashboard, CRUD/auditoría, stock, restauración y backends de observabilidad |
| `e2e` | login y recorridos de UI contra el stack existente, incluida evidencia de auditoría |
| `security-headers` | encabezados de seguridad HTTP |
| `security-zap` | ZAP baseline contra la instancia desplegada |
| `performance-smoke` | smoke de k6; no sustituye una prueba formal de carga |
| `evidence-safety` | ausencia de secretos, JWT y artifacts inseguros en toda la evidencia |

La comprobación de observabilidad pertenece al despliegue actual, no a datos
históricos. El script crea un marcador de log después de registrar el inicio del
check; Loki debe devolverlo dentro de ese rango y con
`compose_project=COMPOSE_PROJECT_NAME`. Tempo se consulta por
`service.name=inventory-backend` y
`deployment.id=STAGING_DEPLOYMENT_ID`, y solo acepta trazas iniciadas después
del comienzo del check.

En la fase `e2e`, staging fuerza `list`, JUnit y un reporter PNG de allowlist.
Conserva únicamente los PNG allowlisted que las pruebas adjuntan explícitamente
para login, CRUD, roles, responsive, stock y auditoría. Deshabilita también el
screenshot automático de fallo, pues no puede someterse a una revisión visual
antes de publicar. No genera reporte HTML ni retiene traces o videos.

Después del post-deploy, el workflow ejecuta una última
`collect-evidence.sh`. Solo entonces vuelve a ejecutar
`verify-evidence-safety.sh`; el upload usa la condición
`steps.evidence_safety.outcome == 'success'`. Por ello:

- un fallo de deploy o post-deploy puede conservar diagnóstico únicamente si
  esa revisión final da `PASS`;
- si la revisión final no pasa, la evidencia detallada se retiene y no existe
  artifact publicable;
- el resumen del job informa que la evidencia fue retenida, sin copiar su
  contenido;
- después del intento de upload, el preview se destruye con sus volúmenes;
- el gate final exige deploy, post-deploy y revisión final de evidencia
  exitosos.

No queda una instancia navegable después del run.

## Evidencia y trazabilidad

Una ejecución cuya revisión final de seguridad pasa intenta publicar por 30
días:

```text
test-results-staging-post-deploy-<DEPLOYED_SHA>-<run_attempt>
├── deployment.json
├── deployment-summary.md
├── compose-ps.txt
├── compose-images.txt
├── compose.log
└── post-deploy/
    ├── summary.json
    ├── summary.md
    └── reportes, logs redactados y capturas de las fases
```

Este artifact solo existe cuando la revisión final de seguridad da `PASS`.
`DEPLOYED_SHA` se obtiene con `git rev-parse HEAD` después del checkout y también
se usa como `APP_VERSION`; no se infiere del nombre de una rama ni del SHA del
evento. `deployment.json` registra ese commit, la versión y los identificadores
de imagen, el fingerprint de fuentes, el estado del worktree, los servicios
activos, el proyecto Compose, el ciclo de vida y la visibilidad.

La revisión de seguridad recorre todos los archivos y rechaza symlinks,
`trace.zip`, videos WebM, HAR e imágenes E2E fuera del directorio de PNG
controlados. Busca los secretos configurados en texto plano,
sus representaciones Base64, credenciales Basic y valores con forma de JWT.
También abre de forma recursiva ZIP y gzip y decodifica payloads Base64
embebidos, con límites de tamaño, expansión y profundidad. El archivo
`evidence-safety.json` solo se genera con resultado `PASS`.

La evidencia de cierre del issue debe incluir:

- enlace al run exitoso;
- SHA de `deployment.json`;
- nombre exacto `test-results-staging-post-deploy-<DEPLOYED_SHA>-<run_attempt>`;
- `ephemeral` y `runner-private`;
- resultado de las siete fases, incluida `evidence-safety`;
- al menos una captura o reporte del flujo principal;
- confirmación de que el safety posterior a la última recolección dio `PASS`.

Si `collect-evidence.sh` falla, `post-deploy.sh` añade
`evidence-collection: FAIL` al resumen y el gate completo falla. Esa anotación
de diagnóstico no sustituye ninguna de las siete fases obligatorias.

## Configuración manual obligatoria en GitHub

El propietario del repositorio debe crear y proteger el GitHub Environment
`staging` **antes de ejecutar por primera vez el workflow**. El YAML referencia
el environment, pero no puede crear sus reglas de protección.

En `Settings > Environments > staging` se debe configurar:

1. al menos un required reviewer distinto del autor y, si la opción está
   disponible, impedir la autoaprobación;
2. deployment branches/tags con política de referencias seleccionadas que
   permita `staging` y las referencias de merge de PR autorizadas;
3. sin URL del environment, porque el servicio solo existe en loopback;
4. sin secretos permanentes mientras el workflow continúe generándolos de forma
   efímera.

Si el workflow referencia un environment inexistente, GitHub puede crearlo sin
reglas de protección. Por eso no se debe usar ese mecanismo como sustituto de la
configuración anterior.

Cuando exista por primera vez el check
`Deploy and validate runner-private staging`, el propietario también debe
agregarlo como status check requerido a las reglas de las ramas de promoción
correspondientes.

`workflow_dispatch` solo queda disponible desde la interfaz cuando el archivo
del workflow existe en la rama por defecto. Mientras `main` no lo contenga, la
forma reproducible de validación es el PR a `develop` o el push resultante de un
PR aprobado a `staging`.

## Promoción

No se permiten promociones directas:

1. integrar el cambio en `develop` mediante PR revisado y conservar la
   evidencia aplicable;
2. promover `develop` a `staging` mediante PR aprobado, sin push directo;
3. validar el push al SHA real de `staging` y adjuntar su evidencia;
4. promover `staging` a `main` mediante PR; el workflow rechaza cualquier otro
   origen para `main`.

Para promociones se recomienda merge commit, pues conserva una relación
explícita entre ramas. En cualquier estrategia debe registrarse el SHA exacto de
`deployment.json` y este debe corresponder al contenido que se desea promover.

## Rollback y recuperación

### Preview efímero de Actions

El workflow destruye contenedores y volúmenes después del intento condicionado
de publicación. Por tanto, no existe una instancia o base viva que revertir. La
recuperación consiste en volver a ejecutar el pipeline con un SHA conocido como
bueno; el nuevo run crea datos sintéticos desde cero.

### Staging local administrado

Antes de un cambio de riesgo, respaldar la base de la aplicación:

```bash
./scripts/staging/backup-database.sh
```

El backup se escribe de forma atómica: `pg_dump` custom se comprime hacia un
archivo temporal privado dentro de `.staging/backups`, se verifica que no esté
vacío y que gzip sea válido, se fija modo `0600` y solo entonces se mueve al
nombre final. El script no sobrescribe backups y solo acepta destinos
`.dump.gz` directamente dentro de ese directorio.

Para volver a imágenes que ya existan localmente:

```bash
./scripts/staging/rollback.sh <APP_VERSION_ANTERIOR>
```

El rollback comprueba que ambas imágenes existan, crea un backup atómico,
actualiza versión e identificador de despliegue y cambia backend y frontend como
una unidad. La versión anterior solo se acepta después de ejecutar el gate
post-deploy completo de siete fases. Si falla, el script restaura las imágenes,
la versión y el identificador anteriores, separa la evidencia fallida, recolecta
evidencia del estado recuperado y termina con error; no marca el rollback como
exitoso.

Flyway es forward-only: si la versión anterior no es compatible con el esquema
actual, se debe restaurar de forma explícita el backup correcto:

```bash
./scripts/staging/restore-database.sh <BACKUP.dump.gz> --confirm
```

La restauración es exacta y destructiva: exige un archivo explícito y
`--confirm`, valida gzip y el catálogo de `pg_restore`, crea primero un backup
de seguridad, detiene backend y frontend, termina sesiones, elimina y recrea la
base de la aplicación y ejecuta
`pg_restore --clean --if-exists --no-owner --exit-on-error`. Luego reinicia la
aplicación y exige que
`verify-integration.sh` pase. Un trap intenta reiniciar los servicios aun si la
restauración falla.

Los scripts respaldan únicamente la base de la aplicación, no la base de
Keycloak. El realm incluido es sintético y se genera para cada ambiente; en un
volumen persistente, `--import-realm` no reemplaza un realm ya creado. Los
cambios persistentes de identidad deben aplicarse mediante la Admin API o, solo
si el volumen es descartable, recreando el volumen de Keycloak.

## Datos y límite de producción

Staging ejecuta Flyway V1--V7 y sus datos semilla sintéticos. Producción todavía
no está provisionada y no debe reutilizar esa carga sin separar o desactivar los
usuarios y productos demo. Este preview demuestra despliegue, integración y
recuperación de staging; no representa un despliegue de producción.

# Guía de reporting, cobertura y CI

La ruta canónica de consulta es [`test-results/`](../../test-results/README.md),
tanto localmente como dentro de los artifacts de CI. Las herramientas conservan
sus carpetas nativas de build cuando las necesitan, pero
`scripts/testing/collect_test_results.py` copia la evidencia exportable,
normaliza JUnit y genera `summary.md`, `summary.json` y `metrics.prom`.

Los artifacts de diagnóstico solo se publican cuando su contenido es seguro.
Staging puede publicar diagnóstico si falla el despliegue o una prueba
post-deploy, pero únicamente cuando la revisión de seguridad ejecutada después
de la última recolección de evidencia da `PASS`.

## Estructura central

| Suite | Ruta canónica |
|---|---|
| Backend unitarias | `test-results/backend/unit/` |
| Backend integración/Testcontainers | `test-results/backend/integration/` |
| Backend API/contrato | `test-results/backend/api/` |
| Frontend unitarias/cobertura | `test-results/frontend/unit/` |
| Playwright E2E | `test-results/e2e/playwright/` |
| Rendimiento k6 | `test-results/performance/k6/` |
| OWASP ZAP | `test-results/security/zap/` |
| Trivy | `test-results/security/trivy/` |
| Validación post-deploy | `test-results/staging/post-deploy/` |

Después de ejecutar una o varias suites locales, centralice todo lo disponible:

```bash
./scripts/testing/collect_local_test_results.sh
```

Un `status: unknown` significa que la suite no produjo evidencia en esa
ejecución; no se presenta como aprobada. Los XML JUnit con failures o errors
siempre cambian el resumen a `failed`.

## Comandos locales

Todos los comandos de esta sección parten de la raíz del repositorio. La forma
recomendada, que evita depender de un Chromium instalado en el host y evita
errores por ejecutar `cd backend` o `cd tests/e2e` dos veces, es:

```bash
make test
```

Los targets de backend seleccionan explícitamente un JDK 21 instalado bajo
`/usr/lib/jvm`, aunque la shell tenga otro Java activo mediante SDKMAN.

Este comando:

1. inicializa `.env` con secretos aleatorios y permisos `0600`;
2. ejecuta build, unit, API e integración del backend;
3. ejecuta build y unit tests del frontend usando Chromium de Playwright en Docker;
4. levanta un stack Compose aislado y ejecuta Playwright en su imagen fijada;
5. ejecuta smoke de k6, headers, OWASP ZAP y Trivy;
6. centraliza todos los resultados y elimina cada stack aislado.

No configure `CHROME_BIN=/usr/bin/chromium` salvo que ese archivo exista. El
ejecutor oficial no necesita un navegador instalado en el host.
Los runners leen las URLs desde los puertos del `.env`; la fuente de verdad es
[`puertos.md`](../../puertos.md).

### Interfaz de desarrollo

| Objetivo | Alcance |
|---|---|
| `make help` | Lista todos los targets y su propósito. |
| `make env` | Crea o completa `.env` con permisos `0600`. |
| `make build` | Construye backend y frontend. |
| `make build-backend` | Ejecuta `clean assemble` con Java 21/Gradle. |
| `make build-frontend` | Instala con lockfile y construye Angular. |
| `make check-config` | Valida scripts, recolector y Compose base + overlay local sin levantar servicios. |
| `make test-backend` | Unitarias y JaCoCo. |
| `make test-api` | API/contrato RestAssured. |
| `make test-integration` | Testcontainers. |
| `make test-infra` | Formato, validación y planes contractuales OpenTofu con provider simulado; no llama APIs GCP. |
| `make test-frontend` | Karma en Chromium Playwright/Docker. |
| `make test-e2e` | Stack Compose y Playwright. |
| `make test-performance` | k6 smoke. |
| `make test-security` | Headers, ZAP y Trivy sobre repositorio e imágenes. |
| `make results` | Recolecta resultados ya disponibles. |
| `make test` | Ejecuta todas las fases anteriores. |

Los runners de `make test-e2e`, `make test-performance` y
`make test-security` cargan explícitamente `docker-compose.yml` y
`docker-compose.override.yml`. El segundo archivo publica en el host los
puertos definidos en `.env`; omitirlo deja los servicios accesibles sólo
dentro de la red Docker. Cada runner usa un proyecto Compose propio, reinicia
su directorio de resultados y desmonta contenedores, redes y volúmenes aunque
falle el setup. También realiza readiness HTTP desde el host antes de iniciar
Playwright, k6 o ZAP.

Las imágenes públicas se descargan primero con la configuración normal de
Docker. Si el credential helper de Docker Desktop/WSL falla, el runner reintenta
la descarga con una configuración temporal sin helpers. Trivy conserva sus
bases en `/tmp/qa-gestion-inventarios-trivy-<uid>` y usa los repositorios
oficiales de GHCR para no depender de `mirror.gcr.io`.

| Suite | Comando | Reporte local |
|---|---|---|
| Backend build | `cd backend && ./gradlew clean assemble --no-daemon` | `backend/build/libs/*.jar` |
| Backend unit + JaCoCo | `cd backend && ./gradlew test jacocoTestReport jacocoTestCoverageVerification --no-daemon; cd .. && ./scripts/testing/collect_local_test_results.sh` | `test-results/backend/unit/` |
| API RestAssured | `cd backend && ./gradlew apiTest --no-daemon; cd .. && ./scripts/testing/collect_local_test_results.sh` | `test-results/backend/api/` |
| Integration Testcontainers | `cd backend && ./gradlew integrationTest jacocoIntegrationTestCoverageVerification --no-daemon; cd .. && ./scripts/testing/collect_local_test_results.sh` | `test-results/backend/integration/` |
| Frontend unit + coverage | `cd frontend && pnpm test` | `test-results/frontend/unit/` |
| Frontend build | `cd frontend && pnpm build` | `frontend/dist/` |
| E2E Playwright local | `cd tests/e2e && pnpm test` | `test-results/e2e/playwright/` |
| E2E conservando el stack para diagnóstico | `E2E_KEEP_STACK=true pnpm --dir tests/e2e test` | `test-results/e2e/playwright/` |
| Performance k6 | `./tests/performance/run-local.sh` | `test-results/performance/k6/` |
| Headers + OWASP ZAP + Trivy | `./tests/security/run-local.sh` | `test-results/security/headers/`, `test-results/security/zap/`, `test-results/security/trivy/` |
| Staging completo | `./scripts/staging/deploy.sh && ./scripts/staging/post-deploy.sh && ./scripts/testing/collect_local_test_results.sh` | `test-results/staging/post-deploy/` |
| Recolectar evidencia de staging | `./scripts/staging/collect-evidence.sh` | `.staging/evidence/deployment.json`, resumen, servicios, imágenes y logs redactados |

Si se desea ejecutar una suite individual, primero regrese a la raíz. Por
ejemplo, después de estar dentro de `backend/`, use `./gradlew test`; no vuelva
a ejecutar `cd backend`. Para E2E individual desde la raíz:

```bash
pnpm --dir tests/e2e test
```

Ese script prepara `.env`, instala dependencias, usa la imagen
`mcr.microsoft.com/playwright:v1.60.0-noble`, pasa los secretos al contenedor
sin imprimirlos y limpia el proyecto Compose `inventory-e2e-local`.

## GitHub Actions

| Workflow | Jobs principales | Artifacts |
|---|---|---|
| `Quality Pipeline` | clasificación de rutas, pipelines aplicables, gate agregado `CI Required` y promoción | No genera evidencia propia; agrega los resultados de los workflows llamados |
| `Backend CI` | build, unit tests, API tests, integration tests | `test-results-backend-unit-*`, `test-results-backend-api-*`, `test-results-backend-integration-*` |
| `Frontend CI` | build Angular, unit tests con coverage | `test-results-frontend-unit-*`, `frontend-diagnostics-*` si falla |
| `OpenTofu CI` | formato, validación y planes contractuales de development, staging y production | No publica planes ni credenciales; la salida queda en el log |
| `Playwright E2E` | stack Docker Compose, matriz Playwright y safety | `test-results-e2e-playwright-*`, solo después de `verify-artifacts.sh` |
| `Security Testing` | Trivy, ZAP y safety de evidencia | `test-results-security-trivy-*`, `test-results-security-zap-*` |
| `Secret Scanning` | Gitleaks sobre PR y push | No publica artifacts ni comentarios con detecciones |
| `SonarCloud` | análisis de calidad y cobertura JaCoCo | Quality Gate en el PR |
| `Conventional Commits` | validación de commits del PR | Check de formato |
| `Staging Preview` | deploy Compose aislado y siete fases post-deploy después de `CI Required` | `test-results-staging-post-deploy-<DEPLOYED_SHA>-<run_attempt>`, solo con evidence safety `PASS` |

`Quality Pipeline` se ejecuta en cada PR y selecciona las suites por rutas,
siguiendo las áreas y ramas definidas en el anexo del proyecto:

| Cambio del PR | Pipelines requeridos |
|---|---|
| Sólo `docs/**` o Markdown | Conventional Commits y Gitleaks |
| `backend/**` | Backend CI y SonarCloud; si cambia runtime también Playwright, seguridad y staging |
| `frontend/**` | Frontend CI; si cambia runtime también Playwright, seguridad y staging |
| `tests/e2e/**` | Playwright y staging post-deploy |
| `tests/security/**` o `scripts/security/**` | Security Testing y staging post-deploy |
| `tests/performance/**` | Staging post-deploy, que ejecuta k6 smoke |
| `infra/opentofu/**` o scripts OpenTofu | OpenTofu CI; por afectar `infra/**`, también Playwright, seguridad y staging |
| Otro `infra/**`, Docker o Compose | Playwright, seguridad y staging |
| Workflows, Jenkins o scripts de reporting | Pipeline completo para validar el cambio de CI/CD |

El job `CI Required` falla si una suite seleccionada falla o se omite, y también
si se ejecuta inesperadamente un pipeline que debía quedar fuera. De esta forma
cada PR conserva un único check obligatorio estable sin obligar a que un PR
documental levante el stack completo.

Cada artifact `test-results-*` conserva la misma ruta interna que se ve
localmente. El resumen JSON sigue
`test-results/schema/test-summary.schema.json`. `metrics.prom` puede ser leído
por un textfile collector o transformado por un job futuro antes de enviarse a
Prometheus/Grafana; este repositorio no hace push de métricas desde un PR.

Los quality gates exigen cobertura de líneas >= 90% en backend unitario,
>= 60% en integración y >= 80% en frontend; el frontend exige además
statements/functions >= 80% y branches >= 70%. Los resúmenes JSON, Markdown y
Prometheus incluyen los contadores y porcentajes de cobertura.

Playwright utiliza `list` y JUnit en CI. Los screenshots automáticos, HTML,
traces y videos se desactivan porque pueden conservar credenciales introducidas
en formularios. Antes del upload, `scripts/security/verify-artifacts.sh`
protege también la evidencia Trivy/ZAP y los logs Docker: rechaza formatos de
alto riesgo y busca los secretos configurados en texto, Base64, Basic auth,
JWT, ZIP y gzip.

### Evidencia oficial de staging

`Staging Preview` es la evidencia de despliegue oficial para el issue #86. Lo
llama `Quality Pipeline` después de `CI Required` cuando un PR afecta el sistema
desplegable, las suites post-deploy o CI/CD. Un push a `staging` siempre lo
ejecuta. Para un PR hacia `main`, el job exige que la rama origen sea
exactamente `staging`; cualquier otro origen falla el gate de promoción.

Los workflows reutilizables ejecutan antes del deploy las suites aplicables de
backend, frontend, SonarCloud, Playwright y seguridad. Después, staging valida
la instancia desplegada con:

1. integración y estado de las bases;
2. API, autenticación, Swagger, flujos principales y observabilidad;
3. E2E Playwright;
4. headers de seguridad;
5. ZAP baseline;
6. smoke de k6;
7. seguridad recursiva de la evidencia.

Las suites Gradle `apiTest` e `integrationTest` son quality gates pre-deploy. No
se deben presentar como pruebas contra la instancia desplegada; esa afirmación
corresponde a `scripts/staging/post-deploy.sh` y sus reportes black-box.

Playwright usa un modo específico para staging: reporters `list` y JUnit,
capturas PNG adjuntadas de forma explícita y allowlisted por los escenarios.
Desactiva screenshots automáticos de fallo, reporter HTML, traces y videos. Este
contrato no cambia los reporters más amplios de una ejecución E2E local o del
workflow E2E independiente.

El post-deploy recolecta evidencia antes de su séptima fase
`evidence-safety`. Después, el workflow ejecuta otra recolección con
`if: always()` y vuelve a comprobar la seguridad. El artifact se sube únicamente
si esta comprobación final da `PASS`; incluye archivos ocultos bajo
`.staging/evidence/` y se retiene 30 días. Si falla el safety, no se publica el
artifact y el resumen del job solo informa que la evidencia fue retenida.

El escaneo recorre archivos en texto o binario, rechaza symlinks, imágenes E2E
fuera del directorio controlado y artifacts Playwright de alto riesgo
(`trace.zip`, WebM y HAR), y detecta secretos en texto
plano, Base64, Basic auth y valores con forma de JWT. También inspecciona
recursivamente ZIP, gzip y payloads Base64 embebidos, con límites de tamaño,
expansión y profundidad.

El artifact no incluye `.staging/staging.env` ni el realm renderizado.
`DEPLOYED_SHA` se calcula con `git rev-parse HEAD` después del checkout, se usa
como `APP_VERSION` y forma parte del nombre
`test-results-staging-post-deploy-<DEPLOYED_SHA>-<run_attempt>`.
`deployment.json` registra ese
commit real, versión e identificadores de imagen, fingerprint de fuentes,
servicios, proyecto Compose, URLs de loopback, ciclo de vida y visibilidad.

El ambiente de Actions es `ephemeral` y `runner-private`: se destruye con sus
volúmenes después del intento condicionado de publicación. Por ello, cuando el
gate completo pasa, el enlace del run y el artifact —no una URL pública
persistente— constituyen la prueba reproducible. La operación completa está en
[`docs/deployment/staging.md`](../deployment/staging.md).

La observabilidad también está acotada al run actual. Alloy conserva únicamente
contenedores cuya label de proyecto coincide con `COMPOSE_PROJECT_NAME`. Loki
debe devolver un marcador nuevo dentro del rango temporal del check y con esa
misma label. Tempo se consulta por `service.name=inventory-backend`,
`deployment.id=STAGING_DEPLOYMENT_ID` y una traza iniciada después del comienzo
del check.

## Jenkins

El `Jenkinsfile` ejecuta checkout, build, pruebas, cobertura, análisis,
Docker Compose y E2E contra el stack levantado. Los artifacts generales incluyen
JAR, reportes Gradle, JaCoCo, frontend y auditoría de dependencias.

La evidencia Playwright se trata por separado: Jenkins no publica HTML, traces,
videos ni HAR. El JUnit E2E y la evidencia UX controlada solo se archivan
después de superar `verify-artifacts.sh`. Este preview local/académico no
sustituye `Staging Preview` como evidencia del issue #86.

## Evidencia para Pull Requests

Cada PR debe incluir:

- issue enlazado con `Closes #...`;
- comando ejecutado localmente o workflow usado, distinguiendo pre-deploy y
  post-deploy;
- resultado del job o salida relevante y SHA probado;
- nombre exacto del artifact generado;
- enlace a SonarCloud cuando aplique;
- confirmación de que no se publicaron secretos;
- revisión cruzada.

Cuando aplique staging, además debe incluir el enlace al run, el SHA de
`deployment.json`, nombre basado en ese `DEPLOYED_SHA`, ciclo de vida,
visibilidad, resultado de las siete fases, safety final `PASS` y al menos una
captura o reporte del flujo principal. La plantilla
`.github/PULL_REQUEST_TEMPLATE.md` contiene estos campos.

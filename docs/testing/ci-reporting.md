# Guía de reporting, cobertura y CI

Esta guía consolida los comandos y reportes de calidad, incluido el ambiente
validable del issue #86. Staging puede publicar diagnóstico si falla el
despliegue o una prueba post-deploy, pero solo cuando la revisión de seguridad
ejecutada después de la última recolección de evidencia da `PASS`.

## Comandos locales

| Suite | Comando | Reporte local |
|---|---|---|
| Backend build | `cd backend && ./gradlew clean assemble --no-daemon` | `backend/build/libs/*.jar` |
| Backend unit + JaCoCo | `cd backend && ./gradlew test jacocoTestReport jacocoTestCoverageVerification --no-daemon` | `backend/build/reports/tests/test/index.html`, `backend/build/reports/jacoco/test/html/index.html` |
| API RestAssured | `cd backend && ./gradlew apiTest --no-daemon` | `backend/build/reports/tests/apiTest/index.html` |
| Integration Testcontainers | `cd backend && ./gradlew integrationTest --no-daemon` | `backend/build/reports/tests/integrationTest/index.html`, `backend/build/reports/jacoco/integrationTest/html/index.html` |
| Frontend unit + coverage | `cd frontend && pnpm exec ng test --watch=false --browsers=ChromeHeadlessNoSandbox --code-coverage` | `frontend/coverage/qa-gestion-inventarios-frontend/index.html` |
| Frontend build | `cd frontend && pnpm build` | `frontend/dist/` |
| E2E Playwright | `cd tests/e2e && pnpm test` | `tests/e2e/playwright-report/index.html`, `tests/e2e/test-results/playwright-results.xml` |
| E2E contra stack existente | `cd tests/e2e && E2E_MANAGE_STACK=false pnpm exec playwright test` | `tests/e2e/playwright-report/index.html`, `tests/e2e/test-results/**` |
| Staging completo | `./scripts/staging/deploy.sh && ./scripts/staging/post-deploy.sh` | `.staging/evidence/post-deploy/summary.{md,json}` y evidencia por fase |
| Recolectar evidencia de staging | `./scripts/staging/collect-evidence.sh` | `.staging/evidence/deployment.json`, resumen, servicios, imágenes y logs redactados |

## GitHub Actions

| Workflow | Jobs principales | Artifacts |
|---|---|---|
| `Backend CI` | build, unit tests, API tests, integration tests | `backend-build-*`, `backend-unit-test-reports-*`, `backend-api-test-reports-*`, `backend-integration-test-reports-*` |
| `Frontend CI` | build Angular, unit tests con coverage | `frontend-coverage-*`, `frontend-diagnostics-*` si falla |
| `Playwright E2E` | stack Docker Compose, Playwright, diagnosticos Docker | `playwright-e2e-*` |
| `SonarCloud` | analisis de calidad y cobertura JaCoCo | Quality Gate en el PR |
| `Conventional Commits` | validacion de commits del PR | Check de formato |
| `Staging Preview` | gates backend/frontend, deploy Compose aislado y siete fases post-deploy | `staging-evidence-<DEPLOYED_SHA>-<run_attempt>`, solo con evidence safety `PASS` |

El quality gate de backend se aplica con `jacocoTestCoverageVerification` y exige cobertura de lineas >= 60%.

### Evidencia oficial de staging

`Staging Preview` es la evidencia de despliegue oficial para el issue #86. Se
activa en PR hacia `develop`, PR hacia `main`, push a `staging` y ejecución
manual cuando el workflow exista en la rama por defecto. Para un PR hacia
`main`, el job exige que la rama origen sea exactamente `staging`; cualquier
otro origen falla el gate de promoción. La ejecución manual admite un
`deploy_ref` opcional.

El pipeline ejecuta antes del deploy las suites unitarias, API MockMvc,
Testcontainers, JaCoCo y frontend. Después valida la instancia desplegada con:

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
`staging-evidence-<DEPLOYED_SHA>-<run_attempt>`. `deployment.json` registra ese
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

El `Jenkinsfile` replica el flujo visual requerido por la asignación:

- checkout, environment, backend build, unit tests, coverage gate, integration tests y API tests;
- frontend build, audit de dependencias frontend y SonarCloud;
- Docker build, deploy preview con Docker Compose y E2E Playwright contra el stack levantado;
- publicacion de JUnit, HTML de pruebas backend, HTML de JaCoCo y HTML de Playwright.

Los artifacts de Jenkins incluyen JAR backend, reportes Gradle, resultados
JUnit, cobertura JaCoCo, build frontend, audit frontend y evidencia Playwright.
Ese preview local/académico no sustituye `Staging Preview` como evidencia del
issue #86.

## Evidencia para Pull Requests

Cada PR de testing o CI debe incluir:

- issue enlazado con `Closes #...`;
- comando ejecutado localmente o workflow usado, distinguiendo pre-deploy y
  post-deploy;
- resultado del job o salida relevante y SHA probado;
- nombre exacto del artifact generado;
- enlace a SonarCloud cuando aplique;
- confirmación de que no se publicaron secretos.

Cuando aplique staging, además debe incluir el enlace al run, el SHA de
`deployment.json`, nombre basado en ese `DEPLOYED_SHA`, ciclo de vida,
visibilidad, resultado de las siete fases, safety final `PASS` y al menos una
captura o reporte del flujo principal. La plantilla
`.github/PULL_REQUEST_TEMPLATE.md` contiene estos campos.

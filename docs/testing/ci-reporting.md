# Guia de reporting, cobertura y CI

Esta guia consolida los comandos y reportes usados para el issue #45. Los jobs publican artifacts aunque una suite falle para conservar evidencia de diagnostico.

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

## GitHub Actions

| Workflow | Jobs principales | Artifacts |
|---|---|---|
| `Backend CI` | build, unit tests, API tests, integration tests | `backend-build-*`, `backend-unit-test-reports-*`, `backend-api-test-reports-*`, `backend-integration-test-reports-*` |
| `Frontend CI` | build Angular, unit tests con coverage | `frontend-coverage-*`, `frontend-diagnostics-*` si falla |
| `Playwright E2E` | stack Docker Compose, Playwright, diagnosticos Docker | `playwright-e2e-*` |
| `SonarCloud` | analisis de calidad y cobertura JaCoCo | Quality Gate en el PR |
| `Conventional Commits` | validacion de commits del PR | Check de formato |

El quality gate de backend se aplica con `jacocoTestCoverageVerification` y exige cobertura de lineas >= 60%.

## Jenkins

El `Jenkinsfile` replica el flujo visual requerido por la asignacion:

- checkout, environment, backend build, unit tests, coverage gate, integration tests y API tests;
- frontend build, audit de dependencias frontend y SonarCloud;
- Docker build, deploy preview con Docker Compose y E2E Playwright contra el stack levantado;
- publicacion de JUnit, HTML de pruebas backend, HTML de JaCoCo y HTML de Playwright.

Los artifacts de Jenkins incluyen JAR backend, reportes Gradle, resultados JUnit, cobertura JaCoCo, build frontend, audit frontend y evidencia Playwright.

## Evidencia para Pull Requests

Cada PR de testing o CI debe incluir:

- comando ejecutado localmente o workflow usado;
- resultado del job o salida relevante;
- nombre del artifact generado;
- enlace a SonarCloud cuando aplique;
- `Closes #45` solo en el PR que cierre este issue transversal.
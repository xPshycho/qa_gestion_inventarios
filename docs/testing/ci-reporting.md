# Guía de reporting, cobertura y CI

Esta guía consolida los comandos y reportes de calidad. Los artifacts de
diagnóstico solo se publican cuando su contenido es seguro.

## Comandos locales

| Suite | Comando | Reporte local |
|---|---|---|
| Backend build | `cd backend && ./gradlew clean assemble --no-daemon` | `backend/build/libs/*.jar` |
| Backend unit + JaCoCo | `cd backend && ./gradlew test jacocoTestReport jacocoTestCoverageVerification --no-daemon` | `backend/build/reports/tests/test/index.html`, `backend/build/reports/jacoco/test/html/index.html` |
| API RestAssured | `cd backend && ./gradlew apiTest --no-daemon` | `backend/build/reports/tests/apiTest/index.html` |
| Integration Testcontainers | `cd backend && ./gradlew integrationTest --no-daemon` | `backend/build/reports/tests/integrationTest/index.html`, `backend/build/reports/jacoco/integrationTest/html/index.html` |
| Frontend unit + coverage | `cd frontend && pnpm exec ng test --watch=false --browsers=ChromeHeadlessNoSandbox --code-coverage` | `frontend/coverage/qa-gestion-inventarios-frontend/index.html` |
| Frontend build | `cd frontend && pnpm build` | `frontend/dist/` |
| E2E Playwright local | `cd tests/e2e && pnpm test` | HTML y resultados locales ignorados |
| E2E contra stack existente | `cd tests/e2e && E2E_MANAGE_STACK=false pnpm exec playwright test` | CI conserva únicamente JUnit y diagnósticos verificados |

## GitHub Actions

| Workflow | Jobs principales | Artifacts |
|---|---|---|
| `Backend CI` | build, unit tests, API tests, integration tests | `backend-build-*`, `backend-unit-test-reports-*`, `backend-api-test-reports-*`, `backend-integration-test-reports-*` |
| `Frontend CI` | build Angular, unit tests con coverage | `frontend-coverage-*`, `frontend-diagnostics-*` si falla |
| `Playwright E2E` | stack Docker Compose, Playwright y safety | JUnit y diagnósticos Docker, solo después de `verify-artifacts.sh` |
| `Security Testing` | Trivy, ZAP y safety de evidencia | JSON y diagnósticos, solo después de `verify-artifacts.sh` |
| `Secret Scanning` | Gitleaks sobre PR y push | No publica artifacts ni comentarios con detecciones |
| `SonarCloud` | análisis de calidad y cobertura JaCoCo | Quality Gate en el PR |
| `Conventional Commits` | validación de commits del PR | Check de formato |

El quality gate de backend exige cobertura de líneas >= 60% mediante
`jacocoTestCoverageVerification`.

Playwright utiliza `list` y JUnit en CI. Los screenshots automáticos, HTML,
traces y videos se desactivan porque pueden conservar credenciales introducidas
en formularios. Antes del upload, `scripts/security/verify-artifacts.sh`
protege también la evidencia Trivy/ZAP y los logs Docker: rechaza formatos de
alto riesgo y busca los secretos configurados en texto, Base64, Basic auth,
JWT, ZIP y gzip.

## Jenkins

El `Jenkinsfile` ejecuta checkout, build, pruebas, cobertura, análisis,
Docker Compose y E2E. Los artifacts generales incluyen JAR, reportes Gradle,
JaCoCo, frontend y auditoría de dependencias.

La evidencia Playwright se trata por separado: Jenkins no publica HTML, traces,
videos ni HAR. El JUnit E2E solo se archiva después de superar
`verify-artifacts.sh`.

## Evidencia para Pull Requests

Cada PR debe incluir:

- issue enlazado con `Closes #...`;
- comando o workflow ejecutado;
- resultado y SHA probado;
- nombre del artifact, cuando aplique;
- enlace de SonarCloud;
- confirmación de que no se publicaron secretos;
- revisión cruzada.

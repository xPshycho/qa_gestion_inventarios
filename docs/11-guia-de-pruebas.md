# Guía de pruebas

## Estrategia

| Nivel | Herramienta | Qué protege |
|---|---|---|
| Unit backend | JUnit/Mockito | reglas, validaciones y seguridad |
| API | RestAssured | contratos, status, payloads y permisos |
| Integración | Testcontainers | PostgreSQL 16, Keycloak 26.6.3 y Flyway |
| Unit frontend | Jasmine/Karma/Chromium | componentes, auth, guards e interceptor |
| E2E | Playwright | login, CRUD, roles, stock, auditoría, a11y, responsive y browsers |
| Datos | JUnit/Testcontainers/Flyway | migraciones, seeds, relaciones y constraints PostgreSQL |
| Seguridad | headers, ZAP baseline/API activo, Trivy | configuración HTTP, API autenticada y vulnerabilidades altas/críticas |
| Rendimiento | k6 | mezcla autenticada de lecturas y thresholds |
| Staging | scripts black-box | health, API, OIDC, E2E, seguridad, observabilidad |
| Exploratoria manual | charters versionados | flujos principales, experiencia, oráculos cruzados y defectos |

## Ejecución completa

`No ejecutado como un único comando; sus suites se verificaron individualmente`

```bash
make test
```

Requisitos: raíz del repo, Docker activo y espacio para imágenes. Genera
resultados bajo `test-results/`.

## Backend

`Verificado · desde backend · Java 21`

```bash
GRADLE_USER_HOME="$PWD/.gradle" \
  ../scripts/testing/run_with_java_21.sh \
  ./gradlew clean test jacocoTestReport \
  jacocoTestCoverageVerification --no-daemon --stacktrace
```

Resultado: 125 unitarias, 0 fallos/errores/skips.

`Verificado · requiere Docker/Testcontainers`

```bash
GRADLE_USER_HOME="$PWD/.gradle" \
  ../scripts/testing/run_with_java_21.sh \
  ./gradlew apiTest integrationTest \
  jacocoIntegrationTestReport \
  jacocoIntegrationTestCoverageVerification \
  --no-daemon --stacktrace
```

Resultado: API 23/23; integración 17/17.

Reportes:
`backend/build/reports/tests/{test,apiTest,integrationTest}/index.html` y XML
en `backend/build/test-results/`.

## Frontend

`Verificado · desde la raíz · Docker`

```bash
./frontend/scripts/test-local.sh
```

Resultado: 101/101 en Chrome Headless 148. Coverage en
`frontend/coverage/qa-gestion-inventarios-frontend/index.html`.

## E2E, seguridad y rendimiento

`Verificado · raíz · stacks Compose aislados que se eliminan al terminar`

```bash
pnpm --dir tests/e2e test
./tests/performance/run-local.sh
./tests/security/run-local.sh
```

Resultados: E2E 20/20; k6 stress PASS a 100 VUs con 10,804 requests y 0 %
de errores; headers/ZAP baseline/API activo/Trivy PASS. Detalle en los
documentos 13-15 y [evidencias](22-evidencias.md).

## Pruebas de datos

`Verificado · desde backend · requiere Docker/Testcontainers`

Las pruebas de datos son parte de las 17 pruebas de integración aprobadas. No
son una inferencia basada únicamente en migraciones presentes:
`DataIntegrityIntegrationTest` fuerza violaciones de constraints y
`FlywayMigrationIntegrationTest` consulta el historial y los seeds reales del
contenedor PostgreSQL 16.

```bash
GRADLE_USER_HOME="$PWD/.gradle" \
  ../scripts/testing/run_with_java_21.sh \
  ./gradlew integrationTest \
  jacocoIntegrationTestReport \
  jacocoIntegrationTestCoverageVerification \
  --no-daemon --stacktrace
```

Resultado: 17/17, incluido el control de ocho migraciones, seeds, relaciones,
SKU único, stock no negativo, claves foráneas y delta de movimientos. Reporte:
`backend/build/reports/tests/integrationTest/index.html`. Índice persistente:
[evidencia de datos](evidence/data/README.md).

## Pruebas exploratorias

`Verificado históricamente · no reejecutado en esta auditoría`

Existe una ejecución manual versionada del 25 de julio de 2026 contra
development, commit `9efa2ab1a621d0b68d8f19d698bccca7977b2f76`:

- seis charters y seis sesiones;
- 32 artefactos: 18 PNG, 13 JSON y un log sanitizado;
- productos, stock, auditoría, seguridad, reportes y observabilidad;
- cuatro defectos reproducibles, una discrepancia de contrato y riesgos
  residuales.

El reporte fuente es
[`docs/testing/exploratory-testing.md`](testing/exploratory-testing.md) y la
[galería curada](evidence/exploratory/README.md) enlaza las capturas. Esta
evidencia demuestra la ejecución local, pero no sustituye el retest final en
staging: ese retest es **Pendiente de verificación**.

## Datos de prueba

- Realm `inventory`, users demo por rol, secrets generados localmente.
- Seed SQL de productos, catálogo de permisos/roles y usuarios operativos.
- E2E crea/actualiza/elimina productos de prueba y usa un proyecto Compose
  exclusivo.
- Los scripts llaman `down -v --remove-orphans`; no apuntar su proyecto/URLs a
  producción.

## Criterios de aprobación

- cero tests fallidos;
- unit line coverage backend >= 90 %;
- integration line coverage backend >= 60 %;
- frontend: statements >= 80, branches >= 70, functions >= 80, lines >= 80;
- k6: todos los thresholds PASS;
- ZAP: cero alertas High según script;
- Trivy: cero HIGH/CRITICAL corregibles según `--ignore-unfixed`;
- safety de artefactos antes de publicar CI.

## Pipeline

GitHub Actions selecciona suites según rutas y publica artifacts incluso ante
fallos. Jenkins es complementario y tiene brechas documentadas en
[CI/CD](16-ci-cd-jenkins.md).

## Diagnóstico

1. Abrir el HTML/JUnit de la suite.
2. Revisar `test-results/<suite>/summary.md`.
3. Revisar `evidence/docker/compose-ps.txt` y `compose.log`, sanitizando.
4. Confirmar Docker, puertos y `.env` modo 0600.
5. Repetir una sola prueba antes de reejecutar toda la suite.

Nunca interpretar “existe un test” como “aprobó”; usar timestamp/summary del
run.

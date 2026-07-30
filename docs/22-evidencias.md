# Evidencias

## Dónde consultar los resultados

| Resultado | Entorno | Herramienta | Ubicación | Método de acceso | Retención |
|---|---|---|---|---|---|
| Unit backend | local | JUnit | `backend/build/reports/tests/test/` | `index.html` | hasta `clean` |
| API | local | RestAssured/JUnit | `backend/build/reports/tests/apiTest/` | `index.html` | hasta `clean` |
| Integración | local | Testcontainers/JUnit | `backend/build/reports/tests/integrationTest/` | `index.html` | hasta `clean` |
| Datos | local | JUnit/Testcontainers/Flyway | `backend/build/reports/tests/integrationTest/` | HTML/XML + [índice](evidence/data/README.md) | hasta `clean` |
| Coverage backend | local | JaCoCo | `backend/build/reports/jacoco/` | HTML/XML | hasta `clean` |
| Frontend unit/coverage | local | Karma | `frontend/coverage/.../index.html` | navegador | siguiente run/limpieza |
| E2E | local | Playwright | `test-results/e2e/playwright/` | summary/JUnit/screenshots | siguiente reset/limpieza |
| Exploratoria | development 25-07-2026 | charters/manual | `docs/testing/evidence/exploratory/2026-07-25/` | [reporte y galería](evidence/exploratory/README.md) | versionada en Git |
| ZAP | local | OWASP ZAP | `test-results/security/zap/` | JSON/Markdown | siguiente reset |
| Trivy | local | Trivy | `test-results/security/trivy/` | JSON | siguiente reset |
| Rendimiento | local | k6 | `test-results/performance/k6/` | JSON/Markdown | siguiente reset |
| Pipeline | Jenkins | Jenkins | build -> Test/HTML/Artifacts | UI Jenkins | 20 builds/10 artifacts |
| Quality `main` | GitHub | Actions | [run 30499884455](https://github.com/xPshycho/qa_gestion_inventarios/actions/runs/30499884455) | run -> Artifacts | observada hasta 12-08-2026 |
| Quality `staging` | GitHub | Actions | [run 30498677524](https://github.com/xPshycho/qa_gestion_inventarios/actions/runs/30498677524) | run -> Artifacts | observada hasta 12-08-2026 |
| Deploy producción | GitHub/GCP | Actions | [run 30500093137](https://github.com/xPshycho/qa_gestion_inventarios/actions/runs/30500093137) | run -> artifact `production-evidence-*` | observada hasta 28-08-2026 |
| OpenTofu offline | GitHub | OpenTofu CI | [run 30499884455](https://github.com/xPshycho/qa_gestion_inventarios/actions/runs/30499884455) -> job OpenTofu | log: fmt/validate/tests simulados | retención del run |
| OpenTofu state | GCP | backend GCS | bucket `project-e70349a8-c787-4733-9a0-opentofu-state` | IAM + generaciones GCS; [runbook](27-guia-operativa-gcp-opentofu.md#recuperación-del-state) | versionado/soft delete observado |
| Swagger/OpenAPI | producción | Springdoc | `https://34.123.136.144/api/v3/api-docs` | curl/JSON + [evidencia](evidence/deployment/swagger-keycloak-flujos.md) | endpoint vigente; reconfirmar |
| Keycloak/OIDC | producción | Keycloak | `https://34.123.136.144/auth/realms/inventory/.well-known/openid-configuration` | curl/JSON + [evidencia](evidence/deployment/swagger-keycloak-flujos.md) | endpoint vigente; reconfirmar |
| Métricas | dev/staging | Prometheus | puertos 9090/19090 | UI/API | volumen/config efectiva |
| Dashboards | dev/staging | Grafana | puertos 3000/13000 | UI autenticada | volumen/config efectiva |
| Logs/traces | dev/staging | Loki/Tempo | vía Grafana o API | UI/API privada | config efectiva |
| Producción | GCP | Logging/Ops Agent | Logs Explorer | IAM | Default 30d/Required 400d |

Los tres runs GitHub anteriores se abrieron mediante la API pública y sus
artifacts se enumeraron sin descargarlos. Jenkins continúa **Pendiente de
verificación** porque no se proporcionó un servidor/run consultable.

## Ejecuciones de esta auditoría

| Suite | Comando | Resultado |
|---|---|---|
| Backend unit | Gradle `clean test jacoco...` | 125/125, coverage gate PASS |
| Backend API | Gradle `apiTest` | 22/22 |
| Backend integración | Gradle `integrationTest jacoco...` | 17/17, gate PASS |
| Datos | mismas 17 pruebas de integración | migraciones, seeds, relaciones y constraints PASS |
| Frontend | `./frontend/scripts/test-local.sh` | 101/101, gates PASS |
| E2E | `pnpm --dir tests/e2e test` | 20/20 |
| k6 | `./tests/performance/run-local.sh` | smoke thresholds PASS |
| Headers/ZAP/Trivy | `./tests/security/run-local.sh` | PASS/PASS/PASS |
| Exploratoria | inspección del reporte/32 artifacts versionados | evidencia histórica completa; retest staging pendiente |
| HTTPS producción | curl/OpenSSL | frontend, health y OIDC UP; TLS vence 2026-08-04 |
| Cloud Run | curl | 200/UP tras cold start |
| OpenAPI producción | curl + jq | OpenAPI 3.0.1, 18 rutas, `bearer-jwt` |

Fecha UTC de summaries locales: 30 de julio de 2026.

## Índices por categoría

- [Coverage](evidence/coverage/README.md)
- [Datos](evidence/data/README.md)
- [E2E](evidence/e2e/README.md)
- [Exploratoria](evidence/exploratory/README.md)
- [ZAP/seguridad](evidence/zap/README.md)
- [k6](evidence/k6/README.md)
- [Pipeline](evidence/pipeline/README.md)
- [Observabilidad](evidence/observability/README.md)
- [Deployment](evidence/deployment/README.md)
- [Rollback](evidence/rollback/README.md)

Los diez READMEs de evidencia son persistentes y sanitizados. Los reportes nativos
pueden estar ignorados/regenerarse; cada índice explica comando, fecha,
resultado, interpretación, requisito y limitaciones.

## Evidencia GCP

La auditoría usó consultas `gcloud --project` sin cambiar la configuración
global. Resultados consolidados en
[Infraestructura GCP](03-infraestructura-gcp.md). No se guardaron dumps de IAM
con correos humanos ni valores de secretos.

## Integridad y seguridad

- Fuentes `proyecto_final`: movidas sin cambiar nombre/contenido; hashes
  pre/post coincidentes durante la operación.
- E2E/seguridad: scripts ejecutan safety antes de publicar CI.
- Capturas: revisar nuevamente antes de hacer commit; pueden contener nombres
  demo, pero no passwords/tokens.
- Logs: sanitizar Authorization, cookies, JWT, `.env`, URLs con credenciales y
  datos personales.

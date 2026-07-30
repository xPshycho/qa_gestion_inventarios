# Trazabilidad de entregables

## Fuentes auditadas

La fuente normativa principal es
`proyecto_final_division_edwin_carlos_2.pdf`; avances, divisiones, preguntas y
reportes históricos fueron consultados durante la auditoría. Esos archivos no
forman parte de este commit por la exclusión expresa de reportes
preexistentes y la ruta `docs/referencias/proyecto-final/` no existe en el
checkout actual. Su disponibilidad después de clonar es **Pendiente de
verificación**.

## Inventario e integridad de fuentes

| Archivo preservado | SHA-256 |
|---|---|
| `avance_proyecto.md` | `ca6340315baa142549e783ff16bd2da890c54c8989cff1b71ee24f9a0a0c7977` |
| `informe-defensa.md` | `c76a2057124d90194103144e96288e21e1dbf6d700b9e8de2f2909123be92973` |
| `issues-dependency-report.md` | `9126beb32c411c59fc38abe6b24346620fbd58613085c0eaf674357e8817e16a` |
| `preguntas_freuentes.md` | `572d424f2a23e9cdf29b0e615291f2e488e217fed0c4efe813443619f4ed1124` |
| `proyecto_final_division.md` | `ac3e1cadfe715a177ee084b292a1f7a5ec81225916b6d339b0c72965f9dcfb11` |
| `proyecto_final_division_edwin_carlos_2.pdf` | `054db933d9aea60274741164798d30d45e139c76b1580983135e444d16366cec` |
| `proyecto_final_v3.md` | `8f03f8f30a2465590a8a993e69ef0ad90ce43044ad1565dfb0b22b91794027bd` |
| `puertos_desplegados.md` | `ba123a2beea31a784fd7c5bf6cf93dc499bf1159f82766ee99c0e0105cea3faf` |
| `reporte-verificacion-avance-2026-06-18-v2.md` | `9e8961fbd5d9fc3a6de2e7bae76390bcbcf277f0edeced0127afe7dee225a023` |
| `reporte-verificacion-avance-2026-06-18.md` | `3862d17ee60d53205e685c975d998f4e6c96f62c5d94a87e5d119722e61555ab` |
| `reporte-verificacion-avance.md` | `d1ab8196aed5acd9dfc785cf9b0ac1bd5fc1206d7d79ee64a8321dfe8f810e94` |
| `reporte-verificacion-final-issue-86-staging-2026-07-27.md` | `a1c9b3618246e86b9d6f6e34c0d5a653c95224ed37b9e379d43a6986e5213acc` |
| `reporte-verificacion-issue-86-staging.md` | `fa81106692cac7567c4faae67dc355ee99dabe9d65b601276e786ef9c70f1fbb` |
| `respuestas-preguntas-frecuentes-defensa.md` | `977751d6d2fecea5b95cb4dc7174881be86f028d1731b2c634d58be62fdcc79b` |

Los hashes se registraron durante la auditoría previa. Como los archivos
fuente no forman parte de este commit, el receptor debe volver a verificarlos
con `sha256sum <ARCHIVO>` cuando reciba el paquete externo.

## Procedencia del PDF citado por el issue

Durante la auditoría previa se inspeccionó un PDF en:
`docs/referencias/proyecto-final/proyecto_final_division_edwin_carlos_2.pdf`,
11 páginas, SHA-256
`054db933d9aea60274741164798d30d45e139c76b1580983135e444d16366cec`.
El checkout actual no contiene archivos PDF y el archivo llamado exactamente
`document_pdf (1).pdf` tampoco está presente.

El PDF preservado contiene los capítulos de alcance funcional, permisos,
seguridad, arquitectura, full stack testing, ambientes, observabilidad,
calidad, CI/CD, documentación y presentación que esta matriz cubre. La
equivalencia de procedencia entre ambos nombres es **Pendiente de
verificación**: debe compararse el hash del archivo original
`document_pdf (1).pdf` con el hash anterior. No se renombró ni recreó un PDF
sin esa evidencia.

Estados: `Completo`, `Parcial`, `No encontrado`, `Pendiente de validación`,
`No aplica`.

## Matriz exacta del issue #91

| Requisito del issue | Fuente | Implementación | Prueba/validación | Evidencia | Documento | Estado |
|---|---|---|---|---|---|---|
| Matriz requisito → implementación → prueba → evidencia | alcance del issue | esta tabla y matriz por capítulos | revisión de rutas y enlaces relativos | fuentes con SHA + índices `docs/evidence/` | 25 | Completo |
| Instalación, local, staging y troubleshooting consolidados | issue + PDF: Entornos/Documentación | `docker-compose*.yml`, `scripts/staging/`, `.env*.example` | suites locales, scripts inspeccionados y GCP read-only | resultados centralizados + reporte histórico #86 | 04, 05, 19, 21 | Completo |
| Arquitectura final backend/frontend/seguridad/datos/infra/CI/observabilidad | issue + PDF: Arquitectura/Observabilidad/CI | `backend/`, `frontend/`, `infra/`, workflows y `Jenkinsfile` | build/tests, inspección de configuración y snapshot GCP | ocho diagramas Mermaid + inventario GCP; límites declarados | 02, 03, 06, 08, 16, 17 | Completo |
| Consolidar unit, integration, API, E2E, performance, security, data y exploratory | issue + PDF: Full Stack Testing | suites bajo `backend/src/{test,apiTest,integrationTest}`, `frontend/src`, `tests/` y charters | 125 unit backend, 22 API, 17 integration/data, 101 frontend, 20 E2E, k6/ZAP/Trivy; reporte exploratorio inspeccionado | índices coverage/data/E2E/exploratory/ZAP/k6; load/stress, ZAP activo y retest staging visibles | 11-15, 22 | Completo |
| Evidencias de pipeline, dashboards, Swagger, Keycloak, reportes y flujos | issue + PDF: API/Seguridad/Observabilidad/CI | workflows, dashboard JSON, `OpenApiConfig`, realm, diagramas | GitHub API pública, curls OpenAPI/OIDC, evidencia exploratoria versionada | runs 30499884455, 30498677524, 30500093137; capturas y JSON; Jenkins remoto/VM pendientes | 16, 17, 22 | Completo |
| Corregir documentación desactualizada o contradictoria | criterio del issue | portal canónico 00-27; banner histórico; estado de producción de datos corregido | `rg` de contradicciones, enlaces, `git diff --check` y safety documental | esta matriz y checklist final | 00, 22, 25-27 | Completo |
| Checklist de entrega y presentación funcional | issue + PDF: Documentación/Presentación | presentación de 23 diapositivas y guion reproducible | revisión de cobertura del guion contra resultados y rutas | presentación, script y checklist | 23, 24, 26 | Completo |
| Cubrir capítulos relevantes del PDF | criterio de aceptación | docs 01-25 especializados | extracción/lectura del único PDF preservado y cruce por capítulo | hash, inventario y matriz siguiente; nombre `document_pdf (1).pdf` pendiente de procedencia | 00, 25 | Parcial |
| No presentar componentes ausentes como entregados | criterio de aceptación | estados `Parcial`/`Pendiente` en documentos canónicos | búsqueda de afirmaciones contradictorias | brechas ZAP activo, load/stress, Jenkins remoto, restore, producción interna | 03, 14-22, 26 | Completo |
| Evidencias enlazadas o en rutas documentadas | criterio de aceptación | diez índices de evidencia y tabla central | validador de enlaces relativos | `docs/evidence/`, artifacts GitHub y evidencias exploratorias | 22 | Completo |
| README y docs consistentes con estado real | criterio de aceptación | README enlaza índice, evidencia y matriz | comprobación de enlaces/estados finales | README + checklist | README, 00, 26 | Completo |

## Trazabilidad por capítulo y entregable

| Requisito | Fuente | Evidencia repo/ejecución | Documento generado | Estado |
|---|---|---|---|---|
| README definitivo | PDF/avance/issue #91 | `README.md` | README + 00 | Completo |
| Descripción/alcance | PDF | controllers/módulos | 01 | Completo |
| Arquitectura moderna | PDF | módulos, Compose, GCP | 02 + diagramas | Completo |
| CRUD productos | PDF | ProductController/E2E CRUD | 01/07 | Completo |
| Stock/historial | PDF | StockService/E2E stock | 01/07 | Completo |
| Auditoría Envers | PDF | V6-V7/AuditController/E2E | 01/06/07 | Completo |
| API OpenAPI/Swagger | PDF | OpenAPI producción 3.0.1, 18 rutas, `bearer-jwt`; `OpenApiConfig` | 07/22 | Completo |
| UI/dashboard/usabilidad | PDF | Angular/E2E responsive/a11y | 13/23/24 | Completo |
| Seguridad granular | PDF | 7 permisos/4 roles/SecurityConfig | 08/09 | Completo |
| JWT/OAuth2/Keycloak | PDF/preguntas | realm + auth code | 08 | Completo |
| Refresh/expiración | PDF | `AuthService.updateToken`, realm lifespan | 08 | Completo |
| Scopes/policies | PDF | claims y reglas Spring; policies históricas | 08/09 | Parcial |
| Unit backend | PDF/avance | 125/125, JaCoCo | 11/12/22 | Completo |
| Unit frontend | PDF | 101/101, Karma coverage | 11/12/22 | Completo |
| Integración Testcontainers | PDF | 17/17, PostgreSQL/Keycloak | 11/12 | Completo |
| API/contract | PDF | 22/22 RestAssured/OpenAPI | 07/11 | Completo |
| E2E Playwright | PDF | 20/20, browsers/responsive | 13 | Completo |
| Security testing | PDF | headers/ZAP/Trivy | 14 | Parcial |
| Performance | PDF | k6 smoke PASS | 15 | Parcial |
| Data testing | PDF | 17/17 integración; Flyway, seeds, relaciones y constraints | 06/11/22 | Completo |
| Exploratory manual | PDF | 6 charters, 6 sesiones y 32 artifacts del 25-07-2026 | testing + 11/22 | Parcial |
| Development | PDF | Compose ejecutado | 04/05 | Completo |
| Preview/staging | PDF/issue #86 | scripts y evidencia histórica 7 fases | 19 | Completo |
| Producción | PDF | VM HTTPS/health GCP | 03/19 | Parcial |
| CI/CD | PDF | Actions runs `main`/`staging` PASS; deploy producción PASS; Jenkinsfile | 16/22 | Parcial |
| Publicación de reportes | issue #91 | artifacts remotos Actions y rutas Jenkins versionadas | 16/22 | Parcial |
| Observabilidad completa | PDF | stack versionado; findings dashboard | 17 | Parcial |
| Logs/métricas/trazas | PDF | Alloy/Prom/Loki/Tempo | 17 | Parcial |
| Backup/rollback | PDF | snapshots/scripts; restore no probado | 20 | Parcial |
| Infra GCP | issue #91/solicitud | inventario live read-only | 03 | Completo |
| Operación GCP/OpenTofu | issue #109 | plan PR aprobado, jobs deploy development/staging, roots, Environments y dependencias auditados | 27 | Parcial por apply `skipped`, aprobación staging y drills pendientes |
| Matriz permisos | PDF | realm/SQL/SecurityConfig/tests | 09 | Completo |
| Usuarios/accesos | solicitud | realm/IAM/secret stores | 10 | Completo |
| Troubleshooting | issue #91 | hallazgos y runbooks | 21 | Completo |
| Dónde ver resultados | solicitud | rutas/retención | 22 | Completo |
| Presentación | PDF/issue #91 | 23 diapositivas con notas | 23 | Completo |
| Demostración | issue #91 | guion reproducible | 24 | Completo |
| Trazabilidad | issue #91 | esta matriz | 25 | Completo |

## Justificación de parciales

- Scopes/policies: los permisos viajan como claim/scope, pero Authorization
  Services contiene rutas históricas y el enforcement real es Spring.
- Security: ZAP no es activo/autenticado.
- Performance: solo smoke auditado; load/stress/soak pendientes.
- Producción: superficie pública/GCP verificada, interior VM sin OS Login y
  certificado próximo a vencimiento.
- Exploratoria: ejecución local y 32 artefactos completos; retest final en
  staging pendiente.
- CI/reportes: GitHub Actions y artifacts remotos fueron verificados; Jenkins
  remoto continúa pendiente.
- Observabilidad: stack existe, pero hay queries inconsistentes y producción
  interna pendiente.
- Rollback: scripts/snapshot existen; no se ejecutó restore Cloud SQL ni
  rollback productivo por seguridad.

## Requisitos no encontrados/no aplicables

- Colección Postman: no encontrada; OpenAPI cumple como contrato importable.
- Rate limiting: no encontrado; no se marca No aplica porque una API externa
  puede requerirlo.
- GKE/Cloud DNS/Load Balancer: no aplican al despliegue observado; APIs
  GKE/DNS deshabilitadas y la VM sirve por IP.
- Microservicios: no aplica; la decisión real es monolito modular.

## Hallazgos históricos

Los reportes de avance contienen cifras/estados anteriores que no deben
presentarse como actuales. Esta documentación usa resultados del 30 de julio
UTC y referencia las fuentes históricas solo como trazabilidad.

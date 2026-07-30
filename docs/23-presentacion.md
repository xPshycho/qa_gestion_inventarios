# Presentación técnica final

Formato sugerido: 23 diapositivas, 24-28 minutos más preguntas. Cada evidencia
debe abrirse desde el repositorio o entorno; no mostrar `.env`, tokens,
passwords, cookies ni consola de Secret Manager con valores.

## Diapositivas

### 1. Problema — 1 min

Objetivo: explicar la necesidad.\
Contenido: inventario requiere consistencia, trazabilidad, control granular y
operación observable.\
Evidencia: [descripción](01-descripcion-del-proyecto.md).\
Notas: diferenciar “CRUD” de una entrega empresarial mantenible.

### 2. Solución — 1 min

Objetivo: resumir el producto.\
Contenido: Angular + Spring + PostgreSQL + Keycloak + QA/DevSecOps.\
Evidencia: README y aplicación.\
Notas: una frase por capa.

### 3. Alcance — 1 min

Objetivo: fijar qué está implementado.\
Contenido: productos, stock, reportes, auditoría, seguridad, API.\
Evidencia: controllers referidos en documento 01.\
Notas: declarar rate limiting y active ZAP como brechas.

### 4. Arquitectura — 1.5 min

Objetivo: explicar el monolito modular.\
Contenido: límites y flujo de datos.\
Evidencia: [arquitectura general](diagrams/arquitectura-general.md).\
Notas: justificar simplicidad operativa frente a microservicios.

### 5. Tecnologías — 1 min

Objetivo: mostrar toolchain reproducible.\
Contenido: versiones verificadas de Java/Spring/Angular/Keycloak/PostgreSQL y
testing.\
Evidencia: manifests y [descripción](01-descripcion-del-proyecto.md).\
Notas: enfatizar digests y pnpm fijado.

### 6. Infraestructura GCP — 2 min

Objetivo: separar estado observado y objetivo OpenTofu.\
Contenido: VM producción, Cloud Run dev, SQL pública y dos SQL privadas,
redes, secrets, registry, WIF.\
Evidencia: [GCP](03-infraestructura-gcp.md) y [red](diagrams/red-gcp.md).\
Notas: explicar que las privadas pasaron de creación a `RUNNABLE`, pero aún no
había servicios Cloud Run consumidores observados.

### 7. Modelo de seguridad — 1 min

Objetivo: mostrar límites de confianza.\
Contenido: OIDC/OAuth2, Bearer stateless, CORS y permisos atómicos.\
Evidencia: `SecurityConfig:47-118`.\
Notas: backend es enforcement; UI solo experiencia.

### 8. JWT y Keycloak — 1.5 min

Objetivo: explicar firma/validación/refresh.\
Contenido: PKCE S256, token 300 s, refresh 60 s antes, JWK/issuer.\
Evidencia: [flujo auth](diagrams/flujo-autenticacion.md).\
Notas: Keycloak firma; backend no posee clave privada.

### 9. Roles y permisos — 1 min

Objetivo: demostrar granularidad.\
Contenido: cuatro roles, siete permisos.\
Evidencia: [matriz](09-matriz-de-permisos.md).\
Notas: mostrar una denegación 403.

### 10. API externa — 1 min

Objetivo: consumir sin GUI.\
Contenido: OpenAPI, Bearer, paginación y errores.\
Evidencia: Swagger y [curl](07-api.md).\
Notas: no hay `/v1` ni rate limiting.

### 11. Estrategia de pruebas — 1 min

Objetivo: mostrar pirámide/gates.\
Contenido: unit, API, integración, frontend, E2E, seguridad, rendimiento,
manual/datos.\
Evidencia: [guía](11-guia-de-pruebas.md).\
Notas: existencia no equivale a ejecución; citar fecha.

### 12. Coverage — 1 min

Objetivo: mostrar medición real.\
Contenido: backend unit 90.97 % líneas, integración 60.52 %, frontend 83.63 %.\
Evidencia: [coverage](12-coverage.md).\
Notas: branch integración 33.12 % es una brecha.

### 13. E2E — 1 min

Objetivo: demostrar flujos reales.\
Contenido: 20/20, tres motores, tres viewports, WCAG/teclado.\
Evidencia: JUnit/screenshots en `test-results/e2e/playwright`.\
Notas: safe reporting evita tokens.

### 14. ZAP/Trivy — 1 min

Objetivo: comunicar resultado y límite.\
Contenido: ZAP cero High, cinco Warning; Trivy cero High/Critical corregible.\
Evidencia: [seguridad](14-seguridad-zap.md).\
Notas: baseline pasivo/no autenticado, no active scan.

### 15. k6 — 1 min

Objetivo: interpretar, no sobredimensionar.\
Contenido: smoke 31 requests, 0 % errores, p95 127.58 ms, thresholds PASS.\
Evidencia: [k6](15-rendimiento-k6.md).\
Notas: no es capacidad productiva.

### 16. CI/CD — 1.5 min

Objetivo: explicar selección y gates.\
Contenido: Actions principal; Jenkins complementario; WIF a GCP.\
Evidencia: [CI/CD](16-ci-cd-jenkins.md), [diagrama](diagrams/ci-cd.md).\
Notas: exponer brechas Jenkins, no ocultarlas.

### 17. Reportes del pipeline — 1 min

Objetivo: responder “¿dónde lo veo?”.\
Contenido: runs Actions `main`/`staging`, JUnit, HTML, JaCoCo, summaries,
artifacts y retención.\
Evidencia: [tabla central](22-evidencias.md#dónde-consultar-los-resultados).\
Notas: abrir el run 30499884455 y sus artifacts; la ejecución remota pendiente
es Jenkins, no GitHub Actions.

### 18. Observabilidad — 1.5 min

Objetivo: explicar métricas/logs/trazas.\
Contenido: Prometheus/Grafana/Loki/Tempo/Alloy/Alertmanager.\
Evidencia: [observabilidad](17-observabilidad.md).\
Notas: mostrar queries correctas y brechas de dashboard.

### 19. Despliegue — 1 min

Objetivo: describir staging -> producción por SHA.\
Contenido: prechecks, secret stores, smoke.\
Evidencia: [ambientes](19-staging-produccion.md).\
Notas: producción actual es VM, no Cloud Run.

### 20. Rollback — 1 min

Objetivo: demostrar recuperabilidad.\
Contenido: release anterior, backup, script, validación y contingencia.\
Evidencia: [rollback](20-backup-y-rollback.md).\
Notas: simulación staging histórica; restore Cloud SQL pendiente.

### 21. Riesgos — 1.5 min

Objetivo: mostrar criterio técnico.\
Contenido: audiencia JWT, direct grants, WIF cross-env, TLS corto, restore
drill, alerts GCP, findings F-01..F-05.\
Evidencia: docs 01/03/08/17.\
Notas: priorizar por impacto y no prometer correcciones no realizadas.

### 22. Demostración — 1 min de introducción

Objetivo: preparar el flujo en vivo.\
Contenido: health, login, producto/stock, API, permiso, test, reportes,
observabilidad.\
Evidencia: [guion](24-script-demostracion.md).\
Notas: usar entorno local/staging y plan B de screenshots.

### 23. Conclusiones — 1 min

Objetivo: cerrar con evidencia.\
Contenido: sistema reproducible, gates aprobados, producción observable
externamente y pendientes explícitos.\
Evidencia: [estado #91](26-cierre-issue-91.md).\
Notas: el issue permanece abierto y sin modificar por instrucción del usuario.

## Material de respaldo

- capturas sanitizadas E2E;
- [galería exploratoria sanitizada](evidence/exploratory/README.md);
- summaries JSON/Markdown;
- Mermaid del repositorio;
- [OpenAPI/OIDC verificados](evidence/deployment/swagger-keycloak-flujos.md);
- [runs y artifacts del pipeline](evidence/pipeline/README.md);
- inventario GCP sin IAM humano/secret values;
- plan B: video/capturas sin sesión autenticada.

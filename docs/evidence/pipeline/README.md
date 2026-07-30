# Evidencia de pipeline

Consulta pública de solo lectura realizada el 29 de julio de 2026. No se
reintentó, aprobó ni modificó ningún run.

## Quality Pipeline en `main`

| Campo | Valor verificado |
|---|---|
| Run | [30499884455](https://github.com/xPshycho/qa_gestion_inventarios/actions/runs/30499884455) |
| Workflow | `Quality Pipeline` |
| Rama / SHA | `main` / `0cfbd7ba37be6b5e1b87d9c45d6003ae98481251` |
| Ejecución | 29 de julio de 2026, 23:32:59-23:36:54 UTC |
| Resultado | `completed / success` |

Jobs aprobados: selección, Gitleaks, SonarCloud, build backend, unit backend y
coverage, integración y coverage, API, frontend build/unit, Playwright, escaneo
de dependencias/configuración/imágenes, OWASP ZAP, OpenTofu y `CI Required`.
`Staging after CI` fue omitido en este run; no se interpreta como un staging
ejecutado.

Artefactos observados y no expirados al consultar:

| Artefacto | Tamaño observado | Expira |
|---|---:|---|
| `test-results-security-zap-45` | 45,535 bytes | 12-08-2026 |
| `test-results-e2e-playwright-45` | 6,004,189 bytes | 12-08-2026 |
| `test-results-backend-integration-45` | 577,807 bytes | 12-08-2026 |
| `test-results-security-trivy-45` | 49,938 bytes | 12-08-2026 |
| `test-results-backend-unit-45` | 478,303 bytes | 12-08-2026 |
| `test-results-backend-api-45` | 61,935 bytes | 12-08-2026 |
| `test-results-frontend-unit-45` | 93,617 bytes | 12-08-2026 |
| `backend-build-45` | 69,972,804 bytes | 12-08-2026 |

Método de acceso: abrir el run, sección **Artifacts**, mientras no haya
expirado. Los tamaños confirman la existencia del paquete, no sustituyen la
lectura de sus reportes.

## Quality Pipeline en `staging`

| Campo | Valor verificado |
|---|---|
| Run | [30498677524](https://github.com/xPshycho/qa_gestion_inventarios/actions/runs/30498677524) |
| Workflow | `Quality Pipeline` |
| Rama / SHA | `staging` / `62e1433b087e94fa2d53a6bd63b8c35bbf7781bf` |
| Inicio | 29 de julio de 2026, 23:10 UTC |
| Resultado | `completed / success`; `CI Required` aprobado |

Aprobaron las mismas suites principales de calidad: backend unit/integration/API,
frontend unit, Playwright, Gitleaks, SonarCloud, Trivy/configuración/imagen, ZAP
y OpenTofu. El job `Staging after CI` figura `skipped`; por tanto este run
prueba calidad sobre la rama, no un deployment de staging.

Artefactos observados: `test-results-security-zap-43`,
`test-results-e2e-playwright-43`, `test-results-backend-integration-43`,
`test-results-security-trivy-43`, `test-results-backend-unit-43`,
`test-results-backend-api-43`, `test-results-frontend-unit-43` y
`backend-build-43`. Expiración observada: 12 de agosto de 2026. La API devolvió
tres entradas repetidas para `test-results-backend-unit-43`; se registra la
duplicidad sin inferir tres ejecuciones distintas.

## Deployment de producción

| Campo | Valor verificado |
|---|---|
| Run | [30500093137](https://github.com/xPshycho/qa_gestion_inventarios/actions/runs/30500093137) |
| Workflow | `GCP Production Deploy` |
| Rama / SHA | `main` / `0cfbd7ba37be6b5e1b87d9c45d6003ae98481251` |
| Job | `Deploy and validate production` |
| Resultado | `completed / success` |
| Artefacto | `production-evidence-0cfbd7ba37be6b5e1b87d9c45d6003ae98481251-1`, 116,574 bytes |
| Expira | 28 de agosto de 2026 |

## Jenkins

La definición y las rutas de publicación existen en `Jenkinsfile`; no se
proporcionó una URL ni credencial de un servidor Jenkins. Una ejecución remota
de Jenkins continúa **Pendiente de verificación**. Esto no invalida la
evidencia real de GitHub Actions, que es el pipeline principal observado.

## Reproducción de la consulta

`Verificado · solo lectura · requiere red`

```bash
curl --fail --silent --show-error \
  'https://api.github.com/repos/xPshycho/qa_gestion_inventarios/actions/runs/30499884455/jobs?per_page=100'

curl --fail --silent --show-error \
  'https://api.github.com/repos/xPshycho/qa_gestion_inventarios/actions/runs/30499884455/artifacts?per_page=100'
```

No se descargaron artefactos ni se almacenaron tokens. Requisito cubierto:
ejecución CI/CD, publicación y ubicación de reportes.

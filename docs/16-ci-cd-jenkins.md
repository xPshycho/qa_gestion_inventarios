# CI/CD y Jenkins

## Pipelines existentes

GitHub Actions es el pipeline principal: clasifica cambios, ejecuta suites por
área, aplica required gate, valida staging cuando corresponde y usa WIF para
GCP. Jenkins ofrece un pipeline complementario local/administrado.

Archivos fuente:

- `.github/workflows/quality-pipeline.yml` y workflows especializados;
- `.github/workflows/staging-preview.yml`;
- `.github/workflows/gcp-production-deploy.yml`;
- `Jenkinsfile`;
- `compose.jenkins.yml`, `infra/jenkins/jenkins.yaml`.

## Jenkinsfile

Ruta: `Jenkinsfile`\
Líneas aproximadas: 1-338\
Componente: Declarative Pipeline\
Responsabilidad: checkout confiable, toolchain, backend, seguridad básica,
imágenes, preview, Playwright, publicación y cleanup.

### Trigger, agent y retención

- agent label: `linux && docker`;
- branch parametrizable, default `develop`;
- Sonar opcional;
- rechaza fork PR con Docker/secretos;
- no permite builds concurrentes;
- conserva 20 builds y artifacts de 10 builds;
- el trigger concreto depende de la configuración del job; no hay `triggers`
  en el Jenkinsfile.

### Stages

1. Checkout.
2. Trusted Pipeline Guard.
3. Environment.
4. Backend Build.
5. Unit Tests + Coverage Gate.
6. Integration Tests.
7. API Tests.
8. Frontend Build.
9. Security Scan: `pnpm audit` y Sonar opcional.
10. Docker Build.
11. Deploy Preview.
12. E2E Playwright.

### Publicación

| Resultado | Publicación Jenkins | Retención |
|---|---|---:|
| JUnit backend | acción JUnit del build | 20 builds |
| Tests backend HTML | links `Unit/Integration/API Test Report` | `keepAll`, sujeto a 20 builds |
| JaCoCo unit/integración | links HTML | sujeto a 20 builds |
| JUnit E2E | acción JUnit | 20 builds |
| E2E seguro | archive tras `verify-artifacts.sh` | 10 builds |
| JAR/frontend/dist/audit/resúmenes | archiveArtifacts | 10 builds |

Desde Jenkins: abrir job -> build -> `Test Result`, el enlace HTML nombrado o
`Artifacts`.

### Comportamiento ante fallo

El bloque `post always` intenta publicar reportes, recolectar resultados,
ejecutar safety, bajar el proyecto Compose con volúmenes y limpiar workspace.
`pnpm audit` puede marcar `UNSTABLE`; el safety E2E fallido marca el build
`FAILURE` y retiene la evidencia.

## Brechas Jenkins verificadas en código

No se cambió el pipeline por instrucción de “solo documentación”.

| Brecha | Impacto |
|---|---|
| No ejecuta unit/coverage frontend; registra estado `unknown`. | No hay gate frontend en Jenkins. |
| Integration stage no invoca explícitamente `jacocoIntegrationTestCoverageVerification`. | El gate 60 % no está garantizado por ese stage. |
| No ejecuta ZAP, Trivy, headers ni k6. | Seguridad/rendimiento dependen de Actions/local. |
| No publica HTML Playwright; usa evidencia segura/JUnit. | Correcto por seguridad, pero debe explicarse. |
| `suiteStatus` usa el resultado global para varias suites. | Puede atribuir un fallo tardío a suites que aprobaron. |
| No se verificó un servidor/run Jenkins real. | Estado operativo remoto pendiente. |

## Operación local Jenkins

`No verificado en esta auditoría · Requiere Docker`

```bash
./scripts/security/init-secret-env.sh jenkins
docker compose --env-file .env.jenkins \
  -p inventory-jenkins \
  -f compose.jenkins.yml \
  up -d --build --wait
curl --fail http://localhost:18080/login
```

Password: `.env.jenkins` privado. No imprimirlo.

```bash
docker compose --env-file .env.jenkins \
  -p inventory-jenkins \
  -f compose.jenkins.yml ps
docker compose --env-file .env.jenkins \
  -p inventory-jenkins \
  -f compose.jenkins.yml logs --tail=200 jenkins
```

`Destructivo local: elimina Jenkins y su estado`

```bash
# Respaldar JENKINS_HOME/volumen antes.
docker compose --env-file .env.jenkins \
  -p inventory-jenkins \
  -f compose.jenkins.yml down -v
```

Alternativa segura: omitir `-v`.

## GitHub Actions

Los artifacts usan nombres `test-results-<suite>-*`; staging conserva su
evidencia según el `retention-days` de cada workflow.

La API pública de GitHub confirmó dos ejecuciones de calidad completas:

| Rama | Run | SHA | Resultado | Evidencia |
|---|---|---|---|---|
| `main` | [30499884455](https://github.com/xPshycho/qa_gestion_inventarios/actions/runs/30499884455) | `0cfbd7ba37be6b5e1b87d9c45d6003ae98481251` | success | ocho artifacts de tests/build, expiración observada 12-08-2026 |
| `staging` | [30498677524](https://github.com/xPshycho/qa_gestion_inventarios/actions/runs/30498677524) | `62e1433b087e94fa2d53a6bd63b8c35bbf7781bf` | success | artifacts unit/API/integration/frontend/E2E/ZAP/Trivy/build, expiración observada 12-08-2026 |

En ambos, `CI Required` aprobó. En ambos, `Staging after CI` apareció
`skipped`; esos runs demuestran las suites de la rama, no un deployment
staging. El workflow de producción
[30500093137](https://github.com/xPshycho/qa_gestion_inventarios/actions/runs/30500093137)
aprobó `Deploy and validate production` para el SHA de `main` y publicó
`production-evidence-0cfbd7...-1`, con expiración observada 28-08-2026.

Los nombres, tamaños, jobs y límites están preservados en el
[índice de evidencia del pipeline](evidence/pipeline/README.md).

No se consultó ni modificó el issue #91. GitHub se usó únicamente en modo
público/solo lectura; no se descargaron artifacts ni se reejecutaron workflows.

## Despliegue y rollback

Producción VM se despliega desde el workflow GCP por SHA y scripts
`scripts/gcp/`. `opentofu-ci.yml` ejecutó correctamente el plan GCP de solo
lectura del PR #145 y `gcp-managed-deploy.yml` define los applies
development/staging por WIF después de CI. El primer job de development
post-merge quedó `skipped`; por ello #107 continúa abierto y no se declara el
apply automático como validado. El root OpenTofu production no reemplaza la
ruta VM vigente. Los procedimientos están en
[staging/producción](19-staging-produccion.md),
[rollback](20-backup-y-rollback.md) y
[operación GCP/OpenTofu](27-guia-operativa-gcp-opentofu.md).

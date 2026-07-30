# OpenTofu para Google Cloud

Esta carpeta contiene la infraestructura declarativa del issue #106. Prepara
una plataforma administrada y aislada para `development`, `staging` y
`production` sin modificar automáticamente la VM de producción existente.

La guía operativa completa está en
[`docs/deployment/opentofu-gcp.md`](../../docs/deployment/opentofu-gcp.md). El
estado observado, las aprobaciones, incidentes, recuperación y trazabilidad del
issue #109 están en
[`docs/27-guia-operativa-gcp-opentofu.md`](../../docs/27-guia-operativa-gcp-opentofu.md).

## Estructura

```text
infra/opentofu/
├── bootstrap/                  # Bucket GCS versionado para state remoto
├── platform/                   # APIs compartidas y Artifact Registry
├── environments/
│   ├── development/            # State y variables independientes
│   ├── staging/
│   └── production/
└── modules/
    ├── artifact_registry/
    ├── cloud_run_service/
    ├── cloud_sql/
    ├── environment/
    ├── project_services/
    └── secret_catalog/
```

Los archivos `*.tfvars.example` y `backend.hcl.example` son contratos sin
credenciales. `.tfvars`, state, `.terraform/` y `*.tfplan` están ignorados por
Git. Una copia llamada `backend.hcl` **no está ignorada actualmente**: nunca
debe contener `credentials` y el operador debe comprobar `git status` para no
añadirla por accidente.

## Validación segura

```bash
make test-infra
```

La validación:

1. comprueba formato;
2. rechaza valores de secretos, credenciales, states y planes versionables;
3. inicializa todos los roots con `-backend=false`;
4. ejecuta `tofu validate`;
5. genera planes simulados mediante `mock_provider`;
6. confirma aislamiento, Cloud SQL privado/cifrado, imágenes inmutables y
   protección de staging/production.

No autentica contra Google Cloud, no consulta recursos y no ejecuta `apply`.

## Orden de aplicación

```text
bootstrap local
      ↓
platform remoto
      ↓
environment con deploy_services=false
      ├── VPC + Private Services Access
      └── Cloud SQL sin IP pública
      ↓
crear usuarios y versiones de secretos fuera de OpenTofu
      ↓
publicar imágenes inmutables
      ↓
environment con deploy_services=true
```

Nunca se ejecuta `tofu apply` desde un pull request. Los PR realizan planes
GCP de solo lectura; `ci-required.yml` conecta los pushes a `develop` y
`staging` con `gcp-managed-deploy.yml`. El primer job post-merge de development
quedó `skipped`, por lo que el `apply` automático continúa pendiente de
validación y el issue #107 sigue abierto. `main -> production` conserva la
ruta VM: el root OpenTofu de production solo se planifica.

# OpenTofu para Google Cloud

Esta carpeta contiene la infraestructura declarativa del issue #106. Prepara
una plataforma administrada y aislada para `development`, `staging` y
`production` sin modificar automáticamente la VM de producción existente.

La guía operativa completa está en
[`docs/deployment/opentofu-gcp.md`](../../docs/deployment/opentofu-gcp.md).

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
credenciales. Las copias reales están ignoradas por Git.

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

Nunca se ejecuta `tofu apply` desde un pull request. El issue #107 incorporará
Workload Identity Federation, aprobación por GitHub Environment y promoción
automática por SHA.

# Módulo `project_services`

Habilita las APIs requeridas por la plataforma y conserva
`disable_on_destroy=false` para evitar que destruir un stack interrumpa otros
recursos del proyecto.

| Entrada | Descripción |
|---|---|
| `project_id` | Proyecto GCP objetivo |
| `services` | Conjunto de APIs que deben permanecer habilitadas |

La salida `enabled_services` expone los nombres efectivamente administrados.
El root `platform` consume este módulo antes de Artifact Registry y WIF.

```hcl
module "services" {
  source     = "../modules/project_services"
  project_id = var.project_id
  services   = ["run.googleapis.com", "sqladmin.googleapis.com"]
}
```


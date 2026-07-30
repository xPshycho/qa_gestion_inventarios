# Módulo `secret_catalog`

Crea contenedores de Secret Manager y concede acceso a las cuentas runtime.
No crea `google_secret_manager_secret_version` ni administra `secret_data`.

| Entrada | Descripción |
|---|---|
| `project_id` | Proyecto que contiene los secretos |
| `secrets` | Mapa de sufijo y cuentas autorizadas |
| `labels` | Ambiente y ownership |

La salida `secret_ids` permite construir referencias de Cloud Run. Los valores
se cargan desde GitHub Environments mediante
[`seed-runtime-secrets.sh`](../../../../scripts/opentofu/seed-runtime-secrets.sh)
y nunca deben aparecer en `.tfvars`, planes, state o artifacts.


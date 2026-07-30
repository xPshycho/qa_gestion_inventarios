# Módulo `artifact_registry`

Crea un repositorio Docker regional con labels y política de limpieza. El
pipeline publica tags por SHA y convierte las referencias a digests antes del
plan de Cloud Run.

| Entrada | Descripción |
|---|---|
| `project_id`, `region` | Ubicación del repositorio |
| `repository_id` | Nombre estable del repositorio Docker |
| `labels` | Metadatos de ownership |

| Salida | Consumidor |
|---|---|
| `repository_id` | IAM y configuración de CI |
| `repository_url` | Construcción de referencias de imágenes |

No reduzca la retención sin comprobar que los digests necesarios para rollback
continúan disponibles.


# Módulo `cloud_run_service`

Define un servicio Cloud Run v2 con un contenedor ingress, sidecars opcionales,
Direct VPC egress, límites de escalado, IAM público opcional y protección de
borrado.

| Entradas principales | Función |
|---|---|
| `project_id`, `region`, `name` | Identidad del servicio |
| `service_account_email` | Identidad runtime |
| `network`, `subnetwork` | Salida privada |
| `ingress_container` | Imagen, puerto, recursos, env y secretos |
| `sidecar_containers` | Backend o Cloud SQL Auth Proxy |
| `min_instances`, `max_instances` | Escalado |
| `allow_unauthenticated`, `ingress` | Exposición |
| `deletion_protection` | Protección por ambiente |

Las salidas son `name`, `uri` y `service_account_email`. Las imágenes deben
estar fijadas a un digest completo; las versiones de secretos deben ser
numéricas y explícitas.


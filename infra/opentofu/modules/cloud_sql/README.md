# Módulo `cloud_sql`

Administra PostgreSQL, las bases `inventory` y `keycloak`, backups y
conectividad exclusivamente privada.

| Entradas principales | Función |
|---|---|
| `project_id`, `region`, `environment` | Identidad y ubicación |
| `instance_name`, `tier`, `disk_size_gb` | Capacidad |
| `private_network`, `allocated_ip_range` | Private Services Access |
| `availability_type`, `backup_start_time` | Continuidad |
| `deletion_protection` | Protección por ambiente |

Las salidas incluyen nombre, connection name, IP privada y nombres de bases.
El módulo no crea usuarios ni contraseñas: el seed operativo los sincroniza
fuera del state.

Aceptación mínima: sin IPv4 pública, conexión cifrada, backup habilitado y
protección de borrado en staging/production.


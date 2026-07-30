# Base de datos

## Motor y topología

Motor: PostgreSQL 16.\
Local: contenedor `postgres`, host `localhost:55432`, interno `5432`.\
Producción VM: contenedor interno; no hay puerto público documentado.\
GCP development: Cloud SQL PostgreSQL 16 mediante Cloud SQL Auth Proxy.

En GCP se observaron tres instancias: `inventory-development` pública,
`inventory-development-postgres` privada y `inventory-staging-postgres`
privada. Las dos nuevas convergieron a `RUNNABLE` durante la auditoría, pero no
se verificaron bases, usuarios o consumidores en ellas.

## Esquema

Flyway mantiene siete migraciones bajo
`backend/src/main/resources/db/migration/`:

| Migración | Responsabilidad |
|---|---|
| V1 | tabla `products` |
| V2 | usuarios, permisos, roles y movimientos |
| V3 | columnas/ajustes de seguridad |
| V4 | datos iniciales de inventario y matriz |
| V5 | sincronización/constraints adicionales |
| V6-V7 | auditoría Envers y correcciones |

Tablas verificadas por migraciones: `products`, `inventory_users`,
`permissions`, `roles`, `role_permissions`, `user_roles`,
`stock_movements`, `audit_log`, `audit_revisions`, `products_aud` y
`stock_movements_aud`.

Relaciones principales:

- roles N:M permissions mediante `role_permissions`;
- users N:M roles mediante `user_roles`;
- product 1:N stock movements;
- revisiones Envers enlazan entidades auditadas con la revisión.

Véase [modelo de datos](diagrams/modelo-datos.md).

Ruta: `backend/src/main/resources/db/migration/V2__create_stock_security_tables.sql`\
Líneas aproximadas: 1-71\
Componente: esquema stock/seguridad\
Responsabilidad: constraints, claves foráneas e índices que protegen
integridad. Flyway lo ejecuta antes del backend; integración/Testcontainers
prueba el esquema real.

Ruta: `backend/src/main/resources/application.properties`\
Líneas aproximadas: 3-15\
Componente: datasource/JPA/Flyway\
Responsabilidad: obliga password por entorno, valida el esquema y evita
generación automática.

## Consola y consultas

Todos los comandos se ejecutan desde la raíz.

`Verificado por Compose; requiere entorno local iniciado`

```bash
docker compose exec postgres \
  psql -U inventory_user -d inventory
```

Dentro de `psql`:

```text
\l
\dn
\dt
\d products
\d stock_movements
SELECT version, description, success
FROM flyway_schema_history ORDER BY installed_rank;
SELECT id, sku, name, current_stock
FROM products ORDER BY id LIMIT 20;
SELECT pid, usename, application_name, client_addr, state
FROM pg_stat_activity WHERE datname = current_database();
\q
```

Los usernames corresponden al contrato local; el password se obtiene del
`.env` privado si `psql` lo solicita.

## Backup local

`No verificado en esta auditoría · crea archivo sensible`

```bash
umask 077
docker compose exec -T postgres \
  pg_dump -U inventory_user -d inventory -Fc > inventory.backup
```

El archivo puede contener datos operativos. Cifrar, restringir permisos,
definir retención y no versionarlo.

## Restauración local

**Destructivo: sobrescribe el contenido lógico del destino.** Validar el backup
en una base temporal antes de producción.

`No verificado · Destructivo · requiere aprobación`

```bash
docker compose exec -T postgres \
  createdb -U inventory_user inventory_restore_test
docker compose exec -T postgres \
  pg_restore -U inventory_user -d inventory_restore_test --clean --if-exists \
  < inventory.backup
```

La alternativa segura es restaurar siempre a `inventory_restore_test` y
comparar conteos/migraciones antes de promover.

## Cloud SQL

`Verificado · Requiere privilegios GCP · solo metadatos`

```bash
gcloud sql instances describe inventory-development \
  --project=project-e70349a8-c787-4733-9a0
gcloud sql databases list \
  --instance=inventory-development \
  --project=project-e70349a8-c787-4733-9a0
gcloud sql backups list \
  --instance=inventory-development \
  --project=project-e70349a8-c787-4733-9a0
```

Para consola SQL se recomienda Cloud SQL Auth Proxy o
`gcloud sql connect` desde una identidad autorizada. No se verificó conexión
interactiva para evitar solicitar/exponer credenciales.

## Recuperación GCP

Backups y PITR estaban habilitados, pero no existe evidencia de un restore
drill. Antes de declarar RTO/RPO:

1. crear una instancia de restauración aislada;
2. restaurar un backup elegido;
3. validar Flyway, conteos, constraints y login de aplicación;
4. medir tiempo y documentar responsables;
5. eliminar el recurso solo con aprobación.

Estado: **Pendiente de verificación**. La restauración crea recursos/costos y
no se ejecutó en una auditoría documental.

## Riesgos

- protección de eliminación deshabilitada en las tres instancias observadas;
- una instancia pública depende del proxy y no tiene authorized networks;
- no hay evidencia de restore drill;
- los dumps locales contienen datos sensibles;
- una migración fallida bloquea el backend por diseño; nunca editar una
  migración aplicada, crear una nueva versión.

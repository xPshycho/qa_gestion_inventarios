# Calidad de datos y ambientes

Esta guía describe las garantías verificadas por la suite de datos y la separación
operativa actual de las bases de datos. No sustituye el despliegue de staging,
pendiente en el issue #86.

## Suite reproducible

Ejecutar desde `backend`:

```bash
./gradlew integrationTest --no-daemon
```

La suite usa PostgreSQL 16 mediante Testcontainers y parte de una base vacía en
cada JVM. Spring Boot ejecuta Flyway contra ese contenedor; por ello prueba el
mismo conjunto de migraciones que usa la aplicación, sin acceder a la base local.

Las pruebas validan:

- las siete migraciones Flyway y sus seeds iniciales;
- permisos, roles y usuarios demo con relaciones completas;
- movimientos `INITIAL` consistentes con el stock de los productos base;
- restricciones de SKU único, stock no negativo, claves foráneas y delta de stock.

## Estado por ambiente

| Ambiente | Base de datos | Datos | Persistencia |
| --- | --- | --- | --- |
| Integración y CI | Testcontainers PostgreSQL 16 | V1--V7, con seeds deterministas | Efímera; se elimina al terminar la ejecución |
| Desarrollo local | `docker compose` | V1--V7, con seeds deterministas | Volumen Docker nombrado `inventory-platform_postgres-data` |
| E2E y ZAP en CI | Compose con proyecto por `github.run_id` | V1--V7, con seeds deterministas | Efímera; CI ejecuta `docker compose down -v` |
| Staging | Aún no provisionado | Debe usar datos sintéticos controlados | Pendiente del issue #86 |
| Producción | Aún no provisionado | No debe contener usuarios ni productos demo | Pendiente del issue #86 |

Los datos de PostgreSQL no se almacenan en `./`. `postgres-data` es un volumen
gestionado por Docker y se monta en `/var/lib/postgresql/data` dentro del
contenedor. En Linux suele vivir bajo el directorio de datos del daemon Docker;
en Docker Desktop/WSL queda dentro de su disco administrado. El único bind mount
de Flyway es `./backend/src/main/resources/db/migration`, que contiene scripts,
no datos persistentes.

## Política para staging y producción

Las migraciones V1--V6 ya son históricas y no se modifican: Flyway valida sus
checksums. Mientras no exista un despliegue de staging/producción, el proyecto no
debe afirmar que los datos demo están separados por ambiente.

Antes de habilitar esos ambientes se debe implementar un job explícito e
idempotente de bootstrap de datos, separado de las migraciones estructurales:

1. aplicar Flyway para esquema e integridad en todos los ambientes;
2. ejecutar datos sintéticos solo en desarrollo y staging;
3. ejecutar en producción únicamente bootstrap mínimo aprobado y credenciales
   externas, nunca usuarios/productos demo;
4. conservar volúmenes de staging/producción y respaldarlos antes de cambios.

Esta separación se implementará junto con el despliegue real del issue #86; no se
simula mediante perfiles inexistentes ni modificando migraciones aplicadas.

# Calidad de datos y ambientes

> **Vigencia:** la descripción de la suite y sus resultados fue reconfirmada el
> 29/30 de julio de 2026. Las referencias al preview del issue #86 describen el
> flujo versionado; el inventario GCP actual está en
> [`docs/03-infraestructura-gcp.md`](../03-infraestructura-gcp.md).

Esta guía describe las garantías verificadas por la suite de datos y la
separación operativa de las bases. El preview de staging del issue #86 está
definido en [`docs/deployment/staging.md`](../deployment/staging.md).

## Suite reproducible

Ejecutar desde `backend`:

```bash
./gradlew integrationTest --no-daemon
```

La suite usa PostgreSQL 16 mediante Testcontainers y parte de una base vacía en
cada JVM. Spring Boot ejecuta Flyway contra ese contenedor; por ello prueba el
mismo conjunto de migraciones que usa la aplicación, sin acceder a la base local.

Las pruebas validan:

- las ocho migraciones Flyway y sus seeds iniciales;
- permisos, roles y usuarios demo con relaciones completas;
- movimientos `INITIAL` consistentes con el stock de los productos base;
- restricciones de SKU único, stock no negativo, claves foráneas y delta de stock.

## Estado por ambiente

| Ambiente | Base de datos | Datos | Persistencia |
| --- | --- | --- | --- |
| Integración y CI | Testcontainers PostgreSQL 16 | V1--V8, con seeds deterministas | Efímera; se elimina al terminar la ejecución |
| Desarrollo local | `docker compose` | V1--V8, con seeds deterministas | Volumen Docker nombrado `inventory-platform_postgres-data` |
| E2E y ZAP en CI | Compose con proyecto por `github.run_id` | V1--V8, con seeds deterministas | Efímera; CI ejecuta `docker compose down -v` |
| Staging en GitHub Actions | PostgreSQL de aplicación y PostgreSQL de Keycloak separados | V1--V8, con seeds sintéticos deterministas y realm generado | Efímera; el workflow ejecuta `destroy.sh --volumes` |
| Staging local | PostgreSQL de aplicación y PostgreSQL de Keycloak separados | V1--V8, con seeds sintéticos deterministas y realm generado | Administrada por el operador; `destroy.sh` conserva volúmenes por defecto |
| Producción observada | VM `qa-inventario`; base efectiva interna pendiente de inspección | Las migraciones versionadas aún contienen datos demo; no se verificó el contenido de la base productiva | VM y disco persistente observados; Cloud SQL development/staging no se atribuyen a producción sin evidencia |

La fila de producción no afirma que la VM use una de las instancias Cloud SQL:
el acceso interno por IAP/OS Login falló y no fue posible inspeccionar el
`compose` efectivo. El comando de verificación y el motivo están documentados
en [Infraestructura GCP](../03-infraestructura-gcp.md#producción-en-compute-engine).

Los datos de PostgreSQL no se almacenan en `./`. `postgres-data` es un volumen
gestionado por Docker y se monta en `/var/lib/postgresql/data` dentro del
contenedor. En Linux suele vivir bajo el directorio de datos del daemon Docker;
en Docker Desktop/WSL queda dentro de su disco administrado. El único bind mount
de Flyway es `./backend/src/main/resources/db/migration`, que contiene scripts,
no datos persistentes.

## Verificación de datos desplegados

La suite Testcontainers sigue siendo un gate reproducible previo al despliegue.
Después del despliegue, `scripts/staging/verify-integration.sh` comprueba contra
los contenedores activos que:

- los once servicios están ejecutándose y el job de Flyway terminó con código
  cero;
- no existen migraciones fallidas y la versión más reciente fue aplicada;
- los productos y usuarios sintéticos esperados existen;
- las comprobaciones de la base solo ejecutan consultas `SELECT`.

`scripts/staging/post-deploy.sh` incluye esa verificación y conserva el resultado
en `.staging/evidence/`.

## Persistencia, respaldo y restauración

El preview de Actions crea un proyecto Compose por run y elimina sus volúmenes al
final. No contiene datos reales y se recupera repitiendo un SHA conocido como
bueno.

El staging local conserva volúmenes salvo que se invoque explícitamente
`destroy.sh --volumes`. `backup-database.sh`, `rollback.sh` y
`restore-database.sh` protegen la base de la aplicación. No respaldan la base de
Keycloak; el realm es sintético, y los cambios persistentes de identidad deben
gestionarse mediante Admin API o recrearse solo en volúmenes descartables.

Flyway es forward-only. Una versión anterior de la aplicación puede ser
incompatible con un esquema más nuevo; en ese caso, respaldo e imágenes
anteriores se restauran como una unidad.

## Riesgo y política pendiente para producción

Las migraciones V1--V8 son históricas y no se modifican: Flyway valida sus
checksums. Actualmente incluyen datos demo, por lo que el repositorio no debe
afirmar que el bootstrap de producción ya está separado.

Aunque la VM de producción ya está desplegada, sigue pendiente implementar o
demostrar un bootstrap explícito e idempotente separado de las migraciones
estructurales:

1. aplicar Flyway para esquema e integridad en todos los ambientes;
2. ejecutar datos sintéticos solo en desarrollo, CI y staging;
3. ejecutar en producción únicamente bootstrap mínimo aprobado y credenciales
   externas, nunca usuarios/productos demo;
4. conservar los volúmenes persistentes y respaldarlos antes de cambios.

El issue #86 resolvió el ambiente aislado y validable de staging, pero no
demuestra esa separación en la VM productiva. No debe simularse mediante
perfiles inexistentes ni modificando migraciones ya aplicadas.

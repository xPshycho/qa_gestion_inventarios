# Matriz de permisos

El backend autoriza permisos, no nombres de rol. Los roles son composiciones
del realm y del seed SQL.

## Roles reales

| Acción | `INVENTORY_ADMIN` | `STOCK_OPERATOR` | `INVENTORY_VIEWER` | `AUDIT_REVIEWER` | Service account |
|---|:---:|:---:|:---:|:---:|:---:|
| Consultar productos | ✓ | ✓ | ✓ | ✓ | — |
| Crear/editar/eliminar producto | ✓ | — | — | — | — |
| Consultar stock/historial | ✓ | ✓ | ✓ | ✓ | — |
| Registrar entrada/salida/ajuste | ✓ | ✓ | — | — | — |
| Consultar reportes/dashboard | ✓ | ✓ | ✓ | — | — |
| Gestionar usuarios/roles | ✓ | — | — | — | Keycloak Admin API |
| Consultar auditoría | ✓ | — | — | ✓ | — |
| Consultar métricas públicas backend | ✓ | ✓ | ✓ | ✓ | Prometheus |
| Desplegar infraestructura | — | — | — | — | IAM/WIF, fuera de roles de aplicación |

`—` significa no concedido por la composición versionada; no significa que la
UI sea el control. La API es el control efectivo.

## Trazabilidad de permiso a endpoint

| Permiso | Endpoint/acción | Regla | Prueba principal |
|---|---|---|---|
| `product:view` | GET `/products`, `/products/{id}` | `SecurityConfig:59` | API products, E2E viewer |
| `product:manage` | POST/PUT/DELETE `/products...` | `SecurityConfig:61-63` | API permisos, E2E CRUD/roles |
| `stock:view` | GET `/products/{id}/stock-movements` | `SecurityConfig:58` | E2E stock/audit |
| `stock:manage` | POST `/products/{id}/stock/**` | `SecurityConfig:60` | API stock, E2E stock |
| `report:view` | GET `/reports/**` | `SecurityConfig:64` | k6 reports, E2E dashboard |
| `user:manage` | `/security/**` | `SecurityConfig:65` | API security, E2E roles |
| `audit:view` | GET `/audit/**` | `SecurityConfig:66` | E2E audit allowed/denied |

Ruta: `infra/keycloak/inventory-realm.json`\
Líneas aproximadas: 19-126 y 249-262\
Componente: roles compuestos y protocol mapper\
Responsabilidad: compone los siete permisos en cuatro roles y los emite en
`permissions`.

Ruta: `backend/src/main/resources/db/migration/V4__seed_initial_inventory_data.sql`\
Líneas aproximadas: 39-59\
Componente: catálogo local\
Responsabilidad: hace consultable la misma matriz para administración. No
reemplaza la autorización del JWT.

## Servicios de infraestructura

| Acción | Control real |
|---|---|
| Ver Grafana | credencial de Grafana + gateway/red del ambiente |
| Consultar Prometheus | red/gateway; Prometheus no gestiona usuarios en esta configuración |
| Ejecutar Jenkins | usuario/credencial Jenkins y permisos del job |
| Desplegar VM | GitHub Environment + WIF + IAM de deploy |
| Desplegar Cloud Run/OpenTofu | plan read-only en PR; WIF por ref y jobs `apply` versionados para `develop`/development y `staging`/staging; primera ejecución development pendiente |
| Consultar GCP | IAM del proyecto/service account |

Los roles de aplicación no otorgan permisos GCP/Jenkins/Grafana.

## Cambio de permisos

Un rol nuevo que solo compone permisos existentes puede funcionar sin cambiar
la regla backend, siempre que el mapper emita esos permisos. Un permiso nuevo
requiere sincronizar:

1. constante/regla `SecurityConfig`;
2. realm/mappers;
3. catálogo/migración SQL;
4. guards/visibilidad Angular;
5. pruebas 401/403 y E2E;
6. esta matriz.

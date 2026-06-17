# Seguridad OAuth2/JWT con Keycloak

## Resource server

La API Spring Boot funciona como OAuth2 resource server y valida tokens JWT emitidos por
Keycloak.

Issuer configurado:

```properties
spring.security.oauth2.resourceserver.jwt.issuer-uri=${SPRING_SECURITY_OAUTH2_RESOURCESERVER_JWT_ISSUER_URI:http://keycloak:8080/realms/inventory}
```

En Docker Compose el valor por defecto resuelve contra el servicio interno `keycloak`. Para ejecutar
el backend fuera de Docker se debe usar el issuer local:

```bash
SPRING_SECURITY_OAUTH2_RESOURCESERVER_JWT_ISSUER_URI=http://localhost:8081/realms/inventory ./gradlew bootRun
```

## Claims de permisos

La autorizacion se hace por permisos granulares, no por roles. El mapper de Keycloak agrega el claim
`permissions` al access token y la API tambien acepta permisos enviados como scopes OAuth2 en `scope`
o `scp`.

Ejemplo de claims soportados:

```json
{
  "permissions": ["product:view", "stock:manage"],
  "scope": "report:view audit:view"
}
```

## Matriz de endpoints

| Endpoint | Metodo | Permiso requerido |
|----------|--------|-------------------|
| `/products` | `GET` | `product:view` |
| `/products/{id}` | `GET` | `product:view` |
| `/products` | `POST` | `product:manage` |
| `/products/{id}` | `PUT` | `product:manage` |
| `/products/{id}` | `DELETE` | `product:manage` |
| `/products/{id}/stock/entries` | `POST` | `stock:manage` |
| `/products/{id}/stock/exits` | `POST` | `stock:manage` |
| `/products/{id}/stock/adjustments` | `POST` | `stock:manage` |
| `/products/{id}/stock-movements` | `GET` | `stock:view` |
| `/reports/**` | `GET` | `report:view` |
| `/security/users` | `GET` | `user:manage` |
| `/security/users` | `POST` | `user:manage` |
| `/security/users/{id}` | `PUT` | `user:manage` |
| `/security/users/{id}/roles` | `PUT` | `user:manage` |
| `/security/roles` | `GET` | `user:manage` |
| `/security/permissions` | `GET` | `user:manage` |
| `/audit/**` | `GET` | `audit:view` |
| `/actuator/health` | `GET` | Publico |

## Administracion de usuarios

El modulo de seguridad de la aplicacion permite consultar usuarios, crear usuarios basicos,
activar/desactivar cuentas y asignar roles funcionales. La fuente de autorizacion efectiva sigue
siendo Keycloak: el backend usa Keycloak Admin REST con un cliente confidencial de service account y
sin exponer credenciales administrativas al frontend.

Cliente usado por la API:

| Variable | Valor local por defecto |
|----------|-------------------------|
| `KEYCLOAK_ADMIN_URL` | `http://keycloak:8080` en Docker Compose |
| `KEYCLOAK_ADMIN_REALM` | `inventory` |
| `KEYCLOAK_ADMIN_CLIENT_ID` | `inventory-admin-service` |
| `KEYCLOAK_ADMIN_CLIENT_SECRET` | `cambiar-admin-service` |

El cliente `inventory-admin-service` se importa desde `infra/keycloak/inventory-realm.json` con
permisos minimos de `realm-management`: `view-realm`, `query-users`, `view-users` y `manage-users`. En ambientes
reales el secreto debe inyectarse con un secret manager o variable protegida, no editarse en codigo.

La app administra roles funcionales (`INVENTORY_ADMIN`, `STOCK_OPERATOR`, `INVENTORY_VIEWER`,
`AUDIT_REVIEWER`). Los permisos individuales se muestran como matriz de consulta y se heredan por
roles compuestos en Keycloak. La gestion de contrasenas, reset temporal y politicas avanzadas quedan
en la consola de Keycloak.

## Comportamiento esperado

| Caso | Resultado |
|------|-----------|
| Request sin `Authorization: Bearer ...` | `401 Unauthorized` |
| JWT valido sin el permiso requerido | `403 Forbidden` |
| JWT valido con el permiso requerido | Acceso permitido |

## Trazabilidad de stock

Los endpoints de movimientos de stock derivan el usuario operativo desde el JWT autenticado. El
backend usa el claim `preferred_username` cuando esta disponible y valida que exista un registro
equivalente en `inventory_users.username`. El cliente no debe enviar `userId` para entradas,
salidas ni ajustes de stock.

El campo `currentStock` no se modifica mediante `PUT /products/{id}`. Los cambios de inventario
deben pasar por `/products/{id}/stock/entries`, `/products/{id}/stock/exits` o
`/products/{id}/stock/adjustments` para conservar historial y auditoria.

## Evidencia automatizada

Las pruebas de seguridad viven en:

```text
backend/src/test/java/com/pucmm/inventory/config/SecurityConfigTest.java
```

Cobertura principal:

- `requestWithoutJwtReturnsUnauthorized`
- `jwtWithoutRequiredPermissionReturnsForbidden`
- `jwtWithRequiredPermissionAllowsRequest`
- `permissionsClaimIsMappedToAuthorities`

Comando de verificacion:

```bash
cd backend
./gradlew test
```
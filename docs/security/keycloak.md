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
| `/audit/**` | `GET` | `audit:view` |
| `/actuator/health` | `GET` | Publico |

## Comportamiento esperado

| Caso | Resultado |
|------|-----------|
| Request sin `Authorization: Bearer ...` | `401 Unauthorized` |
| JWT valido sin el permiso requerido | `403 Forbidden` |
| JWT valido con el permiso requerido | Acceso permitido |

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

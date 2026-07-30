# Evidencia de Swagger, Keycloak y flujos públicos

Consulta de solo lectura: 29 de julio de 2026, producción
`https://34.123.136.144`. No se inició sesión ni se enviaron secretos.

## Swagger/OpenAPI

`Verificado`

```bash
curl --fail --silent --show-error \
  https://34.123.136.144/api/v3/api-docs |
  jq '{openapi,info,path_count:(.paths|length),security_schemes:(.components.securitySchemes|keys)}'
```

Resultado observado:

| Campo | Valor |
|---|---|
| OpenAPI | `3.0.1` |
| Título | `Sistema de Gestion de Inventarios API` |
| Versión | `1.0.0` |
| Rutas | 18 |
| Esquema de seguridad | `bearer-jwt` |

Referencia de implementación:

| Ruta | Líneas aproximadas | Componente | Responsabilidad |
|---|---:|---|---|
| `backend/src/main/java/com/pucmm/inventory/config/OpenApiConfig.java` | 11-28 | `OpenApiConfig` | metadatos OpenAPI y esquema HTTP bearer/JWT |

La ruta usa el prefijo público `/api` del gateway. Localmente el backend
expone `/v3/api-docs`, tal como explica [API](../../07-api.md).

## Keycloak/OIDC

`Verificado`

```bash
curl --fail --silent --show-error \
  https://34.123.136.144/auth/realms/inventory/.well-known/openid-configuration |
  jq '{issuer,authorization_endpoint,token_endpoint,jwks_uri,scopes_supported}'
```

Se observó:

- issuer `https://34.123.136.144/auth/realms/inventory`;
- endpoints de autorización, token y JWKS bajo el realm `inventory`;
- scopes `product:view`, `product:manage`, `stock:view`, `stock:manage`,
  `report:view`, `audit:view` y `user:manage`, además de scopes OIDC.

Los metadatos anuncian varios grant types de Keycloak. Eso no significa que
todos estén habilitados para cada cliente ni aprobados por la aplicación; el
flujo real del frontend es Authorization Code + PKCE y está documentado en
[Autenticación](../../08-autenticacion-autorizacion.md).

Referencias:

| Ruta | Líneas aproximadas | Componente | Responsabilidad |
|---|---:|---|---|
| `infra/keycloak/inventory-realm.json` | 1-294 | realm y clientes frontend/backend | roles, scopes, mappers y configuración OIDC |
| `frontend/src/app/auth/auth.service.ts` | 27-150 | `AuthService` | inicialización, login, token y renovación |

## Flujos principales y evidencia

- autenticación: [diagrama](../../diagrams/flujo-autenticacion.md);
- consumo API: [diagrama](../../diagrams/flujo-api.md);
- CRUD: [captura de producto creado](../../testing/evidence/exploratory/2026-07-25/EXP-PROD-01-02-producto-creado.png);
- stock: [captura de historial y alerta](../../testing/evidence/exploratory/2026-07-25/EXP-STOCK-01-03-historial-y-alerta.png);
- permisos: [matriz observada](../../testing/evidence/exploratory/2026-07-25/EXP-SEC-01-02-matriz-roles-permisos.png);
- pipeline/deployment: [runs y artefactos](../pipeline/README.md).

Limitación: no se almacenó una captura de Swagger UI ni de la consola
administrativa Keycloak en este run. La evidencia es el contrato/metadato
público consultado y la configuración versionada; una captura adicional es
**Pendiente de verificación** si el evaluador la exige literalmente.

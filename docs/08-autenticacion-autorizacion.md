# Autenticación y autorización

## Respuesta corta

Keycloak firma y emite JWT; la aplicación no firma tokens. Angular usa
`keycloak-js` y Authorization Code + PKCE S256. Spring Boot actúa como OAuth2
Resource Server, valida el JWT mediante issuer/JWK y exige permisos atómicos.

## Dónde se maneja JWT

Ruta: `backend/src/main/resources/application.properties`\
Líneas aproximadas: 23-29\
Componente: Resource Server y cliente admin\
Responsabilidad: obtiene issuer y JWK Set de variables; recibe el client secret
desde un almacén de secretos.

Ruta: `backend/src/main/java/com/pucmm/inventory/config/SecurityConfig.java`\
Líneas aproximadas: 47-118\
Componente: `SecurityFilterChain`, `JwtAuthenticationConverter`\
Responsabilidad: API stateless; valida Bearer con Spring Security, extrae
`permissions`, `scp` y `scope`, los convierte a `GrantedAuthority` y protege
rutas con `hasAuthority`.

Entradas: request HTTP, JWT firmado, CORS origin.\
Salidas: `Authentication` autenticado o 401/403.\
Riesgos controlados: manipulación de firma, expiración estándar, acceso sin
permiso, sesión de servidor y origen CORS no permitido.\
Pruebas: `SecurityConfigTest`, API tests, integración y Playwright roles.\
Consumidores: todos los controllers y el resolver de usuario de stock.

Ruta: `frontend/src/app/auth/auth.service.ts`\
Líneas aproximadas: 44-246\
Componente: `AuthService`\
Responsabilidad: `check-sso`, flow standard, PKCE S256, login/logout, refresco,
expiración y lectura de usuario/permisos.

Ruta: `frontend/src/app/auth/auth.interceptor.ts`\
Líneas aproximadas: 6-44\
Componente: `authInterceptor`\
Responsabilidad: obtiene token vigente, añade Bearer solo a `/api`, fuerza un
refresco tras 401 y reintenta una vez.

## Firma, validación y claves

- Algoritmo concreto: lo determina la configuración de claves del realm y el
  header del token; no se debe afirmar uno sin inspeccionar un token/JWK
  vigente.
- Firma: Keycloak.
- Validación: Spring Security obtiene claves públicas del JWK Set y valida el
  issuer configurado.
- Clave privada: permanece en Keycloak; no está en el repositorio.
- Client secret administrativo: `.env` local, credencial Jenkins/GitHub o GCP
  Secret Manager según ambiente; se representa como
  `<SECRET_ADMINISTRADO_EN_ALMACEN_DEL_ENTORNO>`.
- El backend no necesita la clave privada que firma JWT.

## Duración y claims

Configuración versionada del realm:

| Propiedad | Valor |
|---|---:|
| Access token lifespan | 300 s |
| SSO idle | 1,800 s |
| SSO max | 28,800 s |
| Margen de refresco Angular | 60 s |

Claims consumidos:

| Claim | Uso |
|---|---|
| `sub` | ID de identidad |
| `preferred_username` | username operativo |
| `name`, `given_name`, `family_name` | nombre de presentación |
| `permissions` | permisos granulares principales |
| `scope` / `scp` | permisos/scopes alternativos |
| `exp` | programación del refresco/expiración |
| `iss` | validación del issuer |

Existe refresh token en el flujo estándar de Keycloak y `keycloak-js` lo usa
internamente con `updateToken()`. No se persiste en código de aplicación.

## Realm y clientes

Realm: `inventory`.

| Cliente | Tipo/flujo | Uso |
|---|---|---|
| `inventory-frontend` | público, standard flow + PKCE; Direct Access Grants activo | SPA y QA |
| `inventory-backend` | cliente de recurso; direct grants desactivado | audiencia/recurso conceptual |
| `inventory-admin-service` | confidencial, service account | Keycloak Admin REST |

Los roles funcionales son composiciones de permisos. El mapper `inventory
permissions` emite permisos en el claim `permissions`. La service account
administrativa tiene permisos mínimos de realm-management definidos en el
export.

Export/import:

```bash
# No verificado; importa el archivo versionado al iniciar el contenedor local.
docker compose up -d keycloak
```

La recuperación se realiza recreando Keycloak sobre su base, importando el
realm solo cuando corresponda y restaurando la base de Keycloak desde backup.
No sobrescribir un realm productivo con el JSON local sin un plan de datos.

## Endpoints protegidos

Las reglas exactas están en [matriz de permisos](09-matriz-de-permisos.md).
Públicos: GET health, Prometheus, Swagger y OpenAPI. Todo otro request requiere
autenticación.

## Por qué JWT

Permite que la API valide cada request sin mantener sesión local, distribuye
claims de identidad/permisos y desacopla autenticación de la lógica de
inventario. Controla falsificación mediante firma y acceso granular mediante
claims; no controla por sí mismo robo de token, XSS, revocación inmediata,
rate limiting ni configuración incorrecta de audience.

## Riesgos residuales

- No se encontró validador explícito de `aud` en `SecurityConfig`; confirmar el
  comportamiento efectivo y añadir audiencia antes de compartir issuer entre
  APIs.
- Direct Access Grants está activo en el cliente frontend para QA; desactivar
  en producción si ningún consumidor lo necesita.
- Los recursos/policies de Authorization Services del realm contienen rutas
  históricas `/users`; la enforcement efectiva actual está en Spring.
- CSRF está deshabilitado de forma apropiada para Bearer stateless, pero un
  cambio futuro a cookies exigiría reevaluarlo.
- No hay rate limiting.
- Tokens/capturas autenticadas pueden ser secretos: CI seguro desactiva traces,
  video y HTML automáticos.

## Rotación

1. Crear nueva credencial/versión en el almacén del ambiente.
2. Actualizar referencia de `inventory-admin-service`.
3. Reiniciar/desplegar backend.
4. Validar listado de roles/usuarios y 401/403.
5. Revocar/deshabilitar la versión anterior.
6. Auditar logs sin imprimir valores.

La rotación de claves de firma se administra en Keycloak con solapamiento de
claves públicas suficiente para tokens vigentes. Procedimiento productivo:
**Pendiente de verificación**, porque no se inspeccionó la consola/DB interna.

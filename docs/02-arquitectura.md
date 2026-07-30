# Arquitectura

## Vista lógica

El sistema separa presentación, aplicación, datos, identidad y telemetría. No
hay microservicios de negocio independientes: los módulos `product`, `stock`,
`report`, `audit` y `security` se compilan en una sola API Spring Boot.

```text
Navegador -> Nginx/Angular -> /api -> Spring Boot -> PostgreSQL
        \-> /auth -> Keycloak -----------^
Spring Boot -> OTLP/Prometheus -> Alloy/Prometheus/Loki/Tempo -> Grafana
```

Véase el [diagrama mantenible](diagrams/arquitectura-general.md).

## Componentes y límites de confianza

| Componente | Entrada | Salida | Límite de confianza |
|---|---|---|---|
| Nginx/Angular | HTTPS/HTTP local | `/api`, `/auth`, `/grafana` | Todo dato del navegador es no confiable. |
| Spring Boot | REST JSON + Bearer JWT | SQL, Keycloak Admin, métricas/OTLP | Valida DTO, JWT y permiso atómico. |
| Keycloak | OIDC/OAuth2 | JWT, JWK, Admin REST | Custodia identidad y credenciales. |
| PostgreSQL | SQL autenticado | Datos de negocio/Keycloak | Solo red de contenedores o proxy autorizado. |
| Observabilidad | métricas, logs y trazas | consultas/dashboards | Puede contener metadatos operativos; no enviar tokens. |

## Flujo de datos principal

1. Angular carga `auth-config.json` generado al iniciar el contenedor.
2. `AuthService` usa Authorization Code + PKCE S256 y `check-sso`.
3. Keycloak devuelve un access token al cliente; el frontend lo conserva en la
   memoria administrada por `keycloak-js`.
4. El interceptor añade `Authorization: Bearer <TOKEN>`.
5. Spring valida firma/issuer mediante JWK y convierte `permissions`, `scp` o
   `scope` a `GrantedAuthority`.
6. `SecurityConfig` exige el permiso del endpoint.
7. Servicio y repositorio ejecutan la regla de negocio y SQL.
8. Filtros/Micrometer emiten correlación, métricas y trazas.

Ruta: `frontend/src/app/auth/auth.service.ts`\
Líneas aproximadas: 44-190\
Componente: `AuthService`\
Responsabilidad: inicializa Keycloak, refresca token con 60 segundos de margen,
sincroniza usuario/permisos y gestiona expiración. Depende de `keycloak-js`; lo
consumen guards e interceptor; las pruebas están en `auth.service.spec.ts`.

Ruta: `frontend/src/app/auth/auth.interceptor.ts`\
Líneas aproximadas: 6-44\
Componente: interceptor HTTP funcional\
Responsabilidad: añade Bearer solo a llamadas API, reintenta una vez tras
refresco ante 401 y no expone el token en URLs.

Ruta: `backend/src/main/java/com/pucmm/inventory/config/SecurityConfig.java`\
Líneas aproximadas: 47-118\
Componente: `SecurityFilterChain` y `JwtAuthenticationConverter`\
Responsabilidad: API stateless, CORS, rutas públicas, permisos y traducción de
claims.

## Arquitectura física por ambiente

| Ambiente | Despliegue |
|---|---|
| Development | Docker Compose en una estación; puertos de servicio publicados. |
| Staging local/CI | Compose aislado, puertos solo en `127.0.0.1`, evidencia efímera. |
| GCP development | Cloud Run público con cuatro contenedores y Cloud SQL. |
| Producción vigente | VM Compute Engine, Compose y gateway Nginx; público solo 80/443. |

La infraestructura declarativa OpenTofu describe una plataforma Cloud Run por
ambiente, pero no importa ni administra la VM vigente. El estado observado y
el declarado no deben confundirse; véase
[Infraestructura GCP](03-infraestructura-gcp.md#deriva-entre-lo-declarado-y-lo-observado).

## Decisiones y riesgos

- Monolito modular: reduce complejidad operativa y conserva módulos de dominio.
- JWT stateless: evita sesión de servidor, pero requiere proteger el navegador,
  renovar tokens y validar correctamente issuer/audience.
- El código verificado valida issuer/firma mediante la configuración estándar de
  Spring; no se encontró validador explícito de audience. Es una brecha a
  resolver antes de aceptar tokens destinados a múltiples APIs.
- CORS es lista explícita, sin credenciales, métodos GET/POST/PUT/DELETE/OPTIONS.
- No existe rate limiting en el repositorio: **Pendiente de verificación/implementación**
  si el servicio se ofrece a terceros.

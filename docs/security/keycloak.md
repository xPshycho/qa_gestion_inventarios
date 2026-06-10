# Keycloak: realm, clientes y permisos granulares

Este documento resume la configuracion local de Keycloak para el issue #11:
`[SECURITY] Keycloak: realm, clientes, roles, scopes y permisos granulares`.

## Realm y clientes

| Elemento | Valor | Uso |
|----------|-------|-----|
| Realm | `inventory` | Realm del sistema de inventarios |
| Cliente frontend | `inventory-frontend` | Cliente publico OIDC para Angular |
| Cliente backend | `inventory-backend` | Resource server para la API REST |
| Issuer local | `http://localhost:8081/realms/inventory` | Emisor de tokens JWT |
| Export | `infra/keycloak/inventory-realm.json` | Configuracion importable del realm |

El cliente `inventory-frontend` tiene Authorization Code + PKCE y Direct Access Grants habilitados
para pruebas locales con `curl`. El cliente `inventory-backend` define resources, scopes, policies y
scope permissions en Authorization Services para que el issue de proteccion de endpoints pueda
consumir esta matriz sin depender solo de nombres de roles.

## Matriz de permisos por rol

| Permiso | INVENTORY_ADMIN | STOCK_OPERATOR | INVENTORY_VIEWER | AUDIT_REVIEWER |
|---------|-----------------|----------------|------------------|----------------|
| `product:view` | Si | Si | Si | Si |
| `product:manage` | Si | No | No | No |
| `stock:view` | Si | Si | Si | Si |
| `stock:manage` | Si | Si | No | No |
| `report:view` | Si | Si | Si | No |
| `user:manage` | Si | No | No | No |
| `audit:view` | Si | No | No | Si |

## Usuarios demo locales

Estas credenciales son solo para desarrollo local y no deben reutilizarse en ambientes reales.

| Usuario | Password | Rol |
|---------|----------|-----|
| `carlos` | `Carlos123!` | `INVENTORY_ADMIN` |
| `edwin` | `Edwin123!` | `STOCK_OPERATOR` |
| `viewer` | `Viewer123!` | `INVENTORY_VIEWER` |
| `auditor` | `Auditor123!` | `AUDIT_REVIEWER` |

## Validacion local

Levantar Keycloak:

```bash
docker compose up -d keycloak
```

Validar discovery OIDC:

```bash
curl http://localhost:8081/realms/inventory/.well-known/openid-configuration
```

Obtener un token para el administrador de inventario:

```bash
curl -s -X POST http://localhost:8081/realms/inventory/protocol/openid-connect/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password" \
  -d "client_id=inventory-frontend" \
  -d "username=carlos" \
  -d "password=Carlos123!" \
  -d "scope=openid product:view product:manage stock:view stock:manage report:view user:manage audit:view"
```

Decodificar el payload del JWT:

```bash
export TOKEN="<access_token>"
python -c "import base64,json,os; p=os.environ['TOKEN'].split('.')[1]; p += '=' * (-len(p) % 4); print(json.dumps(json.loads(base64.urlsafe_b64decode(p)), indent=2))"
```

Validaciones esperadas:

- El token de `carlos` debe contener permisos administrativos como `product:manage` y `user:manage`.
- El token de `viewer` debe contener permisos de consulta como `product:view`, `stock:view` y `report:view`.
- El token de `viewer` no debe contener `product:manage`, `stock:manage`, `user:manage` ni `audit:view`.
- El issuer debe ser `http://localhost:8081/realms/inventory`.

La aplicacion backend aun no rechaza peticiones sin JWT en este issue. La proteccion de endpoints
por permisos corresponde al issue #12.

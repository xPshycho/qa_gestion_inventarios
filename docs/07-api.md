# API REST

## Contrato

La API Spring Boot no usa prefijo de versión. El OpenAPI documental declara
versión `1.0.0`, pero las rutas reales son `/products`, `/reports`,
`/security` y `/audit`.

| Entorno | Base URL externa |
|---|---|
| Development directo | `http://localhost:8080` |
| Development vía frontend | `http://localhost:5173/api` |
| Staging local | `http://127.0.0.1:15173/api` |
| Cloud Run development | `<URL_RUN_APP_OBSERVADA>/api` |
| Producción VM | `https://34.123.136.144/api` |

Swagger: `/swagger-ui/index.html`; OpenAPI JSON: `/v3/api-docs`. En un gateway,
anteponer `/api` si corresponde.

Content type de escritura: `application/json`. Header de negocio:
`Authorization: Bearer <ACCESS_TOKEN>`.

## Autenticación sin GUI

El frontend usa Authorization Code + PKCE. Para QA local el cliente
`inventory-frontend` también tiene Direct Access Grants habilitado; no es el
flujo recomendado para producción.

`No verificado manualmente en esta auditoría; cubierto por k6/E2E · local`

```bash
export KC_URL=http://localhost:8081
export API_URL=http://localhost:8080
export DEMO_USERNAME=viewer
read -r -s DEMO_PASSWORD

ACCESS_TOKEN="$(
  curl --fail --silent --show-error \
    --data-urlencode grant_type=password \
    --data-urlencode client_id=inventory-frontend \
    --data-urlencode username="$DEMO_USERNAME" \
    --data-urlencode password="$DEMO_PASSWORD" \
    "$KC_URL/realms/inventory/protocol/openid-connect/token" |
  jq -r .access_token
)"
test -n "$ACCESS_TOKEN" && test "$ACCESS_TOKEN" != null
```

No imprimir, registrar ni guardar `ACCESS_TOKEN`. Ejecutar `unset ACCESS_TOKEN
DEMO_PASSWORD` al terminar.

El response OIDC puede incluir refresh token. Su renovación estándar usa
`grant_type=refresh_token`, pero guardar el refresh token en shell aumenta
riesgo; para operación humana se recomienda el flujo PKCE de la aplicación.

## Consultas

`Verificado indirectamente por API/E2E/k6`

```bash
curl --fail --silent --show-error \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H 'Accept: application/json' \
  "$API_URL/products?page=0&size=20&sort=name&direction=asc"

curl --fail --silent --show-error \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  "$API_URL/reports/dashboard"
```

La lista de productos admite `search`, `category`, `status`, `sort` y
`direction`; `size` está limitado a 1-100.

## CRUD reproducible

Use exclusivamente development/staging controlado. Cambiar el SKU de demo en
cada ejecución.

`No verificado como bloque manual · muta datos locales`

```bash
ADMIN_TOKEN=<ACCESS_TOKEN_CON_PRODUCT_MANAGE>
PRODUCT_ID="$(
  curl --fail --silent --show-error \
    -X POST "$API_URL/products" \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    -H 'Content-Type: application/json' \
    -d '{
      "sku": "DOC-DEMO-001",
      "name": "Producto de demostración",
      "description": "Creado para validar la API",
      "category": "Demostración",
      "price": 100.00,
      "currentStock": 0,
      "minimumStock": 2,
      "status": "ACTIVE"
    }' | jq -r .id
)"

curl --fail --silent --show-error \
  -X PUT "$API_URL/products/$PRODUCT_ID" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{
    "sku": "DOC-DEMO-001",
    "name": "Producto de demostración actualizado",
    "description": "Validación de actualización",
    "category": "Demostración",
    "price": 125.00,
    "currentStock": 0,
    "minimumStock": 2,
    "status": "ACTIVE"
  }'

curl --fail --silent --show-error \
  -X DELETE "$API_URL/products/$PRODUCT_ID" \
  -H "Authorization: Bearer $ADMIN_TOKEN"
```

La actualización directa de `currentStock` está restringida por la lógica de
negocio; use endpoints de stock:

```bash
curl --fail --silent --show-error \
  -X POST "$API_URL/products/$PRODUCT_ID/stock/entries" \
  -H "Authorization: Bearer <TOKEN_CON_STOCK_MANAGE>" \
  -H 'Content-Type: application/json' \
  -d '{"quantity":3,"observations":"Recepción de demo"}'
```

## Errores esperados

| Caso | HTTP esperado |
|---|---:|
| Sin token, token inválido o expirado | 401 |
| Token válido sin permiso | 403 |
| Validación de DTO/parámetro | 400 |
| Producto no encontrado | 404 |
| SKU duplicado | 409 |
| Creación | 201 |
| Eliminación correcta | 204 |

`ErrorResponse` contiene `status`, `message` y `timestamp`.

Ruta: `backend/src/main/java/com/pucmm/inventory/common/api/ErrorResponse.java`\
Líneas aproximadas: 6-13\
Componente: contrato de error\
Responsabilidad: respuesta JSON uniforme con timestamp UTC.

Prueba de permiso insuficiente:

```bash
curl --silent --output /dev/null --write-out '%{http_code}\n' \
  -X POST "$API_URL/products" \
  -H "Authorization: Bearer <TOKEN_VIEWER>" \
  -H 'Content-Type: application/json' \
  -d '{}'
```

Debe devolver 403 antes de evaluar el DTO. Token inválido:

```bash
INVALID_ACCESS_TOKEN='not-a-jwt'
curl --silent --output /dev/null --write-out '%{http_code}\n' \
  -H "Authorization: Bearer $INVALID_ACCESS_TOKEN" \
  "$API_URL/products"
unset INVALID_ACCESS_TOKEN
```

## Límites y CORS

- No se encontró rate limiting: **Pendiente de implementación/verificación**.
- CORS usa lista explícita por entorno, no permite credenciales y acepta
  Authorization/Content-Type/Accept.
- No existe colección Postman versionada. OpenAPI es la fuente importable.
- La validación explícita de audience JWT no se encontró en código; véase
  [autenticación](08-autenticacion-autorizacion.md#riesgos-residuales).

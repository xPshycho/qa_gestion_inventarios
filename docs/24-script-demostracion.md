# Script de demostración

Duración objetivo: 18-22 minutos. Usar development o staging aislado. No hacer
CRUD, ZAP activo, carga ni rollback destructivo en producción.

## 1. Preparación — 2 min

Qué mostrar: repo, índice y versión.\
Qué decir: “La demo usa un stack reproducible y secretos locales generados”.\
Comando (`Verificado`, raíz):

```bash
./scripts/security/init-secret-env.sh local
docker compose up --build -d --wait --wait-timeout 240
docker compose ps
```

Resultado: servicios healthy/running.\
Si falla: usar `docker compose logs --tail=100 <servicio>` y no mostrar `.env`.

## 2. Health — 1 min

Qué mostrar: frontend/API/OIDC.\
Qué decir: “Validamos presentación, negocio e identidad por separado”.\
Comando:

```bash
curl --fail http://localhost:5173/health
curl --fail http://localhost:8080/actuator/health
curl --fail \
  http://localhost:8081/realms/inventory/.well-known/openid-configuration |
  jq '{issuer,token_endpoint,jwks_uri}'
```

Esperado: `ok`, `UP` e issuer local.\
Si falla: revisar ports/health y usar screenshots del último E2E.

## 3. Login y flujo funcional — 3 min

Qué mostrar: login admin/operator, dashboard, catálogo, creación con stock 0,
entrada/ajuste e historial.\
Qué decir: “El stock cambia solo por movimientos auditables”.\
Comando: interacción GUI en `http://localhost:5173`.\
Esperado: dashboard actualizado y movimiento con usuario.\
Si falla: no editar base manualmente; mostrar E2E screenshots.

## 4. API sin GUI — 2 min

Qué mostrar: Swagger/OpenAPI y GET autenticado.\
Qué decir: “La SPA no es requisito para consumir la API”.\
Comando: seguir [obtención de token](07-api.md#autenticación-sin-gui), luego:

```bash
curl --fail --silent \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  'http://localhost:8080/products?page=0&size=5' | jq .
```

Esperado: página JSON.\
Si falla: verificar issuer/token y no imprimir el token.

## 5. Roles y permisos — 2 min

Qué mostrar: viewer puede listar pero no crear; auditor ve auditoría.\
Qué decir: “La API valida `hasAuthority`, no confía en el botón”.\
Comando:

```bash
curl --silent --output /dev/null --write-out '%{http_code}\n' \
  -X POST http://localhost:8080/products \
  -H "Authorization: Bearer <TOKEN_VIEWER>" \
  -H 'Content-Type: application/json' -d '{}'
```

Esperado: 403.\
Si falla: inspeccionar el claim localmente sin compartir JWT y revisar realm.

## 6. JWT — 1 min

Qué mostrar: `SecurityConfig:47-118` y `auth.service.ts:44-190`.\
Qué decir: “Keycloak firma; Spring valida issuer/JWK; permisos viajan en
`permissions`; Angular refresca 60 s antes”.\
Comando: ninguno; no decodificar un token real en pantalla.\
Si preguntan audience: reconocer que no hay validador explícito y es riesgo.

## 7. Prueba local — 1 min

Qué mostrar: una suite rápida/listado.\
Comando:

```bash
cd tests/e2e
pnpm exec playwright test --list
```

Esperado: inventario de tests/proyectos.\
Si falla: usar `pnpm --dir tests/e2e test` desde raíz con Docker.

## 8. Playwright visible — 2 min

Qué mostrar: un flujo con navegador.

```bash
cd tests/e2e
pnpm exec playwright test specs/products-crud.spec.ts \
  --project=chromium --headed
```

Estado: `No verificado` por ser interactivo; compatible con configuración.\
Esperado: navegador visible y test aprobado.\
Si falla por display/browser: usar el run Docker 20/20 y capturas controladas.

## 9. Coverage — 1 min

Qué mostrar: HTML JaCoCo/Karma generado.\
Qué decir: unit backend 90.97 % líneas; frontend 83.63 %; citar fecha.

```bash
python3 -m http.server 8765 \
  --directory backend/build/reports/jacoco/test/html
```

Abrir `http://127.0.0.1:8765`; Ctrl-C al terminar.\
Si falta reporte: ejecutar comandos del documento 12.

## 10. Pipeline/reportes — 1.5 min

Qué mostrar: [run Quality `main` 30499884455](https://github.com/xPshycho/qa_gestion_inventarios/actions/runs/30499884455),
sus artifacts, Jenkinsfile stages y tabla “Dónde consultar”.\
Qué decir: “Actions principal aprobó suites y publicó artifacts; Jenkins es
complementario y su run remoto está pendiente; safety se ejecuta antes de
publicar E2E”.\
Comando: ninguno.\
Esperado: mostrar resultado `success`, SHA
`0cfbd7ba37be6b5e1b87d9c45d6003ae98481251`, artifacts con expiración
observada 12-08-2026 y explicar rutas/retención en menos de un minuto.\
Si GitHub no está disponible: usar el
[índice de pipeline](evidence/pipeline/README.md); no simular Jenkins.

## 11. Observabilidad — 2 min

Qué mostrar: Prometheus targets, PromQL `up`, Grafana Explore.\
Comando:

```bash
curl --silent http://localhost:9090/api/v1/targets |
  jq '.data.activeTargets[] | {scrapeUrl,health,lastError}'
curl --get --silent \
  --data-urlencode 'query=up{job="inventory-backend"}' \
  http://localhost:9090/api/v1/query | jq .
```

Esperado: backend UP.\
Si falla: usar diagnóstico del documento 17 y reconocer brecha.

## 12. Producción y rollback — 2 min

Qué mostrar: health HTTPS y diagrama, no ejecutar deploy.

```bash
curl --fail https://34.123.136.144/health
curl --fail https://34.123.136.144/api/actuator/health
```

Qué decir: releases por SHA, backup previo, rollback script y smoke.\
Esperado: `ok`/`UP`.\
Si falla: declarar incidente; no reiniciar ni desplegar desde la demo.

Simulación segura: recorrer los parámetros de
`docs/20-backup-y-rollback.md` con placeholders, sin ejecutar.

## 13. Cierre — 1 min

Qué mostrar: trazabilidad y pendientes.\
Qué decir: “Las suites auditadas aprobaron; ZAP es baseline pasivo, Cloud SQL
restore y observabilidad interna VM siguen pendientes; el issue #91 no fue
modificado”.\
Comando: ninguno.

## Limpieza

`Cambia estado local; conserva volúmenes`

```bash
docker compose stop
unset ACCESS_TOKEN DEMO_PASSWORD ADMIN_TOKEN
```

No usar `down -v` si se necesita conservar la demo/evidencia.

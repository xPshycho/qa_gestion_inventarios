# Performance testing con k6

Suite de performance para validar la API con perfiles smoke, carga y estrés
controlado. Cubre health, consulta paginada de productos y dashboard de
reportes. No es una certificación de capacidad productiva ni debe ejecutarse
contra producción.

## Prerrequisitos

- Docker y Docker Compose para levantar PostgreSQL, Flyway, Keycloak, backend y frontend.
- k6 instalado localmente o Docker para ejecutar `grafana/k6`.
- Stack local arriba con los comandos oficiales del repositorio.
- Datos semilla aplicados por Flyway.
- Usuario con permisos `product:view` y `report:view`; el usuario demo de consulta cumple ese rol.
- Puertos por defecto disponibles: backend `8080`, Keycloak `8081`, PostgreSQL `55432`.

## Levantar el entorno local

Desde la raiz del repositorio:

```bash
docker compose up --build --wait --wait-timeout 240 -d
docker compose ps
```

Comprobaciones rapidas:

```bash
curl http://localhost:8080/actuator/health
curl http://localhost:8081/realms/inventory
```

Los endpoints de negocio estan protegidos por JWT. La suite obtiene un token desde Keycloak o usa
un token ya emitido mediante `K6_ACCESS_TOKEN`.

## Variables de entorno

| Variable | Obligatoria | Default | Descripcion |
|---|---|---|---|
| `BASE_URL` | No | `http://localhost:8080` | URL base del backend. |
| `KEYCLOAK_URL` | No | `http://localhost:8081` | URL publica de Keycloak usada para obtener tokens. |
| `KEYCLOAK_REALM` | No | `inventory` | Realm de Keycloak. |
| `KEYCLOAK_CLIENT_ID` | No | `inventory-frontend` | Cliente OIDC publico con Direct Access Grants en local. |
| `KEYCLOAK_CLIENT_SECRET` | No | vacio | Solo para clientes confidenciales si el ambiente lo requiere. |
| `K6_USERNAME` | No | `viewer` | Usuario de pruebas con permisos de lectura. |
| `K6_PASSWORD` | Si, salvo `K6_ACCESS_TOKEN` | vacio | Password del usuario de pruebas. No se imprime ni se guarda. |
| `K6_ACCESS_TOKEN` | Si, salvo `K6_PASSWORD` | vacio | Access token preemitido. Tiene prioridad sobre password grant. |
| `K6_PROFILE` | No | `smoke` | Perfil `smoke`, `load` o `stress`. |
| `HEALTH_PATH` | No | `/actuator/health` | Endpoint de health. |
| `PRODUCTS_PATH` | No | `/products?page=0&size=20&sort=name&direction=asc` | Consulta paginada de productos. |
| `REPORTS_PATH` | No | `/reports/dashboard` | Endpoint principal de reportes. |
| `K6_RESULTS_DIR` | No | `test-results/performance/k6` | Carpeta central donde se escriben resumenes. |
| `K6_SLEEP_SECONDS` | No | `1` | Pausa entre iteraciones por VU. |
| `K6_ERROR_RATE` | No | `0.01` | Maximo error rate global permitido. |
| `K6_CHECK_RATE` | No | `0.99` | Minimo de checks exitosos. |
| `K6_P95_MS` | No | `1200` | Maximo p95 global. |
| `K6_P99_MS` | No | `2500` | Maximo p99 global. |
| `K6_HEALTH_P95_MS` | No | `300` | Maximo p95 de health. |
| `K6_PRODUCTS_P95_MS` | No | `800` | Maximo p95 de productos. |
| `K6_REPORTS_P95_MS` | No | `1500` | Maximo p95 de reportes. |

## Ejecucion smoke

La ejecución local equivalente al pipeline prepara un `.env` ignorado, levanta
un proyecto Compose aislado y usa la imagen k6 fijada:

```bash
./tests/performance/run-local.sh
```

Usar `smoke` para comprobar script, autenticacion y endpoints:

```bash
K6_PROFILE=smoke \
K6_PASSWORD="<password-local>" \
k6 run tests/performance/performance.js
```

Con token ya emitido:

```bash
K6_PROFILE=smoke \
K6_ACCESS_TOKEN="<access-token>" \
k6 run tests/performance/performance.js
```

## Ejecucion load

El perfil `load` usa una carga local conservadora con ramp-up, periodo estable y ramp-down:

```bash
K6_PROFILE=load \
K6_PASSWORD="<password-local>" \
k6 run tests/performance/performance.js
```

## Ejecución stress

El perfil `stress` eleva la concurrencia de 25 a 100 VUs y conserva los mismos
thresholds de error, checks, latencia y throughput:

```bash
K6_PROFILE=stress \
K6_PASSWORD="<password-local>" \
k6 run tests/performance/performance.js
```

## Ejecucion con Docker

Si k6 no esta instalado en el host, se puede usar la imagen oficial. En Linux, `--network host`
permite que k6 use las mismas URLs publicas que el backend espera en el issuer del JWT:

```bash
docker run --rm --network host \
  --user "$(id -u):$(id -g)" \
  -v "$PWD:/work" \
  -w /work \
  grafana/k6 run \
  -e K6_PROFILE=smoke \
  -e K6_PASSWORD="<password-local>" \
  tests/performance/performance.js
```

En macOS, Windows o Docker Desktop, usar un token emitido desde el host y apuntar al host desde el
contenedor:

```bash
docker run --rm \
  --user "$(id -u):$(id -g)" \
  -v "$PWD:/work" \
  -w /work \
  grafana/k6 run \
  -e BASE_URL=http://host.docker.internal:8080 \
  -e K6_PROFILE=smoke \
  -e K6_ACCESS_TOKEN="<access-token>" \
  tests/performance/performance.js
```

En Linux sin `--network host`, agregar `--add-host=host.docker.internal:host-gateway`. Evitar
obtener tokens contra `http://keycloak:8080` si el backend espera issuer
`http://localhost:8081/realms/inventory`, porque el JWT puede ser rechazado por mismatch de issuer.

## Distribucion de solicitudes

La suite usa una mezcla deterministica por iteraciones:

| Area | Peso aproximado |
|---|---:|
| Productos | 55% |
| Reportes | 30% |
| Health | 15% |

Cada request queda etiquetado con `endpoint=products`, `endpoint=reports`, `endpoint=health` o
`endpoint=auth`. La autenticacion ocurre una vez en `setup()`, por lo que su latencia no representa
carga concurrente sobre Keycloak.

## Resultados

k6 muestra su resumen estandar y la suite genera:

```text
test-results/performance/k6/k6-summary.json
test-results/performance/k6/k6-summary.md
```

Los archivos incluyen perfil, fecha, duracion, VUs, iteraciones, requests, requests/s, error rate,
checks, latencia promedio, p90, p95, p99, thresholds y metricas por endpoint. No incluyen tokens,
passwords ni headers de autorizacion.

Metricas principales:

| Metrica | Lectura |
|---|---|
| `http_req_duration` | Tiempo total de una request HTTP. Revisar p90, p95 y p99. |
| `http_req_failed` | Proporcion de requests HTTP fallidas. `401`, `403`, `404` y `500` fallan. |
| `http_reqs` | Total y tasa de requests. |
| `iterations` | Iteraciones completadas por los VUs. |
| `vus` / `vus_max` | Usuarios virtuales activos y maximos. |
| `checks` | Validaciones funcionales exitosas. |
| Thresholds | Si fallan, k6 termina con codigo distinto de cero. |

## Thresholds iniciales

| Metrica | Umbral | Motivo |
|---|---:|---|
| `http_req_failed` | `< 1%` | Detecta errores HTTP de forma temprana. |
| `checks` | `> 99%` | Evita considerar rapida una respuesta funcionalmente incorrecta. |
| `http_req_duration p95` | `< 1200ms` | Limite global conservador para entorno local. |
| `http_req_duration p99` | `< 2500ms` | Controla cola larga sin ser demasiado fragil localmente. |
| `health p95` | `< 300ms` | Health debe ser liviano y publico. |
| `products p95` | `< 800ms` | Listado paginado con filtros simples e indices. |
| `reports p95` | `< 1500ms` | Dashboard ejecuta agregaciones y listas de movimientos. |

Para demostrar que los thresholds fallan ante latencia excesiva:

```bash
K6_PROFILE=smoke \
K6_P95_MS=1 \
K6_PASSWORD="<password-local>" \
k6 run tests/performance/performance.js
```

Ese fallo es intencional y no debe registrarse como defecto de la plataforma.

## Fallos frecuentes

| Sintoma | Causa probable | Accion |
|---|---|---|
| `401 Unauthorized` | Token ausente, expirado o issuer incorrecto. | Revisar `K6_ACCESS_TOKEN`, `KEYCLOAK_URL` y que el backend espere el mismo issuer. |
| `403 Forbidden` | Usuario sin `product:view` o `report:view`. | Usar un usuario de consulta o un token con esos permisos. |
| `Connection refused` | Stack local apagado o puerto cambiado. | Ejecutar `docker compose ps` y ajustar `BASE_URL`/`KEYCLOAK_URL`. |
| Token expirado | Token preemitido vencio. | Emitir uno nuevo o usar `K6_PASSWORD` en una prueba corta. |
| Keycloak no disponible | Contenedor no esta healthy. | Revisar `docker compose logs keycloak`. |
| Datos semilla inexistentes | Flyway no corrio o volumen viejo. | Revisar `docker compose logs flyway` y recrear volumenes solo si corresponde. |
| Endpoint incorrecto | Se uso `/api/...` contra backend directo. | Usar `/products` y `/reports/dashboard` sobre `BASE_URL`. |
| Threshold superado | Latencia o errores reales, o maquina local saturada. | Revisar endpoint por endpoint y repetir con el equipo estable. |
| Problemas de red desde Docker | El contenedor k6 no ve `localhost` del host. | Usar `--network host` en Linux o `host.docker.internal` segun plataforma. |
| `port is already allocated` | Un puerto local del stack esta ocupado. | Ajustar el puerto en `.env`, por ejemplo `GRAFANA_PORT`, o liberar el proceso local. |

## Limitaciones

- Es una prueba inicial de respuesta, no una prueba de capacidad maxima.
- No sustituye soak, spike, capacidad ni pruebas de performance con tráfico
  productivo real.
- Los resultados locales dependen de CPU, memoria, Docker Desktop, red y procesos del equipo.
- No comparar directamente cifras locales con produccion.
- Repetir la suite contra staging cuando el issue #86 este resuelto.
- La automatizacion como quality gate o artifact de CI corresponde al issue #88.

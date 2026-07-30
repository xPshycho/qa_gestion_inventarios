# Rendimiento con k6

## Escenario real

Ruta: `tests/performance/performance.js`\
Líneas aproximadas: 13-160\
Componente: `inventory_read_mix`\
Responsabilidad: obtiene token y distribuye lecturas entre productos, reportes
y health; valida status, JSON, paginación y forma de métricas.

Ruta: `tests/performance/config/profiles.js`\
Líneas aproximadas: 1-35\
Componente: perfiles k6\
Responsabilidad: smoke 1 VU/30 s y load con ramp 5 -> 10 VUs.

Mezcla por ciclo de 20: 11 productos, 6 reportes y 3 health. Autenticación se
realiza en `setup`; no se mide como endpoint de negocio continuo.

## Thresholds

Fuente: `tests/performance/helpers/environment.js`, líneas aproximadas 35-99.

| Métrica | Threshold |
|---|---:|
| checks | `rate > 0.99` |
| errores HTTP | `rate < 0.01` |
| global p95 | `< 1200 ms` |
| global p99 | `< 2500 ms` |
| health p95 | `< 300 ms` |
| products p95 | `< 800 ms` |
| reports p95 | `< 1500 ms` |

## Resultado auditado

Fecha UTC: 30 de julio de 2026.\
Entorno: local aislado. Perfil: `smoke`.

| Métrica | Resultado |
|---|---:|
| Duración | 30.79 s |
| VUs máximos | 1 |
| Iteraciones | 30 |
| Requests | 31 |
| Throughput | 1.01 req/s |
| Error rate | 0 % |
| Checks | 100 % |
| Latencia promedio | 24.63 ms |
| p90 | 24.16 ms |
| p95 | 127.58 ms |
| p99 | 205.06 ms |
| Thresholds | PASS |

Endpoint p95: health 3.43 ms, products 16.13 ms, reports 58.36 ms,
autenticación 185.4 ms (una muestra).

Interpretación: el stack local pasó su smoke gate con una carga mínima. No
prueba capacidad, autoscaling, stress ni SLO productivo.

## Ejecución

`Verificado · Requiere Docker`

```bash
./tests/performance/run-local.sh
```

Perfil load:

`No verificado en esta auditoría · solo staging/local controlado`

```bash
K6_PROFILE=load ./tests/performance/run-local.sh
```

Defaults load: 20 s a 5 VUs, 1 min a 5, 20 s a 10 y 20 s a 0. Pueden
sobrescribirse con `K6_LOAD_*`, pero toda modificación debe registrarse junto
al resultado.

Nunca ejecutar el script contra producción: crea dependencias/usuarios de QA y
el flujo no fue diseñado como prueba de capacidad productiva.

## Reportes

| Archivo | Uso |
|---|---|
| `test-results/performance/k6/k6-summary.json` | métricas nativas |
| `.../k6-summary.md` | lectura humana |
| `.../summary.{json,md}` | contrato común |
| `.../metrics.prom` | ingestión Prometheus |
| `.../evidence/docker/` | estado/log del stack |

## Brechas

- no se ejecutó perfil load en el snapshot actual;
- no hay stress/soak/capacity test;
- Jenkins no ejecuta k6;
- la ejecución debe mantenerse fuera de producción;
- no se definieron SLO basados en tráfico real.

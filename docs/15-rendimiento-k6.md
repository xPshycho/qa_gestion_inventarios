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
Responsabilidad: smoke 1 VU/30 s, load de 5 a 10 VUs y stress de 25 a
100 VUs.

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

## Resultados auditados

Fecha UTC: 30 de julio de 2026.\
Entorno: Compose local aislado.

| Perfil | VUs máx. | Requests | Throughput | Error | Checks | p95 | p99 | Gate |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| smoke | 1 | 31 | 1.01 req/s | 0 % | 100 % | 127.58 ms | 205.06 ms | PASS |
| load | 10 | 590 | registrado por k6 | 0 % | 100 % | 48.88 ms | bajo 2,500 ms | PASS |
| stress | 100 | 10,804 | 51 req/s | 0 % | 100 % | 166.11 ms | 421.61 ms | PASS |

En el stress de 100 VUs, los p95 fueron: health 114.32 ms, products
140.51 ms y reports 229.22 ms. Se completaron 10,803 iteraciones sin
interrupciones.

Interpretación: el stack local superó sanidad, carga y estrés controlado hasta
100 usuarios virtuales. Esto no valida autoscaling, soak prolongado, capacidad
máxima ni un SLO productivo.

## Ejecución

`Verificado · Requiere Docker`

```bash
./tests/performance/run-local.sh
```

Perfil load:

`Verificado · solo staging/local controlado`

```bash
K6_PROFILE=load ./tests/performance/run-local.sh
```

Defaults load: 20 s a 5 VUs, 1 min a 5, 20 s a 10 y 20 s a 0. Pueden
sobrescribirse con `K6_LOAD_*`, pero toda modificación debe registrarse junto
al resultado.

Perfil stress:

`Verificado · pico de 100 VUs · solo staging/local controlado`

```bash
K6_PROFILE=stress ./tests/performance/run-local.sh
```

Defaults stress: 30 s hasta 25 VUs, 1 min estable, 30 s hasta 100, 1 min a
100 y 30 s de descenso. Se ajusta mediante `K6_STRESS_*`.

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

## Límites

- no hay soak prolongado ni determinación del punto de quiebre;
- Jenkins no ejecuta k6;
- la ejecución debe mantenerse fuera de producción;
- no se definieron SLO basados en tráfico real.

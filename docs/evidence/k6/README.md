# Evidencia k6

- Nombre: mezcla autenticada de lectura con perfiles smoke, load y stress.
- Fecha: 30 de julio de 2026 UTC.
- Entorno: Compose local aislado.
- Comando final: `K6_PROFILE=stress ./tests/performance/run-local.sh`.
- Resultado stress: 100 VUs máximos, 10,804 requests, 51 req/s, 0 % error,
  100 % checks, p95 166.11 ms y p99 421.61 ms; thresholds PASS.
- Evidencia: `test-results/performance/k6/`.
- Interpretación: sanidad, carga y estrés local controlado hasta 100 VUs.
- Requisito: performance testing.
- Limitaciones: no determina capacidad máxima, soak, autoscaling ni SLO de
  producción.

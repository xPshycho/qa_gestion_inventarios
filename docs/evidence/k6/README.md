# Evidencia k6

- Nombre: smoke autenticado de lectura.
- Fecha: 30 de julio de 2026 UTC.
- Entorno: Compose local aislado.
- Comando: `./tests/performance/run-local.sh`.
- Resultado: 31 requests, 0 % error, 100 % checks, p95 127.58 ms, p99
  205.06 ms, todos los thresholds PASS.
- Evidencia: `test-results/performance/k6/`.
- Interpretación: sanidad de rendimiento con 1 VU/30 s.
- Requisito: performance testing.
- Limitaciones: no representa capacidad, stress, soak ni producción; perfil
  load no se ejecutó en esta auditoría.

# Evidencia de coverage

- Nombre: coverage backend unit/integración y frontend unit.
- Fecha: 30 de julio de 2026 UTC.
- Entorno: host local; frontend en contenedor Playwright fijado.
- Comandos: Gradle JaCoCo indicados en `docs/12-coverage.md` y
  `./frontend/scripts/test-local.sh`.
- Resultado: backend unit 90.97 % líneas; integración 60.52 %; frontend
  83.63 %. Todos los gates aprobaron.
- Evidencia nativa: `backend/build/reports/jacoco/` y `frontend/coverage/`.
- Interpretación: cobertura sobre el código ejecutado por cada suite; no es una
  medida directa de calidad.
- Requisito: Full Stack Testing/coverage e issue #91.
- Limitaciones: paths de build se regeneran; branch integración 33.12 %.

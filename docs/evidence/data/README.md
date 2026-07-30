# Evidencia de calidad de datos

| Campo | Valor |
|---|---|
| Nombre | Integridad, migraciones y dataset determinista |
| Fecha | 29/30 de julio de 2026 |
| Entorno | PostgreSQL 16 efímero mediante Testcontainers |
| Comando | `cd backend && ./gradlew integrationTest jacocoIntegrationTestReport jacocoIntegrationTestCoverageVerification --no-daemon` |
| Resultado | 17/17 pruebas de integración; gate de cobertura aprobado |
| Requisito | Pruebas de datos, migraciones, constraints y seeds |

## Qué se comprobó

- ocho migraciones Flyway aplicadas;
- cuatro productos base, 24 productos demo y al menos 45 movimientos demo;
- siete permisos, cuatro roles y cuatro usuarios seed con relaciones completas;
- movimientos `INITIAL` coherentes con el stock;
- rechazo de SKU duplicado, stock negativo, clave foránea inexistente y delta
  incoherente.

Referencias verificables:

| Ruta | Líneas aproximadas | Componente | Responsabilidad |
|---|---:|---|---|
| `backend/src/integrationTest/java/com/pucmm/inventory/integration/DataIntegrityIntegrationTest.java` | 13-140 | `DataIntegrityIntegrationTest` | seeds, relaciones y constraints |
| `backend/src/integrationTest/java/com/pucmm/inventory/integration/FlywayMigrationIntegrationTest.java` | 10-111 | `FlywayMigrationIntegrationTest` | migraciones y cantidades deterministas |

## Dónde consultar

- HTML:
  `backend/build/reports/tests/integrationTest/index.html`;
- XML:
  `backend/build/test-results/integrationTest/`;
- cobertura:
  `backend/build/reports/jacoco/integrationTest/html/index.html`;
- explicación por ambiente:
  [`docs/testing/data-quality.md`](../../testing/data-quality.md).

Retención local: hasta `clean` o una nueva ejecución. En GitHub Actions:
artifact `test-results-backend-integration-<run_number>` del run; la evidencia
remota concreta está en [Pipeline](../pipeline/README.md).

## Interpretación y limitaciones

La suite demuestra integridad contra una base vacía y migrada de forma
reproducible. No demuestra el contenido ni la conectividad de la base efectiva
de producción. Esa comprobación permanece **Pendiente de verificación** porque
no se obtuvo OS Login a la VM.

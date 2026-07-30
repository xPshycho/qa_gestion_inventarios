# Evidencia de pruebas exploratorias

| Campo | Valor |
|---|---|
| Nombre | Charters manuales de productos, stock, auditoría, seguridad, reportes y observabilidad |
| Fecha | 25 de julio de 2026 |
| Entorno | Development local, commit `9efa2ab1a621d0b68d8f19d698bccca7977b2f76` |
| Resultado | 6 charters, 6 sesiones, 32 artefactos; ejecución completada con defectos |
| Requisito | Pruebas exploratorias y evidencia de flujos principales |

El reporte completo, los oráculos, pasos, hallazgos y limitaciones están en
[`docs/testing/exploratory-testing.md`](../../testing/exploratory-testing.md).
Es evidencia histórica versionada y no se presenta como retest final de
staging.

## Galería curada

- [Producto creado](../../testing/evidence/exploratory/2026-07-25/EXP-PROD-01-02-producto-creado.png)
- [Validación de stock insuficiente](../../testing/evidence/exploratory/2026-07-25/EXP-STOCK-01-02-salida-insuficiente-validada.png)
- [Trazabilidad de producto y stock](../../testing/evidence/exploratory/2026-07-25/EXP-AUD-01-01-trazabilidad-producto-stock.png)
- [Matriz de roles y permisos](../../testing/evidence/exploratory/2026-07-25/EXP-SEC-01-02-matriz-roles-permisos.png)
- [Dashboard con datos](../../testing/evidence/exploratory/2026-07-25/EXP-REP-01-01-dashboard-datos-exploratorios.png)
- [Targets Prometheus UP](../../testing/evidence/exploratory/2026-07-25/EXP-OBS-01-02-prometheus-targets-up.png)
- [Alerta controlada en firing](../../testing/evidence/exploratory/2026-07-25/EXP-OBS-01-04-alerta-backend-down-firing.png)

El directorio fuente contiene 18 PNG, 13 JSON y un log sanitizado. No contiene
contraseñas, access tokens, refresh tokens ni cookies según el registro de la
ejecución.

## Interpretación y limitaciones

La ejecución demuestra los flujos y conserva evidencia visual/estructurada,
pero encontró defectos y se realizó en development. El retest final en staging,
después de confirmar correcciones, es **Pendiente de verificación**.

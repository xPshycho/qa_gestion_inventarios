# Evidencia E2E

- Nombre: Playwright local completo.
- Fecha: 30 de julio de 2026 UTC.
- Entorno: `inventory-e2e-local`, Compose aislado.
- Comando: `pnpm --dir tests/e2e test`.
- Resultado: 20/20 PASS en 42.2 s; Chromium, Firefox, WebKit,
  mobile/tablet/desktop, login, CRUD, stock, roles, auditoría, a11y y teclado.
- Evidencia: `test-results/e2e/playwright/summary.{json,md}`, JUnit y capturas
  controladas bajo `evidence/`.
- Interpretación: flujos críticos aprobaron con dependencias reales.
- Requisito: E2E, responsive, seguridad y accesibilidad.
- Limitaciones: el stack se destruyó al finalizar; trace/video solo se retiene
  localmente ante fallo y puede contener sesión.

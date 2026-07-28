# Accesibilidad, teclado, responsive y navegadores

Esta guía documenta la suite del issue #90 y la evidencia que produce.

## Alcance

Las vistas críticas son:

- login;
- dashboard;
- productos;
- movimientos de stock;
- auditoría;
- seguridad.

La suite combina cuatro capas:

| Archivo | Objetivo |
|---|---|
| `specs/accessibility.spec.ts` | axe con reglas WCAG A/AA y bloqueo de impactos críticos o serios. |
| `specs/keyboard.spec.ts` | Login por teclado, skip link, diálogo, focus trap, retorno de foco, ordenamiento y errores. |
| `specs/responsive.spec.ts` | Reflow, overflow y solapamientos en mobile, tablet y desktop. |
| `specs/browser-compatibility.spec.ts` | Recorrido de las seis vistas en Chromium, Firefox y WebKit. |

## Ejecución

Desde `tests/e2e`:

```bash
pnpm install --frozen-lockfile
pnpm exec playwright install --with-deps chromium firefox webkit
pnpm run test:issue-90
```

Para ejecutar una dimensión:

```bash
pnpm run test:a11y
pnpm run test:keyboard
pnpm run test:responsive
pnpm run test:browsers
```

La URL predeterminada es `http://localhost:5173`. Puede cambiarse con
`E2E_BASE_URL`. Use `E2E_MANAGE_STACK=false` si el stack ya está levantado.

## Matrices

Navegadores:

- Chromium;
- Firefox;
- WebKit.

Viewports:

- Pixel 7, aproximadamente 412x839;
- tablet 768x1024;
- desktop 1440x900.

El proyecto `chromium` ejecuta la suite funcional, axe y teclado. Los proyectos
`browser-*` ejecutan solo compatibilidad y los proyectos `responsive-*`
ejecutan solo las comprobaciones de layout.

## Criterios de fallo

La ejecución falla cuando:

- axe encuentra una violación crítica o seria;
- un flujo no se puede completar exclusivamente con el teclado;
- el foco escapa del diálogo o no vuelve al activador;
- faltan estados ARIA esperados;
- el documento presenta overflow horizontal;
- el header o contenido principal sale del viewport;
- el header solapa el contenido;
- una vista crítica no carga en alguno de los tres motores.

## Evidencia

El reporter `ux-evidence-reporter.ts` copia únicamente adjuntos JSON con nombres
controlados y genera:

- `ux-evidence/summary.json`;
- `ux-evidence/summary.md`;
- evidencia JSON por pantalla, navegador y viewport.

El reporte HTML y JUnit permanecen en:

- `playwright-report/index.html`;
- `test-results/playwright-results.xml`.

GitHub Actions publica todo dentro del artifact
`playwright-e2e-<run_number>`. Jenkins archiva los mismos directorios. Staging
usa el reporter seguro, desactiva trazas y video sensibles, y guarda la
evidencia del issue bajo `post-deploy/e2e/`.

## Interpretación

Un resultado verde demuestra que no se conocen violaciones axe críticas o
serias en el alcance probado, que los flujos seleccionados funcionan con
teclado y que las vistas no presentan los defectos automatizados de layout.
No reemplaza una evaluación manual exhaustiva con tecnologías de asistencia.

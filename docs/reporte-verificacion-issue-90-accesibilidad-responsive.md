# Reporte final de verificación del issue #90

## Accesibilidad, usabilidad, responsive y compatibilidad

- **Fecha de verificación:** 27 de julio de 2026 (`America/Santo_Domingo`)
- **Repositorio:** `xPshycho/qa_gestion_inventarios`
- **Rama de trabajo:** `test/final-a11y-responsive-ux`
- **Base dependiente:** `3b2dd561a1269666ba30210cd05bda40aac28383` (PR #111 hacia `develop`)
- **Pull request:** [#112 hacia `develop`](https://github.com/xPshycho/qa_gestion_inventarios/pull/112) (draft hasta integrar #111)
- **Issue:** [#90 - Validación de accesibilidad, usabilidad y responsive final](https://github.com/xPshycho/qa_gestion_inventarios/issues/90)
- **Resultado técnico:** **COMPLETO Y APROBADO**

## 1. Decisión ejecutiva

La implementación del issue #90 está completa en el árbol de trabajo revisado.

La suite automatizada cubre login, dashboard, productos, stock, auditoría y
seguridad; valida WCAG A/AA con axe, navegación exclusiva por teclado, gestión
de foco, errores en línea, tablas ordenables, tres tamaños de pantalla y los
motores Chromium, Firefox y WebKit.

La ejecución integral final obtuvo:

- **17/17 pruebas Playwright aprobadas**;
- **0 violaciones axe**, incluidas 0 críticas y 0 serias, en las seis vistas;
- **30 registros JSON** específicos de accesibilidad y UX;
- **18 validaciones/capturas responsive**: seis vistas por tres viewports;
- compatibilidad de las seis vistas aprobada en Chromium, Firefox y WebKit;
- **32 capturas PNG** en el reporte completo;
- build de producción del frontend aprobado;
- suite unitaria completa de Angular aprobada: **64/64**.

La ejecución multinavegador se realizó con la imagen oficial
`mcr.microsoft.com/playwright:v1.60.0-noble`, equivalente al entorno
reproducible configurado para CI.

## 2. Fuentes y alcance

Se aplicaron como fuentes principales:

| Fuente | Uso |
|---|---|
| `proyecto_final_v3.md` y `Proyecto_Final_V3.pdf` | Requisitos de entrega final y evidencia QA. |
| `proyecto_final_division.md` y los PDF de división | Responsabilidades, trazabilidad y Definition of Done. |
| `docs/issues-dependency-report.md` | Dependencias y secuencia de cierre; #59 ya no bloquea #90. |
| Issue de GitHub #90 | Alcance técnico y criterios de aceptación específicos. |
| `Avance_Proyecto_V3 (2).pdf` | Contexto histórico únicamente; no sustituye la entrega final. |

La comprobación se centró en:

- seis pantallas críticas;
- accesibilidad automática WCAG A/AA;
- operación por teclado;
- foco y anuncios accesibles;
- errores de formulario;
- tablas ordenables;
- reflow, overflow y solapamientos;
- mobile, tablet y desktop;
- Chromium, Firefox y WebKit;
- publicación reproducible de resultados.

## 3. Matriz de aceptación

| Criterio del issue #90 | Estado | Evidencia |
|---|---:|---|
| Suite reproducible de accesibilidad/usabilidad | **Cumple** | `@axe-core/playwright`, scripts dedicados y configuración Playwright versionada. |
| Pantallas críticas sin violaciones críticas conocidas | **Cumple** | Login, dashboard, productos, stock, auditoría y seguridad: 0 violaciones axe. |
| Flujos principales operables con teclado | **Cumple** | Login, skip link, modal, focus trap, Escape, retorno de foco, ordenamiento y validación de Seguridad. |
| Sin overflow horizontal ni solapamientos | **Cumple** | Seis vistas en 412x839, 768x1024 y 1440x900. |
| Evidencia publicada por CI | **Cumple** | HTML, JUnit, capturas y `ux-evidence` se archivan en GitHub Actions y Jenkins. |
| Compatibilidad multinavegador | **Cumple** | Las seis vistas funcionan en Chromium, Firefox y WebKit. |

## 4. Correcciones aplicadas

### Navegación y foco

- Se agregó un enlace visible al recibir foco para saltar al contenido
  principal.
- Cada cambio de ruta actualiza el título del documento y mueve el foco al
  contenido principal.
- La navegación activa expone `aria-current="page"`.
- El indicador global `:focus-visible` tiene contraste y grosor perceptibles.
- Se conserva `prefers-reduced-motion`.

### Productos

- La tabla publica `aria-sort` y nombres accesibles que describen la acción de
  ordenamiento.
- El diálogo de eliminación usa focus trap, foco inicial seguro en Cancelar,
  cierre con Escape y retorno del foco al elemento activador.
- Tras eliminar, el foco se mueve a una acción estable en vez de quedar
  perdido.

### Formularios y estados

- Seguridad muestra errores por campo, `aria-invalid`, alerta de resumen y
  foco automático en el primer campo inválido.
- Los estados de carga se anuncian de forma no intrusiva con `aria-live`.
- Las barras de progreso tienen nombres accesibles.
- Todas las vistas críticas exponen un `main` enfocable con identificador
  estable.

### Automatización y evidencia

- Se incorporó `@axe-core/playwright`.
- Se añadieron pruebas de accesibilidad, teclado, responsive y compatibilidad.
- Se creó un reporter que admite únicamente adjuntos JSON controlados y
  produce `summary.json` y `summary.md`.
- El reporter seguro de staging admite capturas controladas del issue #90 sin
  relajar el control de evidencia sensible.
- GitHub Actions instala los tres motores y publica la evidencia.
- Jenkins instala los tres motores y archiva la evidencia.
- El post-deploy de staging ejecuta axe/teclado y la matriz responsive
  Chromium; la matriz completa multinavegador queda en GitHub Actions y
  Jenkins.

## 5. Matriz automatizada final

| Dimensión | Cobertura | Resultado |
|---|---|---:|
| axe WCAG | 6 vistas | 6/6, 0 violaciones |
| Teclado y foco | 3 flujos críticos | 3/3 |
| Browser compatibility | 3 motores x 6 vistas | 3/3 recorridos |
| Responsive | 3 viewports x 6 vistas | 18/18 |
| Suite Playwright completa | 17 casos | 17/17 |

Viewports:

- mobile: Pixel 7, aproximadamente 412x839;
- tablet: 768x1024 con soporte táctil;
- desktop: 1440x900.

En cada vista responsive se comprueba que:

- el documento no produzca overflow horizontal;
- el contenido principal esté dentro del viewport;
- el header permanezca dentro del viewport;
- el header no solape el contenido principal.

## 6. Reproducción

Desde `tests/e2e`:

```bash
pnpm install --frozen-lockfile
pnpm exec playwright install --with-deps chromium firefox webkit
pnpm run test:issue-90
```

Comandos parciales:

```bash
pnpm run test:a11y
pnpm run test:keyboard
pnpm run test:responsive
pnpm run test:browsers
```

La aplicación debe estar disponible en `http://localhost:5173`; el helper
`ensure-stack.mjs` puede gestionar el stack cuando `E2E_MANAGE_STACK` no se
establece en `false`.

Salidas:

- `tests/e2e/playwright-report/index.html`;
- `tests/e2e/test-results/playwright-results.xml`;
- `tests/e2e/test-results/**`;
- `tests/e2e/ux-evidence/summary.json`;
- `tests/e2e/ux-evidence/summary.md`;
- archivos JSON por pantalla, navegador y viewport.

## 7. Evidencia local final

La evidencia reproducida el 28 de julio de 2026 UTC registró:

```text
17 passed (44.1s)
Angular unit tests: 64 passed
Playwright status: passed
UX evidence JSON: 30
Axe screens: 6
Axe violations: 0
Responsive checks: 18
Browsers: Chromium, Firefox, WebKit
```

Los directorios de resultados locales son artefactos efímeros ignorados por
Git; CI los vuelve a generar y publicar en cada ejecución.

## 8. Limitaciones conocidas

axe y Playwright detectan una parte importante de WCAG, pero no sustituyen una
evaluación humana completa con lectores de pantalla. No queda registrada
ninguna violación crítica o seria conocida dentro del alcance automatizado del
issue.

## 9. Conclusión

Los criterios técnicos y de evidencia del issue #90 están satisfechos. La
implementación está publicada en el PR #112 con `Closes #90`.

El PR permanece como draft hasta que #111 se fusione en `develop`; después
debe completarse la evidencia CI del SHA definitivo, la revisión cruzada y el
merge. El issue remoto se cerrará automáticamente con ese merge.

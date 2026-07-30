# Pruebas E2E con Playwright

## Configuración real

Ruta: `tests/e2e/playwright.config.ts`\
Líneas aproximadas: 1-122\
Componente: Playwright 1.60\
Responsabilidad: base URL, reporters, seguridad de artefactos, reintentos,
workers y proyectos.

| Propiedad | Local | CI/safe reporting |
|---|---|---|
| Base URL | `E2E_BASE_URL` o `http://localhost:5173` | variable del job |
| Workers | 1 | 1 |
| Paralelismo | deshabilitado | deshabilitado |
| Reintentos | 0 | 1 |
| HTML | sí | no |
| Screenshot automático | solo fallo | no |
| Trace/video | retener en fallo | no |
| JUnit | sí | sí |
| Evidencia UX controlada | sí | sí |

Proyectos: Chromium general, compatibilidad Chromium/Firefox/WebKit y
responsive mobile/tablet/desktop.

## Resultado auditado

`pnpm --dir tests/e2e test`: 20/20 PASS en 42.2 s, incluyendo login/logout,
CRUD, stock, permisos, auditoría, WCAG, teclado, los tres motores y tres
viewports. El stack `inventory-e2e-local` y volúmenes fueron eliminados al
final.

Resumen:
`test-results/e2e/playwright/summary.{json,md}`. JUnit:
`test-results/e2e/playwright/evidence/junit/playwright-results.xml`.

## Comandos

Desde la raíz, entorno completo aislado:

`Verificado · Requiere Docker`

```bash
pnpm --dir tests/e2e test
```

Los siguientes requieren que el stack ya esté disponible y dependencias
instaladas.

`Validado por scripts/config; headed no se ejecutó por ser interactivo`

```bash
cd tests/e2e
pnpm test:headed
pnpm test:ui
pnpm exec playwright test --debug
pnpm report
```

Ejecutar archivo/título/proyecto:

```bash
cd tests/e2e
pnpm exec playwright test specs/products-crud.spec.ts
pnpm exec playwright test --grep "permite completar el CRUD"
pnpm exec playwright test specs/browser-compatibility.spec.ts \
  --project=browser-firefox
pnpm exec playwright test --list
```

Actualizar snapshots:

```bash
cd tests/e2e
pnpm exec playwright test --update-snapshots
```

No se encontraron assertions de snapshot visual que requirieran actualización;
el comando es compatible con Playwright, pero su uso en este repo es
**No verificado**.

## Usuarios y variables

Los usernames por rol son no sensibles; passwords vienen de `.env`. El script
local inicia Keycloak/PostgreSQL real, espera health/OIDC y pasa variables sin
imprimir valores.

Variables principales: `E2E_BASE_URL`, URL/realm/client Keycloak, credentials
E2E por rol, directorios de JUnit/HTML/output y
`PLAYWRIGHT_SAFE_REPORTING`.

## Artefactos

| Tipo | Ruta local |
|---|---|
| HTML | `test-results/e2e/playwright/evidence/html/` |
| JUnit | `.../evidence/junit/playwright-results.xml` |
| screenshots controladas | `.../evidence/screenshots/` |
| UX JSON/MD | `.../evidence/ux/` |
| trace/video de fallo local | `.../evidence/artifacts/` |
| Compose diagnóstico | `.../evidence/docker/` |

En el run aprobado no se generó HTML final en el listado observado del
recolector y no hubo trace/video de fallo. Las capturas controladas cubren
escenarios, no secretos.

## Depuración segura

1. Repetir un archivo con `--headed` o `--debug`.
2. Abrir el reporte con `pnpm report` si existe HTML.
3. Revisar JUnit y `compose.log`.
4. Solo conservar trace/video local; puede contener tokens/sesiones.
5. No subir `.env`, storage state, cookies, HAR o HTML autenticado.

Si falta navegador, usar el camino Docker fijado. Si un puerto está ocupado,
detener el stack anterior o cambiar los puertos en el `.env` local; no apuntar
la suite CRUD a producción.

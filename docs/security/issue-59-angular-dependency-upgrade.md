# Issue #59: actualizacion de Angular y dependencias frontend

## Resumen

- Motivo: corregir las vulnerabilidades conocidas presentes en las dependencias de produccion del frontend y mantener una combinacion soportada de Angular, TypeScript y Node.js.
- Rama base: `develop` (`d95cfde`).
- Rama de trabajo: `security/carlos-angular-dependency-upgrade`.
- Fecha de ejecucion: 2026-07-11 (America/Santo_Domingo).
- pnpm: 10.12.1.
- Node.js: el host de diagnostico tenia 25.9.0, version no soportada por Angular 20. La instalacion y el build limpios se comprobaron con Node.js 22.23.1 en Docker. El proyecto declara Node.js 20.19+, 22.12+ o 24.x.
- Angular anterior: Core 19.2.25, CLI 19.2.27 y Material/CDK 19.2.19.
- Angular nuevo: Core 20.3.26, CLI 20.3.32 y Material/CDK 20.2.14.

La seleccion mantiene el cambio en Angular 20, la version mayor minima que corrige los advisories detectados por el audit, y evita una migracion adicional a Angular 21. No se usaron `--force`, `pnpm.overrides` ni ediciones manuales del lockfile.

## Dependencias actualizadas

| Dependencia | Version anterior | Version nueva | Motivo |
| ----------- | ---------------: | ------------: | ------ |
| `@angular/animations` | 19.2.25 | 20.3.26 | Alinear los paquetes oficiales con Angular Core corregido. |
| `@angular/common` | 19.2.25 | 20.3.26 | Corregir CVE-2026-54266 y CVE-2026-54268. |
| `@angular/compiler` | 19.2.25 | 20.3.26 | Corregir CVE-2026-54265. |
| `@angular/core` | 19.2.25 | 20.3.26 | Corregir CVE-2026-54267. |
| `@angular/forms` | 19.2.25 | 20.3.26 | Mantener compatibilidad entre paquetes Angular. |
| `@angular/platform-browser` | 19.2.25 | 20.3.26 | Mantener compatibilidad entre paquetes Angular. |
| `@angular/platform-browser-dynamic` | 19.2.25 | 20.3.26 | Mantener compatibilidad entre paquetes Angular. |
| `@angular/router` | 19.2.25 | 20.3.26 | Mantener compatibilidad y las rutas protegidas existentes. |
| `@angular/cdk` | 19.2.19 | 20.2.14 | Alinear CDK con Angular 20 y Angular Material. |
| `@angular/material` | 19.2.19 | 20.2.14 | Alinear la libreria de UI con Angular 20. |
| `@angular/cli` | 19.2.27 | 20.3.32 | Usar la CLI compatible con Angular 20. |
| `@angular-devkit/build-angular` | 19.2.27 | 20.3.32 | Usar builders compatibles y actualizar el toolchain transitivo. |
| `@angular/compiler-cli` | 19.2.25 | 20.3.26 | Alinear el compilador AOT con Angular Core. |
| `typescript` | 5.7.3 | 5.9.3 | Version compatible requerida por Angular 20.3. |

`rxjs` 7.8.2, `zone.js` 0.15.1 y `keycloak-js` 26.2.4 se conservaron porque son compatibles y no introducian los advisories de produccion. Se actualizo de forma dirigida la resolucion de Karma 6.4.4 para incorporar `engine.io` 6.6.9 y `ws` 8.21.0 sin ampliar el alcance a un cambio de runner.

## Vulnerabilidades

| Advisory | Severidad | Paquete | Ruta de dependencia | Estado | Justificacion |
| -------- | --------- | ------- | ------------------- | ------ | ------------- |
| [GHSA-rgjc-h3x7-9mwg](https://github.com/advisories/GHSA-rgjc-h3x7-9mwg) / CVE-2026-54267 | Alta | `@angular/core` | Dependencia directa de produccion | Corregida | La actualizacion de 19.2.25 a 20.3.26 elimina el advisory del audit. |
| [GHSA-48r7-hpm6-gfxm](https://github.com/advisories/GHSA-48r7-hpm6-gfxm) / CVE-2026-54268 | Alta | `@angular/common` | Dependencia directa de produccion | Corregida | La actualizacion de 19.2.25 a 20.3.26 elimina el advisory del audit. |
| [GHSA-39pv-4j6c-2g6v](https://github.com/advisories/GHSA-39pv-4j6c-2g6v) / CVE-2026-54266 | Alta | `@angular/common` | Dependencia directa de produccion | Corregida | La actualizacion de 19.2.25 a 20.3.26 elimina el advisory del audit. |
| [GHSA-58w9-8g37-x9v5](https://github.com/advisories/GHSA-58w9-8g37-x9v5) / CVE-2026-54265 | Moderada | `@angular/compiler` | Dependencia directa de produccion | Corregida | La actualizacion de 19.2.25 a 20.3.26 elimina el advisory del audit. |
| [GHSA-w5hq-g745-h8pq](https://github.com/advisories/GHSA-w5hq-g745-h8pq) / CVE-2026-41907 | Moderada | `uuid` 8.3.2 | `@angular-devkit/build-angular > webpack-dev-server > sockjs > uuid` | Riesgo residual de desarrollo | No aparece en `pnpm audit --prod` ni se incluye en la aplicacion estatica servida por Nginx. `sockjs` fija la rama 8 y no existe una actualizacion compatible directa del paquete padre en el toolchain actual. |
| [GHSA-64mm-vxmg-q3vj](https://github.com/advisories/GHSA-64mm-vxmg-q3vj) / CVE-2026-55602 | Moderada | `http-proxy-middleware` 2.0.9 | `@angular-devkit/build-angular > webpack-dev-server > http-proxy-middleware` | Riesgo residual de desarrollo | Solo pertenece al servidor de desarrollo; no aparece en `pnpm audit --prod`, no se empaqueta en el artefacto y la configuracion del proyecto no usa una tabla `router` vulnerable. |

Estado del audit:

- Antes, produccion: 3 vulnerabilidades altas y 1 moderada.
- Despues, produccion: 0 vulnerabilidades.
- Antes, audit completo: 15 altas, 10 moderadas y 3 bajas.
- Despues, audit completo: 0 altas, 2 moderadas y 0 bajas; ambas excepciones estan descritas arriba.

## Migraciones aplicadas

Comandos principales:

```bash
pnpm exec ng update @angular/core@20 @angular/cli@20
pnpm exec ng update @angular/material@20 --allow-dirty
pnpm update karma@6.4.4
```

`--allow-dirty` fue necesario porque el primer conjunto coherente de migraciones ya estaba presente en la rama; no sustituye verificaciones de peer dependencies y no equivale a `--force`.

La migracion oficial agrego en `frontend/angular.json` los valores explicitos de nombres y separadores que preservan el estilo previo de los schematics. Las migraciones de imports de `DOCUMENT`, `InjectFlags`, `TestBed.get` y bootstrap de servidor no encontraron usos que modificar. El proyecto ya utilizaba el application builder y `moduleResolution: bundler`; no se cambio el modelo de bootstrap, guards, interceptores, rutas, formularios ni integracion Keycloak. Las migraciones de Material/CDK tampoco requirieron cambios de codigo.

Una asercion unitaria se ajusto para comprobar el `href` publico renderizado en lugar del atributo de depuracion `ng-reflect-router-link`, que Angular 20 ya no garantiza. No se redujo ni desactivo cobertura.

## Validaciones

| Validacion | Resultado verificable |
| ---------- | --------------------- |
| Instalacion congelada local | PASS: `pnpm install --frozen-lockfile`. |
| Instalacion limpia compatible | PASS: Docker `node:22-alpine` (Node.js 22.23.1) instalo con `pnpm install --frozen-lockfile --ignore-scripts`. |
| Audit de produccion | PASS: `pnpm audit --prod`, 0 vulnerabilidades. |
| Audit completo | PASS respecto a severidad alta: 0 altas; permanecen 2 moderadas solo de desarrollo, justificadas en este documento. |
| Build local | PASS: `pnpm build`; bundle inicial 772.25 kB. |
| Build Docker | PASS con Node.js 22.23.1 y el Dockerfile oficial. |
| Presupuesto de bundle | WARN preexistente: 772.25 kB supera el warning de 600 kB por 172.25 kB, pero permanece por debajo del limite de error de 1 MB. La linea base era 779.20 kB. |
| Lint | NO DISPONIBLE: el frontend no define script ni configuracion de ESLint. |
| Unit tests | PASS: 62/62 con `CHROME_BIN=/usr/bin/chromium pnpm test`. Sin `CHROME_BIN`, la linea base no podia localizar Chrome en este host. |
| Cobertura | PASS, sin regresion: statements 73.14 %, branches 50.22 %, functions 75.12 % y lines 73.04 %. |
| Docker Compose | PASS: `GRAFANA_PORT=23000 docker compose config --quiet` y stack final saludable. Solo se movio Grafana porque el puerto 3000 del host estaba ocupado; los puertos funcionales oficiales no se cambiaron. |
| Playwright | PASS: 8/8 antes y 8/8 despues, usando Chromium y el stack oficial. |
| Login y logout Keycloak | PASS mediante `specs/auth.spec.ts`. |
| Navegacion y permisos | PASS mediante `specs/roles.spec.ts` y la validacion de acceso denegado de auditoria. |
| Listado y CRUD de productos | PASS mediante `specs/products-crud.spec.ts`; cubre listado, creacion, edicion y eliminacion. |
| Stock y auditoria | PASS mediante `specs/stock-movements.spec.ts` y `specs/audit.spec.ts`. |
| Responsive existente | PASS mediante el proyecto Playwright `mobile-chromium`. |
| Jenkins remoto | NO EJECUTADO: se revisaron estaticamente sus comandos Node 22/pnpm, pero el job esta asociado a la rama compartida y no se lanzo desde esta rama. |

El primer intento aislado de Compose encontro el puerto 3000 ocupado por otro servicio local. Un intento de mover tambien los puertos de frontend y Keycloak demostro que el realm limita correctamente los redirects a `http://localhost:5173`. La validacion reproducible mantuvo los puertos oficiales de frontend, backend y Keycloak y cambio unicamente Grafana a 23000.

## Workarounds y riesgos residuales

### `uuid` transitivo del servidor de desarrollo

- Problema: GHSA-w5hq-g745-h8pq permanece en `uuid` 8.3.2 a traves de SockJS.
- Solucion temporal: no exponer `ng serve` como runtime; produccion continua usando el bundle estatico en Nginx.
- Motivo: forzar `uuid` 11 sobre un consumidor que declara la rama 8 puede romper su API y no es una solucion compatible demostrada.
- Riesgo: moderado y limitado al entorno local de desarrollo.
- Revision: issue #58 y cada actualizacion de `@angular-devkit/build-angular`; retirar cuando `webpack-dev-server`/`sockjs` adopten una version corregida compatible.

### `http-proxy-middleware` transitivo del servidor de desarrollo

- Problema: GHSA-64mm-vxmg-q3vj permanece en la version 2.0.9 del toolchain.
- Solucion temporal: no usar el servidor de desarrollo en produccion ni configuraciones proxy con tablas `router` controlables por datos externos.
- Motivo: no hay una actualizacion compatible directa disponible en el paquete padre instalado y el artefacto de produccion no contiene este modulo.
- Riesgo: moderado, de desarrollo, condicionado a una configuracion que el proyecto no utiliza.
- Revision: issue #58 y la siguiente version compatible del builder; retirar al actualizar el paquete padre a una resolucion corregida.

### Version de Node.js del host

Node.js 25.9.0 permitio el diagnostico local, pero Angular 20 lo marca como no soportado. `frontend/package.json` y el README ahora expresan las ramas soportadas; Docker y CI usan Node.js 22. El resultado reproducible de Node.js 22.23.1 es la evidencia autoritativa.

El warning de presupuesto del bundle ya existia antes de la actualizacion y mejoro en 6.95 kB. No se modificaron presupuestos para ocultarlo; su optimizacion no forma parte de #59.

## Dependencias posteriores

- #90 puede validar accesibilidad y responsive sobre la version de Angular que se integrara.
- #58 puede ejecutar los scans finales partiendo de un audit de produccion sin vulnerabilidades y dar seguimiento a las dos herramientas de desarrollo.
- #88 puede integrar `pnpm install --frozen-lockfile`, `pnpm audit --prod`, build, unit tests y Playwright sobre un lockfile reproducible.

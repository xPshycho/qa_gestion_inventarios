# Issue #89 - Pruebas exploratorias manuales

## Estado del reporte

| Campo | Valor |
|---|---|
| Issue | [#89 - Pruebas exploratorias manuales con charters y evidencias](https://github.com/xPshycho/qa_gestion_inventarios/issues/89) |
| Fecha de ejecución | 25 de julio de 2026 |
| Zona horaria | `America/Santo_Domingo` (`UTC-04:00`) |
| Rama evaluada | `develop` |
| Commit evaluado | `9efa2ab1a621d0b68d8f19d698bccca7977b2f76` |
| Ambiente | Development local con Docker Compose |
| Resultado | **Ejecución local completada con defectos; no apto todavía para cerrar #89 como evidencia final** |

Este documento consolida los charters, las notas de sesión, la matriz de riesgos, los
hallazgos, las decisiones de no-fix y las evidencias de la ejecución manual solicitada
por #89. No sustituye la repetición final en staging cuando se complete #86.

## Veredicto ejecutivo

Antes de esta ejecución, `develop` no contenía charters, sesiones, ledger de hallazgos
ni evidencias manuales versionadas para #89. La ejecución produjo:

- seis charters, uno por cada módulo crítico solicitado;
- seis registros de sesión con ambiente, fecha, duración activa, usuarios, pasos y resultado;
- 32 artefactos: 18 capturas PNG, 13 registros JSON y un log sanitizado;
- respuestas de API, SQL y resultados de Prometheus, Tempo, Loki y Alertmanager;
- un ledger con cuatro defectos reproducibles, una discrepancia de contrato y
  observaciones residuales;
- una prueba controlada de alerta `pending -> firing -> inactive`;
- trazabilidad entre los requisitos finales, las sesiones y las evidencias.

El issue **no debe cerrarse todavía** por estas razones:

1. #86, que debe proporcionar staging/post-deploy, continúa abierto.
2. #90, que debe estabilizar accesibilidad, usabilidad y responsive, continúa abierto.
3. Se encontraron defectos reales de prioridad alta y media que no han sido corregidos.
4. GitHub rechazó la creación de issues derivados con `403 Resource not accessible by integration`;
   no se inventaron números de issues y los candidatos quedaron documentados en este reporte.
5. La rama remota `test/final-exploratory-charters` y su PR hacia `develop` no existen.
6. Por instrucción expresa para esta ejecución, no se creó rama, commit ni Pull Request.

La dependencia estricta #85 ya está cerrada, por lo que el charter de observabilidad sí
pudo ejecutarse localmente. El resultado local sirve como evidencia previa y como base
reproducible para el retest final.

## Fuentes de requisitos

Se tomaron como fuentes vigentes:

- `proyecto_final_v3.md:84-224`, para productos, stock, auditoría, reportes y seguridad;
- `proyecto_final_v3.md:292-296`, que exige charters, bugs y escenarios explorados;
- `proyecto_final_v3.md:326-362`, para observabilidad, telemetría y alertas;
- `proyecto_final_v3.md:392-404`, que exige casos, resultados y defectos en la guía de pruebas;
- `proyecto_final_v3.md:442-460`, para reportes de pruebas y evidencias QA;
- `proyecto_final_division.md:540-567`, para trazabilidad por issue, rama, PR y evidencia;
- `proyecto_final_division.md:889-890` y `:952-957`, para exploratory charters, bugs y evidencias;
- `proyecto_final_division.md:1188-1225`, para la Definition of Done del PR;
- `proyecto_final_division.md:1377-1393`, para el flujo de bugs derivados;
- `docs/issues-dependency-report.md`, para el orden y las dependencias actuales;
- `proyecto_final_division_edwin_carlos_2.pdf`, páginas 4 y 8-11, como versión PDF consolidada.

Los archivos `Proyecto_Final_V3.pdf`, `Avance_Proyecto_V3 (2).pdf` y
`proyecto_final_division_edwin_carlos.pdf` no están presentes en este checkout. El
archivo `avance_proyecto.md` fue excluido del oráculo porque el solicitante indicó que
el avance ya no está vigente. La evaluación se realizó contra la entrega final.

## Estado de GitHub y dependencias

Estado consultado el 25 de julio de 2026:

| Issue | Estado | Impacto sobre #89 |
|---|---|---|
| #55 Headers y CORS | Cerrado | Base de seguridad integrada |
| #58 Security testing | Cerrado | Base de seguridad integrada |
| #59 Angular/dependencias | Cerrado | Frontend actualizado |
| #85 Observabilidad | Cerrado | Dependencia estricta satisfecha |
| #86 Staging/post-deploy | **Abierto** | Obliga a repetir la evidencia final en staging |
| #87 Data testing | Cerrado | Migraciones y dataset final integrados |
| #88 Pipeline final | **Abierto** | Riesgo de cambios posteriores al commit evaluado |
| #90 A11y/usabilidad/responsive | **Abierto** | Puede cambiar UI y corregir un hallazgo de foco |
| #91 Documentación final | **Abierto** | Debe consolidar este reporte al final |
| #92 Secretos/credenciales | **Abierto** | Puede cambiar configuración de ambientes |

## Ambiente y datos

### Línea base

| Elemento | Valor observado |
|---|---|
| Sistema operativo | Linux `7.1.3-arch1-2`, x86_64 |
| Docker | `29.6.1` |
| Docker Compose | `5.3.1` |
| Navegador | Chromium `150.0.7871.114` |
| Viewport principal | `1440 x 900` |
| Locale / timezone del navegador | `es-DO` / `America/Santo_Domingo` |
| Proyecto Compose | `inventory-platform` |
| Frontend | `http://127.0.0.1:5173` |
| Backend | `http://127.0.0.1:8080` |
| Keycloak | `http://localhost:8081` |
| Prometheus | `http://127.0.0.1:9090` |
| Grafana | `http://127.0.0.1:3300` |
| Loki | `http://127.0.0.1:3100` |
| Tempo | `http://127.0.0.1:3200` |
| Alertmanager | `http://127.0.0.1:9093` |

El puerto documentado de Grafana, `3000`, estaba ocupado en el host. Grafana se publicó
temporalmente en `3300` mediante `GRAFANA_PORT=3300`, sin editar archivos.

El `.env` local ignorado por Git todavía contenía `OTEL_SDK_DISABLED=true`, mientras
`.env.example` y la configuración final versionada usan `false`. El primer pase dejó
esta desviación registrada. El segundo pase recreó solamente el backend con el override
temporal `OTEL_SDK_DISABLED=false`; el log confirmó:

```text
OpenTelemetry Spring Boot starter (2.28.1) has been started
```

No se almacenaron contraseñas, access tokens, refresh tokens ni cookies en las evidencias.

### Usuarios y dataset

| Usuario | Rol efectivo | Uso en la sesión |
|---|---|---|
| `carlos` | `INVENTORY_ADMIN` | CRUD, stock, auditoría, seguridad y reportes |
| `viewer` | `INVENTORY_VIEWER` | Lectura de reportes/productos y accesos negativos |
| `auditor` | `AUDIT_REVIEWER` | Consulta de auditoría y acceso negativo a reportes |
| Anónimo | Sin sesión | Login inválido y protección de recursos |

El volumen se creó durante esta ejecución con 28 productos seed. Se creó el producto
temporal:

```text
id=29
sku=EXP89-20260725
stock=7
minimumStock=7
```

El producto se conserva en el volumen local para reproducir los defectos de trazabilidad
y borrado. No afecta archivos ni migraciones del repositorio.

## Matriz de riesgos

| Riesgo | Módulo | Probabilidad | Impacto | Cobertura aplicada | Residual |
|---|---|---:|---:|---|---|
| R-01 | Productos | Media | Alta | Límites, duplicado, edición y borrado con historial | Defecto F-03 abierto |
| R-02 | Stock | Alta | Alta | Cero, entrada, salida, insuficiencia, mínimo y ajuste | Concurrencia no explorada |
| R-03 | Auditoría | Media | Alta | Alta/edición/movimientos, actor, valores y permisos | Producto borrado no auditable por bloqueo de FK |
| R-04 | Seguridad | Baja | Crítica | Login inválido, logout, guards y matriz de roles | Refresh/expiración necesita sesión prolongada |
| R-05 | Reportes | Alta | Alta | Reconciliación con DB, ranking y permisos | Defecto F-02 abierto |
| R-06 | Observabilidad | Alta | Crítica | Targets, métricas, logs, trazas y alerta real | Defecto F-05 abierto |
| R-07 | Ambiente | Alta | Alta | Registro de SHA, puertos y override OTel | Staging #86 no disponible |
| R-08 | UI | Media | Media | Consola y foco de confirmación | Hallazgo F-04 debe incorporarse a #90 |

## Charters

### EXP-PROD-01 - Productos

**Misión:** explorar el ciclo de vida de un producto y sus límites para descubrir
inconsistencias entre catálogo, validaciones, persistencia y borrado.

**Probes:** búsqueda por SKU, orden por precio, paginación, valores negativos, alta,
SKU duplicado, edición, borrado sin pérdida silenciosa de historial y errores de consola.

**Oráculos:** requisitos de productos, restricciones HTML, respuesta HTTP, catálogo,
base de datos y mensajes de la UI.

**Criterio de salida:** alta y edición observables, duplicado rechazado y política de
borrado reproducida con su status HTTP.

### EXP-STOCK-01 - Stock

**Misión:** explorar invariantes de existencias y trazabilidad de entradas, salidas y
ajustes alrededor del stock mínimo.

**Probes:** stock inicial, cantidad cero, entrada `+3`, salida `-3`, salida mayor al
disponible, ajuste a `6`, restauración a `7`, alerta crítica y actor.

**Oráculos:** stock anterior/nuevo, delta, reglas `>= 1`, historial, catálogo y auditoría.

**Criterio de salida:** ninguna operación inválida modifica stock y todas las operaciones
válidas posteriores al alta quedan en el historial.

### EXP-AUD-01 - Auditoría

**Misión:** comprobar que el alta, edición y movimientos son reconstruibles y que el
permiso `audit:view` se aplica en navegación y deep links.

**Probes:** revisión inicial, edición de nombre/precio, cuatro movimientos, orden,
actor, timestamps, lectura con `auditor` y acceso directo con `viewer`.

**Oráculos:** timeline de Envers, historial de stock y matriz de permisos.

**Criterio de salida:** valores anteriores/nuevos y actor reproducibles; usuario sin
permiso redirigido a `/forbidden`.

### EXP-SEC-01 - Seguridad

**Misión:** explorar autenticación, logout, visibilidad por permisos y administración
de la matriz de roles sin modificar usuarios demo.

**Probes:** credencial inválida, sesión de administrador, `viewer`, `auditor`, deep
links, navegación disponible, 401 anónimo, logout y consola.

**Oráculos:** Keycloak, permisos del token aplicados por la aplicación, guards y endpoints.

**Criterio de salida:** ningún rol obtiene una pantalla fuera de sus permisos y el login
inválido no crea sesión.

### EXP-REP-01 - Reportes

**Misión:** reconciliar el dashboard con la base de datos y comprobar que sus rankings
representan el indicador anunciado.

**Probes:** totales, activos/inactivos, críticos, unidades, valor, movimientos, historial
reciente, ranking, actualización y permisos `report:view`.

**Oráculos:** consultas SQL, payload `/reports/dashboard`, requisitos finales y UI.

**Criterio de salida:** métricas exactas y semántica de ranking verificable.

### EXP-OBS-01 - Observabilidad

**Misión:** comprobar la cadena métrica-log-traza-alerta con servicios reales, no solo
la presencia de contenedores.

**Probes:** salud, targets, métrica de negocio, histograma P95, LogQL, TraceQL, dashboard,
correlation ID y alerta `InventoryBackendDown`.

**Oráculos:** APIs de Prometheus/Loki/Tempo/Alertmanager, dashboard provisionado y logs
del backend.

**Criterio de salida:** target `UP`, una traza consultable, paneles con datos y alerta
`firing/resolved` demostrable.

## Registro de sesiones

Las acciones manuales se ejecutaron de forma secuencial; algunos charters se
intercalaron para reutilizar el mismo dato de prueba y validar sus efectos entre
módulos. “Duración” representa tiempo activo.

Todas las filas heredan la fecha, zona horaria, SHA, navegador, viewport y URLs de la
sección de ambiente. Las sesiones fueron dirigidas paso a paso y no ejecutaron un spec
prefabricado; las decisiones, variaciones y oráculos se eligieron durante cada sesión.
El tiempo activo excluye arranque del stack, autenticaciones repetidas y consolidación
posterior de evidencias.

| Sesión | Inicio local | Fin local | Duración | Usuarios | Resultado |
|---|---:|---:|---:|---|---|
| EXP-PROD-01 | 10:28 | 11:08 | 6 min activos en tres pases | `carlos` | Pass con F-03/F-04 |
| EXP-STOCK-01 | 10:31 | 10:33 | 2 min | `carlos` | Pass con discrepancia F-01 |
| EXP-AUD-01 | 10:33 | 10:35 | 2 min | `carlos`, `auditor`, `viewer` | Pass |
| EXP-SEC-01 | 10:35 | 10:37 | 2 min | Anónimo, `viewer`, `auditor`, `carlos` | Pass con observación |
| EXP-REP-01 | 10:37 | 10:38 | 1 min | `carlos`, `viewer`, `auditor` | Pass con F-02 |
| EXP-OBS-01 | 10:40 | 11:15 | 22 min activos en tres pases | `carlos`, Grafana admin y tráfico anónimo controlado | Parcial con F-05 |

### Notas EXP-PROD-01

1. El catálogo cargó 28 productos, 10 por página.
2. La búsqueda `MON-` devolvió exactamente tres monitores.
3. El segundo clic en orden por precio devolvió `26,800`, `18,900`, `14,250`.
4. Precio, stock y mínimo negativos fueron rechazados por `min=0`.
5. Se creó `EXP89-20260725`; el total subió a 29.
6. Una segunda alta con el mismo SKU fue rechazada con conflicto y mensaje explícito.
7. Se editaron nombre y precio; catálogo y auditoría reflejaron ambos cambios.
8. El borrado del producto con movimientos mostró un mensaje comprensible, pero el API
   devolvió HTTP 500 por `DataIntegrityViolationException`, tres de tres intentos.
9. Abrir la confirmación produjo dos excepciones de foco en consola.

**Resultado:** operaciones principales utilizables, con defectos de manejo HTTP y foco.

**Evidencia:**

- [Catálogo baseline](evidence/exploratory/2026-07-25/EXP-PROD-01-01-catalogo-baseline.png)
- [Producto creado](evidence/exploratory/2026-07-25/EXP-PROD-01-02-producto-creado.png)
- [SKU duplicado](evidence/exploratory/2026-07-25/EXP-PROD-01-03-sku-duplicado-validado.png)
- [Error al borrar con historial](evidence/exploratory/2026-07-25/EXP-PROD-01-04-eliminar-con-historial-error.png)
- [Respuesta HTTP 500](evidence/exploratory/2026-07-25/EXP-PROD-01-delete-with-history-response.json)
- [Eventos de consola sanitizados](evidence/exploratory/2026-07-25/browser-console-events.json)

### Notas EXP-STOCK-01

1. El producto recién creado tenía stock `7`, mínimo `7`, estado crítico y `0 movimientos`.
2. La cantidad cero fue rechazada por `min=1` y no generó historial.
3. Una entrada de `3` cambió `7 -> 10`, delta `+3`, actor `Carlos Hernandez`.
4. Una salida de `3` cambió `10 -> 7`, delta `-3`, y reactivó la alerta crítica.
5. Una salida de `8` sobre stock `7` fue rechazada; el stock permaneció en `7`.
6. Un ajuste cambió `7 -> 6`, delta `-1`.
7. Un segundo ajuste restauró `6 -> 7`, delta `+1`.
8. El historial final mostró cuatro movimientos posteriores al alta, en orden descendente.

**Resultado:** invariantes y alerta correctas; el alta con existencia inicial no queda
explicada por el historial.

**Evidencia:**

- [Stock inicial sin movimiento](evidence/exploratory/2026-07-25/EXP-STOCK-01-01-stock-inicial-sin-movimiento.png)
- [Salida insuficiente rechazada](evidence/exploratory/2026-07-25/EXP-STOCK-01-02-salida-insuficiente-validada.png)
- [Historial y alerta](evidence/exploratory/2026-07-25/EXP-STOCK-01-03-historial-y-alerta.png)

### Notas EXP-AUD-01

1. El alta del producto quedó registrada con todos sus valores iniciales.
2. Los cuatro movimientos generaron cuatro revisiones de stock y revisiones correlativas
   del stock actual del producto.
3. La edición produjo una revisión adicional con nombre y precio anterior/nuevo.
4. El usuario `auditor` pudo leer seis revisiones de producto y cuatro de stock.
5. El usuario `auditor` no recibió acciones de editar/eliminar.
6. El usuario `viewer` fue redirigido de `/productos/29/auditoria` a `/forbidden`.

**Resultado:** trazabilidad de los cambios posteriores al alta y autorización correctas.

**Evidencia:**

- [Trazabilidad de producto y stock](evidence/exploratory/2026-07-25/EXP-AUD-01-01-trazabilidad-producto-stock.png)
- [Lectura con rol auditor](evidence/exploratory/2026-07-25/EXP-AUD-01-02-lectura-rol-auditor.png)
- [Acceso negado a viewer](evidence/exploratory/2026-07-25/EXP-AUD-01-03-viewer-sin-permiso.png)

### Notas EXP-SEC-01

1. Una contraseña inválida para `viewer` no creó sesión.
2. `viewer` vio Dashboard y Productos, sin alta, edición, borrado, auditoría ni Seguridad.
3. `auditor` vio Productos, Auditoría y Movimientos; no pudo abrir Dashboard.
4. `carlos` abrió la administración con cuatro usuarios, cuatro roles compuestos y los
   siete permisos mínimos.
5. Los deep links no autorizados terminaron en `/forbidden`.
6. El logout devolvió a `/login`.
7. Las solicitudes sin bearer token recibieron 401.
8. No se crearon, deshabilitaron ni reasignaron usuarios para evitar alterar las cuentas
   compartidas del ambiente demo.

**Resultado:** matriz y guards coherentes. Queda como riesgo residual la renovación y
expiración de una sesión de larga duración.

**Observación:** durante los flujos alojados en Keycloak aparecieron textos en inglés y
el navegador registró bloqueos CSP no funcionales. Se difiere su evaluación visual a
#90 y no se debilitó la CSP.

**Evidencia:**

- [Login inválido](evidence/exploratory/2026-07-25/EXP-SEC-01-01-login-invalido.png)
- [Matriz de roles y permisos](evidence/exploratory/2026-07-25/EXP-SEC-01-02-matriz-roles-permisos.png)
- [Eventos de consola sanitizados](evidence/exploratory/2026-07-25/browser-console-events.json)

### Notas EXP-REP-01

La UI y la base de datos coincidieron en:

| Indicador | Valor |
|---|---:|
| Total productos | 29 |
| Activos | 26 |
| Inactivos | 3 |
| Críticos activos | 12 |
| Unidades | 314 |
| Valor | DOP 3,161,160.00 |
| Movimientos | 57 |

La reconciliación del ranking detectó una inconsistencia:

- la UI colocó primero `EXP89-20260725` con 4 movimientos y 8 unidades;
- `PAPER-A4-500` tenía 95 unidades movidas, pero apareció quinto;
- el resultado está ordenado por número de movimientos, aunque la UI anuncia
  “Productos más movidos - por unidades”;
- el requisito final pide “Productos más vendidos”, no cantidad de eventos.

`viewer` pudo consultar el dashboard sin acciones administrativas. `auditor`, que no
posee `report:view`, fue redirigido a `/forbidden`.

**Resultado:** totales correctos; ranking semánticamente incorrecto.

**Evidencia:**

- [Dashboard con datos exploratorios](evidence/exploratory/2026-07-25/EXP-REP-01-01-dashboard-datos-exploratorios.png)
- [Dashboard con viewer](evidence/exploratory/2026-07-25/EXP-REP-01-02-dashboard-rol-viewer.png)
- [Payload del dashboard](evidence/exploratory/2026-07-25/EXP-REP-01-dashboard-response.json)
- [Reconciliación SQL de solo lectura](evidence/exploratory/2026-07-25/EXP-REP-01-database-reconciliation.json)

### Notas EXP-OBS-01

1. El verificador alcanzó Prometheus, Grafana, Loki, Tempo y Alertmanager.
2. Prometheus mostró `inventory-backend` e `inventory-keycloak` en estado `UP`.
3. Las cinco reglas cargaron con `health=ok`.
4. Con OpenTelemetry habilitado, Tempo devolvió trazas de `inventory-backend`.
5. Prometheus devolvió un vector vacío tanto para `inventory_products_critical` como
   para el selector completo `{__name__=~"inventory_.*"}`.
6. La consulta P95 versionada basada en `http_server_requests_seconds_bucket` devolvió
   un vector vacío.
7. La consulta LogQL versionada `{container=~".*backend.*"}` devolvió cero streams.
8. El dashboard final mostró backend `1`, pero P95, negocio, logs y trazas sin datos.
9. Se detuvo únicamente el backend a las 10:54:23.
10. `InventoryBackendDown` cambió a `pending` y luego a `firing`; Alertmanager recibió
    una alerta crítica a las 10:55:38.
11. Se restauró el backend; quedó `healthy`, la regla regresó a `inactive` y Alertmanager
    quedó sin alertas activas.
12. En un segundo pase a las 11:07, una solicitud con
    `X-Correlation-ID: exploratory-89-delete-03` recibió el mismo header de respuesta.
    El error SQL incluyó `traceId`, `spanId`, correlation ID y endpoint; `user` quedó
    vacío y la línea final del servlet perdió el contexto MDC.
13. Un snapshot posterior, a las 11:13, confirmó backend `UP`, target `1`, regla
    `inactive/ok` y cero alertas activas. A las 11:14 se repitieron las consultas
    PromQL vacías.

**Resultado:** salud, trazas por API y ciclo de alerta correctos; dashboard final y
métricas/logs de negocio incompletos.

**Evidencia:**

- [Dashboard con paneles vacíos](evidence/exploratory/2026-07-25/EXP-OBS-01-01-dashboard-paneles-sin-datos.png)
- [Targets de Prometheus UP](evidence/exploratory/2026-07-25/EXP-OBS-01-02-prometheus-targets-up.png)
- [Alertmanager sin alertas](evidence/exploratory/2026-07-25/EXP-OBS-01-03-alertmanager-sin-alertas.png)
- [BackendDown firing](evidence/exploratory/2026-07-25/EXP-OBS-01-04-alerta-backend-down-firing.png)
- [Targets Prometheus JSON](evidence/exploratory/2026-07-25/EXP-OBS-01-prometheus-targets.json)
- [Reglas Prometheus JSON](evidence/exploratory/2026-07-25/EXP-OBS-01-prometheus-rules.json)
- [Métrica de negocio vacía](evidence/exploratory/2026-07-25/EXP-OBS-01-prometheus-business-metric.json)
- [Consultas PromQL del dashboard](evidence/exploratory/2026-07-25/EXP-OBS-01-prometheus-dashboard-queries.json)
- [Consulta Loki vacía](evidence/exploratory/2026-07-25/EXP-OBS-01-loki-dashboard-query.json)
- [Búsqueda de trazas Tempo](evidence/exploratory/2026-07-25/EXP-OBS-01-tempo-search.json)
- [Extracto de arranque y correlación](evidence/exploratory/2026-07-25/EXP-OBS-01-backend-correlation.log)
- [Alerta activa JSON](evidence/exploratory/2026-07-25/EXP-OBS-01-alertmanager-firing.json)
- [Alerta resuelta JSON](evidence/exploratory/2026-07-25/EXP-OBS-01-alertmanager-resolved.json)
- [Estado final post-incidente](evidence/exploratory/2026-07-25/EXP-OBS-01-final-state.json)

## Ledger de hallazgos

Escala: **Alta** bloquea confianza en una función o evidencia final; **Media** degrada
contrato, diagnóstico o accesibilidad sin impedir el flujo principal; **Baja** es una
observación no bloqueante.

| ID | Tipo | Módulo | Severidad | Reproducción | Estado |
|---|---|---|---|---:|---|
| F-01 | Discrepancia de contrato | Stock/Auditoría | Media | 1/1 | Decisión de producto pendiente; alta en GitHub bloqueada por 403 |
| F-02 | Defecto | Reportes | Alta | 2/2 refresh | Issue candidato; alta en GitHub bloqueada por 403 |
| F-03 | Defecto | Productos/API | Media | 3/3 | Issue candidato; alta en GitHub bloqueada por 403 |
| F-04 | Defecto | UI/A11y | Media | 2/2 | Debe incorporarse a #90 |
| F-05 | Defecto | Observabilidad | Alta | 2/2 pases visuales | Issue candidato; alta en GitHub bloqueada por 403 |
| O-01 | Observación | Seguridad/UI | Baja | Repetida | No-fix en #89; retest en #90 |
| R-01 | Riesgo | Ambiente | Alta | N/A | Repetir todo en staging #86 |

### F-01 - El alta con stock inicial no crea movimiento INITIAL

**Oráculo compuesto:** el requisito final exige cantidad inicial y un historial de
entradas/salidas, pero no ordena textualmente crear un movimiento para el alta. El
dominio sí define `INITIAL`, la UI lo etiqueta, el dashboard lo cuenta y los productos
seed lo usan; la suite de datos exige esa consistencia para los productos base.

**Actual:** el producto nace con stock `7` y `0 movimientos`. Los productos seed sí
poseen movimientos `INITIAL`, por lo que hay dos modelos de trazabilidad distintos.

**Impacto:** historial y conteo `initialMovements` no tienen la misma semántica para
productos seed y productos creados por la UI. Envers sí conserva los valores del alta.

**Clasificación:** discrepancia que requiere una decisión de producto. Si `INITIAL`
forma parte del contrato general, debe corregirse como defecto atómico; si solo aplica
al seed, debe documentarse y cubrirse con prueba.

**Issue candidato:** `[DECISION] Alinear el alta interactiva con la semántica de movimiento INITIAL`.

**Labels propuestos:** `area:functionality`, `area:testing`, `priority:high`.

### F-02 - El ranking por unidades se ordena por cantidad de eventos

**Esperado:** el ranking debe representar “más vendidos” o, como mínimo, ordenar por las
unidades que anuncia.

**Actual:** 8 unidades con cuatro eventos aparecen por encima de 95 unidades con dos
eventos.

**Impacto:** el dashboard puede inducir decisiones de inventario incorrectas.

**Issue candidato:** `[BUG] El dashboard ordena productos movidos por eventos y no por unidades/vendidos`.

**Labels propuestos:** `type:bug`, `area:functionality`, `area:testing`, `priority:high`.

### F-03 - Borrar un producto con historial devuelve HTTP 500

**Esperado:** preservar el historial y responder un conflicto de dominio, por ejemplo
HTTP 409, con payload estable.

**Actual:** la FK evita el borrado correctamente, pero la excepción no se traduce y el
API devuelve 500. La UI oculta el detalle con un mensaje genérico.

**Impacto:** error de servidor falso, ruido en alertas y contrato API inestable.

**Issue candidato:** `[BUG] DELETE de producto con movimientos devuelve 500 en vez de conflicto`.

**Labels propuestos:** `type:bug`, `area:functionality`, `area:testing`.

### F-04 - La confirmación de borrado lanza una excepción de foco

**Esperado:** el botón de confirmar recibe foco sin errores.

**Actual:** cada apertura registró
`TypeError: Cannot read properties of undefined (reading 'focus')`.

**Impacto:** foco inicial no fiable para teclado/lector de pantalla y consola contaminada.

**Trazabilidad:** debe agregarse como caso concreto de #90. No se propone un issue
separado para evitar duplicar el trabajo de accesibilidad aún abierto.

### F-05 - El dashboard final de observabilidad muestra paneles vacíos

**Esperado:** con targets `UP` y tráfico real, los paneles de latencia, negocio, logs y
trazas deben contener datos.

**Actual:**

- el selector PromQL `inventory_*` devuelve un vector vacío;
- la consulta P95 versionada devuelve un vector vacío;
- la consulta LogQL versionada con `container` devuelve cero streams;
- Tempo contiene trazas, pero el panel provisionado indica `No data found in response`;
- en una solicitud autenticada el error SQL conserva traza, correlación y endpoint, pero
  `user` queda vacío y la línea final del servlet pierde todo el contexto MDC.

**Impacto:** la infraestructura parece sana, pero el dashboard no permite diagnosticar
negocio, latencia ni correlación.

**Issue candidato:** `[BUG] Dashboard final de observabilidad queda sin métricas, logs ni trazas`.

**Labels propuestos:** `type:bug`, `area:observability`, `area:testing`, `priority:high`.

### O-01 - Localización y CSP de Keycloak

Durante los flujos de autenticación alojados en Keycloak aparecieron textos en inglés y
el navegador agrupó 28 errores de evento inline bloqueado por CSP. El archivo de consola
no conserva URL por evento, por lo que no se atribuye cada mensaje a un componente
concreto. La autenticación funcionó y no se recomienda debilitar la política. Se
documenta para evaluar localización e integración en #90.

## Decisiones de no-fix y límites

| Decisión | Justificación | Retest/owner |
|---|---|---|
| No permitir cascade delete del historial | Preservar auditoría es correcto; F-03 solo pide traducir el conflicto | Equipo de Productos |
| No editar `.env` local | Es un archivo ignorado y el charter se repitió con override explícito | #86/#92 |
| No debilitar CSP por los mensajes de Keycloak | No hubo fallo funcional y reducir CSP sería un riesgo de seguridad | #90 |
| No modificar usuarios demo | Evita invalidar sesiones compartidas y otras pruebas | Repetir en staging aislado |
| No disparar CPU, latencia y error-rate | Son pruebas más invasivas/largas; las reglas cargaron sanas | Staging #86 |
| No probar concurrencia de stock en dos sesiones | Quedó fuera del timebox local | Siguiente ciclo exploratorio |
| No corregir defectos en esta entrega | El alcance solicitado fue reporte/evidencia, sin cambiar el proyecto | Issues derivados |
| No crear rama/commit/PR | Instrucción expresa de esta ejecución | Responsable `Code-Hdez` |

## Reproducción

### Stack local

```bash
docker compose up --build --wait --wait-timeout 300 -d

# Si 3000 está ocupado:
GRAFANA_PORT=3300 docker compose up -d grafana

# Pase final de trazas sin editar .env:
OTEL_SDK_DISABLED=false GRAFANA_PORT=3300 \
  docker compose up -d --force-recreate backend

GRAFANA_PORT=3300 ./scripts/verify-observability.sh
```

### Reconciliación del dashboard

```sql
SELECT
  COUNT(*) AS total_products,
  COUNT(*) FILTER (WHERE status = 'ACTIVE') AS active_products,
  COUNT(*) FILTER (WHERE status = 'INACTIVE') AS inactive_products,
  COUNT(*) FILTER (
    WHERE status = 'ACTIVE' AND current_stock <= minimum_stock
  ) AS active_critical,
  SUM(current_stock) AS units_in_stock,
  SUM(price * current_stock) AS inventory_value,
  (SELECT COUNT(*) FROM stock_movements) AS total_movements
FROM products;
```

### Consultas de observabilidad

```text
PromQL: up{job="inventory-backend"}
PromQL: inventory_products_critical
PromQL: {__name__=~"inventory_.*"}
PromQL: histogram_quantile(0.95,
        sum(rate(http_server_requests_seconds_bucket{job="inventory-backend"}[5m])) by (le))
LogQL:  {container=~".*backend.*"}
TraceQL: { resource.service.name = "inventory-backend" }
```

La prueba `InventoryBackendDown` detiene el backend durante más de un minuto. Solo debe
repetirse en un ambiente aislado y debe terminar verificando backend `healthy`, regla
`inactive` y cero alertas activas.

## Matriz de aceptación de #89

| Criterio | Estado | Evidencia / brecha |
|---|---|---|
| Al menos un charter por módulo crítico | **Cumplido** | Seis charters: productos, stock, auditoría, seguridad, reportes y observabilidad |
| Sesión con ambiente, usuario, fecha, pasos y resultado | **Cumplido localmente** | Registro de sesiones y notas por charter |
| Defectos con issue o justificación | **Parcial / bloqueado** | F-04 pendiente de agregar a #90; cuatro registros derivados pendientes por 403 |
| Documentación reproducible y auditable | **Cumplido** | SHA, entorno, datos, pasos, oráculos y archivos de evidencia |
| Evidencias organizadas para el PR | **Cumplido en filesystem** | `docs/testing/evidence/exploratory/2026-07-25/`; todavía no existe PR |

### Condiciones de cierre

1. Crear `test/final-exploratory-charters` desde el `develop` definitivo.
2. Crear la decisión F-01 y los issues derivados F-02, F-03 y F-05.
3. Agregar F-04 a #90.
4. Corregir o aceptar formalmente cada defecto, con owner y fecha.
5. Completar #86 y repetir los seis charters sobre staging.
6. Repetir especialmente stock concurrente, expiración/refresh, usuarios aislados y los
   cinco tipos de alerta.
7. Actualizar este reporte con URLs de staging, nuevos timestamps y resultados de retest.
8. Abrir PR hacia `develop`, incluir `Closes #89`, evidencias, pruebas ejecutadas y revisión
   cruzada.

### Estado al finalizar

- Backend restaurado y `healthy`.
- Prometheus volvió a reportar el backend `UP`.
- `InventoryBackendDown` volvió a `inactive`.
- Alertmanager quedó sin alertas activas.
- Grafana permanece accesible en `http://127.0.0.1:3300`.
- No se modificó código, configuración, dependencias ni migraciones.
- No se creó rama, commit ni PR.
- El producto temporal se conserva en el volumen local para retest.

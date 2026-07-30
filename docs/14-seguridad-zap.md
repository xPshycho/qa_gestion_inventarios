# Seguridad dinámica: OWASP ZAP

## Alcance real

La suite combina dos recorridos aislados:

- `zap-baseline.py`: spider tradicional y análisis pasivo del frontend;
- `zap-api-scan.py`: importación OpenAPI y análisis activo de la API con JWT
  efímero de `viewer`, usuario sin permisos de mutación.

Ruta: `tests/security/run-zap-baseline.sh`\
Líneas aproximadas: 13-58\
Componente: gate ZAP\
Responsabilidad: ejecuta ZAP 2.17.0 fijado por digest, produce JSON/Markdown y
falla solo si el JSON contiene alertas con `riskcode >= 3` (High).

Ruta: `tests/security/run-zap-api-scan.sh`\
Componente: gate API autenticado\
Responsabilidad: añade el bearer token sin persistirlo, importa
`/v3/api-docs`, ejecuta active scan y aplica el mismo gate de cero High.

## Ejecución auditada

Fecha UTC: 30 de julio de 2026.\
Entorno: Compose local aislado, target `http://localhost:5173`.\
Comando: `./tests/security/run-local.sh`.\
Resultado del gate: PASS, cero alertas High.

El baseline inspeccionó ocho URLs: 62 reglas PASS, cero fallos y cinco
categorías Warning. El active scan importó 29 URLs del contrato OpenAPI con un
JWT efímero de sólo lectura: 118 reglas PASS, cero fallos y cero Warning.

ZAP reportó cinco categorías Warning:

1. `Server` revela versión/información;
2. contenido almacenable/cacheable;
3. CSP permite `style-src 'unsafe-inline'`;
4. detección informativa de aplicación web moderna;
5. Cross-Origin-Embedder-Policy ausente/inválido.

No se clasificaron automáticamente como falsos positivos. El hallazgo “Modern
Web Application” es informativo; los demás requieren análisis de impacto y
compatibilidad antes de corregir.

## Reportes

| Formato | Ruta |
|---|---|
| JSON | `test-results/security/zap/evidence/reports/zap-baseline-report.json` |
| Markdown | `test-results/security/zap/evidence/reports/zap-baseline-report.md` |
| API JSON | `test-results/security/zap/evidence/reports/zap-api-report.json` |
| API Markdown | `test-results/security/zap/evidence/reports/zap-api-report.md` |
| Config/reglas | `test-results/security/zap/evidence/reports/zap.yaml` |
| Resumen | `test-results/security/zap/summary.{json,md}` |
| Diagnóstico Compose | `test-results/security/zap/evidence/docker/` |

HTML se excluye deliberadamente porque el gate de seguridad de artefactos
rechaza evidencia renderizable.

## Ejecución

`Verificado · Requiere Docker · no usar contra producción`

```bash
./tests/security/run-local.sh
```

Ejecución directa:

`Integrada y verificada mediante run-local · requiere stack y variables`

```bash
ZAP_TARGET_URL=http://localhost:5173 \
ZAP_DOCKER_NETWORK=host \
ZAP_REPORT_DIR="$PWD/test-results/security/zap/evidence/reports" \
  ./tests/security/run-zap-baseline.sh
```

## Criterio y limitaciones

El criterio automatizado actual es “cero High”. Los Warning no hacen fallar.
No confundir PASS del gate con ausencia de vulnerabilidades.

El active scan usa `viewer`: puede alcanzar recursos autenticados de lectura,
pero recibe `403` ante POST/PUT/DELETE. Así evita mutar datos y complementa las
pruebas específicas de JWT, permisos, CORS y autenticación. No sustituye una
prueba Ajax del flujo visual OIDC ni autoriza ejecutarlo sobre producción.

## Otras validaciones de la misma suite

- Headers: PASS; evidencia en
  `test-results/security/headers/evidence/headers.txt`.
- Trivy 0.70.0: PASS; cero HIGH/CRITICAL corregibles en repositorio, backend
  image y frontend image con `--ignore-unfixed`.

Trivy descargó bases vigentes al momento del run. El resultado envejece con
nuevos CVE; repetir en cada cambio de dependencias/imágenes.

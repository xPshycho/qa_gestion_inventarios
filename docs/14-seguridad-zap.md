# Seguridad dinámica: OWASP ZAP

## Alcance real

El repositorio ejecuta `zap-baseline.py`: spider tradicional de 2 minutos y
passive scan contra el frontend. No usa contexto autenticado, Ajax Spider ni
active scan. Por tanto, el resultado no cubre endpoints autenticados ni
vulnerabilidades que requieren payload activo.

Ruta: `tests/security/run-zap-baseline.sh`\
Líneas aproximadas: 13-58\
Componente: gate ZAP\
Responsabilidad: ejecuta ZAP 2.17.0 fijado por digest, produce JSON/Markdown y
falla solo si el JSON contiene alertas con `riskcode >= 3` (High).

## Ejecución auditada

Fecha UTC: 30 de julio de 2026.\
Entorno: Compose local aislado, target `http://localhost:5173`.\
Comando: `./tests/security/run-local.sh`.\
Resultado del gate: PASS, cero alertas High.

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

`No verificado por separado · requiere stack y variables`

```bash
ZAP_TARGET_URL=http://localhost:5173 \
ZAP_DOCKER_NETWORK=host \
ZAP_REPORT_DIR="$PWD/test-results/security/zap/evidence/reports" \
  ./tests/security/run-zap-baseline.sh
```

## Criterio y limitaciones

El criterio automatizado actual es “cero High”. Los Warning no hacen fallar.
No confundir PASS del gate con ausencia de vulnerabilidades.

Para cumplir una evaluación activa/autenticada:

**Pendiente de verificación/implementación**

- crear un contexto ZAP que autentique vía OIDC sin exponer tokens;
- spider/Ajax Spider de rutas autorizadas;
- active scan solo en un staging aislado con datos desechables;
- excluir logout/acciones destructivas justificadamente;
- triage por severidad, evidencia y falso positivo;
- publicar JSON/Markdown tras safety scan.

No se ejecutó active scan porque podría mutar datos y el usuario pidió solo
documentación.

## Otras validaciones de la misma suite

- Headers: PASS; evidencia en
  `test-results/security/headers/evidence/headers.txt`.
- Trivy 0.70.0: PASS; cero HIGH/CRITICAL corregibles en repositorio, backend
  image y frontend image con `--ignore-unfixed`.

Trivy descargó bases vigentes al momento del run. El resultado envejece con
nuevos CVE; repetir en cada cambio de dependencias/imágenes.

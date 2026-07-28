# Verificación final del issue #92 — Secret hardening

## Dictamen

**Implementación del repositorio: COMPLETA Y PUBLICADA.**

**Cierre del issue: pendiente únicamente de dos controles externos: constancia
de revocación del token histórico de SonarQube Cloud y revisión cruzada.**

Al 28 de julio de 2026 se corrigieron los hallazgos documentados en
`docs/reporte-auditoria-issue-92-secret-hardening.md`, se creó la rama exclusiva
desde `origin/develop`, se ejecutaron las pruebas locales y se abrió el
[PR #113](https://github.com/xPshycho/qa_gestion_inventarios/pull/113) hacia
`develop`.

El PR permanece en draft deliberadamente. El código no puede demostrar ni
ejecutar la revocación de una credencial en la cuenta externa de otra persona,
y no sería correcto cerrar #92 sin esa constancia.

## Identificación

| Campo | Resultado |
| --- | --- |
| Fecha de corte | 2026-07-28 01:21 AST (`America/Santo_Domingo`) |
| Repositorio | `xPshycho/qa_gestion_inventarios` |
| Base | `origin/develop` en `9efa2ab1a621d0b68d8f19d698bccca7977b2f76` |
| Rama | `security/final-secret-hardening` |
| PR | [#113 hacia `develop`](https://github.com/xPshycho/qa_gestion_inventarios/pull/113) |
| SHA técnico verificado | `f944d64c552c14da7b04923f20105c2b8d1d2b44` |
| Relación con la base | 0 commits detrás, 3 delante al abrir el PR |
| Mergeabilidad inicial | `MERGEABLE` |
| Revisión | `REVIEW_REQUIRED` |
| Issue #92 | Enlazado mediante `Closes #92` |

La rama se creó directamente desde `origin/develop`. No contiene los commits
de los issues #86 ni #90 que existían en la rama de trabajo anterior.

## Implementación realizada

### Secretos y configuración

- El token literal de SonarQube Cloud fue eliminado de
  `infra/jenkins/jenkins.yaml`. JCasC no crea credenciales Sonar.
- `.env.example` y `.env.jenkins.example` conservan valores sensibles vacíos.
- `scripts/security/init-secret-env.sh` genera secretos aleatorios, no los
  imprime, escribe con permisos `0600` y permite rotarlos.
- Docker Compose, Jenkins Compose y Spring Boot fallan si falta un secreto
  requerido.
- El realm de Keycloak usa placeholders de entorno para el client secret y las
  cuatro contraseñas E2E.
- Las pruebas backend usan passwords y client secrets sintéticos aleatorios por
  ejecución.
- Los E2E leen sus contraseñas del entorno o del `.env` ignorado y fallan con
  un mensaje explícito si no están disponibles.
- Se eliminaron las copias generadas inseguras de `backend/bin/` y el
  directorio quedó ignorado.

### Prevención

- `Secret Scanning / Gitleaks` usa Gitleaks 8.30.1, reglas oficiales sin
  allowlists amplias y acciones fijadas a commits inmutables.
- El scanner no publica comentarios, summaries ni artifacts con detecciones.
- La plantilla de PR exige gate, rotación redactada y revisión cruzada.
- SonarCloud valida `SONAR_TOKEN` en contextos confiables y no expone secretos
  a PR de forks.
- Jenkins recibe `sonarcloud-token` únicamente desde Credentials y usa
  `withCredentials` con trazado de shell desactivado.

### Evidencia segura

- Playwright desactiva HTML, screenshots automáticos, traces y videos en CI.
- Jenkins archiva el JUnit E2E solo después del safety.
- Los workflows Playwright y Security Testing verifican JUnit, diagnósticos
  Docker y reportes Trivy/ZAP antes de subirlos.
- `verify-artifacts.sh` y `scan-artifacts.py` detectan secretos configurados en
  texto, Base64 y Basic auth, además de JWT, ZIP y gzip. También rechazan
  enlaces simbólicos y formatos de alto riesgo.

### Jenkins reproducible

La validación real detectó y corrigió el contexto de build incorrecto del
servicio auxiliar `docker-images`. Después de la corrección:

- la imagen Jenkins construyó correctamente;
- el daemon Docker interno y Jenkins quedaron `healthy`;
- JCasC creó `inventory-avance-ci`;
- el job expone `GIT_BRANCH` con default `develop` y `RUN_SONAR=false`;
- el SCM acepta la rama confiable seleccionada;
- el almacén de credenciales del Jenkins limpio contiene cero credenciales
  Sonar, tal como exige la externalización.

## Evidencia local

| Comprobación | Resultado |
| --- | --- |
| `./gradlew test integrationTest --no-daemon` | **PASS** — 119 unitarias y 15 de integración |
| Build de imágenes del stack principal | **PASS** |
| Stack principal completo | **PASS** — todos los servicios `healthy` |
| Playwright `--list` en modo seguro | **PASS** — 8 pruebas descubiertas |
| Playwright contra el stack | **PASS** — 8/8 |
| JUnit Playwright sin trace/video/HAR/HTML | **PASS** |
| Safety del JUnit | **PASS** — 2 payloads inspeccionados |
| Rechazo de un artifact que contiene secretos configurados | **PASS** |
| Compose base con `.env` externo | **PASS** |
| Jenkins Compose con `.env.jenkins` externo | **PASS** |
| Templates vacíos | **PASS** — ambos Compose fallan de forma segura |
| Jenkins/JCasC real | **PASS** — build e inicio healthy |
| Bash, Python, JSON y YAML | **PASS** |
| `git diff --check origin/develop...HEAD` | **PASS** |

Después del E2E se destruyeron los volúmenes efímeros del stack principal y se
rotaron otra vez las credenciales locales. Los valores nunca se mostraron.

## Secret scanning

Se usó Gitleaks 8.30.1 con redacción total:

| Alcance | Resultado |
| --- | --- |
| Commit actual versionado | **PASS** — 0 hallazgos |
| Worktree completo que Git permitiría añadir | **PASS** — 0 hallazgos |
| Tres commits `origin/develop..f944d64` | **PASS** — 0 hallazgos |
| Check remoto `Secret Scanning / Gitleaks` del PR #113 | **PASS** |

La historia compartida conserva el commit que introdujo el token histórico.
No se reescribió porque eso rompería referencias compartidas y, por sí solo,
no revocaría la credencial. La mitigación correcta es su revocación en el
proveedor.

## Estado remoto al corte

Al abrir el PR:

- `Validate Conventional Commits`: **PASS**;
- `Secret Scanning / Gitleaks`: **PASS**;
- Backend, Frontend, Playwright, Security Testing, ZAP y SonarCloud:
  en ejecución;
- revisión cruzada: pendiente.

GitHub confirma que existe un repository secret llamado `SONAR_TOKEN`, pero su
fecha de actualización visible es `2026-06-04T00:31:50Z`, anterior al commit
que expuso el token el 18 de junio. Ese metadato no prueba rotación y no se
acepta como constancia de revocación.

## Matriz de aceptación

| Criterio | Estado | Evidencia |
| --- | --- | --- |
| No quedan secretos reales en el árbol propuesto | **PASS** | Gitleaks local y remoto |
| Jenkins y GitHub consumen credenciales externas | **PASS de configuración** | JCasC vacío, `withCredentials`, `secrets.SONAR_TOKEN` |
| Documentación de secretos y responsables | **PASS** | `docs/security/secrets-management.md` |
| Prevención de nuevos secretos | **PASS** | workflow Gitleaks y checklist de PR |
| Artifacts sin credenciales | **PASS local** | modo seguro y scanner recursivo |
| Rama exclusiva y PR hacia `develop` | **PASS** | `security/final-secret-hardening`, PR #113 |
| Commits convencionales | **PASS** | check remoto y tres commits atómicos |
| Revisión cruzada | **PENDIENTE EXTERNO** | requiere otro integrante |
| Token histórico revocado o invalidado | **PENDIENTE EXTERNO** | requiere propietario de SonarQube Cloud |
| Jenkins con token nuevo y `RUN_SONAR=true` | **PENDIENTE EXTERNO** | Jenkins limpio no posee el secreto |

## Condición exacta para cerrar #92

El propietario de SonarQube Cloud debe:

1. revocar el token histórico desde **My Account > Security**;
2. crear un reemplazo de menor alcance;
3. actualizar `SONAR_TOKEN` en GitHub y `sonarcloud-token` en Jenkins;
4. ejecutar SonarCloud y Jenkins con `RUN_SONAR=true`;
5. añadir al PR únicamente proveedor, nombre/ID, fecha, responsable y enlaces
   de runs exitosos, sin token, hash, log o captura sensible;
6. solicitar y obtener revisión cruzada.

Cumplidos esos controles y con los checks remotos verdes, el PR puede salir de
draft, fusionarse hacia `develop` y cerrar #92.

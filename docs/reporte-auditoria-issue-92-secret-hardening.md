# Reporte de verificación del issue #92

## Dictamen

**Estado: NO COMPLETO / BLOQUEANTE para la entrega final.**

Al 25 de julio de 2026, el contenido auditado de `develop` no satisface los
criterios de aceptación del issue
[#92](https://github.com/xPshycho/qa_gestion_inventarios/issues/92).
Existe una credencial de SonarCloud hardcodeada en un archivo versionado, no
hay evidencia de su rotación, falta prevención automática de nuevos secretos y
no existe la rama, el Pull Request ni la evidencia exigida para este issue.

Hay dos implementaciones parciales correctas:

- GitHub Actions consume `SONAR_TOKEN` desde `secrets.SONAR_TOKEN`.
- El `Jenkinsfile` consume el ID `sonarcloud-token` mediante
  `withCredentials`.

Estas dos referencias seguras no cierran el issue porque la configuración JCasC
de Jenkins sigue creando esa credencial con un valor literal versionado.

## Identificación de la revisión

| Campo | Valor |
|---|---|
| Fecha de auditoría | 2026-07-25, zona `America/Santo_Domingo` |
| Repositorio | `xPshycho/qa_gestion_inventarios` |
| Rama auditada | `develop` |
| `HEAD` auditado | `9efa2ab1a621d0b68d8f19d698bccca7977b2f76` |
| Relación con remoto | `HEAD = origin/develop` al iniciar la revisión |
| Issue | [#92 — Remover secretos hardcodeados y rotar credenciales expuestas](https://github.com/xPshycho/qa_gestion_inventarios/issues/92) |
| Rama exigida por el issue | `security/final-secret-hardening` |
| Destino exigido | `develop` |
| Naturaleza de la revisión | Solo lectura sobre código/configuración; este reporte es el único entregable creado |

El worktree ya contenía archivos añadidos al índice antes de esta auditoría.
No se alteraron, eliminaron ni des-stagearon. El escaneo del estado que podría
versionarse se hizo sobre una copia temporal exacta del índice Git, por lo que
también cubre esos archivos preexistentes.

## Fuentes documentales usadas

La fuente principal fue `proyecto_final_v3.md`, conforme a la indicación de que
el avance ya no es el criterio vigente.

| Documento solicitado | Estado en el workspace | Uso en esta revisión |
|---|---|---|
| `proyecto_final_v3.md` | Presente | Fuente principal de requisitos finales |
| `Proyecto_Final_V3.pdf` | No presente | Se utilizó su contraparte Markdown indicada por el usuario |
| `proyecto_final_division.md` | Presente | Reglas de ramas, commits, PR, revisión y evidencia |
| `proyecto_final_division_edwin_carlos.pdf` | No presente | Se revisó la variante disponible con sufijo `_2` |
| `proyecto_final_division_edwin_carlos_2.pdf` | Presente, 11 páginas | Contraste del documento final y su anexo operativo |
| `docs/issues-dependency-report.md` | Presente bajo `docs/` | Dependencias y condiciones especiales de cierre de #92 |
| `Avance_Proyecto_V3 (2).pdf` | No presente | No se usó como criterio final |
| `avance_proyecto.md` | Presente | Identificado como histórico; excluido del dictamen de requisitos |

Requisitos documentales relevantes:

- `proyecto_final_v3.md:364-384` exige SonarCloud/SonarQube, GitHub Actions,
  Jenkins y un pipeline completo.
- `proyecto_final_v3.md:406-420` exige gestión de secretos, variables de
  entorno y ausencia de credenciales hardcodeadas.
- `proyecto_final_division.md:1188-1225` exige issue enlazado, Conventional
  Commits, pruebas, evidencia, revisión cruzada, ausencia de secretos y quality
  gate.
- `proyecto_final_division.md:1292-1312` exige Jenkinsfile, workflows y
  evidencia de ejecución.
- `docs/issues-dependency-report.md:22-25` divide #92 en limpieza inicial y
  auditoría final.
- `docs/issues-dependency-report.md:98-100` exige repetir el escaneo después de
  los cambios de #88 y #86, validar credenciales externas y rotar valores
  expuestos.
- `docs/issues-dependency-report.md:159-167` impide considerar cerrada la
  cadena hasta completar ese rescan final.

## Metodología

Se realizaron las siguientes comprobaciones sin mostrar valores sensibles:

1. Estado de rama, índice, remoto, archivos rastreados e ignorados.
2. Revisión manual de `infra/jenkins/jenkins.yaml`, `Jenkinsfile`,
   `compose.jenkins.yml`, `.github/workflows/*.yml`, `.env`, `.env.example`,
   `.gitignore`, README y documentación de Jenkins.
3. Gitleaks `v8.28.0` sobre:
   - una copia temporal exacta del índice Git actual;
   - los 149 commits alcanzables del historial de `develop`.
4. Búsquedas adicionales de patrones de tokens, credenciales, claves privadas,
   contraseñas y mecanismos preventivos.
5. Consulta en vivo del issue, ramas, PR, comentarios y GitHub Actions.
6. Validación sintáctica de ambos archivos Compose con
   `docker compose ... config --quiet`.

No se intentó autenticar contra SonarCloud con la credencial expuesta. Hacerlo
reutilizaría un secreto comprometido y no demostraría su rotación de forma
segura.

## Evidencia del escaneo de secretos

### Índice Git actual

Comando equivalente ejecutado:

```bash
gitleaks dir <copia-temporal-del-indice> \
  --report-format=json \
  --redact=100 \
  --exit-code=0
```

Resultado:

```text
Versión: Gitleaks 8.28.0
Datos analizados: aproximadamente 1.57 MB
Hallazgos: 2

generic-api-key  infra/jenkins/jenkins.yaml:33
curl-auth-user   docs/reporte-verificacion-avance.md:41-46
```

El reporte JSON fue generado fuera del repositorio, con secretos redactados:

```text
SHA-256: 0d4de1fedb950c363b7c9a51e203c9e149b66144e5476901c0a36177fa07b0af
```

Interpretación:

- El primer hallazgo es la credencial SonarCloud versionada y es bloqueante.
- El segundo corresponde a autenticación básica de una demostración local en
  un reporte de avance preexistente y actualmente añadido al índice. Aunque no
  prueba una credencial productiva, impide presentar una salida limpia sin
  corregirlo o justificar una exclusión estrictamente limitada.
- El contenido del reporte de avance no se usó como fuente de requisitos, pero
  sí debe escanearse porque está preparado para ser versionado.

### Historial de `develop`

Resultado:

```text
Commits analizados: 149
Datos analizados: aproximadamente 1.55 MB
Hallazgos: 3

generic-api-key  infra/jenkins/jenkins.yaml
curl-auth-user   docs/observability/grafana.md
curl-auth-user   README.md
```

El reporte histórico redactado tuvo el siguiente hash:

```text
SHA-256: 91b7c22891f4c93d02e208ef6031261571477f6f9995d7977f829e5bfa69bf5d
```

Gitleaks atribuye la introducción de la credencial de Jenkins/SonarCloud al
commit:

```text
792b2f0d28a30e3cbe90f6957eca5919f8630956
fix(jenkins): arreglo del tests
2026-06-18T12:37:59-04:00
```

Ese commit es ancestro del `HEAD` auditado y el valor todavía está en el árbol
actual. Los dos hallazgos `curl-auth-user` históricos corresponden a comandos
locales; deben clasificarse o acotarse, pero no reducen la criticidad del token
que continúa presente.

Las búsquedas complementarias no encontraron firmas conocidas de tokens de
GitHub, AWS, Google, OpenAI o Slack, marcadores de claves privadas ni archivos
de claves habituales (`.pem`, `.key`, `.p12`, `.pfx`, `.jks`). Fuera de
lockfiles, el único literal hexadecimal largo con contexto de credencial fue el
de `infra/jenkins/jenkins.yaml:33`. La capa textual del PDF disponible tampoco
produjo coincidencias sensibles.

## Hallazgos

### SEC-92-01 — Crítico — Credencial SonarCloud versionada

`infra/jenkins/jenkins.yaml:28-34` define la credencial
`sonarcloud-token`. En `infra/jenkins/jenkins.yaml:33`, la propiedad `secret`
contiene un valor literal de 40 caracteres hexadecimales detectado por Gitleaks
como `generic-api-key`.

El valor fue omitido deliberadamente de este reporte.

Impacto:

- cualquier persona con acceso al repositorio o a su historial pudo copiarlo;
- `infra/jenkins/Dockerfile:38` copia el YAML dentro de la imagen Jenkins, por
  lo que el valor también puede quedar recuperable desde capas e imágenes
  construidas;
- quitarlo del último commit no revoca el valor ya expuesto;
- contradice el requisito de no versionar secretos;
- contradice `docs/ci/jenkins.md:79-85`, que indica crear la credencial como
  `Secret text` externa.

Estado: **no resuelto**.

Acción obligatoria: revocar o invalidar el valor desde SonarCloud, generar una
credencial nueva y almacenarla únicamente en el proveedor de credenciales
correspondiente. La nueva credencial no debe aparecer en commits, capturas,
logs ni documentación.

### SEC-92-02 — Alto — Jenkins no está completamente externalizado

Aspectos correctos:

- `Jenkinsfile:146` usa `withCredentials` con el ID `sonarcloud-token`.
- `Jenkinsfile:150` desactiva el trazado del shell antes del análisis.

Aspectos pendientes:

- la fuente de esa credencial sigue siendo el literal de
  `infra/jenkins/jenkins.yaml:33`;
- `compose.jenkins.yml:83-84` versiona el usuario y la contraseña del
  administrador local;
- `docs/ci/jenkins.md:13-22` y `docs/ci/jenkins.md:28-32` publican la misma
  credencial administrativa de demostración.

La contraseña administrativa está declarada como local/demo, no como
productiva. Aun así, no cumple una interpretación estricta de “no hardcoded
credentials” y sería insegura si este Compose se expone fuera de localhost.

Estado: **parcial, no aceptable para cerrar #92**.

### SEC-92-03 — Alto — Documentación de secretos incompleta y contradictoria

`docs/ci/jenkins.md:77-85` documenta correctamente el ID requerido
`sonarcloud-token`, pero no explica un aprovisionamiento reproducible que evite
el literal JCasC existente.

`.github/workflows/sonarcloud.yml:43-47` consume
`secrets.SONAR_TOKEN`, pero no existe una guía que explique:

- el nombre exacto `SONAR_TOKEN`;
- dónde configurarlo en GitHub;
- quién debe tener permiso para rotarlo;
- cómo validar la rotación sin revelar el valor;
- el comportamiento seguro de PR provenientes de forks.

Estado: **parcial**.

### SEC-92-04 — Alto — No existe control preventivo de secretos

No se encontró configuración de Gitleaks, TruffleHog, `detect-secrets`,
`git-secrets`, pre-commit equivalente ni checklist específico.

`.github/workflows/security-testing.yml:43-49` ejecuta Trivy únicamente con:

```text
scanners: vuln,misconfig
```

Por tanto, el workflow llamado `Security Testing` no inspecciona secretos.

`.gitignore:40` ignora archivos llamados exactamente `.env`, lo cual protege el
`.env` local actual, pero no cubre variantes como `.env.local`,
`.env.production` o `.env.test`.

Estado: **no resuelto**.

### SEC-92-05 — Alto — Rotación o invalidación no demostrada

No existe constancia pública de revocación, fecha de rotación, identificador
redactado, captura segura ni comentario de auditoría. El repositorio tampoco
puede demostrar por sí solo el estado actual de una credencial en SonarCloud.

Debido a que el valor expuesto continúa versionado, no hay base para presumir
que fue rotado.

Estado: **no verificado y, para aceptación, no cumplido**.

### SEC-92-06 — Alto — Falta toda la trazabilidad del issue

La consulta en vivo a GitHub comprobó:

- issue #92: **OPEN**;
- asignado a `Code-Hdez`;
- labels correctos: `area:security`, `area:ci-cd`, `priority:high`;
- comentarios en el issue: **0**;
- rama local `security/final-secret-hardening`: **no existe**;
- rama remota `security/final-secret-hardening`: **no existe**;
- PR con esa rama o con referencia a #92: **no existe**;
- commits que mencionen #92 o `final-secret-hardening`: **no existen**.

Por tanto, no hay scan, captura segura, revisión cruzada ni pipeline atribuible
a este issue.

Estado: **no resuelto**.

### SEC-92-07 — Medio — Higiene del `.env` local

El `.env` local:

- está correctamente ignorado y no está rastreado;
- contiene una contraseña que difiere de `.env.example`, sin registrar aquí su
  valor;
- tiene permisos de archivo `0644`.

Esto no constituye un secreto versionado. Sin embargo, `0600` sería una
protección local más apropiada cuando el archivo contiene credenciales.

Estado: **no bloquea por versionado, pero requiere endurecimiento local**.

### SEC-92-08 — Medio — Credenciales demo y fixtures literales

También existen valores literales de desarrollo/pruebas en:

- `.env.example:7-24`;
- `compose.jenkins.yml:83-84`;
- `infra/keycloak/inventory-realm.json:568-582`;
- helpers E2E y pruebas de integración;
- README y documentación local.

Estos valores parecen fixtures o placeholders y no prueban por sí mismos una
credencial productiva. No obstante, la especificación final usa la regla amplia
“No hardcoded credentials”. El equipo debe:

1. externalizarlos cuando sea viable; o
2. documentarlos inequívocamente como datos sintéticos no reutilizables y
   aplicar una allowlist mínima por regla/ruta, nunca por un patrón amplio.

Estado: **requiere decisión y justificación explícita antes del PR**.

## Verificación de pipelines

### GitHub Actions

Implementación segura encontrada:

```text
.github/workflows/sonarcloud.yml:46
SONAR_TOKEN <- secrets.SONAR_TOKEN
```

La última ejecución sobre el `HEAD` auditado fue exitosa:

- [SonarCloud run 30063900682](https://github.com/xPshycho/qa_gestion_inventarios/actions/runs/30063900682)
- SHA: `9efa2ab1a621d0b68d8f19d698bccca7977b2f76`
- Evento: `push` a `develop`
- Fecha: 2026-07-24
- Job `SonarCloud Analysis`: `success`
- Paso `Build and analyze`: `success`

Esto demuestra que GitHub Actions puede ejecutar SonarCloud con la referencia
externa actual. No demuestra que el token hardcodeado de Jenkins haya sido
revocado ni constituye una corrida del inexistente PR de #92.

El mismo SHA tuvo ejecuciones exitosas de Backend CI, Frontend CI, Playwright
E2E y Security Testing. La corrida de Security Testing no sirve como
secret-scan porque su configuración solo usa `vuln,misconfig`.

### Jenkins

El `Jenkinsfile` contiene los stages requeridos y su sintaxis de consumo de
credenciales es adecuada, pero:

- no hay implementación post-hardening que probar;
- no había una instancia Jenkins local activa durante la revisión;
- no existe evidencia de una corrida Jenkins con la credencial nueva externa;
- la configuración actual todavía provisiona el secreto versionado.

Como antecedente, el reporte histórico
`docs/reporte-verificacion-avance-2026-06-18-v2.md:53` y
`docs/reporte-verificacion-avance-2026-06-18-v2.md:185-187` ya registraba que
Jenkins estaba configurado pero no se había verificado en un servidor real.
Ese documento no se usa como requisito vigente, pero confirma que una
configuración declarativa no sustituye la evidencia de ejecución faltante.

Los archivos `compose.jenkins.yml` y `docker-compose.yml` sí pasaron
`docker compose config --quiet`. Esto solo valida configuración sintáctica, no
el criterio de manejo seguro ni la ejecución del pipeline.

## Dependencias de cierre

El reporte de dependencias exige que #92 se audite nuevamente después de #86 y
#88. Ambos issues continúan abiertos:

- [#86 — Entorno preview/staging y validación post-deploy](https://github.com/xPshycho/qa_gestion_inventarios/issues/86):
  **OPEN**.
- [#88 — Pipeline final de GitHub Actions con quality gates](https://github.com/xPshycho/qa_gestion_inventarios/issues/88):
  **OPEN**.

Aunque se corrigiera hoy el literal, todavía faltaría repetir el escaneo después
de integrar esos dos trabajos para satisfacer
`docs/issues-dependency-report.md:98-100` y
`docs/issues-dependency-report.md:159-167`.

## Matriz de criterios de aceptación

| Criterio | Estado | Evidencia / brecha |
|---|---|---|
| No quedan tokens reales ni secretos productivos versionados | **No cumple** | Gitleaks detecta la credencial en `infra/jenkins/jenkins.yaml:33` |
| Pipelines funcionan con credenciales externas | **Parcial** | GitHub Actions sí; Jenkins consume un ID, pero JCasC lo alimenta con un literal y no hay corrida post-hardening |
| Documentación explica secretos Jenkins/GitHub Actions | **Parcial** | Jenkins documenta el ID; falta GitHub `SONAR_TOKEN`, rotación, responsables y aprovisionamiento coherente |
| Todo secreto expuesto fue rotado o invalidado | **No cumple / no verificable** | No existe evidencia externa y el valor continúa versionado |
| PR incluye scan, captura segura y pipeline exitoso | **No cumple** | No existen rama ni PR de #92, el issue no tiene comentarios ni evidencia |
| Validación/checklist evita nuevos secretos | **No cumple** | No hay secret scanner, pre-commit ni checklist; Trivy omite el scanner `secret` |
| Rescan final posterior a #86 y #88 | **No cumple** | Ambos issues siguen abiertos |

Ningún criterio principal está completamente satisfecho de extremo a extremo.

## Trabajo mínimo pendiente para cerrar #92

1. Revocar inmediatamente en SonarCloud el token expuesto y registrar evidencia
   segura de la revocación sin mostrar su valor.
2. Crear un token nuevo con el menor alcance y vigencia necesarios.
3. Eliminar el literal de `infra/jenkins/jenkins.yaml`.
4. Reconstruir la imagen Jenkins y retirar de registros, caches o artifacts
   cualquier imagen anterior que haya incorporado el YAML con el secreto.
5. Aprovisionar `sonarcloud-token` mediante Jenkins Credentials, Docker Secret,
   Vault u otro proveedor externo; conservar solamente el nombre/ID en Git.
6. Externalizar `JENKINS_ADMIN_PASSWORD` y eliminar la contraseña literal de
   Compose y de las instrucciones de acceso.
7. Mantener `secrets.SONAR_TOKEN` en GitHub Actions y documentar su
   configuración, propietario, rotación y validación.
8. Agregar Gitleaks u otro scanner de secretos como quality gate obligatorio
   para PR/push y, si se desea, como pre-commit.
9. Ampliar la protección de archivos `.env.*`, preservando únicamente templates
   explícitos como `.env.example`.
10. Resolver o justificar de forma acotada los fixtures/demo que disparen el
   scanner; nunca ignorar globalmente `generic-api-key`.
11. Completar e integrar #86 y #88; después ejecutar nuevamente el scan de
    árbol e historial.
12. Ejecutar GitHub Actions y Jenkins con las credenciales externas nuevas.
13. Trabajar el cambio en `security/final-secret-hardening`, abrir PR hacia
    `develop`, incluir `Closes #92`, revisión del otro integrante y adjuntar:
    - salida redactada del scan;
    - captura de Jenkins/GitHub Secrets donde solo se vea el nombre;
    - constancia redactada de revocación/rotación;
    - URLs y resultados del pipeline;
    - checklist de no exposición en logs y artifacts.

## Condición para cambiar el dictamen

El dictamen solo puede pasar a **COMPLETO** cuando exista un PR trazable que
elimine los valores, demuestre la rotación externa, documente ambos proveedores,
incorpore prevención automática y muestre ejecuciones exitosas posteriores al
hardening y a la integración de #86/#88.

Hasta entonces, cerrar #92 produciría evidencia incompleta y contradiría tanto
los criterios del issue como el orden de cierre definido para la entrega final.

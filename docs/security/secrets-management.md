# Gestión de secretos y rotación de credenciales

## Regla de seguridad

Ningún token, password o client secret real se almacena en Git, imágenes,
capturas, artifacts o logs. El repositorio versiona únicamente nombres de
variables, IDs de credenciales y templates con valores sensibles vacíos.

Los archivos de runtime `.env`, `.env.jenkins` y `.staging/` están ignorados.
Los scripts de inicialización los crean con permisos `0600`, generan valores
aleatorios con OpenSSL y nunca imprimen esos valores.

## Inventario y responsables

| Ámbito | Nombre | Proveedor | Responsable de alta/rotación |
| --- | --- | --- | --- |
| GitHub Actions | `SONAR_TOKEN` | Repository secret | Administrador del repositorio y propietario de SonarQube Cloud |
| Jenkins | `sonarcloud-token` | Jenkins Credentials, tipo `Secret text` | Administrador de Jenkins y propietario de SonarQube Cloud |
| Jenkins local | `JENKINS_ADMIN_PASSWORD` | `.env.jenkins` ignorado | Operador local |
| Aplicación local | `POSTGRES_PASSWORD` | `.env` ignorado | Operador local |
| Keycloak local | `KEYCLOAK_ADMIN_PASSWORD` | `.env` ignorado | Operador local |
| Backend/Keycloak | `KEYCLOAK_ADMIN_CLIENT_SECRET` | `.env` o secret del entorno | Administrador de identidad |
| Usuarios E2E | `E2E_*_PASSWORD` | `.env` o secreto efímero del runner | Responsable de QA |
| Grafana | `GRAFANA_ADMIN_PASSWORD` | `.env` o secret del entorno | Operador de observabilidad |

`GITHUB_TOKEN` no se configura manualmente: GitHub lo crea para cada job. El
workflow de Gitleaks solo solicita `contents: read`.

## Entorno local

Crear o completar `.env`:

```bash
./scripts/security/init-secret-env.sh local
```

El comando conserva valores existentes. Para rotar todos los secretos locales:

```bash
./scripts/security/init-secret-env.sh local --rotate
docker compose down -v
docker compose up --build -d
```

La eliminación de volúmenes es necesaria porque PostgreSQL, Keycloak y Grafana
persisten credenciales inicializadas anteriormente.

`infra/keycloak/inventory-realm.json` solo contiene placeholders:

```text
${KEYCLOAK_ADMIN_CLIENT_SECRET}
${E2E_ADMIN_PASSWORD}
${E2E_OPERATOR_PASSWORD}
${E2E_VIEWER_PASSWORD}
${E2E_AUDITOR_PASSWORD}
```

Keycloak sustituye estos valores desde el entorno durante el import. Este
mecanismo está documentado en la
[guía oficial de importación de realms](https://www.keycloak.org/server/importExport#_using_environment_variables_within_the_realm_configuration_files).

## Jenkins

Crear la credencial administrativa local:

```bash
./scripts/security/init-secret-env.sh jenkins
docker compose --env-file .env.jenkins \
  -p inventory-jenkins \
  -f compose.jenkins.yml \
  up -d --build --wait
```

Para SonarQube Cloud:

1. En **Manage Jenkins > Credentials**, crear una credencial `Secret text`.
2. Asignar exactamente el ID `sonarcloud-token`.
3. Pegar el token nuevo sin incluirlo en JCasC, variables versionadas o logs.
4. Ejecutar el job con `RUN_SONAR=true`.
5. Conservar como evidencia el número del build y Stage View, nunca el valor.

`Jenkinsfile` inyecta la credencial con `withCredentials`, desactiva el trazado
del shell antes de usarla y no la archiva.

## GitHub Actions

Configurar SonarQube Cloud:

1. Abrir **Settings > Secrets and variables > Actions**.
2. Seleccionar **New repository secret**.
3. Usar exactamente el nombre `SONAR_TOKEN`.
4. Guardar el token nuevo y ejecutar el workflow `SonarCloud`.
5. Registrar la URL del run exitoso y el SHA analizado.

`.github/workflows/sonarcloud.yml` referencia únicamente
`${{ secrets.SONAR_TOKEN }}`.

GitHub no entrega Actions secrets a workflows iniciados desde forks o
Dependabot. Ese comportamiento es deliberado: un PR externo puede ejecutar
checks que no requieren secretos, pero el análisis Sonar autenticado debe
validarse en una rama confiable o después del merge. No se debe cambiar a
`pull_request_target` para eludir esta protección.

Referencia:
[tipos y restricciones de GitHub Actions secrets](https://docs.github.com/en/code-security/reference/secret-security/secret-types#actions-secrets).

## Rotación por exposición

Cuando un valor aparece en un commit, log, artifact o captura:

1. Tratarlo inmediatamente como comprometido.
2. Revocarlo en el proveedor; eliminarlo del último commit no lo invalida.
3. Crear un reemplazo con el menor alcance y expiración viables.
4. Actualizar Jenkins/GitHub sin copiar el valor a comentarios o evidencia.
5. Reconstruir imágenes y eliminar artifacts o caches que incorporaron el
   secreto anterior.
6. Ejecutar Gitleaks sobre árbol e historial.
7. Ejecutar Jenkins y GitHub Actions con la credencial nueva.
8. Documentar fecha, proveedor, nombre/ID y responsable de la rotación, nunca
   el token ni un hash reversible.

En SonarQube Cloud, los tokens se administran en **My Account > Security**. La
interfaz muestra un botón **Revoke** para cada token:
[documentación oficial de tokens](https://docs.sonarsource.com/sonarqube-cloud/managing-your-account/managing-tokens).

Para el token histórico detectado por #92, la evidencia de cierre debe indicar:

```text
Proveedor: SonarQube Cloud
Credencial anterior: revocada
Credencial nueva: almacenada como SONAR_TOKEN y sonarcloud-token
Fecha/hora:
Responsable:
Run GitHub:
Build Jenkins:
Valor sensible mostrado: no
```

## Prevención y verificación

Antes de cada commit:

```bash
./scripts/security/scan-secrets.sh --staged
```

Para revisar el árbol del commit actual:

```bash
./scripts/security/scan-secrets.sh --current
```

Para incluir cambios rastreados y archivos nuevos que Git permitiría versionar:

```bash
./scripts/security/scan-secrets.sh --worktree
```

Para una auditoría explícita del historial:

```bash
./scripts/security/scan-secrets.sh --history
```

El workflow `Secret Scanning` ejecuta Gitleaks 8.30.1 mediante la acción v3
fijada a un commit inmutable en cada PR y push hacia las ramas principales.
La configuración extiende las reglas oficiales sin allowlists amplias. Un
hallazgo bloquea el job; no se publican comentarios, resúmenes ni artifacts que
pudieran replicar un valor detectado. Las excepciones solo se aceptan si son
sintéticas, están justificadas por regla y ruta, y no ocultan categorías
completas de secretos.

Los workflows E2E y Jenkins desactivan HTML, screenshots automáticos, traces y
videos de Playwright. El workflow `Security Testing` somete también los
reportes Trivy/ZAP y los diagnósticos Docker a
`scripts/security/verify-artifacts.sh` antes del upload. El verificador rechaza
artifacts de alto riesgo y busca recursivamente los secretos configurados en
texto plano, Base64, Basic auth, JWT, ZIP y gzip. Si el safety falla, la
evidencia afectada se retiene y el job falla.

El checklist del PR exige además confirmar que `.env`, realms renderizados,
tokens, traces, videos y HAR sensibles no fueron publicados.

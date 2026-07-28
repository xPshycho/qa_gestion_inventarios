# Jenkins Pipeline

El repositorio incluye un Jenkins local reproducible para demostrar el pipeline sin configurar plugins, usuarios ni jobs manualmente. Jenkins se ejecuta junto a un daemon Docker-in-Docker aislado y conserva configuracion, historial y caches en volumenes Docker.

## Iniciar Jenkins

Desde la raiz del repositorio:

```bash
./scripts/security/init-secret-env.sh jenkins
docker compose --env-file .env.jenkins \
  -p inventory-jenkins \
  -f compose.jenkins.yml \
  up -d --build --wait
```

Acceso local:

| Dato | Fuente |
|---|---|
| URL | `http://localhost:18080` |
| Usuario | `JENKINS_ADMIN_ID` en `.env.jenkins` |
| Password | `JENKINS_ADMIN_PASSWORD` en `.env.jenkins` |
| Job | `inventory-avance-ci` |

`.env.jenkins` está ignorado, usa permisos `0600` y no debe copiarse a logs,
capturas ni artifacts. El asistente inicial está desactivado; no se utiliza
`initialAdminPassword`.

El job se crea automáticamente mediante Jenkins Configuration as Code y Job
DSL. Está configurado como Pipeline from SCM sobre
`https://github.com/xPshycho/qa_gestion_inventarios.git`. El parámetro
`GIT_BRANCH` selecciona una rama confiable y usa `develop` por defecto.

## Flujo para la demostracion

1. Publicar la rama que contiene el `Jenkinsfile` que se desea validar.
2. Ejecutar el comando de arranque y abrir `http://localhost:18080`.
3. Iniciar sesión con los valores locales de `.env.jenkins`.
4. Abrir `inventory-avance-ci`.
5. Pulsar **Build with Parameters**, indicar `GIT_BRANCH` y mantener
   `RUN_SONAR=false` salvo que se valide SonarQube Cloud.
6. Abrir la ejecucion y seleccionar **Console Output** o **Stage View**.
7. Al finalizar, revisar los enlaces de pruebas, cobertura y artifacts.

No es necesario reiniciar Jenkins cuando cambia el `Jenkinsfile`: cada build
obtiene la versión actual de la rama indicada desde GitHub.

## Comandos de operacion

```bash
# Estado
docker compose --env-file .env.jenkins -p inventory-jenkins -f compose.jenkins.yml ps

# Logs de Jenkins
docker compose --env-file .env.jenkins -p inventory-jenkins -f compose.jenkins.yml logs -f jenkins

# Reiniciar Jenkins conservando job, historial y caches
docker compose --env-file .env.jenkins -p inventory-jenkins -f compose.jenkins.yml restart jenkins

# Detener conservando datos
docker compose --env-file .env.jenkins -p inventory-jenkins -f compose.jenkins.yml down

# Eliminar Jenkins, historial, caches e imagenes del daemon interno
docker compose --env-file .env.jenkins -p inventory-jenkins -f compose.jenkins.yml down -v

# Recrear una instalacion limpia
docker compose --env-file .env.jenkins -p inventory-jenkins -f compose.jenkins.yml down -v
./scripts/security/init-secret-env.sh jenkins --rotate
docker compose --env-file .env.jenkins -p inventory-jenkins -f compose.jenkins.yml up -d --build --wait
```

Los archivos del job los crea el proceso `jenkins`, no `root`. No se debe crear `/var/jenkins_home/jobs/.../config.xml` con `docker exec -u root`; eso fue la causa de los errores `Permission denied` al generar builds.

## Entorno incluido

La imagen definida en `infra/jenkins/` incluye:

- Jenkins LTS sobre JDK 21.
- Node.js 22, Corepack y pnpm 10.12.1.
- Docker CLI y Docker Compose v2.
- Chromium y dependencias de Playwright 1.60.0.
- Pipeline, Git, JUnit, HTML Publisher, Workspace Cleanup, Credentials Binding, Stage View, JCasC y Job DSL.

El daemon Docker interno usa TLS y una red privada. Jenkins y Docker comparten el workspace para que los bind mounts de Docker Compose funcionen. Las pruebas acceden al preview mediante el hostname interno `docker`; por eso no dependen de los puertos `localhost` de la maquina ni chocan con el stack normal del proyecto.

Docker-in-Docker requiere `privileged: true`. Esta configuracion está limitada al entorno academico local y no debe reutilizarse como arquitectura de produccion.

## SonarCloud opcional

El build normal deja `RUN_SONAR=false`, por lo que no necesita secretos. Para ejecutar el analisis real:

1. Crear en Jenkins una credencial **Secret text**.
2. Usar exactamente el ID `sonarcloud-token`.
3. Ejecutar **Build with Parameters** con `RUN_SONAR=true`.

El token se inyecta solo durante el stage de SonarCloud y no debe aparecer en
logs. Su valor no se incluye en JCasC; `infra/jenkins/jenkins.yaml` únicamente
configura Jenkins y el job.

La rotación coordinada con GitHub Actions, el responsable y la evidencia
redactada están documentados en
`docs/security/secrets-management.md`.

## Stages y resultados

- `Checkout`: descarga la rama confiable indicada por `GIT_BRANCH`.
- `Environment`: valida Java, Docker, Compose y pnpm.
- `Backend Build`: compila el backend.
- `Unit Tests + Coverage Gate`: ejecuta JUnit y exige al menos 60% de cobertura de lineas.
- `Integration Tests`: ejecuta PostgreSQL y Keycloak con Testcontainers.
- `API Tests`: ejecuta contratos RestAssured.
- `Frontend Build`: instala dependencias y compila Angular.
- `Security Scan`: ejecuta `pnpm audit`; SonarCloud solo si se solicita.
- `Docker Build` y `Deploy Preview`: construyen y levantan el stack en el daemon aislado.
- `E2E Tests`: ejecuta Playwright Chromium contra el preview.

Jenkins publica JUnit, reportes HTML de pruebas backend, JaCoCo, el JAR y el
build frontend. El JUnit de Playwright solo se archiva después de superar
`verify-artifacts.sh`; HTML, screenshots automáticos, traces, videos y HAR de
Playwright permanecen desactivados. `pnpm audit` puede dejar el build como
`UNSTABLE` si detecta vulnerabilidades; los fallos de compilación o pruebas
producen `FAILURE`.

El bloque `post` elimina los contenedores, redes y volumenes temporales de cada build. Las caches de Gradle, pnpm, Playwright y las capas Docker persisten para acelerar la siguiente demostracion.

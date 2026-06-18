# Jenkins Pipeline

El repositorio incluye un Jenkins local reproducible para demostrar el pipeline sin configurar plugins, usuarios ni jobs manualmente. Jenkins se ejecuta junto a un daemon Docker-in-Docker aislado y conserva configuracion, historial y caches en volumenes Docker.

## Iniciar Jenkins

Desde la raiz del repositorio:

```bash
docker compose -p inventory-jenkins -f compose.jenkins.yml up -d --build --wait
```

Acceso de demostracion:

| Dato | Valor |
|---|---|
| URL | `http://localhost:18080` |
| Usuario | `admin` |
| Password | `admin123` |
| Job | `inventory-avance-ci` |

La credencial es exclusivamente local y no debe reutilizarse en un servidor expuesto. El asistente inicial está desactivado; no se utiliza `initialAdminPassword`.

El job se crea automáticamente mediante Jenkins Configuration as Code y Job DSL. Está configurado como Pipeline from SCM para leer `Jenkinsfile` desde la rama `develop` de `https://github.com/xPshycho/qa_gestion_inventarios.git`.

## Flujo para la demostracion

1. Publicar previamente en `origin/develop` cualquier cambio del `Jenkinsfile`.
2. Ejecutar el comando de arranque y abrir `http://localhost:18080`.
3. Iniciar sesion con `admin` / `admin123`.
4. Abrir `inventory-avance-ci`.
5. Pulsar **Build Now**. El parametro `RUN_SONAR` es `false` por defecto.
6. Abrir la ejecucion y seleccionar **Console Output** o **Stage View**.
7. Al finalizar, revisar los enlaces de pruebas, cobertura y artifacts.

No es necesario reiniciar Jenkins cuando cambia el `Jenkinsfile`: cada build obtiene la version actual de `develop` desde GitHub.

## Comandos de operacion

```bash
# Estado
docker compose -p inventory-jenkins -f compose.jenkins.yml ps

# Logs de Jenkins
docker compose -p inventory-jenkins -f compose.jenkins.yml logs -f jenkins

# Reiniciar Jenkins conservando job, historial y caches
docker compose -p inventory-jenkins -f compose.jenkins.yml restart jenkins

# Detener conservando datos
docker compose -p inventory-jenkins -f compose.jenkins.yml down

# Eliminar Jenkins, historial, caches e imagenes del daemon interno
docker compose -p inventory-jenkins -f compose.jenkins.yml down -v

# Recrear una instalacion limpia
docker compose -p inventory-jenkins -f compose.jenkins.yml down -v
docker compose -p inventory-jenkins -f compose.jenkins.yml up -d --build --wait
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

El token se inyecta solo durante el stage de SonarCloud y no debe aparecer en logs.

## Stages y resultados

- `Checkout`: descarga `develop` desde GitHub.
- `Environment`: valida Java, Docker, Compose y pnpm.
- `Backend Build`: compila el backend.
- `Unit Tests + Coverage Gate`: ejecuta JUnit y exige al menos 60% de cobertura de lineas.
- `Integration Tests`: ejecuta PostgreSQL y Keycloak con Testcontainers.
- `API Tests`: ejecuta contratos RestAssured.
- `Frontend Build`: instala dependencias y compila Angular.
- `Security Scan`: ejecuta `pnpm audit`; SonarCloud solo si se solicita.
- `Docker Build` y `Deploy Preview`: construyen y levantan el stack en el daemon aislado.
- `E2E Tests`: ejecuta Playwright Chromium contra el preview.

Jenkins publica JUnit, reportes HTML de pruebas, JaCoCo, el JAR, el build frontend y las evidencias Playwright. `pnpm audit` puede dejar el build como `UNSTABLE` si detecta vulnerabilidades; los fallos de compilacion o pruebas producen `FAILURE`.

El bloque `post` elimina los contenedores, redes y volumenes temporales de cada build. Las caches de Gradle, pnpm, Playwright y las capas Docker persisten para acelerar la siguiente demostracion.

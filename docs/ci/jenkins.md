# Jenkins Pipeline

Este proyecto incluye un `Jenkinsfile` declarativo para ejecutar el flujo visual de CI/CD del sistema de inventarios: checkout, build, pruebas, analisis de calidad, build Docker, despliegue preview y pruebas E2E.

## Requisitos del nodo Jenkins

- Linux con Docker Engine y Docker Compose v2.
- JDK 21 configurado en Jenkins con el nombre `temurin-21`.
- Node.js 20 o superior con Corepack disponible.
- Paquetes del sistema requeridos por Playwright Chromium. El pipeline intenta instalarlos con `playwright install --with-deps chromium`.
- Acceso de red a Maven Central, Gradle distributions, npm registry, Docker Hub, Quay.io y SonarCloud.
- Usuario del agente Jenkins con permisos para usar Docker.

El acceso a Docker debe limitarse a un nodo confiable. Montar `/var/run/docker.sock` equivale a dar permisos altos sobre el host, por lo que este pipeline no debe ejecutarse para ramas o pull requests no confiables.

## Plugins requeridos

- Pipeline
- Git
- JUnit
- HTML Publisher
- AnsiColor
- Workspace Cleanup
- Credentials Binding

## Credenciales

Crear en Jenkins una credencial de tipo Secret Text:

| ID | Uso |
|---|---|
| `sonarcloud-token` | Token de SonarCloud consumido por el stage `SonarCloud Quality Analysis`. |

El token se inyecta con `withCredentials` y no debe imprimirse en logs. Las credenciales demo de Keycloak y E2E son datos de prueba locales y no deben reutilizarse fuera del entorno academico.

## Crear el pipeline

1. Crear un nuevo job tipo Pipeline o Multibranch Pipeline.
2. Apuntar al repositorio `https://github.com/xPshycho/qa_gestion_inventarios`.
3. Usar la rama `ci/edwin-jenkins-pipeline` mientras se desarrolla el issue.
4. Configurar el script path como `Jenkinsfile`.
5. Ejecutar el build en un agente con label `linux && docker`.
6. Reservar los puertos `5173`, `8080`, `8081` y `55432` en el nodo, o definir `FRONTEND_PORT`, `BACKEND_PORT`, `KEYCLOAK_PORT` y `POSTGRES_PORT` para el job Jenkins.

## Stages principales

- `Checkout`: descarga el codigo.
- `Environment`: valida Java, Docker, Docker Compose, Gradle Wrapper y pnpm.
- `Backend Build`: compila el backend con Gradle.
- `Unit Tests + Coverage Gate`: ejecuta unit tests y JaCoCo con umbral minimo.
- `Integration Tests`: ejecuta Testcontainers con PostgreSQL y Keycloak.
- `API Tests`: ejecuta la suite dedicada `apiTest` con RestAssured para contratos, errores y permisos.
- `Frontend Build`: instala dependencias del frontend y genera build Angular.
- `Security Scan`: ejecuta `pnpm audit --prod` y SonarCloud. El audit frontend marca el build como `UNSTABLE` si encuentra vulnerabilidades y conserva `frontend-audit.json`.
- `Docker Build`: construye imagenes backend y frontend.
- `Deploy Preview`: levanta el stack con Docker Compose.
- `E2E Tests`: espera el stack desplegado y ejecuta Playwright contra ese entorno.

## Reportes y artifacts

Jenkins publica siempre los resultados disponibles, incluso cuando falla un stage:

- JUnit XML: `backend/build/test-results/**/*.xml`
- Unit test HTML
- Integration test HTML
- API test HTML
- JaCoCo unit coverage
- JaCoCo integration coverage
- JAR backend
- Reportes Gradle
- Build frontend
- Resultado JUnit de Playwright
- Resultado de `pnpm audit --prod` en `frontend-audit.json`

No se archiva el workspace completo, `.env`, `.gradle`, `node_modules`, dumps, traces, videos ni credenciales.

## Comandos equivalentes locales

```bash
cd backend && ./gradlew clean assemble
cd backend && ./gradlew test jacocoTestReport jacocoTestCoverageVerification
cd backend && ./gradlew apiTest
cd backend && ./gradlew integrationTest

cd frontend && pnpm install --frozen-lockfile && pnpm build

cd tests/e2e
pnpm install --frozen-lockfile
pnpm test
```

## Limpieza

El pipeline ejecuta `docker compose down -v --remove-orphans` en `post always` para evitar contenedores, redes o volumenes persistentes entre builds.

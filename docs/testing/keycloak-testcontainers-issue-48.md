# Issue #48 - Diagnostico de Keycloak con Testcontainers

## Objetivo

Validar si `./gradlew integrationTest` falla localmente por timeout al levantar Keycloak con
Testcontainers, como se documento en el bug #48.

## Resultado

La suite de integracion paso de forma reproducible cuando se ejecuto con JDK 21 y Docker accesible
desde el proceso de Gradle.

Evidencia local del 2026-06-13:

| Corrida | Comando | Resultado |
|---------|---------|-----------|
| 1 | Docker JDK 21 con red host | `BUILD SUCCESSFUL` en 1m12s |
| 2 | Docker JDK 21 con red host y `--rerun-tasks` | `BUILD SUCCESSFUL` en 1m21s |

Resumen de `backend/build/test-results/integrationTest` en la segunda corrida:

| Suite | Tests | Fallos | Errores |
|-------|-------|--------|---------|
| `AuditServiceIntegrationTest` | 2 | 0 | 0 |
| `FlywayMigrationIntegrationTest` | 1 | 0 | 0 |
| `ProductServiceIntegrationTest` | 1 | 0 | 0 |
| `StockServiceIntegrationTest` | 2 | 0 | 0 |
| `KeycloakSecurityIntegrationTest` | 5 | 0 | 0 |

Total validado: 11 pruebas de integracion, 0 fallos, 0 errores.

## Requisitos locales

- JDK 21. Gradle 8.14 no debe ejecutarse con Java 26 para esta validacion.
- Docker activo y accesible para el usuario que ejecuta Gradle.
- Sin contenedores previos que ocupen recursos o puertos de Docker.

Validaciones rapidas:

```bash
java -version
docker version
docker ps
```

## Comando recomendado

Cuando JDK 21 esta instalado en la maquina:

```bash
cd backend
./gradlew integrationTest --no-daemon
```

Los reportes quedan en:

```text
backend/build/reports/tests/integrationTest/index.html
backend/build/test-results/integrationTest/
backend/build/reports/jacoco/integrationTest/html/index.html
```

## Alternativa con Docker JDK 21

Si la maquina local tiene otra version de Java, se puede ejecutar Gradle desde la imagen del
Dockerfile del backend. Este comando debe ejecutarse desde la raiz del repositorio en Linux:

```bash
mkdir -p /tmp/qa-gradle-issue48-docker

docker run --rm --network host \
  --user "$(id -u):$(id -g)" \
  --group-add "$(stat -c '%g' /var/run/docker.sock)" \
  -v "$PWD":/workspace \
  -v /tmp/qa-gradle-issue48-docker:/tmp/gradle-cache \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -w /workspace/backend \
  -e HOME=/tmp \
  -e GRADLE_USER_HOME=/tmp/gradle-cache \
  -e TESTCONTAINERS_HOST_OVERRIDE=127.0.0.1 \
  eclipse-temurin:21-jdk-alpine \
  ./gradlew integrationTest --no-daemon --rerun-tasks
```

`--network host` y `TESTCONTAINERS_HOST_OVERRIDE=127.0.0.1` son importantes en esta alternativa:
Testcontainers publica PostgreSQL y Keycloak en el Docker host, y el proceso de Gradle debe poder
alcanzar esos puertos.

## Hallazgos

- Con Java 26, Gradle falla antes de iniciar las pruebas con `Unsupported class file major version
  70`. Ese fallo no diagnostica Keycloak.
- Ejecutar Gradle dentro de Docker sin red host puede producir falsos negativos:
  - Ryuk puede fallar con `Could not connect to Ryuk`.
  - PostgreSQL puede fallar por timeout de conexion desde Spring/Flyway.
  - Keycloak puede importar el realm y quedar escuchando en `0.0.0.0:8080`, pero el
    `HttpWaitStrategy` no logra alcanzar el puerto publicado desde el contenedor de Gradle.
- En la corrida valida, Keycloak 26.6.3 importo el realm `inventory` y las 5 pruebas de seguridad
  pasaron.

## Conclusion

El bug #48 queda clasificado como problema de entorno local cuando Gradle no se ejecuta con JDK 21 o
cuando se usa una ejecucion dockerizada sin red host. No se requiere cambiar `KeycloakIntegrationTest`
mientras la suite siga pasando con JDK 21 y Docker accesible.

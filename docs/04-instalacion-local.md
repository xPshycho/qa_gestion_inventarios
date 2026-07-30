# Instalación local

## Requisitos

| Requisito | Versión/uso |
|---|---|
| Git | clonado |
| Docker Engine | >= 24 según README |
| Docker Compose plugin | >= 2.20 |
| Bash, curl, jq, OpenSSL | scripts y health checks |
| Java | 21 para ejecutar Gradle fuera de Docker |
| Node | rangos declarados en `frontend/package.json`; se recomienda 22 LTS |
| pnpm | 10.12.1, fijado por el proyecto |

Hardware mínimo no está codificado. Para el stack completo se recomienda
provisionalmente 4 CPU, 8 GiB RAM y 15 GiB libres:
**Pendiente de verificación** con medición en una estación limpia.

## Instalación reproducible con Docker

`Verificado · Requiere Docker · desde la raíz`

```bash
git clone https://github.com/xPshycho/qa_gestion_inventarios.git
cd qa_gestion_inventarios
./scripts/security/init-secret-env.sh local
docker compose up --build -d --wait --wait-timeout 240
docker compose ps
curl --fail http://localhost:8080/actuator/health
curl --fail http://localhost:5173/health
```

`init-secret-env.sh` crea `.env` modo 0600 con valores aleatorios. No copiarlo
a documentación ni adjuntarlo a evidencias.

Servicios y URLs se describen en [Configuración](05-configuracion.md#puertos).

## Compilación nativa

`Verificado para backend/frontend mediante las suites; requiere Java 21 y pnpm`

```bash
cd backend
../scripts/testing/run_with_java_21.sh ./gradlew clean assemble --no-daemon
cd ../frontend
corepack pnpm install --frozen-lockfile
corepack pnpm build
```

En el host auditado Node 25/pnpm 11 no coincidían con el toolchain fijado; las
pruebas frontend se ejecutaron en la imagen Playwright del proyecto.

## Migraciones y seed

Flyway se ejecuta antes del backend mediante el servicio `flyway`. Hibernate
usa `ddl-auto=validate`, por lo que no crea esquema silenciosamente.

`Verificado como parte de E2E/performance/security`

```bash
docker compose up --build -d --wait --wait-timeout 240
docker compose ps flyway postgres backend
docker compose logs --no-color flyway
```

No publicar logs sin pasar el safety scan: pueden contener URLs o metadatos.

## Acceso y primer uso

1. Abrir `http://localhost:5173`.
2. Iniciar sesión vía Keycloak.
3. Usar uno de los usernames no sensibles declarados en `.env.example`.
4. Obtener la contraseña desde el `.env` local del operador, nunca desde Git.

La administración de identidades y rotación está en
[Usuarios y accesos](10-usuarios-y-accesos.md).

## Detención y limpieza

`Verificado · cambia estado local, conserva volúmenes`

```bash
docker compose stop
docker compose start
```

`Destructivo local · elimina base de datos y telemetría local`

```bash
# Respalde primero con el procedimiento de docs/06-base-de-datos.md.
docker compose down -v --remove-orphans
```

Alternativa segura: `docker compose down` sin `-v`.

## Instalación de navegadores Playwright

No es necesaria para el camino recomendado: `pnpm --dir tests/e2e test` usa la
imagen fijada. Para ejecución nativa:

`No verificado en el host · descarga binarios`

```bash
cd tests/e2e
corepack pnpm install --frozen-lockfile
corepack pnpm exec playwright install
```

Véase [Playwright](13-pruebas-e2e-playwright.md).

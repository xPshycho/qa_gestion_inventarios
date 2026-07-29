# Matriz de puertos por ambiente

Este documento es la fuente de verdad para configurar URLs, `docker compose`,
pruebas locales y despliegues. Un puerto interno de contenedor no implica que
esté publicado en el host o en Internet.

## Development local

`docker-compose.yml` define los puertos internos y
`docker-compose.override.yml` publica los puertos del host. Los valores se
configuran en el `.env` local generado a partir de `.env.example`.

| Servicio | Puerto interno | Puerto host por defecto | URL local |
|---|---:|---:|---|
| Frontend Angular/Nginx | 8080 | 5173 | `http://localhost:5173` |
| Backend Spring Boot | 8080 | 8080 | `http://localhost:8080` |
| Keycloak | 8080 | 8081 | `http://localhost:8081` |
| Keycloak health/metrics | 9000 | No publicado | Red Docker |
| PostgreSQL aplicación | 5432 | 55432 | `localhost:55432` |
| Prometheus | 9090 | 9090 | `http://localhost:9090` |
| Grafana | 3000 | 3000 | `http://localhost:3000` |
| Loki | 3100 | 3100 | `http://localhost:3100` |
| Tempo HTTP | 3200 | 3200 | `http://localhost:3200` |
| Tempo OTLP gRPC | 4317 | No publicado | Red Docker |
| Tempo OTLP HTTP | 4318 | No publicado | Red Docker |
| Grafana Alloy OTLP gRPC | 4317 | No publicado | Red Docker |
| Grafana Alloy OTLP HTTP | 4318 | No publicado | Red Docker |
| Grafana Alloy UI | 12345 | 12345 | `http://localhost:12345` |
| Alertmanager | 9093 | 9093 | `http://localhost:9093` |
| Flyway | Ninguno | Ninguno | Proceso temporal |

Variables canónicas:

```dotenv
POSTGRES_PORT=55432
BACKEND_PORT=8080
KEYCLOAK_PORT=8081
FRONTEND_PORT=5173
PROMETHEUS_PORT=9090
GRAFANA_PORT=3000
ALLOY_HTTP_PORT=12345
LOKI_PORT=3100
TEMPO_PORT=3200
ALERTMANAGER_PORT=9093
```

Los runners bajo `tests/**/run-local.sh` leen estos valores desde `.env`; no
deben duplicar números de puerto en sus comandos.

## Preview / staging

Staging publica los servicios solamente sobre loopback. Los valores por defecto
están en `.env.staging.example`.

| Servicio | Puerto interno | Puerto host |
|---|---:|---:|
| Frontend | 8080 | 15173 |
| Backend | 8080 | 18082 |
| Keycloak | 8080 | 18081 |
| Keycloak management | 9000 | 19000 |
| Prometheus | 9090 | 19090 |
| Grafana | 3000 | 13000 |
| Alloy UI | 12345 | 12346 |
| Loki | 3100 | 13100 |
| Tempo HTTP | 3200 | 13200 |
| Alertmanager | 9093 | 19093 |

El bind predeterminado es `127.0.0.1`; estas interfaces no deben exponerse
directamente a Internet.

## Producción GCP

En la VM solo 80 y 443 están publicados a Internet. Los demás servicios
funcionan dentro de la red privada de Docker.

| Servicio | Puerto interno | Acceso desde Internet |
|---|---:|---|
| Gateway Nginx | 80, 443 | Sí |
| Frontend Angular/Nginx | 8080 | Mediante `https://34.123.136.144/` |
| Backend Spring Boot | 8080 | Mediante `/api/` en 443 |
| Keycloak | 8080 | Mediante `/auth/` en 443 |
| Keycloak health/metrics | 9000 | No |
| PostgreSQL aplicación | 5432 | No |
| PostgreSQL Keycloak | 5432 | No |
| Prometheus | 9090 | No |
| Grafana | 3000 | Mediante `/grafana/` en 443 |
| Loki | 3100 | No |
| Tempo HTTP | 3200 | No |
| Tempo OTLP gRPC | 4317 | No |
| Tempo OTLP HTTP | 4318 | No |
| Grafana Alloy OTLP gRPC | 4317 | No |
| Grafana Alloy OTLP HTTP | 4318 | No |
| Grafana Alloy UI | 12345 | No |
| Alertmanager | 9093 | No |
| Flyway | Ninguno | Proceso temporal |
| SSH | 22 | Solo mediante Google IAP |

El gateway publica únicamente `80:80` y `443:443`, según
`docker-compose.production.yml`. Las rutas públicas se configuran en
`infra/gcp/gateway/nginx.conf.template`.

Reglas del firewall:

- 80/tcp abierto a Internet.
- 443/tcp abierto a Internet.
- 22/tcp solo desde `35.235.240.0/20`, rango de Google IAP.
- Ninguna regla pública para 3000, 5432, 8080, 9090 o 18080.

## Jenkins local

Jenkins no está desplegado en la VM productiva. Es un entorno académico local
independiente definido en `compose.jenkins.yml`.

| Uso | Puerto |
|---|---:|
| Jenkins web | 18080 |
| Agentes Jenkins | 50000 |
| Docker-in-Docker TLS interno | 2376 |
| PostgreSQL temporal | 55433 |
| Backend temporal | 18082 |
| Keycloak temporal | 18081 |
| Frontend temporal | 15173 |
| Prometheus temporal | 19090 |
| Grafana temporal | 13000 |

Por tanto, `http://34.123.136.144:18080` no corresponde a un Jenkins
desplegado y el firewall de producción no permite ese puerto.

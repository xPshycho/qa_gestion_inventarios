# Arquitectura general

```mermaid
flowchart LR
  U[Operador / cliente API]
  subgraph Gateway["Límite web"]
    N[Nginx]
    A[Angular SPA]
  end
  subgraph App["Monolito modular Spring Boot"]
    P[Product]
    S[Stock]
    R[Report]
    AU[Audit]
    SE[Security]
  end
  K[Keycloak]
  DB[(PostgreSQL)]
  O[Actuator / Micrometer / OTEL]
  subgraph Obs["Observabilidad"]
    PR[Prometheus]
    AL[Alloy]
    LO[Loki]
    TE[Tempo]
    GR[Grafana]
    AM[Alertmanager]
  end

  U -->|HTTPS| N
  N --> A
  N -->|/api| App
  N -->|/auth| K
  N -->|/grafana| GR
  A -->|Authorization Code + PKCE| K
  A -->|Bearer JWT| App
  App --> DB
  SE -->|Admin REST| K
  App --> O
  PR -->|scrape| O
  AL -->|logs| LO
  AL -->|traces| TE
  PR --> GR
  LO --> GR
  TE --> GR
  PR --> AM
```

La API de negocio es un único proceso con módulos de dominio; Keycloak,
PostgreSQL y telemetría son servicios de infraestructura separados. El
navegador y la red pública están fuera del límite de confianza. Nginx es el
único punto público del despliegue VM.

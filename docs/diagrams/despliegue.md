# Despliegue por ambiente

```mermaid
flowchart TB
  SRC[Repositorio / SHA]
  SRC --> DEV[Development Compose]
  SRC --> STG[Staging Compose aislado]
  SRC --> CR[Cloud Run development]
  SRC --> VM[Compute Engine producción]

  DEV --> DDB[(PostgreSQL volumen local)]
  DEV --> DK[Keycloak]
  STG --> SDB[(Volumen staging exclusivo)]
  STG --> SK[Keycloak start]
  CR --> CP[Cloud SQL Auth Proxy]
  CP --> CSQL[(Cloud SQL inventory-development)]
  VM --> VNG[Nginx 80/443]
  VM --> VAPP[Contenedores internos]
  VAPP --> VDB[(PostgreSQL volumen VM)]
```

Staging local/CI publica solo loopback. Cloud Run development agrupa
frontend/backend/Keycloak/proxy en una revisión. Producción vigente es la VM,
no un servicio Cloud Run production.

# Evidencia de deployment

- Nombre: inventario GCP y despliegues observados.
- Fecha: 29 de julio de 2026 local.
- Entorno: proyecto `project-e70349a8-c787-4733-9a0`.
- Procedimiento: `gcloud` de solo lectura, curls de health y API pública de
  GitHub para Environments/dependencias.
- Resultado: VM producción RUNNING/UP; Cloud Run development revisión activa
  UP; tres Cloud SQL `RUNNABLE`. Las privadas development/staging aparecieron
  durante la convergencia y no tenían consumidor Cloud Run observado.
- Evidencia: `docs/03-infraestructura-gcp.md`.
- Runbook y matriz del issue #109:
  [`docs/27-guia-operativa-gcp-opentofu.md`](../../27-guia-operativa-gcp-opentofu.md).
- Evidencia de superficies públicas:
  [Swagger/OpenAPI, Keycloak OIDC y flujos](swagger-keycloak-flujos.md).
- Interpretación: snapshot verificable, con deriva OpenTofu explícita.
- Requisito: deployment, GCP y producción.
- Limitaciones: recursos cambiaban concurrentemente; reconfirmar estados; no
  se ingresó a la VM; `staging` no tiene protection rules; #107 continúa
  abierto aunque el PR #145 incorporó planes y deploy administrado.

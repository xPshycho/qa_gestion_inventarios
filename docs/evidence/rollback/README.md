# Evidencia de rollback

- Nombre: procedimientos de recuperación y evidencia histórica staging.
- Fecha de revisión: 29 de julio de 2026.
- Entorno: scripts versionados; staging histórico issue #86.
- Procedimiento: revisión de `scripts/staging/`, `scripts/gcp/rollback.sh`,
  snapshots y backups GCP.
- Resultado: mecanismos documentados; snapshot VM y backup Cloud SQL
  observados.
- Evidencia: `docs/20-backup-y-rollback.md` y fuentes de proyecto final del
  issue #86.
- Interpretación: existe ruta de rollback por SHA y respaldo.
- Requisito: recuperación/rollback.
- Limitaciones: no se ejecutó rollback productivo ni restore Cloud SQL en esta
  auditoría; RTO/RPO quedan pendientes.

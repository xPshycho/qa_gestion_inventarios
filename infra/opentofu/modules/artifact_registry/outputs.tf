output "repository_id" {
  description = "ID estable del repositorio Docker."
  value       = google_artifact_registry_repository.docker.repository_id
}

output "repository_url" {
  description = "Prefijo regional completo usado para publicar imágenes."
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.docker.repository_id}"
}

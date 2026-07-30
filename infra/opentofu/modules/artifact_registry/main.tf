resource "google_artifact_registry_repository" "docker" {
  project       = var.project_id
  location      = var.region
  repository_id = var.repository_id
  description   = "Immutable inventory application images promoted by Git SHA"
  format        = "DOCKER"
  mode          = "STANDARD_REPOSITORY"
  labels        = var.labels

  cleanup_policy_dry_run = true
}

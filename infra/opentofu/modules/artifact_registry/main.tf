resource "google_artifact_registry_repository" "docker" {
  project       = var.project_id
  location      = var.region
  repository_id = var.repository_id
  description   = "Immutable inventory application images promoted by Git SHA"
  format        = "DOCKER"
  mode          = "STANDARD_REPOSITORY"
  labels        = var.labels

  cleanup_policy_dry_run = false

  cleanup_policies {
    id     = "delete-untagged-after-14-days"
    action = "DELETE"

    condition {
      tag_state  = "UNTAGGED"
      older_than = "1209600s"
    }
  }

  cleanup_policies {
    id     = "keep-recent-images"
    action = "KEEP"

    most_recent_versions {
      keep_count = 30
    }
  }
}

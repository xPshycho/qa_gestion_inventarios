resource "google_project_service" "storage" {
  project            = var.project_id
  service            = "storage.googleapis.com"
  disable_on_destroy = false
}

resource "google_storage_bucket" "state" {
  project                     = var.project_id
  name                        = var.state_bucket_name
  location                    = var.region
  storage_class               = "STANDARD"
  force_destroy               = false
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  labels = merge(var.labels, {
    application = "inventory"
    managed_by  = "opentofu"
    purpose     = "remote-state"
  })

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      num_newer_versions = 20
      with_state         = "ARCHIVED"
    }
    action {
      type = "Delete"
    }
  }

  lifecycle {
    prevent_destroy = true
  }

  depends_on = [google_project_service.storage]
}

resource "google_storage_bucket_iam_member" "state_admin" {
  for_each = var.state_admin_members

  bucket = google_storage_bucket.state.name
  role   = "roles/storage.objectAdmin"
  member = each.value
}

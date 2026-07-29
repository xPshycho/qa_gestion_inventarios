locals {
  accessor_bindings = merge([
    for secret_id, config in var.secrets : {
      for accessor in config.accessors :
      "${secret_id}:${accessor}" => {
        secret_id = secret_id
        accessor  = accessor
      }
    }
  ]...)
}

resource "google_secret_manager_secret" "catalog" {
  for_each = var.secrets

  project   = var.project_id
  secret_id = each.key
  labels    = var.labels

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_iam_member" "accessor" {
  for_each = local.accessor_bindings

  project   = var.project_id
  secret_id = google_secret_manager_secret.catalog[each.value.secret_id].secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${each.value.accessor}"
}

resource "google_sql_database_instance" "postgres" {
  project             = var.project_id
  name                = var.instance_name
  region              = var.region
  database_version    = "POSTGRES_16"
  deletion_protection = var.deletion_protection

  settings {
    tier              = var.tier
    edition           = "ENTERPRISE"
    availability_type = var.availability_type
    disk_type         = "PD_SSD"
    disk_size         = var.disk_size_gb
    disk_autoresize   = true
    user_labels       = var.labels

    backup_configuration {
      enabled                        = true
      point_in_time_recovery_enabled = true
      start_time                     = var.backup_start_time
      transaction_log_retention_days = var.environment == "production" ? 7 : 3
    }

    ip_configuration {
      ipv4_enabled                                  = false
      private_network                               = var.private_network
      allocated_ip_range                            = var.allocated_ip_range
      enable_private_path_for_google_cloud_services = true
      ssl_mode                                      = "ENCRYPTED_ONLY"
    }

    maintenance_window {
      day          = 7
      hour         = 4
      update_track = "stable"
    }
  }

  lifecycle {
    precondition {
      condition     = var.environment != "production" || var.availability_type == "REGIONAL"
      error_message = "Production Cloud SQL must use REGIONAL availability."
    }

    precondition {
      condition     = var.environment != "production" || var.deletion_protection
      error_message = "Production Cloud SQL must enable deletion protection."
    }
  }
}

resource "google_sql_database" "inventory" {
  project  = var.project_id
  name     = "inventory"
  instance = google_sql_database_instance.postgres.name
}

resource "google_sql_database" "keycloak" {
  project  = var.project_id
  name     = "keycloak"
  instance = google_sql_database_instance.postgres.name
}

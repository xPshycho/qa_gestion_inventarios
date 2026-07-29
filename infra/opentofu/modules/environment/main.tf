locals {
  prefix = "inventory-${var.environment}"
  labels = merge(var.labels, {
    application = "inventory"
    environment = var.environment
    managed_by  = "opentofu"
  })

  runtime_accounts = {
    web      = "inv-${substr(var.environment, 0, 8)}-web"
    identity = "inv-${substr(var.environment, 0, 8)}-identity"
  }

  runtime_roles = {
    for binding in flatten([
      for account in keys(local.runtime_accounts) : [
        for role in [
          "roles/cloudsql.client",
          "roles/logging.logWriter",
          "roles/monitoring.metricWriter",
          ] : {
          key     = "${account}:${role}"
          account = account
          role    = role
        }
      ]
    ]) : binding.key => binding
  }

  secret_ids = {
    inventory_db_password   = "${local.prefix}-inventory-db-password"
    keycloak_db_password    = "${local.prefix}-keycloak-db-password"
    keycloak_admin_password = "${local.prefix}-keycloak-admin-password"
    keycloak_admin_client   = "${local.prefix}-keycloak-admin-client-secret"
    e2e_admin_password      = "${local.prefix}-e2e-admin-password"
    e2e_operator_password   = "${local.prefix}-e2e-operator-password"
    e2e_viewer_password     = "${local.prefix}-e2e-viewer-password"
    e2e_auditor_password    = "${local.prefix}-e2e-auditor-password"
  }
}

resource "google_service_account" "runtime" {
  for_each = local.runtime_accounts

  project      = var.project_id
  account_id   = each.value
  display_name = "Inventory ${var.environment} ${each.key} runtime"
  description  = "Least-privilege runtime identity managed by OpenTofu."
}

resource "google_project_iam_member" "runtime" {
  for_each = local.runtime_roles

  project = var.project_id
  role    = each.value.role
  member  = "serviceAccount:${google_service_account.runtime[each.value.account].email}"
}

resource "google_compute_network" "environment" {
  project                 = var.project_id
  name                    = "${local.prefix}-network"
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

resource "google_compute_subnetwork" "serverless" {
  project                  = var.project_id
  name                     = "${local.prefix}-serverless"
  region                   = var.region
  network                  = google_compute_network.environment.id
  ip_cidr_range            = var.serverless_subnet_cidr
  private_ip_google_access = true
}

resource "google_compute_global_address" "private_services" {
  project       = var.project_id
  name          = "${local.prefix}-private-services"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.environment.id
}

resource "google_service_networking_connection" "private_services" {
  network                 = google_compute_network.environment.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_services.name]
}

module "database" {
  source = "../cloud_sql"

  project_id          = var.project_id
  region              = var.region
  environment         = var.environment
  instance_name       = "${local.prefix}-postgres"
  private_network     = "projects/${var.project_id}/global/networks/${google_compute_network.environment.name}"
  allocated_ip_range  = google_compute_global_address.private_services.name
  tier                = var.database_tier
  availability_type   = var.database_availability_type
  disk_size_gb        = var.database_disk_size_gb
  deletion_protection = var.database_deletion_protection
  labels              = local.labels

  depends_on = [google_service_networking_connection.private_services]
}

module "secrets" {
  source = "../secret_catalog"

  project_id = var.project_id
  labels     = local.labels
  secrets = {
    (local.secret_ids.inventory_db_password) = {
      accessors = [google_service_account.runtime["web"].email]
    }
    (local.secret_ids.keycloak_db_password) = {
      accessors = [google_service_account.runtime["identity"].email]
    }
    (local.secret_ids.keycloak_admin_password) = {
      accessors = [google_service_account.runtime["identity"].email]
    }
    (local.secret_ids.keycloak_admin_client) = {
      accessors = [
        google_service_account.runtime["web"].email,
        google_service_account.runtime["identity"].email,
      ]
    }
    (local.secret_ids.e2e_admin_password) = {
      accessors = [google_service_account.runtime["identity"].email]
    }
    (local.secret_ids.e2e_operator_password) = {
      accessors = [google_service_account.runtime["identity"].email]
    }
    (local.secret_ids.e2e_viewer_password) = {
      accessors = [google_service_account.runtime["identity"].email]
    }
    (local.secret_ids.e2e_auditor_password) = {
      accessors = [google_service_account.runtime["identity"].email]
    }
  }
}

module "identity" {
  count  = var.deploy_services ? 1 : 0
  source = "../cloud_run_service"

  project_id            = var.project_id
  region                = var.region
  name                  = "${local.prefix}-identity"
  service_account_email = google_service_account.runtime["identity"].email
  network               = google_compute_network.environment.name
  subnetwork            = google_compute_subnetwork.serverless.name
  allow_unauthenticated = true
  deletion_protection   = var.service_deletion_protection
  min_instances         = var.identity_min_instances
  max_instances         = var.identity_max_instances
  labels                = local.labels

  ingress_container = {
    name         = "keycloak"
    image        = var.keycloak_image
    port         = 8080
    args         = ["start", "--import-realm", "--http-enabled=true", "--proxy-headers=xforwarded", "--hostname-strict=false"]
    depends_on   = ["cloud-sql-proxy"]
    cpu          = "1"
    memory       = "1Gi"
    startup_path = "/realms/inventory/.well-known/openid-configuration"
    env = {
      KC_DB                       = "postgres"
      KC_DB_URL                   = "jdbc:postgresql://127.0.0.1:5432/keycloak"
      KC_DB_USERNAME              = "keycloak"
      KC_HEALTH_ENABLED           = "true"
      KC_METRICS_ENABLED          = "true"
      KC_BOOTSTRAP_ADMIN_USERNAME = "inventory-admin"
      KEYCLOAK_ADMIN_CLIENT_ID    = "inventory-admin-service"
    }
    secret_env = {
      KC_DB_PASSWORD = {
        secret  = local.secret_ids.keycloak_db_password
        version = var.secret_version
      }
      KC_BOOTSTRAP_ADMIN_PASSWORD = {
        secret  = local.secret_ids.keycloak_admin_password
        version = var.secret_version
      }
      KEYCLOAK_ADMIN_CLIENT_SECRET = {
        secret  = local.secret_ids.keycloak_admin_client
        version = var.secret_version
      }
      E2E_ADMIN_PASSWORD = {
        secret  = local.secret_ids.e2e_admin_password
        version = var.secret_version
      }
      E2E_OPERATOR_PASSWORD = {
        secret  = local.secret_ids.e2e_operator_password
        version = var.secret_version
      }
      E2E_VIEWER_PASSWORD = {
        secret  = local.secret_ids.e2e_viewer_password
        version = var.secret_version
      }
      E2E_AUDITOR_PASSWORD = {
        secret  = local.secret_ids.e2e_auditor_password
        version = var.secret_version
      }
    }
  }

  sidecar_containers = {
    cloud-sql-proxy = {
      image = var.cloud_sql_proxy_image
      args = [
        "--structured-logs",
        "--private-ip",
        "--address=0.0.0.0",
        "--port=5432",
        module.database.connection_name,
      ]
      cpu              = "1"
      memory           = "256Mi"
      startup_tcp_port = 5432
    }
  }

  depends_on = [
    google_project_iam_member.runtime,
    module.secrets,
  ]
}

module "web" {
  count  = var.deploy_services ? 1 : 0
  source = "../cloud_run_service"

  project_id            = var.project_id
  region                = var.region
  name                  = "${local.prefix}-web"
  service_account_email = google_service_account.runtime["web"].email
  network               = google_compute_network.environment.name
  subnetwork            = google_compute_subnetwork.serverless.name
  allow_unauthenticated = true
  deletion_protection   = var.service_deletion_protection
  min_instances         = var.web_min_instances
  max_instances         = var.web_max_instances
  labels                = local.labels

  ingress_container = {
    name          = "frontend"
    image         = var.frontend_image
    port          = 8080
    depends_on    = ["backend"]
    cpu           = "1"
    memory        = "256Mi"
    startup_path  = "/health"
    liveness_path = "/health"
    env = {
      BACKEND_UPSTREAM    = "127.0.0.1:8081"
      KEYCLOAK_PUBLIC_URL = module.identity[0].uri
      KEYCLOAK_REALM      = "inventory"
      KEYCLOAK_CLIENT_ID  = "inventory-frontend"
    }
  }

  sidecar_containers = {
    backend = {
      image      = var.backend_image
      depends_on = ["cloud-sql-proxy"]
      cpu        = "1"
      memory     = "1Gi"
      env = {
        SERVER_PORT                                           = "8081"
        SPRING_DATASOURCE_URL                                 = "jdbc:postgresql://127.0.0.1:5432/inventory"
        SPRING_DATASOURCE_USERNAME                            = "inventory"
        SPRING_SECURITY_OAUTH2_RESOURCESERVER_JWT_ISSUER_URI  = "${module.identity[0].uri}/realms/inventory"
        SPRING_SECURITY_OAUTH2_RESOURCESERVER_JWT_JWK_SET_URI = "${module.identity[0].uri}/realms/inventory/protocol/openid-connect/certs"
        KEYCLOAK_ADMIN_URL                                    = module.identity[0].uri
        KEYCLOAK_ADMIN_REALM                                  = "inventory"
        KEYCLOAK_ADMIN_CLIENT_ID                              = "inventory-admin-service"
        OTEL_SDK_DISABLED                                     = "false"
        OTEL_SERVICE_NAME                                     = "inventory-backend"
        OTEL_RESOURCE_ATTRIBUTES                              = "deployment.environment=${var.environment}"
      }
      secret_env = {
        SPRING_DATASOURCE_PASSWORD = {
          secret  = local.secret_ids.inventory_db_password
          version = var.secret_version
        }
        KEYCLOAK_ADMIN_CLIENT_SECRET = {
          secret  = local.secret_ids.keycloak_admin_client
          version = var.secret_version
        }
      }
      startup_http_port = 8081
      startup_http_path = "/actuator/health"
    }
    cloud-sql-proxy = {
      image = var.cloud_sql_proxy_image
      args = [
        "--structured-logs",
        "--private-ip",
        "--address=0.0.0.0",
        "--port=5432",
        module.database.connection_name,
      ]
      cpu              = "1"
      memory           = "256Mi"
      startup_tcp_port = 5432
    }
  }

  depends_on = [
    google_project_iam_member.runtime,
    module.secrets,
    module.identity,
  ]
}

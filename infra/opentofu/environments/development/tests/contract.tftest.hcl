mock_provider "google" {}

variables {
  project_id            = "inventory-qa-project"
  deploy_services       = true
  frontend_image        = "us-central1-docker.pkg.dev/inventory-qa-project/inventory-images/frontend@sha256:1111111111111111111111111111111111111111111111111111111111111111"
  backend_image         = "us-central1-docker.pkg.dev/inventory-qa-project/inventory-images/backend@sha256:2222222222222222222222222222222222222222222222222222222222222222"
  keycloak_image        = "us-central1-docker.pkg.dev/inventory-qa-project/inventory-images/keycloak@sha256:3333333333333333333333333333333333333333333333333333333333333333"
  cloud_sql_proxy_image = "gcr.io/cloud-sql-connectors/cloud-sql-proxy@sha256:4444444444444444444444444444444444444444444444444444444444444444"
}

run "development_contract" {
  command = plan

  plan_options {
    refresh = false
  }

  assert {
    condition     = output.environment.environment == "development"
    error_message = "Development must remain isolated under its canonical name."
  }

  assert {
    condition     = output.environment.cloud_run_enabled
    error_message = "The full plan must include Cloud Run services."
  }

  assert {
    condition     = output.environment.safety_contract.database_availability_type == "ZONAL"
    error_message = "Development must use a cost-controlled zonal database."
  }

  assert {
    condition     = output.environment.safety_contract.images_are_immutable
    error_message = "Every planned image must be immutable."
  }

  assert {
    condition     = output.environment.safety_contract.database_private_only && output.environment.safety_contract.database_encrypted_only
    error_message = "Cloud SQL must remain private-only and require encrypted connections."
  }
}

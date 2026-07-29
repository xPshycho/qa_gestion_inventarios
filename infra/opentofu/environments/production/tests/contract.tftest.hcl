mock_provider "google" {}

variables {
  project_id            = "inventory-qa-project"
  deploy_services       = true
  frontend_image        = "us-central1-docker.pkg.dev/inventory-qa-project/inventory-images/frontend@sha256:1111111111111111111111111111111111111111111111111111111111111111"
  backend_image         = "us-central1-docker.pkg.dev/inventory-qa-project/inventory-images/backend@sha256:2222222222222222222222222222222222222222222222222222222222222222"
  keycloak_image        = "us-central1-docker.pkg.dev/inventory-qa-project/inventory-images/keycloak@sha256:3333333333333333333333333333333333333333333333333333333333333333"
  cloud_sql_proxy_image = "gcr.io/cloud-sql-connectors/cloud-sql-proxy@sha256:4444444444444444444444444444444444444444444444444444444444444444"
}

run "production_contract" {
  command = plan

  plan_options {
    refresh = false
  }

  assert {
    condition     = output.environment.environment == "production"
    error_message = "Production must remain isolated under its canonical name."
  }

  assert {
    condition     = output.environment.safety_contract.database_availability_type == "REGIONAL"
    error_message = "Production Cloud SQL must use regional high availability."
  }

  assert {
    condition     = output.environment.safety_contract.database_deletion_protection
    error_message = "Production Cloud SQL must be protected from accidental deletion."
  }

  assert {
    condition     = output.environment.safety_contract.service_deletion_protection
    error_message = "Production Cloud Run must be protected from accidental deletion."
  }

  assert {
    condition     = output.environment.safety_contract.database_private_only && output.environment.safety_contract.database_encrypted_only
    error_message = "Production Cloud SQL must remain private-only and require encrypted connections."
  }
}

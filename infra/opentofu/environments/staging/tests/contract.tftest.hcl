mock_provider "google" {}

variables {
  project_id            = "inventory-qa-project"
  deploy_services       = true
  frontend_image        = "us-central1-docker.pkg.dev/inventory-qa-project/inventory-images/frontend@sha256:1111111111111111111111111111111111111111111111111111111111111111"
  backend_image         = "us-central1-docker.pkg.dev/inventory-qa-project/inventory-images/backend@sha256:2222222222222222222222222222222222222222222222222222222222222222"
  keycloak_image        = "us-central1-docker.pkg.dev/inventory-qa-project/inventory-images/keycloak@sha256:3333333333333333333333333333333333333333333333333333333333333333"
  cloud_sql_proxy_image = "gcr.io/cloud-sql-connectors/cloud-sql-proxy@sha256:4444444444444444444444444444444444444444444444444444444444444444"
}

run "staging_contract" {
  command = plan

  plan_options {
    refresh = false
  }

  assert {
    condition     = output.environment.environment == "staging"
    error_message = "Staging must remain isolated under its canonical name."
  }

  assert {
    condition     = output.environment.safety_contract.database_deletion_protection
    error_message = "Staging Cloud SQL must be protected from accidental deletion."
  }

  assert {
    condition     = output.environment.safety_contract.service_deletion_protection
    error_message = "Staging Cloud Run must be protected from accidental deletion."
  }

  assert {
    condition     = output.environment.network.serverless_subnet_cidr == "10.20.0.0/24"
    error_message = "Staging must keep an isolated serverless subnet."
  }
}

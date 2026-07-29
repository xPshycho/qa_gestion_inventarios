terraform {
  required_version = ">= 1.12.0, < 2.0.0"

  backend "gcs" {}

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

module "environment" {
  source = "../../modules/environment"

  project_id                   = var.project_id
  region                       = var.region
  environment                  = "production"
  serverless_subnet_cidr       = "10.30.0.0/24"
  deploy_services              = var.deploy_services
  frontend_image               = var.frontend_image
  backend_image                = var.backend_image
  keycloak_image               = var.keycloak_image
  cloud_sql_proxy_image        = var.cloud_sql_proxy_image
  secret_version               = var.secret_version
  database_tier                = var.database_tier
  database_availability_type   = "REGIONAL"
  database_disk_size_gb        = var.database_disk_size_gb
  database_deletion_protection = true
  service_deletion_protection  = true
  web_min_instances            = var.web_min_instances
  web_max_instances            = var.web_max_instances
  identity_min_instances       = 1
  identity_max_instances       = 2
  labels                       = var.labels
}

output "environment" {
  value = module.environment
}

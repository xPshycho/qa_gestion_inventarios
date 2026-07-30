locals {
  labels = merge(var.labels, {
    application = "inventory"
    managed_by  = "opentofu"
    scope       = "platform"
  })
}

module "services" {
  source = "../modules/project_services"

  project_id = var.project_id
  services = [
    "artifactregistry.googleapis.com",
    "compute.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "run.googleapis.com",
    "secretmanager.googleapis.com",
    "serviceusage.googleapis.com",
    "servicenetworking.googleapis.com",
    "sqladmin.googleapis.com",
    "storage.googleapis.com",
  ]
}

module "artifact_registry" {
  source = "../modules/artifact_registry"

  project_id    = var.project_id
  region        = var.region
  repository_id = var.repository_id
  labels        = local.labels

  depends_on = [module.services]
}

module "github_wif" {
  source = "../modules/github_wif"

  project_id                 = var.project_id
  region                     = var.region
  state_bucket_name          = var.state_bucket_name
  artifact_repository_id     = module.artifact_registry.repository_id
  github_repository_id       = var.github_repository_id
  github_repository_owner_id = var.github_repository_owner_id

  depends_on = [module.artifact_registry]
}

locals {
  pool_id = "github-inventory-cloudrun"

  deployments = {
    development = {
      branch      = "develop"
      provider_id = "github-develop"
    }
    staging = {
      branch      = "staging"
      provider_id = "github-staging"
    }
    production = {
      branch      = "main"
      provider_id = "github-main"
    }
  }

  deploy_roles = toset([
    "roles/cloudsql.admin",
    "roles/compute.networkAdmin",
    "roles/iam.serviceAccountAdmin",
    "roles/iam.serviceAccountUser",
    "roles/resourcemanager.projectIamAdmin",
    "roles/run.admin",
    "roles/secretmanager.admin",
    "roles/serviceusage.serviceUsageAdmin",
  ])

  development_platform_roles = toset([
    "roles/artifactregistry.admin",
    "roles/iam.workloadIdentityPoolAdmin",
  ])

  deploy_role_bindings = {
    for binding in flatten([
      for environment in keys(local.deployments) : [
        for role in local.deploy_roles : {
          key         = "${environment}:${role}"
          environment = environment
          role        = role
        }
      ]
    ]) : binding.key => binding
  }

  plan_roles = toset([
    "roles/artifactregistry.reader",
    "roles/cloudsql.viewer",
    "roles/compute.networkViewer",
    "roles/iam.securityReviewer",
    "roles/run.viewer",
    "roles/secretmanager.viewer",
    "roles/serviceusage.serviceUsageConsumer",
  ])

  repository_principal = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository_id/${var.github_repository_id}"
}

resource "google_iam_workload_identity_pool" "github" {
  project                   = var.project_id
  workload_identity_pool_id = local.pool_id
  display_name              = "GitHub Inventory OpenTofu"
  description               = "Keyless GitHub Actions identities for plans and deployments."
}

resource "google_iam_workload_identity_pool_provider" "deploy" {
  for_each = local.deployments

  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = each.value.provider_id
  display_name                       = "GitHub ${each.value.branch} deploy"
  attribute_condition                = "assertion.repository_id == '${var.github_repository_id}' && assertion.repository_owner_id == '${var.github_repository_owner_id}' && assertion.ref == 'refs/heads/${each.value.branch}'"
  attribute_mapping = {
    "google.subject"                = "assertion.sub"
    "attribute.ref"                 = "assertion.ref"
    "attribute.repository_id"       = "assertion.repository_id"
    "attribute.repository_owner_id" = "assertion.repository_owner_id"
  }

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_iam_workload_identity_pool_provider" "plan" {
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-pull-request-plan"
  display_name                       = "GitHub pull request plan"
  attribute_condition                = "assertion.repository_id == '${var.github_repository_id}' && assertion.repository_owner_id == '${var.github_repository_owner_id}' && assertion.ref.startsWith('refs/pull/')"
  attribute_mapping = {
    "google.subject"                = "assertion.sub"
    "attribute.ref"                 = "assertion.ref"
    "attribute.repository_id"       = "assertion.repository_id"
    "attribute.repository_owner_id" = "assertion.repository_owner_id"
  }

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account" "deploy" {
  for_each = local.deployments

  project      = var.project_id
  account_id   = "inv-${substr(each.key, 0, 8)}-deploy"
  display_name = "Inventory ${each.key} GitHub deploy"
  description  = "Keyless branch-restricted deployment identity."
}

resource "google_service_account" "plan" {
  project      = var.project_id
  account_id   = "inv-tofu-plan"
  display_name = "Inventory OpenTofu PR plan"
  description  = "Read-only keyless identity for internal pull-request plans."
}

resource "google_service_account_iam_member" "deploy_wif" {
  for_each = local.deployments

  service_account_id = google_service_account.deploy[each.key].name
  role               = "roles/iam.workloadIdentityUser"
  member             = local.repository_principal
}

resource "google_service_account_iam_member" "plan_wif" {
  service_account_id = google_service_account.plan.name
  role               = "roles/iam.workloadIdentityUser"
  member             = local.repository_principal
}

resource "google_project_iam_member" "deploy" {
  for_each = local.deploy_role_bindings

  project = var.project_id
  role    = each.value.role
  member  = google_service_account.deploy[each.value.environment].member
}

resource "google_project_iam_member" "development_platform" {
  for_each = local.development_platform_roles

  project = var.project_id
  role    = each.value
  member  = google_service_account.deploy["development"].member
}

resource "google_project_iam_member" "plan" {
  for_each = local.plan_roles

  project = var.project_id
  role    = each.value
  member  = google_service_account.plan.member
}

resource "google_artifact_registry_repository_iam_member" "deploy_writer" {
  for_each = local.deployments

  project    = var.project_id
  location   = var.region
  repository = var.artifact_repository_id
  role       = "roles/artifactregistry.writer"
  member     = google_service_account.deploy[each.key].member
}

resource "google_storage_bucket_iam_member" "deploy_state" {
  for_each = local.deployments

  bucket = var.state_bucket_name
  role   = "roles/storage.objectAdmin"
  member = google_service_account.deploy[each.key].member

  condition {
    title       = "manage_inventory_${each.key}_state"
    description = "Restricts the deployment identity to its environment state."
    expression  = "resource.name.startsWith('projects/_/buckets/${var.state_bucket_name}/objects/inventory/environments/${each.key}/')"
  }
}

resource "google_storage_bucket_iam_member" "plan_state" {
  bucket = var.state_bucket_name
  role   = "roles/storage.objectViewer"
  member = google_service_account.plan.member

  condition {
    title       = "read_inventory_environment_states"
    description = "Allows internal pull requests to read environment states."
    expression  = "resource.name.startsWith('projects/_/buckets/${var.state_bucket_name}/objects/inventory/environments/')"
  }
}

resource "google_storage_bucket_iam_member" "plan_platform_state" {
  bucket = var.state_bucket_name
  role   = "roles/storage.objectViewer"
  member = google_service_account.plan.member

  condition {
    title       = "read_inventory_platform_state"
    description = "Allows internal pull requests to read the shared platform state."
    expression  = "resource.name.startsWith('projects/_/buckets/${var.state_bucket_name}/objects/inventory/platform/')"
  }
}

resource "google_storage_bucket_iam_member" "development_platform_state" {
  bucket = var.state_bucket_name
  role   = "roles/storage.objectAdmin"
  member = google_service_account.deploy["development"].member

  condition {
    title       = "manage_inventory_platform_state"
    description = "Allows the develop branch pipeline to manage shared platform state."
    expression  = "resource.name.startsWith('projects/_/buckets/${var.state_bucket_name}/objects/inventory/platform/')"
  }
}

resource "google_storage_bucket_iam_member" "development_platform_bucket_iam" {
  bucket = var.state_bucket_name
  role   = "roles/storage.legacyBucketOwner"
  member = google_service_account.deploy["development"].member
}

resource "google_storage_bucket_iam_member" "state_validation" {
  bucket = var.state_bucket_name
  role   = "roles/storage.objectAdmin"
  member = google_service_account.deploy["development"].member

  condition {
    title       = "manage_inventory_state_validation"
    description = "Allows disposable locking and state recovery exercises."
    expression  = "resource.name.startsWith('projects/_/buckets/${var.state_bucket_name}/objects/validation/')"
  }
}

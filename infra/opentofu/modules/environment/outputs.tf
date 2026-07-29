output "environment" {
  value = var.environment
}

output "database" {
  value = {
    instance_name   = module.database.instance_name
    connection_name = module.database.connection_name
    database_names  = module.database.database_names
  }
}

output "network" {
  value = {
    name                   = google_compute_network.environment.name
    serverless_subnet_name = google_compute_subnetwork.serverless.name
    serverless_subnet_cidr = google_compute_subnetwork.serverless.ip_cidr_range
    private_services_range = google_compute_global_address.private_services.name
  }
}

output "runtime_service_accounts" {
  value = {
    for name, account in google_service_account.runtime :
    name => account.email
  }
}

output "secret_ids" {
  value = module.secrets.secret_ids
}

output "service_urls" {
  value = var.deploy_services ? {
    web      = module.web[0].uri
    identity = module.identity[0].uri
  } : null
}

output "cloud_run_enabled" {
  value = var.deploy_services
}

output "safety_contract" {
  value = {
    database_availability_type   = var.database_availability_type
    database_deletion_protection = var.database_deletion_protection
    service_deletion_protection  = var.service_deletion_protection
    database_private_only        = true
    database_encrypted_only      = true
    images_are_immutable = alltrue([
      for image in [
        var.frontend_image,
        var.backend_image,
        var.keycloak_image,
        var.cloud_sql_proxy_image,
        ] : !var.deploy_services || (
        can(regex("@sha256:[0-9a-f]{64}$", image)) &&
        !endswith(image, "@sha256:0000000000000000000000000000000000000000000000000000000000000000")
      )
    ])
  }
}

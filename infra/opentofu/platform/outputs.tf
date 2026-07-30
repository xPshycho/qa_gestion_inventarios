output "artifact_registry_repository" {
  value = module.artifact_registry.repository_id
}

output "artifact_registry_url" {
  value = module.artifact_registry.repository_url
}

output "enabled_services" {
  value = module.services.enabled_services
}

output "github_wif" {
  value = module.github_wif
}

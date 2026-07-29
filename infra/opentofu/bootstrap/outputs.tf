output "state_bucket_name" {
  description = "Bucket to place in each backend.hcl."
  value       = google_storage_bucket.state.name
}

output "state_prefixes" {
  description = "Canonical independent state prefixes."
  value = {
    platform    = "inventory/platform"
    development = "inventory/environments/development"
    staging     = "inventory/environments/staging"
    production  = "inventory/environments/production"
  }
}

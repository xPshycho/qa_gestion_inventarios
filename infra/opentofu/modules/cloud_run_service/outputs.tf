output "name" {
  value = google_cloud_run_v2_service.service.name
}

output "uri" {
  value = google_cloud_run_v2_service.service.uri
}

output "service_account_email" {
  value = var.service_account_email
}

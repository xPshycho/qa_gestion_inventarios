output "name" {
  description = "Nombre del servicio Cloud Run creado."
  value       = google_cloud_run_v2_service.service.name
}

output "uri" {
  description = "URI HTTPS asignada al servicio."
  value       = google_cloud_run_v2_service.service.uri
}

output "service_account_email" {
  description = "Correo de la identidad runtime asociada."
  value       = var.service_account_email
}

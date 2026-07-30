output "instance_name" {
  description = "Nombre de la instancia PostgreSQL."
  value       = google_sql_database_instance.postgres.name
}

output "connection_name" {
  description = "Connection name utilizado por Cloud SQL Auth Proxy."
  value       = google_sql_database_instance.postgres.connection_name
}

output "private_ip_address" {
  description = "Dirección privada de la instancia dentro de Private Services Access."
  value       = google_sql_database_instance.postgres.private_ip_address
}

output "database_names" {
  description = "Nombres de las bases de aplicación e identidad."
  value = {
    inventory = google_sql_database.inventory.name
    keycloak  = google_sql_database.keycloak.name
  }
}

output "instance_name" {
  value = google_sql_database_instance.postgres.name
}

output "connection_name" {
  value = google_sql_database_instance.postgres.connection_name
}

output "private_ip_address" {
  value = google_sql_database_instance.postgres.private_ip_address
}

output "database_names" {
  value = {
    inventory = google_sql_database.inventory.name
    keycloak  = google_sql_database.keycloak.name
  }
}

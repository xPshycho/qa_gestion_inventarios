output "secret_ids" {
  description = "IDs de secretos indexados por nombre lógico, sin material sensible."
  value = {
    for key, secret in google_secret_manager_secret.catalog :
    key => secret.secret_id
  }
}

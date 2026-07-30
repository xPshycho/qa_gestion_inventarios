output "deploy_service_accounts" {
  description = "Correos de las cuentas de despliegue, indexados por ambiente."
  value = {
    for environment, account in google_service_account.deploy :
    environment => account.email
  }
}

output "deploy_workload_identity_providers" {
  description = "Nombres completos de los providers WIF restringidos a cada rama."
  value = {
    for environment, provider in google_iam_workload_identity_pool_provider.deploy :
    environment => provider.name
  }
}

output "plan_service_account" {
  description = "Correo de la cuenta read-only utilizada por pull requests."
  value       = google_service_account.plan.email
}

output "plan_workload_identity_provider" {
  description = "Nombre completo del provider WIF restringido a refs de pull request."
  value       = google_iam_workload_identity_pool_provider.plan.name
}

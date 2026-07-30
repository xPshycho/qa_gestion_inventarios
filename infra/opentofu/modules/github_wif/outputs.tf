output "deploy_service_accounts" {
  value = {
    for environment, account in google_service_account.deploy :
    environment => account.email
  }
}

output "deploy_workload_identity_providers" {
  value = {
    for environment, provider in google_iam_workload_identity_pool_provider.deploy :
    environment => provider.name
  }
}

output "plan_service_account" {
  value = google_service_account.plan.email
}

output "plan_workload_identity_provider" {
  value = google_iam_workload_identity_pool_provider.plan.name
}

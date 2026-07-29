variable "project_id" {
  description = "Google Cloud project ID."
  type        = string
}

variable "region" {
  type    = string
  default = "us-central1"
}

variable "deploy_services" {
  description = "Enable only after image digests and secret versions exist."
  type        = bool
  default     = false
}

variable "frontend_image" {
  type    = string
  default = ""
}

variable "backend_image" {
  type    = string
  default = ""
}

variable "keycloak_image" {
  type    = string
  default = ""
}

variable "cloud_sql_proxy_image" {
  type    = string
  default = ""
}

variable "secret_version" {
  type    = string
  default = "1"
}

variable "database_tier" {
  type    = string
  default = "db-f1-micro"
}

variable "database_disk_size_gb" {
  type    = number
  default = 10
}

variable "database_deletion_protection" {
  type    = bool
  default = false
}

variable "web_max_instances" {
  type    = number
  default = 2
}

variable "labels" {
  type    = map(string)
  default = {}
}

variable "project_id" {
  description = "Google Cloud project ID."
  type        = string
}

variable "region" {
  type    = string
  default = "us-central1"
}

variable "deploy_services" {
  description = "Enable only through the protected production apply workflow."
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
  default = "db-custom-2-7680"
}

variable "database_disk_size_gb" {
  type    = number
  default = 20
}

variable "web_min_instances" {
  type    = number
  default = 1
}

variable "web_max_instances" {
  type    = number
  default = 5
}

variable "labels" {
  type    = map(string)
  default = {}
}

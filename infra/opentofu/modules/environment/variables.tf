variable "project_id" {
  description = "Google Cloud project that owns this environment."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "project_id must be a valid Google Cloud project ID."
  }
}

variable "region" {
  description = "Region shared by Cloud Run and Cloud SQL."
  type        = string
  default     = "us-central1"
}

variable "environment" {
  description = "Environment name."
  type        = string

  validation {
    condition     = contains(["development", "staging", "production"], var.environment)
    error_message = "environment must be development, staging or production."
  }
}

variable "deploy_services" {
  description = "Create Cloud Run services only after images and secret versions exist."
  type        = bool
  default     = false
}

variable "serverless_subnet_cidr" {
  description = "Non-overlapping /24 used by Cloud Run Direct VPC egress."
  type        = string

  validation {
    condition     = can(cidrnetmask(var.serverless_subnet_cidr)) && tonumber(split("/", var.serverless_subnet_cidr)[1]) == 24
    error_message = "serverless_subnet_cidr must be a valid IPv4 /24 CIDR."
  }
}

variable "frontend_image" {
  description = "Immutable frontend image reference."
  type        = string
  default     = ""
}

variable "backend_image" {
  description = "Immutable backend image reference."
  type        = string
  default     = ""
}

variable "keycloak_image" {
  description = "Immutable Keycloak image containing the rendered realm import contract."
  type        = string
  default     = ""
}

variable "cloud_sql_proxy_image" {
  description = "Immutable Cloud SQL Auth Proxy image reference."
  type        = string
  default     = ""
}

variable "secret_version" {
  description = "Numeric Secret Manager version mounted into Cloud Run revisions."
  type        = string
  default     = "1"

  validation {
    condition     = can(regex("^[1-9][0-9]*$", var.secret_version))
    error_message = "secret_version must be an explicit positive numeric version, never latest."
  }
}

variable "database_tier" {
  description = "Cloud SQL machine tier."
  type        = string
}

variable "database_availability_type" {
  description = "ZONAL for non-production, REGIONAL for production."
  type        = string
}

variable "database_disk_size_gb" {
  description = "Initial Cloud SQL disk size."
  type        = number
}

variable "database_deletion_protection" {
  description = "Protect Cloud SQL from accidental deletion."
  type        = bool
}

variable "service_deletion_protection" {
  description = "Protect Cloud Run services from accidental deletion."
  type        = bool
}

variable "web_min_instances" {
  type    = number
  default = 0
}

variable "web_max_instances" {
  type    = number
  default = 2
}

variable "identity_min_instances" {
  type    = number
  default = 0
}

variable "identity_max_instances" {
  type    = number
  default = 1
}

variable "labels" {
  description = "Additional labels applied to resources."
  type        = map(string)
  default     = {}
}

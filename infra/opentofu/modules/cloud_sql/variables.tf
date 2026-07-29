variable "project_id" {
  description = "Google Cloud project that owns the database."
  type        = string
}

variable "region" {
  description = "Cloud SQL region."
  type        = string
}

variable "environment" {
  description = "Environment name."
  type        = string

  validation {
    condition     = contains(["development", "staging", "production"], var.environment)
    error_message = "environment must be development, staging or production."
  }
}

variable "instance_name" {
  description = "Cloud SQL instance name."
  type        = string
}

variable "private_network" {
  description = "Self-link of the VPC used for private services access."
  type        = string
}

variable "allocated_ip_range" {
  description = "Name of the reserved private services access range."
  type        = string
}

variable "tier" {
  description = "Cloud SQL machine tier."
  type        = string
}

variable "availability_type" {
  description = "ZONAL for non-production or REGIONAL for production."
  type        = string

  validation {
    condition     = contains(["ZONAL", "REGIONAL"], var.availability_type)
    error_message = "availability_type must be ZONAL or REGIONAL."
  }
}

variable "disk_size_gb" {
  description = "Initial SSD size."
  type        = number

  validation {
    condition     = var.disk_size_gb >= 10
    error_message = "disk_size_gb must be at least 10."
  }
}

variable "deletion_protection" {
  description = "Protect the instance from accidental deletion."
  type        = bool
}

variable "backup_start_time" {
  description = "UTC start time for automated backups."
  type        = string
  default     = "03:00"
}

variable "labels" {
  description = "Labels applied to Cloud SQL."
  type        = map(string)
  default     = {}
}

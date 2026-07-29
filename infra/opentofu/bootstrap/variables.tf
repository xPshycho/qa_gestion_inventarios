variable "project_id" {
  description = "Google Cloud project that owns the remote-state bucket."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "project_id must be a valid Google Cloud project ID."
  }
}

variable "region" {
  description = "Default Google Cloud region."
  type        = string
  default     = "us-central1"
}

variable "state_bucket_name" {
  description = "Globally unique GCS bucket name."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9._-]{1,61}[a-z0-9]$", var.state_bucket_name))
    error_message = "state_bucket_name must be a valid globally unique GCS bucket name."
  }
}

variable "state_admin_members" {
  description = "IAM members allowed to read and write OpenTofu state objects."
  type        = set(string)

  validation {
    condition     = length(var.state_admin_members) > 0
    error_message = "At least one state administrator is required."
  }
}

variable "labels" {
  description = "Additional bucket labels."
  type        = map(string)
  default     = {}
}

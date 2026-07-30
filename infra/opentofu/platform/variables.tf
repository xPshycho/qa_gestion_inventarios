variable "project_id" {
  description = "Google Cloud project shared by the managed environments."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "project_id must be a valid Google Cloud project ID."
  }
}

variable "region" {
  description = "Artifact Registry and workload region."
  type        = string
  default     = "us-central1"
}

variable "repository_id" {
  description = "Shared immutable-image repository."
  type        = string
  default     = "inventory-images"
}

variable "labels" {
  description = "Additional platform labels."
  type        = map(string)
  default     = {}
}

variable "state_bucket_name" {
  description = "Remote-state bucket receiving environment-scoped WIF bindings."
  type        = string
}

variable "github_repository_id" {
  description = "Immutable numeric GitHub repository ID."
  type        = string

  validation {
    condition     = can(regex("^[1-9][0-9]*$", var.github_repository_id))
    error_message = "github_repository_id must be numeric."
  }
}

variable "github_repository_owner_id" {
  description = "Immutable numeric GitHub owner ID."
  type        = string

  validation {
    condition     = can(regex("^[1-9][0-9]*$", var.github_repository_owner_id))
    error_message = "github_repository_owner_id must be numeric."
  }
}

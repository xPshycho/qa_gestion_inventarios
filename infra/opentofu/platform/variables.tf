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

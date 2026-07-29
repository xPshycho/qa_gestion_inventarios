variable "project_id" {
  description = "Google Cloud project that owns the repository."
  type        = string
}

variable "region" {
  description = "Repository location."
  type        = string
}

variable "repository_id" {
  description = "Artifact Registry repository identifier."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{3,62}$", var.repository_id))
    error_message = "repository_id must use lowercase letters, digits and hyphens."
  }
}

variable "labels" {
  description = "Labels applied to the repository."
  type        = map(string)
  default     = {}
}

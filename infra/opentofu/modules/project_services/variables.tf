variable "project_id" {
  description = "Google Cloud project where APIs are enabled."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "project_id must be a valid Google Cloud project ID."
  }
}

variable "services" {
  description = "Google Cloud service APIs managed by this module."
  type        = set(string)
}

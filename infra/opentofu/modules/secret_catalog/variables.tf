variable "project_id" {
  description = "Google Cloud project that owns the secrets."
  type        = string
}

variable "secrets" {
  description = "Secret metadata and service accounts allowed to read each secret. Values are deliberately not managed."
  type = map(object({
    accessors = set(string)
  }))
}

variable "labels" {
  description = "Labels applied to every secret."
  type        = map(string)
  default     = {}
}

variable "project_id" {
  description = "Google Cloud project that owns the service."
  type        = string
}

variable "region" {
  description = "Cloud Run region."
  type        = string
}

variable "name" {
  description = "Cloud Run service name."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,61}[a-z0-9]$", var.name))
    error_message = "name must be a valid Cloud Run service name."
  }
}

variable "service_account_email" {
  description = "Runtime service account."
  type        = string
}

variable "network" {
  description = "VPC network used by Direct VPC egress."
  type        = string
}

variable "subnetwork" {
  description = "Regional subnet used by Direct VPC egress."
  type        = string
}

variable "ingress" {
  description = "Cloud Run ingress policy."
  type        = string
  default     = "INGRESS_TRAFFIC_ALL"
}

variable "allow_unauthenticated" {
  description = "Grant roles/run.invoker to allUsers."
  type        = bool
  default     = false
}

variable "deletion_protection" {
  description = "Protect the Cloud Run service from deletion."
  type        = bool
  default     = false
}

variable "min_instances" {
  description = "Minimum number of instances."
  type        = number
  default     = 0
}

variable "max_instances" {
  description = "Maximum number of instances."
  type        = number
  default     = 2
}

variable "labels" {
  description = "Labels applied to the service."
  type        = map(string)
  default     = {}
}

variable "ingress_container" {
  description = "Public ingress container."
  type = object({
    name       = string
    image      = string
    port       = number
    command    = optional(list(string), [])
    args       = optional(list(string), [])
    depends_on = optional(list(string), [])
    env        = optional(map(string), {})
    secret_env = optional(map(object({
      secret  = string
      version = string
    })), {})
    cpu               = optional(string, "1")
    memory            = optional(string, "512Mi")
    startup_path      = optional(string, "/")
    startup_period    = optional(number, 5)
    startup_failures  = optional(number, 12)
    liveness_path     = optional(string)
    liveness_period   = optional(number, 30)
    liveness_failures = optional(number, 3)
    startup_cpu_boost = optional(bool, true)
    cpu_idle          = optional(bool, true)
  })

  validation {
    condition = (
      can(regex("@sha256:[0-9a-f]{64}$", var.ingress_container.image)) &&
      !endswith(var.ingress_container.image, "@sha256:0000000000000000000000000000000000000000000000000000000000000000")
    )
    error_message = "The ingress image must end in a real, non-placeholder @sha256 digest."
  }
}

variable "sidecar_containers" {
  description = "Private containers sharing the Cloud Run instance network."
  type = map(object({
    image      = string
    command    = optional(list(string), [])
    args       = optional(list(string), [])
    depends_on = optional(list(string), [])
    env        = optional(map(string), {})
    secret_env = optional(map(object({
      secret  = string
      version = string
    })), {})
    cpu               = optional(string, "1")
    memory            = optional(string, "512Mi")
    startup_http_port = optional(number)
    startup_http_path = optional(string, "/")
    startup_tcp_port  = optional(number)
    startup_period    = optional(number, 5)
    startup_failures  = optional(number, 12)
    startup_cpu_boost = optional(bool, true)
    cpu_idle          = optional(bool, true)
  }))
  default = {}

  validation {
    condition = alltrue([
      for container in values(var.sidecar_containers) :
      can(regex("@sha256:[0-9a-f]{64}$", container.image)) &&
      !endswith(container.image, "@sha256:0000000000000000000000000000000000000000000000000000000000000000")
    ])
    error_message = "Every sidecar image must end in a real, non-placeholder @sha256 digest."
  }

  validation {
    condition = alltrue([
      for container in values(var.sidecar_containers) :
      container.startup_http_port == null || container.startup_tcp_port == null
    ])
    error_message = "A sidecar may configure an HTTP or TCP startup probe, not both."
  }
}

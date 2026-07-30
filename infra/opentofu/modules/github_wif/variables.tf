variable "project_id" {
  description = "ID del proyecto GCP que contiene las identidades federadas y sus permisos."
  type        = string
}

variable "region" {
  description = "Región del Artifact Registry al que escriben las identidades de despliegue."
  type        = string
}

variable "state_bucket_name" {
  description = "Nombre del bucket GCS que almacena los states separados por prefijo."
  type        = string
}

variable "artifact_repository_id" {
  description = "ID del repositorio Docker administrado por la plataforma."
  type        = string
}

variable "github_repository_id" {
  description = "ID numérico inmutable del repositorio GitHub autorizado."
  type        = string
}

variable "github_repository_owner_id" {
  description = "ID numérico inmutable del propietario GitHub autorizado."
  type        = string
}

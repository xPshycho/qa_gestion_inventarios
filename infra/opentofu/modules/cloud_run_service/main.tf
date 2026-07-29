resource "google_cloud_run_v2_service" "service" {
  project             = var.project_id
  name                = var.name
  location            = var.region
  ingress             = var.ingress
  deletion_protection = var.deletion_protection
  labels              = var.labels

  template {
    service_account = var.service_account_email

    vpc_access {
      egress = "PRIVATE_RANGES_ONLY"

      network_interfaces {
        network    = var.network
        subnetwork = var.subnetwork
      }
    }

    scaling {
      min_instance_count = var.min_instances
      max_instance_count = var.max_instances
    }

    containers {
      name       = var.ingress_container.name
      image      = var.ingress_container.image
      command    = var.ingress_container.command
      args       = var.ingress_container.args
      depends_on = var.ingress_container.depends_on

      ports {
        container_port = var.ingress_container.port
      }

      resources {
        limits = {
          cpu    = var.ingress_container.cpu
          memory = var.ingress_container.memory
        }
        cpu_idle          = var.ingress_container.cpu_idle
        startup_cpu_boost = var.ingress_container.startup_cpu_boost
      }

      dynamic "env" {
        for_each = var.ingress_container.env
        content {
          name  = env.key
          value = env.value
        }
      }

      dynamic "env" {
        for_each = var.ingress_container.secret_env
        content {
          name = env.key
          value_source {
            secret_key_ref {
              secret  = env.value.secret
              version = env.value.version
            }
          }
        }
      }

      startup_probe {
        initial_delay_seconds = 0
        timeout_seconds       = 3
        period_seconds        = var.ingress_container.startup_period
        failure_threshold     = var.ingress_container.startup_failures

        http_get {
          path = var.ingress_container.startup_path
          port = var.ingress_container.port
        }
      }

      dynamic "liveness_probe" {
        for_each = var.ingress_container.liveness_path == null ? [] : [var.ingress_container.liveness_path]
        content {
          timeout_seconds   = 3
          period_seconds    = var.ingress_container.liveness_period
          failure_threshold = var.ingress_container.liveness_failures

          http_get {
            path = liveness_probe.value
            port = var.ingress_container.port
          }
        }
      }
    }

    dynamic "containers" {
      for_each = var.sidecar_containers
      content {
        name       = containers.key
        image      = containers.value.image
        command    = containers.value.command
        args       = containers.value.args
        depends_on = containers.value.depends_on

        resources {
          limits = {
            cpu    = containers.value.cpu
            memory = containers.value.memory
          }
          cpu_idle          = containers.value.cpu_idle
          startup_cpu_boost = containers.value.startup_cpu_boost
        }

        dynamic "env" {
          for_each = containers.value.env
          content {
            name  = env.key
            value = env.value
          }
        }

        dynamic "env" {
          for_each = containers.value.secret_env
          content {
            name = env.key
            value_source {
              secret_key_ref {
                secret  = env.value.secret
                version = env.value.version
              }
            }
          }
        }

        dynamic "startup_probe" {
          for_each = (
            containers.value.startup_http_port != null ||
            containers.value.startup_tcp_port != null
          ) ? [containers.value] : []
          content {
            timeout_seconds   = 3
            period_seconds    = startup_probe.value.startup_period
            failure_threshold = startup_probe.value.startup_failures

            dynamic "http_get" {
              for_each = startup_probe.value.startup_http_port == null ? [] : [startup_probe.value.startup_http_port]
              content {
                path = startup_probe.value.startup_http_path
                port = http_get.value
              }
            }

            dynamic "tcp_socket" {
              for_each = startup_probe.value.startup_tcp_port == null ? [] : [startup_probe.value.startup_tcp_port]
              content {
                port = tcp_socket.value
              }
            }
          }
        }
      }
    }
  }

  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }

  lifecycle {
    precondition {
      condition     = var.max_instances >= var.min_instances
      error_message = "max_instances must be greater than or equal to min_instances."
    }
  }
}

resource "google_cloud_run_v2_service_iam_member" "public" {
  count = var.allow_unauthenticated ? 1 : 0

  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.service.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

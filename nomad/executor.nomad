variable "datacenters" {
  type = list(string)
}

variable "alertmanager_url" {
  type = string
}

variable "alertmanager_auth" {
  type = string
}

variable "executor_image" {
  type = string
}

variable "executor_cpu" {
  type = number
}

variable "executor_memory" {
  type = number
}

job "executor" {
  datacenters = var.datacenters
  type        = "service"

  update {
    max_parallel     = 1
    min_healthy_time = "10s"
    healthy_deadline = "3m"
    auto_revert      = false
    canary           = 0
  }

  migrate {
    max_parallel     = 1
    health_check     = "checks"
    min_healthy_time = "10s"
    healthy_deadline = "5m"
  }

  group "executor" {
    count = 1

    restart {
      attempts = 2
      interval = "30m"
      delay    = "15s"
      mode     = "fail"
    }

    network {
      port "http" {}
    }

    task "executor" {
      driver = "docker"

      config {
        image = var.executor_image
        command = "/bin/executor"
        args    = ["-config", "/config/config.yaml"]
        port_map {
          webserver     = 8082
          grpc          = 50060
        }
      }

      env {
        ALERTMANAGER_URL = var.alertmanager_url
        ALERTMANAGER_AUTH = var.alertmanager_auth
      }


      resources {
        cpu    = var.executor_cpu
        memory = var.executor_memory
      }

      service {
        name = "executor"
        port = "http"
        check {
          type     = "http"
          path     = "/health"
          interval = "10s"
          timeout  = "1s"
        }
      }

      template {
        destination = "/config/config.yaml"
        data = <<EOF
        api:
          host: mediator
          port: 50051

        global:
          host_root: /host

        webserver:
          port: 8082

        EOF
      }
    }
  }
}
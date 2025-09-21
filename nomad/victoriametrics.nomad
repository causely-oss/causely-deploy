variable "datacenters" {
  type = list(string)
}

variable "victoriametrics_image" {
  type = string
}

variable "victoriametrics_cpu" {
  type = number
}

variable "victoriametrics_memory" {
  type = number
}

variable "nfs_server" {
  type = string
}

variable "nfs_path" {
  type = string
}

job "victoriametrics" {
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

  group "victoriametrics" {
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

    task "victoriametrics" {
      driver = "docker"

      config {
        image = var.victoriametrics_image
        args  = [
          "-search.maxConcurrentRequests=128"
          "-search.maxUniqueTimeseries=3000000"
          "-search.maxQueryDuration=5m"
          "-search.maxQueryLen=65536"
          "-retentionPeriod=1d"
          "-storageDataPath=/local/victoria-metrics"
        ]
        port_map {
          http = 8428
        }
      }

      resources {
        cpu    = var.victoriametrics_cpu
        memory = var.victoriametrics_memory
      }

      service {
        name = "victoriametrics"
        port = "http"
        check {
          type     = "http"
          path     = "/health"
          interval = "10s"
          timeout  = "2s"
        }
      }

      volume_mount {
        volume      = "victoriametrics_data"
        destination = "/local/victoria-metrics"
      }
    }

    volume "victoriametrics_data" {
      type = "csi"
      source = "nfs"
      attachment_mode = "file-system"
      access_mode = "multi-node-multi-writer"
    }
  }
}
variable "datacenters" {
  type = list(string)
}

variable "gateway_token" {
  type = string
}

variable "mediator_image" {
  type = string
}

variable "mediator_cpu" {
  type = number
}

variable "mediator_memory" {
  type = number
}

variable "ml_image" {
  type = string
}

variable "ml_cpu" {
  type = number
}

variable "ml_memory" {
  type = number
}

variable "nfs_server" {
  type = string
}

variable "nfs_path" {
  type = string
}

job "mediator" {
  datacenters = {{ env "node.datacenter" }}

  type = "service"

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

  group "causely-mediator" {
    count = 1

    network {
      port "grpc-otlp" {}
      port "http-datadog" {}
      port "webserver" {}
      port "webserver2" {}
    }

    task "mediator" {
      driver = "docker"

      config {
        image   = var.mediator_image
        command = "/bin/mediator"
        args    = ["-config", "/config/config.yaml"]
        port_map {
          grpc-otlp     = 8360
          http-datadog  = 8125
          webserver     = 8082
          grpc          = 50051
        }
      }

      env {
        CAUSELY_GATEWAY_TOKEN = env("CAUSELY_GATEWAY_TOKEN", var.gateway_token)
      }

      resources {
        cpu    = var.mediator_cpu
        memory = var.mediator_memory
      }

      service {
        name = "mediator"
        port = "webserver"
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
        gateway:
          host: gw.causely.app
          port: 443
          tls: true
          insecure: false

        label_semconv:
          entities:
            - entity_type: "BusinessApplication"
              labels:
                - "app.kubernetes.io/part-of"
          scopes:
            geography:
              - "partition"
            environment:
              - "environment"
            team:
              - "team_name"

        ml:
          enabled: true
          host: causelyml.service.{{ env "node.datacenter" }}.consul
          port: 8361
          token: ""
          tls: false
          insecure: true

        repository:
          persistence:
            enabled: true
            path: /data/mediator.gob
          garbage_collector:
            enabled: true
          timeseries_forecast:
            enabled: true
          backend_sync:
            interval: 30s
          entity_attribute_metrics:
            enabled: true

        global:
          host_root: /host
          cluster_name: {{ env "node.datacenter" }}

        server:
          listen_port: 50051

        webserver:
          port: 8362

        time_series:
          hostname: causelyvictoria.service.{{ env "node.datacenter" }}.consul
          port: 8428

        scrapers:
          - type: Consul
            enabled: true
            sync_interval: 60s
            logging:
              scraper:
                level: info
              repository:
                level: info
            service_endpoint: http://consul-server.consul.svc.cluster.local:8500

          - type: Nomad
            enabled: true
            sync_interval: 60s
            logging:
              scraper:
                level: info
              repository:
                level: info
            nomad_api_endpoint: http://host.docker.internal:4646
            consul_api_endpoint: http://host.docker.internal:8500
            loki_endpoint: http://loki.docker.internal:3100
            logs_enabled: true
            token: ""

          - type: Prometheus
            enabled: true
            sync_interval: 20s
            logging:
              scraper:
                level: info
              repository:
                level: info
            servers:
              prometheus:
                endpoint: http://prometheus-operated.monitoring.svc.cluster.local:9090
                exporters:
                  - go-applications
                  - java-applications
                  - python-applications
            exporters:
              go-applications:
                entities:
                  - entity:
                      workload: {}

                    discovery:
                      - nomad_allocation:
                          namespace: "yext_site"
                          allocation_id: "alloc_id"
                    metrics:
                      - attribute: MutexWaitSecondsTotal
                        query: sum by (yext_site, alloc_id) (go_sync_mutex_wait_total_seconds_total{alloc_id!=""})

                      - attribute: UserCPUSecondsTotal
                        query: sum by (yext_site, alloc_id) (go_cpu_classes_user_cpu_seconds_total{alloc_id!=""})

                      - attribute: GCTotalCPUSecondsTotal
                        query: sum by (yext_site, alloc_id) (go_cpu_classes_gc_total_cpu_seconds_total{alloc_id!=""})

                      - attribute: DBConnectionUsage
                        query: sum by (yext_site, alloc_id) (avg_over_time(go_sql_connections_open[15m]))

                      - attribute: DBConnectionCapacity
                        query: sum by (yext_site, alloc_id) (avg_over_time(go_sql_connections_max_open[15m]))

                      - attribute: DBQueryDuration
                        query: "sum by (yext_site, alloc_id) (rate(postgres_queries_sum[1m]) / (rate(postgres_queries_count[1m]) > 0 or (rate(postgres_queries_count[1m]) + 1)))"

                      - attribute: GoMaxProcs
                        query: sum by (yext_site, alloc_id) (go_sched_gomaxprocs_threads{alloc_id!=""})

              java-applications:
                entities:
                  - entity:
                      workload: {}

                    discovery:
                      - nomad_allocation:
                          namespace: "yext_site"
                          allocation_id: "alloc_id"

                    metrics:
                      - attribute: JavaHeapCapacity
                        query: jvm_memory_bytes_max{area="heap"} or jvm_memory_max_bytes{area="heap"}

                      - attribute: JavaHeapUsage
                        query: jvm_memory_bytes_used{area="heap"} or jvm_memory_used_bytes{area="heap"}

                      - attribute: UserCPUSecondsTotal
                        query: sum by (yext_site, alloc_id) (process_cpu_seconds_total{alloc_id!=""})

                      - attribute: GCTotalCPUSecondsTotal
                        query: sum by (yext_site, alloc_id) (jvm_gc_collection_seconds_sum{alloc_id!=""})

              python-applications:
                entities:
                  - entity:
                      workload: {}

                    discovery:
                      - nomad_allocation:
                          namespace: "namespace"
                          allocation_id: "alloc_id"
                    metrics:
                      - attribute: RequestsTotal
                        query: sum by (yext_site, alloc_id) (rate(request_result_total[1m]))

          - type: OpenTelemetry
            enabled: true
            sync_interval: 20s
            port: 8360
            createAssets: true
            logging:
              scraper:
                level: info
              repository:
                level: info
            semconv:
              general:
                service.namespace:
                  - "deployment.site"

          - type: CauselyServices
            enabled: true
            sync_interval: 30s
            logging:
              scraper:
                level: info
              repository:
                level: info

        EOF
      }

      volume_mount {
        volume      = "repository"
        destination = "/local"
      }
    }

    task "ml" {
      driver = "docker"

      config {
        image   = var.ml_image
        command = "/bin/sh"
        args    = ["-c", "uv run mediator/main.py --config /config/config.yaml"]
        port_map {
          grpc      = 8361
          webserver2 = 8081
        }
      }

      resources {
        cpu    = var.ml_cpu
        memory = var.ml_memory
      }

      service {
        name = "ml"
        port = "webserver2"
        check {
          type     = "http"
          path     = "/health"
          interval = "10s"
          timeout  = "1s"
        }
      }

      template {
        destination = "/config/config_ml.yaml"
        data = <<EOF
        grpc:
          host: "0.0.0.0"
          port: 8361
          max_send_msg_size: 33554432 # 32MB
          max_receive_msg_size: 33554432 # 32MB

        # victoriametrics configuration
        victoriametrics:
          endpoint: "http://victoriametrics:8428"
          period: "24h"
          step: "5m"
          batch_size: 100
          batch_write_size: 1000
          max_backoff_minutes: 20 # 20 minutes max backoff
          initial_backoff_seconds: 1 # Initial backoff delay
          backoff_multiplier: 2 # Exponential backoff factor
          jitter: 0.1 # Jitter factor

        # Model settings
        model:
          min_threshold_ms: 10.00
          threshold_method: "iqr"
          horizon: 12 # 1 hour forecast with 5 minutes interval
          freq: "5min"

          # IQR model settings
          iqr:
            # Window is used to compute rolling statistics
            window_size: 72       # 6 hour window, 60 (min) / 5 (min) * 6 = 72
            upper_quantile: 0.95
            lower_quantile: 0.00
          min_threshold_ms: 10

          # Prophet model settings
          prophet:
            args:
              daily_seasonality: false
              weekly_seasonality: false
              yearly_seasonality: false
              seasonality_mode: "multiplicative"
              interval_width: 0.99
              changepoint_range: 0.8

        # webserver settings
        webserver:
          host: "0.0.0.0"
          port: 8081
        EOF
      }
    }

    volume "repository" {
      type = "csi"
      source = "nfs"
      attachment_mode = "file-system"
      access_mode = "multi-node-multi-writer"
    }
  }
}
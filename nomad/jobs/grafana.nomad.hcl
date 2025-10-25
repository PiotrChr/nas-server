job "grafana" {
  datacenters = ["dc1"]
  type        = "service"

  group "grafana" {
    network {
      mode = "bridge"
      port "http" {
        static = 3000
        to     = 3000
      }
    }

    volume "data" {
      type   = "host"
      source = "graf_data"
    }

    task "grafana" {
      driver = "docker"

      # Resolve Postgres via Consul and inject as env
      template {
        destination = "secrets/db.env"
        env         = true
        change_mode = "restart"
        data = <<-EOT
        GF_DATABASE_TYPE=postgres
        GF_DATABASE_NAME=grafana
        GF_DATABASE_USER=${GRAFANA_USER}
        GF_DATABASE_PASSWORD=${GRAFANA_PASSWORD}
        GF_DATABASE_HOST={{ with service "postgres" }}{{ (index . 0).Address }}:{{ (index . 0).Port }}{{ end }}
        EOT
      }

      # Provision Prometheus datasource via Consul discovery (no hardcoded IPs)
      template {
        destination = "local/provisioning/datasources/prometheus.yaml"
        change_mode = "restart"
        data = <<-YAML
        apiVersion: 1
        datasources:
          - name: Prometheus
            type: prometheus
            access: proxy
            isDefault: true
            url: http://{{ with service "prometheus" }}{{ (index . 0).Address }}:{{ (index . 0).Port }}{{ end }}
            jsonData:
              timeInterval: 15s
        YAML
      }

      config {
        image = "grafana/grafana-oss:latest"
        ports = ["http"]
        volumes = [
          "local/provisioning:/etc/grafana/provisioning"
        ]
      }

      volume_mount {
        volume      = "data"
        destination = "/var/lib/grafana"
      }

      service {
        name         = "grafana"
        port         = "http"
        address_mode = "host"
        check {
          name     = "http"
          type     = "http"
          method   = "GET"
          path     = "/api/health"
          interval = "15s"
          timeout  = "2s"
          port     = "http"
        }
      }

      resources {
        cpu    = 400
        memory = 256
      }
    }
  }
}

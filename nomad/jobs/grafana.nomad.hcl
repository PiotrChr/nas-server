job "grafana" {
  datacenters = ["dc1"]
  type = "service"

  group "grafana" {
    network {
      mode = "bridge"
      port "http" {
        static = 3000
        to = 3000
      }
    }

    volume "data" {
      type   = "host"
      source = "graf_data"
    }

    task "grafana" {
      driver = "docker"

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

      config {
        image = "grafana/grafana-oss:latest"
        ports = ["http"]
      }

      volume_mount {
        volume      = "data"
        destination = "/var/lib/grafana"
      }

      resources {
        cpu    = 300
        memory = 256
      }
    }
  }
}

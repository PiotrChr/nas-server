job "snmp-exporter" {
  datacenters = ["dc1"]
  type        = "service"

  group "snmp" {
    network {
      mode = "host"

      port "http" {
        static = 9116
        to     = 9116
      }
    }

    task "exporter" {
      driver = "docker"

      env {
        SNMP_COMMUNITY = "public"
      }

      config {
        image = "prom/snmp-exporter:v0.26.0"
        ports = ["http"]

        args = [
          "--config.file=/etc/snmp_exporter/snmp.yml",
        ]
      }

      service {
        name         = "snmp-exporter"
        port         = "http"
        address_mode = "host"

        check {
          name     = "http"
          type     = "http"
          path     = "/metrics"
          interval = "15s"
          timeout  = "2s"
          port     = "http"
        }
      }

      resources {
        cpu    = 50
        memory = 64
      }
    }
  }
}

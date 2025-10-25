job "node-exporter" {
  datacenters = ["dc1"]
  type = "service"
  
  group "node" {
    network {
      mode = "host"
      port "http" {
        static = 9100
        to     = 9100
      }
    }

    task "node-exporter" {
      driver = "docker"
      config {
        image = "prom/node-exporter:v1.8.2"
        network_mode = "host"
        pid_mode = "host"
        args = [
          "--collector.filesystem.mount-points-exclude=^/(dev|proc|sys|var/lib/docker/.+|run)/($|)",
          "--web.listen-address=:9100"
        ]
      }

      service {
        name = "node-exporter"
        port = "http"
        address_mode = "host"
        check {
            name = "http"
            type = "http"
            path = "/metrics"
            interval = "15s"
            timeout = "2s"
            port = "http"
        }
      }

      resources {
        cpu = 50
        memory = 64
      }
    }
  }
}
job "cadvisor" {
  datacenters = ["dc1"]
  type = "service"

  group "cad" {

    network {
        mode = "host"
        port "http" {
          static = 8090
          to     = 8090
        }
    }

    task "cadvisor" {
      driver = "docker"

      config {
        image = "gcr.io/cadvisor/cadvisor:v0.49.2"
        network_mode = "host"
        privileged = true
        volumes = [
          "/:/rootfs:ro",
          "/var/run:/var/run:rw",
          "/sys:/sys:ro",
          "/var/lib/docker/:/var/lib/docker:ro"
        ]
        args = ["--listen_ip=0.0.0.0", "--port=8090"]
      }

      service {
        name = "cadvisor"
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
        cpu = 200
        memory = 128
      }
    }
  }
}
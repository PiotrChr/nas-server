job "caddy" {
  datacenters = ["dc1"]
  type        = "service"

  group "proxy" {
    network {
      mode = "host"
    }

    volume "data" {
      type   = "host"
      source = "caddy_data"
    }

    volume "conf" {
      type   = "host"
      source = "caddy_conf"
    }

    task "caddy" {
        driver = "docker"

        template {
        destination = "local/Caddyfile"
        change_mode = "restart"
        data = <<-EOT
        {
            auto_https off
        }

        http://consul.home {
            reverse_proxy 127.0.0.1:8500
        }

        http://nomad.home {
            reverse_proxy 127.0.0.1:4646
        }

        http://grafana.home {
            reverse_proxy 127.0.0.1:3000
        }

        http://cadvisor.home {
            reverse_proxy 127.0.0.1:8090
        }

        http://prometheus.home {
            reverse_proxy 127.0.0.1:9090 
        }
        EOT
    }
      

      config {
        image        = "caddy:2"
        network_mode = "host"
        volumes = [
          "local/Caddyfile:/etc/caddy/Caddyfile"
        ]
      }

      volume_mount {
        volume      = "data"
        destination = "/data"
      }

      volume_mount {
        volume      = "conf"
        destination = "/config"
      }

      resources {
        cpu    = 200
        memory = 128
      }
    }
  }
}

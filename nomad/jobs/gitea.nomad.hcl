job "gitea" {
  datacenters = ["home"]
  type        = "service"
  constraint {
    attribute = "${node.class}"
    value     = "nas"
  }

  group "gitea" {
    network {
      mode = "bridge"
      port "http" {
        static = 3001
        to     = 3000
      }
      port "ssh" {
        static = 2223
        to     = 2223
      }
    }

    volume "data" {
      type      = "host"
      source    = "gitea_data"
      read_only = false
    }

    task "gitea" {
      driver = "docker"

      config {
        image        = "gitea/gitea:latest"
        #network_mode = "host"
        ports        = ["http", "ssh"]
      }

      volume_mount {
        volume      = "data"
        destination = "/data"
        read_only   = false
      }

      service {
        name         = "gitea"
        port         = "http"
        address_mode = "host"
        check {
          name     = "http"
          type     = "http"
          path     = "/api/healthz"
          interval = "15s"
          timeout  = "3s"
          port     = "http"
        }
      }

      resources {
        cpu    = 600
        memory = 768
      }
    }
  }
}

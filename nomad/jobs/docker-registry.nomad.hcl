job "docker-registry" {
  datacenters = ["home"]
  type        = "service"
  constraint {
    attribute = "${node.class}"
    value     = "nas"
  }

  group "registry" {
    count = 1

    network {
      port "http" {
        static = 5000
        to     = 5000
      }
    }

    volume "data" {
      type      = "host"
      source    = "docker_registry_data"
      read_only = false
    }

    task "registry" {
      driver = "docker"

      template {
        destination = "local/registry-config.yml"
        change_mode = "restart"
        data = <<-EOT
        version: 0.1
        log:
          fields:
            service: registry
        storage:
          filesystem:
            rootdirectory: /var/lib/registry
        http:
          addr: :5000
        delete:
          enabled: true
        EOT
      }

      env {
        REGISTRY_STORAGE_DELETE_ENABLED = "true"
      }

      config {
        image = "registry:2"
        ports = ["http"]
        volumes = [
          "local/registry-config.yml:/etc/docker/registry/config.yml"
        ]
      }

      volume_mount {
        volume      = "data"
        destination = "/var/lib/registry"
        read_only   = false
      }

      service {
        name = "docker-registry"
        port = "http"

        check {
          name     = "http"
          type     = "http"
          path     = "/v2/"
          interval = "15s"
          timeout  = "2s"
          port     = "http"
        }
      }

      resources {
        cpu    = 200
        memory = 256
      }
    }
  }
}

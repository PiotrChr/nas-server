job "immich" {
  datacenters = ["dc1"]
  type        = "service"

  # If media/volumes exist only on one node, pin the job there:
  # constraint {
  #   attribute = "${node.unique.name}"
  #   value     = "your-media-node"
  # }

  group "immich" {
    count = 1

    network {
      mode = "host"

      port "http" {
        static = 2283
        to     = 2283
      }

      port "ml-http" {
        static = 3003
        to     = 3003
      }
    }

    volume "uploads" {
      type      = "host"
      source    = "immich_uploads"
      read_only = false
    }

    volume "mlcache" {
      type      = "host"
      source    = "immich_ml_cache"
      read_only = false
    }

    # ----------------- Immich Machine Learning -----------------
    task "ml" {
      driver = "docker"

      env {
        TZ                     = "Europe/Zurich"
        MACHINE_LEARNING_CACHE = "/cache"
        MACHINE_LEARNING_URL   = "http://192.168.1.119:3003"
        GUNICORN_CMD_ARGS      = "--workers 1 --threads 2 --timeout 180"
        OMP_NUM_THREADS        = "1"
        OPENBLAS_NUM_THREADS   = "1"
      }

      config {
        image = "ghcr.io/immich-app/immich-machine-learning:release"
        ports = ["ml-http"]
        network_mode = "host"
        # For GPU accel later, we can add devices/capabilities here.
      }

      volume_mount {
        volume      = "mlcache"
        destination = "/cache"
        read_only   = false
      }

      resources {
        cpu    = 1000
        memory = 3024
      }

      service {
        name = "immich-ml"
        port = "ml-http"

        check {
          name     = "ml-tcp"
          type     = "tcp"
          interval = "15s"
          timeout  = "2s"
        }
      }
    }

    # ----------------- Immich Server (web + API) -----------------
    task "server" {
      driver = "docker"
      env {
        TZ = "Europe/Zurich"
        MACHINE_LEARNING_URL = "http://192.168.1.119:3003"
      }
      template {
        destination = "local/immich.env"
        env         = true
        change_mode = "restart"
        data = <<-EOT
        DB_HOSTNAME={{ with service "postgres" }}{{ (index . 0).Address }}{{ end }}
        DB_PORT={{ with service "postgres" }}{{ (index . 0).Port }}{{ end }}
        DB_USERNAME=immich
        DB_PASSWORD=immichpass
        DB_DATABASE_NAME=immich
        IMMICH_BIND_ADDRESS="0.0.0.0"

        REDIS_HOSTNAME="192.168.1.119"
        REDIS_PORT="6379"
        EOT
      }

      config {
        image = "ghcr.io/immich-app/immich-server:release"
        ports = ["http"]
        network_mode = "host"
        volumes      = ["/dev/dri:/dev/dri"]
        privileged = true
      }

      volume_mount {
        volume      = "uploads"
        destination = "/usr/src/app/upload"
        read_only   = false
      }

      resources {
        cpu    = 6000
        memory = 3048
      }

      service {
        name = "immich"
        port = "http"
        
        check {
          name     = "http"
          type     = "http"
          path     = "/"
          interval = "15s"
          timeout  = "3s"
          port     = "http"
        }
      }
    }
  }
}

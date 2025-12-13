job "redis" {
  datacenters = ["home"]
  type        = "service"
  constraint {
    attribute = "${node.class}"
    value     = "nas"
  }

  group "redis" {
    count = 1

    network {
      mode = "host"
      
      port "db" {
        static = 6379
        to     = 6379
      }
    }

    volume "redis_data" {
      type      = "host"
      source    = "redis_data"
      read_only = false
    }

    task "redis" {
      driver = "docker"

      env {
        TZ = "Europe/Zurich"
      }

      config {
        image = "redis:7-alpine"
        ports = ["db"]
        network_mode = "host"
        # Enable append-only file persistence
        command = "redis-server"
        args = [
          "--appendonly", "yes",
          "--bind", "0.0.0.0",
          "--save", "60", "10000"
        ]
      }

      volume_mount {
        volume      = "redis_data"
        destination = "/data"
        read_only   = false
      }

      resources {
        cpu    = 500
        memory = 512
      }

      service {
        name = "redis"
        port = "db"

        check {
          name     = "redis-ping"
          type     = "tcp"
          interval = "10s"
          timeout  = "1s"
        }
      }
    }
  }
}

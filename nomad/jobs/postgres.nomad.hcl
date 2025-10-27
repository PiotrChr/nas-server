job "postgres" {
  datacenters = ["dc1"]
  type = "service"

  group "pg" {
    network {
      mode = "bridge"
      port "db" { to = 5432 }
    }

    volume "data" {
      type   = "host"
      source = "postgres"
    }

    task "postgres" {
      driver = "docker"

      env {
        POSTGRES_USER     = "${POSTGRES_USER}"
        POSTGRES_PASSWORD = "${POSTGRES_PASSWORD}"
      }

      config {
        image = "postgres:17"
        ports = ["db"]
        args = [
            "-c", "shared_preload_libraries=pg_stat_statements",
            "-c", "track_io_timing=on",
            "-c", "pg_stat_statements.track=all",
            "-c", "track_activity_query_size=2048",
            # optional, for pgBadger later:
            # "-c", "log_min_duration_statement=500",
            # "-c", "log_line_prefix=%m [%p] %q%u@%d "
            ]
        volumes = [
          "local/init:/docker-entrypoint-initdb.d:ro"
        ]
      }

      volume_mount {
        volume      = "data"
        destination = "/var/lib/postgresql/data"
      }

      service {
        name = "postgres"
        port = "db"
        address_mode = "host"

        check {
          name     = "tcp-5432"
          type     = "tcp"
          interval = "10s"
          timeout  = "2s"
          port     = "db"
        }
      }

      resources {
        cpu    = 300
        memory = 512
      }
    }
  }
}

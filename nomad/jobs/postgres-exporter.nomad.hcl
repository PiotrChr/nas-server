job "postgres-exporter" {
  datacenters = ["dc1"]
  type = "service"

  group "metrics" {
    network {
      mode = "host"
      port "http" {
        static = 9187
        to     = 9187
      }
    }

    task "exporter" {
      driver = "docker"

      template {
        destination = "secrets/exporter.env"
        env         = true
        change_mode = "restart"
        data = <<-EOT
        DATA_SOURCE_NAME=postgresql://exporter:${EXPORTER_PASSWORD}@{{ with service "postgres" }}{{ (index . 0).Address }}:{{ (index . 0).Port }}{{ end }}/postgres?sslmode=disable
        PG_EXPORTER_EXTEND_QUERY_PATH=/etc/postgres_exporter/queries.yml
        PG_EXPORTER_AUTO_DISCOVER_DATABASES=true
        EOT
      }

      template {
        destination = "local/queries.yml"
        change_mode = "restart"
        data = <<-YAML
        pg_stat_statements:
            query: |
                SELECT
                d.datname,
                s.userid,
                s.dbid,
                s.queryid,
                sum(s.calls)               AS calls,
                sum(s.total_exec_time)     AS total_exec_time,
                sum(s.rows)                AS rows,
                sum(s.shared_blks_hit)     AS shared_blks_hit,
                sum(s.shared_blks_read)    AS shared_blks_read,
                sum(s.shared_blks_dirtied) AS shared_blks_dirtied,
                sum(s.shared_blks_written) AS shared_blks_written
                FROM pg_stat_statements s
                JOIN pg_database d ON d.oid = s.dbid
                WHERE d.datname = :'__dbname'
                GROUP BY d.datname, s.userid, s.dbid, s.queryid;
            metrics:
                - datname:              { usage: "LABEL",   description: "database" }
                - userid:               { usage: "LABEL",   description: "user OID" }
                - dbid:                 { usage: "LABEL",   description: "db OID" }
                - queryid:              { usage: "LABEL",   description: "query id" }
                - calls:                { usage: "COUNTER", description: "number of calls" }
                - total_exec_time:      { usage: "COUNTER", description: "total execution time (ms)" }
                - rows:                 { usage: "COUNTER", description: "rows returned" }
                - shared_blks_hit:      { usage: "COUNTER", description: "shared blocks hit" }
                - shared_blks_read:     { usage: "COUNTER", description: "shared blocks read" }
                - shared_blks_dirtied:  { usage: "COUNTER", description: "shared blocks dirtied" }
                - shared_blks_written:  { usage: "COUNTER", description: "shared blocks written" }
        YAML
      }

      config {
        image  = "prometheuscommunity/postgres-exporter:v0.15.0"
        ports  = ["http"]
        args = [
          "--no-collector.stat_bgwriter"
        ]
        volumes = [
          "local/queries.yml:/etc/postgres_exporter/queries.yml:ro"
        ]
      }

      service {
        name         = "postgres-exporter"
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
        cpu    = 100
        memory = 128
      }
    }
  }
}

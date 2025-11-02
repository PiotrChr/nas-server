job "filebeat" {
  datacenters = ["dc1"]
  type        = "system"

  group "filebeat" {
    network {
      mode = "host"
      port "http" {
        static = 5066
        to     = 5066
      }
    }

    task "filebeat" {
      driver = "docker"

      env {
        ELASTIC_USER     = "${ELASTIC_USER}"
        ELASTIC_PASSWORD = "${ELASTIC_PASSWORD}"
      }

      # TODO: When creating automation, we need to parametrize things like: filebeath image version
      template {
        destination = "local/filebeat.yml"
        change_mode = "restart"
        data = <<-YAML
        filebeat.inputs:
          - type: filestream
            id: system-logs
            paths:
              - /var/log/*.log
            ignore_older: 72h
          - type: filestream
            id: docker-containers
            paths:
              - /var/lib/docker/containers/*/*.log
            ignore_older: 72h
            parsers:
              - ndjson:
                  target: ""
                  overwrite_keys: true
                  add_error_key: true

        processors:
          - add_host_metadata: ~
          - add_cloud_metadata: ~

        output.elasticsearch:
          hosts: ["http://{{ with service \"elasticsearch\" }}{{ (index . 0).Address }}:{{ (index . 0).Port }}{{ end }}"]
          username: "${ELASTIC_USER}"
          password: "${ELASTIC_PASSWORD}"
          ssl.enabled: false

        setup.template.enabled: true
        setup.ilm.enabled: true

        http.enabled: true
        http.host: 0.0.0.0
        http.port: 5066

        logging.to_files: false
        YAML
      }

      config {
        image        = "docker.elastic.co/beats/filebeat:8.15.3"
        network_mode = "host"
        ports        = ["http"]
        args         = ["-e"]
        volumes = [
          "/var/log:/var/log:ro",
          "/var/lib/docker/containers:/var/lib/docker/containers:ro",
          "local/filebeat.yml:/usr/share/filebeat/filebeat.yml"
        ]
      }

      service {
        name         = "filebeat"
        port         = "http"
        address_mode = "host"
        tags         = ["logging", "elk"]
        check {
          name     = "http"
          type     = "http"
          method   = "GET"
          path     = "/"
          interval = "15s"
          timeout  = "5s"
        }
      }

      resources {
        cpu    = 300
        memory = 256
      }
    }
  }
}

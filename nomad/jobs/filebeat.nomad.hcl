job "filebeat" {
  type        = "system"
  datacenters = ["home"]
  constraint {
    attribute = "${node.class}"
    value     = "nas"
  }

  group "filebeat" {
    network {
      mode = "host"

      port "http" {
        to     = 5066
        static = 5066
      }
    }

    volume "docker_containers" {
      type      = "host"
      source    = "docker_containers"
      read_only = true
    }

    volume "filebeat_data" {
      type      = "host"
      source    = "filebeat_data"
      read_only = false
    }

    task "filebeat" {
      driver = "docker"
      user   = "root"
      
      env {
        ELASTIC_USERNAME = "${ELASTIC_USERNAME}"
        ELASTIC_PASSWORD = "${ELASTIC_PASSWORD}"
        TZ               = "Europe/Zurich"
      }

      template {
        destination = "local/filebeat.yml"
        change_mode = "restart"
        data = <<-EOT
        filebeat.inputs:
          - type: container
            id: docker-containers
            enabled: true
            paths:
              - /var/lib/docker/containers/*/*.log
            processors:
              - add_docker_metadata: ~
              - add_host_metadata: ~
          - type: filestream
            id: system-logs
            paths:
              - /var/log/*.log

        output.elasticsearch:
          hosts: ["http://{{ with service "elasticsearch" }}{{ (index . 0).Address }}:{{ (index . 0).Port }}{{ end }}"]
          username: ${ELASTIC_USERNAME}
          password: ${ELASTIC_PASSWORD}

        setup.kibana:
          host: "http://{{ with service "kibana" }}{{ (index . 0).Address }}:{{ (index . 0).Port }}{{ end }}"

        http.enabled: true
        http.host: 0.0.0.0
        http.port: 5066

        logging.to_stderr: true
        logging.level: info
        EOT
      }

      config {
        image = "docker.elastic.co/beats/filebeat:8.15.2"
        ports = ["http"]
        network_mode = "host"
        privileged   = true
        args = [
          "-e",
          "-c", "/usr/share/filebeat/filebeat.yml",
        ]

        mounts = [
          {
            type        = "bind"
            target      = "/var/lib/docker/containers"
            source      = "/var/lib/docker/containers"
            readonly    = true
            bind_options = {
              propagation = "rslave"
            }
          },
          {
            type     = "bind"
            target   = "/var/run/docker.sock"
            source   = "/var/run/docker.sock"
            readonly = true
          }
        ]

        volumes = [
          "local/filebeat.yml:/usr/share/filebeat/filebeat.yml:ro",
        ]
      }

      volume_mount {
        volume      = "filebeat_data"
        destination = "/usr/share/filebeat/data"
        read_only   = false
      }

      service {
        name = "filebeat"
        port = "http"

        check {
          name     = "http"
          type     = "http"
          path     = "/"
          interval = "15s"
          timeout  = "2s"
        }
      }

      resources {
        cpu    = 300
        memory = 384
      }
    }
  }
}

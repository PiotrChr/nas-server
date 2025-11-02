job "kibana" {
  datacenters = ["dc1"]
  type        = "service"

  group "kibana" {
    network {
      mode = "host"
      port "http" {
        static = 5601
        to     = 5601
      }
    }

    task "kibana" {
      driver = "docker"

      env {
        KIBANA_SYSTEM_PASSWORD = "${KIBANA_SYSTEM_PASSWORD}"
        KIBANA_ENCRYPTION_KEY  = "${KIBANA_ENCRYPTION_KEY}"
      }

      template {
        destination = "local/kibana.yml"
        change_mode = "restart"
        data = <<-YAML
        server.host: "0.0.0.0"
        server.publicBaseUrl: "http://kibana.home"
        elasticsearch.hosts: ["http://{{ with service "elasticsearch" }}{{ (index . 0).Address }}:{{ (index . 0).Port }}{{ end }}"]
        elasticsearch.username: "kibana_system"
        elasticsearch.password: "{{ env "KIBANA_SYSTEM_PASSWORD" }}"
        xpack.security.encryptionKey: "{{ env "KIBANA_ENCRYPTION_KEY" }}"
        xpack.encryptedSavedObjects.encryptionKey: "{{ env "KIBANA_ENCRYPTION_KEY" }}"
        xpack.reporting.encryptionKey: "{{ env "KIBANA_ENCRYPTION_KEY" }}"
        YAML
      }

      config {
        image        = "docker.elastic.co/kibana/kibana:8.15.3"
        network_mode = "host"
        ports        = ["http"]
        volumes = [
          "local/kibana.yml:/usr/share/kibana/config/kibana.yml"
        ]
      }

      service {
        name         = "kibana"
        port         = "http"
        address_mode = "host"
        tags         = ["visualization", "elk"]
        check {
          name     = "tcp"
          type     = "tcp"
          interval = "15s"
          timeout  = "5s"
        }
      }

      resources {
        cpu    = 500
        memory = 768
      }
    }
  }
}

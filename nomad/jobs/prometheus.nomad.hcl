job "prometheus" {
  datacenters = ["dc1"]
  type = "service"

  group "prom" {
    network {
        mode = "host"
        port "http" {
          static = 9090
          to     = 9090
        }
    }

    volume "data" {
      type   = "host"
      source = "prom_data"
    }

    task "prometheus" {
      driver = "docker"

      template {
        destination = "local/prometheus.yml"
        change_mode = "restart"
        data = <<-EOT
        global:
          scrape_interval: 15s
          evaluation_interval: 15s
          external_labels:
            dc: dc1
        scrape_configs:
          - job_name: "self"
            static_configs:
              - targets: ["127.0.0.1:9090"]

          - job_name: "node"
            consul_sd_configs:
              - server: "127.0.0.1:8500"
                services: ["node-exporter"]
            relabel_configs:
              - source_labels: ["__meta_consul_service_address","__meta_consul_service_port"]
                regex: "(.+);(.*)"
                replacement: "$1:$2"
                target_label: "__address__"

          - job_name: "cadvisor"
            consul_sd_configs:
              - server: "127.0.0.1:8500"
                services: ["cadvisor"]
            relabel_configs:
              - source_labels: ["__meta_consul_service_address","__meta_consul_service_port"]
                regex: "(.+);(.*)"
                replacement: "$1:$2"
                target_label: "__address__"

          - job_name: "nomad"
            metrics_path: /v1/metrics
            params:
              format: ["prometheus"]
            static_configs:
              - targets: ["127.0.0.1:4646"]

          - job_name: "consul"
            metrics_path: /v1/agent/metrics
            params:
              format: ["prometheus"]
            static_configs:
              - targets: ["127.0.0.1:8500"]
        EOT
      }

      config {
        image = "prom/prometheus:v2.55.0"
        network_mode = "host"
        args = [
          "--config.file=/etc/prometheus/prometheus.yml",
          "--storage.tsdb.path=/prometheus",
          "--storage.tsdb.retention.time=15d",
          "--web.enable-lifecycle",
          "--web.listen-address=:9090"
        ]
        volumes = ["local/prometheus.yml:/etc/prometheus/prometheus.yml"]
      }

      volume_mount {
        volume      = "data"
        destination = "/prometheus"
      }

      service {
        name = "prometheus"
        port = "http"
        address_mode = "host"
        check {
            name = "ready"
            type = "http"
            path = "/-/ready"
            interval = "10s"
            timeout = "2s"
            port = "http"
        }
     }

      resources {
        cpu = 300
        memory = 512
      }
    }
  }
}

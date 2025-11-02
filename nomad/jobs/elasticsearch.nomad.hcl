job "elasticsearch" {
  datacenters = ["dc1"]
  type        = "service"

  group "elasticsearch" {
    network {
      mode = "host"
      port "http" {
        static = 9200
        to     = 9200
      }
      port "transport" {
        static = 9300
        to     = 9300
      }
    }

    volume "data" {
      type   = "host"
      source = "elastic_data"
    }

    task "elasticsearch" {
      driver = "docker"

      env {
        ELASTIC_PASSWORD = "${ELASTIC_PASSWORD}"
        ES_JAVA_OPTS     = "-Xms1g -Xmx1g"
      }

      template {
        destination = "local/config/elasticsearch.yml"
        change_mode = "restart"
        data = <<-YAML
        cluster.name: home-elastic
        node.name: home-elastic
        discovery.type: single-node
        network.host: 0.0.0.0
        http.port: 9200
        transport.port: 9300
        xpack.security.enabled: true
        xpack.security.http.ssl.enabled: false
        xpack.security.transport.ssl.enabled: false
        YAML
      }

      config {
        image        = "docker.elastic.co/elasticsearch/elasticsearch:8.15.3"
        privileged   = false
        ports        = ["http", "transport"]
        network_mode = "host"
        volumes = [
          "local/config/elasticsearch.yml:/usr/share/elasticsearch/config/elasticsearch.yml"
        ]
      }

      volume_mount {
        volume      = "data"
        destination = "/usr/share/elasticsearch/data"
      }

      service {
        name         = "elasticsearch"
        port         = "http"
        address_mode = "host"
        tags         = ["search", "elk"]
        check {
          name     = "tcp"
          type     = "tcp"
          interval = "15s"
          timeout  = "5s"
        }
      }

      resources {
        cpu    = 1500
        memory = 3072
      }
    }

    task "kbn-password-reset" {
      driver = "docker"

      # Run after the main ES task starts; script waits until ES is healthy
      lifecycle {
        hook = "poststart"
      }

      restart {
        attempts = 0
        mode     = "fail"
      }

      env {
        ES_URL                 = "127.0.0.1:9200"
        ELASTIC_PASSWORD       = "${ELASTIC_PASSWORD}"
        KIBANA_SYSTEM_PASSWORD = "${KIBANA_SYSTEM_PASSWORD}"
      }

      template {
  destination = "local/reset_kbn_pwd.sh"
  perms       = "0755"
  data = <<-EOT
#!/usr/bin/env sh
set -eux

ES_BASE="http://$${ES_URL:-}"

until curl -s -u "elastic:$${ELASTIC_PASSWORD:-}" "$${ES_BASE:-}/_cluster/health?wait_for_status=yellow&timeout=60s" | grep -q '"status"'; do
  echo "Waiting for Elasticsearch ($${ES_BASE:-}) to be healthy..."
  sleep 2
done

echo "Changing kibana_system password to: $${KIBANA_SYSTEM_PASSWORD:-}"

curl -sS -u "elastic:$${ELASTIC_PASSWORD:-}" \
  -H 'Content-Type: application/json' \
  -X POST "$${ES_BASE:-}/_security/user/kibana_system/_password" \
  -d "{\"password\":\"$${KIBANA_SYSTEM_PASSWORD:-}\"}"
EOT
}

      config {
        image        = "curlimages/curl:8.10.1"
        network_mode = "host"
        command      = "/bin/sh"
        args         = ["-c", "/local/reset_kbn_pwd.sh"]
      }

      resources {
        cpu    = 100
        memory = 64
      }
    }
  }
}

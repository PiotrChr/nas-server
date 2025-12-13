job "qbittorrent" {
  datacenters = ["home"]
  type        = "service"
  constraint {
    attribute = "${node.class}"
    value     = "nas"
  }

  group "qbittorrent" {
    count = 1

    network {
      mode = "host"
      port "webui" {
        to = 8111
        static = 8111
      }
    }
    
    volume "downloads" {
      type      = "host"
      source    = "torrent_downloads"
      read_only = false
    }

    volume "qbittorrent_config" {
      type      = "host"
      source    = "torrent_config"
      read_only = false
    }

    task "qbittorrent" {
      driver = "docker"

      env {
        PUID = "1000"
        PGID = "1000"
        TZ   = "Europe/Zurich"
        WEBUI_PORT = "8111"
      }

      config {
        image = "lscr.io/linuxserver/qbittorrent:latest"
        ports = ["webui"]
      }


      service {
        name = "qbittorrent"
        port = "webui"
        
        check {
          name     = "http"
          type     = "http"
          path     = "/"
          interval = "15s"
          timeout  = "2s"
          port     = "webui"
        }
      }

      volume_mount {
        volume      = "downloads"
        destination = "/downloads"
        read_only   = false
      }

      volume_mount {
        volume      = "qbittorrent_config"
        destination = "/config"
        read_only   = false
      }

      resources {
        cpu    = 1000
        memory = 512
      }
    }
  }
}

job "plex" {
  datacenters = ["home"]
  type        = "service"
  constraint {
    attribute = "${node.class}"
    value     = "nas"
  }

  group "plex" {
    count = 1

    # If media paths exist only on one node, pin the job there:
    # constraint {
    #   attribute = "${node.unique.name}"
    #   value     = "your-media-node"
    # }

    network {
      port "http" {
        static = 32400
      }
    }

    volume "config" {
      type      = "host"
      source    = "plex_config"
      read_only = false
    }

    volume "transcode" {
      type      = "host"
      source    = "plex_transcode"
      read_only = false
    }

    volume "movies" {
      type      = "host"
      source    = "movies_library"
      read_only = true
    }

    volume "music" {
      type      = "host"
      source    = "music_library"
      read_only = true
    }

    volume "torrent_downloads" {
      type      = "host"
      source    = "torrent_downloads"
      read_only = false
    }

    task "plex" {
      driver = "docker"

      env {
        PUID       = "1000"
        PGID       = "1000"
        TZ         = "Europe/Zurich"
        VERSION    = "docker"
        # One-time claim token from https://www.plex.tv/claim/
        PLEX_CLAIM = "${PLEX_CLAIM}"
      }

      config {
        image = "lscr.io/linuxserver/plex:latest"
        ports = ["http"]

        # Hardware transcoding (Plex Pass) — requires /dev/dri on host
        privileged = true
        devices = [
          { host_path = "/dev/dri", container_path = "/dev/dri" }
        ]
      }

      volume_mount {
        volume      = "config"
        destination = "/config"
        read_only   = false
      }

      volume_mount {
        volume      = "transcode"
        destination = "/transcode"
        read_only   = false
      }

      volume_mount {
        volume      = "movies"
        destination = "/data/movies"
        read_only   = true
      }

      volume_mount {
        volume      = "music"
        destination = "/data/music"
        read_only   = true
      }

     volume_mount {
       volume      = "torrent_downloads"
       destination = "/data/torrent_downloads"
       read_only   = false
     }

      service {
        name = "plex"
        port = "http"

        check {
          name     = "tcp"
          type     = "tcp"
          interval = "15s"
          timeout  = "2s"
          port     = "http"
        }
      }

      resources {
        cpu    = 1500
        memory = 2024
      }
    }
  }
}

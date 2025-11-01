# Home Media Server

## Goal

Extend the home server with a media layer that can:

1. Download content (torrents) directly to NAS storage.
2. Expose a web UI for managing downloads.
3. Optionally organize and stream videos/music to local devices.
4. Fit into the existing Nomad + Ansible + observability setup.

## Core Components

* **Downloader**: `qbittorrent-nox` (headless) as Nomad job, with web UI.

  * Alternative: **Transmission** (lighter) or **rTorrent + Flood** (advanced users).
* **Indexers / automation (optional, later)**: `Prowlarr` → integrates trackers; `Sonarr` (series), `Radarr` (movies), `Lidarr` (music).
* **Media server** (pick one):

  * **Jellyfin** (fully open source, great for homelab)
  * **Plex** (mature, great clients, closed core)
  * **Emby** (between the two)
* **Storage layout**: single NAS path (e.g. `/srv/media`) with subfolders for `/downloads`, `/movies`, `/series`, `/music`.

## Logical Steps

1. **Define storage vars** (Ansible): base media dir, downloads dir, config dir.
2. **Deploy qBittorrent-nox** (Nomad): mount downloads + config; expose web UI via Caddy/Traefik.
3. **Deploy media server** (Jellyfin or Plex): mount media dirs read-only; expose via reverse proxy; enable hardware transcoding if available.
4. **(Optional) Deploy automation**: Sonarr/Radarr/Prowlarr, all pointing to qBittorrent and the same media root.
5. **Integrate with observability**: Filebeat collects downloader + media-server logs; Prometheus exporters where available; Grafana dashboards.

## Notes

* Reuse the same "storage-agnostic" Ansible wizard to ask for media base dir and generate Nomad volume mounts.
* Keep download and library dirs separate → automation can move/rename files safely.
* For remote access, prefer Tailscale/ZeroTier over exposing ports to the internet.

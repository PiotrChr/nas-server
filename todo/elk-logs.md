# Home Observability Stack

## Goal

Build a generic, repeatable home-lab observability setup on top of Nomad + Ansible that ingests logs from Docker/Nomad services, stores them in Elasticsearch, makes them queryable in Grafana (already running), and leaves room for future OpenTelemetry-based apps.

## Target Stack

* **Elasticsearch** – log storage and indexing (single-node to start)
* **Kibana** – fallback/diagnostic UI for ES
* **Filebeat** – lightweight log shipper from Docker/Nomad
* **OpenTelemetry Collector** – future-proof ingestion for custom apps/traces/metrics
* **Grafana** – single source of truth for dashboards (Prometheus + Elasticsearch)

## Logical Steps

1. **Deploy ELK core** (Elasticsearch + Kibana) as Nomad jobs or system services.
2. **Deploy Filebeat** as a single Nomad job on hosts running Docker/Nomad; mount Docker logs dir and point Filebeat to ES.
3. **Enable Filebeat modules** for common services (Postgres, Caddy/Nginx, system logs) to reuse ready-made parsers.
4. **Add Elasticsearch data source to Grafana** to query logs alongside Prometheus metrics.
5. **Deploy OTel Collector** as a Nomad job with a basic pipeline to ES; keep idle until custom apps are ready.
6. **Test with a sample Nomad workload** (e.g. Minecraft, test web service) and verify logs appear in Grafana.

## Notes

* Prefer **one central Filebeat** per node that reads Docker stdout logs over sidecars (simpler for Nomad/Docker).
* Keep **Kibana** installed even if Grafana is the primary UI.
* Ansible can generate **host_vars/group_vars** with storage paths (mount points) from a small "wizard" play.
* Everything should be **storage-agnostic**: user provides base path → templates fill in volumes → Nomad jobs mount.

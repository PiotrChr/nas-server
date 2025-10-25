# NAS Infrastructure Automation

This project defines a fully automated infrastructure for a home-lab NAS environment using **Ansible**, **Nomad**, **Consul**, **Caddy**, and supporting monitoring services (**Grafana**, **Prometheus**, **Node Exporter**, **cAdvisor**).

---

## Overview

### Core Components

| Service           | Role                                                               |
| ----------------- | ------------------------------------------------------------------ |
| **Ansible**       | Provisions base packages, configures firewall, volumes, and Nomad. |
| **Nomad**         | Schedules and manages all containerized workloads.                 |
| **Consul**        | Provides service discovery and health checks across jobs.          |
| **Caddy**         | Acts as reverse proxy and HTTPS gateway for internal services.     |
| **PostgreSQL**    | Backing database for Grafana and future apps.                      |
| **Prometheus**    | Time-series monitoring and alerting engine.                        |
| **Grafana**       | Visualization layer for all metrics.                               |
| **Node Exporter** | Collects host-level system metrics.                                |
| **cAdvisor**      | Collects container-level resource usage metrics.                   |

---

## Directory Layout

```
ansible/
  roles/
    nomad/
    consul/
    caddy/
  inventory.ini
  site.yml
nomad/jobs/
  grafana.nomad
  postgres.nomad
  prometheus.nomad
  node-exporter.nomad
  cadvisor.nomad
  caddy.nomad
```

---

## Deployment Flow

1. **Provision Base System (Ansible)**

   ```bash
   make run
   ```

   Installs:

   * Nomad + Consul
   * Required volumes under `/bulk2` or `/optane`
   * Firewall rules for Nomad/Consul/Caddy

2. **Run Core Nomad Jobs**

   ```bash
   make run-postgres
   make run-grafana
   make run-prometheus
   make run-node-exporter
   make run-cadvisor
   make run-caddy
   ```

3. **Access Services**

   * Nomad UI → [https://nomad.home](https://nomad.home)
   * Consul UI → [https://consul.home](https://consul.home)
   * Grafana → [https://grafana.home](https://grafana.home)
   * Prometheus → [https://prometheus.home](https://prometheus.home)

---

## Network and DNS

* **dnsmasq** resolves `*.home` to local LAN IP.
* **Caddy** handles HTTPS termination with automatic certificates.
* All services are reachable under subdomains (e.g. `grafana.home`, `prometheus.home`).

---

## Persistent Storage

| Mount Source                | Usage              |
| --------------------------- | ------------------ |
| `/bulk2/data`               | Application data   |
| `/bulk2/metrics/prometheus` | Prometheus TSDB    |
| `/bulk2/metrics/grafana`    | Grafana data       |
| `/optane/...`               | High I/O workloads |

Each Nomad job defines a **host volume** in `/etc/nomad.d/nomad.hcl` that maps these paths.

---

## Service Discovery & Integration

* Grafana dynamically discovers Postgres and Prometheus endpoints via **Consul template**.
* Prometheus uses **Consul service discovery** to find exporters.

---

## Monitoring Stack

* **Node Exporter** exposes host metrics on port `9100`.
* **cAdvisor** exposes container metrics on port `8090`.
* **Prometheus** scrapes both using Consul.
* **Grafana** visualizes via Prometheus datasource (auto-provisioned).

---

## Future Additions

* Add **Postgres exporter** for database metrics.
* Add **Loki + Promtail** for centralized logging.
* Integrate **alertmanager** with Prometheus.
* Expand to multiple Nomad nodes (Consul auto-joins cluster).

---

## References

* Nomad Docs: [https://developer.hashicorp.com/nomad/docs](https://developer.hashicorp.com/nomad/docs)
* Consul Docs: [https://developer.hashicorp.com/consul/docs](https://developer.hashicorp.com/consul/docs)
* Caddy Docs: [https://caddyserver.com/docs](https://caddyserver.com/docs)
* Prometheus Docs: [https://prometheus.io/docs](https://prometheus.io/docs)
* Grafana Docs: [https://grafana.com/docs](https://grafana.com/docs)

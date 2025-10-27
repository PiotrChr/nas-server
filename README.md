# NAS Infrastructure Automation

Hands-free provisioning for a home-lab NAS built on **Ansible**, **Nomad**, **Consul**, **Caddy**, and a full observability stack (Prometheus, Grafana, exporters).

---

## Overview

### Core Services

| Service                | Role                                                                                 |
| ---------------------- | ------------------------------------------------------------------------------------ |
| **Ansible**            | Brings the host to a desired state: packages, firewall rules, volumes, Nomad config. |
| **Nomad**              | Schedules and manages container workloads.                                           |
| **Consul**             | Service discovery for Nomad jobs and health checks.                                  |
| **Caddy**              | Reverse proxy for all internal services with LAN TLS off by default.                 |
| **PostgreSQL**         | Primary stateful service and Grafana datastore.                                      |
| **Prometheus**         | Time-series collection and alerting foundation.                                      |
| **Grafana**            | Dashboards and visualizations, pre-provisioned with Prometheus datasource.           |
| **Node Exporter**      | Host telemetry (CPU, memory, disk, network).                                         |
| **cAdvisor**           | Container-level metrics for all Nomad allocations.                                   |
| **PostgreSQL Exporter**| Deep Postgres metrics with extended queries (pg\_stat\_statements, latency, I/O).     |
| **SNMP Exporter**      | Router telemetry (if\_mib) for network health dashboards.                            |

![Nomad service overview](resources/readme/NomadServiceOverview.png)

---

## Repository Layout

```
ansible/
  roles/
    consul/
    docker/
    nomad/
    samba/
    dnsmasq/
  site.yml
dbs/
  exporter.sql
nomad/jobs/
  cadvisor.nomad.hcl
  caddy.nomad.hcl
  grafana.nomad.hcl
  node-exporter.nomad.hcl
  postgres.nomad.hcl
  postgres-exporter.nomad.hcl
  prometheus.nomad.hcl
  snmp-exporter.nomad.hcl
resources/
  docs/Setup.md              # Manual bootstrap checklist before Ansible
  grafana/dashboards/*.json  # Import-ready Grafana dashboards
  readme/*                   # Images & gifs referenced below
```

---

## Getting Started

1. **Bootstrap the host manually (optional but recommended).**  
   Follow `resources/docs/Setup.md` for the minimal Ubuntu baseline before automation.

2. **Prepare environment variables.**

   ```bash
   cp .env.dist .env
   ```

   Fill in:

   * `HOST`, `USER`, `KEY` for Ansible connectivity.
   * `POSTGRES_*` and `GRAFANA_*` credentials.
   * `NOMAD_ADDR` (e.g. `http://nomad.home:4646`) to make the Nomad CLI and Makefile targets work against the UI/API.

3. **Provision the host.**

   ```bash
   make run
   ```

   Installs Nomad, Consul, Docker, dnsmasq, configures firewall access (`80`, `443`, `4646`, `8500`, `8080`, `8090`, `9090`, `9100`, `9116`, `9187`), and prepares host volumes.

4. **Deploy Nomad workloads via the Makefile.**

   | Command                  | Deploys / Updates                           |
   | ------------------------ | ------------------------------------------- |
   | `make run-postgres`      | PostgreSQL with `pg_stat_statements` tuned. |
   | `make run-grafana`       | Grafana with Consul-driven datasource.      |
   | `make run-prometheus`    | Prometheus scrape config with Consul SD.    |
   | `make run-node-exporter` | Host metrics exporter.                      |
   | `make run-cadvisor`      | Container metrics exporter.                 |
   | `make run-caddy`         | Reverse proxy for `*.home` services.        |
   | `make run-postgres-exporter` | Postgres telemetry with custom queries. |
   | `make run-snmp-exporter` | Router SNMP bridge (default `if_mib` module).|

   All targets source `.env`, run `envsubst`, and pipe job specs directly into `nomad job run`.

5. **Seed the Postgres exporter role (run once per cluster).**

   ```bash
   psql -h <postgres-host> -U ${POSTGRES_USER} -f dbs/exporter.sql
   ```

   The script creates the `exporter` role, grants permissions, and enables `pg_stat_statements`.

---

## Monitoring & Exporters

* **Prometheus** (`prometheus.home`) scrapes:
  * Nomad API (`127.0.0.1:4646`)
  * Consul metrics (`127.0.0.1:8500`)
  * Node Exporter (Consul service discovery)
  * cAdvisor (Consul service discovery)
  * PostgreSQL Exporter (Consul service discovery)
  * SNMP Exporter (`192.168.1.119:9116` with `if_mib` target, router IP configurable in job file)
* **PostgreSQL Exporter** exposes extended metrics on `:9187`, including latency and query stats fed by `pg_stat_statements`.
* **SNMP Exporter** brings router interface stats into Prometheus; adjust community string and targets in `nomad/jobs/snmp-exporter.nomad.hcl`.
* **Grafana** (`grafana.home`) auto-discovers the Prometheus datasource through Consul, so dashboards are ready once jobs converge.

---

## Grafana Dashboards

Import-ready dashboards live in `resources/grafana/dashboards`. Use Grafana's **Dashboards → Import → Upload JSON** dialog and point to the desired file. Each dashboard assumes the default Prometheus datasource created by the Grafana job.

- **Nomad & System Services** – aggregate health view for Nomad allocations, Consul, and system-level exporters.  
  ![Nomad and System Services dashboard](resources/readme/NomadandSystemServices.gif)

- **Node & Container Detail** – correlates host metrics from Node Exporter with container stats from cAdvisor.  
  ![Node and container dashboard](resources/readme/Nodeandcontainers.gif)

- **Router Overview** – visualizes SNMP metrics for the edge router, including interface throughput and errors.  
  ![Router overview dashboard](resources/readme/RouterOverview.gif)

- **Postgres Health** – query performance, cache hit ratios, and I/O gleaned from the custom exporter queries.  
  ![Postgres dashboard](resources/readme/Postgres.gif)

Feel free to customize and re-export updated JSON into the same directory.

---

## Accessing Services

| URL                       | Purpose                              |
| ------------------------- | ------------------------------------ |
| `https://nomad.home`      | Nomad UI + API                       |
| `https://consul.home`     | Consul UI                            |
| `https://grafana.home`    | Grafana dashboards                   |
| `https://prometheus.home` | Prometheus UI for ad-hoc queries     |
| `https://cadvisor.home`   | cAdvisor UI (useful for spot checks) |

`dnsmasq` (provisioned by Ansible) resolves `*.home` to the NAS IP, so make sure LAN clients use it as their DNS forwarder.

---

## Future Enhancements

* Add **Loki + Promtail** for log aggregation.
* Wire **Alertmanager** with meaningful alert rules.
* Expand Nomad to run multiple clients with shared Consul service discovery.

---

## References

* Nomad Docs: [https://developer.hashicorp.com/nomad/docs](https://developer.hashicorp.com/nomad/docs)
* Consul Docs: [https://developer.hashicorp.com/consul/docs](https://developer.hashicorp.com/consul/docs)
* Caddy Docs: [https://caddyserver.com/docs](https://caddyserver.com/docs)
* Prometheus Docs: [https://prometheus.io/docs](https://prometheus.io/docs)
* Grafana Docs: [https://grafana.com/docs](https://grafana.com/docs)
